/*
 * ARTICo3 user runtime
 *
 * Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 *               Juan Encinas <juan.encinas@upm.es>
 * Date        : May 2024
 * Description : This file contains the ARTICo3 runtime API, which can
 *               be used by any application to get access to adaptive
 *               hardware acceleration.
 *
 */


#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <math.h>      // ceil(), requires -lm in LDFLAGS
#include <pthread.h>

#include <fcntl.h>
#include <sys/types.h>

#include <dirent.h>      // DIR, struct dirent, opendir(), readdir(), closedir()
#include <sys/mman.h>    // mmap()
#include <sys/ioctl.h>   // ioctl()
#include <sys/poll.h>    // poll()
#include <sys/time.h>    // struct timeval, gettimeofday()
#include <sys/stat.h>    // stat(), S_IRUSR, S_IWUSR
#include <sys/syscall.h> // syscall()

#include "artico3.h"
#include "artico3_dbg.h"
#include "artico3_data.h"

#include <inttypes.h>


// Needed when compiling -lrt statically linked
// Note this "/dev/shm" might not be implemented in all systems
#define SHMDIR "/dev/shm/"
// TODO: for separate users, better create new common file
const char * __shm_directory(size_t * len) {
	*len = (sizeof SHMDIR) - 1;
	return SHMDIR;
}


// Get thread ID used to identify each user
#ifdef SYS_gettid
#define gettid() ((pid_t)syscall(SYS_gettid))
#else
#error "SYS_gettid unavailable on this system"
#endif


/*
 * ARTICo3 kernel buffer
 *
 * @name     : name of the kernel buffer
 * @size     : size of the virtual memory
 * @data     : virtual memory of input
 *
 */
struct a3buf_t {
    char *name;
    size_t size;
    void *data;
};


/*
 * ARTICo3 kernel (hardware accelerator)
 *
 * @name     : kernel name
 * @membanks : number of local memory banks inside kernel
 * @ports   : port configuration for this kernel
 *
 */
struct a3kernel_t {
    char *name;
    size_t membanks;
    struct a3buf_t **bufs;
};


/*
 * ARTICo3 global variables
 *
 * @kernels             : current kernel list
 *
 * @coordinator         : current ARTICo3 Daemon coordinator
 * @user                : current user
 *
 * @args_mutex          : synchronization primitive for handling request input argumetns
 * @kernel_create_mutex : synchronization primitive for creating a new kernel
 * @kernels_mutex       : synchronization primitive for accessing @kernels
 *
 * @user_shm            : user shared memory object filename
 *
 * @max_kernels         : maximum number of kernels
 *
 */
// TODO : remove this array of structures to avoid replicating code between user and daemon
static struct a3kernel_t **kernels;

static struct a3coordinator_t *coordinator = NULL;
static struct a3user_t *user = NULL;

static pthread_mutex_t args_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t kernel_create_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t kernels_mutex = PTHREAD_MUTEX_INITIALIZER;

static char user_shm[13];
unsigned int max_kernels = 0;


/*
 * ARTICo3 send request
 *
 * This function makes command requests to the ARTICo3 Daemon.
 *
 * NOTE : only the runtime can call this function, using it from user
 *       applications is forbidden (and not possible due to the static
 *       specifier).
 *
 * @request : request to be sent to the Daemon
 *
 * Return : 0 on success, error code otherwise
 *
 */
