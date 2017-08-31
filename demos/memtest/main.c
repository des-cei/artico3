#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

#include <sys/mman.h>

#include <time.h>
#include <sys/time.h>

#include "../../linux/drivers/dmaproxy/dmaproxy.h"

#define VALUES (16 * 64 * 1024 / 4)
#define ROUNDS (4096)
#define DMADEV "/dev/dmaproxy0"

int main(int argc, char *argv[]) {
    unsigned int i, j, values, rounds;
    int fd;
    uint32_t *data = NULL;
    uint32_t *virt = NULL;
    uint32_t *phys = NULL;
    uint32_t acc;

    struct timeval t0, tf;
    float t_p, t_v;

    values = 0;
    if (argc > 1) {
        values = atoi(argv[1]);
    }
    values = ((values > 0) && (values <= VALUES)) ? values : VALUES;

    rounds = 0;
    if (argc > 2) {
        rounds = atoi(argv[2]);
    }
    rounds = ((rounds > 0) && (rounds <= ROUNDS)) ? rounds : ROUNDS;

    srand(time(NULL));

    printf("Working with %d round(s) of %d 32-bit word(s)\n", rounds, values);

    data = malloc(values * sizeof *data);
    for (i = 0; i < values; i++) {
        //~ data[i] = rand();
        data[i] = i + 1;
    }

    virt = malloc(values * sizeof *virt);

    fd = open(DMADEV, O_RDWR);
    phys = mmap(NULL, values * sizeof *phys, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);

    gettimeofday(&t0, NULL);
    for (j = 0; j < rounds; j++) {
        for (i = 0; i < values; i++) {
            virt[i] = data[i];
        }
    }
    gettimeofday(&tf, NULL);
    t_v = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Virtual memory write : %.3f ms\n", t_v);

    gettimeofday(&t0, NULL);
    for (j = 0; j < rounds; j++) {
        for (i = 0; i < values; i++) {
            phys[i] = data[i];
        }
    }
    gettimeofday(&tf, NULL);
    t_p = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Physical memory write : %.3f ms\n", t_p);
    printf("Ratio : %.3f\n", t_p / t_v);

    gettimeofday(&t0, NULL);
    for (j = 0; j < rounds; j++) {
        memcpy(virt, data, values * sizeof *virt);
    }
    gettimeofday(&tf, NULL);
    t_v = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Virtual memcpy write : %.3f ms\n", t_v);

    gettimeofday(&t0, NULL);
    for (j = 0; j < rounds; j++) {
        memcpy(phys, data, values * sizeof *phys);
    }
    gettimeofday(&tf, NULL);
    t_p = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Physical memcpy write : %.3f ms\n", t_p);
    printf("Ratio : %.3f\n", t_p / t_v);

    gettimeofday(&t0, NULL);
    acc = 0;
    for (j = 0; j < rounds; j++) {
        for (i = 0; i < values; i++) {
            acc += virt[i];
        }
    }
    gettimeofday(&tf, NULL);
    t_v = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("acc = %08x\n", acc);
    printf("Virtual memory read : %.3f ms\n", t_v);

    gettimeofday(&t0, NULL);
    acc = 0;
    for (j = 0; j < rounds; j++) {
        for (i = 0; i < values; i++) {
            acc += phys[i];
        }
    }
    gettimeofday(&tf, NULL);
    t_p = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("acc = %08x\n", acc);
    printf("Physical memory read : %.3f ms\n", t_p);
    printf("Ratio : %.3f\n", t_p / t_v);

    gettimeofday(&t0, NULL);
    for (j = 0; j < rounds; j++) {
        memcpy(data, virt, values * sizeof *data);
    }
    gettimeofday(&tf, NULL);
    t_v = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Virtual memcpy read : %.3f ms\n", t_v);

    gettimeofday(&t0, NULL);
    for (j = 0; j < rounds; j++) {
        memcpy(data, phys, values * sizeof *data);
    }
    gettimeofday(&tf, NULL);
    t_p = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Physical memcpy read : %.3f ms\n", t_p);
    printf("Ratio : %.3f\n", t_p / t_v);

    munmap(phys, values * sizeof *phys);

    free(virt);

    free(data);

    return 0;
}
