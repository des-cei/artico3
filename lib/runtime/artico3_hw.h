/*
 * ARTICo3 low-level hardware API
 *
 * Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date        : August 2017
 * Description : This file contains the low-level functions required to
 *               work with the ARTICo3 infrastructure (Data Shuffler).
 *
 */

//~ <a3<artico3_preproc>a3>

#ifndef _ARTICO3_HW_H_
#define _ARTICO3_HW_H_

/*
 * ARTICo3 hardware configuration parameters
 *
 */
#define A3_MAXSLOTS (4)   // TODO: make this using a3dk parser (<a3<NUM_SLOTS>a3>)
#define A3_MAXKERNS (0xF) // TODO: maybe make it configurable? Would also require additional VHDL parsing in Shuffler...
#define A3_SLOTADDR (0x8aa00000)


/*
 * ARTICo3 infrastructure register offsets (in 32-bit words)
 *
 */
#define A3_ID_REG_LOW     (0x00000000 >> 2) // ID register (low)
#define A3_ID_REG_HIGH    (0x00000004 >> 2) // ID register (high)
#define A3_TMR_REG_LOW    (0x00000008 >> 2) // TMR register (low)
#define A3_TMR_REG_HIGH   (0x0000000c >> 2) // TMR register (high)
#define A3_DMR_REG_LOW    (0x00000010 >> 2) // DMR register (low)
#define A3_DMR_REG_HIGH   (0x00000014 >> 2) // DMR register (high)
#define A3_BLOCK_SIZE_REG (0x00000018 >> 2) // Block size register
#define A3_CLOCK_GATE_REG (0x0000001c >> 2) // Clock gating register
#define A3_READY_REG      (0x00000028 >> 2) // Ready register


/*
 * ARTICo3 kernel port
 *
 * @name : name of the kernel port
 * @data : virtual memory of input
 *
 */
struct a3port_t {
    char *name;
    size_t size;
    void *data;
};


/*
 * ARTICo3 kernel (hardware accelerator)
 *
 * @name     : kernel name
 * @id       : kernel ID (0x1 - 0xF)
 * @membytes : local memory inside kernel, in bytes
 * @membanks : number of local memory banks inside kernel
 * @regrw    : number of read/write registers inside kernel
 * @regro    : number of read only registers inside kernel
 * @inputs   : input port configuration for this kernel
 * @outputs  : output port configuration for this kernel
 *
 */
struct a3kernel_t {
    char *name;
    uint8_t id;
    size_t membytes;
    size_t membanks;
    size_t regrw;
    size_t regro;
    struct a3port_t **inputs;
    struct a3port_t **outputs;
};


/*
 * ARTICo3 slot state
 *
 * S_EMPTY : no hardware kernel is present in this slot
 * S_IDLE  : the hardware kernel in this slot is idle
 * S_LOAD  : loading hardware kernel using DPR
 * S_WRITE : writing data from main memory to hardware kernel
 * S_RUN   : the hardware kernel in this slot is computing
 * S_READY : the hardware kernel in this slot finished computing
 * S_READ  : reading data from hardware kernel to main memory
 *
 */
enum a3state_t {S_EMPTY, S_IDLE, S_LOAD, S_WRITE, S_RUN, S_READY, S_READ};


/*
 * ARTICo3 slot
 *
 * @kernel : pointer to the kernel entity currently loaded in this slot
 * @state  : current state of this slot (see a3_state_t)
 *
 */
struct a3slot_t {
    struct a3kernel_t *kernel;
    enum a3state_t state;
};


/*
 * ARTICo3 infrastructure
 *
 * @id_reg      : slot ID configuration shadow register
 * @tmr_reg     : slot TMR configuration shadow register
 * @dmr_reg     : slot TMR configuration shadow register
 * @blksize_reg : transfer block size configuration shadow register
 * @clkgate_reg : clock gating configuration shadow register
 * @slots       : array of slot entities for current implementation
 *
 */
struct a3shuffler_t {
    uint64_t id_reg;
    uint64_t tmr_reg;
    uint64_t dmr_reg;
    uint32_t blksize_reg;
    uint32_t clkgate_reg;
    struct a3slot_t *slots;
};


/*
 * ARTICo3 low-level hardware function
 *
 * Gets current number of available hardware accelerators for a given
 * kernel ID tag.
 *
 * @id : current kernel ID
 *
 * Returns : number of accelerators on success, error code otherwise
 *
 */
int artico3_hw_get_naccs(uint8_t id);


/*
 * ARTICo3 low-level hardware function
 *
 * Gets, for the current accelerator setup, the expected mask to be used
 * when checking the ready register in the Data Shuffler.
 *
 * @id : current kernel ID
 *
 * Return : ready mask on success, 0 otherwise
 *
 */
uint32_t artico3_hw_get_readymask(uint8_t id);


void artico3_hw_print_regs();


#endif /* _ARTICO3_HW_H_ */
