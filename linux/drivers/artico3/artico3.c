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

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/platform_device.h>
#include <linux/uaccess.h>
#include <linux/of.h>
#include <linux/errno.h>
#include <linux/mutex.h>
#include <linux/spinlock.h>
#include <linux/completion.h>
#include <linux/dma-mapping.h>
#include <linux/dmaengine.h>
#include <linux/mm.h>
#include <linux/list.h>
#include <linux/types.h>
#include <linux/ioport.h>
#include <linux/slab.h>
#include <linux/poll.h>
#include <linux/interrupt.h>
#include <linux/workqueue.h>
#include <linux/of_irq.h>

#include "artico3.h"
#define DRIVER_NAME "artico3"

#define dev_info(...)
#define printk(KERN_INFO ...)

/*
 * NOTE: using Xilinx DMA driver crashes the system, which means that,
 *       so far, it is not possible to use this driver with AXI CDMA
 *       IP cores (the ones that provide memcpy capabilities).
 *       Crashes involve random page errors, null pointer dereferences,
 *       unexpected process termination, and even NFS faults.
 *
 * In the event that those errors were fixed, the following change
 * should be applied in order to make this driver work with CDMA IPs:
 *     - #include <linux/dma-mapping.h>
 *     - #include <linux/dmaengine.h>
 *     + #include <linux/dma/xilinx_dma.h>
 *
 */


// ARTICo³ hardware information
struct artico3_hw {
    void __iomem *regs;                 // Hardware registers in ARTICo³
    uint32_t ready_prev;                // Previous ready register value
    uint32_t ready[ARTICo3_MAX_ID];     // Currently finished accelerators per kernel ID
    uint32_t readymask[ARTICo3_MAX_ID]; // Expected ready register values per kernel ID
};

// Custom device structure (DMA proxy device)
struct artico3_device {
    dev_t devt;
    struct cdev cdev;
    struct device *dev;
    struct platform_device *pdev;
    struct dma_chan *chan;
    dma_cookie_t cookie;
    struct mutex mutex;
    struct list_head head;
    spinlock_t lock;
    wait_queue_head_t queue;
    unsigned int irq;
    struct artico3_hw hw;
};

// Custom data structure to store allocated memory regions
struct artico3_vm_list {
    struct artico3_device *artico3_dev;
    void *addr_usr;
    void *addr_ker;
    dma_addr_t addr_phy;
    size_t size;
    pid_t pid;
    struct list_head list;
};

// Char device parameters
static dev_t devt;
static struct class *artico3_class;


/* IRQ MANAGEMENT */

// ARTICo³ ISR
static irqreturn_t artico3_isr(unsigned int irq, void *data) {

    struct artico3_device *artico3_dev = data;
    unsigned long flags;
    unsigned int id;
    uint32_t ready_reg, rising;

    //~ dev_info(artico3_dev->dev, "[ ] artico3_isr()");
    spin_lock_irqsave(&artico3_dev->lock, flags);

        // Read current ready register
        ready_reg = ioread32(artico3_dev->hw.regs + ARTICo3_READY_REG);
        //~ dev_info(artico3_dev->dev, "[i] ready : %08x | ready_prev : %08x", ready_reg, artico3_dev->hw.ready_prev);

        // Only act when rising edges are detected
        rising = (artico3_dev->hw.ready_prev ^ ready_reg) & ready_reg;
        if (rising) {
            // Iterate for all kernel IDs
            for (id = 1; id <= ARTICo3_MAX_ID; id++) {
                artico3_dev->hw.ready[id-1] |= rising & artico3_dev->hw.readymask[id-1];
                //~ dev_info(artico3_dev->dev, "[i] id : %2d | ready : %08x | mask : %08x", id, artico3_dev->hw.ready[id-1], artico3_dev->hw.readymask[id-1]);
            }
            // Inform poll() queue
            wake_up(&artico3_dev->queue);
        }

        // Update previous ready register
        artico3_dev->hw.ready_prev = ready_reg;

    spin_unlock_irqrestore(&artico3_dev->lock, flags);
    //~ dev_info(artico3_dev->dev, "[+] artico3_isr()");

    return IRQ_HANDLED;
}


/* DMA MANAGEMENT */

// DMA asynchronous callback function
static void artico3_dma_callback(void *data) {
    struct artico3_device *artico3_dev = data;
    //~ unsigned long flags;

    dev_info(artico3_dev->dev, "[ ] artico3_dma_callback()");
    //~ spin_lock_irqsave(&artico3_dev->lock, flags);
        wake_up(&artico3_dev->queue);
    //~ spin_unlock_irqrestore(&artico3_dev->lock, flags);
    dev_info(artico3_dev->dev, "[+] artico3_dma_callback()");
}

