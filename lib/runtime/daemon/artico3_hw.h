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

extern uint32_t *artico3_hw;
extern struct a3shuffler_t shuffler;


/*
 * ARTICo3 hardware configuration parameters
 *
 */
#define A3_MAXKERNS (0xF) // TODO: maybe make it configurable? Would also require additional VHDL parsing in Shuffler...

#ifdef ZYNQMP
#define A3_SLOTADDR (0xb0000000)
#else
#define A3_SLOTADDR (0x8aa00000)
#endif


/*
 * ARTICo3 infrastructure register offsets (in 32-bit words)
 *
 */
#define A3_ID_REG_LOW     (0x00000000 >> 2)                     // ID register (low)
#define A3_ID_REG_HIGH    (0x00000004 >> 2)                     // ID register (high)
#define A3_TMR_REG_LOW    (0x00000008 >> 2)                     // TMR register (low)
#define A3_TMR_REG_HIGH   (0x0000000c >> 2)                     // TMR register (high)
#define A3_DMR_REG_LOW    (0x00000010 >> 2)                     // DMR register (low)
#define A3_DMR_REG_HIGH   (0x00000014 >> 2)                     // DMR register (high)
#define A3_BLOCK_SIZE_REG (0x00000018 >> 2)                     // Block size register
#define A3_CLOCK_GATE_REG (0x0000001c >> 2)                     // Clock gating register
#define A3_NSLOTS_REG     (0x00000028 >> 2)                     // Firmware info : number of slots
#define A3_READY_REG      (0x0000002c >> 2)                     // Ready register
#define A3_PMC_CYCLES_REG (0x00000030 >> 2)                     // PMC (cycles)
#define A3_PMC_ERRORS_REG (A3_PMC_CYCLES_REG + shuffler.nslots) // PMC (errors)


/*
 * ARTICo3 kernel port
 *
 * @name     : name of the kernel port
 * @size     : size of the virtual memory
 * @filename : filename of the shared memory
 * @data     : virtual memory of input
 *
 */
struct a3port_t {
    char *name;
    size_t size;
    char *filename;
    void *data;
};


/*
 * ARTICo3 kernel (hardware accelerator)
 *
 * @name     : kernel name
 * @id       : kernel ID (0x1 - 0xF)
 * @membytes : local memory inside kernel, in bytes
 * @membanks : number of local memory banks inside kernel
 * @regs     : number of read/write registers inside kernel
 * @c_loaded : flag to check whether constant memories have been loaded
 * @consts   : constant input port configuration for this kernel
 * @inputs   : input port configuration for this kernel
 * @outputs  : output port configuration for this kernel
 * @inouts   : inout port configuration for this kernel
 *
 */
struct a3kernel_t {
    char *name;
    uint8_t id;
    size_t membytes;
    size_t membanks;
    size_t regs;
    uint8_t c_loaded;
    struct a3port_t **consts;
    struct a3port_t **inputs;
    struct a3port_t **outputs;
    struct a3port_t **inouts;
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
    uint32_t nslots;
    struct a3slot_t *slots;
};


/*
 * ARTICo3 low-level hardware function
 *
 * Gets firmware information (number of ARTICo3 slots) of the current
 * static system.
 *
 * Returns : number of slots
 *
 */
uint32_t artico3_hw_get_nslots();


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


/*
 * ARTICo3 low-level hardware function
 *
 * Prints the current ARTICo3 configuration by directly accessing the
 * configuration registers in the Data Shuffler.
 *
 */
void artico3_hw_print_regs();


/*
 * ARTICo3 low-level hardware function
 *
 * Sets up a data transfer by writing to the ARTICo3 configuration
 * registers (ID, TMR, DMR, block size).
 *
 * @blksize : block size (32-bit words to be sent to each accelerator)
 *
 */
void artico3_hw_setup_transfer(uint32_t blksize);


/*
 * ARTICo3 low-level hardware function
 *
 * Checks if a processing round is finished. The configuration of the
 * specific round is passed using the expected ready mask.
 *
 * @readymask : expected ready register contents (mask)
 *
 * Return : 0 when still working, 1 when finished
 *
 */
int artico3_hw_transfer_isdone(uint32_t readymask);


/*
 * ARTICo3 low-level hardware function
 *
 * Enables the clock in the reconfigurable region (ARTICo3 slots).
 *
 */
void artico3_hw_enable_clk();


/*
 * ARTICo3 low-level hardware function
 *
 * Disables the clock in the reconfigurable region (ARTICo3 slots).
 *
 */
void artico3_hw_disable_clk();


/*
 * ARTICo3 low-level hardware function
 *
 * Reads the value of the "cycles" PMC.
 *
 * @slot : number/ID of the slot that is to be checked
 *
 * Return : PMC value (execution cycles)
 *
 */
uint32_t artico3_hw_get_pmc_cycles(uint8_t slot);


/*
 * ARTICo3 low-level hardware function
 *
 * Reads the value of the "errors" PMC.
 *
 * @slot : number/ID of the slot that is to be checked
 *
 * Return : PMC value (execution errors)
 *
 */
uint32_t artico3_hw_get_pmc_errors(uint8_t slot);


/*
 * ARTICo3 low-level hardware function
 *
 * Generic write operation to access accelerator registers or to send
 * specific commands.
 *
 * @id    : kernel ID
 * @op    : operation code
 *          0 - write operation
 *          1 - reset all accelerators from kernel #ID
 * @reg   : for actual register write operations, register offset
 * @value : for actual register write operations, value to be written
 *
 * NOTE: this implementation assumes fixed number of bits for ID, OP and
 *       address ranges inside the memory map (4, 4, and 12 respectively)
 *
 */
static inline void artico3_hw_regwrite(uint8_t id, uint8_t op, uint16_t reg, uint32_t value){
    artico3_hw[((((id & 0xf) << 16) | ((op & 0xf) << 12)) >> 2) | (reg & 0xfff)] = value;
}


/*
 * ARTICo3 low-level hardware function
 *
 * Generic read operation to access accelerator registers or to execute
 * specific commands.
 *
 * @id    : kernel ID
 * @op    : operation code
 *          0    - read operation
 *          1..f - reduction operation code
 * @reg   : for actual register read operations, register offset
 *
 * Return : for actual register read operations, read value
 *
 * NOTE: this implementation assumes fixed number of bits for ID, OP and
 *       address ranges inside the memory map (4, 4, and 12 respectively)
 *
 */
static inline uint32_t artico3_hw_regread(uint8_t id, uint8_t op, uint16_t reg){
    return artico3_hw[((((id & 0xf) << 16) | ((op & 0xf) << 12)) >> 2) | (reg & 0xfff)];
}


#endif /* _ARTICO3_HW_H_ */
