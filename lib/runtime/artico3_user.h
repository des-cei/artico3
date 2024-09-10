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
 * TODO: implement query function to ask info to the daemon (A3U_MAXSLOTS, etc.)
 *
 */


#ifndef _artico3_USER_H_
#define _artico3_USER_H_

#include <stdlib.h> // size_t
#include <stdint.h> // uint32_t

#define A3U_ARGS_SIZE              (100) // Size of the request input arguments shared memory object
#define A3U_MAXCHANNELS_PER_CLIENT (10)  // Max number of simultaneous execution threads per user
#define A3U_COORDINATOR_FILENAME   "a3d" // Coordinator shared memory object filename
#define A3U_MAXSLOTS               (16)  // Number of slots available

/*
 * ARTICo3 data type
 *
 * This is the main data type to be used when creating buffers between
 * user applications and ARTICo3 hardware kernels. All variables to be
 * sent/received need to be declared as pointers to this type.
 *
 *     a3data_t *myconst  = artico3_user_alloc(size, kname, pname, A3_P_C);
 *     a3data_t *myinput  = artico3_user_alloc(size, kname, pname, A3_P_I);
 *     a3data_t *myoutput = artico3_user_alloc(size, kname, pname, A3_P_O);
 *     a3data_t *myinout  = artico3_user_alloc(size, kname, pname, A3_P_IO);
 *
 */
typedef uint32_t a3_user_data_t;


/*
 * ARTICo3 port direction
 *
 * A3_P_C  - ARTICo3 Constant Input Port
 * A3_P_I  - ARTICo3 Input Port
 * A3_P_O  - ARTICo3 Output Port
 * A3_P_IO - ARTICo3 Output Port
 *
 */
enum a3_user_pdir_t {A3U_P_C, A3U_P_I, A3U_P_O, A3U_P_IO};


/*
 * ARTICo3 kernel (hardware accelerator)
 *
 * @name     : kernel name
 * @membanks : number of local memory banks inside kernel
 * @ports   : port configuration for this kernel
 *
 */
struct a3ukernel_t {
    char *name;
    size_t membanks;
    struct a3port_t **ports;
};


/*
 * ARTICo3 function IDs
 *
 * A3U_F_ADD_USER       - ARTICo3 artico3_add_user() Function
 * A3U_F_LOAD           - ARTICo3 artico3_load() Function
 * A3U_F_UNLOAD         - ARTICo3 artico3_unload() Function
 * A3U_F_KERNEL_CREATE  - ARTICo3 artico3_kernel_create() Function
 * A3U_F_KERNEL_RELEASE - ARTICo3 artico3_kernel_release() Function
 * A3U_F_KERNEL_EXECUTE - ARTICo3 artico3_kernel_execute() Function
 * A3U_F_KERNEL_WAIT    - ARTICo3 artico3_kernel_wait() Function
 * A3U_F_KERNEL_RESET   - ARTICo3 artico3_kernel_reset() Function
 * A3U_F_KERNEL_WCFG    - ARTICo3 artico3_kernel_wcfg() Function
 * A3U_F_KERNEL_RCFG    - ARTICo3 artico3_kernel_wcfg() Function
 * A3U_F_ALLOC          - ARTICo3 artico3_alloc() Function
 * A3U_F_FREE           - ARTICo3 artico3_free() Function
 * A3U_F_REMOVE_USER    - ARTICo3 artico3_remove_user() Function
 *
 */
enum a3ufunc_t {
    A3U_F_ADD_USER,
    A3U_F_LOAD,
    A3U_F_UNLOAD,
    A3U_F_KERNEL_CREATE,
    A3U_F_KERNEL_RELEASE,
    A3U_F_KERNEL_EXECUTE,
    A3U_F_KERNEL_WAIT,
    A3U_F_KERNEL_RESET,
    A3U_F_KERNEL_WCFG,
    A3U_F_KERNEL_RCFG,
    A3U_F_ALLOC,
    A3U_F_FREE,
    A3U_F_REMOVE_USER
};


/*
 * ARTICo3 user request
 *
 * @user_id    : ID of the user quering the request
 * @channel_id : ID of the channel used for handling the request
 * @func       : function requested by the user
 * @shm        : user shared memory data filename (only used on new users)
 *
 */
struct a3urequest_t {
    int user_id;
    int channel_id;
    enum a3ufunc_t func;
    char shm[13];
};


/*
 * ARTICo3 user channel (each channel handles a single request)
 *
 * @mutex              : synchronization primitive for accessing @request_available
 * @cond_response      : processed user request signaling conditional variable
 * @response_available : processed user request signaling flag
 * @response           : processed user request response
 * @free               : channel free flag
 * @args               : user request input arguments buffer
 *
 */
struct a3uchannel_t {
    pthread_mutex_t mutex;
    pthread_cond_t cond_response;
    int response_available;
    int response;
    int free;
    char args[A3U_ARGS_SIZE];
};


/*
 * ARTICo3 user (user data and its channels data )
 *
 * @user_id  : ID of the user quering the request
 * @channels : user threads to handle user request queries
 * @shm      : user shared memory data filename
 *
 */