static int _artico3_send_request(struct a3request_t request) {
    int ack;
    struct a3channel_t *channel = NULL;

    pthread_mutex_lock(&coordinator->mutex);

    // Wait for server available
    while (coordinator->request_available) {
        a3_print_debug("[artico3u-hw] wait until server is free\n");
        pthread_cond_wait(&coordinator->cond_request, &coordinator->mutex);
    }

    // Signal the request
    coordinator->request = request;
    coordinator->request_available = 1;
    pthread_cond_signal(&coordinator->cond_request);
    a3_print_debug("[artico3u-hw] request signaled to the server\n");

    pthread_mutex_unlock(&coordinator->mutex);

    // Get the channel to be used for communication
    channel = &user->channels[request.channel_id];

    // Wait for response
    pthread_mutex_lock(&channel->mutex);
    while (!channel->response_available) {
        a3_print_debug("[artico3u-hw] wait for server command response\n");
        pthread_cond_wait(&channel->cond_response, &channel->mutex);
    }

    // Get the return of the requested command
    ack = channel->response;
    channel->response_available = 0;
    channel->free = 1;

    pthread_mutex_unlock(&channel->mutex);

    a3_print_debug("[artico3u-hw] request processed (id=%d, func=%d, response=%d)\n", user->user_id, request.func, ack);

    return ack;
}


/*
 * ARTICo3 user init function
 *
 * This function sets up the basic software entities required to interact
 * with the Daemon (kernel distribbution, shared memory objects, synchronization
 * primitives, etc.).
 *
 * It also loads the FPGA with the initial bitstream (static system).
 *
 * TODO : Get the tid as an argument from the user to make it user-dependant and not thread-dependant
 *
 * NOTE : This will not return if the shm filename chosen in already in use.
 *       It is done this way since there is no mechanism for new users to receive response from a3d.
 *       A timeout when shm filename already in use could be a solution.
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_init() {
    unsigned int index;
    int ret, shm_fd;
    struct stat stat_buffer;
    pid_t tid;
    char a3u_shm_check_path[50];
    struct a3request_t request;
    struct a3channel_t *channel = NULL;
    enum a3func_t type = A3_F_ADD_USER;

    // Create a shared memory object for daemon data
    shm_fd = shm_open(A3_COORDINATOR_FILENAME, O_RDWR, S_IRUSR | S_IWUSR);
    if(shm_fd < 0) {
        a3_print_error("[artico3u-hw] shm_open() failed\n");
        return -ENODEV;
    }

    // Resize the shared memory object
    ftruncate(shm_fd, sizeof (struct a3coordinator_t));

    // Allocate memory for application mapped to the shared memory object with mmap()
    coordinator = mmap(0, sizeof (struct a3coordinator_t), PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
    if(coordinator == MAP_FAILED) {
        a3_print_error("[artico3u-hw] mmap() failed\n");
        close(shm_fd);
        return -ENODEV;
    }
    a3_print_debug("[artico3u-hw] mmap=%p\n", coordinator);

    // Close shared memory object file descriptor (not needed anymore)
    close(shm_fd);

    // Create the shared memory object filename (based on thread ID)
    tid = gettid();
    snprintf(user_shm, sizeof user_shm, "user_%07d", tid);

    // Ensure the file does not exist (have not been already created by other client)
    snprintf(a3u_shm_check_path, sizeof a3u_shm_check_path, "%s%s", SHMDIR, user_shm);
    if (stat(a3u_shm_check_path, &stat_buffer) == 0) {
        a3_print_error("[artico3u-hw] \"%s\" already exist\n", a3u_shm_check_path);
        ret = -EINVAL;
        goto err_munmap_daemon;
    }

    // Create a shared memory object for arguments passing
    shm_fd = shm_open(user_shm, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
    if(shm_fd < 0) {
        a3_print_error("[artico3u-hw] shm_open() failed\n");
        ret = -ENODEV;
        goto err_munmap_daemon;
    }

    // Resize the shared memory object
    ftruncate(shm_fd, sizeof (struct a3user_t));

    // Allocate memory for application mapped to the shared memory object with mmap()
    user = mmap(0, sizeof (struct a3user_t), PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
    if(user == MAP_FAILED) {
        a3_print_error("[artico3u-hw] mmap() failed\n");
        close(shm_fd);
        shm_unlink(user_shm);
        ret = -ENODEV;
        goto err_munmap_daemon;
    }
    a3_print_debug("[artico3u-hw] mmap=%p\n", user);

    // Close shared memory object file descriptor (not needed anymore)
    close(shm_fd);

    // Initialize mutex and condition variables with shared memory attributes
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        channel = &user->channels[index];
        a3_print_debug("[artico3u-hw] init channel=%p\n", channel);

        pthread_mutexattr_t mutex_attr;
        pthread_condattr_t cond_attr;

        pthread_mutexattr_init(&mutex_attr);
        pthread_mutexattr_setpshared(&mutex_attr, PTHREAD_PROCESS_SHARED);
        pthread_mutex_init(&channel->mutex, &mutex_attr);
        pthread_mutexattr_destroy(&mutex_attr);

        pthread_condattr_init(&cond_attr);
        pthread_condattr_setpshared(&cond_attr, PTHREAD_PROCESS_SHARED);
        pthread_cond_init(&channel->cond_response, &cond_attr);
        pthread_condattr_destroy(&cond_attr);

        // Initialize flags
        channel->free = 1;
        channel->response = 0;
        channel->response_available = 0;
    }
    a3_print_debug("[artico3u-hw] initialized mutex and conditional variables\n");

    // Write request data
    request.func = type;
    request.user_id = -1;
    request.channel_id = 0;
    strcpy(request.shm, user_shm);

    // Make request
    a3_print_debug("[artico3u-hw] request command\n");
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        goto err_munmap_user;
    }

    // Get maximum number of kernels
    max_kernels = ret;

    // Initialize kernel list (software)
    kernels = malloc(max_kernels * sizeof **kernels);
    if (!kernels) {
        a3_print_error("[artico3u-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_munmap_user;
    }
    for (index = 0; index < max_kernels; index++) {
        kernels[index] = NULL;
    }
    a3_print_debug("[artico3u-hw] kernels=%p\n", kernels);

    return 0;

err_munmap_user:
    munmap(user, sizeof (struct a3user_t));
    shm_unlink(user_shm);

err_munmap_daemon:
    munmap(coordinator, sizeof (struct a3coordinator_t));

    return ret;
}


/*
 * ARTICo3 user exit function
 *
 * This function cleans the software entities created by artico3_init().
 *
 */
