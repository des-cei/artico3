/*
 * ARTICo3 runtime API
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

#include <dirent.h>    // DIR, struct dirent, opendir(), readdir(), closedir()
#include <sys/mman.h>  // mmap()
#include <sys/ioctl.h> // ioctl()
#include <sys/poll.h>  // poll()
#include <sys/time.h>  // struct timeval, gettimeofday()

#include "drivers/artico3/artico3.h"
#include "artico3.h"
#include "artico3_hw.h"
#include "artico3_rcfg.h"
#include "artico3_dbg.h"

#include <inttypes.h>


/*
 * ARTICo3 global variables
 *
 * @artico3_hw : user-space map of ARTICo3 hardware registers
 * @artico3_fd : /dev/artico3 file descriptor (used to access kernels)
 *
 * @shuffler   : current ARTICo3 infrastructure configuration
 * @kernels    : current kernel list
 *
 * @threads    : array of delegate scheduling threads
 * @mutex      : synchronization primitive for accessing @running
 * @running    : number of hardware kernels currently running (write/run/read)
 *
 */
static int artico3_fd;
uint32_t *artico3_hw = NULL;

struct a3shuffler_t shuffler = {
    .id_reg      = 0x0000000000000000,
    .tmr_reg     = 0x0000000000000000,
    .dmr_reg     = 0x0000000000000000,
    .blksize_reg = 0x00000000,
    .clkgate_reg = 0x00000000,
    .nslots      = 0,
    .slots       = NULL,
};
static struct a3kernel_t **kernels = NULL;

static pthread_t *threads = NULL;
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
static int running = 0;


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
int artico3_init() {
    const char *filename = "/dev/artico3";
    unsigned int i;
    int ret;

    /*
     * NOTE: this function relies on predefined addresses for both control
     *       and data interfaces of the ARTICo3 infrastructure.
     *       If the processor memory map is changed somehow, this has to
     *       be reflected in this file.
     *
     *       Zynq-7000 Devices
     *       ARTICo3 Control -> 0x7aa00000
     *       ARTICo3 Data    -> 0x8aa00000
     *
     *       Zynq UltraScale+ MPSoC Devices
     *       ARTICo3 Control -> 0xa0000000
     *       ARTICo3 Data    -> 0xb0000000
     *
     */

    // Load static system (global FPGA reconfiguration)
    fpga_load("system.bin", 0);

    // Open ARTICo3 device file
    artico3_fd = open(filename, O_RDWR);
    if (artico3_fd < 0) {
        a3_print_error("[artico3-hw] open() %s failed\n", filename);
        return -ENODEV;
    }
    a3_print_debug("[artico3-hw] artico3_fd=%d | dev=%s\n", artico3_fd, filename);

    // Obtain access to physical memory map using mmap()
    artico3_hw = mmap(NULL, 0x100000, PROT_READ | PROT_WRITE, MAP_SHARED, artico3_fd, 0);
    if (artico3_hw == MAP_FAILED) {
        a3_print_error("[artico3-hw] mmap() failed\n");
        ret = -ENOMEM;
        goto err_mmap;
    }
    a3_print_debug("[artico3-hw] artico3_hw=%p\n", artico3_hw);

    // Get maximum number of ARTICo3 slots in the platform
    shuffler.nslots = artico3_hw_get_nslots();
    if (shuffler.nslots == 0) {
        a3_print_error("[artico3-hw] firmware read (number of slots) failed\n");
        ret = -ENODEV;
        goto err_malloc_slots;
    }

    // Initialize Shuffler structure (software)
    shuffler.slots = malloc(shuffler.nslots * sizeof (struct a3slot_t));
    if (!shuffler.slots) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_slots;
    }
    for (i = 0; i < shuffler.nslots; i++) {
        shuffler.slots[i].kernel = NULL;
        shuffler.slots[i].state = S_EMPTY;
    }
    a3_print_debug("[artico3-hw] shuffler.slots=%p\n", shuffler.slots);

    // Initialize kernel list (software)
    kernels = malloc(A3_MAXKERNS * sizeof **kernels);
    if (!kernels) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_kernels;
    }
    for (i = 0; i < A3_MAXKERNS; i++) {
        kernels[i] = NULL;
    }
    a3_print_debug("[artico3-hw] kernels=%p\n", kernels);

    // Initialize delegate threads
    threads = malloc(A3_MAXKERNS * sizeof *threads);
    if (!threads) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_threads;
    }
    for (i = 0; i < A3_MAXKERNS; i++) {
        threads[i] = 0;
    }
    a3_print_debug("[artico3-hw] threads=%p\n", threads);

    // Enable clocks in reconfigurable region
    artico3_hw_enable_clk();

    // Print ARTICo3 control registers
    artico3_hw_print_regs();

    return 0;

err_malloc_threads:
    free(kernels);

err_malloc_kernels:
    free(shuffler.slots);

err_malloc_slots:
    munmap(artico3_hw, 0x100000);

err_mmap:
    close(artico3_fd);

    return ret;
}


/*
 * ARTICo3 exit function
 *
 * This function cleans the software entities created by artico3_init().
 *
 */