// DMA transfer function
static int artico3_dma_transfer(struct artico3_device *artico3_dev, dma_addr_t dst, dma_addr_t src, size_t len) {
    struct dma_device *dma_dev = artico3_dev->chan->device;
    struct dma_async_tx_descriptor *tx = NULL;
    enum dma_ctrl_flags flags = DMA_CTRL_ACK | DMA_PREP_INTERRUPT;
    int res = 0;

    dev_info(dma_dev->dev, "[ ] DMA transfer");
    dev_info(dma_dev->dev, "[i] source address      = %p", (void *)src);
    dev_info(dma_dev->dev, "[i] destination address = %p", (void *)dst);
    dev_info(dma_dev->dev, "[i] transfer length     = %d bytes", len);
    dev_info(dma_dev->dev, "[i] aligned transfer?   = %d", is_dma_copy_aligned(dma_dev, src, dst, len));

    // Initialize asynchronous DMA descriptor
    dev_info(dma_dev->dev, "[ ] device_prep_dma_memcpy()");
    tx = dma_dev->device_prep_dma_memcpy(artico3_dev->chan, dst, src, len, flags);
    if (!tx) {
        dev_err(dma_dev->dev, "[X] device_prep_dma_memcpy()");
        res = -ENOMEM;
        goto err_tx;
    }
    dev_info(dma_dev->dev, "[+] device_prep_dma_memcpy()");

    // Set asynchronous DMA transfer callback
    tx->callback = artico3_dma_callback;
    tx->callback_param = artico3_dev;

    // Submit DMA transfer
    dev_info(dma_dev->dev, "[ ] dmaengine_submit()");
    artico3_dev->cookie = dmaengine_submit(tx);
    res = dma_submit_error(artico3_dev->cookie);
    if (res) {
        dev_err(dma_dev->dev, "[X] dmaengine_submit()");
        goto err_cookie;
    }
    dev_info(dma_dev->dev, "[+] dmaengine_submit()");

    // Start pending transfers
    dma_async_issue_pending(artico3_dev->chan);

err_cookie:
    // Free descriptors
    dmaengine_desc_free(tx);

err_tx:
    dev_info(dma_dev->dev, "[+] DMA transfer");
    return res;
}

// Set up DMA subsystem
static int artico3_dma_init(struct platform_device *pdev) {
    int res;
    struct dma_chan *chan = NULL;
    const char *chan_name = ""; // e.g. "ps-dma"

    // Retrieve custom device info using platform device (private data)
    struct artico3_device *artico3_dev = platform_get_drvdata(pdev);

    // Get device tree node pointer from platform device structure
    struct device_node *node = pdev->dev.of_node;

    dev_info(&pdev->dev, "[ ] artico3_dma_init()");

    // Read DMA channel info from device tree (only the first occurrence is used)
    dev_info(&pdev->dev, "[ ] of_property_read_string()");
    res = of_property_read_string(node, "dma-names", &chan_name);
    //~ res = of_property_read_string_index(node, "dma-names", of_index, &chan_name);
    if (res) {
        dev_err(&pdev->dev, "[X] of_property_read_string()");
        return res;
    }
    dev_info(&pdev->dev, "[+] of_property_read_string() -> %s", chan_name);

    // Request DMA channel
    dev_info(&pdev->dev, "[ ] dma_request_slave_channel()");
    chan = dma_request_slave_channel(&pdev->dev, chan_name);
    if (IS_ERR(chan) || (!chan)) {
        dev_err(&pdev->dev, "[X] dma_request_slave_channel()");
        //return PTR_ERR(chan);
        return -EBUSY;
    }
    dev_info(&pdev->dev, "[+] dma_request_slave_channel() -> %s", chan_name);
    dev_info(chan->device->dev, "[i] dma_request_slave_channel()");

    artico3_dev->chan = chan;

    dev_info(&pdev->dev, "[+] artico3_dma_init()");
    return 0;
}

// Clean up DMA subsystem
static void artico3_dma_exit(struct platform_device *pdev) {

    // Retrieve custom device info using platform device (private data)
    struct artico3_device *artico3_dev = platform_get_drvdata(pdev);

    dev_info(&pdev->dev, "[ ] artico3_dma_exit()");
    dma_release_channel(artico3_dev->chan);
    dev_info(&pdev->dev, "[+] artico3_dma_exit()");
}


/* CHAR DEVICES */

// File operation on char device: open
static int artico3_open(struct inode *inodep, struct file *fp) {
    struct artico3_device *artico3_dev = container_of(inodep->i_cdev, struct artico3_device, cdev);
    fp->private_data = artico3_dev;
    dev_info(artico3_dev->dev, "[ ] open()");
    dev_info(artico3_dev->dev, "[+] open()");
    return 0;
}

// File operation on char device: release/close
static int artico3_release(struct inode *inodep, struct file *fp) {
    struct artico3_device *artico3_dev = container_of(inodep->i_cdev, struct artico3_device, cdev);
    fp->private_data = NULL;
    dev_info(artico3_dev->dev, "[ ] release()");
    dev_info(artico3_dev->dev, "[+] release()");
    return 0;
}

