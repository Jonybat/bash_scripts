#!/bin/bash
#
### rm replacement, moves files to trash dir
#
# Add alias rm="/path/to/script/rm_replacement.sh" to .bashrc or alike
#
# Based on a script found on the interwebz, cant find the source anymore

trash="$HOME/.trash/"

OPTIND=1
force=""
rmFlags=""
mvFlags=""

while getopts ":frRvh" args; do
	case "$args" in
		f)
			force=1 ;;
		r|R)
			rmFlags="$rmFlags -r" ;;
		v)
			rmFlags="$rmFlags -v"
			mvFlags="$mvFlags -v" ;;
		h)
			echo "You are running a replacement for rm called by an alias"
			echo "Usage rm [options] file1 file2 ..."
			echo ""
			echo "Moves files and directories to $trash"
			echo ""
			echo "Flags:"
			echo " -v           verbose mode"
			echo " -f           force processing with /bin/rm"
			echo " -r, -R       runs /bin/rm in recursive mode"
			echo " -h           this help message"
			echo ""
			exit 0 ;;
		\?)
			echo "Invalid argument: -$OPTARG" >&2
			exit 1 ;;
	esac
done

shift $((OPTIND-1))

for file in "$@"; do
	if [[ $force -eq 1 ]]; then
		/bin/rm -f $rmFlags "$file"
	else
		if [[ -e "$file" ]]; then
			if [[ -e "$trash$(basename $file)" ]]; then
				version=2
				while [[ -e "$trash$(basename $file)_$version" ]]; do
					let version=$version+1
				done
				mv $mvFlags "$trash$(basename $file)" "$trash$(basename $file)_$version"
			fi
				mv $mvFlags "$file" "$trash"
		fi
	fi
done
