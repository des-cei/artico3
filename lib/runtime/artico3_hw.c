/*
 * ARTICo3 low-level hardware API
 *
 * Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date        : August 2017
 * Description : This file contains the low-level functions required to
 *               work with the ARTICo3 infrastructure (Data Shuffler).
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <math.h>      // ceil() [NOTE: requires -lm in LDFLAGS]

#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

#include <dirent.h>    // DIR, struct dirent, opendir(), readdir(), closedir()
#include <sys/mman.h>  // mmap()
#include <sys/ioctl.h> // ioctl()

#include "../../linux/drivers/dmaproxy/dmaproxy.h" // TODO: use Makefile
#include "artico3_hw.h"


#define A3_MAXSLOTS (4)   // TODO: make this using a3dk parser (<a3<NUM_SLOTS>a3>)
#define A3_MAXKERNS (0xF) // TODO: maybe make it configurable? Would also require additional VHDL parsing in Shuffler...
#define A3_SLOTADDR (0x8aa00000)


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
 */

static int artico3_fd;
static uint32_t *artico3_hw = NULL;
static int a3slots_fd;

static struct a3_shuffler shuffler = {
    .id_reg      = 0x0000000000001222,
    .tmr_reg     = 0x0000000000000000,
    .dmr_reg     = 0x0000000000000000,
    .blksize_reg = 0x00000000,
    .clkgate_reg = 0x00000000,
    .slots       = NULL,
};

static struct a3_kernel **kernels = NULL;


/*
 * ARTICo3 init function
 *
 * This function sets up the basic software entities required to manage
 * the ARTICo3 low-level functionality (DMA transfers, kernel and slot
 * distributions, etc.).
 *
 * Return : 0 if initialization finished successfully, error otherwise
 */
int artico3_init() {
    DIR *d;
    struct dirent *dir;
    char filename[32];
    unsigned int i;
    int ret;

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
        ret = -ENODEV;
        goto err_uio;
    }

    // Open UIO device file
    artico3_fd = open(filename, O_RDWR);
    if (artico3_fd < 0) {
        a3_print_error("[artico3-hw] open() %s failed\n", filename);
        ret = -ENODEV;
        goto err_uio;
    }
    a3_print_debug("[artico3-hw] open()   -> artico3_fd : %d : %s\n", artico3_fd, filename);

    // Obtain access to physical memory map using mmap()
    artico3_hw = mmap(NULL, 0x100000, PROT_READ | PROT_WRITE, MAP_SHARED, artico3_fd, 0);
    if (artico3_hw == MAP_FAILED) {
        a3_print_error("[artico3-hw] mmap() failed\n");
        ret = -ENOMEM;
        goto err_mmap;
    }
    a3_print_debug("[artico3-hw] mmap()   -> artico3_hw : %p\n", artico3_hw);

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
    a3_print_debug("[artico3-hw] open()   -> a3slots_fd : %d : %s\n", a3slots_fd, filename);

    // Initialize Shuffler structure (software)
    shuffler.slots = malloc(A3_MAXSLOTS * sizeof (struct a3_slot));
    if (!shuffler.slots) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        ret = -ENOMEM;
        goto err_malloc_slots;
    }
    a3_print_debug("[artico3-hw] malloc() -> shuffler.slots : %p\n", shuffler.slots);
    for (i = 0; i < A3_MAXSLOTS; i++) {
        shuffler.slots[i].kernel = NULL;
        shuffler.slots[i].state  = S_EMPTY;
    }

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

    // Enable clocks in reconfigurable region (TODO: change if a more precise power management is required)
    uint32_t clkgate = 0;
    for (i = 0; i < A3_MAXSLOTS; i++) {
        clkgate |= 1 << i;
    }
    artico3_hw[A3_CLOCK_GATE_REG] = clkgate;

    return 0;

err_malloc_kernels:
    free(shuffler.slots);

err_malloc_slots:
    close(a3slots_fd);

err_dmaproxy:
    munmap(artico3_hw, 0x100000);

err_mmap:
    close(artico3_fd);

err_uio:
    return ret;
}


