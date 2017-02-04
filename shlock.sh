#!/bin/bash
#
### Shell script run lock
#
# Requires: shlog.sh
#
### To be sourced from other scripts

relativeLockDir=$(dirname "$0")

# Check if we have permission to write in /run, if not set the LOCKDIR the same as the script's dir
if [[ -w "/run" ]]; then
  LOCKDIR="/run"
else
  LOCKDIR=$(cd "$relativeLogDir" && pwd)
fi

# Get the script name, filter the path and replace extension with .pid, if it has one
if [[ "$0" =~ \.sh ]]; then
  LOCKFILE=$LOCKDIR/$(echo "$0" | sed 's/.*\///' | sed 's/sh$/pid/')
else
  LOCKFILE=$LOCKDIR/$(echo "$0" | sed 's/.*\///').pid
fi

# Check if a lock file exists and the script is still running or create the lock file if its not
if [[ -e $LOCKFILE ]]; then
  kill -0 $(cat $LOCKFILE) 2> /dev/null
  if [[ $? -eq 0 ]]; then
    shlog -s datestamp "Script already running. Exiting"
    exit 1
  else
    shlog -s datestamp "Lock file found but script is not running. Updating pid"
    echo $$ > $LOCKFILE
  fi
else
  echo $$ > $LOCKFILE
fi

remove_lock (){
  rm -f $LOCKFILE
}
