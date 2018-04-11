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

#define VALUES (1024) // Number of elements in each block

#define A3_INCREMENT_REG_0 (0x000)

int main(int argc, char *argv[]) {
    unsigned int i;
    struct timeval t0, tf;
    float t_hw;

    a3data_t *a = NULL;
    a3data_t *b = NULL;
    a3data_t *c = NULL;

    a3data_t wcfg[2] = {0x20, 0x10};
    a3data_t rcfg[2];

    /* APP */

    // Initialize ARTICo3 infrastructure
    artico3_init();

    // Create kernel instance
    artico3_kernel_create("increment", 12288, 3, 3, 3);

    // Load accelerators
    gettimeofday(&t0, NULL);
    artico3_load("increment", 0, 0, 2, 1);
    artico3_load("increment", 1, 0, 1, 1);
    artico3_load("increment", 2, 0, 1, 1);
    artico3_load("increment", 3, 0, 2, 1);
    gettimeofday(&tf, NULL);
    t_hw = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading : %.6f ms\n", t_hw);

    // Allocate data buffers
    a = artico3_alloc(2 * VALUES * sizeof *a, "increment", "a", A3_P_I);
    b = artico3_alloc(2 * VALUES * sizeof *b, "increment", "b", A3_P_O);
    c = artico3_alloc(2 * VALUES * sizeof *c, "increment", "c", A3_P_IO);

    // Initialize data buffers
    printf("Initializing data buffers...\n");
    srand(time(NULL));
    for (i = 0; i < (2 * VALUES); i++) {
        a[i] = 0;
        c[i] = 0;
    }

    // Configuration registers
    artico3_kernel_rcfg("increment", A3_INCREMENT_REG_0, rcfg);
    for (i = 0; i < 2; i++) printf("rcfg[%d] = %08x\n", i, rcfg[i]);
    for (i = 0; i < 2; i++) printf("wcfg[%d] = %08x\n", i, wcfg[i]);
    artico3_kernel_wcfg("increment", A3_INCREMENT_REG_0, wcfg);
    artico3_kernel_rcfg("increment", A3_INCREMENT_REG_0, rcfg);
    for (i = 0; i < 2; i++) printf("rcfg[%d] = %08x\n", i, rcfg[i]);

    // Execute kernel
    printf("Executing kernel 10 times...\n");
    gettimeofday(&t0, NULL);
    for (i = 0; i < 10; i++) {
        //~ artico3_kernel_reset("increment");
        artico3_kernel_execute("increment", 2 * VALUES, VALUES);
        artico3_kernel_wait("increment");
        printf("round: %6d | out: %08x | inout: %08x\n", i, b[0], c[0]);
        printf("round: %6d | out: %08x | inout: %08x\n", i, b[VALUES], c[VALUES]);
    }
    gettimeofday(&tf, NULL);
    t_hw = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel execution : %.6f ms\n", t_hw);

    // Check results
    printf("Checking results...\n");
    for (i = 0; i < (2 * VALUES); i++) {
        if (i % VALUES < 4) printf("%6d | out: %08x | inout: %08x\n", i, b[i], c[i]);
    }

    // Free data buffers
    artico3_free("increment", "a");
    artico3_free("increment", "b");
    artico3_free("increment", "c");

    // Release kernel instance
    artico3_kernel_release("increment");

    // Clean ARTICo3 setup
    artico3_exit();

    return 0;
}
