#!/bin/bash
#
. /opt/scripts/shlog.sh
testDir=/opt/scripts/test

shlog "default/test.log (1)"

shlog -s timestamp
shlog -s datestamp
shlog -s weekstamp

shlog -s timestamp "time"
shlog -s datestamp "date"
shlog -s weekstamp "week"

shlog -p $testDir/logs_alt/ "logs_alt/test.log (1)"
shlog -p alt.log "default/alt.log (1)"
shlog -p $testDir/logs_alt/alt.log "logs_alt/alt.log (1)"

shlog "default/test.log (2)"

LOGFILE=logfile.log

shlog "default/logfile.log"

LOGDIR=$testDir/log/

shlog "default/logdir.log"

LOGDIR=$testDir/log/logpath.log

shlog "default/logpath.log"

shlog -p $testDir/logs_alt/ "logs_alt/test.log (2)"
shlog -p alt.log "default/alt.log (2)"
shlog -p $testDir/logs_alt/alt.log "logs_alt/alt.log (2)"

echo "
----------
"
grep -qo "default/test.log (1)" $testDir/log/test.log 2>/dev/null && echo "default/test.log (1) OK" || echo "default/test.log (1) Failed"
grep -qo "logs_alt/test.log (1)" $testDir/logs_alt/test.log 2>/dev/null && echo "logs_alt/test.log (1) OK" || echo "logs_alt/test.log (1) Failed"
grep -qo "default/alt.log (1)" $testDir/log/alt.log 2>/dev/null && echo "default/alt.log (1) OK" || echo "default/alt.log (1) Failed"
grep -qo "logs_alt/alt.log (1)" $testDir/logs_alt/alt.log 2>/dev/null && echo "logs_alt/alt.log (1) OK" || echo "logs_alt/alt.log (1) Failed"
grep -qo "default/test.log (2)" $testDir/log/test.log 2>/dev/null && echo "default/test.log (2) OK" || echo "default/test.log (2) Failed"
grep -qo "default/logfile.log" $testDir/log/logfile.log 2>/dev/null && echo "default/logfile.log OK" || echo "default/logfile.log Failed"
grep -qo "default/logdir.log" $testDir/log/logdir.log 2>/dev/null && echo "default/logdir.log OK" || echo "default/logdir.log Failed"
grep -qo "default/logpath.log" $testDir/log/logpath.log 2>/dev/null && echo "default/logpath.log OK" || echo "default/logpath.log Failed"
grep -qo "logs_alt/test.log (2)" $testDir/logs_alt/test.log 2>/dev/null && echo "logs_alt/test.log (2) OK" || echo "logs_alt/test.log (2) Failed"
grep -qo "default/alt.log (2)" $testDir/log/alt.log 2>/dev/null && echo "default/alt.log (2) OK" || echo "default/alt.log (2) Failed"
grep -qo "logs_alt/alt.log (2)" $testDir/logs_alt/alt.log 2>/dev/null && echo "logs_alt/alt.log (2) OK" || echo "logs_alt/alt.log (2) Failed"
