/*
 * DMA proxy kernel module
 *
 * Author   : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date     : July 2017
 *
 * Features :
 *     - Platform driver + character device
 *     - Targets memcpy operations (requires src and dst addresses)
 *     - Relies on Device Tree (Open Firmware) to get DMA engine info
 *     - mmap()  : provides zero-copy memory allocation (direct access
 *                 from user-space virtual memory to physical memory)
 *     - ioctl() : enables command passing between user-space and
 *                 character device (e.g. to start DMA transfers)
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

#include "dmaproxy.h"
#define DRIVER_NAME "dmaproxy"

//~ #define dev_err(...)
#define dev_info(...)
#define printk(KERN_INFO ...)
//~ #define printk(...)

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


// Custom device structure (DMA proxy device)
struct dmaproxy_device {
    int id;
    dev_t devt;
    struct cdev cdev;
    struct device *dev;
    struct platform_device *pdev;
    struct dma_chan *chan;
    struct mutex mutex;
    struct list_head head;
    rwlock_t lock;
    struct completion cmp;
};

static int max_devices = 16;
module_param(max_devices, int, 0440);
MODULE_PARM_DESC(max_devices, "Maximum number of proxy devices that can be created");

//~ static int of_index = 0;
//~ module_param(of_index, int, 0440);
//~ MODULE_PARM_DESC(of_index, "DMA index in dma-names field (device tree)");

// Minor numbers for char devices are assigned dynamically using this "table"
static char *minor;
DEFINE_MUTEX(minor_mutex);

// Custom data structure to store allocated memory regions
struct dmaproxy_vm_list {
    struct dmaproxy_device *dmaproxy_dev;
    void *addr_usr;
    void *addr_ker;
    dma_addr_t addr_phy;
    size_t size;
    pid_t pid;
    struct list_head list;
};

// Char device parameters
static dev_t devt;
static struct class *dmaproxy_class;


/* DMA MANAGEMENT */

// DMA asynchronous callback function
static void dmaproxy_dma_callback(void *data) {
    struct dmaproxy_device *dmaproxy_dev = data;
    unsigned long flags;

    dev_info(dmaproxy_dev->dev, "[ ] dmaproxy_dma_callback()");
    write_lock_irqsave(&dmaproxy_dev->lock, flags);
    complete(&dmaproxy_dev->cmp);
    write_unlock_irqrestore(&dmaproxy_dev->lock, flags);
    dev_info(dmaproxy_dev->dev, "[+] dmaproxy_dma_callback()");
}

