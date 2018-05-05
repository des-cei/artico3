/*
 * ARTICo3 test application
 * Array addition
 *
 * Author : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date   : August 2017
 *
 * Hardware kernel (HLS)
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

A3_KERNEL(a3in_t    a,
          a3out_t   b,
          a3inout_t c,
          a3reg_t   inc) {
    unsigned int i;

    // All registers in HLS-based kernels need to be initialized
    a3reg_init(inc);

    for (i = 0; i < VALUES; i++) {
#pragma HLS PIPELINE
        b[i] = a[i] + *inc;
        c[i] += *inc;
    }

    (*inc)++;
}