// File operation on char device: ioctl
static long artico3_ioctl(struct file *fp, unsigned int cmd, unsigned long arg) {
    struct artico3_device *artico3_dev = fp->private_data;
    struct artico3_vm_list *vm_list, *backup;
    struct dmaproxy_token token;
    struct platform_device *pdev = artico3_dev->pdev;
    resource_size_t address, size;
    int res;
    int retval = 0;
    struct resource *rsrc;
    uint64_t id_reg;
    unsigned int i;

    dev_info(artico3_dev->dev, "[ ] ioctl()");
    dev_info(artico3_dev->dev, "[i] ioctl() -> magic   = '%c'", _IOC_TYPE(cmd));
    dev_info(artico3_dev->dev, "[i] ioctl() -> command = %d", _IOC_NR(cmd));

    // Command precheck - step 1
    if (_IOC_TYPE(cmd) != ARTICo3_IOC_MAGIC) {
        dev_err(artico3_dev->dev, "[X] ioctl() -> magic does not match");
        return -ENOTTY;
    }

    // Command precheck - step 2
    if (_IOC_NR(cmd) > ARTICo3_IOC_MAXNR) {
        dev_err(artico3_dev->dev, "[X] ioctl() -> command number exceeds limit");
        return -ENOTTY;
    }

    // Command decoding
    switch (cmd) {

        case ARTICo3_IOC_DMA_MEM2HW:

            // Lock mutex (released in artico3_poll() after DMA transfer)
            mutex_lock(&artico3_dev->mutex);

            // Copy data from user
            dev_info(artico3_dev->dev, "[ ] copy_from_user()");
            res = copy_from_user(&token, (void *)arg, sizeof token);
            if (res) {
                dev_err(artico3_dev->dev, "[X] copy_from_user()");
                return -ENOMEM;
            }
            dev_info(artico3_dev->dev, "[+] copy_from_user() -> token");

            dev_info(artico3_dev->dev, "[i] DMA from memory to hardware");
            dev_info(artico3_dev->dev, "[i] DMA -> memory address   = %p", token.memaddr);
            dev_info(artico3_dev->dev, "[i] DMA -> memory offset    = %p", (void *)token.memoff);
            dev_info(artico3_dev->dev, "[i] DMA -> hardware address = %p", token.hwaddr);
            dev_info(artico3_dev->dev, "[i] DMA -> hardware offset  = %p", (void *)token.hwoff);
            dev_info(artico3_dev->dev, "[i] DMA -> transfer size    = %d bytes", token.size);

            // Transfers to constant input memories (transfer size is 0)
            if (token.size == 0) {
                // Get current ID register
                id_reg = (uint64_t)ioread32(artico3_dev->hw.regs + ARTICo3_ID_REG_HIGH) << 32 | (uint64_t)ioread32(artico3_dev->hw.regs + ARTICo3_ID_REG_LOW);
                // Compute expected ready value
                artico3_dev->hw.ready[((token.hwoff >> 16) & 0xf) - 1] = 0x00000000;
                artico3_dev->hw.readymask[((token.hwoff >> 16) & 0xf) - 1] = 0x00000000;
                i = 0;
                while (id_reg) {
                    if ((id_reg  & 0xf) == ((token.hwoff >> 16) & 0xf)) artico3_dev->hw.readymask[((token.hwoff >> 16) & 0xf) - 1] |= 0x1 << i;
                    i++;
                    id_reg >>= 4;
                }
                // Early release of mutex (this is not an actual transfer)
                mutex_unlock(&artico3_dev->mutex);
                // Exit ioctl()
                break;
            }

            // Search if the requested memory region is allocated
            list_for_each_entry_safe(vm_list, backup, &artico3_dev->head, list) {
                if ((vm_list->pid == current->pid) && (vm_list->addr_usr == token.memaddr)) {
                    // Memory check
                    if (vm_list->size < (token.memoff + token.size)) {
                        dev_err(artico3_dev->dev, "[X] DMA -> requested transfer out of memory region");
                        retval = -EINVAL;
                        break;
                    }
                    // Get resource info
                    rsrc = platform_get_resource_byname(artico3_dev->pdev, IORESOURCE_MEM, "data");
                    dev_info(&pdev->dev, "[i] resource name  = %s", rsrc->name);
                    dev_info(&pdev->dev, "[i] resource start = %lx", rsrc->start);
                    dev_info(&pdev->dev, "[i] resource end   = %lx", rsrc->end);
                    // Get memory map base address and size
                    address = rsrc->start;
                    size = rsrc->end - rsrc->start + 1;
                    // Hardware check
                    if (size < (token.hwoff + token.size)) {
                        dev_err(artico3_dev->dev, "[X] DMA Slave -> requested transfer out of hardware region");
                        retval = -EINVAL;
                        break;
                    }
                    // Address check
                    dev_info(artico3_dev->dev, "[i] hardware memory map start = %x", address);
                    if ((void *)address != token.hwaddr) {
                        dev_err(artico3_dev->dev, "[X] DMA Slave -> hardware address does not match");
                        retval = -EINVAL;
                        break;
                    }
                    // Get current ID register
                    id_reg = (uint64_t)ioread32(artico3_dev->hw.regs + ARTICo3_ID_REG_HIGH) << 32 | (uint64_t)ioread32(artico3_dev->hw.regs + ARTICo3_ID_REG_LOW);
                    // Compute expected ready value
                    artico3_dev->hw.ready[((token.hwoff >> 16) & 0xf) - 1] = 0x00000000;
                    artico3_dev->hw.readymask[((token.hwoff >> 16) & 0xf) - 1] = 0x00000000;
                    i = 0;
                    while (id_reg) {
                        if ((id_reg  & 0xf) == ((token.hwoff >> 16) & 0xf)) artico3_dev->hw.readymask[((token.hwoff >> 16) & 0xf) - 1] |= 0x1 << i;
                        i++;
                        id_reg >>= 4;
                    }
                    // Perform transfer
                    retval = artico3_dma_transfer(artico3_dev, address + token.hwoff, vm_list->addr_phy + token.memoff, token.size);
                    break;
                }
            }

            break;

        case ARTICo3_IOC_DMA_HW2MEM:

            // Lock mutex (released in artico3_poll() after DMA transfer)
            mutex_lock(&artico3_dev->mutex);

            // Copy data from user
            dev_info(artico3_dev->dev, "[ ] copy_from_user()");
            res = copy_from_user(&token, (void *)arg, sizeof token);
            if (res) {
                dev_err(artico3_dev->dev, "[X] copy_from_user()");
                return -ENOMEM;
            }
            dev_info(artico3_dev->dev, "[+] copy_from_user() -> token");

            dev_info(artico3_dev->dev, "[i] DMA from hardware to memory");
            dev_info(artico3_dev->dev, "[i] DMA -> memory address   = %p", token.memaddr);
            dev_info(artico3_dev->dev, "[i] DMA -> memory offset    = %p", (void *)token.memoff);
            dev_info(artico3_dev->dev, "[i] DMA -> hardware address = %p", token.hwaddr);
            dev_info(artico3_dev->dev, "[i] DMA -> hardware offset  = %p", (void *)token.hwoff);
            dev_info(artico3_dev->dev, "[i] DMA -> transfer size    = %d bytes", token.size);

            // Search if the requested memory region is allocated
            list_for_each_entry_safe(vm_list, backup, &artico3_dev->head, list) {
                if ((vm_list->pid == current->pid) && (vm_list->addr_usr == token.memaddr)) {
                    // Memory check
                    if (vm_list->size < (token.memoff + token.size)) {
                        dev_err(artico3_dev->dev, "[X] DMA -> requested transfer out of memory region");
                        retval = -EINVAL;
                        break;
                    }
                    // Get resource info
                    rsrc = platform_get_resource_byname(artico3_dev->pdev, IORESOURCE_MEM, "data");
                    dev_info(&pdev->dev, "[i] resource name  = %s", rsrc->name);
                    dev_info(&pdev->dev, "[i] resource start = %lx", rsrc->start);
                    dev_info(&pdev->dev, "[i] resource end   = %lx", rsrc->end);
                    // Get memory map base address and size
                    address = rsrc->start;
                    size = rsrc->end - rsrc->start + 1;
                    // Hardware check
                    if (size < (token.hwoff + token.size)) {
                        dev_err(artico3_dev->dev, "[X] DMA Slave -> requested transfer out of hardware region");
                        retval = -EINVAL;
                        break;
                    }
                    // Address check
                    dev_info(artico3_dev->dev, "[i] hardware memory map start = %x", address);
                    if ((void *)address != token.hwaddr) {
                        dev_err(artico3_dev->dev, "[X] DMA Slave -> hardware address does not match");
                        retval = -EINVAL;
                        break;
                    }
                    // Perform transfer
                    retval = artico3_dma_transfer(artico3_dev, vm_list->addr_phy + token.memoff, address + token.hwoff, token.size);
                    break;
                }
            }

            break;

        default:
            dev_err(artico3_dev->dev, "[i] ioctl() -> command %x does not exist", cmd);
            retval = -ENOTTY;

    }

    dev_info(artico3_dev->dev, "[+] ioctl()");
    return retval;
}