// DMA transfer function
static int dmaproxy_dma_transfer(struct dmaproxy_device *dmaproxy_dev, dma_addr_t dst, dma_addr_t src, size_t len) {
    struct dma_device *dma_dev = dmaproxy_dev->chan->device;
    struct dma_async_tx_descriptor *tx = NULL;
    dma_cookie_t cookie;
    enum dma_ctrl_flags flags = DMA_CTRL_ACK | DMA_PREP_INTERRUPT;
    enum dma_status status;
    unsigned long timeout = msecs_to_jiffies(3000);
    int res = 0;

    dev_info(dma_dev->dev, "[ ] DMA transfer");
    dev_info(dma_dev->dev, "[i] source address      = %p", (void *)src);
    dev_info(dma_dev->dev, "[i] destination address = %p", (void *)dst);
    dev_info(dma_dev->dev, "[i] transfer length     = %d bytes", len);
    dev_info(dma_dev->dev, "[i] aligned transfer?   = %d", is_dma_copy_aligned(dma_dev, src, dst, len));

    // Initialize asynchronous DMA descriptor
    dev_info(dma_dev->dev, "[ ] device_prep_dma_memcpy()");
    tx = dma_dev->device_prep_dma_memcpy(dmaproxy_dev->chan, dst, src, len, flags);
    if (!tx) {
        dev_err(dma_dev->dev, "[X] device_prep_dma_memcpy()");
        res = -ENOMEM;
        goto err_tx;
    }
    dev_info(dma_dev->dev, "[+] device_prep_dma_memcpy()");

    // Initialize completion flag
    write_lock_irq(&dmaproxy_dev->lock);
    reinit_completion(&dmaproxy_dev->cmp);
    write_unlock_irq(&dmaproxy_dev->lock);

    // Set asynchronous DMA transfer callback
    tx->callback = dmaproxy_dma_callback;
    tx->callback_param = dmaproxy_dev;

    // Submit DMA transfer
    dev_info(dma_dev->dev, "[ ] dmaengine_submit()");
    cookie = dmaengine_submit(tx);
    if (dma_submit_error(cookie)) {
        dev_err(dma_dev->dev, "[X] dmaengine_submit()");
        res = dma_submit_error(cookie);
        goto err_cookie;
    }
    dev_info(dma_dev->dev, "[+] dmaengine_submit()");

    // Start pending transfers
    dma_async_issue_pending(dmaproxy_dev->chan);

    /*
     * NOTE: using rwlock_t to protect access to dmaproxy_dev->cmp
     *       (struct completion cmp), generates problems in the kernel,
     *       even forcing system stall.
     *       The problem seems to be calling wait_for_completion(),
     *       since it implicitly calls schedule(), and doing so after
     *       taking the rwlock_t causes malfunctioning.
     *       The question here is: can we assume that removing the
     *       read_lock() function is safe? If not, the code needs some
     *       rethinking to remove the wait_for_completion() call.
     *
     *
     * BUG: scheduling while atomic: dma1.elf/729/0x00000002
     * Modules linked in: mdmaproxy(O)
     * CPU: 0 PID: 729 Comm: dma1.elf Tainted: G           O    4.9.0-xilinx-dirty #1
     * Hardware name: Xilinx Zynq Platform
     * [<c010e48c>] (unwind_backtrace) from [<c010a664>] (show_stack+0x10/0x14)
     * [<c010a664>] (show_stack) from [<c02df5cc>] (dump_stack+0x80/0xa0)
     * [<c02df5cc>] (dump_stack) from [<c01379c8>] (__schedule_bug+0x60/0x84)
     * [<c01379c8>] (__schedule_bug) from [<c060c270>] (__schedule+0x54/0x430)
     * [<c060c270>] (__schedule) from [<c060c6fc>] (schedule+0xb0/0xcc)
     * [<c060c6fc>] (schedule) from [<c060f24c>] (schedule_timeout+0x28c/0x2c4)
     * [<c060f24c>] (schedule_timeout) from [<c060d18c>] (wait_for_common+0x110/0x150)
     * [<c060d18c>] (wait_for_common) from [<bf000910>] (dmaproxy_dma_transfer+0x94/0xfc [mdmaproxy])
     * [<bf000910>] (dmaproxy_dma_transfer [mdmaproxy]) from [<bf0003a0>] (dmaproxy_ioctl+0x288/0x2ec [mdmaproxy])
     * [<bf0003a0>] (dmaproxy_ioctl [mdmaproxy]) from [<c01de5ec>] (vfs_ioctl+0x20/0x34)
     * [<c01de5ec>] (vfs_ioctl) from [<c01dee88>] (do_vfs_ioctl+0x764/0x8b4)
     * [<c01dee88>] (do_vfs_ioctl) from [<c01df00c>] (SyS_ioctl+0x34/0x5c)
     * [<c01df00c>] (SyS_ioctl) from [<c0106e00>] (ret_fast_syscall+0x0/0x3c)
     *
     */

    // Wait for transfer to finish or to timeout
    dev_info(dma_dev->dev, "[ ] wait_for_completion_timeout()");
    //~ read_lock_irq(&dmaproxy_dev->lock);
    timeout = wait_for_completion_timeout(&dmaproxy_dev->cmp, timeout);
    //~ read_unlock_irq(&dmaproxy_dev->lock);
    status = dma_async_is_tx_complete(dmaproxy_dev->chan, cookie, NULL, NULL);
    if (timeout == 0) {
        dev_err(dma_dev->dev, "[X] wait_for_completion_timeout() -> timeout expired");
        res = -EBUSY;
    }
    else if (status != DMA_COMPLETE) {
        dev_err(dma_dev->dev, "[X] wait_for_completion_timeout() -> received callback, status is '%s'", (status == DMA_ERROR) ? "error" : "in progress");
        res = -EBUSY;
    }
    dev_info(dma_dev->dev, "[+] wait_for_completion_timeout()");

err_cookie:
    // Free descriptors
    dmaengine_desc_free(tx);

err_tx:
    dev_info(dma_dev->dev, "[+] DMA transfer");
    return res;
}

// Set up DMA subsystem
static int dmaproxy_dma_init(struct platform_device *pdev) {
    int res;
    struct dma_chan *chan = NULL;
    const char *chan_name = ""; // e.g. "ps-dma"

    // Retrieve custom device info using platform device (private data)
    struct dmaproxy_device *dmaproxy_dev = platform_get_drvdata(pdev);

    // Get device tree node pointer from platform device structure
    struct device_node *node = pdev->dev.of_node;

    dev_info(&pdev->dev, "[ ] dmaproxy_dma_init()");

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

    dmaproxy_dev->chan = chan;

    dev_info(&pdev->dev, "[+] dmaproxy_dma_init()");
    return 0;
}

