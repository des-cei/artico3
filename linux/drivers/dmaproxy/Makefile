#
# DMA proxy kernel module
# 
# Author   : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date     : July 2017
# 
# Features :
#     - Platform driver + character device
#     - Targets memcpy operations (requires src and dst addresses)
#     - Relies on Device Tree (Open Firmware) to get DMA engine info
#     - mmap()  : provides zero-copy memory allocation (direct access
#                 from user-space virtual memory to physical memory)
#     - ioctl() : enables command passing between user-space and
#                 character device (e.g. to start DMA transfers)
# 
# Notes:
#     - This Makefile requires the following environment variables to
#       be previously set (by the user, or the ARTICo3 toolchain):
#		ARCH, CROSS_COMPILE, KDIR
#

obj-m += mdmaproxy.o
mdmaproxy-objs := dmaproxy.o

all:
	make -C $(KDIR) M=$(PWD) modules
	
clean:
	make -C $(KDIR) M=$(PWD) clean
