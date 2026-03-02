#!/bin/sh

# Start file system event manager.
# Required for applications utilizing inotify_...() APIs.
# Must start before any block device driver.
if [ -x /sbin/fsevmgr ]; then
    echo "---> Starting fsevmgr"
    /sbin/fsevmgr
    waitfor /dev/fsnotify
fi

# Start virtio block device driver
BLK_DEVICE_RAW=sd0

echo "---> Starting SDMMC block driver"
devb-sdmmc-bcm2711 cam user=20:20 mem name=below1G sdio addr=0xfe340000,irq=158 disk name=sd blk ramdisk=20m

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
    # Create /run/lola_discovery for lola
    mkdir /run/lola_discovery
else
    echo "ERROR: No /dev/ram0 detected. /run file system is not available."
fi
