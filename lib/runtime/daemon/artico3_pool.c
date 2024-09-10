/*
 * ARTICo3 thread pool API
 *
 * Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 *               Juan Encinas <juan.encinas@upm.es>
 * Date        : Jun 2024
 * Description : This file contains functions to implement a thread pool software
 *               design pattern to efficiently handle a multitude of asynchronous
 *               concurrent tasks in a scalable and stable manner.
 *
 *               Two thread pool types are implemented:
 *               - "kernel" type generates a dedicated thread per available kernel.
 *                  It uses a set of synchronization resources particular to each thread.
 *               - "user request" type generates a set of threads.
 *                  It uses one set synchronization resources to handle all the threads as a whole.
 *               Both thread pool types are implemented using common functions that perform
 *               some operations in a specific manner based on the thread pool type.
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include <pthread.h>

#include <unistd.h>
#include <sys/syscall.h>  // syscall()

#include "artico3_pool.h"
#include "artico3_dbg.h"


// Get thread ID used to identify each user
#ifdef SYS_gettid
#define gettid() ((pid_t)syscall(SYS_gettid))
#else
#error "SYS_gettid unavailable on this system"
#endif


/*
 * ARTICo3 thread pool information (given to each worker at creation)
 *
 * @pool   : pointer to the thread pool
 * @id     : id of the particular worker
 * @random : flag indicating the workers are selected randomly
 *
 */
struct a3pool_info_t {
    struct a3pool_t *pool;
    int id;
};


/*
 * ARTICo3 pool delegate thread
 *
 */
static void* _artico3_pool_worker(void *p) {

    struct a3pool_info_t *t_info = (struct a3pool_info_t *) p;
    struct a3pool_t *pool = t_info->pool;
    pthread_mutex_t *pool_lock;
    pthread_cond_t *pool_cond;
    pthread_cond_t *pool_ack;
    struct a3task_t **pool_task;
    long int *pool_t_id;
    int *pool_wake_up, *pool_running, *pool_shutdown, *pool_executed_task_per_thread;

    // Get local variables based on the pool type (multiple sync resources vs one sycn resource)
    if (pool->sync_resources == 1) {
        pool_lock = pool->lock;
        pool_cond = pool->cond;
        pool_task = pool->task;
        pool_wake_up = pool->wake_up;
        pool_ack = pool->ack;
    }
    else {
        pool_lock = &pool->lock[t_info->id];
        pool_cond = &pool->cond[t_info->id];
        pool_task = &pool->task[t_info->id];
        pool_wake_up = &pool->wake_up[t_info->id];
        *pool_wake_up = 0;
        pool_ack = &pool->ack[t_info->id];
    }
    pool_executed_task_per_thread = &pool->executed_task_per_thread[t_info->id];
    pool_t_id = &pool->t_ids[t_info->id];
    pool_running = &pool->running[t_info->id];
    pool_shutdown = &pool->shutdown;

    // Initialize certain variables
    *pool_executed_task_per_thread = 0;
    *pool_t_id = gettid();
    *pool_running = 0;

    // Infinite loop where each thread will be waiting and executing tasks
	while(1) {
        struct a3task_t *task;

        pthread_mutex_lock(pool_lock);

        // Wait for a wake up signal
        while(*pool_wake_up == 0) {
            // Indicate the thread is not running
            *pool_running = 0;

            // Finishing each thread when the thread pool is cleaned
            if(*pool_shutdown) {
                pthread_mutex_unlock(pool_lock);
		        a3_print_debug("[artico3-hw] thread shutdown=%d\n", t_info->id);
                t_info->pool = NULL;
                free(t_info);
                pthread_exit(NULL);
            }

            // Wait for a new task to execute
            pthread_cond_wait(pool_cond, pool_lock);

            // Indicate the thread is running
            *pool_running = 1;
        }

        // Fetch task to be executed
        task = *pool_task;
        *pool_task = NULL;

        // Send ack
        *pool_wake_up = 0;
        pthread_cond_signal(pool_ack);

        pthread_mutex_unlock(pool_lock);

        // Execute the task
        a3_print_debug("[artico3-hw] thread executing task=%d\n", t_info->id);
		(task->routine)(task->arg);
        free(task);
        (*pool_executed_task_per_thread)++;
        a3_print_debug("[artico3-hw] task executed=%d\n", t_info->id);
	}
}