// mmap close function (required to free allocated memory) - DMA transfers
static void artico3_mmap_dma_close(struct vm_area_struct *vma) {
    struct artico3_vm_list *token = vma->vm_private_data;
    struct artico3_device *artico3_dev = token->artico3_dev;
    struct dma_device *dma_dev = artico3_dev->chan->device;

    dev_info(artico3_dev->dev, "[ ] munmap()");
    dev_info(artico3_dev->dev, "[i] vma->vm_start = %p", (void *)vma->vm_start);
    dev_info(artico3_dev->dev, "[i] vma->vm_end   = %p", (void *)vma->vm_end);
    dev_info(artico3_dev->dev, "[i] vma size      = %ld bytes", vma->vm_end - vma->vm_start);

    dma_free_coherent(dma_dev->dev, token->size, token->addr_ker, token->addr_phy);

    // Critical section: remove region from dynamic list
    mutex_lock(&artico3_dev->mutex);
    list_del(&token->list);
    mutex_unlock(&artico3_dev->mutex);

    kfree(token);
    vma->vm_private_data = NULL;

    dev_info(artico3_dev->dev, "[+] munmap()");
}

// mmap specific operations - DMA transfers
static struct vm_operations_struct artico3_mmap_dma_ops = {
    .close = artico3_mmap_dma_close,
};