int artico3_exit() {
    int ret;
    unsigned int index;
    unsigned num_bytes;
    struct a3request_t request;
    char *args_ptr = NULL;
    struct a3channel_t *channel = NULL;
    enum a3func_t type = A3_F_REMOVE_USER;

    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return -EBUSY;
    }

    // Write request data
    request.func = type;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy request arguments
    args_ptr = user->channels[index].args;
    memcpy(args_ptr, &user->user_id, sizeof (int));
    num_bytes = sizeof (int);
    memcpy(&(args_ptr[num_bytes]), &index, sizeof (int));

    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return ret;
    }

    // Destroy mutex and condition variables with shared memory attributes
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        channel = &user->channels[index];

        pthread_mutex_destroy(&channel->mutex);
        pthread_cond_destroy(&channel->cond_response);

        // Initialize flags
        channel->response = 0;
        channel->response_available = 0;
    }

    // Cleanup user list
    munmap(user, sizeof (struct a3user_t));
    shm_unlink(user_shm);

    // Cleanup daemon structure
    munmap(coordinator, sizeof (struct a3coordinator_t));

    // Cleanup kernel list
    free(kernels);

    return 0;
}


/*
 * ARTICo3 create hardware kernel
 *
 * This function creates an ARTICo3 kernel in the current application.
 *
 * @name     : name of the hardware kernel to be created
 * @membytes : local memory size (in bytes) of the associated accelerator
 * @membanks : number of local memory banks in the associated accelerator
 * @regs     : number of read/write registers in the associated accelerator
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_kernel_create(const char *name, size_t membytes, size_t membanks, size_t regs) {
    int ret;
    unsigned num_bytes;
    unsigned int index, i;
    struct a3request_t request;
    struct a3kernel_t *kernel = NULL;
    enum a3func_t type = A3_F_KERNEL_CREATE;

    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return -EBUSY;
    }

    // Write request data
    request.func = type;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy arguments
    char *args_ptr = user->channels[index].args;
    // @name
    memcpy(args_ptr, name, strlen(name));
    num_bytes = strlen(name);
    args_ptr[num_bytes++] = '\0';
    // @membytes
    memcpy(&(args_ptr[num_bytes]), &membytes, sizeof (size_t));
    num_bytes += sizeof (size_t);
    // @membanks
    memcpy(&(args_ptr[num_bytes]), &membanks, sizeof (size_t));
    num_bytes += sizeof (size_t);
    // @regs
    memcpy(&(args_ptr[num_bytes]), &regs, sizeof (size_t));

    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return ret;
    }

    pthread_mutex_lock(&kernel_create_mutex);

    // Search first available ID; if none, return with error
    for (index = 0; index < max_kernels; index++) {
        if (kernels[index] == NULL) break;
    }
    if (index == max_kernels) {
        a3_print_error("[artico3u-hw] kernel list is already full\n");
        return -EBUSY;
    }

    // Allocate memory for kernel info
    kernel = malloc(sizeof *kernel);
    if (!kernel) {
        a3_print_error("[artico3u-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_kernel;
    }

    // Set kernel name
    kernel->name = malloc(strlen(name) + 1);
    if (!kernel->name) {
        a3_print_error("[artico3u-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_kernel_name;
    }
    strcpy(kernel->name, name);

    // Set kernel configuration
    kernel->membanks = membanks;

    // Initialize kernel buffers
    kernel->bufs = malloc(membanks * sizeof *kernel->bufs);
    if (!kernel->bufs) {
        a3_print_error("[artico3u-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_kernel_bufs;
    }

    // Set initial values for ports
    for (i = 0; i < membanks; i++) {
        kernel->bufs[i] = NULL;
    }

    a3_print_debug("[artico3u-hw] created kernel (name=%s,membytes=%zd,membanks=%zd,regs=%zd)\n", name, membytes, membanks, regs);

    // Store kernel configuration in kernel list
    kernels[index] = kernel;

    pthread_mutex_unlock(&kernel_create_mutex);

    return ret;

err_malloc_kernel_bufs:
    free(kernel->name);

err_malloc_kernel_name:
    free(kernel);

err_malloc_kernel:
    kernels[index] = NULL;

    return ret;
}


/*
 * ARTICo3 release hardware kernel
 *
 * This function deletes an ARTICo3 kernel in the current application.
 *
 * @name : name of the hardware kernel to be deleted
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_kernel_release(const char *name) {
    unsigned num_bytes;
    unsigned int index;
    int ret;
    struct a3request_t request;
    struct a3kernel_t *kernel = NULL;
    enum a3func_t type = A3_F_KERNEL_RELEASE;

    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return -EBUSY;
    }

    // Write request data
    request.func = type;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy arguments
    char *args_ptr = user->channels[index].args;
    // @name
    memcpy(args_ptr, name, strlen(name));
    num_bytes = strlen(name);
    args_ptr[num_bytes++] = '\0';

    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return ret;
    }

    pthread_mutex_lock(&kernels_mutex);

    // Search for kernel in kernel list
    for (index = 0; index < max_kernels; index++) {
        if (!kernels[index]) continue;
        if (strcmp(kernels[index]->name, name) == 0) break;
    }
    if (index == max_kernels) {
        a3_print_error("[artico3u-hw] no kernel found with name \"%s\"\n", name);
        pthread_mutex_unlock(&kernels_mutex);
        return -ENODEV;
    }

    // Get kernel pointer
    kernel = kernels[index];

    // Set kernel list entry as empty
    kernels[index] = NULL;

    pthread_mutex_unlock(&kernels_mutex);

    // Free allocated memory
    free(kernel->bufs);
    free(kernel->name);
    free(kernel);
    kernel = NULL;
    a3_print_debug("[artico3u-hw] released kernel (name=%s)\n", name);

    return ret;
}


/*
 * ARTICo3 execute hardware kernel
 *
 * This function executes an ARTICo3 kernel in the current application.
 *
 * @name  : name of the hardware kernel to execute
 * @gsize : global work size (total amount of work to be done)
 * @lsize : local work size (work that can be done by one accelerator)
 *
 * Return : 0 on success, error code otherwisw
 *
 */
