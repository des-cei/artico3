/*
 * ARTICo3 HLS kernel C synthesis header
 *
 * Author : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date   : August 2017
 *
 */

<a3<artico3_preproc>a3>

#include <stdint.h>

#define A3_KERNEL(<a3<ARGS>a3>) void <a3<NAME>a3>(\
<a3<generate for PORTS>a3>
        uint32_t <a3<pid>a3>[<a3<MEMPOS>a3>],\
<a3<end generate>a3>
        uint32_t values)
