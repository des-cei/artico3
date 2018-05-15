#
# ARTICo3 Runtime Library
#
# Author   : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date     : May 2018
#
# Notes:
#     - This Makefile requires the following environment variables to
#       be previously set (by the user, or the ARTICo3 toolchain):
#       CROSS_COMPILE
#
#       CROSS_COMPILE = /opt/Xilinx/SDK/<version>/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin/arm-linux-gnueabihf-
#       CROSS_COMPILE = /opt/Xilinx/SDK/<version>/gnu/aarch64/lin/aarch64-linux/bin/aarch64-linux-gnu-
#

CC = $(CROSS_COMPILE)gcc
AR = $(CROSS_COMPILE)ar

CFLAGS = -Wall -Wextra -O3 -fpic -I../../linux/drivers/dmaproxy
LDFLAGS = -Wl,-R,. -shared
LDLIBS = -lm -lpthread

OBJS = artico3_rcfg.o artico3_hw.o artico3.o

ZYNQ_OBJS = $(OBJS:%=aarch32/_build/Release/%)
ZYNQMP_OBJS = $(OBJS:%=aarch64/_build/Release/%)

ZYNQ_OBJS_DBG = $(OBJS:%=aarch32/_build/Debug/%)
ZYNQMP_OBJS_DBG = $(OBJS:%=aarch64/_build/Debug/%)

MKDIRP = mkdir -p
CPF = cp -f

.PHONY: zynq
zynq: $(ZYNQ_OBJS)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o aarch32/libartico3.so
	$(AR) rcs aarch32/libartico3.a $^
	$(MKDIRP) aarch32/include
	$(CPF) artico3.h aarch32/include

.PHONY: zynqmp
zynqmp: $(ZYNQMP_OBJS)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o aarch64/libartico3.so
	$(AR) rcs aarch64/libartico3.a $^
	$(MKDIRP) aarch64/include
	$(CPF) artico3.h aarch64/include

.PHONY: zynq_dbg
zynq_dbg: $(ZYNQ_OBJS_DBG)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o aarch32/libartico3dbg.so
	$(AR) rcs aarch32/libartico3dbg.a $^
	$(MKDIRP) aarch32/include
	$(CPF) artico3.h aarch32/include

.PHONY: zynqmp_dbg
zynqmp_dbg: $(ZYNQMP_OBJS_DBG)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o aarch64/libartico3dbg.so
	$(AR) rcs aarch64/libartico3dbg.a $^
	$(MKDIRP) aarch64/include
	$(CPF) artico3.h aarch64/include

.PHONY: clean
clean:
	rm -rf aarch32 aarch64

aarch32/_build/Release/%.o: %.c
	$(MKDIRP) $(@D)
	$(CC) $(CFLAGS) -c $< -o $@

aarch64/_build/Release/%.o: %.c
	$(MKDIRP) $(@D)
	$(CC) -DZYNQMP $(CFLAGS) -c $< -o $@

aarch32/_build/Debug/%.o: %.c
	$(MKDIRP) $(@D)
	$(CC) -DA3_DEBUG $(CFLAGS) -c $< -o $@

aarch64/_build/Debug/%.o: %.c
	$(MKDIRP) $(@D)
	$(CC) -DA3_DEBUG -DZYNQMP $(CFLAGS) -c $< -o $@
