#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <time.h>
#include <fcntl.h>

#include <sys/ioctl.h>
#include "../../../linux/drivers/dmaproxy/dmaproxy.h"

#define SLOTS  (4)
#define VALUES (10)
#define ID     (0xa)
#define HWADDR (0x8aa00000)
#define DEVICE "/dev/dmaproxy0"

#define ARTICo3_ADDR (0x7aa00000)

int main(int argc, char *argv[]) {
    int fd;
    unsigned int i, errors;
    struct dmaproxy_token token;
    uint32_t *mem = NULL;
    uint32_t *gld = NULL;
    struct timeval t0, tf;
    float t, tg;

    /* ARTICo3 configuration */

    int fmem;
    uint32_t *artico3 = NULL;
    uint64_t id;

    // Open file (R/W)
    fmem = open("/dev/mem", O_RDWR);
    if (!fmem) {
        printf("File /dev/mem could not be opened\n");
        return -ENODEV;
    }
    printf("Opened /dev/mem\n");

    // Map user-space memory to physical memory
    artico3 = mmap(0, 0x100000, PROT_READ | PROT_WRITE, MAP_SHARED, fmem, ARTICo3_ADDR);
    if (artico3 == MAP_FAILED) {
        printf("mmap() failed\n");
        close(fmem);
        return -ENOMEM;
    }
    printf("Assigned memory region: %p\n", artico3);

    /* ARTICo3 configuration */

    // Allocate memory for golden (SW) copy
    gld = malloc(VALUES * SLOTS * sizeof *gld);
    if (!gld) {
        printf("malloc() failed\n");
        munmap(artico3, 0x100000);
        close(fmem);
        return -ENOMEM;
    }

    // Open file (R/W)
    fd = open(DEVICE, O_RDWR);
    if (!fd) {
        printf("File %s could not be opened\n", DEVICE);
        free(gld);
        munmap(artico3, 0x100000);
        close(fmem);
        return -ENODEV;
    }
    printf("Opened %s\n", DEVICE);

    // Map user-space memory to kernel-space, DMA-allocated memory
    mem = mmap(NULL, VALUES * SLOTS * sizeof *mem, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (mem == MAP_FAILED) {
        printf("mmap() failed\n");
        munmap(artico3, 0x100000);
        free(gld);
        close(fmem);
        close(fd);
        return -ENOMEM;
    }
    printf("Assigned memory region: %p\n", mem);

    // Write to memory
    srand(time(NULL));
    gettimeofday(&t0, NULL);
    for (i = 0; i < (VALUES * SLOTS); i++) {
        //~ mem[i] = rand();
        mem[i] = i + 1;
        gld[i] = mem[i];
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg = t;
    printf("Memory write : %.6f ms\n", t);

    // Configure ARTICo3
    gettimeofday(&t0, NULL);

    id = 0;
    for (i = 0; i < SLOTS; i++) {
        id |= ID << (4 * i);
    }
    artico3[0] = id & 0xFFFFFFFF;         // ID register low
    artico3[1] = (id >> 32) & 0xFFFFFFFF; // ID register high
    artico3[2] = 0x00000000;              // TMR register low
    artico3[3] = 0x00000000;              // TMR register high
    artico3[4] = 0x00000000;              // DMR register low
    artico3[5] = 0x00000000;              // DMR register high
    artico3[6] = VALUES;                  // Block size (# 32-bit words)
    artico3[7] = 0x0000000F;              // Clock enable register

    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("ARTICo3 configuration : %.6f ms\n", t);

    // Send data from memory to hardware
    gettimeofday(&t0, NULL);

    token.memaddr = mem;
    token.memoff = 0x00000000;
    token.hwaddr = (void *)HWADDR;
    token.hwoff = ID << 16;
    token.size = VALUES * SLOTS * sizeof *mem;
    printf("Sending data to hardware...\n");
    ioctl(fd, DMAPROXY_IOC_DMA_MEM2HW, &token);

    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("ARTICo3 send : %.6f ms\n", t);

    // Wait until ARTICo3 is ready
    gettimeofday(&t0, NULL);

    while (!artico3[10]) ;
    printf("Ready: %08x\n", artico3[10]);

    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("ARTICo3 ready : %.6f ms\n", t);

    // Erase memory
    gettimeofday(&t0, NULL);
    for (i = 0; i < (VALUES * SLOTS); i++) {
        mem[i] = 0;
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("Memory erase : %.6f ms\n", t);

    // Configure ARTICo3
    gettimeofday(&t0, NULL);

    id = 0;
    for (i = 0; i < SLOTS; i++) {
        id |= ID << (4 * i);
    }
    artico3[0] = id & 0xFFFFFFFF;         // ID register low
    artico3[1] = (id >> 32) & 0xFFFFFFFF; // ID register high
    artico3[2] = 0x00000000;              // TMR register low
    artico3[3] = 0x00000000;              // TMR register high
    artico3[4] = 0x00000000;              // DMR register low
    artico3[5] = 0x00000000;              // DMR register high
    artico3[6] = VALUES;                  // Block size (# 32-bit words)
    artico3[7] = 0x0000000F;              // Clock enable register

    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("ARTICo3 configuration : %.6f ms\n", t);

    // Send data from hardware to memory
    gettimeofday(&t0, NULL);

    token.memaddr = mem;
    token.memoff = 0x00000000;
    token.hwaddr = (void *)HWADDR;
    token.hwoff = ID << 16;
    token.size = VALUES * SLOTS * sizeof *mem;
    printf("Receiving data from hardware...\n");
    ioctl(fd, DMAPROXY_IOC_DMA_HW2MEM, &token);

    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("ARTICo3 receive : %.6f ms\n", t);

    // Compare against golden reference
    gettimeofday(&t0, NULL);
    errors = 0;
    for (i = 0; i < (VALUES * SLOTS); i++) {
        printf("%3d | %08x | %08x\n", i, mem[i], gld[i]);
        if (mem[i] != gld[i]) {
            errors++;
        }
    }
    printf("Found %d errors\n", errors);
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("Error checking : %.6f ms\n", t);

    printf("Total time : %.6f ms\n", tg);

    // Unmap user-space memory from kernel-space
    munmap(mem, VALUES * SLOTS * sizeof *mem);
    printf("Released memory region\n");

    // Close file
    close(fd);
    printf("Closed %s\n", DEVICE);

    // Release memory
    free(gld);

    /* ARTICo3 configuration */

    // Unmap user-space memory
    munmap(artico3, 0x100000);
    printf("Released ARTICo3 handler\n");

    // Close file
    close(fmem);
    printf("Closed /dev/mem\n");

    /* ARTICo3 configuration */

    return 0;
}
