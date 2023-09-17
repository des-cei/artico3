/** Low-level chromosome implementation.
 * Not an evolution-oriented chromosome, but rather
 * a reconfiguration-oriented one with ICAP in mind.
 **/

#include "sysarr.h"

#ifndef __linux__

    #include <xparameters.h> // XPAR_FAST_ICAP_SYSARR_0_S_AXI_CTRL_BASEADDR

    #define ICAP_CTRL_BASEADDR  XPAR_FAST_ICAP_SYSARR_0_S_AXI_CTRL_BASEADDR
    #if ICAP_CTRL_BASEADDR==0xFFFFFFFF || ICAP_CTRL_BASEADDR==0xFFFFFFFFFFFFFFFF
        #error XPAR_FAST_ICAP_SYSARR_0_S_AXI_CTRL_BASEADDR not set; \
                please set ICAP_CTRL_BASEADDR manually
    #endif


    #define ICAP ((volatile unsigned int *) ICAP_CTRL_BASEADDR)
    #define SA_CTRL (SA_FITNESS[-1])

#else

    #include <stdio.h>
    #include <stdlib.h>
    #include <unistd.h>
    #include <sys/mman.h>
    #include <fcntl.h>

    #include <stdint.h>
    #include "artico3.h"
    #include "evolution.h" // sysarr_load_pbs()

    volatile uint32_t *ICAP;

    #define XDCFG_CTRL_PCAP_PR_MASK   0x08000000 /**< Enable PCAP for PR */
    #define XDCFG_CTRL_PCAP_MODE_MASK 0x04000000 /**< Enable PCAP */

    int icap_setup(void) {

        // Managed through /dev/mem
        int fd;
        fd = open("/dev/mem", O_RDWR);

        // Enable ICAP as reconfiguration engine
        volatile uint32_t *xdevcfg = mmap(NULL, 0x10000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0xf8007000);
        *xdevcfg &= ~(XDCFG_CTRL_PCAP_PR_MASK);
        munmap(xdevcfg, 0x10000);

        // Map ICAP_CTRL to userspace
        ICAP = mmap(NULL, 0x10000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0x40000000);
        //~ printf("ICAP_CTRL : %p\n", ICAP);

        // Load PEs
        sysarr_load_pbs();

        close(fd);
        return 0;
    }

    int icap_release(void) {

        // Managed through /dev/mem
        int fd;
        fd = open("/dev/mem", O_RDWR);

        // Disable ICAP as reconfiguration engine, restore PCAP
        volatile uint32_t *xdevcfg = mmap(NULL, 0x10000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0xf8007000);
        *xdevcfg |= (XDCFG_CTRL_PCAP_PR_MASK);
        munmap(xdevcfg, 0x10000);

        // Unmap ICAP_CTRL
        munmap(ICAP, 0x10000);

        close(fd);
        return 0;
    }

#endif /* __linux__ */

#define SA_REGIONS (SA_WORDS/3) // 3 words per "region" (column/clock reg)

#define FAR(B,T,R,C,F)                      \
        ( (B)<<23   /* block (0=logic) */   \
        | (T)<<22   /* 0=top, 1=bottom */   \
        | (R)<<17   /* row number */        \
        | (C)<< 7   /* column number */     \
        | (F)<< 0 ) /* frame number */
#define XFAR(N, B,T,R,C,F)  /* eXtended */  \
        ( (N)<<26   /* number of frames */  \
        | FAR(B,T,R,C,F) )
#define FAR_SKIP 0

#define CLBLL(T,R,C)    { XFAR(2, 0,T,R,C,32) }, \
                        { XFAR(2, 0,T,R,C,26) }    // L\L  (defines 2 columns)
#define CLBLM(T,R,C)    { XFAR(2, 0,T,R,C,34) }, \
                        { XFAR(2, 0,T,R,C,26) }    // M\L  (defines 2 columns)
