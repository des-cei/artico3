#
# ARTICo³ kernel module
#
# Author   : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date     : April 2019
#
# Features :
#     - Platform driver + character device
#     - mmap()  : provides 1) zero-copy memory allocation (direct access
#                 from user-space virtual memory to physical memory) for
#                 data transfers using a DMA engine, and 2) direct access
#                 to ARTICo³ configuration registers in the FPGA
#     - ioctl() : enables command passing between user-space and
#                 character device (e.g., to start DMA transfers)
#     - poll()  : enables passive (i.e., sleep-based) waiting capabilities
#                 for 1) DMA interrupts, and 2) ARTICo³ interrupts
#     - [DMA] Targets memcpy operations (requires src and dst addresses)
#     - [DMA] Relies on Device Tree (Open Firmware) to get DMA engine info
#
# Notes:
#     - This Makefile requires the following environment variables to
#       be previously set (by the user, or the ARTICo³ toolchain):
#       ARCH, CROSS_COMPILE, KDIR
#

obj-m += martico3.o
martico3-objs := artico3.o

module:
	make -C $(KDIR) M=$(PWD) modules

install: module
	cp martico3.ko $(PREFIX)

clean:
	make -C $(KDIR) M=$(PWD) clean
