/*
 * ARTICo³ kernel module
 *
 * Author   : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date     : April 2019
 *
 * Features :
 *     - Platform driver + character device
 *     - mmap()  : provides 1) zero-copy memory allocation (direct access
 *                 from user-space virtual memory to physical memory) for
 *                 data transfers using a DMA engine, and 2) direct access
 *                 to ARTICo³ configuration registers in the FPGA
 *     - ioctl() : enables command passing between user-space and
 *                 character device (e.g., to start DMA transfers)
 *     - poll()  : enables passive (i.e., sleep-based) waiting capabilities
 *                 for 1) DMA interrupts, and 2) ARTICo³ interrupts
 *     - [DMA] Targets memcpy operations (requires src and dst addresses)
 *     - [DMA] Relies on Device Tree (Open Firmware) to get DMA engine info
 *
 */

#ifndef _ARTICo3_H_
#define _ARTICo3_H_

#include <linux/ioctl.h>


/*
 * Basic data structure to use DMA proxy devices via ioctl()
 *
 * @memaddr - memory address
 * @memoff  - memory address offset
 * @hwaddr  - hardware address
 * @hwoff   - hardware address offset
 * @size    - number of bytes to be transferred
 *
 */
struct dmaproxy_token {
    void *memaddr;
    size_t memoff;
    void *hwaddr;
    size_t hwoff;
    size_t size;
};


/*
 * IOCTL definitions for DMA proxy devices
 *
 * dma_mem2hw - start transfer from main memory to hardware device
 * dma_hw2mem - start transfer from hardware device to main memory
 *
 */


#define ARTICo3_IOC_MAGIC 'x'

#define ARTICo3_IOC_DMA_MEM2HW _IOW(ARTICo3_IOC_MAGIC, 0, struct dmaproxy_token)
#define ARTICo3_IOC_DMA_HW2MEM _IOW(ARTICo3_IOC_MAGIC, 1, struct dmaproxy_token)

#define ARTICo3_IOC_MAXNR 1

#endif /* _ARTICo3_H_ */
