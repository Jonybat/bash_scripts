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
      shlog -s datestamp "Hashes from ransomware honey files do not match"
      return 1
    fi
  else
    shlog -s datestamp "Hashes file is missing"
  fi
}

shrans_init (){
  local DEST="$1"
  if [[ ! -f $DEST/.shrans.md5 ]]; then
    echo "Honey files, do not remove these files nor .shrans.md5" > $DEST/.aaa_do_not_remove.txt
    convert xc:none -page A4 $DEST/.aaa_do_not_remove.pdf
    convert xc:white -size 1920x1080 $DEST/.aaa_do_not_remove.jpg
    md5sum $DEST/.aaa_do_not_remove.txt > $DEST/.shrans.md5
    md5sum $DEST/.aaa_do_not_remove.pdf >> $DEST/.shrans.md5
    md5sum $DEST/.aaa_do_not_remove.jpg >> $DEST/.shrans.md5
    chmod 666 $DEST/.aaa_do_not_remove.*
    chmod 440 $DEST/.shrans.md5
  else
    shlog -s datestamp "Honey files already created"
  fi
}

if [[ $0 =~ .*shrans ]]; then
  if [[ $# -eq 0 ]]; then
    echo "Pass the path to init as the single argument"
    echo "Usage: shrans.sh /path"
    exit 1
  else
    shrans_init "$1"
    echo "Now source this script from other script and call 'shrans_check /path'"
  fi
fi

