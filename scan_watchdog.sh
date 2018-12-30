#!/bin/bash
#
### Scan watchdog
#
# Requires: scanimage (sane-utils), imagemagick, samba

. /opt/scripts/shlog.sh
. /opt/scripts/shuser.sh root
. /opt/scripts/shlock.sh
. /opt/scripts/.secrets

trigger="$SCAN_RAMDISK/scan"

if [[ ! $(mount | grep -o "$SCAN_RAMDISK") ]]; then
  # Create ramdisk, mount it, make it writable by everyone and restart samba
  mkfs -q /dev/ram0 1024
  mount --rw /dev/ram0 "$SCAN_RAMDISK"/
  chmod -R 777 "$SCAN_RAMDISK"
  systemctl restart smbd
fi

error_catch () {
if [[ $? -eq 0 ]]; then
  shlog -s timestamp "Successfully scanned image to $finalFile"
else
  shlog -s timestamp "Error scanning image to $finalFile"
fi
}

### Main
while true; do
if [[ -e "$trigger" ]]; then
  timestamp=$(date +%H-%M-%S)
  tmpFile="/tmp/scan_$timestamp.tiff"
  filename="scan_$timestamp"
  finalFile="$SCAN_DESTINATION$filename.jpg"
  # Check first if the scanner is online, and keep trying until it is
  if [[ $(lsusb | grep -o $SCAN_DEVID) ]]; then
    # Read the scan mode from the file and set the var
    mode=$(grep -Eo ".*\S" "$trigger")
    # Scan and convert according to the scan mode
    if [[ $mode == "" || $mode == color ]]; then
      shlog -s datestamp "Scanning $mode image"
      scanimage --mode=Color --resolution 300 -x 210 -y 297 --format=tiff > "$tmpFile"
      convert "$tmpFile" -quality 90% "$finalFile"
      error_catch
      chown samba:samba "$finalFile"
      chmod 666 "$finalFile"
    elif [[ $mode == grayscale ]]; then
      shlog -s datestamp "Scanning $mode image"
      scanimage --mode=Gray --resolution 300 -x 210 -y 297 --format=tiff > "$tmpFile"
      convert "$tmpFile" -quality 90% "$finalFile"
      error_catch
      chown samba:samba "$finalFile"
      chmod 666 "$finalFile"
    elif [[ $mode == lineart ]]; then
      shlog -s datestamp "Scanning $mode image"
      scanimage --mode=Lineart --resolution 600 -x 210 -y 297 --format=tiff > "$tmpFile"
      convert "$tmpFile" -quality 90% "$finalFile"
      error_catch
      chown samba:samba "$finalFile"
      chmod 666 "$finalFile"
    elif [[ $mode == color-hq ]]; then
      shlog -s datestamp "Scanning $mode image"
      scanimage --mode=Color --resolution 600 -x 210 -y 297 --format=tiff > "$tmpFile"
      convert "$tmpFile" -quality 90% "$finalFile"
      error_catch
      chown samba:samba "$finalFile"
      chmod 666 "$finalFile"
    elif [[ $mode == grayscale-hq ]]; then
      shlog -s datestamp "Scanning $mode image"
      scanimage --mode=Gray --resolution 600 -x 210 -y 297 --format=tiff > "$tmpFile"
      convert "$tmpFile" -quality 90% "$finalFile"
      error_catch
      chown samba:samba "$finalFile"
      chmod 666 "$finalFile"
    else
      shlog -s datestamp "Scan mode $mode not recognized, not doing anything."
    fi
    # Remove the temporary scan file and the scan trigger file, so the script can keep running
    rm -f "$tmpFile"
    rm -f "$trigger"
  else
    shlog -s datestamp "Scanner is not connected"
  fi
fi
sleep 5
done
