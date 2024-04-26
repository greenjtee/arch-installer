#!/bin/bash

set -uo pipefail

pacman -Sy dialog

### Get infomation from user ###
hostname=$(dialog --stdout --inputbox "Enter hostname" 0 0) || exit 1
clear
: ${hostname:?"hostname cannot be empty"}

user=$(dialog --stdout --inputbox "Enter admin username" 0 0) || exit 1
clear
: ${user:?"user cannot be empty"}

password=$(dialog --stdout --passwordbox "Enter admin password" 0 0) || exit 1
clear
: ${password:?"password cannot be empty"}
password2=$(dialog --stdout --passwordbox "Enter admin password again" 0 0) || exit 1
clear
[[ "$password" == "$password2" ]] || ( echo "Passwords did not match"; exit 1; )

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Select installation disk" 0 0 0 ${devicelist}) || exit 1
clear

### Set up logging ###
exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")

timedatectl set-ntp true

### Setup the disk and partitions ###
fdisk "${device}"

partition_list=$(ls ${device}*)
root_partition=$(dialog --stdout --menu "Select root partition" 0 0 0 ${partition_list}) || exit 1
swap_partition=$(dialog --stdout --menu "Select swap partition" 0 0 0 ${swap_partition}) || exit 1
efi_partition=$(dialog --stdout --menu "Select EFI partition" 0 0 0 ${efi_partition}) || exit 1

mkfs.ext4 ${root_partition}
mkswap ${swap_partition}
kfs.fat -F 32 ${efi_partition}

mount ${root_partition} /mnt
mount --mkdir ${efi_partition} /mnt/boot
swapon ${swap_partition}

clear

### Install and configure the basic system ###
pacstrap -K /mnt base linux-zen linux-firmware intel-ucode man-db man-pages texinfo

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
arch-chroot /mnt hwclock --systohc

echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
arch-chroot /mnt locale-gen

echo "${hostname}" > /mnt/etc/hostname

arch-chroot /mnt mkinitcpio -P

arch-chroot /mnt passwd

arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
arch-chroot /mnt useradd ${user}
arch-chroot /mnt passwd ${user}

umount -R /mnt

reboot
