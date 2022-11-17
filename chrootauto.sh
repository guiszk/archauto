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
echo "Installing bootctl..."
bootctl install
echo "Backing up loader.conf..."
cp /boot/loader/loader.conf /boot/loader/loader.conf.bac
echo "Generating loader.conf file..."
echo -e "timeout 5\ndefault arch" > /boot/loader/loader.conf
echo "Creating arch.conf file..."
touch /boot/loader/entries/arch.conf
echo "Generating arch.conf file..."
echo -e "title ArchLinux\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\n"options rw cryptdevice=UUID=$UUID":crypt" root=/dev/mapper/crypt > /boot/loader/entries/arch.conf

# MKINITCPIO
#sed -i 's/oldstring/newstring/g' /etc/mkinitcpio.conf
echo "Backing up mkinitcpio..."
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bac
echo "Generating mkinitcpio..."
sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev block keyboard autodetect modconf shutdown filesystems encrypt fsck keymap)/g" /etc/mkinitcpio.conf
echo "Running mkinitcpio..."
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
echo "Creating user..."
useradd -m -G audio,video,wheel $UNAME
echo "Changing user password."
pwcheck $UNAME
echo "Changing root password."
pwcheck

# GIT
echo -n "Enter git name: "
read GITNAME
echo -n "Enter git email: "
read GITMAIL
echo "Configuring git..."
git config --global user.name "$GITNAME"
git config --global user.email "$GITMAIL"

# TIMEZONE
echo "Configuring timezone..."
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# BACKUP SUDOERS
echo "Backing up sudoers..."
mv /etc/sudoers /etc/sudoers.bac

# ADD USER TO SUDOERS GROUP
echo "Editing sudoers..."
sed "80i$UNAME ALL=(ALL) ALL" /etc/sudoers.bac  > /etc/sudoers

# UNSET VARIABLES
unset DISK
unset UUID
unset UNAME
unset GITNAME
unset GITMAIL

# EXIT CHROOT
echo "Exiting chroot..."
exit