/*
 * ARTICo3 exit function
 *
 * This function cleans the software entities created by artico3_init().
 *
 */
void artico3_exit() {

    // TODO: add clock gating, and garbage cleaning

    // Release allocated memory in Shuffler structure
    free(shuffler.slots);
    a3_print_debug("[artico3-hw] free()   -> shuffler.slots\n");

    // Close DMA proxy device file
    close(a3slots_fd);
    a3_print_debug("[artico3-hw] close()  -> a3slots_fd\n");

    // Release memory obtained with mmap()
    munmap(artico3_hw, 0x100000);
    a3_print_debug("[artico3-hw] munmap() -> artico3_hw\n");

    // Close UIO device file
    close(artico3_fd);
    a3_print_debug("[artico3-hw] close()  -> artico3_fd\n");

}


int artico3_kernel_create(const char *name, size_t membytes, size_t membanks, size_t regrw, size_t regro) {
    unsigned int index, i;
    struct a3_kernel *kernel = NULL;

    // Search first available ID; if none, return with error
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (kernels[index] == NULL) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name %s\n", name);
        return -EBUSY;
    }

    // Allocate memory for kernel info
    kernel = malloc(sizeof *kernel);
    if (!kernel) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        return -ENOMEM;
    }

    // Set kernel configuration
    kernel->name = malloc(strlen(name));
    if (!kernel->name) {
        a3_print_error("[artico3-hw] malloc() failed\n");
        free(kernel);
        return -ENOMEM;
    }
    strcpy(kernel->name, name);
    kernel->id = index + 1;
    kernel->membytes = ceil(((float)membytes / (float)membanks) / sizeof (a3data_t)) * sizeof (a3data_t) * membanks; // Fix to ensure all banks have integer number of 32-bit words
    kernel->membanks = membanks;
    kernel->regrw = regrw;
    kernel->regro = regro;
    kernel->inputs = malloc(membanks * sizeof *kernel->inputs);
    if (!kernel->inputs) {
        free(kernel->name);
        free(kernel);
        return -ENOMEM;
    }
    kernel->outputs = malloc(membanks * sizeof *kernel->outputs);
    if (!kernel->outputs) {
        free(kernel->inputs);
        free(kernel->name);
        free(kernel);
        return -ENOMEM;
    }
    for (i = 0; i < kernel->membanks; i++) {
        kernel->inputs[i] = NULL;
        kernel->outputs[i] = NULL;
    }
    a3_print_debug("[artico3-hw] created <a3_kernel> name=%s,id=%x,membytes=%d,membanks=%d,regrw=%d,regro=%d\n", kernel->name, kernel->id, kernel->membytes, kernel->membanks, kernel->regrw, kernel->regro);

    // Store kernel configuration in kernel list
    kernels[index] = kernel;

    return 0;
}

/*
 * ARTICo3 low-level hardware function
 *
 * Gets current number of available hardware accelerators for a given
 * kernel ID tag.
 *
 * @id : current kernel ID
 *
 * Returns : number of accelerators on success, error code otherwise
 *
 */
