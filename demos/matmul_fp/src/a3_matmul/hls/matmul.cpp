/*
 * ARTICo3 test application
 * Matrix Multiplication (32-bit floating point)
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
 *
 * NOTE: this kernel showcases an application in which data conversion
 *       is required. The ARTICo3 data movement infrastructure works
 *       with 32-bit unsigned integer, whereas the core processing kernel
 *       works with 32-bit floating point numbers. To make everything
 *       compatible, application developers need to use the built-in
 *       functions a3tof() and ftoa3() to convert from a3data_t (uint32_t)
 *       to float and viceversa, respectively.
 *
 */

A3_KERNEL(a3in_t a, a3in_t b, a3out_t c) {
    unsigned int i, j, k, i2, j2, k2;

    float a_local[LSIZE][LSIZE];
# pragma HLS ARRAY_PARTITION variable=a_local complete dim=2
    float b_local[LSIZE][LSIZE];
# pragma HLS ARRAY_PARTITION variable=b_local complete dim=1

    for (i = 0; i < GSIZE; i+=LSIZE) {
        for (j = 0; j < GSIZE; j+=LSIZE) {

            // Initialize accumulator
            for (i2 = 0; i2 < LSIZE; i2++) {
                for (j2 = 0; j2 < LSIZE; j2++) {
#pragma HLS PIPELINE
                    c[((i + i2) * GSIZE) + (j + j2)] = ftoa3(0);
                }
            }

            for (k = 0; k < GSIZE; k+=LSIZE) {

                // Copy partial inputs
                for (i2 = 0; i2 < LSIZE; i2++) {
                    for (j2 = 0; j2 < LSIZE; j2++) {
                        a_local[i2][j2] = a3tof(a[((i + i2) * GSIZE) + (k + j2)]);
                        b_local[i2][j2] = a3tof(b[((k + i2) * GSIZE) + (j + j2)]);
                    }
                }

                // Perform computation
                for (i2 = 0; i2 < LSIZE; i2++) {
                    for (j2 = 0; j2 < LSIZE; j2++) {
#pragma HLS PIPELINE
                        for (k2 = 0; k2 < LSIZE; k2++) {
                            c[((i + i2) * GSIZE) + (j + j2)] = ftoa3(a3tof(c[((i + i2) * GSIZE) + (j + j2)]) + (a_local[i2][k2] * b_local[k2][j2]));
                        }
                    }
                }

            }
        }
    }
}
