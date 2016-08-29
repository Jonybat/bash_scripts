#!/bin/bash
#
. /opt/scripts/shlog.sh

shlog "1"

shlog -s timestamp
shlog -s datestamp
shlog -s weekstamp

shlog -s timestamp "time"
shlog -s datestamp "date"
shlog -s weekstamp "week"

shlog -p /home/ptins573/files/dev/bash_scripts/test/logs_alt/ "dir 1"
shlog -p alt.log "file 1"
shlog -p /home/ptins573/files/dev/bash_scripts/test/logs_alt/alt.log "path 1"

shlog "2"

LOGFILE=logfile.log

shlog "3"

LOGDIR=/home/ptins573/files/dev/bash_scripts/test/logs/

shlog "4"

LOGDIR=/home/ptins573/files/dev/bash_scripts/test/logs/logpath.log

shlog "5"

shlog -p /home/ptins573/files/dev/bash_scripts/test/logs_alt/ "dir 2"
shlog -p alt.log "file 2"
shlog -p /home/ptins573/files/dev/bash_scripts/test/logs_alt/alt.log "path 2
