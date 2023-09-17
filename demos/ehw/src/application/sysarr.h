/** Low-level chromosome implementation.
 * Not an evolution-oriented chromosome as the old one, but rather
 * a reconfiguration-oriented one with ICAP in mind.
 **/

#ifndef SYSARR_H_
#define SYSARR_H_

#ifndef __linux__

    #include <xparameters.h> /* XPAR_SYSARR_SYSTEM_0_*_BASEADDR */

    #define SA_CTRL_BASEADDR  XPAR_SYSARR_SYSTEM_0_S_AXI_CTRL_BASEADDR
    #define SA_IN_BASEADDR    XPAR_SYSARR_SYSTEM_0_S_AXI_IN_BASEADDR
    #define SA_REF_BASEADDR   XPAR_SYSARR_SYSTEM_0_S_AXI_REF_BASEADDR
    #define SA_OUT_BASEADDR   XPAR_SYSARR_SYSTEM_0_S_AXI_OUT_BASEADDR

    #if SA_CTRL_BASEADDR==0xFFFFFFFF || SA_CTRL_BASEADDR==0xFFFFFFFFFFFFFFFF
        #error XPAR_SYSARR_SYSTEM_0_S_AXI_CTRL_BASEADDR not set; \
                please set SA_CTRL_BASEADDR manually
    #endif
    #if SA_IN_BASEADDR==0xFFFFFFFF || SA_IN_BASEADDR==0xFFFFFFFFFFFFFFFF
        #error XPAR_SYSARR_SYSTEM_0_S_AXI_IN_BASEADDR not set; \
                please set SA_IN_BASEADDR manually
    #endif
    #if SA_REF_BASEADDR==0xFFFFFFFF || SA_REF_BASEADDR==0xFFFFFFFFFFFFFFFF
        #error XPAR_SYSARR_SYSTEM_0_S_AXI_REF_BASEADDR not set; \
                please set SA_CTRL_BASEADDR manually
    #endif
    #if SA_OUT_BASEADDR==0xFFFFFFFF || SA_OUT_BASEADDR==0xFFFFFFFFFFFFFFFF
        #error XPAR_SYSARR_SYSTEM_0_S_AXI_OUT_BASEADDR not set; \
                please set SA_CTRL_BASEADDR manually
    #endif


    #define SA_NUM     4  /* number of systolic arrays in sysarr_system */
    #define SA_OTHERS  0  /* remaining systolic arrays in design (if any) */
    #define SA_WORDS  30  /* (1+8+1) columns x 3 cfg words per column */

    #define SA_FITNESS ((volatile unsigned int *) (SA_CTRL_BASEADDR + 4))

    #define SA_CMD_FILT    0x80000000
    #define SA_CMD_CMP_1   1
    #define SA_CMD_FC_1    (SA_CMD_FILT|SA_CMD_CMP_1)
    #define SA_CMD_CMP_ALL ((1u<<SA_NUM) - 1)
    #define SA_CMD_FC_ALL  (SA_CMD_FILT|SA_CMD_CMP_ALL)

    #define SA_IMG_H 128
    #define SA_IMG_W 128
    #define SA_IMG_SIZE (SA_IMG_H*SA_IMG_W)

    #define SA_IMG_IN  ((volatile unsigned char *) SA_IN_BASEADDR)
    #define SA_IMG_REF ((volatile unsigned char *) SA_REF_BASEADDR)
    #define SA_IMG_OUT ((volatile unsigned char *) SA_OUT_BASEADDR)

#else

    /* ARTICo3 kernel definitions */

    // Generic register offsets
    #define A3_SYSARR_SYSTEM_REG_0 (0x000)
    #define A3_SYSARR_SYSTEM_REG_1 (0x001)

    // Aplication specific tags
    #define SA_CTRL           A3_SYSARR_SYSTEM_REG_0
    #define SA_FITNESS(array) (A3_SYSARR_SYSTEM_REG_1 + (array))


    /* sysarr.h definitions */

    #define SA_NUM     4  /* number of systolic arrays in sysarr_system */
    #define SA_OTHERS  0  /* remaining systolic arrays in design (if any) */
    #define SA_WORDS  30  /* (1+8+1) columns x 3 cfg words per column */

    #define SA_CMD_FILT    0x80000000
    #define SA_CMD_CMP_1   1
    #define SA_CMD_FC_1    (SA_CMD_FILT|SA_CMD_CMP_1)
    #define SA_CMD_CMP_ALL ((1u<<SA_NUM) - 1)
    #define SA_CMD_FC_ALL  (SA_CMD_FILT|SA_CMD_CMP_ALL)

    #define SA_IMG_H 128
    #define SA_IMG_W 128
    #define SA_IMG_SIZE (SA_IMG_H*SA_IMG_W)

    /* main.c definitions */

    int icap_setup(void);
    int icap_release(void);

#endif /* __linux__ */

/** Chromosome for configuring the systolic array.
 * Contains info to be written to the fast_icap. **/
struct Chromosome {
    unsigned cfg[SA_WORDS];
};


/** Functions **/
int sysarr_cfg(const struct Chromosome *ch, int arr);
void sysarr_start(unsigned int mode);
void sysarr_wait(void);
void sysarr_go(unsigned int mode);


#endif /* SYSARR_H_ */

