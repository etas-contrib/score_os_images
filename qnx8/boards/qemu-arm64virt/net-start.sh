#!/bin/sh

DEVICE_NAME_PREFIX=vtnet
IP_ADDRESS_vtnet0="192.168.120.20/24"
HOSTNAME=qemu-arm64virt

if [ -f /boot/etc/settings/network ]; then
	. /boot/etc/settings/network
fi

# Set hostname
setconf _CS_HOSTNAME ${HOSTNAME}

echo "---> Starting Ethernet driver"
io-sock -m fdt -d vtnet_mmio

waitfor /dev/socket 1
# Check if any network device is in the system
if [ ! -e /dev/socket ]; then
    # No - exit here
    echo "---> No Network device has been detected"
    exit 0;
fi


if [ "$IP_ADDRESS_vtnet0" = dhcp ]; then
	dhcpcd -bq -f /boot/etc/dhcpcd/dhcpcd.conf -c /boot/etc/dhcpcd/dhcpcd-run-hooks
	# If dhcpcd not run as root, need to give it read/write access to /dev/bpf
	setfacl -m user:38:rw  /dev/bpf
else
    # Setup static IP addresses for all defined devices
	# enumerate devices from 0..3
	for i in 0 1 2 3
	do
		# Try finding env var "IP_ADDRESS_<device>" defined in network config file. 
		# If found, set up corresponding device.
		# Build device name out of prefix + i
		DEVICE_NAME=${DEVICE_NAME_PREFIX}$i
		# Build env var name out of string "NET_IP_ADDRESS_" + DEVICE_NAME
		IP_ADDRESS_TEMPLATE="IP_ADDRESS_$DEVICE_NAME"
		# Evaluate env var name to get IP address for device
		IP_ADDRESS=$(eval echo \$$IP_ADDRESS_TEMPLATE)
		if [ -n "$IP_ADDRESS" ]; then
			echo "---> Setting up $DEVICE_NAME with ip address $IP_ADDRESS"
			if_up -r 10 -p $DEVICE_NAME
			ifconfig $DEVICE_NAME $IP_ADDRESS up
		fi
	done
fi

sysctl -w net.inet.icmp.bmcastecho=1 > /dev/null
sysctl -w qnx.sec.droproot=33:33 > /dev/null

exit 0