// File operation on char device: mmap - DMA transfers
static int artico3_mmap_dma(struct file *fp, struct vm_area_struct *vma) {
    struct artico3_device *artico3_dev = fp->private_data;
    struct dma_device *dma_dev = artico3_dev->chan->device;
    void *addr_vir = NULL;
    dma_addr_t addr_phy;
    struct artico3_vm_list *token = NULL;
    int res;

    dev_info(artico3_dev->dev, "[ ] mmap_dma()");
    dev_info(artico3_dev->dev, "[i] vma->vm_start = %p", (void *)vma->vm_start);
    dev_info(artico3_dev->dev, "[i] vma->vm_end   = %p", (void *)vma->vm_end);
    dev_info(artico3_dev->dev, "[i] vma size      = %ld bytes", vma->vm_end - vma->vm_start);

    // Allocate memory in kernel space
    dev_info(dma_dev->dev, "[ ] dma_alloc_coherent()");
    addr_vir = dma_alloc_coherent(dma_dev->dev, vma->vm_end - vma->vm_start, &addr_phy, GFP_KERNEL);
    if (IS_ERR(addr_vir)) {
        dev_err(dma_dev->dev, "[X] dma_alloc_coherent()");
        return PTR_ERR(addr_vir);
    }
    dev_info(dma_dev->dev, "[+] dma_alloc_coherent()");
    dev_info(dma_dev->dev, "[i] dma_alloc_coherent() -> %p (virtual)", addr_vir);
    dev_info(dma_dev->dev, "[i] dma_alloc_coherent() -> %p (physical)", (void *)addr_phy);
    dev_info(dma_dev->dev, "[i] dma_alloc_coherent() -> %ld bytes", vma->vm_end - vma->vm_start);

    // Map kernel-space memory to DMA space
    dev_info(dma_dev->dev, "[ ] dma_mmap_coherent()");
    res = dma_mmap_coherent(dma_dev->dev, vma, addr_vir, addr_phy, vma->vm_end - vma->vm_start);
    if (res) {
        dev_err(dma_dev->dev, "[X] dma_mmap_coherent() %d", res);
        goto err_dma_mmap;
    }
    dev_info(dma_dev->dev, "[+] dma_mmap_coherent()");

    // Create data structure with allocated memory info
    dev_info(artico3_dev->dev, "[ ] kzalloc() -> token");
    token = kzalloc(sizeof *token, GFP_KERNEL);
    if (!token) {
        dev_err(artico3_dev->dev, "[X] kzalloc() -> token");
        res = -ENOMEM;
        goto err_kmalloc_token;
    }
    dev_info(artico3_dev->dev, "[+] kzalloc() -> token");

    // Set values in data structure
    token->artico3_dev = artico3_dev;
    token->addr_usr = (void *)vma->vm_start;
    token->addr_ker = addr_vir;
    token->addr_phy = addr_phy;
    token->size = vma->vm_end - vma->vm_start;
    token->pid = current->pid;
    INIT_LIST_HEAD(&token->list);

    // Critical section: add new region to dynamic list
    mutex_lock(&artico3_dev->mutex);
    list_add(&token->list, &artico3_dev->head);
    mutex_unlock(&artico3_dev->mutex);

    // Set virtual memory structure operations
    vma->vm_ops = &artico3_mmap_dma_ops;

    // Pass data to virtual memory structure (private data) to enable proper cleanup
    vma->vm_private_data = token;

    dev_info(artico3_dev->dev, "[+] mmap_dma()");
    return 0;

err_kmalloc_token:

err_dma_mmap:
    dma_free_coherent(dma_dev->dev, vma->vm_end - vma->vm_start, addr_vir, addr_phy);
    return res;
}

// mmap specific operations - HW access
static struct vm_operations_struct artico3_mmap_hw_ops = {
#ifdef CONFIG_HAVE_IOREMAP_PROT
    .access = generic_access_phys,
#endif
};

