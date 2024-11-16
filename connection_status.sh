#!/bin/bash
#
### Network connectivity checker and script trigger
#
# Requires: ping, dig

. /opt/scripts/shlog.sh
. /opt/scripts/shlock.sh
. /opt/scripts/pushbullet.sh

### IP Settings
gatewayIP=$(ip route list|grep "default via"|awk '{print $3}')
internetDNS="google.com"
internetIP="8.8.8.8"

### Post check scripts
dyndnsScript="/opt/scripts/dynamic_dns_updater.sh"
postScript="/opt/scripts/post_check_scripts.sh"

run_scripts (){
shlog -s timestamp "Running dynamic DNS updater" -p nolog
bash "$dyndnsScript"
if [ $? -eq 0 ]; then
  shlog -s timestamp "Running post check scripts" -p nolog
  bash "$postScript"
else
  shlog -s datestamp "The DNS updater script exited with code $?. Not running post check scripts"
fi
}

check_dns (){
# Check DNS IP
dig +noall +short +time=1 +tries=1 +retry=1 $internetDNS 2>&1 >/dev/null
if [ $? -ne 0 ]; then
  # Check again, since it failed
  dig +noall +short $internetDNS 2>&1 >/dev/null
  if [ $? -ne 0 ]; then
    shlog -s datestamp "DNS check: $internetDNS - DOWN"
    dnsStatus="0"
  else
    shlog -s datestamp "DNS check: $internetDNS - UP?"
    dnsStatus="1"
  fi
else
  shlog -s datestamp "DNS check: $internetDNS - UP" -p nolog
  dnsStatus="1"
fi
}

check_internet (){
# Check Google IP
ping -c 1 $internetIP 2>&1 >/dev/null
if [ $? -ne 0 ]; then
  # Check again, since it failed
  ping -c 10 $internetIP 2>&1 >/dev/null
  if [ $? -ne 0 ]; then
    shlog -s datestamp "IP check: $internetIP - DOWN"
    internetStatus="0"
  else
    shlog -s datestamp "IP check: $internetIP - UP?"
    internetStatus="1"
  fi
else
  shlog -s datestamp "IP check: $internetIP - UP" -p nolog
  internetStatus="1"
fi
}

### Main
# Check Gateway IP
ping -c 1 $gatewayIP 2>&1 >/dev/null
if [ $? -ne 0 ]; then
  shlog -s datestamp "Gateway IP: $gatewayIP - DOWN"
  remove_lock
  exit 1
else
  shlog -s datestamp "Gateway IP: $gatewayIP - UP" -p nolog
  check_dns
  check_internet
  # Compare both checks and act accordingly
  if [ $dnsStatus -eq 0 ] && [ $internetStatus -eq 0 ]; then
    shlog -s timestamp "Both DNS resolution and Internet IP are down in the main gateway, exiting..."
    # Very unlikely that this will go through but try it anyway
    pushb "Both DNS resolution and Internet IP are down in the main gateway. Not doing anything!"
    remove_lock
    exit 2
  elif [ $dnsStatus -eq 0 ] && [ $internetStatus -eq 1 ]; then
    shlog -s timestamp "DNS resolution is down but Internet IP is up. DNS resolution might fail, trying anyway..."
    run_scripts
  else
    shlog -s timestamp "Both DNS and Internet IPs are up in the main gateway" -p nolog
    run_scripts
  fi
fi

remove_lock
exit 0
