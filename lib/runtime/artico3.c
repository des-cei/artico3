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

#include <sys/time.h>  // struct timeval, gettimeofday()

#include "dmaproxy.h"
#include "artico3.h"
#include "artico3_hw.h"
#include "artico3_rcfg.h"
#include "artico3_dbg.h"


/*
 * ARTICo3 global variables
 *
 * @artico3_fd : /dev/uioX file descriptor (used for interrupt management)
 * @artico3_hw : user-space map of ARTICo3 hardware registers
 * @a3slots_fd : /dev/dmaproxyX file descriptor (used to access kernels)
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
static int a3slots_fd;

struct a3shuffler_t shuffler = {
    .id_reg      = 0x0000000000000000,
    .tmr_reg     = 0x0000000000000000,
    .dmr_reg     = 0x0000000000000000,
    .blksize_reg = 0x00000000,
    .clkgate_reg = 0x00000000,
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
    DIR *d;
    struct dirent *dir;
    char filename[32];
    unsigned int i;
    int ret;

    /*
     * NOTE: this function relies on predefined addresses for both control
     *       and data interfaces of the ARTICo3 infrastructure.
     *       If the processor memory map is changed somehow, this has to
     *       be reflected in this file.
     *
     *       ARTICo3 Shuffler Control -> 0x7aa00000 (uio)
     *       ARTICo3 Shuffler Data    -> 0x8aa00000 (dmaproxy)
     *
     */

    // Load static system (global FPGA reconfiguration)
    fpga_load("system.bin", 0);

    // Find the appropriate UIO device
    d = opendir("/sys/bus/platform/devices/7aa00000.artico3_shuffler/uio/");
    if (d) {
        while ((dir = readdir(d)) != NULL) {
            if ((strcmp(dir->d_name, ".") == 0) || (strcmp(dir->d_name, ".") == 0)) {
                continue;
            }
            sprintf(filename, "/dev/%s", dir->d_name);
        }
        closedir(d);
    }
    else {
        a3_print_error("[artico3-hw] no UIO device found (check device tree address?)\n");
        return -ENODEV;
    }

    // Open UIO device file
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

    // Find the appropriate DMA proxy device
    d = opendir("/sys/bus/platform/devices/8aa00000.artico3_slots/dmaproxy/");
    if (d) {
        while ((dir = readdir(d)) != NULL) {
            if ((strcmp(dir->d_name, ".") == 0) || (strcmp(dir->d_name, ".") == 0)) {
                continue;
            }
            sprintf(filename, "/dev/%s", dir->d_name);
        }
        closedir(d);
    }
    else {
        a3_print_error("[artico3-hw] no DMA proxy device found (check device tree address?)\n");
        ret = -ENODEV;
        goto err_dmaproxy;
    }

    // Open DMA proxy device file
    a3slots_fd = open(filename, O_RDWR);
    if (a3slots_fd < 0) {
        a3_print_error("[artico3-hw] open() %s failed\n", filename);
        ret = -ENODEV;
        goto err_dmaproxy;
    }
    a3_print_debug("[artico3-hw] a3slots_fd=%d | dev=%s\n", a3slots_fd, filename);

    // Initialize Shuffler structure (software)
    shuffler.slots = malloc(A3_MAXSLOTS * sizeof (struct a3slot_t));
    if (!shuffler.slots) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_slots;
    }
    for (i = 0; i < A3_MAXSLOTS; i++) {
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
    close(a3slots_fd);

err_dmaproxy:
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

    // Disable clocks in reconfigurable region
    artico3_hw_disable_clk();

    // Release allocated memory for delegate threads
    free(threads);

    // Release allocated memory for kernel list
    free(kernels);

    // Release allocated memory for slot info
    free(shuffler.slots);

    // Close DMA proxy device file
    close(a3slots_fd);

    // Release memory obtained with mmap()
    munmap(artico3_hw, 0x100000);

    // Close UIO device file
    close(artico3_fd);

}


/*
 * ARTICo3 create hardware kernel
 *
 * This function creates an ARTICo3 kernel in the current application.
 *
 * @name     : name of the hardware kernel to be created
 * @membytes : local memory size (in bytes) of the associated accelerator
 * @membanks : number of local memory banks in the associated accelerator
 * @regrw    : number of read/write registers in the associated accelerator
 * @regro    : number of read only registers in the associated accelerator
 *
 * Return : 0 on success, error code otherwise
 *
 */