struct a3uuser_t {
    int user_id;
    struct a3uchannel_t channels[A3U_MAXCHANNELS_PER_CLIENT];
    char shm[13];
};


/*
 * ARTICo3 coordinator (orchestrates every users/daemon requests)
 *
 * @mutex             : synchronization primitive for accessing @request_available
 * @cond_request      : user request signaling conditional variable
 * @request_available : user request signaling flag
 * @request           : user request info
 *
 */
struct a3ucoordinator_t {
    pthread_mutex_t mutex;
    pthread_cond_t cond_request;
    int request_available;
    struct a3urequest_t request;
};

/*
 * SYSTEM INITIALIZATION
 *
 */

/*
 * ARTICo3 user init function
 *
 * This function sets up the basic software entities required to interact
 * with the Daemon (kernel distribbution, shared memory objects, synchronization
 * primitives, etc.).
 *
 * It also loads the FPGA with the initial bitstream (static system).
 *
 * TODO: Get the tid as an argument from the user to make it user-dependant and not thread-dependant
 *
 * NOTE: This will not return if the shm filename chosen in already in use.
 *       It is done this way since there is no mechanism for new users to receive response from a3d.
 *       A timeout when shm filename already in use could be a solution.
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_user_init();


/*
 * ARTICo3 user exit function
 *
 * This function cleans the software entities created by artico3_user_init().
 *
 */
int artico3_user_exit();


/*
 * SYSTEM MANAGEMENT
 *
 */

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
int artico3_user_load(const char *name, uint8_t slot, uint8_t tmr, uint8_t dmr, uint8_t force);


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
int artico3_user_unload(uint8_t slot);


/*
 * KERNEL MANAGEMENT
 *
 */

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
int artico3_user_kernel_create(const char *name, size_t membytes, size_t membanks, size_t regs);


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
int artico3_user_kernel_release(const char *name);


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
int artico3_user_kernel_execute(const char *name, size_t gsize, size_t lsize);


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
int artico3_user_kernel_wait(const char *name);


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
int artico3_user_kernel_reset(const char *name);


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
int artico3_user_kernel_wcfg(const char *name, uint16_t offset, a3_user_data_t *cfg);


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
int artico3_user_kernel_rcfg(const char *name, uint16_t offset, a3_user_data_t *cfg);


/*
 * MEMORY MANAGEMENT
 *
 * In the current version of the runtime library, the distribution of the
 * memory banks inside an ARTICo3 kernel is as follows:
 *
 *                                          I/O examples
 *                              3/1     2/2     1/3     3/3     4/4
 *
 *     ----------               i       i       i       i       i  o
 *     0000                     |       |       |       |       |  |
 *     ...         Bank 0       |       |       |       |       |  |
 *     03ff                     |       |       |       |       |  |
 *     ----------               |       |       v  o    |  o    |  |
 *     0400                     |       |          |    |  |    |  |
 *     ...         Bank 1       |       |          |    |  |    |  |
 *     07ff                     |       |          |    |  |    |  |
 *     ----------               |       v  o       |    |  |    |  |
 *     0800                     |          |       |    |  |    |  |
 *     ...         Bank 2       |          |       |    |  |    |  |
 *     0bff                     |          |       |    |  |    |  |
 *     ----------               v  o       |       |    v  |    |  |
 *     0c00                        |       |       |       |    |  |
 *     ...         Bank 3          |       |       |       |    |  |
 *     1000                        |       |       |       |    |  |
 *     ----------                  v       v       v       v    v  v
 *
 * This means that bank allocation/distribution starts at the lower index
 * for input ports, and at the higher index for output ports. This can be
 * seen in the first example, where 3 input and 1 output bank are required
 * (the runtime uses banks 0, 1 and 2 as inputs, and 3 as output). Notice
 * that bidirectional ports are supported, even though they are discouraged
 * because memory banks are implemented as single-port BRAMS and therefore
 * the performance would be decreased due to memory bottlenecks.
 *
 * IMPORTANT: memory bank allocation is performed automatically by the
 *            runtime library and therefore, users cannot explicitly
 *            specify which bank to use for which input/output port.
 *            Hence, if the kernel has been designed in HDL, users need
 *            to access the memory banks accordingly.
 *
 */

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
void *artico3_user_alloc(size_t size, const char *kname, const char *pname, enum a3_user_pdir_t dir);


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
int artico3_user_free(const char *kname, const char *pname);


/*
 * ARTICo3 data reinterpretation: float to a3data_t (32 bits)
 *
 */
static inline a3_user_data_t ftoa3u(float f) {
    union { float f; a3_user_data_t u; } un;
    un.f = f;
    return un.u;
}


/*
 * ARTICo3 data reinterpretation: a3data_t to float (32 bits)
 *
 */
static inline float a3utof(a3_user_data_t u) {
    union { float f; a3_user_data_t u; } un;
    un.u = u;
    return un.f;
}


/*
 * PERFORMANCE MONITORING COUNTERS
 *
 */

// Documentation for these functions can be found in artico3_user_hw.h
extern uint32_t artico3_user_hw_get_pmc_cycles(uint8_t slot);
extern uint32_t artico3_user_hw_get_pmc_errors(uint8_t slot);

#endif /* _artico3_USER_H_ */
