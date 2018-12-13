#!/bin/bash
#
### Creates bare git repos for git-http-backend
#
# Requires: git

. /opt/scripts/shlog.sh
. /opt/scripts/shuser.sh root

dataDir="/var/git/"
httpUser="www-data"

if [[ -z $1 ]]; then
  shlog -s datestamp "No repository name specified"
  exit 1
fi

repoName="$1.git"
shlog -s datestamp "Creating repository \'$repoName\'"
cd "$dataDir"
mkdir "$repoName"
cd "$repoName"
git init --bare --shared
cp hooks/post-update.sample hooks/post-update
git update-server-info
chown -R $httpUser: "$dataDir$repoName"

exit 0
