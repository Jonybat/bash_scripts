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
###

# TODO
# - pre commands to include on backup

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

### ALT RSYNC FLAGS
rsyncArgsRootfs="--archive --acls --xattrs --update --force --delete --one-file-system --exclude=/proc/* --exclude=/sys/* --exclude=/tmp/* --exclude=/media/* --exclude=/run/* --exclude=/dev/* --exclude=/lost+found"

### TAR OPTIONS
tarArgs="--create --preserve-permissions --recursion --remove-files --to-stdout"

### 7Z OPTIONS
compressorArgs="a -si -bd"

## CP OPTIONS
cpArgs="--recursive --force"

### VARIABLE CONCATENATION
tmpPath="$tmpDir/$dateStamp"
ftpArgs="-R -T -v -u $ftpUser -p $ftpPass"
mysqlArgs="-h $mysqlHost -u $mysqlUser -p$mysqlPass"
ftpPath="$tmpPath/$ftpDir"
sqlPath="$tmpPath/$sqlFile"
compressedPath="$tmpDir/$compressedFile"
versionsPath="$tmpDir/$versionsFile"
selectionsPath="$tmpDir/$selectionsFile"
warning="0"
error="0"
settings="0"
}

warning_catch ()
{
if [[ $? -ne 0 ]]; then
        warning=$(($warning+1))
        shlog -s timestamp "\e[0;31mERROR!\e[0m - $1"
else
        shlog -s timestamp "\e[0;32mOK!\e[0m    - $2"
fi
}

error_catch ()
{
if [[ $? -ne 0 ]]; then
        error=$(($error+1))
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

dir_cleanup ()
{
if [[ $tarBackup -eq 1 ]]; then
        backupSize=$(ls -l --block-size=K | grep $compressedFile | awk '{print $5}' | sed 's/K$//')
else
        backupSize=$(du -s $dateStamp | awk '{print $1}')
fi
if [[ $backupSize -gt $2 ]]; then
	error=$(($error+1))
	shlog -s timestamp "\e[0;31mERROR!\e[0m - The total size of the backup is bigger than the destination directory ($1)"
else
	cd $1
        dirSpace=$(($2 - $(du -s | awk '{print $1}')))
        while [[ $backupSize -gt $dirSpace ]]; do
                shlog -s timestamp "\e[0;36mINFO\e[0m   - Backup size: ${backupSize}KB - Free space in the destination directory: ${dirSpace}KB"
                oldestBackup=$(ls -lt | awk '{print $9}'|tail -1)
                rm -rfv $oldestBackup
                dirSpace=$(($2 - $(du -s | awk '{print $1}')))
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
if [[ ${#sourceDir[*]} -ne 0 ]]; then
        shlog "Folders and files to copy: \e[0;32m${#sourceDir[*]}\e[0m"
        settings=$(($settings+1))
else
        shlog "Folders and files to copy: \e[0;31m${#sourceDir[*]}\e[0m"
fi
if [[ $backupFtp -eq 1 ]]; then
        shlog "FTP files backup: \e[0;32mYES\e[0m"
        settings=$(($settings+1))
else
        shlog "FTP files backup: \e[0;31mNO\e[0m"
fi
if [[ $backupMysql -eq 1 ]]; then
        shlog "MySQL database backup: \e[0;32mYES\e[0m"
        settings=$(($settings+1))
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
exit 1
}


case "$1" in
'start')
# Pass the second argument to the child function and print the current settings
backup_settings "$2"

mkdir -p "$tmpPath" || critical_exit "Unable to create the temporary directory!"

### Folders and files backup
for dir in ${!sourceDir[*]}
        do
        if [[ -e ${sourceDir[$dir]} ]]; then
                rsync $rsyncArgs "${sourceDir[$dir]}" "$tmpPath"
                warning_catch "The files backup process failed in '${sourceDir[$dir]}'. Check the file permissions." "'${sourceDir[$dir]}' copied successfully."
        else
                warning=$(($warning+1))
                shlog -s timestamp "\e[0;31mERROR!\e[0m - The files backup process failed in '${sourceDir[$dir]}'. Check if the file exists."
        fi
        if [[ $warning -ge ${#sourceDir[*]} ]]; then
                error=$(($error+1))
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
        if [[ $mysqlDb != "-A" ]]; then
                TMPVAR="The database '$mysqlDb' was copied successfully to '$sqlPath'."
        else
                TMPVAR="All the databases were copied successfully to '$sqlPath'."
        fi
        mysqldump $mysqlArgs $mysqlDb > "$sqlPath"
        error_catch "The MySQL database backup failed. Check the settings." "$TMPVAR"
fi

cd $tmpDir || critical_exit "Unable to change to the temporary directory!"

# Check if there are files to backup and act accordingly
if [[ $settings -ne 0 ]]; then
        # Compress the backup files and move to the destination or just move the folder
        if [[ $tarBackup -eq 1 ]]; then
                tar $tarArgs $dateStamp | 7za $compressorArgs $compressedFile 2>1 >/dev/null
                error_catch "Unable to create the 7z file in '$compressedPath'." "The 7z file was created successfully in '$compressedPath'."
                dir_cleanup "$backupDir" $maxDirSize
                mv $compressedFile "$backupDir"
                error_catch "Unable to move the compressed file to '$backupDir'." "The compressed file was moved successfully to '$backupDir'."
        else
                dir_cleanup "$backupDir" $maxDirSize
                mv $dateStamp "$backupDir"
                error_catch "Unable to move the backup folder to '$backupDir'." "The backup folder was moved successfully to '$backupDir'."
        fi
else
        rm -rf $dateStamp*
        critical_exit "There are no files to backup!"
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
		dir_cleanup "$extraBackupDir" $extraBackupDirSize
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
        rsync $rsyncArgsRootfs / "$cloneDir"
        warning_catch "The root filesystem cloning to '$cloneDir' ended with errors." "The root filesystem cloning to '$cloneDir' ended successfully."
        echo "Running "
        "$cloneDirScript"
fi

### Output final script report
shlog " "
if [[ $error -ne 0 ]]; then
        shlog -s datestamp "\e[0;31m$error error(S)\e[0m!  - The process finished with $error error(s)."
elif [[ $warning -ne 0 ]]; then
        shlog -s datestamp "\e[0;33m$warning warning(S)!\e[0m - The process finished with $warning warning(s)."
else
        shlog -s datestamp "\e[0;32mALL GOOD!\e[0m     - The process finished successfully."
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
        less -R $LOGPATH
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


*)
backup_help
;;
esac
exit 0
