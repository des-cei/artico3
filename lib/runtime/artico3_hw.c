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
    unsigned int i;
    struct a3_kernel *kernel = NULL;

    // Search first available ID; if none, return with error
    for (i = 0; i < A3_MAXKERNS; i++) {
        if (kernels[i] == NULL) break;
    }
    if (i == A3_MAXKERNS) return -EBUSY;

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
    kernel->id = i + 1;
    kernel->membytes = ceil(((float)membytes / (float)membanks) / 4) * 4 * membanks; // Fix to ensure all banks have integer number of 32-bit words
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
    unsigned int j;
    for (j = 0; j < kernel->membanks; j++) {
        kernel->inputs[j] = NULL;
        kernel->outputs[j] = NULL;
    }
    a3_print_debug("[artico3-hw] created <a3_kernel> name=%s,id=%x,membytes=%d,membanks=%d,regrw=%d,regro=%d\n", kernel->name, kernel->id, kernel->membytes, kernel->membanks, kernel->regrw, kernel->regro);

    // Store kernel configuration in kernel list
    kernels[i] = kernel;

    return 0;
}


// IMPORTANT: NEEDS TO BE THREAD SAFE!!!, MAYBE A MUTEX IS REQUIRED TO ACCESS SHUFFLER DATA
int artico3_kernel_execute(const char *name, size_t gsize, size_t lsize) {
    unsigned int i;

    uint64_t id_reg;
    uint64_t tmr_reg;
    uint64_t dmr_reg;

    uint8_t id;
    uint32_t ready;
    size_t accelerators;
    size_t rounds;

    // Search for kernel in kernel list
    for (i = 0; i < A3_MAXKERNS; i++) {
        if (strcmp(kernels[i]->name, name) == 0) break;
    }
    if (i == A3_MAXKERNS) return -ENODEV;

    // Get kernel ID
    id = kernels[i]->id;
    a3_print_debug("[artico3-hw] artico3_kernel_execute() step 1 -> <a3_kernel> name=%s,id=%d\n", name, id);

    // Get current shadow registers
    id_reg = shuffler.id_reg;
    tmr_reg = shuffler.tmr_reg;
    dmr_reg = shuffler.dmr_reg;

    // Compute number of equivalent accelerators (assumes correct Shuffler configuration ALWAYS, e.g. no TMR groups with less than 3 elements)
    accelerators = 0;
    while (id_reg) {
        uint8_t aux_id  = id_reg  & 0xf;
        uint8_t aux_tmr = tmr_reg & 0xf;
        uint8_t aux_dmr = dmr_reg & 0xf;
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
        a3_print_error("[artico3-hw] <a3_kernel> name=%s,id=%d has no accelerators loaded\n", name, id);
        return -ENODEV;
    }
    a3_print_debug("[artico3-hw] artico3_kernel_execute() step 2 -> <a3_kernel> accelerators=%d\n", accelerators);

    // Given current configuration, compute number of rounds
    rounds = ceil((float)gsize / (float)(lsize * accelerators));
    a3_print_debug("[artico3-hw] artico3_kernel_execute() step 3 -> <a3_kernel> gsize=%d,lsize=%d,rounds=%d\n", gsize, lsize, rounds);

    // Compute expected ready flag
    id_reg = shuffler.id_reg;
    ready = 0;
    i = 0;
    while (id_reg) {
        if ((id_reg  & 0xf) == id) ready |= 0x1 << i;
        i++;
        id_reg >>= 4;
    }
    a3_print_debug("[artico3-hw] artico3_kernel_execute() step 4 -> <a3_kernel> ready=%08x\n", ready);

    // Iterate over number of rounds
    for (i = 0; i < rounds; i++) {

        // TODO: move equivalent accelerator computation here, and modify
        //       for loop so that the number of accelerators/rounds is
        //       updated after each iteration of the loop.

        // Send data
        artico3_send(id, accelerators, i, rounds);

        // Wait until transfer is complete
        while ((artico3_hw[A3_READY_REG] & ready) != ready) ;

        // Receive data
        artico3_recv(id, accelerators, i, rounds);

    }
    a3_print_debug("[artico3-hw] artico3_kernel_execute() step 5 -> <a3_kernel> end\n");

    return 0;
}