// File operation on char device: mmap - HW access
static int artico3_mmap_hw(struct file *fp, struct vm_area_struct *vma) {
    struct artico3_device *artico3_dev = fp->private_data;
    struct resource *rsrc;

    dev_info(artico3_dev->dev, "[ ] mmap_hw()");
    dev_info(artico3_dev->dev, "[i] vma->vm_start = %p", (void *)vma->vm_start);
    dev_info(artico3_dev->dev, "[i] vma->vm_end   = %p", (void *)vma->vm_end);
    dev_info(artico3_dev->dev, "[i] vma size      = %ld bytes", vma->vm_end - vma->vm_start);

    vma->vm_private_data = artico3_dev;
    vma->vm_ops = &artico3_mmap_hw_ops;
    vma->vm_page_prot = pgprot_noncached(vma->vm_page_prot);

    rsrc = platform_get_resource_byname(artico3_dev->pdev, IORESOURCE_MEM, "ctrl");
    dev_info(artico3_dev->dev, "[i] resource name  = %s", rsrc->name);
    dev_info(artico3_dev->dev, "[i] resource start = 0x%x", rsrc->start);
    dev_info(artico3_dev->dev, "[i] resource end   = 0x%x", rsrc->end);

    dev_info(artico3_dev->dev, "[+] mmap_hw()");

    return remap_pfn_range(vma, vma->vm_start, rsrc->start >> PAGE_SHIFT, vma->vm_end - vma->vm_start, vma->vm_page_prot);
}

// File operation on char device: mmap
static int artico3_mmap(struct file *fp, struct vm_area_struct *vma) {
    struct artico3_device *artico3_dev = fp->private_data;
    int res;
    int mem_idx = (int)vma->vm_pgoff;

    dev_info(artico3_dev->dev, "[ ] mmap()");
    dev_info(artico3_dev->dev, "[i] memory index : %d", mem_idx);
    switch (mem_idx) {
        case 0:
            dev_info(artico3_dev->dev, "[i] ARTICo\u00b3 control map");
            res = artico3_mmap_hw(fp, vma);
            break;
        case 1:
            dev_info(artico3_dev->dev, "[i] ARTICo\u00b3 data map");
            vma->vm_pgoff = 0; // Trick to avoid errors on dma_mmap_coherent()
            res = artico3_mmap_dma(fp, vma);
            break;
        default:
            dev_info(artico3_dev->dev, "[i] YOU SHOULD NOT BE HERE");
            res = -EINVAL;
            break;
    }
    dev_info(artico3_dev->dev, "[+] mmap()");

    return res;
}

// File operation on char device: poll
static unsigned int artico3_poll(struct file *fp, struct poll_table_struct *wait) {
    struct artico3_device *artico3_dev = fp->private_data;
    unsigned long flags;
    unsigned int ret, id;
    enum dma_status status;

    dev_info(artico3_dev->dev, "[ ] poll()");
    poll_wait(fp, &artico3_dev->queue, wait);
    spin_lock_irqsave(&artico3_dev->lock, flags);
        // Set default return value for poll()
        ret = 0;

        //
        // DMA check
        //
        // NOTE: this implementation does not consider errors in the data
        //       transfers.  If the callback is executed, it is assumed
        //       that the following check will always render DMA_COMPLETE.
        status = dma_async_is_tx_complete(artico3_dev->chan, artico3_dev->cookie, NULL, NULL);
        if (status == DMA_COMPLETE) {
            dev_info(artico3_dev->dev, "[i] poll() : ret |= POLLDMA");
            ret |= POLLDMA;
            // Release mutex (acquired in artico3_ioctl() before DMA transfer)
            mutex_unlock(&artico3_dev->mutex);
        }

        //
        // IRQ/Ready check
        //
        for (id = 1; id <= ARTICo3_MAX_ID; id++) {
            if ((artico3_dev->hw.readymask[id-1] != 0) && ((artico3_dev->hw.ready[id-1] & artico3_dev->hw.readymask[id-1]) == artico3_dev->hw.readymask[id-1])) {
                dev_info(artico3_dev->dev, "[i] poll() : ret |= POLLIRQ(%d)", id);
                ret |= POLLIRQ(id);
            }
        }
    spin_unlock_irqrestore(&artico3_dev->lock, flags);

    dev_info(artico3_dev->dev, "[+] poll()");
    return ret;
}


static struct file_operations artico3_fops = {
    .owner          = THIS_MODULE,
    .open           = artico3_open,
    .release        = artico3_release,
    .unlocked_ioctl = artico3_ioctl,
    .mmap           = artico3_mmap,
    .poll           = artico3_poll,
};

// Creates a char device to act as user-space entry point
static int artico3_cdev_create(struct platform_device *pdev) {
    int res;

    // Retrieve custom device info using platform device (private data)
    struct artico3_device *artico3_dev = platform_get_drvdata(pdev);

    dev_info(&pdev->dev, "[ ] artico3_cdev_create()");

    // Set device structure parameters
    artico3_dev->devt = MKDEV(MAJOR(devt), 0);

    // Add char device to the system
    dev_info(&pdev->dev, "[ ] cdev_add()");
    cdev_init(&artico3_dev->cdev, &artico3_fops);
    res = cdev_add(&artico3_dev->cdev, artico3_dev->devt, 1);
    if (res) {
        dev_err(&pdev->dev, "[X] cdev_add() -> %d:%d", MAJOR(artico3_dev->devt), MINOR(artico3_dev->devt));
        return res;
    }
    dev_info(&pdev->dev, "[+] cdev_add() -> %d:%d", MAJOR(artico3_dev->devt), MINOR(artico3_dev->devt));

    // Create char device
    dev_info(&pdev->dev, "[ ] device_create()");
    artico3_dev->dev = device_create(artico3_class, &pdev->dev, artico3_dev->devt, artico3_dev, "%s", DRIVER_NAME);
    if (IS_ERR(artico3_dev->dev)) {
        dev_err(&pdev->dev, "[X] device_create() -> %d:%d", MAJOR(artico3_dev->devt), MINOR(artico3_dev->devt));
        res = PTR_ERR(artico3_dev->dev);
        goto err_device;
    }
    dev_info(&pdev->dev, "[+] device_create() -> %d:%d", MAJOR(artico3_dev->devt), MINOR(artico3_dev->devt));
    dev_info(artico3_dev->dev, "[i] device_create()");

    dev_info(&pdev->dev, "[+] artico3_cdev_create()");
    return 0;

err_device:
    cdev_del(&artico3_dev->cdev);

    return res;
}