void artico3_exit() {

    // Print ARTICo3 control registers
    artico3_hw_print_regs();

    // Disable clocks in reconfigurable region
    artico3_hw_disable_clk();

    // Release allocated memory for delegate threads
    free(threads);

    // Release allocated memory for kernel list
    free(kernels);

    // Release allocated memory for slot info
    free(shuffler.slots);

    // Release memory obtained with mmap()
    munmap(artico3_hw, 0x100000);

    // Close ARTICo3 device file
    close(artico3_fd);

    // Restore Data Shuffler structure
    shuffler.id_reg      = 0x0000000000000000;
    shuffler.tmr_reg     = 0x0000000000000000;
    shuffler.dmr_reg     = 0x0000000000000000;
    shuffler.blksize_reg = 0x00000000;
    shuffler.clkgate_reg = 0x00000000;
    shuffler.nslots      = 0;
    shuffler.slots       = NULL;

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
    unsigned int index, i;
    struct a3kernel_t *kernel = NULL;
    int ret;

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
    kernel->id = index + 1;
    kernel->membytes = ceil(((float)membytes / (float)membanks) / sizeof (a3data_t)) * sizeof (a3data_t) * membanks; // Fix to ensure all banks have integer number of 32-bit words
    kernel->membanks = membanks;
    kernel->regs = regs;

    // Initialize kernel constant memory inputs
    kernel->c_loaded = 0;
    kernel->consts = malloc(membanks * sizeof *kernel->consts);
    if (!kernel->consts) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_kernel_consts;
    }

    // Initialize kernel inputs
    kernel->inputs = malloc(membanks * sizeof *kernel->inputs);
    if (!kernel->inputs) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_kernel_inputs;
    }

    // Initialize kernel outputs
    kernel->outputs = malloc(membanks * sizeof *kernel->outputs);
    if (!kernel->outputs) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_kernel_outputs;
    }

    // Initialize kernel bidirectional I/O ports
    kernel->inouts = malloc(membanks * sizeof *kernel->inouts);
    if (!kernel->inouts) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_kernel_inouts;
    }

    // Set initial values for inputs and outputs
    for (i = 0; i < kernel->membanks; i++) {
        kernel->consts[i] = NULL;
        kernel->inputs[i] = NULL;
        kernel->outputs[i] = NULL;
        kernel->inouts[i] = NULL;
    }

    a3_print_debug("[artico3-hw] created kernel (name=%s,id=%x,membytes=%d,membanks=%d,regs=%d)\n", kernel->name, kernel->id, kernel->membytes, kernel->membanks, kernel->regs);

    // Store kernel configuration in kernel list
    kernels[index] = kernel;

    return 0;

err_malloc_kernel_inouts:
    free(kernel->outputs);

err_malloc_kernel_outputs:
    free(kernel->inputs);

err_malloc_kernel_inputs:
    free(kernel->consts);

err_malloc_kernel_consts:
    free(kernel->name);

err_malloc_kernel_name:
    free(kernel);

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
    unsigned int index, slot;

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (!kernels[index]) continue;
        if (strcmp(kernels[index]->name, name) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name \"%s\"\n", name);
        return -ENODEV;
    }

    // Update ARTICo3 slot info
    for (slot = 0; slot < shuffler.nslots; slot++) {
        if (shuffler.slots[slot].state != S_EMPTY) {
            if (shuffler.slots[slot].kernel == kernels[index]) {
                shuffler.slots[slot].state = S_EMPTY;
                shuffler.slots[slot].kernel = NULL;
            }
        }
    }

    // Free allocated memory
    free(kernels[index]->inouts);
    free(kernels[index]->outputs);
    free(kernels[index]->inputs);
    free(kernels[index]->consts);
    free(kernels[index]->name);
    free(kernels[index]);
    a3_print_debug("[artico3-hw] released kernel (name=%s)\n", name);

    // Set kernel list entry as empty
    kernels[index] = NULL;

    return 0;
}


/*
 * ARTICo3 start hardware kernel
 *
 * This function starts all hardware accelerators of a given kernel.
 *
 * NOTE: only the runtime can call this function, using it from user
 *       applications is forbidden (and not possible due to the static
 *       specifier).
 *
 * @name : hardware kernel to start
 *
 * Return : 0 on success, error code otherwise
 *
 */
static int _artico3_kernel_start(const char *name) {
    unsigned int index;
    uint8_t id;

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (!kernels[index]) continue;
        if (strcmp(kernels[index]->name, name) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name \"%s\"\n", name);
        return -ENODEV;
    }

    // Get kernel id
    id = kernels[index]->id;
    a3_print_debug("[artico3-hw] sending kernel start signal to accelerator(s) with ID = %1x\n", id);

    // Setup transfer (blksize needs to be 0 for register-based transactions)
    artico3_hw_setup_transfer(0);
    // Perform selective START (requires kernel ID and operation code 0x2
    // and the value to be written is not used).
    artico3_hw_regwrite(id, 0x2, 0x000, 0x00000000);

    return 0;
}