/*
 * ARTICo3 submit task to a pool thread
 *
 * This function commands a task to one of the thread pool workers.
 *
 * @pool      : pointer to the thread pool
 * @thread_id : ID of the thread to be used. Random pick when ID == 0
 * @fn        : function to be executed by the worker
 * @arg       : arguments that have to be passed to the function
 *
 * Return : thread_id on success, error code otherwise
 *
 */
int artico3_pool_submit_task(struct a3pool_t *pool, const int thread_id, a3pool_submit_fn_t fn, void *arg) {

    struct a3task_t *task;
    pthread_mutex_t *pool_lock;
    pthread_cond_t *pool_cond;
    pthread_cond_t *pool_ack;
    struct a3task_t **pool_task;
    int *pool_wake_up;

    // Get local variables based on the pool type (multiple sync resources vs one sycn resource)
    if (pool->sync_resources == 1) {
        pool_lock = pool->lock;
        pool_cond = pool->cond;
        pool_task = pool->task;
        pool_wake_up = pool->wake_up;
        pool_ack = pool->ack;
    }
    else {
        pool_lock = &pool->lock[thread_id-1];
        pool_cond = &pool->cond[thread_id-1];
        pool_task = &pool->task[thread_id-1];
        pool_wake_up = &pool->wake_up[thread_id-1];
        pool_ack = &pool->ack[thread_id-1];
    }

    // Create task
	task = malloc(sizeof *task);
	if(task == NULL) {
		a3_print_error("[artico3-hw] malloc() failed=%d\n", thread_id);
		return -1;
	}
	task->routine = fn;
	task->arg = arg;

    pthread_mutex_lock(pool_lock);

    // Signal a task to the thread pool
    *pool_task = task;
	*pool_wake_up = 1;
    pthread_cond_signal(pool_cond);
    a3_print_debug("[artico3-hw] task submited=%d\n", thread_id);

    // Wait for an ack
    while(*pool_wake_up)
        pthread_cond_wait(pool_ack, pool_lock);
    a3_print_debug("[artico3-hw] submited task ack received=%d\n", thread_id);

	pthread_mutex_unlock(pool_lock);

    // Return the ID of the thread in charge
    return thread_id;
}


/*
 * ARTICo3 check if thread commanded function is done
 *
 * This function indicates whether all the workers on the thread pool have
 * finished their assigned task or not.
 *
 * @pool      : pointer to the thread pool
 * @thread_id : ID of the thread to check. Wait for every thread when ID == 0
 *
 * Return : 1 when all the workers have finished their assigned tasks, 0 otherwise
 *
 */
int artico3_pool_isdone(const struct a3pool_t *pool, const int thread_id) {

    int i;

    // Waiting for a specific thread when the pool just have one sync resource
    if (pool->sync_resources > 1) {
        // If the thread is running it returns with 0
        if (pool->running[thread_id-1] > 0) return 0;
        // If the thread is not running it returns with 1
        return 1;
    }

    // Waiting for every thread when the pool have multiple
    // If any thread is running it returns with 0
    for (i = 0; i < pool->num_threads; i++)
        if (pool->running[i] > 0) return 0;

    // If no thread is running it returns with 1
    return 1;

}


/*
 * ARTICo3 initialized the thread pool
 *
 * This function creates and initializes the thread pool.
 *
 * @num_threads_in_pool : number of workers to be generated
 * @type                : 0 means type "kernel", 1 means type "user request"
 *
 * Return : pointer to the created thread pool
 *
 */
