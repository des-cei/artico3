/*
 * ARTICo3 low-level hardware API
 *
 * Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date        : August 2017
 * Description : This file contains the low-level functions required to
 *               work with the ARTICo3 infrastructure (Data Shuffler).
 *
 */

#ifndef _ARTICO3_HW_H_
#define _ARTICO3_HW_H_

#include <stdlib.h>
#include <stdint.h>

// TODO: make this configurable
#define a3_print_debug(msg, args...) printf(msg, ##args)
#define a3_print_error(msg, args...) printf(msg, ##args)


/*
 * ARTICo3 infrastructure register offsets (in 32-bit words)
 *
 */
#define A3_ID_REG_LOW_OFFSET     (0x00000000 >> 2)
#define A3_ID_REG_HIGH_OFFSET    (0x00000004 >> 2)
#define A3_TMR_REG_LOW_OFFSET    (0x00000008 >> 2)
#define A3_TMR_REG_HIGH_OFFSET   (0x0000000c >> 2)
#define A3_DMR_REG_LOW_OFFSET    (0x00000010 >> 2)
#define A3_DMR_REG_HIGH_OFFSET   (0x00000014 >> 2)
#define A3_BLOCK_SIZE_REG_OFFSET (0x00000018 >> 2)
#define A3_CLOCK_GATE_REG_OFFSET (0x0000001c >> 2)
#define A3_READY_REG_OFFSET      (0x00000028 >> 2)


/*
 * ARTICo3 kernel (hardware accelerator)
 *
 * @name     : kernel name
 * @id       : kernel ID (0x1 - 0xF)
 * @membytes : local memory inside kernel, in bytes
 * @membanks : number of local memory banks inside kernel
 * @regrw    : number of read/write registers inside kernel
 * @regro    : number of read only registers inside kernel
 *
 */
struct a3_kernel {
    const char *name;
    uint8_t id;
    size_t membytes;
    size_t membanks;
    size_t regrw;
    size_t regro;
};


/*
 * ARTICo3 slot state
 *
 * S_EMPTY : no hardware kernel is present in this slot
 * S_IDLE  : the hardware kernel in this slot is idle
 * S_LOAD  : loading hardware kernel using DPR
 * S_WRITE : writing data from main memory to hardware kernel
 * S_RUN   : the hardware kernel in this slot is computing
 * S_READ  : reading data from hardware kernel to main memory
 *
 */
enum a3_state_t {S_EMPTY, S_IDLE, S_LOAD, S_WRITE, S_RUN, S_READ};


/*
 * ARTICo3 slot
 *
 * @kernel : pointer to the kernel entity currently loaded in this slot
 * @state  : current state of this slot (see a3_state_t)
 *
 */
struct a3_slot {
    struct a3_kernel *kernel;
    enum a3_state_t state;
};


/*
 * ARTICo3 infrastructure
 *
 * @id_reg      : slot ID configuration shadow register
 * @tmr_reg     : slot TMR configuration shadow register
 * @dmr_reg     : slot TMR configuration shadow register
 * @blksize_reg : transfer block size configuration shadow register
 * @clkgate_reg : clock gating configuration shadow register
 * @nslots      : maximum number of reconfigurable slots
 * @slots       : array of slot entities for current implementation
 *
 */
struct a3_shuffler {
    uint64_t id_reg;
    uint64_t tmr_reg;
    uint64_t dmr_reg;
    uint32_t blksize_reg;
    uint32_t clkgate_reg;
    size_t nslots;
    struct a3_slot *slots;
};


/*
 * ARTICo3 init function
 *
 * This function sets up the basic software entities required to manage
 * the ARTICo3 low-level functionality (DMA transfers, kernel and slot
 * distributions, etc.).
 *
 * Return : 0 if initialization finished successfully, error otherwise
 */
int artico3_init();


/*
 * ARTICo3 exit function
 *
 * This function cleans the software entities created by artico3_init().
 *
 */
void artico3_exit();


/*
 * TODO: ADDITIONAL FUNCTIONS
 *
 */
void artico3_clk_enable(uint8_t slot);
void artico3_clk_disable(uint8_t slot);
void artico3_set_id(uint8_t id, uint8_t slot);


#endif /* _ARTICO3_HW_H_ */