int artico3_kernel_execute(const char *name, size_t gsize, size_t lsize) {
    unsigned num_bytes;
    unsigned int index;
    int ret;
    struct a3request_t request;
    enum a3func_t type = A3_F_KERNEL_EXECUTE;

    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return -EBUSY;
    }

    // Write request data
    request.func = type;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy arguments
    char *args_ptr = user->channels[index].args;
    // @name
    memcpy(args_ptr, name, strlen(name));
    num_bytes = strlen(name);
    args_ptr[num_bytes++] = '\0';
    // @gsize
    memcpy(&(args_ptr[num_bytes]), &gsize, sizeof (size_t));
    num_bytes += sizeof (size_t);
    // @lsize
    memcpy(&(args_ptr[num_bytes]), &lsize, sizeof (size_t));

    // printf("[artico3u-hw] [id=%d] name: %s | gsize : %lu | lsize: %lu\n", user->user_id, name, gsize, lsize);
    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return ret;
    }

    return ret;
}


/*
 * ARTICo3 wait for kernel completion
 *
 * This function waits until the kernel has finished.
 *
 * @name : hardware kernel to wait for
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_kernel_wait(const char *name) {
    unsigned num_bytes;
    unsigned int index;
    int ret;
    struct a3request_t request;
    enum a3func_t type = A3_F_KERNEL_WAIT;

    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return -EBUSY;
    }

    // Write request data
    request.func = type;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy arguments
    char *args_ptr = user->channels[index].args;
    // @name
    memcpy(args_ptr, name, strlen(name));
    num_bytes = strlen(name);
    args_ptr[num_bytes++] = '\0';

    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return ret;
    }

    return ret;
}


/*
 * ARTICo3 reset hardware kernel
 *
 * This function resets all hardware accelerators of a given kernel.
 *
 * @name : hardware kernel to reset
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_kernel_reset(const char *name) {
    unsigned num_bytes;
    unsigned int index;
    int ret;
    struct a3request_t request;
    enum a3func_t type = A3_F_KERNEL_RESET;

    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return -EBUSY;
    }

    // Write request data
    request.func = type;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy arguments
    char *args_ptr = user->channels[index].args;
    // @name
    memcpy(args_ptr, name, strlen(name));
    num_bytes = strlen(name);
    args_ptr[num_bytes++] = '\0';

    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return ret;
    }

    return ret;
}


/*
 * ARTICo3 configuration register write
 *
 * This function writes configuration data to ARTICo3 kernel registers.
 *
 * @name   : hardware kernel to be addressed
 * @offset : memory offset of the register to be accessed
 * @cfg    : array of configuration words to be written, one per
 *           equivalent accelerator
 *
 * Return : 0 on success, error code otherwise
 *
 * NOTE : configuration registers need to be handled taking into account
 *        execution priorities.
 *
 *        TMR == (0x1-0xf) > DMR == (0x1-0xf) > Simplex (TMR == 0 && DMR == 0)
 *
 *        The way in which the hardware infrastructure has been implemented
 *        sequences first TMR transactions (in ascending group order), then
 *        DMR transactions (in ascending group order) and finally, Simplex
 *        transactions.
 *
 */
