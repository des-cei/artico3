/*
 * ARTICo3 test application
 * Array addition
 *
 * Author : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date   : August 2017
 *
 * Hardware Thread (HLS)
 * Core processing function
 *
 */

#include "artico3.h"

#define VALUES (1024)

/*
 * NOTE: in HLS-based ARTICo3 hardware kernels, there is one additional
 *       input port that can be directly accessed from user code even
 *       if it has not been previously declared. This input, "values",
 *       contains the amount of values that have been written to the
 *       internal memories of the accelerator (it is important to take
 *       into account that this includes ALL inputs).
 */

A3_KERNEL(a3in_t a, a3in_t b, a3out_t c) {

    unsigned int i;

//  for (i = 0; i < values/2; i++) {
    for (i = 0; i < VALUES; i++) {
#pragma HLS PIPELINE
        c[i] = a[i] + b[i];
    }
}
