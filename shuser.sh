#!/bin/bash
#
### Shell script running user check
#
# Requires: shlog.sh
#
### To be sourced from other scripts

userID=$(id -u $1 2>/dev/null)
if [[ $? -eq 0 ]]; then
	if [[ $EUID -ne $userID ]]; then
		shlog -s datestamp "This script must be run as $1. Exiting..."
		exit 1
	fi
else
	shlog -s datestamp "The specified user is not valid. Exiting..."
	exit 2
fi
