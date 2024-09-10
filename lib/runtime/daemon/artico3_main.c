/*
 * ARTICo3 daemon main
 *
 * Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 *               Juan Encinas <juan.encinas@upm.es>
 * Date        : May 2024
 * Description : This file contains the main program of the ARTICo3 daemon
 *
 */


#include <stdio.h>
#include <stdlib.h>

#include "artico3.h"


int main() {

    // Initialize ARTICo3 infrastructure
    artico3_init();

    // Wait requests
    artico3_handle_request();

    // Clean ARTICo3 setup
    // TODO: find a proper way to call artico3_exit() when the daemon is commanded to finish
    // artico3_exit(a3d_tid);
    printf("End daemon\n");

    return 0;
}
