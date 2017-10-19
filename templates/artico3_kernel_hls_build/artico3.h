/*
 * ARTICo3 HLS kernel C synthesis header
 *
 * Author : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date   : August 2017
 *
 */

<a3<artico3_preproc>a3>

#ifndef _ARTICO3_H_
#define _ARTICO3_H_

#include <stdint.h>

/*
 * ARTICo3 data type
 *
 */
typedef uint32_t a3data_t;

/*
 * ARTICo3 HLS-based kernel definition
 *
 */
#define a3in_t
#define a3out_t

#define A3_KERNEL(<a3<ARGS>a3>) void <a3<NAME>a3>(\
<a3<generate for PORTS>a3>
        a3data_t <a3<pid>a3>[<a3<MEMPOS>a3>],\
<a3<end generate>a3>
        a3data_t values)

/*
 * ARTICo3 data reinterpretation: float to a3data_t (32 bits)
 *
 */
static inline a3data_t ftoa3(float f) {
    union { float f; a3data_t u; } un;
    un.f = f;
    return un.u;
}

/*
 * ARTICo3 data reinterpretation: a3data_t to float (32 bits)
 *
 */
static inline float a3tof(a3data_t u) {
    union { float f; a3data_t u; } un;
    un.u = u;
    return un.f;
}

#endif /* _ARTICO3_H_ */
