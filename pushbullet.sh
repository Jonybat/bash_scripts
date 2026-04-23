#!/bin/bash
#
### Pushbullet script interface to https://github.com/Red5d/pushbullet-bash
#
### To be sourced from other scripts

pushbulletBin=/opt/pushbullet-bash/pushbullet

# Check if the script is being called directly and set invoker var accordingly
if [[ $0 == *bash ]]; then
  if tty -s 2>/dev/null; then
    INVOKER="${USER:-$(id -un)}"
  else
    INVOKER="cron"
  fi
else
  INVOKER="$(basename "$0" .sh)"
fi

pushb ()
{
$pushbulletBin push all note "[${INVOKER}@$(hostname)]" "$(date '+%H:%M') - $1"
}
