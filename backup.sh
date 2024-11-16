#!/bin/bash
#
### Backup script
#
# Requires:
# - rsync		(to backup files and folders)
# - cp			(to create a copy of the backup)
# - ncftp		(to download files from FTP servers)
# - mysqldump		(to backup MySQL databases)
# - tar			(to archive the backup folder)
# - 7za (p7zip)		(to compress the backup file)
#
### ./backup.sh --help for usage, see the provided backup_config.sample for settings

. /opt/scripts/shlog.sh

backup_vars ()
{
### BACKUP FOLDER NAME
dateStamp=$(date +%Y-%m-%d_%H-%M_%a-%V)

### COMPRESSED FILE NAME
compressedFile="$dateStamp.tar.7z"

### RSYNC EXCLUSIONS
for exc in ${!rsyncExcludes[*]}; do
  excludes="$excludes--exclude ${rsyncExcludes[$exc]} "
done

### RSYNC OPTIONS
rsyncArgs="--quiet --archive --acls --xattrs --force --delete --backup --relative $excludes"

### RSYNC OPTIONS FOR ROOT FS
rsyncArgsRoot="--archive --acls --xattrs --update --force --delete --one-file-system --exclude=/dev/* --exclude=/proc/* --exclude=/sys/* --exclude=/tmp/* --exclude=/run/* --exclude=/lost+found"

### RSYNC OPTIONS FOR FULL CLONE
rsyncArgsAll="--archive --acls --xattrs --update --force --delete --exclude=/dev/* --exclude=/proc/* --exclude=/sys/* --exclude=/tmp/* --exclude=/run/* --exclude=/lost+found --exclude=/media/* --exclude=/mnt/*"

### TAR OPTIONS
tarArgs="--create --preserve-permissions --recursion --remove-files --to-stdout"

### 7Z OPTIONS
compressorArgs="a -si -bd"

## CP OPTIONS
cpArgs="--recursive --force"

### VARIABLE CONCATENATION
tmpPath="$tmpDir/$dateStamp"
ftpArgs="-R -T -v -u $ftpUser -p $ftpPass"
mysqlArgs="-h $mysqlHost -u$mysqlUser -p$mysqlPass -N"
mysqldumpArgs="-h $mysqlHost -u $mysqlUser -p$mysqlPass"
ftpPath="$tmpPath/$ftpDir"
sqlPath="$tmpPath/$sqlDir"
compressedPath="$tmpDir/$compressedFile"
versionsPath="$tmpDir/$versionsFile"
selectionsPath="$tmpDir/$selectionsFile"
warning="0"
error="0"
settings="0"
archiveSettings="0"
totalDirs="0"
totalFiles="0"
}

warning_catch ()
{
if [[ $? -ne 0 ]]; then
  warning=$(( $warning + 1 ))
  shlog -s timestamp "\e[0;31mERROR!\e[0m - $1"
else
  shlog -s timestamp "\e[0;32mOK!\e[0m    - $2"
fi
}

error_catch ()
{
if [[ $? -ne 0 ]]; then
  error=$(( $error + 1 ))
  shlog -s timestamp "\e[0;31mERROR!\e[0m - $1"
else
  shlog -s timestamp "\e[0;32mOK!\e[0m    - $2"
fi
}

critical_exit ()
{
shlog -s timestamp "\e[41mCRITICAL!\e[0m    - $1 - TERMINATED"
exit 1
}

