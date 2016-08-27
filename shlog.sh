#!/bin/bash
#
### Shell script logger
#
# Requires: tee
#
### To be sourced from other scripts
# Defines and uses the following variables globally, can be set by parent script
# LOGDIR, LOGFILE, LOGPATH
#
### Settings
customLogDir="/var/log/scripts/"

### Define the LOGPATH variable
shlog_main ()
{
# Default log directory is the script dir. If set by parent script, unset LOGPATH to allow this script to construct it
if [[ -z "$LOGDIR" ]]; then
	if [[ -z "$customLogDir" ]]; then
		relativeLogDir=$(dirname "$0")
		LOGDIR=$(cd "$relativeLogDir" && pwd)
	else
		LOGDIR="$customLogDir"
	fi
else
	unset LOGPATH
fi

# Check if LOGDIR doesnt exist and try to create it. Check if it exists and that it is a directory and writable
if [[ ! -e "$LOGDIR" ]]; then
	mkdir -p "$LOGDIR"
	if [[ $? -ne 0 ]]; then
		echo "ERROR! - LOGDIR ($LOGDIR) does not exist and can not be created. Exiting..."
		exit 1
	fi
elif [[ ! -d "$LOGDIR" ]]; then
	echo "ERROR! - LOGDIR ($LOGDIR) exists but is not a directory. Exiting..."
	exit 1
elif [[ ! -w "$LOGDIR" ]]; then
	echo "ERROR! - LOGDIR ($LOGDIR) exists but is not writable. Exiting..."
	exit 1
fi

# Check if LOGDIR has a leading slash and add it if it doesnt
if [[ ! "$LOGDIR" =~ /$ ]]; then
	LOGDIR="$LOGDIR"/
fi

# If not set by the parent script, get its name, filter the path and replace extension with .log, if it has one
if [[ -z "$LOGFILE" ]]; then
	if [[ "$0" =~ \.sh ]]; then
		LOGFILE=$(echo "$0" | sed 's/.*\///' | sed 's/sh$/log/')
	else
		LOGFILE=$(echo "$0" | sed 's/.*\///').log
	fi
else
	unset LOGPATH
fi

# Set LOGPATH if not set by the parent script
if [[ -z "$LOGPATH" ]]; then
	if [[ -z "$shlogTmpPath" ]]; then
		LOGPATH="$LOGDIR$LOGFILE"
	# nolog option
	elif [[ "$shlogTmpPath" == "nolog" ]]; then
		LOGPATH="/dev/null"
	# Input is the full path
	elif [[ "$shlogTmpPath" =~ \/([^/]+\/)+[^/]+\.[^/]{1,3} ]]; then
		LOGPATH="$shlogTmpPath"
	# Input is a dir, append default filename
	elif [[ "$shlogTmpPath" =~ \/([^/]+\/)+ ]]; then
	#elif [[ -d "$shlogTmpPath" ]]; then
		LOGPATH="$shlogTmpPath$LOGFILE"
	# Input is a filename, append default dir
	elif [[ "$shlogTmpPath" =~ [^/]+\.[^/]{1,3} ]]; then
	#elif [[ -f "$shlogTmpPath" ]]; then
		LOGPATH="$LOGDIR$shlogTmpPath"
	# Safeguard
	else
		LOGPATH="$LOGDIR$LOGFILE"
	fi
else
	echo "LOGPATH was set by main script. DEBUG: $LOGPATH"
fi
}

shlog_help (){
if [[ $# -eq 0 ]]; then
	echo "Usage: shlog [-p|--path=nolog|/alternative/path/alternative.log] [-s|--stamp=timestamp|datestamp|weekstamp] \"text\"|\"\$(cmd)\""
	exit 1
fi
}


### First run to make the LOGPATH variable available to the parent script
shlog_main


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

# Check/Set LOGPATH variable
shlog_main

# Do the thing
if [[ -n $shlogTmpText ]]; then
	if [[ $shlogTmpStamp == "timestamp" ]]; then
		echo -e "$(date '+%H:%M:%S')" - "$shlogTmpText" | tee -a "$LOGPATH"
	elif [[ $shlogTmpStamp == "datestamp" ]]; then
		echo -e "$(date '+%Y-%m-%d %H:%M:%S')" - "$shlogTmpText" | tee -a "$LOGPATH"
	elif [[ $shlogTmpStamp == "weekstamp" ]]; then
		echo -e "$(date '+%H:%M:%S %d-%m-%Y %a %V')" - "$shlogTmpText" | tee -a "$LOGPATH"
	else
		echo -e "$shlogTmpText" | tee -a "$LOGPATH"
	fi
else
	if [[ $shlogTmpStamp == "timestamp" ]]; then
		echo -e "$(date '+%H:%M:%S')" | tee -a "$LOGPATH"
	elif [[ $shlogTmpStamp == "datestamp" ]]; then
		echo -e "$(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOGPATH"
	elif [[ $shlogTmpStamp == "weekstamp" ]]; then
		echo -e "$(date '+%H:%M:%S %d-%m-%Y %a %V')" | tee -a "$LOGPATH"
	fi
fi
}


### Throw warning if run from a shell
if [[ $0 =~ .*shlog ]]; then
	echo "This script can only executed as a source from within another script!"
	echo "To source it just add an entry in the script like: '. /path/to/shlog.sh'"
	echo ""
	shlog_help
fi
