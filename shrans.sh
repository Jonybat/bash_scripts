#!/bin/bash
#
### Shell script dir mount
#
# Requires:
# - shlog.sh
# - convert (imagemagick)
# - md5sum (coreutils)
#
### To be sourced from other scripts

shrans_check (){
  local DEST="$1"
  if [[ -f $DEST/.shrans.md5 ]]; then
    md5sum --status --strict -c $DEST/.shrans.md5
    if [[ $? -ne 0 ]]; then
      shlog -s datestamp "Hashes from ransomware bait files do not match. Exiting"
      exit 1
    fi
  else
    shlog -s datestamp "Hashes file is missing"
  fi
}

shrans_init (){
  local DEST="$1"
  if [[ ! -f $DEST/.shrans.md5 ]]; then
    echo "Bait files, do not remove these files nor .shrans.md5" > $DEST/.aaa_do_not_remove.txt
    convert xc:none -page A4 $DEST/.aaa_do_not_remove.pdf
    convert xc:white -size 1920x1080 $DEST/.aaa_do_not_remove.jpg
    md5sum $DEST/.aaa_do_not_remove.txt > $DEST/.shrans.md5
    md5sum $DEST/.aaa_do_not_remove.pdf >> $DEST/.shrans.md5
    md5sum $DEST/.aaa_do_not_remove.jpg >> $DEST/.shrans.md5
    chmod 666 $DEST/.aaa_do_not_remove.*
    chmod 440 $DEST/.shrans.md5
  else
    shlog -s datestamp "Bait files already created"
  fi
}
