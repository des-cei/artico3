/*
 * ARTICo3 user runtime
 *
 * Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date        : August 2017
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
#include <sys/stat.h>

#include <dirent.h>     // DIR, struct dirent, opendir(), readdir(), closedir()
#include <sys/mman.h>   // mmap()
#include <sys/ioctl.h>  // ioctl()
#include <sys/poll.h>   // poll()
#include <sys/socket.h> // socket()
#include <sys/un.h>     // struct sockaddr_un
#include <sys/time.h>   // struct timeval, gettimeofday()

#include "artico3_user.h"
#include "artico3_hw.h"
#include "artico3_dbg.h"

#include <inttypes.h>


// Command request socket path
#define SOCKET_PATH "/tmp/a3d_socket"

/*
 * ARTICo3 global variables
 *
 * @socket_fd             : socket file descriptor (used for attending user application requests)
 *
 * @args_ptr              : socket file descriptor (used for attending user application requests)
 * @args_passing_filename : socket file descriptor (used for attending user application requests)
 * @args_size             : socket file descriptor (used for attending user application requests)
 *
 * @kernels               : socket file descriptor (used for attending user application requests)
 *
 */
static int socket_fd;

char *args_ptr = NULL;
char args_passing_filename[] = "arguments";
int args_size = 150;

static struct a3ukernel_t *kernels[A3_MAXKERNS] = {NULL};


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
 *
 */
int artico3_user_init() {
    int shm_fd, ret;
    struct sockaddr_un socket_addr;

    // Create a shared memory object for arguments passing
    shm_fd = shm_open(args_passing_filename, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
    if(shm_fd < 0) {
        return -ENODEV;
    }

    // Resize the shared memory object
    ftruncate(shm_fd, args_size);

    // Allocate memory for application mapped to the shared memory object with mmap()
    args_ptr = mmap(0, args_size, PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
    if(args_ptr == MAP_FAILED) {
        ret = -ENOMEM;
        close(shm_fd);
        goto err_mmap_args_filename;
    }

    // Close shared memory object file descriptor (not needed anymore)
    close(shm_fd);

    // Initialize the request handling socket (as a UNIX socket)
    socket_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if(socket_fd < 0) {
        a3_print_error("[artico3-hw] socket() failed\n");
        ret = -ENODEV;
        goto err_socket;
    }
    socket_addr.sun_family = AF_UNIX;
    strcpy(socket_addr.sun_path, SOCKET_PATH);
    ret = connect(socket_fd, (struct sockaddr *) &socket_addr, sizeof (struct sockaddr_un));
    if (ret < 0) {
        a3_print_error("[artico3-hw] connect() failed\n");
        ret = -ENODEV;
        goto err_connect_shm_open_args_filename;
    }
    a3_print_debug("[artico3-hw] u socket=%d\n", socket_fd);

    return 0;

err_connect_shm_open_args_filename:
    close(socket_fd);

err_socket:
    munmap(args_ptr, args_size);

err_mmap_args_filename:
    shm_unlink(args_passing_filename);

    return ret;
}


/*
 * ARTICo3 send request
 *
 * This function makes command requests to the ARTICo3 Daemon.
 *
 * Return : 0 on success, error code otherwise
 *
 * NOTE: the received commands are set to 1-byte size, limiting the available commands to 256.
 *
 */
static int _artico3_send_request(uint8_t command) {

    int ack, ret;

    // Send request to ARTICo3 Daemon
    ret = send(socket_fd, &command, sizeof (uint8_t), 0);
    if (ret < 0) {
        a3_print_error("[artico3-hw] u socket send() failed=%d\n", ret);
        return -ENODEV;
    }

    // Receive the return of the requested command
    ret = recv(socket_fd, &ack, sizeof (int), 0);
    if (ret < 0) {
        a3_print_error("[artico3-hw] u socket recv() failed=%d\n", ret);
        return -ENODEV;
    }

    return ack;

}


/*
 * ARTICo3 exit function
 *
 * This function cleans the software entities created by artico3d_init().
 *
 */
void artico3_user_exit() {

    // Indicate a3d to stop accepting requests
    _artico3_send_request(0xffff);

    // Close the request handling socket
    close(socket_fd);

    // Free args passing memory
    munmap(args_ptr, args_size);
    shm_unlink(args_passing_filename);

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
int artico3_user_kernel_create(const char *name, size_t membytes, size_t membanks, size_t regs) {

    enum a3u_funct_t type = A3_F_KERNEL_CREATE;
    unsigned copied_bytes;
    unsigned int index, i;
    struct a3ukernel_t *kernel = NULL;
    int ret;

    // Copy arguments
    memcpy(args_ptr, name, strlen(name));
    copied_bytes = strlen(name);
    args_ptr[copied_bytes++] = '\0';
    memcpy(&(args_ptr[copied_bytes]), &membytes, sizeof (size_t));
    copied_bytes += sizeof (size_t);
    memcpy(&(args_ptr[copied_bytes]), &membanks, sizeof (size_t));
    copied_bytes += sizeof (size_t);
    memcpy(&(args_ptr[copied_bytes]), &regs, sizeof (size_t));

    // Make request
    ret = _artico3_send_request(type);
    if (ret < 0)
        return -1;

    // Search first available ID; if none, return with error
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (kernels[index] == NULL) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] kernel list is already full\n");
        return -EBUSY;
    }

    // Allocate memory for kernel info
    kernel = malloc(sizeof *kernel);
    if (!kernel) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        return -ENOMEM;
    }

    // Set kernel name
    kernel->name = malloc(strlen(name) + 1);
    if (!kernel->name) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_kernel_name;
    }
    strcpy(kernel->name, name);

    // Set kernel configuration
    kernel->membanks = membanks;

    // Initialize kernel ports
    kernel->ports = malloc(membanks * sizeof *kernel->ports);
    if (!kernel->ports) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_kernel_ports;
    }

    // Set initial values for ports
    for (i = 0; i < membanks; i++) {
        kernel->ports[i] = NULL;
    }

    a3_print_debug("[artico3-hw] created kernel (name=%s,membytes=%zd,membanks=%zd,regs=%zd)\n", name, membytes, membanks, regs);

    // Store kernel configuration in kernel list
    kernels[index] = kernel;

    return 0;

