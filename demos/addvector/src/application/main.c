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
#include <math.h>
#include <string.h>
#include <sys/ioctl.h>

#include "dmaproxy.h"

// Kernel config
#define SLOTS    (3)
#define MEMSIZE  (16384)
#define MEMBANKS (3)
#define ID       (0xa)
#define VALUES   (1024)

// ARTICo3 config
#define A3SHUFF  (0x7aa00000)
#define A3SLOTS  (0x8aa00000)
#define DMADEV   "/dev/dmaproxy0"

int main(int argc, char *argv[]) {
    int fd;
    unsigned int i, j, values, slots, errors;
    struct dmaproxy_token token;
    uint32_t *a = NULL;
    uint32_t *b = NULL;
    uint32_t *c = NULL;
    uint32_t *mem = NULL;
    uint32_t *gld = NULL;
    struct timeval t0, tf;
    float t, tg;

    /* Command line parsing */

    printf("argc = %d\n", argc);
    for (i = 0; i < argc; i++) {
        printf("argv[%d] = %s\n", i, argv[i]);
    }

    slots = 0;
    if (argc > 1) {
        slots = atoi(argv[1]);
    }
    slots = ((slots < SLOTS) && (slots > 0)) ? slots : SLOTS;
    printf("Using %d slots\n", slots);


    /* ARTICo3 configuration */

    int fmem;
    uint32_t *artico3 = NULL;
    uint64_t id;

    // Open file (R/W)
    fmem = open("/dev/mem", O_RDWR);
    printf("Opened /dev/mem\n");

    // Map user-space memory to physical memory
    artico3 = mmap(0, 0x100000, PROT_READ | PROT_WRITE, MAP_SHARED, fmem, A3SHUFF);
    printf("Assigned memory region: %p\n", artico3);

    // Reset accelerators
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
    artico3[6] = 0x00000000;              // Block size (# 32-bit words)
    artico3[7] = 0x0000000F;              // Clock enable register
    artico3[(ID << 14) + (0x1 << 10)] = 0x1;
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg = t;
    printf("Accelerator reset : %.6f ms\n", t);

    /* ARTICo3 configuration */


    // Generate input data
    srand(time(NULL));
    a = malloc(VALUES * slots * sizeof *a);
    b = malloc(VALUES * slots * sizeof *b);
    c = malloc(VALUES * slots * sizeof *c);
    gettimeofday(&t0, NULL);
    for (i = 0; i < (VALUES * slots); i++) {
        a[i] = i;
        b[i] = i + 2;
        //~ a[i] = rand();
        //~ b[i] = rand();
        c[i] = 0;
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("Data generation : %.6f ms\n", t);

    // Compute golden copy
    gld = malloc(VALUES * slots * sizeof *gld);
    gettimeofday(&t0, NULL);
    for (i = 0; i < (VALUES * slots); i++) {
        gld[i] = a[i] + b[i];
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("Golden reference generation : %.6f ms\n", t);


    /* ARTICo3 memory allocation */

    // Compute amount of memory inside each accelerator (in 32-bit words)
    values = (ceil(((float)MEMSIZE / (float)MEMBANKS) / 4) * MEMBANKS);

    // Open file (R/W)
    fd = open(DMADEV, O_RDWR);
    printf("Opened %s\n", DMADEV);

    // Map user-space memory to kernel-space, DMA-allocated memory
    mem = mmap(NULL, 2 * (values / MEMBANKS) * slots * sizeof *mem, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    printf("Assigned memory region: %p\n", mem);

    // Write to memory
    gettimeofday(&t0, NULL);
    for (i = 0; i < slots; i++) {
        for (j = 0; j < VALUES; j++) {
            mem[j + (i * 2 * (values / MEMBANKS))] = a[j + (i * VALUES)];
            mem[j + (values / MEMBANKS) + (i * 2 * (values / MEMBANKS))] = b[j + (i * VALUES)];
        }
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("Data preparation (+copy to physical memory) : %.6f ms\n", t);

    //~ for (i = 0; i < (2 * (values / MEMBANKS) * slots) / 4; i++) {
        //~ printf("%6d | %d\n", i, mem[i]);
    //~ }

    /* ARTICo3 memory allocation */


    /* ARTICo3 data send */

    // Configure ARTICo3
    gettimeofday(&t0, NULL);

    id = 0;
    for (i = 0; i < slots; i++) {
        id |= ID << (4 * i);
    }
    artico3[0] = id & 0xFFFFFFFF;         // ID register low
    artico3[1] = (id >> 32) & 0xFFFFFFFF; // ID register high
    artico3[2] = 0x00000000;              // TMR register low
    artico3[3] = 0x00000000;              // TMR register high
    artico3[4] = 0x00000000;              // DMR register low
    artico3[5] = 0x00000000;              // DMR register high
    artico3[6] = 2 * (values / MEMBANKS); // Block size (# 32-bit words)
    artico3[7] = 0x0000000F;              // Clock enable register

    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("ARTICo3 configuration : %.6f ms\n", t);

    // Send data from memory to hardware
    gettimeofday(&t0, NULL);

    token.memaddr = mem;
    token.memoff = 0x00000000;
    token.hwaddr = (void *)A3SLOTS;
    token.hwoff = ID << 16;
    token.size = 2 * (values / MEMBANKS) * slots * sizeof *mem;
    printf("Sending data to hardware...\n");
    ioctl(fd, DMAPROXY_IOC_DMA_MEM2HW, &token);

    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("ARTICo3 send : %.6f ms\n", t);

    /* ARTICo3 data send */


    // Wait until ARTICo3 is ready
    gettimeofday(&t0, NULL);

    uint32_t ready = 0;
    for (i = 0; i < slots; i++) {
        ready |= 1 << i;
    }
    printf("Expected ready -> %08x\n", ready);

    while ((artico3[10] & ready) != ready) ;
    printf("Ready register -> %08x | Masked -> %08x\n", artico3[10], artico3[10] & ready);

    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("ARTICo3 ready : %.6f ms\n", t);


    /* ARTICo3 data receive */

    // Configure ARTICo3
    gettimeofday(&t0, NULL);

    id = 0;
    for (i = 0; i < slots; i++) {
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
    token.hwaddr = (void *)A3SLOTS;
    token.hwoff = (ID << 16) + (2 * (values / MEMBANKS) * sizeof *mem);
    token.size = VALUES * slots * sizeof *mem;
    printf("Receiving data from hardware...\n");
    ioctl(fd, DMAPROXY_IOC_DMA_HW2MEM, &token);

    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    tg += t;
    printf("ARTICo3 receive : %.6f ms\n", t);

    /* ARTICo3 data receive */


    // Get results from physical memory to variable
    memcpy(c, mem, VALUES * slots * sizeof *mem);

    // Compare against golden reference
    gettimeofday(&t0, NULL);
    errors = 0;
    for (i = 0; i < (VALUES * slots); i++) {
        if (i % (VALUES) < 4) {
            printf("%5d | %08x | %08x\n", i, c[i], gld[i]);
        }
        if (c[i] != gld[i]) {
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
    munmap(mem, 2 * (values / MEMBANKS) * slots * sizeof *mem);
    printf("Released memory region\n");

    // Close file
    close(fd);
    printf("Closed %s\n", DMADEV);

    // Release memory
    free(gld);
    free(c);
    free(b);
    free(a);

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
