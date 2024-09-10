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

#ifndef _ARTICO3_POOL_H_
#define _ARTICO3_POOL_H_

#include <pthread.h>


/*
 * ARTICo3 thread pool task
 *
 * @routine : task function to be executed
 * @arg     : arguments to be passed to the function
 *
 */
struct a3task_t{
	void* (*routine) (void*);
	void *arg;
};


/*
 * ARTICo3 thread pool
 *
 * @num_threads              : number of threads in the thread pool
 * @sync_resources           : number of synchronization resources (one for "user request", num_threads for "kernel")
 * @threads                  : pthread_t id of each worker (array)
 * @t_ids                    : UNIX thread id of each worker (array)
 * @executed_task_per_thread : number of executed tasks per thread (array)
 * @running                  : flag indicating if each thread is busy (array)
 * @lock;                    : mutex used to synchronize the threads
 * @cond                     : CV used by the user to signal the workers that a task is waiting
 * @ack                      : CV used by a worker to indicate the user it is handling the task
 * @wake_up                  : flag associated with the field "cond" used to command a worker to wake up
 * @shutdown                 : flag associated with the field "cond" used to command a worker to shutdown
 * @task                     : pointer to a task that needs to be executed
 *
 */
struct a3pool_t {
    int num_threads;
    int sync_resources;
    pthread_t *threads;
    long int *t_ids;
    int *executed_task_per_thread;
    int *running;
	pthread_mutex_t *lock;
	pthread_cond_t *cond;
    pthread_cond_t *ack;
    int *wake_up;
    int shutdown;
	struct a3task_t **task;
};


/*
 * ARTICo3 thread pool workers function type
 *
 * Type of which must be each function to be executed by a worker.
 * The functions must have the following signature:
 *       void dispatch_function(void *arg)
 *
 */
typedef void* (*a3pool_submit_fn_t)(void *);


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
int artico3_pool_submit_task(struct a3pool_t *pool, const int thread_id, a3pool_submit_fn_t fn, void *arg);


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
int artico3_pool_isdone(const struct a3pool_t *pool, const int thread_id);


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
struct a3pool_t* artico3_pool_init(const int num_threads, const int type);


/*
 * ARTICo3 clean the thread pool
 *
 * This function destroys the thread pool.
 *
 * @pool : pointer to the thread pool
 *
 */
void artico3_pool_clean(struct a3pool_t *pool);

#endif /*_ARTICO3_POOL_H_*/