/*
 * ARTICo3 data transfer to accelerators
 *
 * @id      : current kernel ID
 * @naccs   : current number of hardware accelerators for this kernel
 * @round   : current round (global over local work ratio index)
 * @nrounds : total number of rounds (global over local work ratio)
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_send(uint8_t id, int naccs, unsigned int round, unsigned int nrounds) {
    int acc;
    unsigned int port, nports, nconsts, ninputs, ninouts;

    struct dmaproxy_token token;
    a3data_t *mem = NULL;

    uint32_t blksize;
    uint8_t loaded;

    struct pollfd pfd;
    pfd.fd = artico3_fd;
    pfd.events = POLLDMA;

    // Check if constant memory ports need to be loaded
    loaded = kernels[id - 1]->c_loaded;

    // Get number of input ports
    nconsts = 0;
    ninputs = 0;
    ninouts = 0;
    for (port = 0; port < kernels[id - 1]->membanks; port++) {
        if (kernels[id - 1]->consts[port]) nconsts++;
        if (kernels[id - 1]->inputs[port]) ninputs++;
        if (kernels[id - 1]->inouts[port]) ninouts++;
    }
    nports = loaded ? (ninputs + ninouts) : (nconsts + ninputs + ninouts);
    if ((nconsts + ninputs + ninouts) == 0) {
        a3_print_error("[artico3-hw] no input ports found for kernel %x\n", id);
        return -ENODEV;
    }

    // If all inputs are constant memories, and they have been already loaded...
    if (nports == 0) {
        // ...launch kernel execution using software command...
        _artico3_kernel_start(kernels[id - 1]->name);
        // ...and return
        return 0;
    }

    // Compute block size (32-bit words per accelerator)
    blksize = nports * ((kernels[id - 1]->membytes / kernels[id - 1]->membanks) / (sizeof (a3data_t)));

    // Allocate DMA physical memory
    mem = mmap(NULL, naccs * blksize * sizeof *mem, PROT_READ | PROT_WRITE, MAP_SHARED, artico3_fd, sysconf(_SC_PAGESIZE));
    if (mem == MAP_FAILED) {
        a3_print_error("[artico3-hw] mmap() failed\n");
        return -ENOMEM;
    }

    // Copy inputs to physical memory (TODO: could it be possible to avoid this step?)
    for (acc = 0; acc < naccs; acc++) {
        // When finishing, there could be more accelerators than rounds left
        if ((round + acc) < nrounds) {
            // Iterate for each port
            for (port = 0; port < nports; port++) {
                size_t size, offset;
                uint32_t idx_mem, idx_dat;
                a3data_t *data = NULL;

                // Constant memories ARE NOT involved in the DMA transfer
                if (loaded) {
                    // Compute offset in DMA-allocated memory buffer
                    idx_mem = (port * (blksize / nports)) + (acc * blksize);
                    // Get port data pointer (userspace memory buffer)
                    if (port < ninputs)
                        data = kernels[id - 1]->inputs[port]->data;                                                     // Inputs
                    else
                        data = kernels[id - 1]->inouts[port - ninputs]->data;                                           // Bidirectional I/O ports
                    // Compute number of elements (32-bit words) to be copied between buffers
                    if (port < ninputs)
                        size = (kernels[id - 1]->inputs[port]->size / sizeof (a3data_t)) / nrounds;                     // Inputs
                    else
                        size = (kernels[id - 1]->inouts[port - ninputs]->size / sizeof (a3data_t)) / nrounds;           // Bidirectional I/O ports
                    // Compute partial offset in userspace memory buffer
                    offset = round * size;
                    // Compute final offset in userspace memory buffer
                    idx_dat = (acc * size) + offset;
                }
                // Constant memories ARE involved in the DMA transfer
                else {
                    // Compute offset in DMA-allocated memory buffer
                    idx_mem = (port * (blksize / nports)) + (acc * blksize);
                    // Get port data pointer (userspace memory buffer)
                    if (port < nconsts)
                        data = kernels[id - 1]->consts[port]->data;                                                     // Constant memory inputs
                    else if (port < nconsts + ninputs)
                        data = kernels[id - 1]->inputs[port - nconsts]->data;                                           // Inputs
                    else
                        data = kernels[id - 1]->inouts[port - nconsts - ninputs]->data;                                 // Bidirectional I/O ports
                    // Compute number of elements (32-bit words) to be copied between buffers
                    if (port < nconsts)
                        size = (kernels[id - 1]->consts[port]->size / sizeof (a3data_t));                               // Constant memory inputs
                    else if (port < nconsts + ninputs)
                        size = (kernels[id - 1]->inputs[port - nconsts]->size / sizeof (a3data_t)) / nrounds;           // Inputs
                    else
                        size = (kernels[id - 1]->inouts[port - nconsts - ninputs]->size / sizeof (a3data_t)) / nrounds; // Bidirectional I/O ports
                    // Compute partial offset in userspace memory buffer
                    offset = round * size;
                    // Compute final offset in userspace memory buffer
                    if (port < nconsts)
                        idx_dat = 0;                                                                                    // Constant memory inputs
                    else
                        idx_dat = (acc * size) + offset;                                                                // Inputs and Bidirectional I/O ports
                }

                // Copy data from userspace memory buffer to DMA-allocated memory buffer
                memcpy(&mem[idx_mem], &data[idx_dat], size * sizeof (a3data_t));
                //~ unsigned int i;
                //~ for (i = 0; i < size; i++) {
                    //~ mem[idx_mem + i] = data[idx_dat + i];
                //~ }

                a3_print_debug("[artico3-hw] id %x | round %4d | acc %2d | i_port %2d | mem %10d | dat %10d | size %10d\n", id, round + acc, acc, port, idx_mem, idx_dat, size * sizeof (a3data_t));
            }
        }
    }

    // Set up data transfer
    artico3_hw_setup_transfer(blksize);

    // Start DMA transfer
    token.memaddr = mem;
    token.memoff = 0x00000000;
    token.hwaddr = (void *)A3_SLOTADDR;
    token.hwoff = (id << 16) + (loaded ? (nconsts * (kernels[id - 1]->membytes / kernels[id - 1]->membanks)) : 0);
    token.size = naccs * blksize * sizeof *mem;
    ioctl(artico3_fd, ARTICo3_IOC_DMA_MEM2HW, &token);

    // Wait for DMA transfer to finish
    poll(&pfd, 1, -1);

    // Release allocated DMA memory
    munmap(mem, naccs * blksize * sizeof *mem);

    // Set constant memory flag to 1 -> next transfer must not load
    kernels[id - 1]->c_loaded = 1;

    // Print ARTICo3 registers
    artico3_hw_print_regs();

    return 0;
}


/*
 * ARTICo3 data transfer from accelerators
 *
 * @id      : current kernel ID
 * @naccs   : current number of hardware accelerators for this kernel
 * @round   : current round (global over local work ratio index)
 * @nrounds : total number of rounds (global over local work ratio)
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_recv(uint8_t id, int naccs, unsigned int round, unsigned int nrounds) {
    int acc;
    unsigned int port, nports, noutputs, ninouts;

    struct dmaproxy_token token;
    a3data_t *mem = NULL;

    uint32_t blksize;

    struct pollfd pfd;
    pfd.fd = artico3_fd;
    pfd.events = POLLDMA;

    // Get number of output ports
    ninouts = 0;
    noutputs = 0;
    for (port = 0; port < kernels[id - 1]->membanks; port++) {
        if (kernels[id - 1]->inouts[port]) ninouts++;
        if (kernels[id - 1]->outputs[port]) noutputs++;
    }
    nports = ninouts + noutputs;
    if (nports == 0) {
        //~ a3_print_error("[artico3-hw] no output ports found for kernel %x\n", id);
        //~ return -ENODEV;
        a3_print_debug("[artico3-hw] no output ports found for kernel %x\n", id);
        return 0;
    }

    // Compute block size (32-bit words per accelerator)
    blksize = nports * ((kernels[id - 1]->membytes / kernels[id - 1]->membanks) / (sizeof (a3data_t)));

    // Allocate DMA physical memory
    mem = mmap(NULL, naccs * blksize * sizeof *mem, PROT_READ | PROT_WRITE, MAP_SHARED, artico3_fd, sysconf(_SC_PAGESIZE));
    if (mem == MAP_FAILED) {
        a3_print_error("[artico3-hw] mmap() failed\n");
        return -ENOMEM;
    }

    // Set up data transfer
    artico3_hw_setup_transfer(blksize);

    // Start DMA transfer
    token.memaddr = mem;
    token.memoff = 0x00000000;
    token.hwaddr = (void *)A3_SLOTADDR;
    token.hwoff = (id << 16) + (kernels[id - 1]->membytes - (blksize * sizeof (a3data_t)));
    token.size = naccs * blksize * sizeof *mem;
    ioctl(artico3_fd, ARTICo3_IOC_DMA_HW2MEM, &token);

    // Wait for DMA transfer to finish
    poll(&pfd, 1, -1);

    // Copy outputs from physical memory (TODO: could it be possible to avoid this step?)
    for (acc = 0; acc < naccs; acc++) {
        // When finishing, there could be more accelerators than rounds left
        if ((round + acc) < nrounds) {
            // Iterate for each port
            for (port = 0; port < nports; port++) {
                size_t size, offset;
                uint32_t idx_mem, idx_dat;
                a3data_t *data = NULL;

                // Compute offset in DMA-allocated memory buffer
                idx_mem = (port * (blksize / nports)) + (acc * blksize);
                // Get port data pointer (userspace memory buffer)
                if (port < ninouts)
                    data = kernels[id - 1]->inouts[port]->data;                                            // Bidirectional I/O ports
                else
                    data = kernels[id - 1]->outputs[port - ninouts]->data;                                 // Outputs
                // Compute number of elements (32-bit words) to be copied between buffers
                if (port < ninouts)
                    size = (kernels[id - 1]->inouts[port]->size / sizeof (a3data_t)) / nrounds;            // Bidirectional I/O ports
                else
                    size = (kernels[id - 1]->outputs[port - ninouts]->size / sizeof (a3data_t)) / nrounds; // Outputs
                // Compute partial offset in userspace memory buffer
                offset = round * size;
                // Compute final offset in userspace memory buffer
                idx_dat = (acc * size) + offset;

                // Copy data from DMA-allocated memory buffer to userspace memory buffer
                memcpy(&data[idx_dat], &mem[idx_mem], size * sizeof (a3data_t));
                //~ unsigned int i;
                //~ for (i = 0; i < size; i++) {
                    //~ data[idx_dat + i] = mem[idx_mem + i];
                //~ }

                a3_print_debug("[artico3-hw] id %x | round %4d | acc %2d | o_port %2d | mem %10d | dat %10d | size %10d\n", id, round + acc, acc, port, idx_mem, idx_dat, size * sizeof (a3data_t));
            }
        }
    }

    // Release allocated DMA memory
    munmap(mem, naccs * blksize * sizeof *mem);

    // Print ARTICo3 registers
    artico3_hw_print_regs();

    return 0;
}


/*
 * ARTICo3 delegate scheduling thread
 *
 */