// Deletes a char device that acted as user-space entry point
static void artico3_cdev_destroy(struct platform_device *pdev) {

    // Retrieve custom device info using platform device (private data)
    struct artico3_device *artico3_dev = platform_get_drvdata(pdev);

    dev_info(&pdev->dev, "[ ] artico3_cdev_destroy()");

    dev_info(artico3_dev->dev, "[i] artico3_cdev_destroy()");

    // Destroy device
    device_destroy(artico3_class, artico3_dev->devt);
    cdev_del(&artico3_dev->cdev);

    dev_info(&pdev->dev, "[+] artico3_cdev_destroy()");
}

// Initializes char device support
static int artico3_cdev_init(void) {
    int res;

    printk(KERN_INFO "%s [ ] artico3_cdev_init()\n", DRIVER_NAME);

    // Dynamically allocate major number for char device
    printk(KERN_INFO "%s [ ] alloc_chrdev_region()\n", DRIVER_NAME);
    res = alloc_chrdev_region(&devt, 0, 1, DRIVER_NAME);
    if (res < 0) {
        printk(KERN_ERR "%s [X] alloc_chrdev_region()\n", DRIVER_NAME);
        return res;
    }
    printk(KERN_INFO "%s [+] alloc_chrdev_region() -> %d:%d-%d\n", DRIVER_NAME, MAJOR(devt), MINOR(devt), MINOR(devt));

    // Create sysfs class
    printk(KERN_INFO "%s [ ] class_create()\n", DRIVER_NAME);
    artico3_class = class_create(THIS_MODULE, DRIVER_NAME);
    if (IS_ERR(artico3_class)) {
        printk(KERN_ERR "%s [X] class_create()\n", DRIVER_NAME);
        res = PTR_ERR(artico3_class);
        goto err_class;
    }
    printk(KERN_INFO "%s [+] class_create() -> /sys/class/%s\n", DRIVER_NAME, DRIVER_NAME);

    printk(KERN_INFO "%s [+] artico3_cdev_init()\n", DRIVER_NAME);
    return 0;

err_class:
    unregister_chrdev_region(devt, 1);
    return res;
}

// Cleans up char device support
static void artico3_cdev_exit(void) {
    printk(KERN_INFO "%s [ ] artico3_cdev_exit()\n", DRIVER_NAME);
    class_destroy(artico3_class);
    unregister_chrdev_region(devt, 1);
    printk(KERN_INFO "%s [+] artico3_cdev_exit()\n", DRIVER_NAME);
}


/* PLATFORM DRIVER */

