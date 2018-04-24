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

// Memory-based I/O
#define a3in_t
#define a3out_t
#define a3inout_t

// Register-based I/O
#define a3reg_t

/*
 * ARTICo3 register initialization
 *
 * NOTE: this function needs to be called for each register defined in the
 *       kernel with a3reg_t. This forces a dummy read and write operation
 *       to enable the desired three-port interface (_i, _o, _o_vld), since
 *       otherwise it could not be automatically generated.
 *
 */
static inline void a3reg_init(a3data_t *reg) {
    volatile a3data_t dummy;
    dummy = *reg;
    *reg = dummy;
}

/*
 * ARTICo3 kernel header
 *
 */
#define A3_KERNEL(<a3<ARGS>a3>) void <a3<NAME>a3>(\
<a3<generate for REGS>a3>
        a3data_t *<a3<rname>a3>,\
<a3<end generate>a3>
<a3<generate for PORTS>a3>
        a3data_t <a3<pname>a3>[<a3<MEMPOS>a3>],\
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
