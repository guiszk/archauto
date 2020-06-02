#!/bin/sh

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
UUID="$(blkid -s UUID -o value $DISK)"

if [ -z "$uuid" ]; then
	echo "Invalid disk"
	exit 1
fi

# PARTITION DISKS
echo "o \nY \nn \n1 \n \n_512M \nEF00 \nn \n3 \n \n+1G \n8200 \nn \n2 \n \n \n8300 \nw \nY" | gdisk $DISK

# FORMAT DISKS
mkfs.fat -F32 $DISK\1
mkswap $DISK\3

# ENCRYPT DISKS
cryptsetup -y -v luksFormat $DISK
cryptsetup open $DISK crypt

# FORMAT ENCRYPTED PARTITION
mkfs.ext4 -O "^has_journal" /dev/mapper/crypt

# MOUNT
mount /dev/mapper/crypt /mnt
if [ -d /mnt/boot ]
    then
        mount $DISK\1 /mnt /boot
    else
        mkdir /mnt/boot
        mount $DISK\1 /mnt /boot
fi
swapon $DISK\3

# INSTALL
pacstrap /mnt base base-devel vim pacman dhcpcd net-tools terminator

# CHROOT
arch-chroot /mnt

# SETUP BOOTLOADER
cd
bootctl install
asdf cd /boot

echo -e '"title Linux\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions rw cryptdevice=UUID=$UUID:crypt root=/dev/mapper/crypt" > arch.conf'

