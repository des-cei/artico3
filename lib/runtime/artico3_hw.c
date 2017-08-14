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

#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

#include <sys/mman.h>  // mmap()

#include "../../linux/drivers/dmaproxy/dmaproxy.h" // TODO: use Makefile
#include "artico3_hw.h"


#define BUFFER_SIZE (64)


/*
 * ARTICo3 global variables
 *
 * @artico_fd : /dev/uioX file descriptor (used for interrupt management)
 * @artico_hw : user-space map of ARTICo3 hardware registers
 *
 * @shuffler  : current ARTICo3 infrastructure configuration
 *
 */

static int artico3_fd;
static uint32_t *artico3_hw = NULL;

static struct a3_shuffler shuffler = {
    .id_reg      = 0x0000000000000000,
    .tmr_reg     = 0x0000000000000000,
    .dmr_reg     = 0x0000000000000000,
    .blksize_reg = 0x00000000,
    .clkgate_reg = 0x00000000,
    .nslots      = 0,
    .slots       = NULL,
};


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
    int fd;
    char filename[BUFFER_SIZE];
    char buffer[BUFFER_SIZE];
    unsigned int i;

    // Find the appropriate device file
    i = 0;
    while (1) {
        sprintf(filename, "/sys/class/uio/uio%d/name", i);
        fd = open(filename, O_RDONLY);
        if (fd < 0) {
            a3_print_error("[artico3-hw] open() %s failed\n", filename);
            return -ENOENT;
        }
        read(fd, buffer, sizeof buffer);
        close(fd);
        if (strcmp(buffer, "artico3_shuffler\n") == 0) {
            a3_print_debug("[artico3-hw] found \"artico3_shuffler\" in %s\n", filename);
            break;
        }
        i++;
    }

    // Open UIO device file
    sprintf(filename, "/dev/uio%d", i);
    artico3_fd = open(filename, O_RDWR);
    if (artico3_fd < 0) {
        a3_print_error("[artico3-hw] open() %s failed\n", filename);
        return -ENOENT;
    }
    a3_print_debug("[artico3-hw] open()   -> artico3_fd : %d\n", artico3_fd);

    // Obtain access to physical memory map using mmap()
    artico3_hw = mmap(NULL, 0x100000, PROT_READ | PROT_WRITE, MAP_SHARED, artico3_fd, 0);
    if (artico3_hw == MAP_FAILED) {
        a3_print_error("[artico3-hw] mmap() failed\n");
        close(artico3_fd);
        return -ENOMEM;
    }
    a3_print_debug("[artico3-hw] mmap()   -> artico3_hw : %p\n", artico3_hw);

    // Initialize Shuffler structure
    shuffler.nslots = 4; // TODO: make this using a3dk parser (<a3<NUM_SLOTS>a3>)
    shuffler.slots = malloc(shuffler.nslots * sizeof (struct a3_slot));
    a3_print_debug("[artico3-hw] malloc() -> shuffler.slots : %p\n", shuffler.slots);
    for (i = 0; i < shuffler.nslots; i++) {
        shuffler.slots[i].kernel = NULL;
        shuffler.slots[i].state  = S_EMPTY;
    }

    // DEBUG
    artico3_hw[A3_CLOCK_GATE_REG_OFFSET] = 0x0000000f;
    for (i = 0; i < 20; i++) {
        a3_print_debug("[artico3-hw] artico3_hw[%2d] : %08x\n", i, artico3_hw[i]);
    }
    // DEBUG

    return 0;
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

    // Release memory obtained with mmap()
    munmap(artico3_hw, 0x100000);
    a3_print_debug("[artico3-hw] munmap() -> artico3_hw\n");

    // Close UIO device file
    close(artico3_fd);
    a3_print_debug("[artico3-hw] close()  -> artico3_fd\n");

}
