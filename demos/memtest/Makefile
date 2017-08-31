CROSS_COMPILE = /opt/Xilinx/SDK/2017.1/gnu/arm/lin/bin/arm-xilinx-linux-gnueabi-
CC = $(CROSS_COMPILE)gcc

CFLAGS += -Wall -O3
LDFLAGS += -static

all:
	$(CC) $(CFLAGS) $(LDFLAGS) -o memtest.elf *.c

clean:
	rm -rf memtest.elf
