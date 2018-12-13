#!/bin/bash
#
### Dynamic DNS updater for namecheap
#
# Requires: wget, dig

. /opt/scripts/shlog.sh
. /opt/scripts/pushbullet.sh
. /opt/scripts/.secrets

### Basic Settings
updateAttempts=3
resolveAttempts=3
delay=10
error=0

updateURL="https://dynamicdns.park-your-domain.com/update?host=$NAMECHEAP_HOST&domain=$NAMECHEAP_DOMAIN&password=$NAMECHEAP_PASSWORD"
updateResult="/var/tmp/dns_update_result.txt"

# @ means self in namecheap
if [[ "$NAMECHEAP_HOST" == @ ]]; then
  dns="$NAMECHEAP_DOMAIN"
else
  dns="$NAMECHEAP_HOST.$NAMECHEAP_DOMAIN"
fi

dns_resolver ()
{
while [[ $resolveAttempts -gt 0 ]]; do
  # Get current IP, catches any string in ip format: 0.123.456.789
  currentIP=$(wget -q -O - http://v4.ipv6-test.com/api/myip.php | grep -o '\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}')
  # Get old FreeDNS dynamic IP (Main server)
  dnsIP=$(dig +noall +short $dns @1.1.1.1 | grep -o '\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}')
  # Check if any of the resolutions failed
  if [[ $currentIP == "" || $dnsIP == "" ]]; then 
  	resolveAttempts=$((resolveAttempts-1))
  else
  	break
  fi
done
# If the previous test failed all the times defined, the script will exit. This safeguards for internet connectivity and for any failed dns result
if [[ $resolveAttempts -eq 0 ]]; then
  shlog -s datestamp "Failed to resolve at least one of the DNS IPs in all the attempts. Exiting"
  exit 1
fi
}

dns_updater ()
{
rm -f "$updateResult"
wget -q -O "$updateResult" "$updateURL"

updateStatus=$(grep -Po "ErrCount>\K([0-9]+)" "$updateResult")
updateError=$(grep -Po "Err1>\K(.*)" "$updateResult" | cut -d"<" -f 1)
updateAttempts=$((updateAttempts-1))
}

### Main
dns_resolver

# Actual check
if [[ $currentIP == $dnsIP ]]; then
  shlog -s datestamp "Current IP [$currentIP] == [$dnsIP] $dns (DNS)" -p nolog
else
  shlog -s datestamp "Current IP [$currentIP] != [$dnsIP] $dns (DNS) - Updating"
  # Update the DNS
  tmp=$updateAttempts
  while [[ $updateAttempts -gt 0 ]]; do
    # Add some delay to the retries
    if [[ $updateAttempts -ne $tmp ]]; then
      sleep $delay
    fi
    # Update the DNS
    dns_updater
    # Check if it was successful this time
    if [[ $updateStatus -eq 0 ]]; then
      shlog -s datestamp "Updated successfully"
      break
    elif [[ $updateAttempts -gt 0 ]]; then
      shlog -s datestamp "Update failed with: "$updateError", retrying"
      pushb "Update failed with: "$updateError", retrying"
    fi
  done
  # If the update failed all the attempts defined, set error var to exit script with code 2
  if [[ $updateAttempts -eq 0 ]]; then
    shlog -s datestamp "Failed to update DNS record of $dns after all the attempts, giving up"
    pushb "Failed to update DNS record of $dns after all the attempts, giving up"
    error=2
  fi
fi

if [[ $error -eq 0 ]]; then
  exit 0
else
  shlog -s datestamp "Script failed with error $error"
  exit $error
fi
