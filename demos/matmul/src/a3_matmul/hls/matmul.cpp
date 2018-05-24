/*
 * ARTICo3 test application
 * Matrix Multiplication (32-bit unsigned integer)
 *
 * Author : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date   : August 2017
 *
 * Hardware kernel (HLS)
 * Core processing function
 *
 */

#include "artico3.h"

#define GSIZE (64)
#define LSIZE (8)

/*
 * NOTE: in HLS-based ARTICo3 hardware kernels, there is one additional
 *       input port that can be directly accessed from user code even
 *       if it has not been previously declared. This input, "values",
 *       contains the amount of values that have been written to the
 *       internal memories of the accelerator (it is important to take
 *       into account that this includes ALL inputs).
 */

A3_KERNEL(a3in_t a, a3in_t b, a3out_t c) {
    unsigned int i, j, k, i2, j2, k2;

    uint32_t a_local[LSIZE][LSIZE];
# pragma HLS ARRAY_PARTITION variable=a_local complete dim=2
    uint32_t b_local[LSIZE][LSIZE];
# pragma HLS ARRAY_PARTITION variable=b_local complete dim=1

    for (i = 0; i < GSIZE; i+=LSIZE) {
        for (j = 0; j < GSIZE; j+=LSIZE) {

            // Initialize accumulator
            for (i2 = 0; i2 < LSIZE; i2++) {
                for (j2 = 0; j2 < LSIZE; j2++) {
#pragma HLS PIPELINE
                    c[((i + i2) * GSIZE) + (j + j2)] = 0;
                }
            }

            for (k = 0; k < GSIZE; k+=LSIZE) {

                // Copy partial inputs
                for (i2 = 0; i2 < LSIZE; i2++) {
                    for (j2 = 0; j2 < LSIZE; j2++) {
                        a_local[i2][j2] = a[((i + i2) * GSIZE) + (k + j2)];
                        b_local[i2][j2] = b[((k + i2) * GSIZE) + (j + j2)];
                    }
                }

                // Perform computation
                for (i2 = 0; i2 < LSIZE; i2++) {
                    for (j2 = 0; j2 < LSIZE; j2++) {
#pragma HLS PIPELINE
                        for (k2 = 0; k2 < LSIZE; k2++) {
                            c[((i + i2) * GSIZE) + (j + j2)] += a_local[i2][k2] * b_local[k2][j2];
                        }
                    }
                }

            }
        }
    }
}
