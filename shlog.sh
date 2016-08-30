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

shlog_validate_dir ()
{
# Check if dir doesnt exist and try to create it. Check if it exists and that it is a directory and writable
if [[ ! -e "$1" ]]; then
	mkdir -p "$1"
	if [[ $? -ne 0 ]]; then
		echo "ERROR! - LOGDIR ($1) does not exist and can not be created. Exiting..."
		exit 1
	fi
elif [[ ! -d "$1" ]]; then
	echo "ERROR! - LOGDIR ($1) exists but is not a directory. Exiting..."
	exit 1
elif [[ ! -w "$1" ]]; then
	echo "ERROR! - LOGDIR ($1) exists but is not writable. Exiting..."
	exit 1
fi

# Check if dir has a leading slash and add it if it doesnt
if [[ ! "$1" =~ /$ ]]; then
	LOGDIR="$1"/
else
	LOGDIR="$1"
fi
}


shlog_logdir ()
{
# Default log directory is the script dir. If set by parent script, unset LOGPATH to allow this script to build it
if [[ -z "$LOGDIR" ]]; then
	if [[ -z "$globalLogDir" ]]; then
		relativeLogDir=$(dirname "$0")
		LOGDIR=$(cd "$relativeLogDir" && pwd)
	else
		LOGDIR="$globalLogDir"
	fi
else
	unset LOGPATH
fi
}

shlog_logfile ()
{
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
}


### Define the LOGPATH variable
shlog_vars ()
{
# Store variables and restore them after -p run
LOGPATH_ORIG="$LOGPATH"
LOGDIR_ORIG="$LOGDIR"
LOGFILE_ORIG="$LOGFILE"

# -p flag set
if [[ -n "$shlogTmpPath" ]]; then
	# Control variable to know if we need to restore global vars after -p run
	shlogAltVars="1"

	# nolog option
	if [[ "$shlogTmpPath" == "nolog" ]]; then
		LOGPATH="/dev/null"

	# Input is the full path
	elif [[ "$shlogTmpPath" =~ \/([^/]+\/)+[^/]+\.[^/]{1,3} ]]; then
		LOGPATH="$shlogTmpPath"

		# TODO: Validate shlogTmpPath (as full path)

	# Input is a dir, append default filename
	elif [[ "$shlogTmpPath" =~ \/([^/]+\/)+ ]]; then
		# Validate and populate $LOGDIR
		shlog_validate_dir "$shlogTmpPath"

		# Populate $LOGFILE
		shlog_logfile

		LOGPATH="$LOGDIR$LOGFILE"

	# Input is a filename, append default dir
	elif [[ "$shlogTmpPath" =~ [^/]+\.[^/]{1,3} ]]; then
		# Populate $LOGDIR
		shlog_logdir
		shlog_validate_dir "$LOGDIR"

		LOGPATH="$LOGDIR$shlogTmpPath"

	fi

	# TODO: Needed?
	unset shlogTmpPath

# $LOGPATH not defined
elif [[ -z "$LOGPATH" ]]; then
	# Get $LOGDIR and $LOGFILE
	shlog_logdir
	shlog_validate_dir "$LOGDIR"

	shlog_logfile

	LOGPATH="$LOGDIR$LOGFILE"

else
	echo "$LOGPATH"
fi

# TODO: Validate $LOGPATH

}


shlog_restore_vars ()
{
# Store variables and restore them after -p run
LOGPATH="$LOGPATH_ORIG"
LOGDIR="$LOGDIR_ORIG"
LOGFILE="$LOGFILE_ORIG"
shlogAltVars="0"
}


shlog_help ()
{
# Check if no arguments were given and print usage message
if [[ $# -eq 0 ]]; then
	echo "Usage: shlog [-p|--path=nolog|/alternative/path/alternative.log] [-s|--stamp=timestamp|datestamp|weekstamp] \"text\"|\"\$(cmd)\""
	exit 1
fi

# TODO: Check if global vars have been set after the first run of shlog_vars

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

		# Check/Set LOGPATH variable
		shlog_vars

		shift 2
	;;
	*)
		local shlogTmpText="$1"
		shift
	;;
esac
done

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

if [[ $shlogAltVars -eq 1 ]]; then
	shlog_restore_vars
fi
}

### Throw warning if run from a shell
if [[ $0 =~ .*shlog ]]; then
	echo "This script can only executed as a source from within another script!"
	echo "To source it just add an entry in the script like: '. /path/to/shlog.sh'"
	echo ""
	shlog_help
fi
