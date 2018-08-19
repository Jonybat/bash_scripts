#!/bin/bash
#
### Grub and fstab installer for backup drive

. /opt/scripts/shlog.sh
. /opt/scripts/shuser.sh root

### Settings
backupFstab="/etc/fstab.backupfs"

error=0

error_incr() {
error=$(( $error + 1 ))
shlog -s timestamp "ERROR! - $1"
}

critical_exit() {
shlog -s timestamp "CRITICAL! - $1 - TERMINATED"
exit 1
}

### Main
# Set backup path from $1
if [[ $# -eq 0 ]]; then
  critical_exit "No path specified"
elif [[ ! $(mount | grep "on $1 ") ]]; then
  critical_exit "Filesystem '$1' is not valid or not mounted"
else
  backupPath="$1"
fi

# Get backup disk from boot folder/mountpoint on the backup path, lvm aware, since /boot cant be in lvm
backupDisk=$(df $1/boot | grep -Eo '/dev/sd.') || critical_exit "Disk '$(df $1/boot | awk '/^\/dev/ {print $1}')' is not valid for grub installation"

# Mount dev, proc and sys if not mounted already
mount | grep -o "on $backupPath/dev type" || mount --bind /dev "$backupPath/dev"
mount | grep -o "on $backupPath/dev/pts type" || mount --bind /dev/pts "$backupPath/dev/pts"
mount | grep -o "on $backupPath/proc type" || mount --bind /proc "$backupPath/proc"
mount | grep -o "on $backupPath/sys type" || mount --bind /sys "$backupPath/sys"
mount | grep -o "on $backupPath/run type" || mount --bind /run "$backupPath/run"

# Chroot to the backup dir and install grub
chroot $backupPath grub-install $backupDisk # || error_incr "Failed to install grub to $backupDisk" # need to find a way to capture chroot commands result
chroot $backupPath update-grub2 # || error_incr "Failed to update grub settings"

umount "$backupPath/dev/pts"
umount "$backupPath/dev"
umount "$backupPath/proc"
umount "$backupPath/sys"
umount "$backupPath/run"

# Check if fstab files differ TODO: this only works the first time, because after the next copy, rsync wont overwrite
#cmp --silent $backupPath$backupFstab $backupPath/etc/fstab && error_incr "Fstab files are equal, the backup fs will not boot"
# Activate backupfs fstab
cp -f $backupPath$backupFstab $backupPath/etc/fstab || error_incr "Unable to activate fstab, the backup fs will not boot"

# Output exit report
if [[ $error -eq 0 ]]; then
  shlog -s datestamp "Updated successfully"
  exit 0
else
  shlog -s datestamp "Script finished with $error error(s)"
  exit 2
fi