err_malloc_kernel_ports:
    free(kernel->name);

err_malloc_kernel_name:
    free(kernel);

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
int artico3_user_kernel_release(const char *name) {

    enum a3u_funct_t type = A3_F_KERNEL_RELEASE;
    unsigned copied_bytes;
    unsigned int index;
    int ret;

    // Copy arguments
    memcpy(args_ptr, name, strlen(name));
    copied_bytes = strlen(name);
    args_ptr[copied_bytes++] = '\0';

    // Make request
    ret = _artico3_send_request(type);
    if (ret < 0)
        return -1;

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (!kernels[index]) continue;
        if (strcmp(kernels[index]->name, name) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name \"%s\"\n", name);
        return -ENODEV;
    }

    // Free allocated memory
    free(kernels[index]->ports);
    free(kernels[index]->name);
    free(kernels[index]);
    a3_print_debug("[artico3-hw] released kernel (name=%s)\n", name);

    // Set kernel list entry as empty
    kernels[index] = NULL;

    return 0;

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
int artico3_user_kernel_execute(const char *name, size_t gsize, size_t lsize) {

    enum a3u_funct_t type = A3_F_KERNEL_EXECUTE;
    unsigned copied_bytes;

    // Copy arguments
    memcpy(args_ptr, name, strlen(name));
    copied_bytes = strlen(name);
    args_ptr[copied_bytes++] = '\0';
    memcpy(&(args_ptr[copied_bytes]), &gsize, sizeof (size_t));
    copied_bytes += sizeof (size_t);
    memcpy(&(args_ptr[copied_bytes]), &lsize, sizeof (size_t));

    // Make request
    return _artico3_send_request(type);

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
int artico3_user_kernel_wait(const char *name) {

    enum a3u_funct_t type = A3_F_KERNEL_WAIT;
    unsigned copied_bytes;

    // Copy arguments
    memcpy(args_ptr, name, strlen(name));
    copied_bytes = strlen(name);
    args_ptr[copied_bytes++] = '\0';

    // Make request
    return _artico3_send_request(type);

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
int artico3_user_kernel_reset(const char *name) {

    enum a3u_funct_t type = A3_F_KERNEL_RESET;
    unsigned copied_bytes;

    // Copy arguments
    memcpy(args_ptr, name, strlen(name));
    copied_bytes = strlen(name);
    args_ptr[copied_bytes++] = '\0';

    // Make request
    return _artico3_send_request(type);

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
int artico3_user_kernel_wcfg(const char *name, uint16_t offset, a3_user_data_t *cfg) {

    enum a3u_funct_t type = A3_F_KERNEL_WCFG;
    unsigned copied_bytes;

    // Copy arguments
    memcpy(args_ptr, name, strlen(name));
    copied_bytes = strlen(name);
    args_ptr[copied_bytes++] = '\0';
    memcpy(&(args_ptr[copied_bytes]), &offset, sizeof (uint16_t));

    // Make request
    return _artico3_send_request(type);

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
int artico3_user_kernel_rcfg(const char *name, uint16_t offset, a3_user_data_t *cfg) {

    enum a3u_funct_t type = A3_F_KERNEL_RCFG;
    unsigned copied_bytes;

    // Copy arguments
    memcpy(args_ptr, name, strlen(name));
    copied_bytes = strlen(name);
    args_ptr[copied_bytes++] = '\0';
    memcpy(&(args_ptr[copied_bytes]), &offset, sizeof (uint16_t));

    // Make request
    return _artico3_send_request(type);

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
void *artico3_user_alloc(size_t size, const char *kname, const char *pname, enum a3_user_pdir_t dir) {

    int fd, ret;
    enum a3u_funct_t type = A3_F_ALLOC;
    struct a3port_t *port = NULL;
    unsigned copied_bytes;
    unsigned int index, p;

    // Copy arguments
    memcpy(args_ptr, &size, sizeof (size_t));
    copied_bytes = sizeof (size_t);
    memcpy(&(args_ptr[copied_bytes]), kname, strlen(kname));
    copied_bytes += strlen(kname);
    args_ptr[copied_bytes++] = '\0';
    memcpy(&(args_ptr[copied_bytes]), pname, strlen(pname));
    copied_bytes += strlen(pname);
    args_ptr[copied_bytes++] = '\0';
    memcpy(&(args_ptr[copied_bytes]), &dir, sizeof (enum a3_user_pdir_t));

    // Make request
    ret = _artico3_send_request(type);
    if (ret < 0)
        return NULL;

    // Allocate memory for kernel port configuration
    port = malloc(sizeof *port);
    if (!port) {
        return NULL;
    }

    // Set port name
    port->name = malloc(strlen(pname) + 1);
    if (!port->name) {
        goto err_malloc_port_name;
    }
    strcpy(port->name, pname);

    // Set port size
    port->size = size;

    // Set port filename (concatenation of kname and pname)
    port->filename = malloc(strlen(kname) + strlen(pname) + 1);
    if (!port->filename) {
        goto err_malloc_port_filename;
    }
    strcpy(port->filename, kname);
    strcpy(port->filename + strlen(kname), pname);

    // Create a shared memory object
    fd = shm_open(port->filename, O_RDWR, S_IRUSR | S_IWUSR);
    if(fd < 0) {
        goto err_shm_open_mmap_port_filename;
    }

    // Resize the shared memory object
    ftruncate(fd, port->size);

    // Allocate memory for application mapped to the shared memory object with mmap()
    port->data = mmap(0, port->size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if(port->data == MAP_FAILED) {
        close(fd);
        goto err_shm_open_mmap_port_filename;
    }

    // Close shared memory object file descriptor (not needed anymore)
    close(fd);

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (!kernels[index]) continue;
        if (strcmp(kernels[index]->name, kname) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name \"%s\"\n", kname);
        return NULL;
    }

    // Add port to ports
    p = 0;
    while (kernels[index]->ports[p] && (p < kernels[index]->membanks)) p++;
    if (p == kernels[index]->membanks) {
        a3_print_error("[artico3-hw] no empty bank found for port\n");
        goto err_noport;
    }
    kernels[index]->ports[p] = port;

    return port->data;

err_noport:
    munmap(port->data, port->size);

err_shm_open_mmap_port_filename:
    free(port->filename);

err_malloc_port_filename:
    free(port->name);

err_malloc_port_name:
    free(port);

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
int artico3_user_free(const char *kname, const char *pname) {

    int ret;
    enum a3u_funct_t type = A3_F_FREE;
    unsigned copied_bytes;
    unsigned int index, p;
    struct a3port_t *port = NULL;

    // Copy arguments
    memcpy(args_ptr, kname, strlen(kname));
    copied_bytes = strlen(kname);
    args_ptr[copied_bytes++] = '\0';
    memcpy(&(args_ptr[copied_bytes]), pname, strlen(pname));
    copied_bytes += strlen(pname);
    args_ptr[copied_bytes++] = '\0';

    // Make request
    ret = _artico3_send_request(type);
    if (ret < 0)
        return -1;

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (!kernels[index]) continue;
        if (strcmp(kernels[index]->name, kname) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name \"%s\"\n", kname);
        return -ENODEV;
    }

    // Search for port in port lists
    for (p = 0; p < kernels[index]->membanks; p++) {
        if (kernels[index]->ports[p]) {
            if (strcmp(kernels[index]->ports[p]->name, pname) == 0) {
                port = kernels[index]->ports[p];
                kernels[index]->ports[p] = NULL;
                break;
            }
        }
    }
    if (p == kernels[index]->membanks) {
        a3_print_error("[artico3-hw] no port found with name %s\n", pname);
        return -ENODEV;
    }

    // Free application memory
    munmap(port->data, port->size);
    free(port->filename);
    free(port->name);
    free(port);

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
int artico3_user_load(const char *name, uint8_t slot, uint8_t tmr, uint8_t dmr, uint8_t force) {

    enum a3u_funct_t type = A3_F_LOAD;
    unsigned copied_bytes;

    // Copy arguments
    memcpy(args_ptr, name, strlen(name));
    copied_bytes = strlen(name);
    args_ptr[copied_bytes++] = '\0';
    memcpy(&(args_ptr[copied_bytes]), &slot, sizeof (uint8_t));
    copied_bytes += sizeof (uint8_t);
    memcpy(&(args_ptr[copied_bytes]), &tmr, sizeof (uint8_t));
    copied_bytes += sizeof (uint8_t);
    memcpy(&(args_ptr[copied_bytes]), &dmr, sizeof (uint8_t));
    copied_bytes += sizeof (uint8_t);
    memcpy(&(args_ptr[copied_bytes]), &force, sizeof (uint8_t));

    // Make request
    return _artico3_send_request(type);

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
int artico3_user_unload(uint8_t slot) {

    enum a3u_funct_t type = A3_F_UNLOAD;
    unsigned copied_bytes;

    // Copy arguments
    memcpy(args_ptr, &slot, sizeof (uint8_t));

    // Make request
    return _artico3_send_request(type);

}
