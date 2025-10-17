#!/bin/sh
VOLUME_GROUP_NAME=VG0-LV0
# get boot and efi partitions
boot=$(mount | grep /target/boot | awk '{print $1}')
efi=$(mount | grep /target/boot/efi | awk '{print $1}')

umount /target/boot/efi/
umount /target/boot/
umount /target/
mount /dev/mapper/$VOLUME_GROUP_NAME /mnt
cd /mnt

# for snapper support
mv @rootfs/ @

# create subvolumes
btrfs subvolume create @snapshots
btrfs subvolume create @home
btrfs subvolume create @tmp
btrfs subvolume create @var
# OPTIONAL
btrfs subvolume create @opt

# mount root directory
mount -o ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@ /dev/mapper/$VOLUME_GROUP_NAME /target

# create mount points
cd /target
mkdir .snapshots
mkdir home
mkdir tmp
mkdir var
# OPTIONAL
mkdir opt

# mount subvolumes
mount -o ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@snapshots /dev/mapper/$VOLUME_GROUP_NAME /target/.snapshots
mount -o ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@home /dev/mapper/$VOLUME_GROUP_NAME /target/home
mount -o ssd,noatime,nodatacow,space_cache=v2,commit=120,discard=async,subvol=@tmp /dev/mapper/$VOLUME_GROUP_NAME /target/tmp
mount -o ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@var /dev/mapper/$VOLUME_GROUP_NAME /target/var
# OPTIONAL /opt
mount -o ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@opt /dev/mapper/$VOLUME_GROUP_NAME /target/opt
# mount boot and efi partitions
mount $boot boot
mount $efi boot/efi

# remove original fstab entry for @
sed '/$VOLUME_GROUP_NAME/d' etc/fstab

echo "/dev/mapper/$VOLUME_GROUP_NAME /             btrfs  ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@            0    1" >> etc/fstab
echo "/dev/mapper/$VOLUME_GROUP_NAME /.snapshots   btrfs  ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@snapshots    0    2" >> etc/fstab
echo "/dev/mapper/$VOLUME_GROUP_NAME /home         btrfs  ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@home        0    2" >> etc/fstab
echo "/dev/mapper/$VOLUME_GROUP_NAME /tmp          btrfs  ssd,noatime,nodatacow,space_cache=v2,commit=120,discard=async,subvol=@tmp          0    2" >> etc/fstab
echo "/dev/mapper/$VOLUME_GROUP_NAME /var          btrfs  ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@var          0    2" >> etc/fstab
# OPTIONAL /opt
echo "/dev/mapper/$VOLUME_GROUP_NAME /opt          btrfs  ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@opt          0    2" >> etc/fstab

cd /
umount /mnt
exit