struct a3pool_t* artico3_pool_init(const int num_threads, const int type) {

    struct a3pool_t *pool = NULL;
    int i;

    // Allocate the thread pool structure
    pool = malloc(sizeof *pool);
    if (pool == NULL) {
        a3_print_error("[artico3-hw] pool malloc() failed\n");
        return NULL;
    }
    a3_print_debug("[artico3-hw] pool=%p\n", pool);

    // Initialize some thread pool variables based on the type of pool
    if (type)
        pool->sync_resources = 1;
    else
        pool->sync_resources = num_threads;
    pool->num_threads = num_threads;
    pool->shutdown = 0;

    // Allocate the array of threads
    pool->threads = malloc(pool->num_threads * sizeof *pool->threads);
    if (pool->threads == NULL) {
        a3_print_error("[artico3-hw] pool malloc() failed\n");
		goto thread_malloc_err;
    }
    a3_print_debug("[artico3-hw] pool->threads=%p\n", pool->threads);

    // Allocate the array of executed task counters
    pool->executed_task_per_thread = malloc(pool->num_threads * sizeof *pool->executed_task_per_thread);
    if (pool->executed_task_per_thread == NULL) {
        a3_print_error("[artico3-hw] pool malloc() failed\n");
		goto executed_task_per_thread_malloc_err;
    }
    a3_print_debug("[artico3-hw] pool->executed_task_per_thread=%p\n", pool->executed_task_per_thread);

    // Allocate the array of thread ids
    pool->t_ids = malloc(pool->num_threads * sizeof *pool->t_ids);
    if (pool->t_ids == NULL) {
        a3_print_error("[artico3-hw] pool malloc() failed\n");
		goto t_ids_malloc_err;
    }
    a3_print_debug("[artico3-hw] pool->t_ids=%p\n", pool->t_ids);

    // Allocate the array of running variables
    pool->running = malloc(pool->num_threads * sizeof *pool->running);
    if (pool->running == NULL) {
        a3_print_error("[artico3-hw] pool malloc() failed\n");
		goto running_malloc_err;
    }
    a3_print_debug("[artico3-hw] pool->running=%p\n", pool->running);

    // Allocate the array of wake_up variables
    pool->wake_up = malloc(pool->sync_resources * sizeof *pool->wake_up);
    if (pool->wake_up == NULL) {
        a3_print_error("[artico3-hw] pool malloc() failed\n");
		goto wake_up_malloc_err;
    }
    a3_print_debug("[artico3-hw] pool->wake_up=%p\n", pool->wake_up);

    // Allocate the array of mutexes
    pool->lock = malloc(pool->sync_resources * sizeof *pool->lock);
    if (pool->lock == NULL) {
        a3_print_error("[artico3-hw] pool malloc() failed\n");
		goto lock_malloc_err;
    }
    a3_print_debug("[artico3-hw] pool->lock=%p\n", pool->lock);

    // Allocate the array of conds
    pool->cond = malloc(pool->sync_resources * sizeof *pool->cond);
    if (pool->cond == NULL) {
        a3_print_error("[artico3-hw] pool malloc() failed\n");
		goto cond_malloc_err;
    }
    a3_print_debug("[artico3-hw] pool->cond=%p\n", pool->cond);

    // Allocate the array of conds
    pool->ack = malloc(pool->sync_resources * sizeof *pool->ack);
    if (pool->ack == NULL) {
        a3_print_error("[artico3-hw] pool malloc() failed\n");
		goto ack_malloc_err;
    }
    a3_print_debug("[artico3-hw] pool->ack=%p\n", pool->ack);

    // Allocate the array of tasks
    pool->task = malloc(pool->sync_resources * sizeof *pool->task);
    if (pool->task == NULL) {
        a3_print_error("[artico3-hw] pool malloc() failed\n");
		goto task_malloc_err;
    }
    a3_print_debug("[artico3-hw] pool->task=%p\n", pool->task);

