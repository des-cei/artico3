/*
 * ARTICo3 test application
 * Array addition
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

#define BLOCKS (10)   // Number of blocks to process
#define VALUES (1024) // Number of elements in each block

int main(int argc, char *argv[]) {
    unsigned int i, errors, blocks;
    struct timeval t0, tf;
    float t_hw, t_sw;

    a3data_t *a = NULL;
    a3data_t *b = NULL;
    a3data_t *c = NULL;

    a3data_t *sw = NULL;


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
    artico3_kernel_create("addvector", 16384, 3, 0);

    // Load accelerators
    gettimeofday(&t0, NULL);
    artico3_load("addvector", 0, 0, 0, 1);
    artico3_load("addvector", 1, 1, 0, 1);
    artico3_load("addvector", 2, 1, 0, 1);
    artico3_load("addvector", 3, 1, 0, 1);
    gettimeofday(&tf, NULL);
    t_hw = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading : %.6f ms\n", t_hw);

    gettimeofday(&t0, NULL);
    artico3_load("addvector", 0, 0, 0, 0);
    artico3_load("addvector", 1, 1, 0, 0);
    artico3_load("addvector", 2, 1, 0, 0);
    artico3_load("addvector", 3, 1, 0, 0);
    gettimeofday(&tf, NULL);
    t_hw = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading (no force): %.6f ms\n", t_hw);

    // Allocate data buffers
    a = artico3_alloc(blocks * VALUES * sizeof *a, "addvector", "a", A3_P_I);
    b = artico3_alloc(blocks * VALUES * sizeof *b, "addvector", "b", A3_P_I);
    c = artico3_alloc(blocks * VALUES * sizeof *c, "addvector", "c", A3_P_O);

    // Allocate memory for software result
    sw = malloc(blocks * VALUES * sizeof *sw);

    // Initialize data buffers
    printf("Initializing data buffers...\n");
    srand(time(NULL));
    for (i = 0; i < (blocks * VALUES); i++) {
        a[i] = rand();
        b[i] = rand();
        c[i] = 0;
    }

    // Execute kernel
    printf("Executing kernel...\n");
    gettimeofday(&t0, NULL);
    artico3_kernel_execute("addvector", (blocks * VALUES), VALUES);
    artico3_kernel_wait("addvector");
    gettimeofday(&tf, NULL);
    t_hw = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel execution : %.6f ms\n", t_hw);

    // Execute software reference
    printf("Executing software...\n");
    gettimeofday(&t0, NULL);
    for (i = 0; i < (blocks * VALUES); i++) {
        sw[i] = a[i] + b[i];
    }
    gettimeofday(&tf, NULL);
    t_sw = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Software execution : %.6f ms\n", t_sw);
    printf("Speedup : %.6f\n", t_sw / t_hw);

    // Check results vs. software reference
    printf("Checking results...\n");
    errors = 0;
    for (i = 0; i < (blocks * VALUES); i++) {
        if (((i % VALUES) < 4) && ((i / VALUES) < 4)) printf("%6d | %08x\n", i, c[i]);
        if (c[i] != sw[i]) errors++;
    }
    printf("Found %d errors\n", errors);

    // Free software result memory
    free(sw);

    // Free data buffers
    artico3_free("addvector", "a");
    artico3_free("addvector", "b");
    artico3_free("addvector", "c");

    // Release kernel instance
    artico3_kernel_release("addvector");

    // Clean ARTICo3 setup
    artico3_exit();

    return 0;
}