int artico3_kernel_wcfg(const char *name, uint16_t offset, a3data_t *cfg) {
    unsigned num_bytes;
    unsigned int index;
    int ret, naccs;
    struct a3request_t request;
    enum a3func_t type = A3_F_KERNEL_WCFG;

    // Ask for naccs
    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return -EBUSY;
    }

    // Write request data
    request.func = A3_F_GET_NACCS;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy arguments
    char *args_ptr = user->channels[index].args;
    // @name
    memcpy(args_ptr, name, strlen(name));
    num_bytes = strlen(name);
    args_ptr[num_bytes++] = '\0';

    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return ret;
    }

    // Store returned naccs
    naccs = ret;

    // Write configuration registers
    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return -EBUSY;
    }

    // Write request data
    request.func = type;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy arguments
    // @name
    memcpy(args_ptr, name, strlen(name));
    num_bytes = strlen(name);
    args_ptr[num_bytes++] = '\0';
    // @offset
    memcpy(&(args_ptr[num_bytes]), &offset, sizeof (uint16_t));
    num_bytes += sizeof (uint16_t);
    // @cfg
    memcpy(&(args_ptr[num_bytes]), cfg, naccs * sizeof (a3data_t));

    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return ret;
    }

    return ret;
}


/*
 * ARTICo3 configuration register read
 *
 * This function reads configuration data from ARTICo3 kernel registers.
 *
 * @name   : hardware kernel to be addressed
 * @offset : memory offset of the register to be accessed
 * @cfg    : array of configuration words to be read, one per
 *           equivalent accelerator
 *
 * Return : 0 on success, error code otherwise
 *
 * NOTE : configuration registers need to be handled taking into account
 *        execution priorities.
 *
 *        TMR == (0x1-0xf) > DMR == (0x1-0xf) > Simplex (TMR == 0 && DMR == 0)
 *
 *        The way in which the hardware infrastructure has been implemented
 *        sequences first TMR transactions (in ascending group order), then
 *        DMR transactions (in ascending group order) and finally, Simplex
 *        transactions.
 *
 */