// Clean up DMA subsystem
static void dmaproxy_dma_exit(struct platform_device *pdev) {

    // Retrieve custom device info using platform device (private data)
    struct dmaproxy_device *dmaproxy_dev = platform_get_drvdata(pdev);

    dev_info(&pdev->dev, "[ ] dmaproxy_dma_exit()");
    dma_release_channel(dmaproxy_dev->chan);
    dev_info(&pdev->dev, "[+] dmaproxy_dma_exit()");
}


/* CHAR DEVICES */

// File operation on char device: open
static int dmaproxy_open(struct inode *inodep, struct file *fp) {
    struct dmaproxy_device *dmaproxy_dev = container_of(inodep->i_cdev, struct dmaproxy_device, cdev);
    fp->private_data = dmaproxy_dev;
    dev_info(dmaproxy_dev->dev, "[ ] open()");
    dev_info(dmaproxy_dev->dev, "[+] open()");
    return 0;
}

// File operation on char device: release/close
static int dmaproxy_release(struct inode *inodep, struct file *fp) {
    struct dmaproxy_device *dmaproxy_dev = container_of(inodep->i_cdev, struct dmaproxy_device, cdev);
    //~ fp->private_data = NULL;
    dev_info(dmaproxy_dev->dev, "[ ] release()");
    dev_info(dmaproxy_dev->dev, "[+] release()");
    return 0;
}

// File operation on char device: read
ssize_t dmaproxy_read(struct file *fp, char __user *buffer, size_t size, loff_t *offset) {
    struct dmaproxy_device *dmaproxy_dev = fp->private_data;
    dev_info(dmaproxy_dev->dev, "[ ] read()");
    dev_info(dmaproxy_dev->dev, "[+] read()");
    return 0;
}

// File operation on char device: write
ssize_t dmaproxy_write(struct file *fp, const char __user *buffer, size_t size, loff_t *offset) {
    struct dmaproxy_device *dmaproxy_dev = fp->private_data;
    dev_info(dmaproxy_dev->dev, "[ ] write()");
    dev_info(dmaproxy_dev->dev, "[+] write()");
    return size;
}

