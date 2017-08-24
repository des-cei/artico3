#include <stdio.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <time.h>

#include "artico3.h"

#define MSIZE_APP (512)
#define MSIZE_ACC (64)

void matmul_sw(int size, a3data_t a[size], a3data_t b[size], a3data_t c[size]) {
    unsigned int i, j, k;

    for (i = 0; i < size; i++) {
        for (j = 0; j < size; j++) {
            c[(i * size) + j] = 0;
            for (k = 0; k < size; k++) {
                c[(i * size) + j] += a[(i * size) + k] * b[(k * size) + j];
            }
        }
    }
}

int main(int argc, char *argv[]) {
    unsigned int i, j, k, i2, j2, errors, naccs;
    struct timeval t0, tf;
    float t_hw, t_sw;

    a3data_t *a = NULL;
    a3data_t *b = NULL;
    a3data_t *hw = NULL;
    a3data_t *a_local = NULL;
    a3data_t *b_local = NULL;
    a3data_t *hw_local = NULL;
    a3data_t *sw = NULL;

    // Parse command line arguments
    naccs = 0;
    if (argc > 1) {
        naccs = atoi(argv[1]);
    }
    naccs = ((naccs > 0) && (naccs <= 4)) ? naccs : 4;
    printf("Using %d ARTICo3 accelerator(s)\n", naccs);

    // Initialize ARTICo3 infrastructure
    artico3_init();

    // Create kernel instance
    artico3_kernel_create("matmul", 49152, 3, 3, 3);

    // Load accelerators
    gettimeofday(&t0, NULL);
    for (i = 0; i < naccs; i++) {
        artico3_load("matmul", i, 0, 0, 1);
    }
    gettimeofday(&tf, NULL);
    t_hw = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading : %.6f ms\n", t_hw);

    // Allocate memory
    a = malloc(MSIZE_APP * MSIZE_APP * sizeof *a);
    b = malloc(MSIZE_APP * MSIZE_APP * sizeof *b);
    hw = malloc(MSIZE_APP * MSIZE_APP * sizeof *hw);
    sw = malloc(MSIZE_APP * MSIZE_APP * sizeof *sw);

    // Allocate data buffers
    a_local = artico3_alloc(MSIZE_APP * MSIZE_ACC * sizeof *a_local, "matmul", "a", A3_P_I);
    b_local = artico3_alloc(MSIZE_APP * MSIZE_ACC * sizeof *b_local, "matmul", "b", A3_P_I);
    hw_local = artico3_alloc(MSIZE_APP * MSIZE_ACC * sizeof *hw_local, "matmul", "hw", A3_P_O);

    // Initialize data buffers
    printf("Initializing data buffers...\n");
    srand(time(NULL));
    for (i = 0; i < (MSIZE_APP * MSIZE_APP); i++) {
        a[i] = rand();
        b[i] = rand();
        //~ a[i] = (i / MSIZE_APP) + (i % MSIZE_APP);
        //~ b[i] = (i / MSIZE_APP) + (i % MSIZE_APP) + 2;
        //~ a[i] = 1;
        //~ b[i] = 1;
    }

    // Execute kernel
    printf("Executing kernel...\n");
    gettimeofday(&t0, NULL);

    for (i = 0; i < MSIZE_APP; i += MSIZE_ACC) {
        for (j = 0; j < MSIZE_APP; j += MSIZE_ACC) {
            // Initialize accumulator
            for (i2 = 0; i2 < MSIZE_ACC; i2++) {
                for (j2 = 0; j2 < MSIZE_ACC; j2++) {
                    hw[((i + i2) * MSIZE_APP) + (j + j2)] = 0;
                }
            }
            // Copy partial inputs
            for (k = 0; k < MSIZE_APP; k+=MSIZE_ACC) {
                for (i2 = 0; i2 < MSIZE_ACC; i2++) {
                    for (j2 = 0; j2 < MSIZE_ACC; j2++) {
                        a_local[((i2 + k) * MSIZE_ACC) + j2] = a[((i + i2) * MSIZE_APP) + (k + j2)];
                        b_local[((i2 + k) * MSIZE_ACC) + j2] = b[((k + i2) * MSIZE_APP) + (j + j2)];
                    }
                }
            }
            // Perform computation
            artico3_kernel_execute("matmul", MSIZE_APP, MSIZE_ACC);
            artico3_kernel_wait("matmul");
            // Copy partial output
            for (k = 0; k < MSIZE_APP; k+=MSIZE_ACC) {
                for (i2 = 0; i2 < MSIZE_ACC; i2++) {
                    for (j2 = 0; j2 < MSIZE_ACC; j2++) {
                        hw[((i + i2) * MSIZE_APP) + (j + j2)] += hw_local[((i2 + k)* MSIZE_ACC) + j2];
                    }
                }
            }
        }
    }

    gettimeofday(&tf, NULL);
    t_hw = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel execution : %.6f ms\n", t_hw);

    // Execute software reference
    printf("Executing software...\n");
    gettimeofday(&t0, NULL);
    matmul_sw(MSIZE_APP, a, b, sw);
    gettimeofday(&tf, NULL);
    t_sw = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Software execution : %.6f ms\n", t_sw);
    printf("Speedup : %.6f\n", t_sw / t_hw);

    // Check results vs. software reference
    printf("Checking results...\n");
    errors = 0;
    for (i = 0; i < (MSIZE_APP * MSIZE_APP); i++) {
        if (hw[i] != sw[i]) errors++;
    }
    printf("Found %d errors\n", errors);

    // Show partial results
    printf("A:\n");
    for (i = 0; i < 4; i++) {
		printf("    ");
        for (j = 0; j < 4; j++) {
            printf("%08x ", a[(i * MSIZE_APP) + j]);
        }
        printf("\n");
    }
    printf("B:\n");
    for (i = 0; i < 4; i++) {
		printf("    ");
        for (j = 0; j < 4; j++) {
            printf("%08x ", b[(i * MSIZE_APP) + j]);
        }
        printf("\n");
    }
    printf("SOFTWARE:\n");
    for (i = 0; i < 4; i++) {
		printf("    ");
        for (j = 0; j < 4; j++) {
            printf("%08x ", sw[(i * MSIZE_APP) + j]);
        }
        printf("\n");
    }
    printf("HARDWARE:\n");
    for (i = 0; i < 4; i++) {
		printf("    ");
        for (j = 0; j < 4; j++) {
            printf("%08x ", hw[(i * MSIZE_APP) + j]);
        }
        printf("\n");
    }

    // Free software result memory
    free(a);
    free(b);
    free(hw);
    free(sw);

    // Free data buffers
    artico3_free("matmul", "a");
    artico3_free("matmul", "b");
    artico3_free("matmul", "hw");

    // Release kernel instance
    artico3_kernel_release("matmul");

    // Clean ARTICo3 setup
    artico3_exit();

    return 0;
}