backup_dir_cleanup ()
{
# Get the total size of the backup, whether it has been compressed or not
if [[ $tarBackup -eq 1 ]]; then
  backupSize=$(ls -l --block-size=K | grep $compressedFile | awk '{print $5}' | sed 's/K$//')
else
  backupSize=$(du -s $dateStamp | awk '{print $1}')
fi
# Check if the backup is bigger than the destination directory and exit
if [[ $backupSize -gt $2 ]]; then
  error=$(( $error + 1 ))
  shlog -s timestamp "\e[0;31mERROR!\e[0m - The total size of the backup is bigger than the destination directory ($1)"
else
  cd $1
  dirSpace=$(( $2 - $(du -s | awk '{print $1}') ))
  # Keep removing the oldest backup untill the backup fits
  while [[ $backupSize -gt $dirSpace ]]; do
    shlog -s timestamp "\e[0;36mINFO\e[0m   - Backup size: ${backupSize}KB - Free space in the destination directory: ${dirSpace}KB"
    oldestBackup="$(ls -lt | awk '{print $9}'|tail -1)"
    rm -rfv "$oldestBackup"
    dirSpace=$(( $2 - $(du -s | awk '{print $1}') ))
    shlog -s timestamp "\e[0;36mINFO\e[0m   - Free space after cleanup: ${dirSpace}KB"
  done
  cd - >/dev/null
fi
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

# Count the real number of dirs and files
for line in ${!sourceDir[*]}; do
  realFiles=$(find "${sourceDir[$line]}" -type f | wc -l)
  totalFiles=$(($totalFiles+$realFiles))
  realDirs=$(find "${sourceDir[$line]}" -type d | wc -l)
  totalDirs=$(($totalDirs+$realDirs))
done

shlog " "
shlog " "
shlog -s weekstamp "Using config file: $1"

shlog " "
if [[ ${#sourceDir[*]} -ne 0 ]]; then
  shlog "Items set to backup: \e[0;32m${#sourceDir[*]}\e[0m - Folders: $totalDirs, Files: $totalFiles"
  settings=$(( $settings + 1 ))
  archiveSettings=$(( $archiveSettings + 1 ))
else
  shlog "Items set to backup: \e[0;31m0\e[0m"
fi
if [[ $backupFtp -eq 1 ]]; then
  shlog "FTP files backup: \e[0;32mYES\e[0m"
  settings=$(( $settings + 1 ))
  archiveSettings=$(( $archiveSettings + 1 ))
else
  shlog "FTP files backup: \e[0;31mNO\e[0m"
fi
if [[ $backupMysql -eq 1 ]]; then
  shlog "MySQL database backup: \e[0;32mYES\e[0m"
  settings=$(( $settings + 1 ))
  archiveSettings=$(( $archiveSettings + 1 ))
else
  shlog "MySQL database backup: \e[0;31mNO\e[0m"
fi
if [[ $tarBackup -eq 1 ]]; then
  shlog "Backup folder compression: \e[0;32mYES\e[0m"
else
  shlog "Backup folder compression: \e[0;31mNO\e[0m"
fi
if [[ -n $extraBackupDir ]]; then
  shlog "Create copy of backup: \e[0;32mYES\e[0m"
else
  shlog "Create copy of backup: \e[0;31mNO\e[0m"
fi
if [[ -n $cloneDir ]]; then
  shlog "Root filesystem cloning: \e[0;32mYES\e[0m"
  settings=$(( $settings + 1 ))
else
  shlog "Root filesystem cloning: \e[0;31mNO\e[0m"
fi
shlog " "

# Output extra info from commands set in config
shlog "$(extra_info)"
shlog " "

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

# Check if any settings are defined
if [[ $archiveSettings -ne 0 ]]; then

  mkdir -p "$tmpPath" || critical_exit "Unable to create the temporary directory!"

  ### Folders and files backup
  for dir in ${!sourceDir[*]}; do
    if [[ -e ${sourceDir[$dir]} ]]; then
      rsync $rsyncArgs "${sourceDir[$dir]}" "$tmpPath"
      warning_catch "The files backup process failed in '${sourceDir[$dir]}'. Check the file permissions." "'${sourceDir[$dir]}' copied successfully."
    else
      warning=$(( $warning + 1 ))
      shlog -s timestamp "\e[0;31mERROR!\e[0m - The files backup process failed in '${sourceDir[$dir]}'. Check if the file exists."
    fi
    if [[ $warning -ge ${#sourceDir[*]} ]]; then
      error=$(( $error + 1 ))
    fi
  done

  ### FTP backup
  if [[ $backupFtp -eq 1 ]]; then
    if mkdir -p "$ftpPath"; then
      ncftpget $ftpArgs $ftpHost "$ftpPath" /
      error_catch "The FTP files backup failed. Check the settings." "All the FTP files were copied successfully."
    else
      shlog -s timestamp "\e[0;31mERROR!\e[0m - Unable to create the FTP directory"
    fi
  fi

  ### MySQL backup
  if [[ $backupMysql -eq 1 ]]; then
    if mkdir -p "$sqlPath"; then
      if [[ $mysqlDb != "-A" ]]; then
        tmpText="The database '$mysqlDb' was copied successfully'."
        mysqldump $mysqldumpArgs $mysqlDb > "$sqlPath/$mysqlDb.sql"
      else
        tmpText="All the databases were copied successfully to '$sqlPath'."
        mysql $mysqlArgs -e 'show databases' | while read dbName; do
          mysqldump $mysqldumpArgs $dbName > "$sqlPath/$dbName.sql"
          error_catch "The database backup failed on database '$dbName'. Check the database permissions." "The database '$dbName' was copied successfully."
        done
      fi
      error_catch "The MySQL database backup failed. Check the settings." "$tmpText"
    else
      shlog -s timestamp "\e[0;31mERROR!\e[0m - Unable to create the SQL directory"
    fi
  fi

  cd $tmpPath || critical_exit "Unable to change to the temporary directory!"

  # Add files from extra commands set in config
  extra_commands

  cd $tmpDir || critical_exit "Unable to change to the temporary directory!"

  # Check if files were backed up to decide if we should archive, move or delete the backup folder
  if [[ -n $(ls $dateStamp) ]]; then
    # Compress the backup files and move to the destination or just move the folder
    if [[ $tarBackup -eq 1 ]]; then
      tar $tarArgs $dateStamp | 7za $compressorArgs $compressedFile 2>&1 >/dev/null
      error_catch "Unable to create the 7z file in '$compressedPath'." "The 7z file was created successfully in '$compressedPath'."
      backup_dir_cleanup "$backupDir" $maxDirSize
      mv $compressedFile "$backupDir"
      error_catch "Unable to move the compressed file to '$backupDir'." "The compressed file was moved successfully to '$backupDir'."
    else
      backup_dir_cleanup "$backupDir" $maxDirSize
      mv $dateStamp "$backupDir"
      error_catch "Unable to move the backup folder to '$backupDir'." "The backup folder was moved successfully to '$backupDir'."
    fi
  else
    error=$(( $error + 1 ))
    shlog -s timestamp "\e[0;31mERROR!\e[0m - No files were backed up. Removing '$dateStamp'"
    rm -rf $dateStamp*
  fi
else
  true || error_catch "Nothing was set to backup!"
fi

### Extra backup copy
if [[ -n $extraBackupDir ]]; then
  # Change dir to the extra backup dir to get all the available space
  cd "$extraBackupDir"
  extraBackupDirSize=$(df . | tail -n 1 | awk '{print $2}')
  # Change to the dir where the backup has been moved to
  cd "$backupDir"
  if [[ "$tarBackup" -eq 1 ]];
    # Clean the destination dir before copying
    backup_dir_cleanup "$extraBackupDir" $extraBackupDirSize
    then
      cp $cpArgs $compressedFile "$extraBackupDir"
      error_catch "Unable to copy the compressed file to '$extraBackupDir'." "The compressed file was copied successfully to '$extraBackupDir'."
    else
      cp $cpArgs "$backupPath" "$extraBackupDir"
      error_catch "Unable to copy the backup folder to '$extraBackupDir'." "The backup folder was copied successfully to '$extraBackupDir'."
  fi
fi

### Root FS clone
if [[ -n $cloneDir ]]; then
  . /opt/scripts/shmount.sh

  mount_mounts "${cloneDirMounts[@]}"
  rsync $rsyncArgsRoot / "$cloneDir"
  warning_catch "The root filesystem cloning to '$cloneDir' ended with errors." "The root filesystem cloning to '$cloneDir' ended successfully."
  rsync $rsyncArgsAll / "$cloneDir"
  warning_catch "The full filesystem cloning to '$cloneDir' ended with errors." "The full filesystem cloning to '$cloneDir' ended successfully."
  # Run clone dir installer script if set
  if [[ -n $cloneDirScript ]]; then
    $cloneDirScript $cloneDir
    warning_catch "The backup filesystem installation script terminated with errors." "The backup filesystem installation script terminated successfully."
  fi
  umount_mounts "${cloneDirMounts[@]}"
fi

### Output final script report
shlog " "
if [[ $error -ne 0 ]]; then
  shlog -s datestamp "\e[0;31m$error ERROR(S)\e[0m    - Backup finished with $error error(s)."
elif [[ $warning -ne 0 ]]; then
  shlog -s datestamp "\e[0;33m$warning WARNINGS(S)\e[0m - Backup finished with $warning warning(s)."
else
  shlog -s datestamp "\e[0;32mALL GOOD\e[0m      - Backup finished successfully."
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
;;


'status')
# Get LOGPATH from shlog
shlog_global_vars -s

if [[ -e $LOGPATH ]]; then
  if [[ -n $2 ]]; then
    configSafe=$(echo $2 | sed 's/\//\\\//g')
    awk "/$configSafe/,/finished/" $LOGPATH | grep -i "finished" | tail -n 1
  else
    for config in $(grep -Po "(?<=file: ).*" $LOGPATH | sort -u); do
      echo ""
      echo "Last backup from config file: $config"
      configSafe=$(echo $config | sed 's/\//\\\//g')
      awk "/$configSafe/,/finished/" $LOGPATH | grep -i "finished" | tail -n 1
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
