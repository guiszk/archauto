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

DISK=$1
UUID="$(blkid -s UUID -o value $DISK\1)"
export DISK

if [ -z "$UUID" ]; then
	echo "Invalid disk"
	exit 1
fi

# START TIMER
SECONDS=0

msg () {
    echo $1; read
}

# UNMOUNT DISKS
msg "Unmounting disks..."
umount /mnt/boot
umount /mnt

# PARTITION DISKS
msg "Partitioning disks..."
echo "o \nY \nn \n1 \n \n_512M \nEF00 \nn \n3 \n \n+1G \n8200 \nn \n2 \n \n \n8300 \nw \nY" | gdisk $DISK
lsblk $DISK

# FORMAT DISKS
msg "Formatting disks..."
mkfs.fat -F32 $DISK\1
mkswap $DISK\3

# ENCRYPT DISKS
msg "Encrypting disks..."
mkcrypt () {
    cryptsetup -y -v luksFormat $DISK\2
    if [ $? -eq  2 ]; then
        mkcrypt
    fi
}
opcrypt () {
    cryptsetup open $DISK\2 crypt
    if [ $? -eq  2 ]; then
        opcrypt
    fi
}
mkcrypt
opcrypt

# FORMAT ENCRYPTED PARTITION
msg "Formatting encrypted disk..."
mkfs.ext4 -O "^has_journal" /dev/mapper/crypt

# MOUNT
msg "Mounting disks..."
mount /dev/mapper/crypt /mnt
if [ -d /mnt/boot ]
    then
        mount $DISK\1 /mnt/boot
    else
        mkdir /mnt/boot
        mount $DISK\1 /mnt/boot
fi
swapon $DISK\3

# UPDATE REPOS
msg "Updating repos..."
pacman -Syy

# INSTALL
msg "Installing..."
time pacstrap /mnt base base-devel linux linux-firmware mkinitcpio vi vim pacman dhcpcd git net-tools terminator

# GET ENCRYPTED DISK UUID
UUID="$(blkid -s UUID -o value $DISK\2)"
export UUID

# CONFIGURE FSTAB
msg "Configuring fstab..."
genfstab -U /mnt
genfstab -U /mnt > /mnt/etc/fstab

# ADD SCRIPT TO CHROOT
msg "Adding script to chroot..."
cp ./chrootauto.sh /mnt/usr/local/bin/chrootauto

# RUN SCRIPT
msg "Running script in chroot..."
arch-chroot /mnt chrootauto $DISK

# UNSET VARIABLES
msg "Unsetting variables..."
unset DISK
unset UUID
unset UNAME

# STOP TIMER
DURATION=$SECONDS
echo "$(($DURATION / 60))m $(($DURATION % 60))s"