    // Initialize mutex, conditional variables and other flags
    for (i = 0; i < pool->sync_resources; i++) {
        if(pthread_mutex_init(&(pool->lock[i]),NULL)) {
            a3_print_error("[artico3-hw] pool pthread_mutex_init() failed\n");
            goto err_thread_create;
        }
        if(pthread_cond_init(&(pool->cond[i]),NULL)) {
            a3_print_error("[artico3-hw] pool pthread_cond_init() failed\n");
            goto err_thread_create;
        }
        if(pthread_cond_init(&(pool->ack[i]),NULL)) {
            a3_print_error("[artico3-hw] pool pthread_cond_init() failed\n");
            goto err_thread_create;
        }
        pool->wake_up[i] = 0;
    }
    a3_print_debug("[artico3-hw] pool mutexes and conditional variables initialized\n");

    // Create the threads of the thread pool
    for (i = 0; i < pool->num_threads; i++) {
        // Create and initiailize each thread info structure
        struct a3pool_info_t *t_info = malloc(sizeof *t_info);
        t_info->pool = pool;
        t_info->id = i;
        if(pthread_create(&(pool->threads[i]), NULL, _artico3_pool_worker, t_info)) {
            a3_print_error("[artico3-hw] pool pthread_create() failed\n");
            free(t_info);
		    goto err_thread_create;
        }
    }
    a3_print_debug("[artico3-hw] pool threads initialized\n");

    return pool;

    // Error handling
    err_thread_create:
    free(pool->task);

    task_malloc_err:
    free(pool->ack);

    ack_malloc_err:
    free(pool->cond);

    cond_malloc_err:
    free(pool->lock);

    lock_malloc_err:
    free(pool->wake_up);

    wake_up_malloc_err:
    free(pool->running);

    running_malloc_err:
    free(pool->t_ids);

    t_ids_malloc_err:
    free(pool->executed_task_per_thread);

    executed_task_per_thread_malloc_err:
    free(pool->threads);

	thread_malloc_err:
    free(pool);

    return NULL;
}


/*
 * ARTICo3 clean the thread pool
 *
 * This function destroys the thread pool.
 *
 * @pool : pointer to the thread pool
 *
 */
void artico3_pool_clean(struct a3pool_t *pool) {

    int i;

    // Shutdown each thread of the pool
    for(i = 0; i < pool->sync_resources; i++) {
        pthread_mutex_lock(&(pool->lock[i]));

        // Signal a shutdown message to all threads
        pool->shutdown = 1;
        pthread_cond_broadcast(&(pool->cond[i]));

        pthread_mutex_unlock(&(pool->lock[i]));
    }

	// Wait for each of the thread of the pool to finish
	for(i = 0; i < pool->num_threads; i++) {
        pthread_join(pool->threads[i], NULL);
	}

    // Deallocate dynamically allocated thread pool variables
	free(pool->threads);
	free(pool->executed_task_per_thread);
	free(pool->t_ids);
	free(pool->running);
	free(pool->wake_up);
	free(pool->task);

    // Destroy mutex and conditional vairables
    for(i = 0; i < pool->sync_resources; i++) {
        if(pthread_mutex_destroy(&(pool->lock[i])) < 0){
            a3_print_error("[artico3-hw] pthread_mutex_destroy() failed\n");
            exit(1);
        }
        if(pthread_cond_destroy(&(pool->cond[i])) < 0){
            a3_print_error("[artico3-hw] pthread_cond_destroy() failed\n");
            exit(1);
        }
        if(pthread_cond_destroy(&(pool->ack[i])) < 0){
            a3_print_error("[artico3-hw] pthread_cond_destroy() failed\n");
            exit(1);
        }
    }
	free(pool->lock);
	free(pool->cond);
	free(pool->ack);

    // Clean the thread pool structure
    free(pool);
}
