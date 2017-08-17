/*
 * ARTICo3 low-level hardware API
 *
 * Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date        : August 2017
 * Description : This file contains the low-level functions required to
 *               work with the ARTICo3 infrastructure (Data Shuffler).
 *
 */


#include <stdint.h>
#include <sys/types.h>
#include <errno.h>

#include "artico3_hw.h"
#include "artico3_dbg.h"


extern uint32_t *artico3_hw;
extern struct a3shuffler_t shuffler;


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
int artico3_hw_get_naccs(uint8_t id) {
    unsigned int i;
    int naccs;

    uint64_t id_reg;
    uint64_t tmr_reg;
    uint64_t dmr_reg;

    uint8_t aux_id;
    uint8_t aux_tmr;
    uint8_t aux_dmr;

    // Get current shadow registers
    id_reg = shuffler.id_reg;
    tmr_reg = shuffler.tmr_reg;
    dmr_reg = shuffler.dmr_reg;

    /*
     * NOTE: this assumes correct Shuffler configuration ALWAYS, e.g.
     *           - no DMR groups with less than 2 elements
     *           - no TMR groups with less than 3 elements
     *           - ...
     *
     */

    // Compute number of equivalent accelerators
    naccs = 0;
    while (id_reg) {
        aux_id  = id_reg  & 0xf;
        aux_tmr = tmr_reg & 0xf;
        aux_dmr = dmr_reg & 0xf;
        if (aux_id == id) {
            if (aux_tmr) {
                for (i = 1; i < A3_MAXSLOTS; i++) {
                    if (((id_reg >> (4 * i)) & 0xf) != aux_id) continue;
                    if (((tmr_reg >> (4 * i)) & 0xf) == aux_tmr) {
                        tmr_reg ^= tmr_reg & (0xf << (4 * i));
                        id_reg ^= id_reg & (0xf << (4 * i));
                    }
                }
            }
            else if (aux_dmr) {
                for (i = 1; i < A3_MAXSLOTS; i++) {
                    if (((id_reg >> (4 * i)) & 0xf) != aux_id) continue;
                    if (((dmr_reg >> (4 * i)) & 0xf) == aux_dmr) {
                        dmr_reg ^= dmr_reg & (0xf << (4 * i));
                        id_reg ^= id_reg & (0xf << (4 * i));
                    }
                }
            }
            naccs++;
        }
        id_reg >>= 4;
        tmr_reg >>= 4;
        dmr_reg >>= 4;
    }
    if (!naccs) {
        a3_print_error("[artico3-hw] no accelerators found with ID %x\n", id);
        return -ENODEV;
    }

    return naccs;
}


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
uint32_t artico3_hw_get_readymask(uint8_t id) {
    unsigned int i;

    uint32_t ready;
    uint64_t id_reg;

    // Get current shadow registers
    id_reg = shuffler.id_reg;

    // Compute expected ready flag
    ready = 0;
    i = 0;
    while (id_reg) {
        if ((id_reg  & 0xf) == id) ready |= 0x1 << i;
        i++;
        id_reg >>= 4;
    }

    return ready;
}


/*
 * ARTICo3 low-level hardware function
 *
 * Prints the current ARTICo3 configuration by directly accessing the
 * configuration registers in the Data Shuffler.
 *
 */
void artico3_hw_print_regs() {
    a3_print_debug("ARTICo3 configuration\n");
    a3_print_debug("  [REG] %-6s | %08x%08x\n", "id", artico3_hw[A3_ID_REG_HIGH], artico3_hw[A3_ID_REG_LOW]);
    a3_print_debug("  [REG] %-6s | %08x%08x\n", "tmr", artico3_hw[A3_TMR_REG_HIGH], artico3_hw[A3_TMR_REG_LOW]);
    a3_print_debug("  [REG] %-6s | %08x%08x\n", "dmr", artico3_hw[A3_DMR_REG_HIGH], artico3_hw[A3_DMR_REG_LOW]);
    a3_print_debug("  [REG] %-6s | %08x\n", "block", artico3_hw[A3_BLOCK_SIZE_REG]);
    a3_print_debug("  [REG] %-6s | %08x\n", "clk", artico3_hw[A3_CLOCK_GATE_REG]);
    a3_print_debug("  [REG] %-6s | %08x\n", "ready", artico3_hw[A3_READY_REG]);
}


/*
 * ARTICo3 low-level hardware function
 *
 * Sets up a data transfer by writing to the ARTICo3 configuration
 * registers (ID, TMR, DMR, block size).
 *
 * @blksize : block size (32-bit words to be sent to each accelerator)
 *
 */
void artico3_hw_setup_transfer(uint32_t blksize) {
    artico3_hw[A3_ID_REG_LOW]     = shuffler.id_reg & 0xFFFFFFFF;          // ID register low
    artico3_hw[A3_ID_REG_HIGH]    = (shuffler.id_reg >> 32) & 0xFFFFFFFF;  // ID register high
    artico3_hw[A3_TMR_REG_LOW]    = shuffler.tmr_reg & 0xFFFFFFFF;         // TMR register low
    artico3_hw[A3_TMR_REG_HIGH]   = (shuffler.tmr_reg >> 32) & 0xFFFFFFFF; // TMR register high
    artico3_hw[A3_DMR_REG_LOW]    = shuffler.dmr_reg & 0xFFFFFFFF;         // DMR register low
    artico3_hw[A3_DMR_REG_HIGH]   = (shuffler.dmr_reg >> 32) & 0xFFFFFFFF; // DMR register high
    artico3_hw[A3_BLOCK_SIZE_REG] = blksize;                               // Block size (# 32-bit words)
}


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
int artico3_hw_transfer_isdone(uint32_t readymask) {
    return ((artico3_hw[A3_READY_REG] & readymask) == readymask) ? 1 : 0;
}


/*
 * ARTICo3 low-level hardware function
 *
 * Enables the clock in the reconfigurable region (ARTICo3 slots).
 *
 */
void artico3_hw_enable_clk() {
    unsigned int i;
    uint32_t clkgate;

    // Enable clocks in reconfigurable region (TODO: change if a more precise power management is required)
    clkgate = 0;
    for (i = 0; i < A3_MAXSLOTS; i++) {
        clkgate |= 1 << i;
    }
    artico3_hw[A3_CLOCK_GATE_REG] = clkgate;
}


/*
 * ARTICo3 low-level hardware function
 *
 * Disables the clock in the reconfigurable region (ARTICo3 slots).
 *
 */
void artico3_hw_disable_clk() {
    // Disable clocks in reconfigurable region
    artico3_hw[A3_CLOCK_GATE_REG] = 0x00000000;
}
