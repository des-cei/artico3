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

A3_KERNEL(a3in_t a, a3in_t b, a3out_t c){

    unsigned int i;

// TODO: document the usage of these two elements: MEMPOS and values
//  for (i = 0; i < MEMPOS; i++) {
//  for (i = 0; i < values/2; i++) {
    for (i = 0; i < VALUES; i++) {
#pragma HLS PIPELINE
        c[i] = a[i] + b[i];
    }
}