#define TOP    0
#define BOTTOM 1
static const unsigned int frame_addresses[SA_NUM+SA_OTHERS][SA_REGIONS][1] = {{
    // Array 0: row T0, col 60 (=1 in Device view for 7z010)
    CLBLM(TOP, 0, 60), // W mux  \ (?, 0)
    CLBLM(TOP, 0, 61), // (?, 1) \ (?, 2)
    CLBLM(TOP, 0, 62), // (?, 3) \ (?, 4)
    CLBLM(TOP, 0, 63), // (?, 5) \ (?, 6)
    CLBLM(TOP, 0, 65), // (?, 7) \ E mux
},{
    // Array 1: row B0, col 60 (=1 in Device view for 7z010)
    CLBLM(BOTTOM, 0, 60), // W mux  \ (?, 0)
    CLBLM(BOTTOM, 0, 61), // (?, 1) \ (?, 2)
    CLBLM(BOTTOM, 0, 62), // (?, 3) \ (?, 4)
    CLBLM(BOTTOM, 0, 63), // (?, 5) \ (?, 6)
    CLBLM(BOTTOM, 0, 65), // (?, 7) \ E mux
},{
    // Array 2: row B1, col 60 (=1 in Device view for 7z010)
    CLBLM(BOTTOM, 1, 60), // W mux  \ (?, 0)
    CLBLM(BOTTOM, 1, 61), // (?, 1) \ (?, 2)
    CLBLM(BOTTOM, 1, 62), // (?, 3) \ (?, 4)
    CLBLM(BOTTOM, 1, 63), // (?, 5) \ (?, 6)
    CLBLM(BOTTOM, 1, 65), // (?, 7) \ E mux
},{
    // Array 3: row B1, col 10 (=1 in Device view for 7z010)
    CLBLM(BOTTOM, 1, 10), // W mux  \ (?, 0)
    CLBLM(BOTTOM, 1, 11), // (?, 1) \ (?, 2)
    CLBLM(BOTTOM, 1, 12), // (?, 3) \ (?, 4)
    CLBLM(BOTTOM, 1, 13), // (?, 5) \ (?, 6)
    CLBLM(BOTTOM, 1, 15), // (?, 7) \ E mux
}};

#define RECONF_ONLY_NEEDED // do not reconfigure unneeded regions
//~ #define COUNT_RECONF // count number of partial reconfigurations performed
#define LIKELY(cond)   __builtin_expect((cond), 1) // cond is usually true
#define UNLIKELY(cond) __builtin_expect((cond), 0) // cond is usually false
int sysarr_cfg(const struct Chromosome *ch, int arr) {
    int count = 0;
    int i;
    for (i=0; i<SA_REGIONS; i++) {
        unsigned cfg1 = ch->cfg[3*i+0];
        unsigned cfg2 = ch->cfg[3*i+1];
        unsigned cfg3 = ch->cfg[3*i+2];

       #ifdef RECONF_ONLY_NEEDED
        static struct Chromosome old[SA_NUM+SA_OTHERS];
        if (UNLIKELY( cfg1!=old[arr].cfg[3*i+0]
                ||    cfg2!=old[arr].cfg[3*i+1]
                ||    cfg3!=old[arr].cfg[3*i+2] )) {
       #endif
            while (ICAP[0] & 0x1) { }  // wait for ack (mandatory)
            ICAP[1] = cfg1;
            ICAP[2] = cfg2;
            ICAP[3] = cfg3;

            unsigned faddr;
            faddr = frame_addresses[arr][i][0];
            // if (LIKELY(faddr != FAR_SKIP)) { // this ALWAYS happens
                //while (ICAP[0] & 0x1) { } // wait for ack (unneeded 1st time)
                ICAP[0] = faddr;
            //}
           #ifdef COUNT_RECONF
            count++;
           #endif
       #ifdef RECONF_ONLY_NEEDED
            old[arr].cfg[3*i+0] = cfg1;
            old[arr].cfg[3*i+1] = cfg2;
            old[arr].cfg[3*i+2] = cfg3;
        }
       #endif
    }

    //~ while (ICAP[0]) { }  // wait for ICAP to finish all pending operations
    // ^^ this can be done in sysarr_start() instead

    return count;
}


