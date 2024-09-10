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

#include "artico3d.h"


int main() {

    // Initialize ARTICo3D infrastructure
    artico3d_init();

    // Wait requests
    artico3d_handle_request();

    // Clean ARTICo3D setup
    artico3d_exit();
    printf("End daemon\n");

    return 0;
}
