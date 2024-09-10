/*
 * ARTICo3 daemon
 *
 * Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 *               Juan Encinas <juan.encinas@upm.es>
 * Date        : May 2024
 * Description : This file contains the ARTICo3 daemon, which enables
 *               user applications to get access to adaptive
 *               hardware acceleration.
 *
 */


#ifndef _ARTICO3D_H_
#define _ARTICO3D_H_

#include <stdlib.h> // size_t
#include <stdint.h> // uint32_t

#include "artico3_data.h"

#define A3_MAXUSERS (10)  // Max number of simultaneous ARTTCo3 users

/*
 * SYSTEM INITIALIZATION
 *
 */

/*
 * ARTICo3 init function
 *
 * This function sets up the basic software entities required to manage
 * the ARTICo3 low-level functionality (DMA transfers, kernel and slot
 * distributions, etc.).
 *
 * It also loads the FPGA with the initial bitstream (static system).
 *
 * Return : 0 on success, error code otherwise
 */
int artico3_init();


/*
 * ARTICo3 exit function
 *
 * This function cleans the software entities created by artico3_init().
 *
 */
void artico3_exit();

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
 * @args      : buffer storing the function arguments sent by the user
 *     @name  : hardware kernel name
 *     @slot  : reconfigurable slot in which the accelerator is to be loaded
 *     @tmr   : TMR group ID (0x1-0xf)
 *     @dmr   : DMR group ID (0x1-0xf)
 *     @force : force reconfiguration even if the accelerator is already present
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_load(void *args);


/*
 * ARTICo3 remove accelerator
 *
 * This function removes a hardware accelerator from a reconfigurable slot.
 *
 * @args      : buffer storing the function arguments sent by the user
 *     @slot  : reconfigurable slot from which the accelerator is to be removed
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_unload(void *args);


/*
 * ARTICo3 add new user
 *
 * This function creates the software entities required to manage a new user.
 *
 * @args             : buffer storing the function arguments sent by the user
 *     @shm_filename : user shared memory object filename
 *
 * TODO: create folders and subfolders on /dev/shm for each user and its data (kernels, inputs, etc.)
 *
 * Return : A3_MAXKERNS on success, error code otherwise
 */
int artico3_add_user(void *args);


/*
 * ARTICo3 remove existing user
 *
 * This function cleans the software entities created by artico3_add_user().
 *
 * @args           : buffer storing the function arguments sent by the user
 *     @user_id    : ID of the user to be removed
 *     @channel_id : ID of the channel used for handling daemon/user communication
 *
 */
int artico3_remove_user(void *args);


/*
 * ARTICo3 wait user hardware-acceleration request
 *
 * This function waits a command request from user.
 *
 * TODO: improve the termination mechanism
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_handle_request();


/*
 * KERNEL MANAGEMENT
 *
 */

/*
 * ARTICo3 create hardware kernel
 *
 * This function creates an ARTICo3 kernel in the current application.
 *
 * @args         : buffer storing the function arguments sent by the user
 *     @name     : name of the hardware kernel to be created
 *     @membytes : local memory size (in bytes) of the associated accelerator
 *     @membanks : number of local memory banks in the associated accelerator
 *     @regs     : number of read/write registers in the associated accelerator
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_kernel_create(void *args);


/*
 * ARTICo3 release hardware kernel
 *
 * This function deletes an ARTICo3 kernel in the current application.
 *
 * @args     : buffer storing the function arguments sent by the user
 *     @name : name of the hardware kernel to be deleted
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_kernel_release(void *args);


/*
 * ARTICo3 execute hardware kernel
 *
 * This function executes an ARTICo3 kernel in the current application.
 *
 * @args      : buffer storing the function arguments sent by the user
 *     @name  : name of the hardware kernel to execute
 *     @gsize : global work size (total amount of work to be done)
 *     @lsize : local work size (work that can be done by one accelerator)
 *
 * Return : 0 on success, error code otherwisw
 *
 */
int artico3_kernel_execute(void *args);


/*
 * ARTICo3 wait for kernel completion
 *
 * This function waits until the kernel has finished.
 *
 * @args     : buffer storing the function arguments sent by the user
 *     @name : hardware kernel to wait for
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_kernel_wait(void *args);


/*
 * ARTICo3 reset hardware kernel
 *
 * This function resets all hardware accelerators of a given kernel.
 *
 * @args     : buffer storing the function arguments sent by the user
 *     @name : hardware kernel to reset
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_kernel_reset(void *args);


/*
 * ARTICo3 configuration register write
 *
 * This function writes configuration data to ARTICo3 kernel registers.
 *
 * @args       : buffer storing the function arguments sent by the user
 *     @name   : hardware kernel to be addressed
 *     @offset : memory offset of the register to be accessed
 *     @cfg    : array of configuration words to be written, one per
 *               equivalent accelerator
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
int artico3_kernel_wcfg(void *args);


/*
 * ARTICo3 configuration register read
 *
 * This function reads configuration data from ARTICo3 kernel registers.
 *
 * @args       : buffer storing the function arguments sent by the user
 *     @name   : hardware kernel to be addressed
 *     @offset : memory offset of the register to be accessed
 *     @cfg    : array of configuration words to be read, one per
 *               equivalent accelerator
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
int artico3_kernel_rcfg(void *args);


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
 * @args      : buffer storing the function arguments sent by the user
 *     @size  : amount of memory (in bytes) to be allocated for the buffer
 *     @kname : hardware kernel name to associate this buffer with
 *     @pname : port name to associate this buffer with
 *     @dir   : data direction of the port
 *
 * Return : pointer to allocated memory on success, NULL otherwise
 *
 * NOTE   : the dynamically allocated buffer is mapped via mmap() to a
 *          POSIX shared memory object in the "/dev/shm" tmpfs to make it
 *          accessible from different processes
 *
 * TODO   : implement optimized version using qsort();
 * TODO   : create folders and subfolders on /dev/shm for each user and its data (kernels, inputs, etc.)
 *
 */
int artico3_alloc(void *args);


/*
 * ARTICo3 release buffer memory
 *
 * This function frees dynamic memory allocated as a buffer between the
 * application and the hardware kernel.
 *
 * @args      : buffer storing the function arguments sent by the user
 *     @kname : hardware kernel name this buffer is associanted with
 *     @pname : port name this buffer is associated with
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_free(void *args);


/*
 * ARTICo3 get number of accelerators
 *
 * This function gets the current number of available hardware accelerators
 * for a given kernel ID tag.
 *
 * @args      : buffer storing the function arguments sent by the user
 *     @name  : name of the hardware kernel to get the naccs from
 *
 * Return : number of accelerators on success, error code otherwise
 *
 */
int artico3_get_naccs(void *args);


/*
 * ARTICo3 data reinterpretation: float to a3data_t (32 bits)
 *
 */
static inline a3data_t ftoa3(float f) {
    union { float f; a3data_t u; } un;
    un.f = f;
    return un.u;
}


/*
 * ARTICo3 data reinterpretation: a3data_t to float (32 bits)
 *
 */
static inline float a3tof(a3data_t u) {
    union { float f; a3data_t u; } un;
    un.u = u;
    return un.f;
}


/*
 * PERFORMANCE MONITORING COUNTERS
 *
 */

// Documentation for these functions can be found in artico3_hw.h
extern uint32_t artico3_hw_get_pmc_cycles(uint8_t slot);
extern uint32_t artico3_hw_get_pmc_errors(uint8_t slot);

#endif /* _ARTICO3_H_ */
