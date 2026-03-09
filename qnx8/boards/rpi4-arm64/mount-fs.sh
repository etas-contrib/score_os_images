#!/bin/sh

echo "---> Mounting file systems"

# On HW platforms: Mount first FAT partition to /boot
if [ -b /dev/sd0.ms.0 ]; then
    # GPT style partition
    echo "Mounting /boot partition /dev/sd0.ms.0"
    mount -tdos /dev/sd0.ms.0 /boot
elif [ -b /dev/sd0t12 ]; then
	# MBR style partition
    echo "Mounting /boot partition /dev/sd0t12"
    mount -tdos /dev/sd0t12 /boot
fi


# Mount S-CORE partition to /opt/score
# Mount probe list: sd0t... is MBR, sd0.qnx6.x is GPT
MOUNT_PROBE_LIST="sd0t177 sd0.qnx6.1"
MOUNT_POINT=/opt/score

if [ -f /boot/etc/settings/mount ]; then
	. /boot/etc/settings/mount
fi

for blk_device in $MOUNT_PROBE_LIST
do
	if [ -e /dev/$blk_device ]
	then
		BLK_DEVICE=$blk_device
		break
	fi
done
if [ -n "$BLK_DEVICE" ]
then
	echo "Mounting filesystem /dev/$BLK_DEVICE to $MOUNT_POINT"
	mount $MOUNTOPTIONS -t qnx6 /dev/$BLK_DEVICE $MOUNT_POINT
else
	echo "No root file system has been detected"
fi

