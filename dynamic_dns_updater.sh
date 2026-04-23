#!/bin/bash
#
### Dynamic DNS updater for cloudflare
#
# Requires: curl, dig, jq

. /opt/scripts/shlog.sh
. /opt/scripts/pushbullet.sh
. /opt/scripts/.secrets

### Basic Settings
updateAttempts=3
resolveAttempts=3
delay=10
error=0

dns="$DNS_RECORD"

dns_resolver ()
{
while [[ $resolveAttempts -gt 0 ]]; do
  # Get current IP, catches any string in ip format: 0.123.456.789
  currentIP=$(curl --max-time 10 -s -4 ifconfig.me/ip | grep -o '\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}')
  # Get IP of DNS record
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
# TTL=1 means auto
result=$(curl --max-time 10 -s https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$CLOUDFLARE_DNS_RECORD_ID \
    -X PUT \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -d '{
          "name": "'"$dns"'",
          "ttl": 1,
          "type": "A",
          "comment": "Dynamic DNS updater",
          "content": "'"$currentIP"'",
          "private_routing": '"$CLOUDFLARE_PRIVATE_ROUTING"',
          "proxied": '"$CLOUDFLARE_PROXIED_DNS"'
        }')

updateSuccess=$(echo "$result" | jq '.success')
updateError=$(echo "$result" | jq -r '.errors[].message')
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
    if [[ $updateSuccess == 'true' ]]; then
      shlog -s datestamp "Updated successfully"
      break
    else
      shlog -s datestamp "Update failed with: $updateError, retrying"
      pushb "Update failed with: $updateError, retrying"
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
