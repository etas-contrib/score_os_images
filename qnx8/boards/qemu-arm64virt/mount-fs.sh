#!/bin/sh

echo "---> Mounting file systems"

# Mount probe list: hd0... is MBR, hd0.qnx6.x is GPT
MOUNT_PROBE_LIST="hd0t177 hd0.qnx6.0 hd0.qnx6.1"

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
	echo "Mounting root overlay filesystem /dev/$BLK_DEVICE"
	mount $MOUNTOPTIONS -t qnx6 /dev/$BLK_DEVICE /
else
	echo "No root file system has been detected"
fi

