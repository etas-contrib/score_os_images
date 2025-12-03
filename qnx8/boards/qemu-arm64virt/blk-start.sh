#!/bin/sh

# Start virtio block device driver
BLK_DEVICE_RAW=hd0

echo "---> Starting block driver"
# virtio-blk values from QEMU virt fdt...
devb-virtio cam user=20:20 blk cache=64M,auto=partition,vnode=2000,ncache=2000,commit=low virtio smem=0xa003e00,irq=79 blk ramdisk=20m

waitfor /dev/$BLK_DEVICE_RAW 3
if [ ! -e /dev/$BLK_DEVICE_RAW ]
then
    echo "ERROR: No block device detected"
fi


# Start /run filesystem
if [ -e /dev/ram0 ]
then
    echo "---> Preparing /run using /dev/ram0"
    # Preparing for many small files: 
    # 4096 inodes, 512 bytes per block, no reserved blocks
    mkqnx6fs -i 4096 -b 512 -r 0 -q /dev/ram0
    mount -t qnx6 /dev/ram0 /run
else
    echo "ERROR: No /dev/ram0 detected. /run file system is not available."
fi
