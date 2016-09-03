#!/bin/bash
#
### Shell script logger
#
# Requires: tee
#
### To be sourced from other scripts
# Defines and uses the following variables globally: LOGDIR, LOGFILE, LOGPATH
# These variables can be set by parent script or can be defined with the shlog_vars function
#
### Can change this variable to set a default global directory. Can still be overridden by the global variables
globalLogDir="/var/log/scripts/"


shlog_check_dir ()
{
# Check if dir doesnt exist and try to create it. Check if it exists and that it is a directory and writable
if [[ ! -e "$1" ]]; then
	mkdir -p "$1" 2>/dev/null
	if [[ $? -ne 0 ]]; then
		echo "ERROR! - shlogDir ($1) does not exist and can not be created. Exiting..."
		exit 1
	fi
elif [[ ! -d "$1" ]]; then
	echo "ERROR! - shlogDir ($1) exists but is not a directory. Exiting..."
	exit 1
elif [[ ! -w "$1" ]]; then
	echo "ERROR! - shlogDir ($1) exists but is not writable. Exiting..."
	exit 1
fi
}

shlog_check_path ()
{
# Try to create the file or if it exists, check it it is writable
if [[ ! -e "$1" ]]; then
	touch "$1" 2>/dev/null
	if [[ $? -ne 0 ]]; then
		# Check if we have access to the dir or if we can create it
		shlog_check_dir "$(echo "$1" | grep -Eo '\/([^/]+\/)+')"
		# If we are still here, try to create it again
		touch "$1" 2>/dev/null
		if [[ $? -ne 0 ]]; then
			echo "ERROR! - shlogPath ($1) does not exist and can not be created. Exiting..."
			exit 1
		fi
	fi
elif [[ ! -w "$1" ]]; then
        echo "ERROR! - shlogPath ($1) exists but is not writable. Exiting..."
        exit 1
fi
}

shlog_validate_dir ()
{
# Check if dir has a leading slash and add it if it doesnt
if [[ ! "$1" =~ /$ ]]; then
	shlogDir="$1"/
else
	shlogDir="$1"
fi
}

shlog_logdir ()
{
# If LOGDIR has not been set by the parent script, check if the globalLogDir has been set in this script. If neither applies, set shlogDir based on the script dir
if [[ -z "$LOGDIR" ]]; then
	if [[ -z "$globalLogDir" ]]; then
		local relativeLogDir=$(dirname "$0")
		shlogDir=$(cd "$relativeLogDir" && pwd)
	else
		shlogDir="$globalLogDir"
	fi
else
	shlogDir="$LOGDIR"
fi
}

shlog_logfile ()
{
# If LOGFILE has not been set by the parent script, get its name, filter the path and replace extension with .log, if it has one
if [[ -z "$LOGFILE" ]]; then
	if [[ "$0" =~ \.sh ]]; then
		shlogFile=$(echo "$0" | sed 's/.*\///' | sed 's/sh$/log/')
	else
		shlogFile=$(echo "$0" | sed 's/.*\///').log
	fi
else
	shlogFile="$LOGFILE"
fi
}

shlog_vars ()
{
# -p flag set
if [[ -n "$shlogTmpPath" ]]; then
	# nolog option
	if [[ "$shlogTmpPath" == "nolog" ]]; then
		shlogPath="/dev/null"

	# Input is the full path
	elif [[ "$shlogTmpPath" =~ \/([^/]+\/)+[^/]+\.[^/]{1,3} ]]; then
		shlogPath="$shlogTmpPath"

	# Input is a dir, append default filename
	elif [[ "$shlogTmpPath" =~ \/([^/]+\/)+ ]]; then
		# Validate and populate shlogDir
		shlog_validate_dir "$shlogTmpPath"
		# Populate shlogFile
		shlog_logfile
		shlogPath="$shlogDir$shlogFile"

	# Input is a filename, append default dir
	elif [[ "$shlogTmpPath" =~ [^/]+\.[^/]{1,3} ]]; then
		# Populate shlogDir
		shlog_logdir
		shlog_validate_dir "$shlogDir"
		shlogPath="$shlogDir$shlogTmpPath"
	fi
	# Unset var to avoid running unnecessary tests when -p flag was not set
	unset shlogTmpPath

# LOGPATH not defined, build it based on LOGDIR and LOGFILE
elif [[ -z "$LOGPATH" ]]; then
	# Get shlogDir and shlogFile
	shlog_logdir
	shlog_validate_dir "$shlogDir"
	shlog_logfile
	shlogPath="$shlogDir$shlogFile"

# LOGPATH is set
else
	shlogPath="$LOGPATH"
fi

# Validate shlogPath
shlog_check_path "$shlogPath"
}

shlog_global_vars ()
{
case "$1" in
	-s|--set)
                shlog_vars
                LOGDIR="$shlogDir"
                LOGFILE="$shlogFile"
                LOGPATH="$shlogPath"
	;;
        -u|--unset)
                LOGDIR=""
                LOGFILE=""
                LOGPATH=""
	;;
esac
}

shlog_help ()
{
# Check if no arguments were given and print usage message
if [[ $# -eq 0 ]]; then
	echo "Usage: shlog [-p|--path=nolog|/alternative/path/alternative.log] [-s|--stamp=timestamp|datestamp|weekstamp] \"text\"|\"\$(cmd)\""
	exit 1
fi
}


### Main function
shlog ()
{
# Put the arguments in variables
while [[ $# -gt 0 ]]; do
case "$1" in
	-s|--stamp)
		local shlogTmpStamp="$2"
		shift 2
	;;
	-p|--path)
		local shlogTmpPath="$2"
		shift 2
	;;
	*)
		local shlogTmpText="$1"
		shift
	;;
esac
done

# Set shlogPath variable
shlog_vars

# Do the thing
if [[ -n $shlogTmpText ]]; then
	if [[ $shlogTmpStamp == "timestamp" ]]; then
		echo -e "$(date '+%H:%M:%S')" - "$shlogTmpText" | tee -a "$shlogPath"
	elif [[ $shlogTmpStamp == "datestamp" ]]; then
		echo -e "$(date '+%Y-%m-%d %H:%M:%S')" - "$shlogTmpText" | tee -a "$shlogPath"
	elif [[ $shlogTmpStamp == "weekstamp" ]]; then
		echo -e "$(date '+%H:%M:%S %d-%m-%Y %a %V')" - "$shlogTmpText" | tee -a "$shlogPath"
	else
		echo -e "$shlogTmpText" | tee -a "$shlogPath"
	fi
else
	if [[ $shlogTmpStamp == "timestamp" ]]; then
		echo -e "$(date '+%H:%M:%S')" | tee -a "$shlogPath"
	elif [[ $shlogTmpStamp == "datestamp" ]]; then
		echo -e "$(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$shlogPath"
	elif [[ $shlogTmpStamp == "weekstamp" ]]; then
		echo -e "$(date '+%H:%M:%S %d-%m-%Y %a %V')" | tee -a "$shlogPath"
	fi
fi

unset shlogPath
unset shlogDir
unset shlogFile
}


### Throw warning if run from a shell
if [[ $0 =~ .*shlog ]]; then
	echo "This script can only executed as a source from within another script!"
	echo "To source it just add an entry in the script like: '. /path/to/shlog.sh'"
	echo ""
	shlog_help
fi