int artico3_kernel_create(const char *name, size_t membytes, size_t membanks, size_t regrw, size_t regro) {
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
    kernel->name = malloc(strlen(name));
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
    kernel->regrw = regrw;
    kernel->regro = regro;

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

    // Set initial values for inputs and outputs
    for (i = 0; i < kernel->membanks; i++) {
        kernel->inputs[i] = NULL;
        kernel->outputs[i] = NULL;
    }

    a3_print_debug("[artico3-hw] created kernel (name=%s,id=%x,membytes=%d,membanks=%d,regrw=%d,regro=%d)\n", kernel->name, kernel->id, kernel->membytes, kernel->membanks, kernel->regrw, kernel->regro);

    // Store kernel configuration in kernel list
    kernels[index] = kernel;

    return 0;

err_malloc_kernel_outputs:
    free(kernel->inputs);

err_malloc_kernel_inputs:
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

    // Free allocated memory
    free(kernels[index]->outputs);
    free(kernels[index]->inputs);
    free(kernels[index]->name);
    free(kernels[index]);
    a3_print_debug("[artico3-hw] released kernel (name=%s)\n", name);

    // Set kernel list entry as empty
    kernels[index] = NULL;

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
    unsigned int acc, port;
    unsigned int nports;

    struct dmaproxy_token token;
    volatile a3data_t *mem = NULL;

    uint32_t blksize;

    // Get number of input ports
    nports = 0;
    for (port = 0; port < kernels[id - 1]->membanks; port++) {
        if (!kernels[id - 1]->inputs[port]) {
            nports = port;
            break;
        }
    }
    if (!nports) {
        a3_print_error("[artico3-hw] no input ports found for kernel %x\n", id);
        return -ENODEV;
    }

    // Compute block size (32-bit words per accelerator)
    blksize = nports * ((kernels[id - 1]->membytes / kernels[id - 1]->membanks) / (sizeof (a3data_t)));

    // Allocate DMA physical memory
    mem = mmap(NULL, naccs * blksize * sizeof *mem, PROT_READ | PROT_WRITE, MAP_SHARED, a3slots_fd, 0);
    if (mem == MAP_FAILED) {
        a3_print_error("[artico3-hw] mmap() failed\n");
        return -ENOMEM;
    }

    // Copy inputs to physical memory (TODO: could it be possible to avoid this step?)
    for (acc = 0; acc < naccs; acc++) {
        for (port = 0; port < nports; port++) {
            // When finishing, there could be more accelerators than rounds left
            if ((round + acc) < nrounds) {
                size_t size = (kernels[id - 1]->inputs[port]->size / sizeof (a3data_t)) / nrounds;
                size_t offset = round * size;
                uint32_t idx_mem = (port * (blksize / nports)) + (acc * blksize);
                uint32_t idx_dat = (acc * size) + offset;
                a3data_t *data = kernels[id - 1]->inputs[port]->data;
                //~ memcpy(&mem[idx_mem], &data[idx_dat], size * sizeof (a3data_t));

                unsigned int i;
                for (i = 0; i < size; i++) {
                    mem[idx_mem + i] = data[idx_dat + i];
                }

                a3_print_debug("[artico3-hw] id %x | round %3d | acc %d | i_port %d | mem %4d | dat %6d | size %4d\n", id, round + acc, acc, port, idx_mem, idx_dat, size * sizeof (a3data_t));
            }
        }
    }

    // Set up data transfer
    artico3_hw_setup_transfer(blksize);

    // Start DMA transfer
    token.memaddr = mem;
    token.memoff = 0x00000000;
    token.hwaddr = (void *)A3_SLOTADDR;
    token.hwoff = id << 16;
    token.size = naccs * blksize * sizeof *mem;
    ioctl(a3slots_fd, DMAPROXY_IOC_DMA_MEM2HW, &token);

    // Release allocated DMA memory
    munmap(mem, naccs * blksize * sizeof *mem);

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
    unsigned int acc, port;
    unsigned int nports;

    struct dmaproxy_token token;
    volatile a3data_t *mem = NULL;

    uint32_t blksize;

    // Get number of input ports
    nports = 0;
    for (port = 0; port < kernels[id - 1]->membanks; port++) {
        if (!kernels[id - 1]->outputs[port]) {
            nports = port;
            break;
        }
    }
    if (!nports) {
        a3_print_error("[artico3-hw] no output ports found for kernel %x\n", id);
        return -ENODEV;
    }

    // Compute block size (32-bit words per accelerator)
    blksize = nports * ((kernels[id - 1]->membytes / kernels[id - 1]->membanks) / (sizeof (a3data_t)));

    // Allocate DMA physical memory
    mem = mmap(NULL, naccs * blksize * sizeof *mem, PROT_READ | PROT_WRITE, MAP_SHARED, a3slots_fd, 0);
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
    ioctl(a3slots_fd, DMAPROXY_IOC_DMA_HW2MEM, &token);

    // Copy outputs from physical memory (TODO: could it be possible to avoid this step?)
    for (acc = 0; acc < naccs; acc++) {
        for (port = 0; port < nports; port++) {
            // When finishing, there could be more accelerators than rounds left
            if ((round + acc) < nrounds) {
                size_t size = (kernels[id - 1]->outputs[port]->size / sizeof (a3data_t)) / nrounds;
                size_t offset = round * size;
                uint32_t idx_mem = (port * (blksize / nports)) + (acc * blksize);
                uint32_t idx_dat = (acc * size) + offset;
                a3data_t *data = kernels[id - 1]->outputs[port]->data;
                //~ memcpy(&data[idx_dat], &mem[idx_mem], size * sizeof (a3data_t));

                unsigned int i;
                for (i = 0; i < size; i++) {
                    data[idx_dat + i] = mem[idx_mem + i];
                }

                a3_print_debug("[artico3-hw] id %x | round %3d | acc %d | o_port %d | mem %4d | dat %6d | size %4d\n", id, round + acc, acc, port, idx_mem, idx_dat, size * sizeof (a3data_t));
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

    // TODO: this should use artico3_print_XXX()
    printf("[artico3-hw] delegate scheduler thread ID:%x | tsend(ms):%.3f | texec(ms):%.3f | trecv(ms):%.3f\n", id, tsend, texec, trecv);

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
    port->name = malloc(strlen(pname));
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

    // Check port direction flag
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
    else {

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


// TODO: add documentation for this function
int artico3_load(const char *name, size_t slot, uint8_t tmr, uint8_t dmr, uint8_t force) {
    unsigned int index;
    char filename[128];
    int ret;

    uint8_t id;
    uint8_t reconf;

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
            if (shuffler.slots[index].state == S_EMPTY) {
                reconf = 1;
            }
            else {
                if (strcmp(shuffler.slots[index].kernel->name, name) != 0) {
                    reconf = 1;
                }
                else {
                    reconf = 0;
                }
            }

            // Even if reconfiguration is not required, it can be forced
            reconf |= force;

            // Perform DPR
            if (reconf) {

                // Set slot flag
                shuffler.slots[index].state = S_LOAD;

                // Load partial bitstream
                sprintf(filename, "pbs/a3_%s_a3_slot_%d_partial.bin", name, slot);
                ret = fpga_load(filename, 1);
                if (ret) {
                    goto err_fpga;
                }

                // Set slot flag
                shuffler.slots[index].state = S_IDLE;

            }

            // Update ARTICo3 slot info
            shuffler.slots[index].kernel = kernels[index];

            // Update ARTICo3 configuration registers
            shuffler.id_reg ^= (shuffler.id_reg & ((uint64_t)0xf << (4 * slot)));
            shuffler.id_reg |= (uint64_t)id << (4 * slot);

            shuffler.tmr_reg ^= (shuffler.tmr_reg & ((uint64_t)0xf << (4 * slot)));
            shuffler.tmr_reg |= (uint64_t)tmr << (4 * slot);

            shuffler.dmr_reg ^= (shuffler.dmr_reg & ((uint64_t)0xf << (4 * slot)));
            shuffler.dmr_reg |= (uint64_t)dmr << (4 * slot);

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


// TODO: add documentation for this function
int artico3_unload(const char *name, size_t slot) {
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

    while (1) {
        pthread_mutex_lock(&mutex);

        // Only change configuration when no kernel is being executed
        if (!running) {

            // Update ARTICo3 slot info
            shuffler.slots[index].kernel = NULL;

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

    a3_print_debug("[artico3-hw] removed accelerator \"%s\" from slot %d\n", name, slot);

    return 0;
}