int artico3_kernel_rcfg(const char *name, uint16_t offset, a3data_t *cfg) {
    unsigned num_bytes;
    unsigned int index;
    int ret, naccs;
    struct a3request_t request;
    enum a3func_t type = A3_F_KERNEL_RCFG;

    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return -EBUSY;
    }

    // Write request data
    request.func = A3_F_GET_NACCS;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy arguments
    char *args_ptr = user->channels[index].args;
    // @name
    memcpy(args_ptr, name, strlen(name));
    num_bytes = strlen(name);
    args_ptr[num_bytes++] = '\0';

    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return ret;
    }

    // Store returned naccs
    naccs = ret;

    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return -EBUSY;
    }

    // Write request data
    request.func = type;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy arguments
    // @name
    memcpy(args_ptr, name, strlen(name));
    num_bytes = strlen(name);
    args_ptr[num_bytes++] = '\0';
    // @offset
    memcpy(&(args_ptr[num_bytes]), &offset, sizeof (uint16_t));
    num_bytes += sizeof (uint16_t);

    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return ret;
    }

    // Copy back pass-by-reference arguments
    // @cfg
    memcpy(cfg, &(args_ptr[num_bytes]), naccs * sizeof (a3data_t));

    return ret;
}


/*
 * ARTICo3 allocate buffer memory
 *
 * This function allocates dynamic memory to be used as a buffer between
 * the application and the local memories in the hardware kernels.
 *
 * @size  : amount of memory (in bytes) to be allocated for the buffer
 * @kname : hardware kernel name to associate this buffer with
 * @pname : port name to associate this buffer with
 * @dir   : data direction of the port
 *
 * Return : pointer to allocated memory on success, NULL otherwise
 *
 * NOTE   : the dynamically allocated buffer is mapped via mmap() to a
 *          POSIX shared memory object in the "/dev/shm" tmpfs to make it
 *          accessible from different processes
 *
 * TODO   : implement optimized version using qsort();
 *
 */