#ifndef __linux__

    /** Make sysarr system start filtering (leave process "running in background").
     * ``mode`` can be:
     * - SA_CMD_FILT:  filter image in SA_IMG_IN using sysarr 0
     *       and store result in SA_IMG_OUT.  Do not calculate fitness.
     * - 1<<0, 1<<1, 1<<2...:  filter image in SA_IMG_IN using sysarr 0, 1, 2...
     *       and compare with SA_IMG_REF to get fitness.  Do not store result.
     * - a logical combination of the above (e.g.: SA_CMD_FILT | 1<<0 | 1<<1)
     *
     * Until sysarr_wait() is called and has returned, the value on the affected
     * SA_FITNESS[i] registers is indeterminate.
     **/
    void sysarr_start(unsigned int mode) {
        while (ICAP[0]) { }  // wait for ICAP to finish any pending operations
        SA_CTRL = mode;  // start
    }

    /** Wait for sysarr system to finish filtering after ``sysarr_start(mode)``.
     * If ``mode`` involved fitness calculations, the fitnesses will be stored
     * in SA_FITNESS[0], SA_FITNESS[1], SA_FITNESS[2]...
     *
     * Until this function is called and has returned, the value on the affected
     * SA_FITNESS[i] registers is indeterminate.
     *
     * The LOWER the fitness, the better the filter.  0 means output is identical
     * to reference; any other value represents the sum of absolute errors (SAE).
     **/
    void sysarr_wait(void) {
        while (SA_CTRL) { }  // wait
    }

    /** Filter an image and wait for the result.
     * ``mode`` can be:
     * - SA_CMD_FILT:  filter image in SA_IMG_IN using sysarr 0
     *       and store result in SA_IMG_OUT.  Do not calculate fitness.
     * - 1<<0, 1<<1, 1<<2...:  filter image in SA_IMG_IN using sysarr 0, 1, 2...
     *       and compare with SA_IMG_REF to get fitness.  Do not store result.
     * - a logical combination of the above (e.g.: SA_CMD_FILT | 1<<0 | 1<<1)
     *
     * If ``mode`` involved fitness calculations, the fitnesses will be stored
     * in SA_FITNESS[0], SA_FITNESS[1], SA_FITNESS[2]...
     *
     * The LOWER the fitness, the better the filter.  0 means output is identical
     * to reference; any other value represents the sum of absolute errors (SAE).
     **/
    void sysarr_go(unsigned int mode) {
        sysarr_start(mode);
        sysarr_wait();
    }

#else

    extern unsigned int naccs;

    /** Make sysarr system start filtering (leave process "running in background").
     * ``mode`` can be:
     * - SA_CMD_FILT:  filter image in SA_IMG_IN using sysarr 0
     *       and store result in SA_IMG_OUT.  Do not calculate fitness.
     * - 1<<0, 1<<1, 1<<2...:  filter image in SA_IMG_IN using sysarr 0, 1, 2...
     *       and compare with SA_IMG_REF to get fitness.  Do not store result.
     * - a logical combination of the above (e.g.: SA_CMD_FILT | 1<<0 | 1<<1)
     *
     * Until sysarr_wait() is called and has returned, the value on the affected
     * SA_FITNESS[i] registers is indeterminate.
     **/
    void sysarr_start(unsigned int mode) {
        while (ICAP[0]) { }  // wait for ICAP to finish any pending operations
        a3data_t wcfg[SA_NUM] = {[0 ... SA_NUM-1] = SA_CMD_CMP_1}; // SA configuration
        artico3_kernel_wcfg("sysarr_system", SA_CTRL, wcfg);
        artico3_kernel_execute("sysarr_system", naccs, 1);
    }

    /** Wait for sysarr system to finish filtering after ``sysarr_start(mode)``.
     * If ``mode`` involved fitness calculations, the fitnesses will be stored
     * in SA_FITNESS[0], SA_FITNESS[1], SA_FITNESS[2]...
     *
     * Until this function is called and has returned, the value on the affected
     * SA_FITNESS[i] registers is indeterminate.
     *
     * The LOWER the fitness, the better the filter.  0 means output is identical
     * to reference; any other value represents the sum of absolute errors (SAE).
     **/
    void sysarr_wait(void) {
        artico3_kernel_wait("sysarr_system");
    }

    /** Filter an image and wait for the result.
     * ``mode`` can be:
     * - SA_CMD_FILT:  filter image in SA_IMG_IN using sysarr 0
     *       and store result in SA_IMG_OUT.  Do not calculate fitness.
     * - 1<<0, 1<<1, 1<<2...:  filter image in SA_IMG_IN using sysarr 0, 1, 2...
     *       and compare with SA_IMG_REF to get fitness.  Do not store result.
     * - a logical combination of the above (e.g.: SA_CMD_FILT | 1<<0 | 1<<1)
     *
     * If ``mode`` involved fitness calculations, the fitnesses will be stored
     * in SA_FITNESS[0], SA_FITNESS[1], SA_FITNESS[2]...
     *
     * The LOWER the fitness, the better the filter.  0 means output is identical
     * to reference; any other value represents the sum of absolute errors (SAE).
     **/
    void sysarr_go(unsigned int mode) {
        sysarr_start(mode);
        sysarr_wait();
    }

#endif /* __linux__ */
