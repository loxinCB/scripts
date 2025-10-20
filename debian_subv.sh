#!/bin/sh

VOLUME_GROUP_NAME=$(mount | grep /@rootfs | awk '{print $1}')
echo root mount is $VOLUME_GROUP_NAME
# get boot and efi partitions
boot=$(mount | grep /target/boot | awk '{print $1}')
efi=$(mount | grep /target/boot/efi | awk '{print $1}')

if ! umount /target/boot/efi/; then
    echo "Error: failed to unmount /target/boot/efi/"
    exit 1
fi
echo successfully unmounted /target/boot/efi/
sleep 1

if ! umount /target/boot/; then
    echo "Error: failed to unmount /target/boot/"
    exit 1
fi
echo successfully unmounted /target/boot/
sleep 1

if ! umount /target/; then
    echo "Error: failed to unmount /target/"
    exit 1
fi
echo successfully unmounted /target/
sleep 1

if ! mount $VOLUME_GROUP_NAME /mnt; then
    echo "Error: failed to mount $VOLUME_GROUP_NAME"
    exit 1
fi
echo successfully mounted $VOLUME_GROUP_NAME
sleep 1

cd /mnt

# for snapper support
if mv @rootfs/ @; then
    echo "root subvol successfully moved to @"
    sleep 1
else
    echo echo "root subvol moved failed"
    exit 1
fi

# create subvolumes
subs=$(
    @snapshots
    @home
    @tmp
    @var
    @opt
)
for sub in "${subs[@]}"
do 
    echo "creating subvolume $sub..."
    if ! btrfs subvolume create "$sub"; then
        echo "Error: failed to create subvolume $sub"
        exit 1
    fi
done
echo "subvolumes created"
sleep 1

# mount root directory
if mount -o ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@ $VOLUME_GROUP_NAME /target; then
    echo "successfully mounted @"
    sleep 1
else
    echo "failed to mount @"
    exit 1
fi

cd /target
# create mount points
mountpoints=$(
    .snapshots
    home
    tmp
    var
    opt
)
for mountpoint in "${mountpoints[@]}"
do
    echo "creating mountpoint $mountpoint..."
    if ! mkdir -p "$mountpoint"; then
        echo "Error: failed to create mountpoint $mountpoint"
        exit 1
    fi
done
echo "mountpoints created"
sleep 1

# mount subvolumes
mountoptions=$(
    ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@snapshots $VOLUME_GROUP_NAME /target/.snapshots
    ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@home $VOLUME_GROUP_NAME /target/home
    ssd,noatime,nodatacow,space_cache=v2,commit=120,discard=async,subvol=@tmp $VOLUME_GROUP_NAME /target/tmp
    ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@var $VOLUME_GROUP_NAME /target/var
    ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@opt $VOLUME_GROUP_NAME /target/opt
)
for mountoption in "${mountoptions[@]}"
do
    echo "mounting with $mountoption..."
    if ! mount -o "$mountoption"; then
        echo "Error: failed to mount with $mountoption"
        exit 1
    fi
done
echo mounting subvolumes completed
sleep 1

# mount boot and efi partitions
if ! mount $boot boot; then
        echo "Error: failed to mount $boot"
        exit 1
fi
echo successfully mounted "$boot"
sleep 1
if ! mount $efi boot/efi; then
        echo "Error: failed to mount $efi"
        exit 1
fi
echo successfully mounted "$efi"
sleep 1

# remove original fstab entry for @
sed '/$VOLUME_GROUP_NAME/d' etc/fstab >> /dev/null

# writing /target/etc/fstab
fstab_entries=$(
    "$VOLUME_GROUP_NAME /             btrfs  ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@           0    1"
    "$VOLUME_GROUP_NAME /.snapshots   btrfs  ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@snapshots  0    2"
    "$VOLUME_GROUP_NAME /home         btrfs  ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@home       0    2"
    "$VOLUME_GROUP_NAME /tmp          btrfs  ssd,noatime,nodatacow,space_cache=v2,commit=120,discard=async,subvol=@tmp              0    2"
    "$VOLUME_GROUP_NAME /var          btrfs  ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@var        0    2"
    "$VOLUME_GROUP_NAME /opt          btrfs  ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@opt        0    2"
)
for fstab_entry in "${fstab_entries[@]}"
do
    echo writing "$fstab_entry" into etc/fstab...
    if ! echo "$fstab_entry" >> etc/fstab; then
        echo "Error: failed to write into etc/fstab"
        exit 1
    fi
done
echo successfully added entries to etc/fstab
sleep 1

cd /
umount /mnt
echo successfully unmounted /mnt
sleep 1
exit
