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

# PARTITION DISKS
echo "o \nY \nn \n1 \n \n_512M \nEF00 \nn \n3 \n \n+1G \n8200 \nn \n2 \n \n \n8300 \nw \nY" | gdisk $DISK

# FORMAT DISKS
mkfs.fat -F32 $DISK\1
mkswap $DISK\3

# ENCRYPT DISKS
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
mkfs.ext4 -O "^has_journal" /dev/mapper/crypt

# MOUNT
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
pacman -Syy

# INSTALL
time pacstrap /mnt base base-devel linux linux-firmware mkinitcpio vi vim pacman dhcpcd git net-tools terminator

# GET ENCRYPTED DISK UUID
UUID="$(blkid -s UUID -o value $DISK\2)"
export UUID

# CONFIGURE FSTAB
genfstab -U /mnt > /mnt/etc/fstab

# CHROOT
#arch-chroot /mnt

# SETUP BOOTLOADER
arch-chroot /mnt cd
arch-chroot /mnt bootctl install
arch-chroot /mnt mv /boot/loader/loader.conf /boot/loader/loader.conf.bac
arch-chroot /mnt echo -e "timeout 5\ndefault arch" > /boot/loader/loader.conf
arch-chroot /mnt echo -e "title ArchLinux\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\n"options rw cryptdevice=UUID=$UUID":crypt" root=/dev/mapper/crypt > /boot/loader/entries/arch.conf

# MKINITCPIO
arch-chroot /mnt #sed -i 's/oldstring/newstring/g' /etc/mkinitcpio.conf
arch-chroot /mnt cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bac
arch-chroot /mnt sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev block keyboard autodetect modconf resume shutdown filesystems encrypt fsck keymap)/g" /etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -p linux

# USER
arch-chroot /mnt echo -n "Enter username: "
arch-chroot /mnt read UNAME
arch-chroot /mnt useradd -m -G audio,video,wheel $UNAME
arch-chroot /mnt echo "Changing user password."
arch-chroot /mnt passwd $UNAME
arch-chroot /mnt echo "Changing root password."
arch-chroot /mnt passwd

# BACKUP SUDOERS
arch-chroot /mnt mv /etc/sudoers /etc/sudoers.bac

# ADD USER TO SUDOERS GROUP
arch-chroot /mnt sed "80i$UNAME ALL=(ALL) ALL" /etc/sudoers.bac  > /etc/sudoers

# EXIT CHROOT
#exit

# UNSET VARIABLES
unset DISK
unset UUID
unset UNAME

# STOP TIMER
DURATION=$SECONDS
echo "$(($DURATION / 60))m $(($DURATION % 60))s"
