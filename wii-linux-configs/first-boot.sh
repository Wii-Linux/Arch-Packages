#!/bin/sh
export TERM=linux
exec > /dev/tty0 2> /dev/tty0
clear
echo "Wii Linux First Boot Script"
sleep 1

bye() {
	echo "Disabling service"
	rm -f /etc/systemd/system/sysinit.target.wants/wii-linux-first-boot.service

	echo "Bye!  Rebooting in 5 seconds..."
	sleep 5
	reboot
}


echo "Detecting the root filesystem..."
ROOT_DEVICE=$(findmnt -no SOURCE /)
if [ "$ROOT_DEVICE" = "" ]; then
	echo "Error: Unable to detect the root filesystem"
	exit 1
fi

DISK=$(lsblk -no PKNAME "$ROOT_DEVICE") # Parent disk (e.g. sda)
PARTITION=$(basename "$ROOT_DEVICE")

DISK="/dev/$DISK"
PARTITION="/dev/$PARTITION"

echo "Root filesystem detected on: $PARTITION (Disk: $DISK)"

echo "Checking if the root partition is the last on the disk..."
LAST_PART_NUM=$(fdisk -l "$DISK" | grep "^$DISK" | tail -n 1 | awk '{print $1}' | grep -o '[0-9]*$')
ROOT_PART_NUM=$(echo "$PARTITION" | grep -o '[0-9]*$')

if [ "$ROOT_PART_NUM" != "$LAST_PART_NUM" ]; then
	echo "Root partition is not the last partition on the disk"
	bye
fi

echo "Checking for free space at the end of the disk..."
DISK_SIZE=$(fdisk -l "$DISK" | grep "Disk $DISK:" | awk '{print $5}')
PART_END=$(fdisk -l "$DISK" | grep "^$PARTITION" | awk '{print $3}')

PART_END_BYTES=$((PART_END * 512))
if [ "$PART_END_BYTES" -gt "$DISK_SIZE" ]; then
	echo "No free space to expand the partition"
	bye
fi

# Resize the partition
echo "Resizing the partition using fdisk..."
(
	echo e    # Resize
	echo "$ROOT_PART_NUM"
	echo ""   # Default (max)
	echo "w"  # Write to disk
) | fdisk "$DISK"

echo "Resizing the filesystem..."
FS_TYPE=$(lsblk -no FSTYPE "$PARTITION")

if [ "$FS_TYPE" = "ext4" ] || [ "$FS_TYPE" = "ext3" ] || [ "$FS_TYPE" = "ext2" ]; then
	resize2fs "$PARTITION"
else
	echo "Unsupported filesystem type: $FS_TYPE, not resizing"
fi

echo "Resize completed"
bye