// File operation on char device: ioctl
static long dmaproxy_ioctl(struct file *fp, unsigned int cmd, unsigned long arg) {
    struct dmaproxy_device *dmaproxy_dev = fp->private_data;
    struct dmaproxy_vm_list *vm_list, *backup;
    struct dmaproxy_token token;
    struct platform_device *pdev = dmaproxy_dev->pdev;
    resource_size_t address, size;
    int res;
    int retval = 0;

    dev_info(dmaproxy_dev->dev, "[ ] ioctl()");
    dev_info(dmaproxy_dev->dev, "[i] ioctl() -> magic   = '%c'", _IOC_TYPE(cmd));
    dev_info(dmaproxy_dev->dev, "[i] ioctl() -> command = %d", _IOC_NR(cmd));

    // Command precheck - step 1
    if (_IOC_TYPE(cmd) != DMAPROXY_IOC_MAGIC) {
        dev_err(dmaproxy_dev->dev, "[X] ioctl() -> magic does not match");
        return -ENOTTY;
    }

    // Command precheck - step 2
    if (_IOC_NR(cmd) > DMAPROXY_IOC_MAXNR) {
        dev_err(dmaproxy_dev->dev, "[X] ioctl() -> command number exceeds limit");
        return -ENOTTY;
    }

    // Lock mutex
    mutex_lock(&dmaproxy_dev->mutex);

    // Command decoding
    switch (cmd) {

        case DMAPROXY_IOC_DMA_MEM2HW:

            // Copy data from user
            dev_info(dmaproxy_dev->dev, "[ ] copy_from_user()");
            res = copy_from_user(&token, (void *)arg, sizeof token);
            if (res) {
                dev_err(dmaproxy_dev->dev, "[X] copy_from_user()");
                return -ENOMEM;
            }
            dev_info(dmaproxy_dev->dev, "[+] copy_from_user() -> token");

            dev_info(dmaproxy_dev->dev, "[i] DMA from memory to hardware");
            dev_info(dmaproxy_dev->dev, "[i] DMA -> memory address   = %p", token.memaddr);
            dev_info(dmaproxy_dev->dev, "[i] DMA -> memory offset    = %p", (void *)token.memoff);
            dev_info(dmaproxy_dev->dev, "[i] DMA -> hardware address = %p", token.hwaddr);
            dev_info(dmaproxy_dev->dev, "[i] DMA -> hardware offset  = %p", (void *)token.hwoff);
            dev_info(dmaproxy_dev->dev, "[i] DMA -> transfer size    = %d bytes", token.size);

            // Search if the requested memory region is allocated
            list_for_each_entry_safe(vm_list, backup, &dmaproxy_dev->head, list) {
                if ((vm_list->pid == current->pid) && (vm_list->addr_usr == token.memaddr)) {
                    // Memory check
                    if (vm_list->size < (token.memoff + token.size)) {
                        dev_err(dmaproxy_dev->dev, "[X] DMA -> requested transfer out of memory region");
                        retval = -EINVAL;
                        break;
                    }
                    // Check number of resources available in platform device (obtained from device tree fields reg, interrupts)
                    if (pdev->num_resources != 1) {
                        dev_err(&pdev->dev, "[X] DMA Slave -> wrong number of resources in device tree (make sure only one range is present in 'reg' field");
                        retval = -EINVAL;
                        break;
                    }
                    // Check if the resource is a memory map
                    if (pdev->resource[0].flags != IORESOURCE_MEM) {
                        dev_err(&pdev->dev, "[X] DMA Slave -> wrong type of resources in device tree (make sure no 'interrupts' field is present)");
                        retval = -EINVAL;
                        break;
                    }
                    // Print resource info
                    dev_info(&pdev->dev, "[i] Platform Device -> resource name  = %s", pdev->resource[0].name);
                    dev_info(&pdev->dev, "[i] Platform Device -> resource start = %lx", pdev->resource[0].start);
                    dev_info(&pdev->dev, "[i] Platform Device -> resource end   = %lx", pdev->resource[0].end);
                    dev_info(&pdev->dev, "[i] Platform Device -> resource flags = %lx", pdev->resource[0].flags);
                    // Get memory map base address and size
                    address = pdev->resource[0].start;
                    size = pdev->resource[0].end - pdev->resource[0].start + 1;
                    // Hardware check
                    if (size < (token.hwoff + token.size)) {
                        dev_err(dmaproxy_dev->dev, "[X] DMA Slave -> requested transfer out of hardware region");
                        retval = -EINVAL;
                        break;
                    }
                    // Address check
                    dev_info(dmaproxy_dev->dev, "[i] hardware memory map start = %x", address);
                    if ((void *)address != token.hwaddr) {
                        dev_err(dmaproxy_dev->dev, "[X] DMA Slave -> hardware address does not match");
                        retval = -EINVAL;
                        break;
                    }
                    // Perform transfer
                    retval = dmaproxy_dma_transfer(dmaproxy_dev, address + token.hwoff, vm_list->addr_phy + token.memoff, token.size);
                    break;
                }
            }

            break;

        case DMAPROXY_IOC_DMA_HW2MEM:

            // Copy data from user
            dev_info(dmaproxy_dev->dev, "[ ] copy_from_user()");
            res = copy_from_user(&token, (void *)arg, sizeof token);
            if (res) {
                dev_err(dmaproxy_dev->dev, "[X] copy_from_user()");
                return -ENOMEM;
            }
            dev_info(dmaproxy_dev->dev, "[+] copy_from_user() -> token");

            dev_info(dmaproxy_dev->dev, "[i] DMA from hardware to memory");
            dev_info(dmaproxy_dev->dev, "[i] DMA -> memory address   = %p", token.memaddr);
            dev_info(dmaproxy_dev->dev, "[i] DMA -> memory offset    = %p", (void *)token.memoff);
            dev_info(dmaproxy_dev->dev, "[i] DMA -> hardware address = %p", token.hwaddr);
            dev_info(dmaproxy_dev->dev, "[i] DMA -> hardware offset  = %p", (void *)token.hwoff);
            dev_info(dmaproxy_dev->dev, "[i] DMA -> transfer size    = %d bytes", token.size);

            // Search if the requested memory region is allocated
            list_for_each_entry_safe(vm_list, backup, &dmaproxy_dev->head, list) {
                if ((vm_list->pid == current->pid) && (vm_list->addr_usr == token.memaddr)) {
                    // Memory check
                    if (vm_list->size < (token.memoff + token.size)) {
                        dev_err(dmaproxy_dev->dev, "[X] DMA -> requested transfer out of memory region");
                        retval = -EINVAL;
                        break;
                    }
                    // Check number of resources available in platform device (obtained from device tree fields reg, interrupts)
                    if (pdev->num_resources != 1) {
                        dev_err(&pdev->dev, "[X] DMA Slave -> wrong number of resources in device tree (make sure only one range is present in 'reg' field");
                        retval = -EINVAL;
                        break;
                    }
                    // Check if the resource is a memory map
                    if (pdev->resource[0].flags != IORESOURCE_MEM) {
                        dev_err(&pdev->dev, "[X] DMA Slave -> wrong type of resources in device tree (make sure no 'interrupts' field is present)");
                        retval = -EINVAL;
                        break;
                    }
                    // Print resource info
                    dev_info(&pdev->dev, "[i] Platform Device -> resource name  = %s", pdev->resource[0].name);
                    dev_info(&pdev->dev, "[i] Platform Device -> resource start = %lx", pdev->resource[0].start);
                    dev_info(&pdev->dev, "[i] Platform Device -> resource end   = %lx", pdev->resource[0].end);
                    dev_info(&pdev->dev, "[i] Platform Device -> resource flags = %lx", pdev->resource[0].flags);
                    // Get memory map base address and size
                    address = pdev->resource[0].start;
                    size = pdev->resource[0].end - pdev->resource[0].start + 1;
                    // Hardware check
                    if (size < (token.hwoff + token.size)) {
                        dev_err(dmaproxy_dev->dev, "[X] DMA Slave -> requested transfer out of hardware region");
                        retval = -EINVAL;
                        break;
                    }
                    // Address check
                    dev_info(dmaproxy_dev->dev, "[i] hardware memory map start = %x", address);
                    if ((void *)address != token.hwaddr) {
                        dev_err(dmaproxy_dev->dev, "[X] DMA Slave -> hardware address does not match");
                        retval = -EINVAL;
                        break;
                    }
                    // Perform transfer
                    retval = dmaproxy_dma_transfer(dmaproxy_dev, vm_list->addr_phy + token.memoff, address + token.hwoff, token.size);
                    break;
                }
            }

            break;

        default:
            dev_err(dmaproxy_dev->dev, "[i] ioctl() -> command %x does not exist", cmd);
            retval = -ENOTTY;

    }

    // Release mutex
    mutex_unlock(&dmaproxy_dev->mutex);

    dev_info(dmaproxy_dev->dev, "[+] ioctl()");
    return retval;
}

