#!/bin/bash
#
. /opt/scripts/shlog.sh
testLogDir=/opt/scripts/test

shlog "1"

shlog -s timestamp
shlog -s datestamp
shlog -s weekstamp

shlog -s timestamp "time"
shlog -s datestamp "date"
shlog -s weekstamp "week"

shlog -p $testLogDir/logs_alt/ "dir 1"
shlog -p alt.log "file 1"
shlog -p $testLogDir//logs_alt/alt.log "path 1"

shlog "2"

LOGFILE=logfile.log

shlog "3"

LOGDIR=$testLogDir/logs/

shlog "4"

LOGDIR=$testLogDir/logs/logpath.log

shlog "5"

shlog -p $testLogDir/logs_alt/ "dir 2"
shlog -p alt.log "file 2"
shlog -p $testLogDir/logs_alt/alt.log "path 2
