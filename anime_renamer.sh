#!/bin/bash
#
### Uses anidbcli to rename anime files according to anidb.net
# https://github.com/adameste/anidbcli

. /opt/scripts/shlog.sh
. /opt/scripts/.secrets

### Settings
bin="/opt/anidbcli/bin/anidbcli"
format="%a_romaji% - ep%ep_no% - %ep_english% - [%g_name%]"
args=(api -u "$ANIDB_USER" -p "$ANIDB_PASS" -k "$ANIDB_APIKEY" -t -sr "$format")
animeListFile="/var/tmp/anime_rename.txt"

### Main
# Define the internal field separator to CR and LF so that the animeList elements are full lines
IFS=$'\r\n'
animeList=( $(cat $animeListFile) )
# Restore the IFS to bash default (space)
IFS=$' '

# Check if animeList has contents before anything...
if [[ ${#animeList[@]} -eq 0 ]]; then
  shlog -s timestamp "No entries in file, nothing to do." -p nolog
  exit 1
fi

# Since it does, do what must be done
for line in ${!animeList[*]}; do
  # Move animeList line to tmp var to make code easier to read
  animeFullPath="${animeList[$line]}"
  # Escape \, /, & and [] because of sed
  animeFullPath_safe=$(echo $animeFullPath | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g' -e 's/\[/\\[/g' -e 's/\]/\\]/g')
  # Split the path in multiple vars for later use
  animePath=$(echo $animeFullPath | grep -Eo '/.*/')
  animeFile=$(basename "`echo $animeFullPath`")
  animeSub="$(echo $animeFile | cut -d. -f -1).srt"
  animeDir=$(echo $animePath | rev | cut -d\/ -f 2 | rev)
  animeName=$(echo $animeFullPath | grep -Po '[^/]*(?= - ep.*)')

  # Check if file exists or not, to avoid errors from the program and get more accurate condition checks later on
  if [[ -e "$animeFullPath" ]]; then
    # Extratct subtitles file if it doesnt exist
    if [[ ! -f "$animePath$animeSub" ]]; then
      shlog -s datestamp "Extracting subtitle: $animePath$animeSub"
      ffmpeg -loglevel fatal -hide_banner -i "$animeFullPath" "$animePath$animeSub"
    fi
    shlog -s datestamp "Renaming: $animeFullPath"
    # Call the program to rename the file, args have to be expanded like this otherwise bash shell expansion will break program input
    result=$($bin "${args[@]}" "$animeFullPath" 2>&1)

    if [[ $(echo $result | grep -i "file renamed") ]]; then
      # Get the name and path after renaming
      newFullPath=$(echo $result | grep -Ei "file renamed.*\.(mkv|mp4|avi)" | cut -d\" -f 2)
      newFile=$(basename "`echo $newFullPath`")
      newSub="$(echo $newFile | cut -d. -f -1).srt"
      newName=$(echo $newFullPath | grep -Po '[^/]*(?= - ep.*)')
      finalFullPath=$(echo $newFullPath | sed "s/$animeDir/$newName/g")
      finalFullPath_safe=$(echo $finalFullPath | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g' -e 's/\[/\\[/g' -e 's/\]/\\]/g')

      # Try to move sub file
      shlog -s timestamp "DEBUG: Moving $animePath$animeSub to $animePath$newSub"
      mv "$animePath$animeSub" "$animePath$newSub"
      # Do some filename checks
      if [[ $(echo $newFullPath | grep -E "[e,E]pisode|[u,U]nknown") ]]; then
	# Episode name contains the word episode or unknown, so it was (probably) not renamed properly
	shlog -s timestamp "File was not renamed properly! Episode probably does not have a name yet on aniDB."
	# Replace the old path with the new so it will go back in the list to be renamed
	shlog -s timestamp "DEBUG: Sed s/$animeFullPath_safe/$finalFullPath_safe/g from $animeListFile"
	sed -i "s/$animeFullPath_safe/$finalFullPath_safe/g" "$animeListFile"
      else
        # File renamed successfully
	shlog -s timestamp "File renamed successfully to $newFullPath."
	shlog -s timestamp "DEBUG: Sed /$animeFullPath_safe/d from $animeListFile"
	sed -i "/$animeFullPath_safe/d" "$animeListFile"
      fi
      # Check if anime name has changed and if so move to the new directory
      if [[ "$newName" != "$animeDir" ]]; then
	newPath=$(echo $animePath | sed "s/$animeDir/$newName/g")
	shlog -s timestamp "Anime name does not match directory. Moving to $newPath"
	mkdir -p "$newPath"
	shlog -s timestamp "DEBUG: Moving $newFullPath to $newPath"
        shlog -s timestamp "DEBUG: Moving $animePath$newSub to $newPath"
	mv "$newFullPath" "$newPath"
        mv "$animePath$newSub" "$newPath"
	# Try removing the old directory, will fail if not empty
	rmdir "$animePath"
      fi
    elif [[ $(echo $result | grep -Ei "connect|timeout") ]]; then
      # API timeout
      shlog -s timestamp "API timeout, cannot continue"
      exit 2
    elif [[ $(echo $result | grep -i "banned") ]]; then
      # API ban
      shlog -s timestamp "API ban, cannot continue"
      exit 2
    elif [[ $(echo $result | grep -i "failed to get file") ]]; then
      # File does not exist in aniDB
      shlog -s timestamp "File does not exist in aniDB (yet?)." # to: $newName"
    elif [[ $(echo $result | grep -i "failed to rename") ]]; then
      # Failed to rename file
      shlog -s timestamp "Failed to rename file. Check file permissions."
    elif [[ $(echo $result | grep -i "does not exist") ]]; then
      # File does not exist in fs, remove it from the list file, just in case something went wrong with the first check
      shlog -s timestamp "File does not exist, removing entry: $animeFullPath"
      sed -i "/$animeFullPath_safe/d" "$animeListFile"
    fi
  else
    # File does not exist in fs, remove it from the list file
    shlog -s datestamp "File does not exist, removing entry: $animeFullPath"
    sed -i "/$animeFullPath_safe/d" "$animeListFile"
  fi
done
exit 0
