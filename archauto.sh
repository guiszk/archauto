#!/bin/bash

if [ "$EUID" -ne 0 ]
  then
    echo "Run as root."
    exit 1
fi

if ! [ -d /sys/firmware/efi ]
  then
    echo "Boot with UEFI."
    exit 1
fi

if [ $# -ne 1 ]
  then
    echo "./archauto.sh <disk>"
    exit 1
fi

if ! (ping -c 1 archlinux.org || ping -c 1 github.com) &>/dev/null
    then
       echo "Connect to internet."
       exit 1
fi

DISK=$1
UUID="$(blkid -s UUID -o value $DISK\1)"
export DISK

if [ -z "$UUID" ]; then
	echo "Invalid disk"
	exit 1
fi

# START TIMER
SECONDS=0

# UNMOUNT DISKS
echo "Unmounting disks..."
umount /mnt/boot
umount /mnt

# PARTITION DISKS
echo "Partitioning disks..."
echo "o \nY \nn \n1 \n \n+512M \nEF00 \nn \n \n \n \n8300 \np \nw \nY" | gdisk $DISK
lsblk $DISK

# FORMAT DISKS
echo "Formatting disks..."
mkfs.fat -F32 $DISK\1

# ENCRYPT DISKS
echo "Encrypting disks..."
mkcrypt () {
    cryptsetup -y -v luksFormat $DISK\2
    if [ $? -ne  0 ]; then
        mkcrypt
    fi
}
opcrypt () {
    cryptsetup open $DISK\2 crypt
    if [ $? -ne  0 ]; then
        opcrypt
    fi
}
mkcrypt
opcrypt

# FORMAT ENCRYPTED PARTITION
echo "Formatting encrypted disk..."
mkfs.ext4 -O "^has_journal" /dev/mapper/crypt

# MOUNT
echo "Mounting disks..."
mount /dev/mapper/crypt /mnt
if [ -d /mnt/boot ]
    then
        mount $DISK\1 /mnt/boot
    else
        mkdir /mnt/boot
        mount $DISK\1 /mnt/boot
fi

# UPDATE REPOS
echo "Updating repos..."
pacman -Syy

# INSTALL
echo "Installing..."
time pacstrap /mnt base base-devel linux linux-firmware mkinitcpio wget gcc vi vim go pacman dhcpcd git zsh net-tools netctl wpa_supplicant dialog terminator

# GET ENCRYPTED DISK UUID
UUID="$(blkid -s UUID -o value $DISK\2)"
export UUID

# CONFIGURE FSTAB
echo "Configuring fstab..."
genfstab -U /mnt
genfstab -U /mnt > /mnt/etc/fstab

# ADD SCRIPT TO CHROOT
echo "Adding script to chroot..."
cp ./chrootauto.sh /mnt/usr/local/bin/chrootauto

# RUN SCRIPT
echo "Running script in chroot..."
arch-chroot /mnt chrootauto $DISK

# REMOVE SCRIPT FROM CHROOT
echo "Cleaning up..."
rm /mnt/usr/local/bin/chrootauto

# UNSET VARIABLES
echo "Unsetting variables..."
unset DISK
unset UUID
unset UNAME

# STOP TIMER
DURATION=$SECONDS
echo "$(($DURATION / 60))m $(($DURATION % 60))s"