// mmap close function (required to free allocated memory)
static void dmaproxy_mmap_close(struct vm_area_struct *vma) {
    struct dmaproxy_vm_list *token = vma->vm_private_data;
    struct dmaproxy_device *dmaproxy_dev = token->dmaproxy_dev;
    struct dma_device *dma_dev = dmaproxy_dev->chan->device;

    dev_info(dmaproxy_dev->dev, "[ ] munmap()");
    dev_info(dmaproxy_dev->dev, "[i] vma->vm_start = %p", (void *)vma->vm_start);
    dev_info(dmaproxy_dev->dev, "[i] vma->vm_end   = %p", (void *)vma->vm_end);
    dev_info(dmaproxy_dev->dev, "[i] vma size      = %ld bytes", vma->vm_end - vma->vm_start);

    dma_free_coherent(dma_dev->dev, token->size, token->addr_ker, token->addr_phy);

    // Critical section: remove region from dynamic list
    mutex_lock(&dmaproxy_dev->mutex);
    list_del(&token->list);
    mutex_unlock(&dmaproxy_dev->mutex);

    kfree(token);
    vma->vm_private_data = NULL;

    dev_info(dmaproxy_dev->dev, "[+] munmap()");
}

// mmap specific operations
static struct vm_operations_struct dmaproxy_mmap_ops = {
    .close = dmaproxy_mmap_close,
};

