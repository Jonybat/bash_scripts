#!/bin/bash

. /opt/scripts/shlog.sh

backup_vars (){
### Init vars
borgBin=/usr/bin/borg
backupName=$(date '+%Y-%m-%d_%H:%M')

# Borg defaults
borgPass=${borgPass:=}
borgCompression=${borgCompression:=auto,lz4}
borgKeepDaily=${borgKeepDaily:=7}
borgKeepWeekly=${borgKeepWeekly:=4}
borgKeepMontly=${borgKeepMonthly:=6}
borgKeepYearly=${borgKeepYearly:=5}

warning=0
error=0
critical=0
settings=0
}

final_report ()
{
shlog " "
if [[ $critical -ne 0 ]]; then
  shlog -s datestamp "Backup result: \e[0;31mFAILED\e[0m"
elif [[ $error -ne 0 ]]; then
  shlog -s datestamp "Backup result: \e[0;31m$error ERROR(S)\e[0m"
elif [[ $warning -ne 0 ]]; then
  shlog -s datestamp "Backup result: \e[0;33m$warning WARNINGS(S)\e[0m"
else
  shlog -s datestamp "Backup result: \e[0;32mALL GOOD\e[0m"
fi
echo ""

# Get LOGPATH from shlog
shlog_global_vars -s

### Create a non colored log file if set above
if [[ -n $plainLog ]]; then
  plainLogFile="$LOGPATH.plain"
  cp "$LOGPATH" "$plainLogFile"
  sed -i -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" "$plainLogFile"
fi
}

borg_catch ()
{
rc=$?
if [[ $rc -eq 0 ]]; then
  shlog -s timestamp "\e[0;32mOK!\e[0m       - $1"
elif [[ $rc -eq 1 ]]; then
  warning=$(( $warning + 1 ))
  shlog -s timestamp "\e[0;33mWARNING!\e[0m  - $1"
elif [[ $rc -eq 2 ]]; then
  error=$(( $error + 1 ))
  shlog -s timestamp "\e[0;31mERROR!\e[0m    - $1"
else
  error=$(( $error + 1 ))
  shlog -s timestamp "\e[0;31mUNKERROR!\e[0m - $1"
fi
}

critical_exit ()
{
shlog -s timestamp "\e[41mCRITICAL!\e[0m - $1"
critical=1
final_report
exit 1
}

backup_source_config ()
{
# Check if config file argument was specified and if it is readable, then source it
if [[ -n "$1" ]]; then
  if [[ -r "$1" ]]; then
    source "$1"
  else
    shlog -s datestamp "Config file is not valid or not readable! Exiting..."
    exit 1
  fi
else
  shlog -s datestamp "No config file specified! Exiting..."
  echo ""
  backup_help
  exit 1
fi
}

backup_settings ()
{
# Check if config file was specified and source it
backup_source_config "$1"

# Populate the vars
backup_vars

shlog " "
shlog " "
shlog -s weekstamp "Using config file: $1"

shlog " "
if [[ ${#repos[*]} -ne 0 ]]; then
  shlog "Repos set to backup: \e[0;32m${#repos[*]}\e[0m"
  settings=$(( $settings + 1 ))
fi
}

backup_help ()
{
echo "Usage: $0 [start|status|settings] [config_file]"
}


### Main
case "$1" in
'start')
# Pass the second argument to the child function and print the current settings
backup_settings "$2"

# Mount required mountpoints before backup, if defined
if [[ -n $backupMounts ]]; then
  . /opt/scripts/shmount.sh
  mount_mounts "${backupMounts[@]}" || critical_exit "Failed to mount backup mountpoints!"
fi

# Check for ransomware in specified dirs, if defined
if [[ -n $ransChecks ]]; then
  . /opt/scripts/shrans.sh
  for dir in ${ransChecks[@]}; do
    shrans_check "$dir" || critical_exit "Ransomware check failed!"
  done
fi

# Create backup dir if it does not exist
if [[ ! -d "$mainDir" ]]; then
  mkdir -p "$mainDir" || critical_exit "Unable to create missing backup directory!"
fi

preCommands

for repo in ${repos[@]}; do
  repoPath="${mainDir}/${repo}"
  if [[ ! -d "$repoPath" ]]
  then
    shlog -s timestamp "Creating new borg repository '$repo' in '$mainDir'"
    result=$(BORG_PASSPHRASE="$borgPass" $borgBin init --encryption=keyfile-blake2 "$repoPath" 2>&1)
    borg_catch "$result"
  fi

  # Declare string as variable
  #declare -n hack="repo_$repo"
  hack="repo_$repo"
  # Use indirect expansion to access all elements of the array
  eval "repoPaths=(\"\${${hack}[@]}\")"

  shlog -s timestamp "Backing up files to '$repo' repo"

  #result=$(printf '%s\n' "${hack[@]}" | BORG_PASSPHRASE="$borgPass" $borgBin create --stats --list --compression auto,lzma,5 --paths-from-stdin "${repoPath}::${backupName}" 2>&1)
  # Borg's --path-from-* does not recurse over provided dirs, so build the list first with find
  unset paths
  for path in $(printf '%s\n' "${repoPaths[@]}"); do
    paths="${paths}"$'\n'"$(find $path)"
  done
  # Remove empty lines
  paths=$(echo "$paths" | sed '/^$/d')

  # Run backup
  result=$(echo "$paths" | BORG_PASSPHRASE="$borgPass" $borgBin create --stats --compression "$borgCompression" --paths-from-stdin "${repoPath}::${backupName}" 2>&1)
  borg_catch "$result"

  # Prune old backups
  shlog -s timestamp "Pruning old backups from '$repo' repo"
  result=$(BORG_PASSPHRASE="$borgPass" $borgBin prune --stats --save-space "$repoPath" --keep-daily=$borgKeepDaily --keep-weekly=$borgKeepWeekly --keep-monthly=$borgKeepMontly --keep-yearly=$borgKeepYearly 2>&1)
  borg_catch "$result"

  # Compact borg repo
  shlog -s timestamp "Compacting '$repo' repo"
  result=$($borgBin compact --verbose "$repoPath" 2>&1)
  borg_catch "$result"

  #chgrp -R syncthing "$repoPath"
  #chmod -R u=rwX,g=rX,o= "$repoPath"
done

postCommands

# Unmount previously mounted mountpoints
if [[ -n $backupMounts ]]; then
  umount_mounts "${backupMounts[@]}"
fi

### Output final script report
final_report
;;


'status')
# Get LOGPATH from shlog
shlog_global_vars -s

if [[ -e $LOGPATH ]]; then
  if [[ -n $2 ]]; then
    configSafe=$(echo $2 | sed 's/\//\\\//g')
    awk "/$configSafe/,/Backup result/" $LOGPATH | grep "Backup result" | tail -n 1
  else
    for config in $(grep -Po "(?<=file: ).*" $LOGPATH | sort -u); do
      echo ""
      echo "Last backup from config file: $config"
      configSafe=$(echo $config | sed 's/\//\\\//g')
      awk "/$configSafe/,/Backup result/" $LOGPATH | grep "Backup result" | tail -n 1
    done
    echo ""
  fi
else
  echo "The log file doesn't exist or it's not accessible"
fi
;;


'settings')
# Change LOGPATH so we dont write anything to the log file
LOGPATH="/dev/null"

# Pass the second argument to the child function and print the current settings
backup_settings "$2"
;;

-h|--help)
backup_help
;;

*)
echo -n "Invalid option!

"
backup_help
exit 1
;;
esac
exit 0
