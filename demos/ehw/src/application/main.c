/*
 * CPS Summer School 2023 tutorial
 * SA-based Evolvable Hardware on ARTICo³
 *
 * Author : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 *          Javier Mora <javier.morad@upm.es>
 * Date   : September 2023
 *
 * Main application
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>   // memcpy()
#include <sys/time.h> // struct timeval, gettimeofday()

#include "artico3.h"
#include "sysarr.h"
#include "evolution.h"


/* Main Application */

unsigned int naccs;

int main(int argc, char *argv[]) {

    // Local variables
    int i;
    struct timeval t0, tf, tr;
    float t;

    // File pointer (images, log)
    FILE *fp = NULL;

    // Input images
    static uint8_t img_s[SA_IMG_H][SA_IMG_W]; // 20% Salt & Pepper noise
    static uint8_t img_b[SA_IMG_H][SA_IMG_W]; // 15% Burst noise
    static uint8_t img_r[SA_IMG_H][SA_IMG_W]; // Reference image

    // ARTICo³ buffers
    a3data_t *ehw_i = NULL;
    a3data_t *ehw_r = NULL;
    a3data_t *ehw_o = NULL;

    // ARTICo³ configuration
    a3data_t wcfg[SA_NUM] = {[0 ... SA_NUM-1] = 0}; // SA configuration
    a3data_t rcfg[SA_NUM] = {[0 ... SA_NUM-1] = 0}; // SA fitness

    // Evolution variables
    int evals;
    struct Chromosome pop[TRIBES];
    unsigned int pop_fit[TRIBES];


    /* [0] System initialization */

    // Initialize ARTICo³ infrastructure
    artico3_init();

    // Create kernel instance
    artico3_kernel_create("sysarr_system", 49152, 3, 2);

    // Read input and reference images
    fp = fopen("img/LENA_S20.GRY", "rb");
    //~ fp = fopen("img/LENA_S05.GRY", "rb");
    fread(img_s, 1, SA_IMG_W * SA_IMG_H, fp);
    fclose(fp);
    fp = fopen("img/LENA_B15.GRY", "rb");
    fread(img_b, 1, SA_IMG_W * SA_IMG_H, fp);
    fclose(fp);
    fp = fopen("img/LENA.GRY", "rb");
    fread(img_r, 1, SA_IMG_W * SA_IMG_H, fp);
    fclose(fp);

    // Get reference time
    gettimeofday(&tr, NULL);


    /*
     * RANDOM SEARCH
     *
     */

    /* [1.a] Train system with random search */

    // Set number of accelerators
    naccs = 4;
    printf("Step #1.a: random search with %d accelerators and 20%% Salt & Pepper noise\n", naccs);

    // Load accelerators
    gettimeofday(&t0, NULL);
    for (i = 0; i < naccs; i++) {
        artico3_load("sysarr_system", i, 0, 0, 1);
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading : %.6f ms\n", t);
    printf("Kernel loading : %.6f ms\n", t);

    // Reset accelerators (RESET_AFTER_RECONFIG does not work properly)
    artico3_kernel_reset("sysarr_system");

    // Allocate data buffers
    ehw_i = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_0", A3_P_C);
    ehw_r = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_1", A3_P_C);

    // Initialize data buffers
    memcpy(ehw_i, img_s, SA_IMG_W * SA_IMG_H * 1);
    memcpy(ehw_r, img_r, SA_IMG_W * SA_IMG_H * 1);

    // Load PEs and setup ICAP
    icap_setup();

    // Evolution
    printf("Initializing random search...");
    rand_n_seed = 1;
    evolve_init(pop, pop_fit, NULL);
    printf("done\n");

    printf("RANDOM SEARCH\n");
    gettimeofday(&t0, NULL);
    t = ((t0.tv_sec - tr.tv_sec) * 1000.0) + ((t0.tv_usec - tr.tv_usec) / 1000.0);
    printf("%7d evals  ->  SAE = %5d\n", 0, pop_fit[0]);
    fp = fopen("img/EVOLUTION1.CSV", "w");
    fprintf(fp, "EVALS,SAE,TIME\n");
    fprintf(fp, "%7d,%5d,%.6f\n", 0, pop_fit[0], t);

    for (evals=TRIBES*SUBEVO_GENS; evals<=EVALS; evals+=TRIBES*SUBEVO_GENS) {
        random_gen(pop, pop_fit, NULL);
        gettimeofday(&tf, NULL);
        t = ((tf.tv_sec - tr.tv_sec) * 1000.0) + ((tf.tv_usec - tr.tv_usec) / 1000.0);
        printf("%7d evals  ->  SAE = %5d\n", evals, pop_fit[0]);
        fprintf(fp, "%7d,%5d,%.6f\n", evals, pop_fit[0], t);
    }
    printf("Done! Fitness = %d\n", pop_fit[0]);
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Random search time : %.6f ms\n", t);
    fclose(fp);

    // Release ICAP
    icap_release();

    // Release data buffers
    artico3_free("sysarr_system", "port_0");
    artico3_free("sysarr_system", "port_1");

    // Unload accelerators
    for (i = 0; i < naccs; i++) {
        artico3_unload(i);
    }


    /* [1.b] Execute random search filter */

    // Set number of accelerators (DO NOT CHANGE!)
    naccs = 1;
    printf("Step #1.b: execute random search filter for 20%% Salt & Pepper noise\n");

    // Load accelerators
    gettimeofday(&t0, NULL);
    for (i = 0; i < naccs; i++) {
        artico3_load("sysarr_system", i, 0, 0, 1);
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading : %.6f ms\n", t);

    // Reset accelerators (RESET_AFTER_RECONFIG does not work properly)
    artico3_kernel_reset("sysarr_system");

    // Allocate data buffers
    ehw_i = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_0", A3_P_I);
    ehw_r = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_1", A3_P_I);
    ehw_o = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_2", A3_P_O);

    // Initialize data buffers
    memcpy(ehw_i, img_s, SA_IMG_W * SA_IMG_H * 1);
    memcpy(ehw_r, img_r, SA_IMG_W * SA_IMG_H * 1);

    // Load PEs and setup ICAP
    icap_setup();

    // Load best chromosome
    for (i = 0; i < naccs; i++) {
        sysarr_cfg(&pop[0], i);
    }

    // Configure arrays to filter
    for (i = 0; i < SA_NUM; i++) wcfg[i] = SA_CMD_FC_1;
    artico3_kernel_wcfg("sysarr_system", SA_CTRL, wcfg);

    // Execute ARTICo³ kernel
    printf("Executing ARTICo³ kernel...\n");
    gettimeofday(&t0, NULL);
    artico3_kernel_execute("sysarr_system", 1, 1);
    artico3_kernel_wait("sysarr_system");
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel execution : %.6f ms\n\n", t);

    // Write results to file
    fp = fopen("img/RES1.GRY", "wb");
    fwrite(ehw_o, 1, SA_IMG_W * SA_IMG_H, fp);
    fclose(fp);

    // Release ICAP
    icap_release();

    // Release data buffers
    artico3_free("sysarr_system", "port_0");
    artico3_free("sysarr_system", "port_1");
    artico3_free("sysarr_system", "port_2");

    // Unload accelerators
    for (i = 0; i < naccs; i++) {
        artico3_unload(i);
    }


    /* [2.a] Train system with random search */

    // Set number of accelerators
    naccs = 4;
    printf("Step #2.a: random search with %d accelerators and 15%% Burst noise\n", naccs);

    // Load accelerators
    gettimeofday(&t0, NULL);
    for (i = 0; i < naccs; i++) {
        artico3_load("sysarr_system", i, 0, 0, 1);
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading : %.6f ms\n", t);
    printf("Kernel loading : %.6f ms\n", t);

    // Reset accelerators (RESET_AFTER_RECONFIG does not work properly)
    artico3_kernel_reset("sysarr_system");

    // Allocate data buffers
    ehw_i = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_0", A3_P_C);
    ehw_r = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_1", A3_P_C);

    // Initialize data buffers
    memcpy(ehw_i, img_b, SA_IMG_W * SA_IMG_H * 1);
    memcpy(ehw_r, img_r, SA_IMG_W * SA_IMG_H * 1);

    // Load PEs and setup ICAP
    icap_setup();

    // Evolution
    printf("Initializing random search...");
    rand_n_seed = 1;
    evolve_init(pop, pop_fit, NULL);
    printf("done\n");

    printf("RANDOM SEARCH\n");
    gettimeofday(&t0, NULL);
    t = ((t0.tv_sec - tr.tv_sec) * 1000.0) + ((t0.tv_usec - tr.tv_usec) / 1000.0);
    printf("%7d evals  ->  SAE = %5d\n", 0, pop_fit[0]);
    fp = fopen("img/EVOLUTION2.CSV", "w");
    fprintf(fp, "EVALS,SAE,TIME\n");
    fprintf(fp, "%7d,%5d,%.6f\n", 0, pop_fit[0], t);

    for (evals=TRIBES*SUBEVO_GENS; evals<=EVALS; evals+=TRIBES*SUBEVO_GENS) {
        random_gen(pop, pop_fit, NULL);
        gettimeofday(&tf, NULL);
        t = ((tf.tv_sec - tr.tv_sec) * 1000.0) + ((tf.tv_usec - tr.tv_usec) / 1000.0);
        printf("%7d evals  ->  SAE = %5d\n", evals, pop_fit[0]);
        fprintf(fp, "%7d,%5d,%.6f\n", evals, pop_fit[0], t);
    }
    printf("Done! Fitness = %d\n", pop_fit[0]);
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Random search time : %.6f ms\n", t);
    fclose(fp);

    // Release ICAP
    icap_release();

    // Release data buffers
    artico3_free("sysarr_system", "port_0");
    artico3_free("sysarr_system", "port_1");

    // Unload accelerators
    for (i = 0; i < naccs; i++) {
        artico3_unload(i);
    }


    /* [2.b] Execute random search filter */

    // Set number of accelerators (DO NOT CHANGE!)
    naccs = 1;
    printf("Step #2.b: execute random search filter for 15%% Burst noise\n");

    // Load accelerators
    gettimeofday(&t0, NULL);
    for (i = 0; i < naccs; i++) {
        artico3_load("sysarr_system", i, 0, 0, 1);
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading : %.6f ms\n", t);

    // Reset accelerators (RESET_AFTER_RECONFIG does not work properly)
    artico3_kernel_reset("sysarr_system");

    // Allocate data buffers
    ehw_i = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_0", A3_P_I);
    ehw_r = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_1", A3_P_I);
    ehw_o = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_2", A3_P_O);

    // Initialize data buffers
    memcpy(ehw_i, img_b, SA_IMG_W * SA_IMG_H * 1);
    memcpy(ehw_r, img_r, SA_IMG_W * SA_IMG_H * 1);

    // Load PEs and setup ICAP
    icap_setup();

    // Load best chromosome
    for (i = 0; i < naccs; i++) {
        sysarr_cfg(&pop[0], i);
    }

    // Configure arrays to filter
    for (i = 0; i < SA_NUM; i++) wcfg[i] = SA_CMD_FC_1;
    artico3_kernel_wcfg("sysarr_system", SA_CTRL, wcfg);

    // Execute ARTICo³ kernel
    printf("Executing ARTICo³ kernel...\n");
    gettimeofday(&t0, NULL);
    artico3_kernel_execute("sysarr_system", 1, 1);
    artico3_kernel_wait("sysarr_system");
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel execution : %.6f ms\n\n", t);

    // Write results to file
    fp = fopen("img/RES2.GRY", "wb");
    fwrite(ehw_o, 1, SA_IMG_W * SA_IMG_H, fp);
    fclose(fp);

    // Release ICAP
    icap_release();

    // Release data buffers
    artico3_free("sysarr_system", "port_0");
    artico3_free("sysarr_system", "port_1");
    artico3_free("sysarr_system", "port_2");

    // Unload accelerators
    for (i = 0; i < naccs; i++) {
        artico3_unload(i);
    }


    /*
     * EVOLUTIONARY SEARCH
     *
     */

    /* [3.a] Train system with evolutionary algorithm */

    // Set number of accelerators
    naccs = 4;
    printf("Step #3.a: train system with %d accelerators and 20%% Salt & Pepper noise\n", naccs);

    // Load accelerators
    gettimeofday(&t0, NULL);
    for (i = 0; i < naccs; i++) {
        artico3_load("sysarr_system", i, 0, 0, 1);
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading : %.6f ms\n", t);

    // Reset accelerators (RESET_AFTER_RECONFIG does not work properly)
    artico3_kernel_reset("sysarr_system");

    // Allocate data buffers
    ehw_i = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_0", A3_P_C);
    ehw_r = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_1", A3_P_C);

    // Initialize data buffers
    memcpy(ehw_i, img_s, SA_IMG_W * SA_IMG_H * 1);
    memcpy(ehw_r, img_r, SA_IMG_W * SA_IMG_H * 1);

    // Load PEs and setup ICAP
    icap_setup();

    // Evolution
    printf("Initializing evolution...");
    rand_n_seed = 1;
    evolve_init(pop, pop_fit, NULL);
    printf("done\n");

    printf("EVOLVING\n");
    gettimeofday(&t0, NULL);
    t = ((t0.tv_sec - tr.tv_sec) * 1000.0) + ((t0.tv_usec - tr.tv_usec) / 1000.0);
    printf("%7d evals  ->  SAE = %5d\n", 0, pop_fit[0]);
    fp = fopen("img/EVOLUTION3.CSV", "w");
    fprintf(fp, "EVALS,SAE,TIME\n");
    fprintf(fp, "%7d,%5d,%.6f\n", 0, pop_fit[0], t);

    for (evals=TRIBES*SUBEVO_GENS; evals<=EVALS; evals+=TRIBES*SUBEVO_GENS) {
        evolve_gen(pop, pop_fit, NULL);
        gettimeofday(&tf, NULL);
        t = ((tf.tv_sec - tr.tv_sec) * 1000.0) + ((tf.tv_usec - tr.tv_usec) / 1000.0);
        printf("%7d evals  ->  SAE = %5d\n", evals, pop_fit[0]);
        fprintf(fp, "%7d,%5d,%.6f\n", evals, pop_fit[0], t);
    }
    printf("Done! Fitness = %d\n", pop_fit[0]);
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Evolution time : %.6f ms\n", t);
    fclose(fp);

    // Release ICAP
    icap_release();

    // Release data buffers
    artico3_free("sysarr_system", "port_0");
    artico3_free("sysarr_system", "port_1");

    // Unload accelerators
    for (i = 0; i < naccs; i++) {
        artico3_unload(i);
    }


    /* [3.b] Execute evolved filter */

    // Set number of accelerators (DO NOT CHANGE!)
    naccs = 1;
    printf("Step #3.b: execute evolved filter for 20%% Salt & Pepper noise\n");

    // Load accelerators
    gettimeofday(&t0, NULL);
    for (i = 0; i < naccs; i++) {
        artico3_load("sysarr_system", i, 0, 0, 1);
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading : %.6f ms\n", t);

    // Reset accelerators (RESET_AFTER_RECONFIG does not work properly)
    artico3_kernel_reset("sysarr_system");

    // Allocate data buffers
    ehw_i = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_0", A3_P_I);
    ehw_r = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_1", A3_P_I);
    ehw_o = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_2", A3_P_O);

    // Initialize data buffers
    memcpy(ehw_i, img_s, SA_IMG_W * SA_IMG_H * 1);
    memcpy(ehw_r, img_r, SA_IMG_W * SA_IMG_H * 1);

    // Load PEs and setup ICAP
    icap_setup();

    // Load best chromosome
    for (i = 0; i < naccs; i++) {
        sysarr_cfg(&pop[0], i);
    }

    // Configure arrays to filter
    for (i = 0; i < SA_NUM; i++) wcfg[i] = SA_CMD_FC_1;
    artico3_kernel_wcfg("sysarr_system", SA_CTRL, wcfg);

    // Execute ARTICo³ kernel
    printf("Executing ARTICo³ kernel...\n");
    gettimeofday(&t0, NULL);
    artico3_kernel_execute("sysarr_system", 1, 1);
    artico3_kernel_wait("sysarr_system");
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel execution : %.6f ms\n\n", t);

    // Write results to file
    fp = fopen("img/RES3.GRY", "wb");
    fwrite(ehw_o, 1, SA_IMG_W * SA_IMG_H, fp);
    fclose(fp);

    // Release ICAP
    icap_release();

    // Release data buffers
    artico3_free("sysarr_system", "port_0");
    artico3_free("sysarr_system", "port_1");
    artico3_free("sysarr_system", "port_2");

    // Unload accelerators
    for (i = 0; i < naccs; i++) {
        artico3_unload(i);
    }


    /* [4.a] Change input noise and retrain with evolutionary algorithm */

    // Set number of accelerators
    naccs = 4;
    printf("Step #4.a: train system with %d accelerators and 15%% Burst noise\n", naccs);

    // Load accelerators
    gettimeofday(&t0, NULL);
    for (i = 0; i < naccs; i++) {
        artico3_load("sysarr_system", i, 0, 0, 1);
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading : %.6f ms\n", t);

    // Reset accelerators (RESET_AFTER_RECONFIG does not work properly)
    artico3_kernel_reset("sysarr_system");

    // Allocate data buffers
    ehw_i = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_0", A3_P_C);
    ehw_r = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_1", A3_P_C);

    // Initialize data buffers
    memcpy(ehw_i, img_b, SA_IMG_W * SA_IMG_H * 1);
    memcpy(ehw_r, img_r, SA_IMG_W * SA_IMG_H * 1);

    // Load PEs and setup ICAP
    icap_setup();

    // Evolution
    printf("Initializing evolution...");
    rand_n_seed = 1;
    evolve_init(pop, pop_fit, NULL);
    printf("done\n");

    //~ // Configure array #0 to compute fitness
    //~ for (i = 0; i < SA_NUM; i++) wcfg[i] = SA_CMD_FC_1;
    //~ artico3_kernel_wcfg("sysarr_system", SA_CTRL, wcfg);

    //~ // Iterate for all tribes
    //~ for (i = 0; i < TRIBES; i++) {
        //~ // Configure chromosome on array #0
        //~ sysarr_cfg(&pop[i], 0);
        //~ // Execute kernel
        //~ artico3_kernel_execute("sysarr_system", naccs, 1);
        //~ artico3_kernel_wait("sysarr_system");
        //~ // Read fitness value
        //~ artico3_kernel_rcfg("sysarr_system", SA_FITNESS(0), rcfg);
        //~ pop_fit[i] = rcfg[0];
    //~ }

    printf("EVOLVING\n");
    gettimeofday(&t0, NULL);
    t = ((t0.tv_sec - tr.tv_sec) * 1000.0) + ((t0.tv_usec - tr.tv_usec) / 1000.0);
    printf("%7d evals  ->  SAE = %5d\n", 0, pop_fit[0]);
    fp = fopen("img/EVOLUTION4.CSV", "w");
    fprintf(fp, "EVALS,SAE,TIME\n");
    fprintf(fp, "%7d,%5d,%.6f\n", 0, pop_fit[0], t);

    for (evals=TRIBES*SUBEVO_GENS; evals<=EVALS; evals+=TRIBES*SUBEVO_GENS) {
        evolve_gen(pop, pop_fit, NULL);
        gettimeofday(&tf, NULL);
        t = ((tf.tv_sec - tr.tv_sec) * 1000.0) + ((tf.tv_usec - tr.tv_usec) / 1000.0);
        printf("%7d evals  ->  SAE = %5d\n", evals, pop_fit[0]);
        fprintf(fp, "%7d,%5d,%.6f\n", evals, pop_fit[0], t);
    }
    printf("Done! Fitness = %d\n", pop_fit[0]);
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Evolution time : %.6f ms\n", t);
    fclose(fp);

    // Release ICAP
    icap_release();

    // Release data buffers
    artico3_free("sysarr_system", "port_0");
    artico3_free("sysarr_system", "port_1");

    // Unload accelerators
    for (i = 0; i < naccs; i++) {
        artico3_unload(i);
    }


    /* [4.b] Execute evolved filter */

    // Set number of accelerators (DO NOT CHANGE!)
    naccs = 1;
    printf("Step #4.b: execute evolved filter for 15%% Burst noise\n");

    // Load accelerators
    gettimeofday(&t0, NULL);
    for (i = 0; i < naccs; i++) {
        artico3_load("sysarr_system", i, 0, 0, 1);
    }
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel loading : %.6f ms\n", t);

    // Reset accelerators (RESET_AFTER_RECONFIG does not work properly)
    artico3_kernel_reset("sysarr_system");

    // Allocate data buffers
    ehw_i = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_0", A3_P_I);
    ehw_r = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_1", A3_P_I);
    ehw_o = artico3_alloc(SA_IMG_W * SA_IMG_H * 1, "sysarr_system", "port_2", A3_P_O);

    // Initialize data buffers
    memcpy(ehw_i, img_b, SA_IMG_W * SA_IMG_H * 1);
    memcpy(ehw_r, img_r, SA_IMG_W * SA_IMG_H * 1);

    // Load PEs and setup ICAP
    icap_setup();

    // Load best chromosome
    for (i = 0; i < naccs; i++) {
        sysarr_cfg(&pop[0], i);
    }

    // Configure arrays to filter
    for (i = 0; i < SA_NUM; i++) wcfg[i] = SA_CMD_FC_1;
    artico3_kernel_wcfg("sysarr_system", SA_CTRL, wcfg);

    // Execute ARTICo³ kernel
    printf("Executing ARTICo³ kernel...\n");
    gettimeofday(&t0, NULL);
    artico3_kernel_execute("sysarr_system", 1, 1);
    artico3_kernel_wait("sysarr_system");
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel execution : %.6f ms\n\n", t);

    // Write results to file
    fp = fopen("img/RES4.GRY", "wb");
    fwrite(ehw_o, 1, SA_IMG_W * SA_IMG_H, fp);
    fclose(fp);

    // Release ICAP
    icap_release();

    // Release data buffers
    artico3_free("sysarr_system", "port_0");
    artico3_free("sysarr_system", "port_1");
    artico3_free("sysarr_system", "port_2");

    // Unload accelerators
    for (i = 0; i < naccs; i++) {
        artico3_unload(i);
    }


    /* [5] System cleanup */

    // Release kernel instance
    artico3_kernel_release("sysarr_system");

    // Clean ARTICo³ setup
    artico3_exit();

    return 0;
}