// File operation on char device: mmap
static int dmaproxy_mmap(struct file *fp, struct vm_area_struct *vma) {
    struct dmaproxy_device *dmaproxy_dev = fp->private_data;
    struct dma_device *dma_dev = dmaproxy_dev->chan->device;
    void *addr_vir = NULL;
    dma_addr_t addr_phy;
    struct dmaproxy_vm_list *token = NULL;
    int res;

    dev_info(dmaproxy_dev->dev, "[ ] mmap()");
    dev_info(dmaproxy_dev->dev, "[i] vma->vm_start = %p", (void *)vma->vm_start);
    dev_info(dmaproxy_dev->dev, "[i] vma->vm_end   = %p", (void *)vma->vm_end);
    dev_info(dmaproxy_dev->dev, "[i] vma size      = %ld bytes", vma->vm_end - vma->vm_start);

    // Allocate memory in kernel space
    dev_info(dma_dev->dev, "[ ] dma_zalloc_coherent()");
    addr_vir = dma_zalloc_coherent(dma_dev->dev, vma->vm_end - vma->vm_start, &addr_phy, GFP_KERNEL);
    if (IS_ERR(addr_vir)) {
        dev_err(dma_dev->dev, "[X] dma_zalloc_coherent()");
        return PTR_ERR(addr_vir);
    }
    dev_info(dma_dev->dev, "[+] dma_zalloc_coherent()");
    dev_info(dma_dev->dev, "[i] dma_zalloc_coherent() -> %p (virtual)", addr_vir);
    dev_info(dma_dev->dev, "[i] dma_zalloc_coherent() -> %p (physical)", (void *)addr_phy);
    dev_info(dma_dev->dev, "[i] dma_zalloc_coherent() -> %ld bytes", vma->vm_end - vma->vm_start);

    // Map kernel-space memory to DMA space
    dev_info(dma_dev->dev, "[ ] dma_common_mmap()");
    //~ res = dma_common_mmap(dma_dev->dev, vma, addr_vir, addr_phy, vma->vm_end - vma->vm_start);
    res = dma_mmap_coherent(dma_dev->dev, vma, addr_vir, addr_phy, vma->vm_end - vma->vm_start);
    if (res) {
        dev_err(dma_dev->dev, "[X] dma_common_mmap()");
        goto err_dma_mmap;
    }
    dev_info(dma_dev->dev, "[+] dma_common_mmap()");

    // Create data structure with allocated memory info
    dev_info(dmaproxy_dev->dev, "[ ] kzalloc()");
    token = kzalloc(sizeof *token, GFP_KERNEL);
    if (!token) {
        dev_err(dmaproxy_dev->dev, "[X] kzalloc()");
        res = -ENOMEM;
        goto err_kmalloc_token;
    }
    dev_info(dmaproxy_dev->dev, "[+] kzalloc() -> token");

    // Set values in data structure
    token->dmaproxy_dev = dmaproxy_dev;
    token->addr_usr = (void *)vma->vm_start;
    token->addr_ker = addr_vir;
    token->addr_phy = addr_phy;
    token->size = vma->vm_end - vma->vm_start;
    token->pid = current->pid;
    INIT_LIST_HEAD(&token->list);

    // Critical section: add new region to dynamic list
    mutex_lock(&dmaproxy_dev->mutex);
    list_add(&token->list, &dmaproxy_dev->head);
    mutex_unlock(&dmaproxy_dev->mutex);

    // Set virtual memory structure operations
    vma->vm_ops = &dmaproxy_mmap_ops;

    // Pass data to virtual memory structure (private data) to enable proper cleanup
    vma->vm_private_data = token;

    dev_info(dmaproxy_dev->dev, "[+] mmap()");
    return 0;

err_kmalloc_token:

err_dma_mmap:
    dma_free_coherent(dma_dev->dev, vma->vm_end - vma->vm_start, addr_vir, addr_phy);
    return res;
}

static struct file_operations dmaproxy_fops = {
    .owner          = THIS_MODULE,
    .open           = dmaproxy_open,
    .release        = dmaproxy_release,
    .read           = dmaproxy_read,
    .write          = dmaproxy_write,
    .unlocked_ioctl = dmaproxy_ioctl,
    .mmap           = dmaproxy_mmap,
};

// Creates a char device to act as user-space entry point
static int dmaproxy_cdev_create(struct platform_device *pdev) {
    int res;
    unsigned int i;

    // Retrieve custom device info using platform device (private data)
    struct dmaproxy_device *dmaproxy_dev = platform_get_drvdata(pdev);

    dev_info(&pdev->dev, "[ ] dmaproxy_cdev_create()");

    // Critical section: access dynamic minor number pool
    dev_info(&pdev->dev, "[ ] Dynamic minor number allocation");
    mutex_lock(&minor_mutex);
    for (i = 0; i < max_devices; i++) {
        if (minor[i]) {
            continue;
        }
        else {
            minor[i] = 1;
            break;
        }
    }
    mutex_unlock(&minor_mutex);
    if (i == max_devices) {
        dev_err(&pdev->dev, "[X] Dynamic minor number allocation failed, already using all (%d) devices", max_devices);
        return -EBUSY;
    }
    dev_info(&pdev->dev, "[+] Dynamic minor number allocation -> %d", i);

    // Set device structure parameters
    dmaproxy_dev->id = i;
    dmaproxy_dev->devt = MKDEV(MAJOR(devt), dmaproxy_dev->id);

    // Add char device to the system
    dev_info(&pdev->dev, "[ ] cdev_add()");
    cdev_init(&dmaproxy_dev->cdev, &dmaproxy_fops);
    res = cdev_add(&dmaproxy_dev->cdev, dmaproxy_dev->devt, 1);
    if (res) {
        dev_err(&pdev->dev, "[X] cdev_add() -> %d:%d", MAJOR(dmaproxy_dev->devt), MINOR(dmaproxy_dev->devt));
        goto err_cdev;
    }
    dev_info(&pdev->dev, "[+] cdev_add() -> %d:%d", MAJOR(dmaproxy_dev->devt), MINOR(dmaproxy_dev->devt));

    // Create char device
    dev_info(&pdev->dev, "[ ] device_create()");
    dmaproxy_dev->dev = device_create(dmaproxy_class, &pdev->dev, dmaproxy_dev->devt, dmaproxy_dev, "%s%d", DRIVER_NAME, i);
    if (IS_ERR(dmaproxy_dev->dev)) {
        dev_err(&pdev->dev, "[X] device_create() -> %d:%d", MAJOR(dmaproxy_dev->devt), MINOR(dmaproxy_dev->devt));
        res = PTR_ERR(dmaproxy_dev->dev);
        goto err_device;
    }
    dev_info(&pdev->dev, "[+] device_create() -> %d:%d", MAJOR(dmaproxy_dev->devt), MINOR(dmaproxy_dev->devt));
    dev_info(dmaproxy_dev->dev, "[i] device_create()");

    dev_info(&pdev->dev, "[+] dmaproxy_cdev_create()");
    return 0;

err_device:
    cdev_del(&dmaproxy_dev->cdev);

err_cdev:
    mutex_lock(&minor_mutex);
    minor[i] = 0;
    mutex_unlock(&minor_mutex);

    return res;
}

