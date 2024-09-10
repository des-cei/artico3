/*
 * ARTICo3 shared data structures
 *
 * Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 *               Juan Encinas <juan.encinas@upm.es>
 * Date        : Jun 2024
 * Description : This file contains data structures and definitions
 *               shared between the daemon and the user.
 *
 */


#ifndef _ARTICO3_DATA_H_
#define _ARTICO3_DATA_H_

#include <stdint.h>  // uint32_t
#include <pthread.h> // pthread_mutex_t, pthread_cond_t

// TODO: COMMENT
#define A3_ARGS_SIZE              (100) // Size of the request input arguments shared memory object
#define A3_MAXCHANNELS_PER_CLIENT (10)  // Max number of simultaneous execution threads per user
#define A3_COORDINATOR_FILENAME   "a3d" // Coordinator shared memory object filename

/*
 * ARTICo3 data type
 *
 * This is the main data type to be used when creating buffers between
 * user applications and ARTICo3 hardware kernels. All variables to be
 * sent/received need to be declared as pointers to this type.
 *
 *     a3data_t *myconst  = artico3_alloc(size, kname, pname, A3_P_C);
 *     a3data_t *myinput  = artico3_alloc(size, kname, pname, A3_P_I);
 *     a3data_t *myoutput = artico3_alloc(size, kname, pname, A3_P_O);
 *     a3data_t *myinout  = artico3_alloc(size, kname, pname, A3_P_IO);
 *
 */
typedef uint32_t a3data_t;


/*
 * ARTICo3 port direction
 *
 * A3_P_C  - ARTICo3 Constant Input Port
 * A3_P_I  - ARTICo3 Input Port
 * A3_P_O  - ARTICo3 Output Port
 * A3_P_IO - ARTICo3 Output Port
 *
 */
enum a3pdir_t {A3_P_C, A3_P_I, A3_P_O, A3_P_IO};


/*
 * ARTICo3 function type
 *
 * balblabla
 *
 */
typedef int (*a3func_t)(void*);


/*
 * ARTICo3 function IDs
 *
 * A3_F_ADD_USER       - ARTICo3 artico3_add_user() Function
 * A3_F_LOAD           - ARTICo3 artico3_load() Function
 * A3_F_UNLOAD         - ARTICo3 artico3_unload() Function
 * A3_F_KERNEL_CREATE  - ARTICo3 artico3_kernel_create() Function
 * A3_F_KERNEL_RELEASE - ARTICo3 artico3_kernel_release() Function
 * A3_F_KERNEL_EXECUTE - ARTICo3 artico3_kernel_execute() Function
 * A3_F_KERNEL_WAIT    - ARTICo3 artico3_kernel_wait() Function
 * A3_F_KERNEL_RESET   - ARTICo3 artico3_kernel_reset() Function
 * A3_F_KERNEL_WCFG    - ARTICo3 artico3_kernel_wcfg() Function
 * A3_F_KERNEL_RCFG    - ARTICo3 artico3_kernel_wcfg() Function
 * A3_F_ALLOC          - ARTICo3 artico3_alloc() Function
 * A3_F_FREE           - ARTICo3 artico3_free() Function
 * A3_F_REMOVE_USER    - ARTICo3 artico3_remove_user() Function
 * A3_F_GET_NACCS      - ARTICo3 artico3_get_naccs() Function
 *
 */
enum a3func_t {
    A3_F_ADD_USER,
    A3_F_LOAD,
    A3_F_UNLOAD,
    A3_F_KERNEL_CREATE,
    A3_F_KERNEL_RELEASE,
    A3_F_KERNEL_EXECUTE,
    A3_F_KERNEL_WAIT,
    A3_F_KERNEL_RESET,
    A3_F_KERNEL_WCFG,
    A3_F_KERNEL_RCFG,
    A3_F_ALLOC,
    A3_F_FREE,
    A3_F_REMOVE_USER,
    A3_F_GET_NACCS
};


/*
 * ARTICo3 request
 *
 * @user_id    : ID of the user quering the request
 * @channel_id : ID of the channel used for handling the request
 * @func       : function requested by the user
 * @shm        : user shared memory data filename (only used on new users)
 *
 */
struct a3request_t {
    int user_id;
    int channel_id;
    enum a3func_t func;
    char shm[13];
};


/*
 * ARTICo3 channel (each channel handles a single request)
 *
 * @mutex              : synchronization primitive for accessing @request_available
 * @cond_response      : processed user request signaling conditional variable
 * @response_available : processed user request signaling flag
 * @response           : processed user request response
 * @free               : channel free flag
 * @args               : user request input arguments buffer
 *
 */
struct a3channel_t {
    pthread_mutex_t mutex;
    pthread_cond_t cond_response;
    int response_available;
    int response;
    int free;
    char args[A3_ARGS_SIZE];
};


/*
 * ARTICo3 (user data and its channels data )
 *
 * @user_id  : ID of the user quering the request
 * @channels : user threads to handle user request queries
 * @shm      : user shared memory data filename
 *
 */
struct a3user_t {
    int user_id;
    struct a3channel_t channels[A3_MAXCHANNELS_PER_CLIENT];
    char shm[13];
};


/*
 * ARTICo3 coordinator (orchestrates every users/daemon requests)
 *
 * @mutex             : synchronization primitive for accessing @request_available
 * @cond_request      : user request signaling conditional variable
 * @cond_free         : conditional variable indicating users the coordinator is free
 * @request_available : user request signaling flag
 * @request           : user request info
 *
 */
struct a3coordinator_t {
    pthread_mutex_t mutex;
    pthread_cond_t cond_request;
    pthread_cond_t cond_free;
    int request_available;
    struct a3request_t request;
};

#endif /* _ARTICO3_DATA_H_ */