int artico3_hw_get_naccs(uint8_t id) {
    unsigned int i;
    int accelerators;

    uint64_t id_reg;
    uint64_t tmr_reg;
    uint64_t dmr_reg;

    uint8_t aux_id;
    uint8_t aux_tmr;
    uint8_t aux_dmr;

    // Get current shadow registers
    id_reg = shuffler.id_reg;
    tmr_reg = shuffler.tmr_reg;
    dmr_reg = shuffler.dmr_reg;

    // Compute number of equivalent accelerators
    // NOTE: this assumes correct Shuffler configuration ALWAYS, e.g.
    //           - no DMR groups with less than 2 elements
    //           - no TMR groups with less than 3 elements
    //           - ...
    accelerators = 0;
    while (id_reg) {
        aux_id  = id_reg  & 0xf;
        aux_tmr = tmr_reg & 0xf;
        aux_dmr = dmr_reg & 0xf;
        if (aux_id == id) {
            if (aux_tmr) {
                for (i = 1; i < A3_MAXSLOTS; i++) {
                    if (((id_reg >> (4 * i)) & 0xf) != aux_id) continue;
                    if (((tmr_reg >> (4 * i)) & 0xf) == aux_tmr) {
                        tmr_reg ^= tmr_reg & (0xf << (4 * i));
                        id_reg ^= id_reg & (0xf << (4 * i));
                    }
                }
            }
            else if (aux_dmr) {
                for (i = 1; i < A3_MAXSLOTS; i++) {
                    if (((id_reg >> (4 * i)) & 0xf) != aux_id) continue;
                    if (((dmr_reg >> (4 * i)) & 0xf) == aux_dmr) {
                        dmr_reg ^= dmr_reg & (0xf << (4 * i));
                        id_reg ^= id_reg & (0xf << (4 * i));
                    }
                }
            }
            accelerators++;
        }
        id_reg >>= 4;
        tmr_reg >>= 4;
        dmr_reg >>= 4;
    }
    if (!accelerators) {
        a3_print_error("[artico3-hw] no accelerators found with ID %x\n", id);
        return -ENODEV;
    }

    return accelerators;
}


/*
 * ARTICo3 low-level hardware function
 *
 * Gets, for the current accelerator setup, the expected mask to be used
 * when checking the ready register in the Data Shuffler.
 *
 * @id : current kernel ID
 *
 * Return : ready mask on success, 0 otherwise
 *
 */
uint32_t artico3_hw_get_readymask(uint8_t id) {
    unsigned int i;

    uint32_t ready;
    uint64_t id_reg;

    // Get current shadow registers
    id_reg = shuffler.id_reg;

    // Compute expected ready flag
    ready = 0;
    i = 0;
    while (id_reg) {
        if ((id_reg  & 0xf) == id) ready |= 0x1 << i;
        i++;
        id_reg >>= 4;
    }

    return ready;
}


int artico3_send(uint8_t id, int naccs, unsigned int round, unsigned int nrounds) {
    unsigned int acc, port;
    unsigned int nports;

    struct dmaproxy_token token;
    a3data_t *mem = NULL;

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

    // Copy inputs to physical memory (TODO: could it be possible to avoid this step?)
    for (acc = 0; acc < naccs; acc++) {
        for (port = 0; port < nports; port++) {        
            // When finishing, there could be more accelerators than rounds left
            if ((round + acc) < nrounds) {
                size_t size = (kernels[id - 1]->inputs[port]->size / sizeof (a3data_t)) / nrounds;
                size_t offset = round * size;
                uint32_t idx_mem = (port * (blksize / nports)) + (acc * blksize);
                uint32_t idx_dat = (acc * size) + offset;
                memcpy(&mem[idx_mem], &kernels[id - 1]->inputs[port]->data[idx_dat], size * sizeof (a3data_t));
                a3_print_debug("[artico3-hw] round %3d | acc %d | i_port %d | mem %4d | dat %6d | size %4d\n", round + acc, acc, port, idx_mem, idx_dat, size * sizeof (a3data_t));
            }
        }
    }

    // Configure ARTICo3
    artico3_hw[A3_ID_REG_LOW]     = shuffler.id_reg & 0xFFFFFFFF;          // ID register low
    artico3_hw[A3_ID_REG_HIGH]    = (shuffler.id_reg >> 32) & 0xFFFFFFFF;  // ID register high
    artico3_hw[A3_TMR_REG_LOW]    = shuffler.tmr_reg & 0xFFFFFFFF;         // TMR register low
    artico3_hw[A3_TMR_REG_HIGH]   = (shuffler.tmr_reg >> 32) & 0xFFFFFFFF; // TMR register high
    artico3_hw[A3_DMR_REG_LOW]    = shuffler.dmr_reg & 0xFFFFFFFF;         // DMR register low
    artico3_hw[A3_DMR_REG_HIGH]   = (shuffler.dmr_reg >> 32) & 0xFFFFFFFF; // DMR register high
    artico3_hw[A3_BLOCK_SIZE_REG] = blksize;                               // Block size (# 32-bit words)

    // Start DMA transfer
    token.memaddr = mem;
    token.memoff = 0x00000000;
    token.hwaddr = (void *)A3_SLOTADDR;
    token.hwoff = id << 16;
    token.size = naccs * blksize * sizeof *mem;
    ioctl(a3slots_fd, DMAPROXY_IOC_DMA_MEM2HW, &token);

    // Release allocated DMA memory
    munmap(mem, naccs * blksize * sizeof *mem);

    return 0;
}


