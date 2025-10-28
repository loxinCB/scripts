#!/bin/sh

VOLUME_GROUP_NAME=$(mount | grep /@rootfs | awk '{print $1}')
echo root mount is $VOLUME_GROUP_NAME
# get boot and efi partitions
boot=$(mount | grep '/target/boot ' | awk '{print $1}')
efi=$(mount | grep '/target/boot/efi' | awk '{print $1}')

echo "Unmounting /target/boot/efi/..."
if umount /target/boot/efi/; then
    echo "✓ Successfully unmounted /target/boot/efi/"
    sleep 1
else
    echo "✗ Error: Failed to unmount /target/boot/efi/" >&2
    exit 1
fi

echo "Unmounting /target/boot/..."
if umount /target/boot/; then
    echo "✓ Successfully unmounted /target/boot/"
    sleep 1
else
    echo "✗ Error: Failed to unmount /target/boot/" >&2
    exit 1
fi

echo "Unmounting /target/..."
if umount /target/; then
    echo "✓ Successfully unmounted /target/"
    sleep 1
else
    echo "✗ Error: Failed to unmount /target/" >&2
    exit 1
fi

echo "Mounting $VOLUME_GROUP_NAME..."
if mount $VOLUME_GROUP_NAME /mnt; then
    echo "✓ Successfully mounted $VOLUME_GROUP_NAME"
    sleep 1
else
    echo "✗ Error: Failed to mount $VOLUME_GROUP_NAME" >&2
    exit 1
fi

cd /mnt

# for snapper support
echo "Moving @rootfs to @..."
if mv @rootfs/ @; then
    echo "✓ Successfully moved @rootfs to @"
    sleep 1
else
    echo "✗ Error: Failed to move @rootfs to @" >&2
    exit 1
fi

# create subvolumes
subs="@snapshots @home @tmp @var @opt"
for sub in $subs
do 
    echo "Creating subvolume $sub..."
    if btrfs subvolume create "$sub"; then
        echo "✓ Successfully created subvolume $sub"
    sleep 1
    else
        echo "✗ Error: Failed to create subvolume $sub" >&2
        exit 1
    fi
done

# mount root directory
echo "Mounting $VOLUME_GROUP_NAME to /target"
if mount -o ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@ $VOLUME_GROUP_NAME /target; then
    echo "✓ Successfully mounted @"
    sleep 1
else
    echo "✗ Error: Failed to mount @"
    exit 1
fi

cd /target
# create mount points
mountpoints=".snapshots home tmp var opt"
for mountpoint in $mountpoints
do
    echo "Creating mountpoint $mountpoint..."
    if  mkdir -p "$mountpoint"; then
        echo "✓ Successfully created mountpoint $mountpoint"
        sleep 1
    else 
        echo "Error: failed to create mountpoint $mountpoint"
        exit 1
    fi
done

# mount subvolumes
echo "Mounting @snapshots..."
if mount -o ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@snapshots "$VOLUME_GROUP_NAME" /target/.snapshots; then
    echo "✓ Successfully mounted @snapshots"
    sleep 1
else
    echo "✗ Error: Failed to mount @snapshots" >&2
    exit 1
fi

echo "Mounting @home..."
if mount -o ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@home "$VOLUME_GROUP_NAME" /target/home; then
    echo "✓ Successfully mounted @home"
    sleep 1
else
    echo "✗ Error: Failed to mount @home" >&2
    exit 1
fi

echo "Mounting @tmp..."
if mount -o ssd,noatime,nodatacow,space_cache=v2,commit=120,discard=async,subvol=@tmp "$VOLUME_GROUP_NAME" /target/tmp; then
    echo "✓ Successfully mounted @tmp"
    sleep 1
else
    echo "✗ Error: Failed to mount @tmp" >&2
    exit 1
fi

echo "Mounting @var..."
if mount -o ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@var "$VOLUME_GROUP_NAME" /target/var; then
    echo "✓ Successfully mounted @var"
    sleep 1
else
    echo "✗ Error: Failed to mount @var" >&2
    exit 1
fi

echo "Mounting @opt..."
if mount -o ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@opt "$VOLUME_GROUP_NAME" /target/opt; then
    echo "✓ Successfully mounted @opt"
    sleep 1
else
    echo "✗ Error: Failed to mount @opt" >&2
    exit 1
fi

# mount boot and efi partitions
echo "Mounting $boot"
if mount $boot boot; then
    echo "✓ Successfully mounted $boot"
    sleep 1
else 
    echo "Error: failed to mount $boot"
    exit 1
fi

echo "Mounting $efi"
if  mount $efi boot/efi; then
    echo "✓ Successfully mounted $efi"
    sleep 1
else 
    echo "Error: failed to mount $efi"
    exit 1
fi

# remove original fstab entry for @
sed '/$VOLUME_GROUP_NAME/d' etc/fstab >> /dev/null

# writing /target/etc/fstab
echo "Writing root (@) entry..."
if echo "$VOLUME_GROUP_NAME / btrfs ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@ 0 1" >> /target/etc/fstab; then
    echo "✓ Successfully wrote root entry"
    sleep 1
else
    echo "✗ Error: Failed to write root entry to fstab" >&2
    exit 1
fi

echo "Writing @snapshots entry..."
if echo "$VOLUME_GROUP_NAME /.snapshots btrfs ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@snapshots 0 2" >> /target/etc/fstab; then
    echo "✓ Successfully wrote @snapshots entry"
    sleep 1
else
    echo "✗ Error: Failed to write @snapshots entry to fstab" >&2
    exit 1
fi

echo "Writing @home entry..."
if echo "$VOLUME_GROUP_NAME /home btrfs ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@home 0 2" >> /target/etc/fstab; then
    echo "✓ Successfully wrote @home entry"
    sleep 1
else
    echo "✗ Error: Failed to write @home entry to fstab" >&2
    exit 1
fi

echo "Writing @tmp entry..."
if echo "$VOLUME_GROUP_NAME /tmp btrfs ssd,noatime,nodatacow,space_cache=v2,commit=120,discard=async,subvol=@tmp 0 2" >> /target/etc/fstab; then
    echo "✓ Successfully wrote @tmp entry"
    sleep 1
else
    echo "✗ Error: Failed to write @tmp entry to fstab" >&2
    exit 1
fi

echo "Writing @var entry..."
if echo "$VOLUME_GROUP_NAME /var btrfs ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@var 0 2" >> /target/etc/fstab; then
    echo "✓ Successfully wrote @var entry"
    sleep 1
else
    echo "✗ Error: Failed to write @var entry to fstab" >&2
    exit 1
fi

echo "Writing @opt entry..."
if echo "$VOLUME_GROUP_NAME /opt btrfs ssd,noatime,space_cache=v2,commit=120,compress=zstd:1,discard=async,subvol=@opt 0 2" >> /target/etc/fstab; then
    echo "✓ Successfully wrote @opt entry"
    sleep 1
else
    echo "✗ Error: Failed to write @opt entry to fstab" >&2
    exit 1
fi

cd /
umount /mnt
echo successfully unmounted /mnt
sleep 1
exit