// Deletes a char device that acted as user-space entry point
static void dmaproxy_cdev_destroy(struct platform_device *pdev) {

    // Retrieve custom device info using platform device (private data)
    struct dmaproxy_device *dmaproxy_dev = platform_get_drvdata(pdev);

    dev_info(&pdev->dev, "[ ] dmaproxy_cdev_destroy()");

    dev_info(dmaproxy_dev->dev, "[i] dmaproxy_cdev_destroy()");

    // Destroy device
    device_destroy(dmaproxy_class, dmaproxy_dev->devt);
    cdev_del(&dmaproxy_dev->cdev);

    // Release minor number
    mutex_lock(&minor_mutex);
    minor[dmaproxy_dev->id] = 0;
    mutex_unlock(&minor_mutex);

    dev_info(&pdev->dev, "[+] dmaproxy_cdev_destroy()");
}

// Initializes char device support
static int dmaproxy_cdev_init(void) {
    int res;

    printk(KERN_INFO "%s [ ] dmaproxy_cdev_init()\n", DRIVER_NAME);

    // Dynamically allocate major number for char device
    printk(KERN_INFO "%s [ ] alloc_chrdev_region()\n", DRIVER_NAME);
    res = alloc_chrdev_region(&devt, 0, max_devices, DRIVER_NAME);
    if (res < 0) {
        printk(KERN_ERR "%s [X] alloc_chrdev_region()\n", DRIVER_NAME);
        return res;
    }
    printk(KERN_INFO "%s [+] alloc_chrdev_region() -> %d:%d-%d\n", DRIVER_NAME, MAJOR(devt), MINOR(devt), MINOR(devt) + max_devices - 1);

    // Create sysfs class
    printk(KERN_INFO "%s [ ] class_create()\n", DRIVER_NAME);
    dmaproxy_class = class_create(THIS_MODULE, DRIVER_NAME);
    if (IS_ERR(dmaproxy_class)) {
        printk(KERN_ERR "%s [X] class_create()\n", DRIVER_NAME);
        res = PTR_ERR(dmaproxy_class);
        goto err_class;
    }
    printk(KERN_INFO "%s [+] class_create() -> /sys/class/%s\n", DRIVER_NAME, DRIVER_NAME);

    printk(KERN_INFO "%s [+] dmaproxy_cdev_init()\n", DRIVER_NAME);
    return 0;

err_class:
    unregister_chrdev_region(devt, max_devices);
    return res;
}

// Cleans up char device support
static void dmaproxy_cdev_exit(void) {
    printk(KERN_INFO "%s [ ] dmaproxy_cdev_exit()\n", DRIVER_NAME);
    class_destroy(dmaproxy_class);
    unregister_chrdev_region(devt, max_devices);
    printk(KERN_INFO "%s [+] dmaproxy_cdev_exit()\n", DRIVER_NAME);
}


/* PLATFORM DRIVER */

