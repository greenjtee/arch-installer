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

partition_list=$(ls -1 ${device}* |awk '{ print $1 " " $1 }')
root_partition=$(dialog --stdout --menu "Select root partition" 0 0 0 ${partition_list}) || exit 1
swap_partition=$(dialog --stdout --menu "Select swap partition" 0 0 0 ${partition_list}) || exit 1
efi_partition=$(dialog --stdout --menu "Select EFI partition" 0 0 0 ${partition_list}) || exit 1

mkfs.ext4 ${root_partition} || exit 1
mkswap ${swap_partition} || exit 1
mkfs.fat -F 32 ${efi_partition} || exit 1

mount ${root_partition} /mnt || exit 1
mount --mkdir ${efi_partition} /mnt/boot || exit 1
swapon ${swap_partition} || exit 1

clear

### Install and configure the basic system ###
pacstrap -K /mnt base linux-zen linux-firmware intel-ucode man-db man-pages texinfo || exit 1

genfstab -U /mnt >> /mnt/etc/fstab || exit 1

arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime || exit 1
arch-chroot /mnt hwclock --systohc || exit 1

echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf || exit 1
arch-chroot /mnt locale-gen || exit 1

echo "${hostname}" > /mnt/etc/hostname || exit 1

arch-chroot /mnt mkinitcpio -P || exit 1

arch-chroot /mnt passwd || exit 1

arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || exit 1
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || exit 1
arch-chroot /mnt useradd ${user} || exit 1
arch-chroot /mnt passwd ${user} || exit 1

umount -R /mnt || exit 1

reboot
