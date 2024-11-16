#!/bin/bash
#
### Shell script dir mount
#
# Requires: shlog.sh
#
### To be sourced from other scripts

mount_mounts (){
MOUNTS=("$@")
for MOUNT in "${MOUNTS[@]}"; do
  IFS="," read -r -a MOUNT_ARRAY <<< "${MOUNT}"
  local MOUNT_UUID=${MOUNT_ARRAY[0]}
  local MOUNT_DIR=${MOUNT_ARRAY[1]}
  local MOUNT_FSTYPE=${MOUNT_ARRAY[2]:=auto}
  local MOUNT_OPTS=${MOUNT_ARRAY[3]:=defaults}

  if mountpoint -q "$MOUNT_DIR"; then
    shlog -s datestamp "Notice: $MOUNT_DIR already mounted"
  else
    sudo mount -t "$MOUNT_FSTYPE" -o "$MOUNT_OPTS" -U "$MOUNT_UUID" "$MOUNT_DIR"
    if [[ $? -ne 0 ]]; then
      shlog -s datestamp "Failed to mount $MOUNT_DIR. Exiting"
      exit 1
    fi
  fi
done
}

umount_mounts (){
MOUNTS=("$@")
# Mountpoints should be unmounted in reverse order, so reverse array
for i in "${MOUNTS[@]}"; do
  MOUNTS_REV=("$i" "${MOUNTS_REV[@]}")
done

for MOUNT in "${MOUNTS_REV[@]}"; do

  IFS="," read -r -a MOUNT_ARRAY <<< "${MOUNT}"
  local MOUNT_UUID=${MOUNT_ARRAY[0]}
  local MOUNT_DIR=${MOUNT_ARRAY[1]}

  if mountpoint -q "$MOUNT_DIR"; then
    sudo umount -q "$MOUNT_DIR"
    if [[ $? -ne 0 ]]; then
      shlog -s datestamp "Failed to umount $MOUNT_DIR. Exiting"
      exit 1
    fi
  fi
done
}