void *_artico3_kernel_execute(void *data) {
    unsigned int round, nrounds;
    int naccs;

    uint8_t id;
    uint32_t readymask;

    struct timeval t0, tf;
    float tsend = 0, texec = 0, trecv = 0;

    // Get kernel invocation data
    unsigned int *tdata = data;
    id = tdata[0];
    nrounds = tdata[1];
    free(tdata);
    a3_print_debug("[artico3-hw] delegate scheduler thread ID:%x\n", id);

    // Iterate over number of rounds
    round = 0;
    while (round < nrounds) {

        pthread_mutex_lock(&mutex);

        // Increase "running" count
        running++;

        // For each iteration, compute number of (equivalent) accelerators,
        // and the corresponding expected mask to check the ready register.
        naccs = artico3_hw_get_naccs(id);
        readymask = artico3_hw_get_readymask(id);

        // Send data
        gettimeofday(&t0, NULL);
        artico3_send(id, naccs, round, nrounds);
        gettimeofday(&tf, NULL);
        tsend += ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);

        pthread_mutex_unlock(&mutex);

        // Wait until transfer is complete
        gettimeofday(&t0, NULL);
        while (!artico3_hw_transfer_isdone(readymask)) ;
        gettimeofday(&tf, NULL);
        texec += ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);

        pthread_mutex_lock(&mutex);

        // Receive data
        gettimeofday(&t0, NULL);
        artico3_recv(id, naccs, round, nrounds);
        gettimeofday(&tf, NULL);
        trecv += ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);

        // Update the round index
        round += naccs;

        // Decrease "running" count
        running--;

        pthread_mutex_unlock(&mutex);

    }

    // Print elapsed times per stage (send - process - receive)
    a3_print_debug("[artico3-hw] delegate scheduler thread ID : %x | tsend(ms) : %8.3f | texec(ms) : %8.3f | trecv(ms) : %8.3f\n", id, tsend, texec, trecv);

    return NULL;
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
    unsigned int index, nrounds;
    int ret;

    uint8_t id;

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (!kernels[index]) continue;
        if (strcmp(kernels[index]->name, name) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name \"%s\"\n", name);
        return -ENODEV;
    }

    // Check if kernel is being executed currently
    if (threads[index]) {
        a3_print_error("[artico3-hw] kernel \"%s\" is already being executed\n", name);
        return -EBUSY;
    }

    // Get kernel ID
    id = kernels[index]->id;

    // Given current configuration, compute number of rounds
    if (gsize % lsize) {
        a3_print_error("[artico3-hw] gsize (%d) not integer multiple of lsize (%d)\n", gsize, lsize);
        return -EINVAL;
    }
    nrounds = gsize / lsize;

    a3_print_debug("[artico3-hw] executing kernel \"%s\" (gsize=%d,lsize=%d,rounds=%d)\n", name, gsize, lsize, nrounds);

    // Launch delegate thread to manage work scheduling/dispatching
    unsigned int *tdata = malloc(2 * sizeof *tdata);
    tdata[0] = id;
    tdata[1] = nrounds;
    ret = pthread_create(&threads[index], NULL, _artico3_kernel_execute, tdata);
    if (ret) {
        a3_print_error("[artico3-hw] could not launch delegate scheduler thread for kernel \"%s\"\n", name);
        return -ret;
    }
    a3_print_debug("[artico3-hw] started delegate scheduler thread for kernel \"%s\"\n", name);

    return 0;
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
    unsigned int index;

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (!kernels[index]) continue;
        if (strcmp(kernels[index]->name, name) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name \"%s\"\n", name);
        return -ENODEV;
    }

    // Wait for thread completion
    pthread_join(threads[index], NULL);

    // Mark thread as completed
    threads[index] = 0;

    return 0;
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
    unsigned int index;
    uint8_t id;

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (!kernels[index]) continue;
        if (strcmp(kernels[index]->name, name) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name \"%s\"\n", name);
        return -ENODEV;
    }

    // Get kernel id
    id = kernels[index]->id;
    a3_print_debug("[artico3-hw] sending kernel reset signal to accelerator(s) with ID = %1x\n", id);

    // Setup transfer (blksize needs to be 0 for register-based transactions)
    artico3_hw_setup_transfer(0);
    // Perform selective RESET (requires kernel ID and operation code 0x1
    // and the value to be written is not used).
    artico3_hw_regwrite(id, 0x1, 0x000, 0x00000000);

    return 0;
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
    unsigned int index, i, j;
    struct a3shuffler_t shuffler_shadow;
    uint8_t id;

    uint64_t id_reg;
    uint64_t tmr_reg;
    uint64_t dmr_reg;

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (!kernels[index]) continue;
        if (strcmp(kernels[index]->name, name) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name \"%s\"\n", name);
        return -ENODEV;
    }

    // Get kernel id
    id = kernels[index]->id;

    // Lock mutex, avoid interference with other processes
    pthread_mutex_lock(&mutex);

    // Copy current shuffler status
    shuffler_shadow = shuffler;

    // Get current shadow registers
    id_reg  = shuffler.id_reg;
    dmr_reg = shuffler.dmr_reg;
    tmr_reg = shuffler.tmr_reg;

    // Initialize index variable
    index = 0;

    // TMR blocks
    for (i = 1; i < (1 << 4); i++) {           // TODO: make this configurable (now, only 4 bits for ID are used)
        shuffler.id_reg  = 0x0000000000000000;
        shuffler.dmr_reg = 0x0000000000000000;
        shuffler.tmr_reg = 0x0000000000000000;
        for (j = 0; j < shuffler.nslots; j++) {
            if ((((id_reg >> (4 * j)) & 0xf) == id) && ((tmr_reg >> (4 * j) & 0xf) == i)) {
                shuffler.id_reg  |= (id << (4 * j));
                shuffler.tmr_reg |= (i << (4 * j));
            }
        }
        if (shuffler.id_reg) {
            // Perform write operation
            artico3_hw_setup_transfer(0); // Register operations do not use blksize register
            artico3_hw_regwrite(id, 0, offset, cfg[index++]);
            a3_print_debug("[artico3-hw] W TMR | kernel : %1x | id : %016" PRIx64 " | tmr : %016" PRIx64 " | dmr : %016" PRIx64 " | register : %03x | value : %08x\n", id, shuffler.id_reg, shuffler.tmr_reg, shuffler.dmr_reg, offset, cfg[index-1]);
        }
    }

    // DMR blocks
    for (i = 1; i < (1 << 4); i++) {           // TODO: make this configurable (now, only 4 bits for ID are used)
        shuffler.id_reg  = 0x0000000000000000;
        shuffler.dmr_reg = 0x0000000000000000;
        shuffler.tmr_reg = 0x0000000000000000;
        for (j = 0; j < shuffler.nslots; j++) {
            if ((((id_reg >> (4 * j)) & 0xf) == id) && ((dmr_reg >> (4 * j) & 0xf) == i)) {
                shuffler.id_reg  |= (id << (4 * j));
                shuffler.dmr_reg |= (i << (4 * j));
            }
        }
        if (shuffler.id_reg) {
            // Perform write operation
            artico3_hw_setup_transfer(0); // Register operations do not use blksize register
            artico3_hw_regwrite(id, 0, offset, cfg[index++]);
            a3_print_debug("[artico3-hw] W DMR | kernel : %1x | id : %016" PRIx64 " | tmr : %016" PRIx64 " | dmr : %016" PRIx64 " | register : %03x | value : %08x\n", id, shuffler.id_reg, shuffler.tmr_reg, shuffler.dmr_reg, offset, cfg[index-1]);
        }
    }

    // Simplex blocks
    for (j = 0; j < shuffler.nslots; j++) {
        shuffler.id_reg  = 0x0000000000000000;
        shuffler.dmr_reg = 0x0000000000000000;
        shuffler.tmr_reg = 0x0000000000000000;
        if ((((id_reg >> (4 * j)) & 0xf) == id) && (((dmr_reg >> (4 * j) & 0xf) == 0x0) && ((tmr_reg >> (4 * j) & 0xf) == 0x0))) {
            shuffler.id_reg  |= (id << (4 * j));
        }
        if (shuffler.id_reg) {
            // Perform write operation
            artico3_hw_setup_transfer(0); // Register operations do not use blksize register
            artico3_hw_regwrite(id, 0, offset, cfg[index++]);
            a3_print_debug("[artico3-hw] W SMP | kernel : %1x | id : %016" PRIx64 " | tmr : %016" PRIx64 " | dmr : %016" PRIx64 " | register : %03x | value : %08x\n", id, shuffler.id_reg, shuffler.tmr_reg, shuffler.dmr_reg, offset, cfg[index-1]);
        }
    }

    // Restore previous shuffler status
    shuffler = shuffler_shadow;

    // Release mutex
    pthread_mutex_unlock(&mutex);

    return 0;
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
    unsigned int index, i, j;
    struct a3shuffler_t shuffler_shadow;
    uint8_t id;

    uint64_t id_reg;
    uint64_t tmr_reg;
    uint64_t dmr_reg;

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (!kernels[index]) continue;
        if (strcmp(kernels[index]->name, name) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name \"%s\"\n", name);
        return -ENODEV;
    }

    // Get kernel id
    id = kernels[index]->id;

    // Lock mutex, avoid interference with other processes
    pthread_mutex_lock(&mutex);

    // Copy current shuffler status
    shuffler_shadow = shuffler;

    // Get current shadow registers
    id_reg  = shuffler.id_reg;
    tmr_reg = shuffler.tmr_reg;
    dmr_reg = shuffler.dmr_reg;

    // Initialize index variable
    index = 0;

    // TMR blocks
    for (i = 1; i < (1 << 4); i++) {           // TODO: make this configurable (now, only 4 bits for ID are used)
        shuffler.id_reg  = 0x0000000000000000;
        shuffler.dmr_reg = 0x0000000000000000;
        shuffler.tmr_reg = 0x0000000000000000;
        for (j = 0; j < shuffler.nslots; j++) {
            if ((((id_reg >> (4 * j)) & 0xf) == id) && ((tmr_reg >> (4 * j) & 0xf) == i)) {
                shuffler.id_reg  |= (id << (4 * j));
                shuffler.tmr_reg |= (i << (4 * j));
            }
        }
        if (shuffler.id_reg) {
            // Perform read operation
            artico3_hw_setup_transfer(0); // Register operations do not use blksize register
            cfg[index++] = artico3_hw_regread(id, 0, offset);
            a3_print_debug("[artico3-hw] R TMR | kernel : %1x | id : %016" PRIx64 " | tmr : %016" PRIx64 " | dmr : %016" PRIx64 " | register : %03x | value : %08x\n", id, shuffler.id_reg, shuffler.tmr_reg, shuffler.dmr_reg, offset, cfg[index-1]);
        }
    }

    // DMR blocks
    for (i = 1; i < (1 << 4); i++) {           // TODO: make this configurable (now, only 4 bits for ID are used)
        shuffler.id_reg  = 0x0000000000000000;
        shuffler.dmr_reg = 0x0000000000000000;
        shuffler.tmr_reg = 0x0000000000000000;
        for (j = 0; j < shuffler.nslots; j++) {
            if ((((id_reg >> (4 * j)) & 0xf) == id) && ((dmr_reg >> (4 * j) & 0xf) == i)) {
                shuffler.id_reg  |= (id << (4 * j));
                shuffler.dmr_reg |= (i << (4 * j));
            }
        }
        if (shuffler.id_reg) {
            // Perform read operation
            artico3_hw_setup_transfer(0); // Register operations do not use blksize register
            cfg[index++] = artico3_hw_regread(id, 0, offset);
            a3_print_debug("[artico3-hw] R DMR | kernel : %1x | id : %016" PRIx64 " | tmr : %016" PRIx64 " | dmr : %016" PRIx64 " | register : %03x | value : %08x\n", id, shuffler.id_reg, shuffler.tmr_reg, shuffler.dmr_reg, offset, cfg[index-1]);
        }
    }

    // Simplex blocks
    for (j = 0; j < shuffler.nslots; j++) {
        shuffler.id_reg  = 0x0000000000000000;
        shuffler.dmr_reg = 0x0000000000000000;
        shuffler.tmr_reg = 0x0000000000000000;
        if ((((id_reg >> (4 * j)) & 0xf) == id) && (((dmr_reg >> (4 * j) & 0xf) == 0x0) && ((tmr_reg >> (4 * j) & 0xf) == 0x0))) {
            shuffler.id_reg  |= (id << (4 * j));
        }
        if (shuffler.id_reg) {
            // Perform read operation
            artico3_hw_setup_transfer(0); // Register operations do not use blksize register
            cfg[index++] = artico3_hw_regread(id, 0, offset);
            a3_print_debug("[artico3-hw] R SMP | kernel : %1x | id : %016" PRIx64 " | tmr : %016" PRIx64 " | dmr : %016" PRIx64 " | register : %03x | value : %08x\n", id, shuffler.id_reg, shuffler.tmr_reg, shuffler.dmr_reg, offset, cfg[index-1]);
        }
    }

    // Restore previous shuffler status
    shuffler = shuffler_shadow;

    // Release mutex
    pthread_mutex_unlock(&mutex);

    return 0;
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
 * TODO   : implement optimized version using qsort();
 *
 */
