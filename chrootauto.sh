#!/bin/bash

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

# GET ENCRYPTED DISK UUID
UUID="$(blkid -s UUID -o value $DISK\2)"
export UUID

# SETUP BOOTLOADER
cd
bootctl install
cp /boot/loader/loader.conf /boot/loader/loader.conf.bac
echo -e "timeout 5\ndefault arch" > /boot/loader/loader.conf
touch /boot/loader/entries/arch.conf
echo -e "title ArchLinux\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\n"options rw cryptdevice=UUID=$UUID":crypt" root=/dev/mapper/crypt > /boot/loader/entries/arch.conf

# MKINITCPIO
#sed -i 's/oldstring/newstring/g' /etc/mkinitcpio.conf
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bac
sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev block keyboard autodetect modconf resume shutdown filesystems encrypt fsck keymap)/g" /etc/mkinitcpio.conf
mkinitcpio -p linux

# USER
pwcheck () {
    passwd $1
    if [ $? -eq 10 ]; then
        pwcheck $1
    fi
}
echo -n "Enter username: "
read UNAME
useradd -m -G audio,video,wheel $UNAME
echo "Changing user password."
pwcheck $UNAME
#passwd $UNAME
echo "Changing root password."
pwcheck
#passwd

# BACKUP SUDOERS
mv /etc/sudoers /etc/sudoers.bac

# ADD USER TO SUDOERS GROUP
sed "80i$UNAME ALL=(ALL) ALL" /etc/sudoers.bac  > /etc/sudoers

# EXIT CHROOT
exit
