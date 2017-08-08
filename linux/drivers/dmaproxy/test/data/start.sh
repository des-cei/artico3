#!/bin/sh

# Load bitstream
cat dma.bit > /dev/xdevcfg

# Create device tree overlay folder
mkdir /sys/kernel/config/device-tree/overlays/dma

# Export device tree overlay
cat dma.dtbo > /sys/kernel/config/device-tree/overlays/dma/dtbo

#~ # Remove device tree overlay folder
#~ rmdir /sys/kernel/config/device-tree/overlays/dma