int artico3_recv(uint8_t id, int naccs, unsigned int round, unsigned int nrounds) {
    unsigned int acc, port;
    unsigned int nports;

    struct dmaproxy_token token;
    a3data_t *mem = NULL;

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

    // Configure ARTICo3
    artico3_hw[A3_ID_REG_LOW]     = shuffler.id_reg & 0xFFFFFFFF;          // ID register low
    artico3_hw[A3_ID_REG_HIGH]    = (shuffler.id_reg >> 32) & 0xFFFFFFFF;  // ID register high
    artico3_hw[A3_TMR_REG_LOW]    = shuffler.tmr_reg & 0xFFFFFFFF;         // TMR register low
    artico3_hw[A3_TMR_REG_HIGH]   = (shuffler.tmr_reg >> 32) & 0xFFFFFFFF; // TMR register high
    artico3_hw[A3_DMR_REG_LOW]    = shuffler.dmr_reg & 0xFFFFFFFF;         // DMR register low
    artico3_hw[A3_DMR_REG_HIGH]   = (shuffler.dmr_reg >> 32) & 0xFFFFFFFF; // DMR register high
    artico3_hw[A3_BLOCK_SIZE_REG] = blksize;                               // Block size (# 32-bit words)

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
                memcpy(&kernels[id - 1]->outputs[port]->data[idx_dat], &mem[idx_mem], size * sizeof (a3data_t));
                a3_print_debug("[artico3-hw] round %3d | acc %d | o_port %d | mem %4d | dat %6d | size %4d\n", round + acc, acc, port, idx_mem, idx_dat, size * sizeof (a3data_t));
            }
        }
    }

    // Release allocated DMA memory
    munmap(mem, naccs * blksize * sizeof *mem);

    return 0;
}


/*
 * ARTICo3 execute hardware kernel
 *
 * @name  : name of the hardware kernel to execute
 * @gsize : global work size (total amount of work to be done)
 * @lsize : local work size (work that can be done by one accelerator)
 *
 * Return : 0 on success, error code otherwisw
 *
 */
int artico3_kernel_execute(const char *name, size_t gsize, size_t lsize) {
    unsigned int index, round, nrounds;
    int naccs;

    uint8_t id;
    uint32_t readymask;

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (strcmp(kernels[index]->name, name) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name %s\n", name);
        return -ENODEV;
    }

    // Get kernel ID
    id = kernels[index]->id;

    // Given current configuration, compute number of rounds
    if (gsize % lsize) {
        a3_print_error("[artico3-hw] gsize (%d) not integer multiple of lsize (%d)\n", gsize, lsize);
        return -EINVAL;
    }
    nrounds = gsize / lsize;
    
    a3_print_debug("[artico3-hw] executing kernel \"%s\" [gsize=%d,lsize=%d,rounds=%d]\n", name, gsize, lsize, nrounds);

    // Iterate over number of rounds
    round = 0;
    while (round < nrounds) {

        // For each iteration, compute number of (equivalent) accelerators,
        // and the corresponding expected mask to check the ready register.
        naccs = artico3_hw_get_naccs(id);
        readymask = artico3_hw_get_readymask(id);

        // Send data
        artico3_send(id, naccs, round, nrounds);

        // Wait until transfer is complete
        while ((artico3_hw[A3_READY_REG] & readymask) != readymask) ;

        // Receive data
        artico3_recv(id, naccs, round, nrounds);

        // Update the round index
        round += naccs;

    }

    return 0;
}


