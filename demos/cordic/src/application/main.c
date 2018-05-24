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
#include <math.h>
#include <float.h>    // FLT_MIN

#include "artico3.h"

#define NACCS  (4)
#define VALUES (4096)

int main(int argc, char *argv[]) {
    unsigned int i, j, naccs, errors;
    float max_error;

    struct timeval t0, tf;
    float t;

    a3data_t *phase  = NULL;
    a3data_t *cosine = NULL;
    a3data_t *sine   = NULL;

    /* Command line parsing */

    printf("argc = %d\n", argc);
    for (i = 0; i < argc; i++) {
        printf("argv[%d] = %s\n", i, argv[i]);
    }

    naccs = 0;
    if (argc > 1) {
        naccs = atoi(argv[1]);
    }
    naccs = ((naccs > 0) && (naccs <= NACCS)) ? naccs : NACCS;
    printf("Using %d accelerator(s)\n", naccs);


    /* APP */

    // Initialize ARTICo3 infrastructure
    artico3_init();

    // Create kernel instance
    artico3_kernel_create("cordic", 49152, 3, 0);

    // Load accelerators
    gettimeofday(&t0, NULL);
    for (i = 0; i < naccs; i++) {
        artico3_load("cordic", i, 0, 0, 0);
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading : %.6f ms\n", t);

    // Allocate data buffers
    phase  = artico3_alloc(naccs * VALUES * sizeof *phase, "cordic", "port0", A3_P_I);
    cosine = artico3_alloc(naccs * VALUES * sizeof *cosine, "cordic", "port1", A3_P_O);
    sine   = artico3_alloc(naccs * VALUES * sizeof *sine, "cordic", "port2", A3_P_O);

    // Initialize data buffers
    printf("Initializing data buffers...\n");
    srand(time(NULL));
    for (i = 0; i < naccs; i++) {
        for (j = 0; j < VALUES; j++) {
            phase[(i * VALUES) + j] = (int32_t)((1 << 29) * (-M_PI + (j * ((2 * M_PI) / VALUES))));
        }
    }

    // Reset accelerators
    artico3_kernel_reset("cordic");

    // Execute kernels
    printf("Executing kernel..\n");
    gettimeofday(&t0, NULL);
    artico3_kernel_execute("cordic", naccs * VALUES, VALUES);
    artico3_kernel_wait("cordic");
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel execution : %.6f ms\n", t);

    // Check results
    printf("Checking results...\n");
    errors = 0;
    max_error = 0.0;
    for (i = 0; i < naccs; i++) {
        for (j = 0; j < VALUES; j++) {
            float phase_hw, cos_sw, sin_sw, cos_hw, sin_hw, error;
            phase_hw  = ((float)(int32_t)phase[(i * VALUES) + j]) / (1 << 29);
            cos_sw    = cos(phase_hw);
            sin_sw    = sin(phase_hw);
            cos_hw    = ((float)(int32_t)cosine[(i * VALUES) + j]) / (1 << 30);
            sin_hw    = ((float)(int32_t)sine[(i * VALUES) + j]) / (1 << 30);
            error     = fabsf(cos_hw - cos_sw);
            max_error = (error > max_error) ? error : max_error;
            if (error > 1e-6) errors++;
            if ((i == 0) && (j % (VALUES / 32)) == 0) {
                printf("acc : %2u | HW | phase : %11.6f | cosine : %11.6f | sine : %11.6f \n", i, phase_hw, cos_hw, sin_hw);
                printf("         | SW | phase : %11.6f | cosine : %11.6f | sine : %11.6f \n", phase_hw, cos_sw, sin_sw);
                printf("         |    | error : %11g | maxerr : %11g |\n", error, max_error);
            }
        }
    }
    printf("Found %d errors\n", errors);
    printf("Maximum absolute error is %g\n", max_error);

    // Free data buffers
    artico3_free("cordic", "port0");
    artico3_free("cordic", "port1");
    artico3_free("cordic", "port2");

    // Release kernel instance
    artico3_kernel_release("cordic");

    // Clean ARTICo3 setup
    artico3_exit();

    return 0;
}
