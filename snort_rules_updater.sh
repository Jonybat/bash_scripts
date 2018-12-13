#!/bin/bash
#
### Snort rules updater
#
# Requires: wget, tar

. /opt/scripts/shlog.sh
. /opt/scripts/shuser.sh root
. /opt/scripts/.secrets

snortRules=$(wget -qO- https://www.snort.org | grep -o "snortrules-snapshot-[0-9]*.tar.gz" | head -n 1)
snortVersion=$(echo $snortRules | sed 's/[^0-9]//g')
fileName="snortrules-snapshot-$snortVersion.tar.gz"
rulesUrl="www.snort.org/rules/$fileName?oinkcode=$SNORT_OINKCODE"
tmpDir="/tmp/snort_rules/"
snortDir="/etc/snort/"
versionFile="rules.version"
currentRules=$(cat "$snortDir$versionFile")
currentVersion=$(echo $currentRules | sed 's/[^0-9]//g')

### Main
if [[ "$fileName" != "$currentRules" ]]; then
  shlog -s datestamp "Current version ($currentVersion) does not match online version ($snortVersion). Updating"
  # Create temp working dir
  mkdir "$tmpDir"
  cd "$tmpDir"
  # Download rules file and extract it
  wget -O "$fileName" "$rulesUrl"
  tar -xzf "$fileName"
  # Copy rules to snort directory
  cp -R preproc_rules/ "$snortDir"
  cp -R rules/ "$snortDir"
  cp -R so_rules/ "$snortDir"
  cp etc/classification.config "$snortDir"
  cp etc/unicode.map "$snortDir"
  cp etc/sid-msg.map "$snortDir"
  # Remove temp dir
  rm -rf "$tmpDir"
  # Update current rules version file
  echo "$fileName" > "$snortDir$versionFile"
  # Restart snort
  systemctl restart snort
  if [[ $? -eq 0 ]]; then
    shlog -s timestamp "Rules updated and snort started successfully"
  else
    shlog -s timestamp "Snort failed to start, some new rules might be incompatible. Need manual intervention"
  fi
else
  shlog -s datestamp "Rules are already up to date" -p nolog
fi

exit 0