int artico3_kernel_release(const char *name) {
    unsigned int index;

    // Search for kernel in kernel list
    for (index = 0; index < A3_MAXKERNS; index++) {
        if (strcmp(kernels[index]->name, name) == 0) break;
    }
    if (index == A3_MAXKERNS) {
        a3_print_error("[artico3-hw] no kernel found with name %s\n", name);
        return -ENODEV;
    }

    // Free allocated memory
    free(kernels[index]->outputs);
    free(kernels[index]->inputs);
    free(kernels[index]->name);
    free(kernels[index]);
    a3_print_debug("[artico3-hw] released <a3_kernel> name=%s\n", name);

    // Set kernel list entry as empty
    kernels[index] = NULL;

    return 0;
}


void *artico3_alloc(size_t size, const char *kname, const char *pname, uint8_t dir) {
    struct a3_kport *port = NULL;
    unsigned int i, j, i2, j2;

    // Search for kernel in kernel list
    for (i = 0; i < A3_MAXKERNS; i++) {
        if (strcmp(kernels[i]->name, kname) == 0) break;
    }
    if (i == A3_MAXKERNS) return NULL;

    // Allocate memory for kernel port configuration
    port = malloc(sizeof *port);
    if (!port) {
        return NULL;
    }

    // Set port name
    port->name = malloc(strlen(pname));
    if (!port->name) {
        free(port);
        return NULL;
    }
    strcpy(port->name, pname);

    // Set port size
    port->size = size;

    // Allocate memory for application
    port->data = malloc(port->size);
    if (!port->data) {
        free(port->name);
        free(port);
        return NULL;
    }

    // Add port to kernel structure and bubble-sort it
    if (dir == 1) {
        j = 0;
        while (kernels[i]->inputs[j]) j++;
        kernels[i]->inputs[j] = port;
        for (i2 = 0; i2 < (kernels[i]->membanks - 1); i2++) {
            for (j2 = 0; j2 < (kernels[i]->membanks - 1 - i); j2++) {
                if (!kernels[i]->inputs[j2 + 1]) break;
                if (strcmp(kernels[i]->inputs[j2]->name, kernels[i]->inputs[j2 + 1]->name) > 0) {
                    struct a3_kport *aux = kernels[i]->inputs[j2 + 1];
                    kernels[i]->inputs[j2 + 1] = kernels[i]->inputs[j2 + 1];
                    kernels[i]->inputs[j2] = aux;
                }
            }
        }
    }
    else {
        j = 0;
        while (kernels[i]->outputs[j]) j++;
        kernels[i]->outputs[j] = port;
        for (i2 = 0; i2 < (kernels[i]->membanks - 1); i2++) {
            for (j2 = 0; j2 < (kernels[i]->membanks - 1 - i); j2++) {
                if (!kernels[i]->outputs[j2 + 1]) break;
                if (strcmp(kernels[i]->outputs[j2]->name, kernels[i]->outputs[j2 + 1]->name) > 0) {
                    struct a3_kport *aux = kernels[i]->outputs[j2 + 1];
                    kernels[i]->outputs[j2 + 1] = kernels[i]->outputs[j2 + 1];
                    kernels[i]->outputs[j2] = aux;
                }
            }
        }
    }

    // Return allocated memory
    return port->data;
}


int artico3_free(const char *kname, const char *pname) {
    struct a3_kport *port = NULL;
    unsigned int i, j;

    // Search for kernel in kernel list
    for (i = 0; i < A3_MAXKERNS; i++) {
        if (strcmp(kernels[i]->name, kname) == 0) break;
    }
    if (i == A3_MAXKERNS) return -ENODEV;

    // Search for port in port lists
    for (j = 0; j < kernels[i]->membanks; j++) {
        if (strcmp(kernels[i]->inputs[j]->name, pname) == 0) {
            port = kernels[i]->inputs[j];
            break;
        }
        else if (strcmp(kernels[i]->outputs[j]->name, pname) == 0) {
            port = kernels[i]->outputs[j];
            break;
        }
    }
    if (j == kernels[i]->membanks) return -ENODEV;

    // Free application memory
    free(port->data);

    // Free port name memory
    free(port->name);

    // Free port memory
    free(port);

    return 0;
}