void *artico3_alloc(size_t size, const char *kname, const char *pname, enum a3pdir_t dir) {
    int fd, ret;
    unsigned num_bytes;
    unsigned int index, b;
    char *buf_filename = NULL;
    struct a3request_t request;
    struct a3buf_t *buf = NULL;
    enum a3func_t type = A3_F_ALLOC;

    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return NULL;
    }

    // Write request data
    request.func = type;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy arguments
    char *args_ptr = user->channels[index].args;
    // @name
    memcpy(args_ptr, &size, sizeof (size_t));
    num_bytes = sizeof (size_t);
    // @kname
    memcpy(&(args_ptr[num_bytes]), kname, strlen(kname));
    num_bytes += strlen(kname);
    args_ptr[num_bytes++] = '\0';
    // @pname
    memcpy(&(args_ptr[num_bytes]), pname, strlen(pname));
    num_bytes += strlen(pname);
    args_ptr[num_bytes++] = '\0';
    // @dir
    memcpy(&(args_ptr[num_bytes]), &dir, sizeof (enum a3pdir_t));

    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return NULL;
    }
    // Allocate memory for kernel buf configuration
    buf = malloc(sizeof *buf);
    if (!buf) {
        return NULL;
    }

    // Set buf name
    buf->name = malloc(strlen(pname) + 1);
    if (!buf->name) {
        goto err_malloc_buf_name;
    }
    strcpy(buf->name, pname);

    // Set buf size
    buf->size = size;

    // Set buf filename (concatenation of kname and pname)
    buf_filename = malloc(strlen(kname) + strlen(pname) + 1);
    if (!buf_filename) {
        goto err_malloc_buf_filename;
    }
    strcpy(buf_filename, kname);
    strcpy(buf_filename + strlen(kname), pname);

    // Create a shared memory object
    fd = shm_open(buf_filename, O_RDWR, S_IRUSR | S_IWUSR);
    if(fd < 0) {
        goto err_shm_open_mmap_buf_filename;
    }

    // Resize the shared memory object
    ftruncate(fd, buf->size);

    // Allocate memory for application mapped to the shared memory object with mmap()
    buf->data = mmap(0, buf->size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if(buf->data == MAP_FAILED) {
        close(fd);
        goto err_shm_open_mmap_buf_filename;
    }

    // Close shared memory object file descriptor (not needed anymore)
    close(fd);

    // Search for kernel in kernel list
    for (index = 0; index < max_kernels; index++) {
        pthread_mutex_lock(&kernels_mutex);
        if (!kernels[index]) {
            pthread_mutex_unlock(&kernels_mutex);
            continue;
        }
        if (strcmp(kernels[index]->name, kname) == 0) {
            pthread_mutex_unlock(&kernels_mutex);
            break;
        }
        pthread_mutex_unlock(&kernels_mutex);
    }
    if (index == max_kernels) {
        a3_print_error("[artico3u-hw] no kernel found with name \"%s\"\n", kname);
        return NULL;
    }

    // Add port to ports
    b = 0;
    while (kernels[index]->bufs[b] && (b < kernels[index]->membanks)) b++;
    if (b == kernels[index]->membanks) {
        a3_print_error("[artico3u-hw] no empty bank found for buf\n");
        goto err_nobuf;
    }
    kernels[index]->bufs[b] = buf;

    free(buf_filename);

    return buf->data;

err_nobuf:
    munmap(buf->data, buf->size);

err_shm_open_mmap_buf_filename:
    free(buf_filename);

err_malloc_buf_filename:
    free(buf->name);

err_malloc_buf_name:
    free(buf);

    return NULL;
}