void *artico3_alloc(size_t size, const char *kname, const char *pname, enum a3pdir_t dir) {
    unsigned int index, p, i, j;
    struct a3port_t *port = NULL;

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (!kernels[index]) continue;
        if (strcmp(kernels[index]->name, kname) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name \"%s\"\n", kname);
        return NULL;
    }

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

    // Allocate memory for application
    port->data = malloc(port->size);
    if (!port->data) {
        goto err_malloc_port_data;
    }

    // Check port direction flag : CONSTANTS
    if (dir == A3_P_C) {

        // Add port to constant memory inputs
        p = 0;
        while (kernels[index]->consts[p] && (p < kernels[index]->membanks)) p++;
        if (p == kernels[index]->membanks) {
            a3_print_error("[artico3-hw] no empty bank found for port\n");
            goto err_noport;
        }
        kernels[index]->consts[p] = port;

        // Bubble-sort constant memory inputs by name
        for (i = 0; i < (kernels[index]->membanks - 1); i++) {
            for (j = 0; j < (kernels[index]->membanks - 1 - i); j++) {
                if (!kernels[index]->consts[j + 1]) break;
                if (strcmp(kernels[index]->consts[j]->name, kernels[index]->consts[j + 1]->name) > 0) {
                    struct a3port_t *aux = kernels[index]->consts[j + 1];
                    kernels[index]->consts[j + 1] = kernels[index]->consts[j];
                    kernels[index]->consts[j] = aux;
                }
            }
        }

        // Set constant memory flag to 0 -> next transfer must load
        kernels[index]->c_loaded = 0;

        // Print sorted list
        a3_print_debug("[artico3-hw] constant memory input ports after sorting: ");
        for (p = 0; p < kernels[index]->membanks; p++) {
            if (!kernels[index]->consts[p]) break;
            a3_print_debug("%s ", kernels[index]->consts[p]->name);
        }
        a3_print_debug("\n");

    }

    // Check port direction flag : INPUTS
    if (dir == A3_P_I) {

        // Add port to inputs
        p = 0;
        while (kernels[index]->inputs[p] && (p < kernels[index]->membanks)) p++;
        if (p == kernels[index]->membanks) {
            a3_print_error("[artico3-hw] no empty bank found for port\n");
            goto err_noport;
        }
        kernels[index]->inputs[p] = port;

        // Bubble-sort inputs by name
        for (i = 0; i < (kernels[index]->membanks - 1); i++) {
            for (j = 0; j < (kernels[index]->membanks - 1 - i); j++) {
                if (!kernels[index]->inputs[j + 1]) break;
                if (strcmp(kernels[index]->inputs[j]->name, kernels[index]->inputs[j + 1]->name) > 0) {
                    struct a3port_t *aux = kernels[index]->inputs[j + 1];
                    kernels[index]->inputs[j + 1] = kernels[index]->inputs[j];
                    kernels[index]->inputs[j] = aux;
                }
            }
        }

        // Print sorted list
        a3_print_debug("[artico3-hw] input ports after sorting: ");
        for (p = 0; p < kernels[index]->membanks; p++) {
            if (!kernels[index]->inputs[p]) break;
            a3_print_debug("%s ", kernels[index]->inputs[p]->name);
        }
        a3_print_debug("\n");

    }

    // Check port direction flag : OUTPUTS
    if (dir == A3_P_O) {

        // Add port to outputs
        p = 0;
        while (kernels[index]->outputs[p] && (p < kernels[index]->membanks)) p++;
        if (p == kernels[index]->membanks) {
            a3_print_error("[artico3-hw] no empty bank found for port\n");
            goto err_noport;
        }
        kernels[index]->outputs[p] = port;

        // Bubble-sort outputs by name
        for (i = 0; i < (kernels[index]->membanks - 1); i++) {
            for (j = 0; j < (kernels[index]->membanks - 1 - i); j++) {
                if (!kernels[index]->outputs[j + 1]) break;
                if (strcmp(kernels[index]->outputs[j]->name, kernels[index]->outputs[j + 1]->name) > 0) {
                    struct a3port_t *aux = kernels[index]->outputs[j + 1];
                    kernels[index]->outputs[j + 1] = kernels[index]->outputs[j];
                    kernels[index]->outputs[j] = aux;
                }
            }
        }

        // Print sorted list
        a3_print_debug("[artico3-hw] output ports after sorting: ");
        for (p = 0; p < kernels[index]->membanks; p++) {
            if (!kernels[index]->outputs[p]) break;
            a3_print_debug("%s ", kernels[index]->outputs[p]->name);
        }
        a3_print_debug("\n");

    }

    // Check port direction flag : BIDIRECTIONAL I/O
    if (dir == A3_P_IO) {

        // Add port to bidirectional I/O ports
        p = 0;
        while (kernels[index]->inouts[p] && (p < kernels[index]->membanks)) p++;
        if (p == kernels[index]->membanks) {
            a3_print_error("[artico3-hw] no empty bank found for port\n");
            goto err_noport;
        }
        kernels[index]->inouts[p] = port;

        // Bubble-sort bidirectional I/O ports by name
        for (i = 0; i < (kernels[index]->membanks - 1); i++) {
            for (j = 0; j < (kernels[index]->membanks - 1 - i); j++) {
                if (!kernels[index]->inouts[j + 1]) break;
                if (strcmp(kernels[index]->inouts[j]->name, kernels[index]->inouts[j + 1]->name) > 0) {
                    struct a3port_t *aux = kernels[index]->inouts[j + 1];
                    kernels[index]->inouts[j + 1] = kernels[index]->inouts[j];
                    kernels[index]->inouts[j] = aux;
                }
            }
        }

        // Print sorted list
        a3_print_debug("[artico3-hw] bidirectional I/O ports after sorting: ");
        for (p = 0; p < kernels[index]->membanks; p++) {
            if (!kernels[index]->inouts[p]) break;
            a3_print_debug("%s ", kernels[index]->inouts[p]->name);
        }
        a3_print_debug("\n");

    }

    // Return allocated memory
    return port->data;