// Actions to perform when the device is added (shows up in the device tree)
static int artico3_probe(struct platform_device *pdev) {
    int res, id;
    struct artico3_device *artico3_dev = NULL;
    struct resource *rsrc;

    dev_info(&pdev->dev, "[ ] artico3_probe()");

    // Allocate memory for custom device structure
    dev_info(&pdev->dev, "[ ] kzalloc() -> artico3_dev");
    artico3_dev = kzalloc(sizeof *artico3_dev, GFP_KERNEL);
    if (!artico3_dev) {
        dev_err(&pdev->dev, "[X] kzalloc() -> artico3_dev");
        return -ENOMEM;
    }
    dev_info(&pdev->dev, "[+] kzalloc() -> artico3_dev");

    // Initialize list head
    INIT_LIST_HEAD(&artico3_dev->head);

    // Pass platform device pointer to custom device structure
    artico3_dev->pdev = pdev;

    // Pass newly created custom device to platform device (as private data)
    platform_set_drvdata(pdev, artico3_dev);

    // Initialize DMA subsystem
    res = artico3_dma_init(pdev);
    if (res) {
        dev_err(&pdev->dev, "[X] artico3_dma_init()");
        goto err_dma_init;
    }

    // Create char device
    res = artico3_cdev_create(pdev);
    if (res) {
        dev_err(&pdev->dev, "[X] artico3_cdev_create()");
        goto err_cdev_create;
    }

    // Initialize synchronization primitives
    mutex_init(&artico3_dev->mutex);
    spin_lock_init(&artico3_dev->lock);
    init_waitqueue_head(&artico3_dev->queue);

    // Initialize hardware information
    dev_info(&pdev->dev, "[ ] ioremap()");
    rsrc = platform_get_resource_byname(artico3_dev->pdev, IORESOURCE_MEM, "ctrl");
    dev_info(&pdev->dev, "[i] resource name  = %s", rsrc->name);
    dev_info(&pdev->dev, "[i] resource start = %lx", rsrc->start);
    dev_info(&pdev->dev, "[i] resource end   = %lx", rsrc->end);
    artico3_dev->hw.regs = ioremap(rsrc->start, rsrc->end - rsrc->start);
    if (!artico3_dev->hw.regs) {
        dev_err(&pdev->dev, "[X] ioremap()");
        res = -ENOMEM;
        goto err_ioremap;
    }
    artico3_dev->hw.ready_prev = 0x00000000;
    for (id = 1; id <= ARTICo3_MAX_ID; id++) {
        artico3_dev->hw.ready[id-1] = 0x00000000;
        artico3_dev->hw.readymask[id-1] = 0x00000000;
    }
    dev_info(&pdev->dev, "[+] ioremap()");

    // Register IRQ
    dev_info(&pdev->dev, "[ ] request_irq()");
    rsrc = platform_get_resource_byname(artico3_dev->pdev, IORESOURCE_IRQ, "irq");
    dev_info(&pdev->dev, "[i] resource name  = %s", rsrc->name);
    dev_info(&pdev->dev, "[i] resource start = %lx", rsrc->start);
    dev_info(&pdev->dev, "[i] resource end   = %lx", rsrc->end);
    artico3_dev->irq = rsrc->start;
    res = request_irq(artico3_dev->irq, (irq_handler_t)artico3_isr, IRQF_TRIGGER_RISING, "artico3", artico3_dev);
    if (res) {
        dev_err(&pdev->dev, "[X] request_irq()");
        goto err_irq;
    }
    dev_info(&pdev->dev, "[+] request_irq()");

    dev_info(&pdev->dev, "[+] artico3_probe()");
    return 0;

err_irq:
    iounmap(artico3_dev->hw.regs);

err_ioremap:
    artico3_cdev_destroy(pdev);

err_cdev_create:
    artico3_dma_exit(pdev);

err_dma_init:
    kfree(artico3_dev);
    return res;
}

// Actions to perform when the device is removed (dissappears from the device tree)
static int artico3_remove(struct platform_device *pdev) {

    // Retrieve custom device info using platform device (private data)
    struct artico3_device *artico3_dev = platform_get_drvdata(pdev);

    dev_info(&pdev->dev, "[ ] artico3_remove()");

    free_irq(artico3_dev->irq, artico3_dev);
    iounmap(artico3_dev->hw.regs);
    mutex_destroy(&artico3_dev->mutex);
    artico3_cdev_destroy(pdev);
    artico3_dma_exit(pdev);
    kfree(artico3_dev);

    dev_info(&pdev->dev, "[+] artico3_remove()");
    return 0;
}

// Device tree (Open Firmware) matching table
static const struct of_device_id artico3_of_match[] = {
    { .compatible = "cei.upm,artico3-1.00.a", },
    {}
};

// Driver structure
static struct platform_driver artico3_driver = {
    .probe  = artico3_probe,
    .remove = artico3_remove,
    .driver = {
        .name           = DRIVER_NAME,
        .of_match_table = artico3_of_match,
    },
};


/* KERNEL MODULE */

// Module initialization
static int __init artico3_init(void) {
    int res;

    printk(KERN_INFO "%s [ ] artico3_init()\n", DRIVER_NAME);

    // Initialize char device(s)
    res = artico3_cdev_init();
    if (res) {
        printk(KERN_ERR "%s [X] artico3_cdev_init()\n", DRIVER_NAME);
        return res;
    }

    // Register platform driver
    printk(KERN_INFO "%s [ ] platform_driver_register()\n", DRIVER_NAME);
    res = platform_driver_register(&artico3_driver);
    if (res) {
        printk(KERN_ERR "%s [X] platform_driver_register()\n", DRIVER_NAME);
        goto err_driver;
    }
    printk(KERN_INFO "%s [+] platform_driver_register()\n", DRIVER_NAME);

    printk(KERN_INFO "%s [+] artico3_init()\n", DRIVER_NAME);
    return 0;

err_driver:
    artico3_cdev_exit();
    return res;
}

// Module cleanup
static void __exit artico3_exit(void) {
    printk(KERN_INFO "%s [ ] artico3_exit()\n", DRIVER_NAME);
    platform_driver_unregister(&artico3_driver);
    artico3_cdev_exit();
    printk(KERN_INFO "%s [+] artico3_exit()\n", DRIVER_NAME);
}

module_init(artico3_init);
module_exit(artico3_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Alfonso Rodriguez <alfonso.rodriguezm@upm.es>");
MODULE_DESCRIPTION("ARTICo\u00b3 kernel module");
MODULE_VERSION("1.0");
