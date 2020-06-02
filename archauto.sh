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
arch-chroot /mnt

# SETUP BOOTLOADER
cd
bootctl install
mv /boot/loader/loader.conf /boot/loader/loader.conf.bac
echo -e "timeout 5\ndefault arch" > /boot/loader/loader.conf
echo -e "title ArchLinux\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\n"options rw cryptdevice=UUID=$UUID":crypt" root=/dev/mapper/crypt > /boot/loader/entries/arch.conf

# MKINITCPIO
#sed -i 's/oldstring/newstring/g' /etc/mkinitcpio.conf
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bac
sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev block keyboard autodetect modconf resume shutdown filesystems encrypt fsck keymap)/g" /etc/mkinitcpio.conf
mkinitcpio -p linux

# USER
echo -n "Enter username: "
read UNAME
useradd -m -G audio,video,wheel $UNAME
echo "Changing user password."
passwd $UNAME
echo "Changing root password."
passwd

# BACKUP SUDOERS
mv /etc/sudoers /etc/sudoers.bac

# ADD USER TO SUDOERS GROUP
sed "80i$UNAME ALL=(ALL) ALL" /etc/sudoers.bac  > /etc/sudoers