err_noport:
    free(port->data);

err_malloc_port_data:
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
int artico3_free(const char *kname, const char *pname) {
    unsigned int index, p;
    struct a3port_t *port = NULL;

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
        if (kernels[index]->consts[p]) {
            if (strcmp(kernels[index]->consts[p]->name, pname) == 0) {
                port = kernels[index]->consts[p];
                kernels[index]->consts[p] = NULL;
                break;
            }
        }
        if (kernels[index]->inputs[p]) {
            if (strcmp(kernels[index]->inputs[p]->name, pname) == 0) {
                port = kernels[index]->inputs[p];
                kernels[index]->inputs[p] = NULL;
                break;
            }
        }
        if (kernels[index]->outputs[p]) {
            if (strcmp(kernels[index]->outputs[p]->name, pname) == 0) {
                port = kernels[index]->outputs[p];
                kernels[index]->outputs[p] = NULL;
                break;
            }
        }
        if (kernels[index]->inouts[p]) {
            if (strcmp(kernels[index]->inouts[p]->name, pname) == 0) {
                port = kernels[index]->inouts[p];
                kernels[index]->inouts[p] = NULL;
                break;
            }
        }
    }
    if (p == kernels[index]->membanks) {
        a3_print_error("[artico3-hw] no port found with name %s\n", pname);
        return -ENODEV;
    }

    // Free application memory
    free(port->data);
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
int artico3_load(const char *name, size_t slot, uint8_t tmr, uint8_t dmr, uint8_t force) {
    unsigned int index;
    char filename[128];
    int ret;

    uint8_t id;
    uint8_t reconf;

    // Check if slot is within range
    if (slot >= shuffler.nslots) {
        a3_print_error("[artico3-hw] slot index out of range (0 ... %d)\n", shuffler.nslots - 1);
        return -ENODEV;
    }

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (!kernels[index]) continue;
        if (strcmp(kernels[index]->name, name) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name \"%s\"\n", name);
        return -ENODEV;
    }

    // Get kernel id
    id = kernels[index]->id;

    while (1) {
        pthread_mutex_lock(&mutex);

        // Only change configuration when no kernel is being executed
        if (!running) {

            // Check if partial reconfiguration is required
            if (shuffler.slots[slot].state == S_EMPTY) {
                reconf = 1;
            }
            else {
                if (strcmp(shuffler.slots[slot].kernel->name, name) != 0) {
                    reconf = 1;
                }
                else {
                    reconf = 0;
                }
            }

            // Even if reconfiguration is not required, it can be forced
            //~ reconf |= force;
            reconf = reconf || force;

            // Perform DPR
            if (reconf) {

                // Set slot flag
                shuffler.slots[slot].state = S_LOAD;

                // Load partial bitstream
                sprintf(filename, "pbs/a3_%s_a3_slot_%d_partial.bin", name, slot);
                ret = fpga_load(filename, 1);
                if (ret) {
                    goto err_fpga;
                }

                // Set slot flag
                shuffler.slots[slot].state = S_IDLE;

            }

            // Update ARTICo3 slot info
            shuffler.slots[slot].kernel = kernels[index];

            // Update ARTICo3 configuration registers
            shuffler.id_reg ^= (shuffler.id_reg & ((uint64_t)0xf << (4 * slot)));
            shuffler.id_reg |= (uint64_t)id << (4 * slot);

            shuffler.tmr_reg ^= (shuffler.tmr_reg & ((uint64_t)0xf << (4 * slot)));
            shuffler.tmr_reg |= (uint64_t)tmr << (4 * slot);

            shuffler.dmr_reg ^= (shuffler.dmr_reg & ((uint64_t)0xf << (4 * slot)));
            shuffler.dmr_reg |= (uint64_t)dmr << (4 * slot);

            // Set constant memory flag to 0 -> next transfer must load
            kernels[index]->c_loaded = 0;

            // Exit infinite loop
            break;

        }

        pthread_mutex_unlock(&mutex);
    }
    pthread_mutex_unlock(&mutex);

    a3_print_debug("[artico3-hw] loaded accelerator \"%s\" on slot %d\n", name, slot);

    return 0;

err_fpga:
    pthread_mutex_unlock(&mutex);

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
int artico3_unload(size_t slot) {

    // Check if slot is within range
    if (slot >= shuffler.nslots) {
        a3_print_error("[artico3-hw] slot index out of range (0 ... %d)\n", shuffler.nslots - 1);
        return -ENODEV;
    }

    while (1) {
        pthread_mutex_lock(&mutex);

        // Only change configuration when no kernel is being executed
        if (!running) {

            // Update ARTICo3 slot info
            shuffler.slots[slot].state = S_EMPTY;
            shuffler.slots[slot].kernel = NULL;

            // Update ARTICo3 configuration registers
            shuffler.id_reg ^= (shuffler.id_reg & ((uint64_t)0xf << (4 * slot)));
            shuffler.tmr_reg ^= (shuffler.tmr_reg & ((uint64_t)0xf << (4 * slot)));
            shuffler.dmr_reg ^= (shuffler.dmr_reg & ((uint64_t)0xf << (4 * slot)));

            // Exit infinite loop
            break;

        }

        pthread_mutex_unlock(&mutex);
    }
    pthread_mutex_unlock(&mutex);

    a3_print_debug("[artico3-hw] removed accelerator from slot %d\n", slot);

    return 0;
}
