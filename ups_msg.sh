#!/bin/bash
#
### NUT upsmon NOTIFYCMD script

. /opt/scripts/shlog.sh
. /opt/scripts/pushbullet.sh
. /opt/scripts/.secrets

case $1 in
  *battery)
    msg="The server is now running on batteries (UPS)"
    notify=1
  ;;

  *power)
    msg="The power supply is back online (AC)"
    notify=1
  ;;

  *low)
    msg="The UPS battery level is low, the server will shutdown soon..."
    notify=1
  ;;

  *shutdown)
    msg="The UPS battery level is critical, the server will shutdown NOW!"
    notify=1
  ;;

  *)
    msg="$1"
    notify=0
  ;;
esac

shlog -s datestamp "$msg"

if [[ $notify -eq 1 ]]; then
  pushb "$msg"
  /opt/ta3scripts/ts3_messenger.sh "$TS3_SERVER" "$TS3_INSTANCE" "$msg"
fi

exit 0