// Actions to perform when the device is added (shows up in the device tree)
static int dmaproxy_probe(struct platform_device *pdev) {
    int res;
    struct dmaproxy_device *dmaproxy_dev = NULL;

    dev_info(&pdev->dev, "[ ] dmaproxy_probe()");

    // Allocate memory for custom device structure
    dev_info(&pdev->dev, "[ ] kzalloc()");
    dmaproxy_dev = kzalloc(sizeof *dmaproxy_dev, GFP_KERNEL);
    if (!dmaproxy_dev) {
        dev_err(&pdev->dev, "[X] kzalloc() -> dmaproxy_dev");
        res = -ENOMEM;
    }
    dev_info(&pdev->dev, "[+] kzalloc() -> dmaproxy_dev");

    // Initialize list head
    INIT_LIST_HEAD(&dmaproxy_dev->head);

    // Pass platform device pointer to custom device structure
    dmaproxy_dev->pdev = pdev;

    // Pass newly created custom device to platform device (as private data)
    platform_set_drvdata(pdev, dmaproxy_dev);

    // Initialize DMA subsystem
    res = dmaproxy_dma_init(pdev);
    if (res) {
        dev_err(&pdev->dev, "[X] dmaproxy_dma_init()");
        goto err_dma_init;
    }

    // Create char device
    res = dmaproxy_cdev_create(pdev);
    if (res) {
        dev_err(&pdev->dev, "[X] dmaproxy_cdev_create()");
        goto err_cdev_create;
    }

    // Initialize synchronization primitives
    mutex_init(&dmaproxy_dev->mutex);
    rwlock_init(&dmaproxy_dev->lock);
    init_completion(&dmaproxy_dev->cmp);

    dev_info(&pdev->dev, "[+] dmaproxy_probe()");
    return 0;

err_cdev_create:
    dmaproxy_dma_exit(pdev);

err_dma_init:
    kfree(dmaproxy_dev);
    return res;
}

// Actions to perform when the device is removed (dissappears from the device tree)
static int dmaproxy_remove(struct platform_device *pdev) {

    // Retrieve custom device info using platform device (private data)
    struct dmaproxy_device *dmaproxy_dev = platform_get_drvdata(pdev);

    dev_info(&pdev->dev, "[ ] dmaproxy_remove()");

    mutex_destroy(&dmaproxy_dev->mutex);
    dmaproxy_cdev_destroy(pdev);
    dmaproxy_dma_exit(pdev);
    kfree(dmaproxy_dev);

    dev_info(&pdev->dev, "[+] dmaproxy_remove()");
    return 0;
}

// Device tree (Open Firmware) matching table
static const struct of_device_id dmaproxy_of_match[] = {
    { .compatible = "cei.upm,proxy-cdma-1.00.a", },
    {}
};

// Driver structure
static struct platform_driver dmaproxy_driver = {
    .probe  = dmaproxy_probe,
    .remove = dmaproxy_remove,
    .driver = {
        .name           = DRIVER_NAME,
        .of_match_table = dmaproxy_of_match,
    },
};


/* KERNEL MODULE */

// Module initialization
static int __init dmaproxy_init(void) {
    int res;
    unsigned int i;

    printk(KERN_INFO "%s [ ] dmaproxy_init()\n", DRIVER_NAME);

    // Initialize char device(s)
    res = dmaproxy_cdev_init();
    if (res) {
        printk(KERN_ERR "%s [X] dmaproxy_cdev_init()\n", DRIVER_NAME);
        return res;
    }

    // Initialize dynamic minor number array
    printk(KERN_INFO "%s [ ] kzmalloc()\n", DRIVER_NAME);
    minor = kzalloc(max_devices * sizeof *minor, GFP_KERNEL);
    if (!minor) {
        printk(KERN_ERR "%s [X] kzmalloc() -> minor\n", DRIVER_NAME);
        res = -ENOMEM;
        goto err_kmalloc_minor;
    }
    printk(KERN_INFO "%s [+] kzmalloc() -> minor\n", DRIVER_NAME);

    // Critical section: initialize dynamic minor number pool
    mutex_lock(&minor_mutex);
    for (i = 0; i < max_devices; i++) {
        minor[i] = 0;
    }
    mutex_unlock(&minor_mutex);

    // Register platform driver
    printk(KERN_INFO "%s [ ] platform_driver_register()\n", DRIVER_NAME);
    res = platform_driver_register(&dmaproxy_driver);
    if (res) {
        printk(KERN_ERR "%s [X] platform_driver_register()\n", DRIVER_NAME);
        goto err_driver;
    }
    printk(KERN_INFO "%s [+] platform_driver_register()\n", DRIVER_NAME);

    printk(KERN_INFO "%s [+] dmaproxy_init()\n", DRIVER_NAME);
    return 0;

err_driver:
    kfree(minor);

err_kmalloc_minor:
    dmaproxy_cdev_exit();
    return res;
}

// Module cleanup
static void __exit dmaproxy_exit(void) {
    printk(KERN_INFO "%s [ ] dmaproxy_exit()\n", DRIVER_NAME);
    platform_driver_unregister(&dmaproxy_driver);
    dmaproxy_cdev_exit();
    kfree(minor);
    printk(KERN_INFO "%s [+] dmaproxy_exit()\n", DRIVER_NAME);
}

module_init(dmaproxy_init);
module_exit(dmaproxy_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Alfonso Rodriguez <alfonso.rodriguezm@upm.es>");
MODULE_DESCRIPTION("DMA proxy driver to enable zero-copy, burst-based transfers from user-space");
MODULE_VERSION("1.0");