/*
 * ARTICo3 release buffer memory
 *
 * This function frees dynamic memory allocated as a buffer between the
 * application and the hardware kernel.
 *
 * @kname : hardware kernel name this buffer is associanted with
 * @pname : port name this buffer is associated with
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_free(const char *kname, const char *pname) {
    unsigned num_bytes;
    unsigned int index, p;
    int ret;
    struct a3request_t request;
    struct a3buf_t *buf = NULL;
    enum a3func_t type = A3_F_FREE;

    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return -EBUSY;
    }

    // Write request data
    request.func = type;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy arguments
    char *args_ptr = user->channels[index].args;
    // @kname
    memcpy(args_ptr, kname, strlen(kname));
    num_bytes = strlen(kname);
    args_ptr[num_bytes++] = '\0';
    // @pname
    memcpy(&(args_ptr[num_bytes]), pname, strlen(pname));
    num_bytes += strlen(pname);
    args_ptr[num_bytes++] = '\0';

    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return ret;
    }

    // Search for kernel in kernel list
    for (index = 0; index < max_kernels; index++) {
        pthread_mutex_lock(&kernels_mutex);
        if (!kernels[index]) {
            pthread_mutex_unlock(&kernels_mutex);
            continue;
        }
        if (strcmp(kernels[index]->name, kname) == 0) {
            pthread_mutex_unlock(&kernels_mutex);
            break;
        }
        pthread_mutex_unlock(&kernels_mutex);
    }
    if (index == max_kernels) {
        a3_print_error("[artico3u-hw] no kernel found with name \"%s\"\n", kname);
        return -ENODEV;
    }

    // Search for port in port lists
    for (p = 0; p < kernels[index]->membanks; p++) {
        if (kernels[index]->bufs[p]) {
            if (strcmp(kernels[index]->bufs[p]->name, pname) == 0) {
                buf = kernels[index]->bufs[p];
                kernels[index]->bufs[p] = NULL;
                break;
            }
        }
    }
    if (p == kernels[index]->membanks) {
        a3_print_error("[artico3u-hw] no port found with name %s\n", pname);
        return -ENODEV;
    }

    // Free application memory
    munmap(buf->data, buf->size);
    free(buf->name);
    free(buf);

    return 0;
}


/*
 * ARTICo3 load accelerator / change accelerator configuration
 *
 * This function loads a hardware accelerator and/or sets its specific
 * configuration.
 *
 * @name  : hardware kernel name
 * @slot  : reconfigurable slot in which the accelerator is to be loaded
 * @tmr   : TMR group ID (0x1-0xf)
 * @dmr   : DMR group ID (0x1-0xf)
 * @force : force reconfiguration even if the accelerator is already present
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_load(const char *name, uint8_t slot, uint8_t tmr, uint8_t dmr, uint8_t force) {
    unsigned num_bytes;
    unsigned int index;
    int ret;
    struct a3request_t request;
    enum a3func_t type = A3_F_LOAD;

    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return -EBUSY;
    }

    // Write request data
    request.func = type;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy arguments
    char *args_ptr = user->channels[index].args;
    // @name
    memcpy(args_ptr, name, strlen(name));
    num_bytes = strlen(name);
    args_ptr[num_bytes++] = '\0';
    // @slot
    memcpy(&(args_ptr[num_bytes]), &slot, sizeof (uint8_t));
    num_bytes += sizeof (uint8_t);
    // @tmr
    memcpy(&(args_ptr[num_bytes]), &tmr, sizeof (uint8_t));
    num_bytes += sizeof (uint8_t);
    // @dmr
    memcpy(&(args_ptr[num_bytes]), &dmr, sizeof (uint8_t));
    num_bytes += sizeof (uint8_t);
    // @force
    memcpy(&(args_ptr[num_bytes]), &force, sizeof (uint8_t));

    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return ret;
    }

    return ret;
}


/*
 * ARTICo3 remove accelerator
 *
 * This function removes a hardware accelerator from a reconfigurable slot.
 *
 * @slot  : reconfigurable slot from which the accelerator is to be removed
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_unload(uint8_t slot) {
    unsigned int index;
    int ret;
    struct a3request_t request;
    enum a3func_t type = A3_F_UNLOAD;

    pthread_mutex_lock(&args_mutex);
    // Search for channel in channel list
    for (index = 0; index < A3_MAXCHANNELS_PER_CLIENT; index++) {
        if (user->channels[index].free == 1) {
            user->channels[index].free = 0;
            break;
        }
    }
    pthread_mutex_unlock(&args_mutex);
    if (index == A3_MAXCHANNELS_PER_CLIENT) {
        a3_print_error("[artico3-hw] no available channel\n");
        return -EBUSY;
    }

    // Write request data
    request.func = type;
    request.user_id = user->user_id;
    request.channel_id = index;

    // Copy arguments
    char *args_ptr = user->channels[index].args;
    // @slot
    memcpy(args_ptr, &slot, sizeof (uint8_t));

    // Make request
    ret = _artico3_send_request(request);
    if (ret < 0){
        a3_print_error("[artico3u-hw] send request failed\n");
        return ret;
    }

    return ret;
}
