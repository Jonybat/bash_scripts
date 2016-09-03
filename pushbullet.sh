#!/bin/bash
#
### Pushbullet script interface to https://github.com/Red5d/pushbullet-bash
#
### To be sourced from other scripts
#
pushbulletBin=/opt/pushbullet/pushbullet

#Check if the script is being called directly and set invoker var accordingly
if [[ $0 == *bash ]]; then
	invoker="$(echo $USER)"
else
	invoker=$(echo $0 | sed 's/.*\///' | sed 's/.sh$//')
fi

pushb ()
{
$pushbulletBin push all note "[$invoker]" "$(date '+%H:%M') - $1"
}
