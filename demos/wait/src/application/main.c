/*
 * ARTICo3 test application
 * Parallel "wait" kernels
 *
 * Author : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date   : August 2017
 *
 * Main application
 *
 */

#include <stdio.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h> // struct timeval, gettimeofday()
#include <time.h>     // time()

#include "artico3.h"

#define BLOCKS (10)
#define VALUES (1024)

int main(int argc, char *argv[]) {
    unsigned int i, blocks;
    struct timeval t0, tf;
    float t;

    a3data_t *a = NULL;
    a3data_t *b = NULL;
    a3data_t *c = NULL;

    a3data_t *d = NULL;
    a3data_t *e = NULL;
    a3data_t *f = NULL;


    /* Command line parsing */

    printf("argc = %d\n", argc);
    for (i = 0; i < argc; i++) {
        printf("argv[%d] = %s\n", i, argv[i]);
    }

    blocks = 0;
    if (argc > 1) {
        blocks = atoi(argv[1]);
    }
    blocks = ((blocks < 10000) && (blocks > 0)) ? blocks : BLOCKS;
    printf("Using %d blocks\n", blocks);


    /* APP */

    // Initialize ARTICo3 infrastructure
    artico3_init();

    // Create kernel instance
    artico3_kernel_create("wait1s", 16384, 3, 3, 3);
    artico3_kernel_create("wait4s", 16384, 3, 3, 3);

    // Load accelerators
    gettimeofday(&t0, NULL);
    artico3_load("wait1s", 0, 1, 0, 1);
    artico3_load("wait1s", 1, 1, 0, 1);
    artico3_load("wait1s", 2, 1, 0, 1);
    artico3_load("wait4s", 3, 0, 0, 1);
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading : %.6f ms\n", t);

    gettimeofday(&t0, NULL);
    artico3_load("wait1s", 0, 1, 0, 0);
    artico3_load("wait1s", 1, 1, 0, 0);
    artico3_load("wait1s", 2, 1, 0, 0);
    artico3_load("wait4s", 3, 0, 0, 0);
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading (no force) : %.6f ms\n", t);

    // Allocate data buffers
    a = artico3_alloc(blocks * VALUES * sizeof *a, "wait1s", "a", A3_P_I);
    b = artico3_alloc(blocks * VALUES * sizeof *b, "wait1s", "b", A3_P_I);
    c = artico3_alloc(blocks * VALUES * sizeof *c, "wait1s", "c", A3_P_O);

    d = artico3_alloc(blocks * VALUES * sizeof *d, "wait4s", "a", A3_P_I);
    e = artico3_alloc(blocks * VALUES * sizeof *e, "wait4s", "b", A3_P_I);
    f = artico3_alloc(blocks * VALUES * sizeof *f, "wait4s", "c", A3_P_O);


    // Initialize data buffers
    printf("Initializing data buffers...\n");
    srand(time(NULL));
    for (i = 0; i < (blocks * VALUES); i++) {
        a[i] = rand();
        b[i] = rand();
        c[i] = 0;

        d[i] = rand();
        e[i] = rand();
        f[i] = 0;
    }

    // Execute kernels
    printf("Executing kernels sequentially...\n");
    gettimeofday(&t0, NULL);

    printf("Starting wait1s...\n");
    artico3_kernel_execute("wait1s", (blocks * VALUES), VALUES);
    artico3_kernel_wait("wait1s");

    printf("Starting wait4s...\n");
    artico3_kernel_execute("wait4s", (blocks * VALUES), VALUES);
    artico3_kernel_wait("wait4s");

    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel execution : %.6f ms\n", t);


    printf("Executing kernels in parallel...\n");
    gettimeofday(&t0, NULL);

    printf("Starting wait1s...\n");
    artico3_kernel_execute("wait1s", (blocks * VALUES), VALUES);
    printf("Starting wait4s...\n");
    artico3_kernel_execute("wait4s", (blocks * VALUES), VALUES);

    artico3_kernel_wait("wait1s");
    artico3_kernel_wait("wait4s");

    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel execution : %.6f ms\n", t);

    // Free data buffers
    artico3_free("wait1s", "a");
    artico3_free("wait1s", "b");
    artico3_free("wait1s", "c");

    artico3_free("wait4s", "a");
    artico3_free("wait4s", "b");
    artico3_free("wait4s", "c");

    // Release kernel instance
    artico3_kernel_release("wait1s");
    artico3_kernel_release("wait4s");

    // Clean ARTICo3 setup
    artico3_exit();

    return 0;
}