int artico3_kernel_release(const char *name) {
    unsigned int i;

    // Search for kernel in kernel list
    for (i = 0; i < A3_MAXKERNS; i++) {
        if (strcmp(kernels[i]->name, name) == 0) break;
    }
    if (i == A3_MAXKERNS) return -ENODEV;

    // Free allocated memory
    free(kernels[i]->name);
    free(kernels[i]);
    a3_print_debug("[artico3-hw] released <a3_kernel> name=%s\n", name);

    // Set kernel list entry as empty
    kernels[i] = NULL;

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


int artico3_send(uint8_t id, size_t accelerators, size_t round, size_t rounds) {
    uint32_t blksize;
    size_t nports = 0;
    struct dmaproxy_token token;
    a3data_t *mem = NULL;
    unsigned int i, j;

    // Get number of input ports
    for (i = 0; i < kernels[id - 1]->membanks; i++) {
        if (!kernels[id - 1]->inputs[i]) {
            nports = i;
            break;
        }
    }
    if (!nports) {
        return -ENODEV;
    }
    printf("Ports : %d\n", nports);

    // Compute block size (32-bit words per accelerator)
    blksize = ((kernels[id - 1]->membytes / kernels[id - 1]->membanks) * nports) / (sizeof (a3data_t));

    // Allocate DMA physical memory
    mem = mmap(NULL, blksize * accelerators * sizeof *mem, PROT_READ | PROT_WRITE, MAP_SHARED, a3slots_fd, 0);

    // Copy inputs to physical memory (TODO: could it be possible to avoid this step?)
    for (i = 0; i < nports; i++) {
        for (j = 0; j < accelerators; j++) {
            // TODO: this part requires handling in case size/rounds is not integer!!
            uint32_t i_mem = (i * blksize / nports) + (j * blksize);
            uint32_t i_dat = (j * ((kernels[id-1]->inputs[i]->size / rounds) / accelerators) + (round * (kernels[id-1]->inputs[i]->size / rounds))) / 4;
            uint32_t cpsize = (kernels[id-1]->inputs[i]->size / rounds) / accelerators;
            printf("port %d | acc %d | i_mem %6d | i_dat %6d | cpsize %6d\n", i, j, i_mem, i_dat, cpsize);
            a3data_t *data = &kernels[id - 1]->inputs[i]->data[i_dat];
            memcpy(&mem[i_mem], data, cpsize);
            printf("data %p %d\n", &kernels[id - 1]->inputs[i]->data[i_dat], data[0]);
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
    token.size = blksize * accelerators * sizeof *mem;
    ioctl(a3slots_fd, DMAPROXY_IOC_DMA_MEM2HW, &token);

    // Release allocated DMA memory
    munmap(mem,  blksize * accelerators * sizeof *mem);

    // DEBUG
    for (i = 0; i < 11; i++) {
        a3_print_debug("[artico3-hw] artico3_hw[%2d] : %08x\n", i, artico3_hw[i]);
    }
    // DEBUG

    return 0;
}
int artico3_recv(uint8_t id, size_t accelerators, size_t round, size_t rounds) {
    uint32_t blksize;
    size_t nports = 0;
    struct dmaproxy_token token;
    a3data_t *mem = NULL;
    unsigned int i, j;

    // Get number of input ports
    for (i = 0; i < kernels[id - 1]->membanks; i++) {
        if (!kernels[id - 1]->outputs[i]) {
            nports = i;
            break;
        }
    }
    if (!nports) {
        return -ENODEV;
    }
    printf("Ports : %d\n", nports);

    // Compute block size (32-bit words per accelerator)
    blksize = ((kernels[id - 1]->membytes / kernels[id - 1]->membanks) * nports) / (sizeof (a3data_t));

    // Allocate DMA physical memory
    mem = mmap(NULL, blksize * accelerators * sizeof *mem, PROT_READ | PROT_WRITE, MAP_SHARED, a3slots_fd, 0);

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
    token.hwoff = (id << 16) + (kernels[id - 1]->membanks - nports) * kernels[id - 1]->membytes / kernels[id - 1]->membanks;
    token.size = blksize * accelerators * sizeof *mem;
    ioctl(a3slots_fd, DMAPROXY_IOC_DMA_HW2MEM, &token);

    // Copy outputs from physical memory (TODO: could it be possible to avoid this step?)
    for (i = 0; i < nports; i++) {
        for (j = 0; j < accelerators; j++) {
            // TODO: this part requires handling in case size/rounds is not integer!!
            uint32_t i_mem = (i * blksize / nports) + (j * blksize);
            uint32_t i_dat = (j * ((kernels[id-1]->outputs[i]->size / rounds) / accelerators) + (round * (kernels[id-1]->outputs[i]->size / rounds))) / 4;
            uint32_t cpsize = (kernels[id-1]->outputs[i]->size / rounds) / accelerators;
            printf("port %d | acc %d | i_mem %6d | i_dat %6d | cpsize %6d\n", i, j, i_mem, i_dat, cpsize);
            a3data_t *data = &kernels[id - 1]->outputs[i]->data[i_dat];
            memcpy(data, &mem[i_mem], cpsize);
            printf("data[0] %d\n", data[0]);
            printf("data %p %d\n", &kernels[id - 1]->outputs[i]->data[i_dat], data[0]);
        }
    }

    // Release allocated DMA memory
    munmap(mem,  blksize * accelerators * sizeof *mem);

    // DEBUG
    for (i = 0; i < 11; i++) {
        a3_print_debug("[artico3-hw] artico3_hw[%2d] : %08x\n", i, artico3_hw[i]);
    }
    // DEBUG

    return 0;
}
