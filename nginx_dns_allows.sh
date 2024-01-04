#!/bin/bash
#
### Resolve DNS entries for use with Nginx

scriptDir=/opt/scripts/
in=${scriptDir}.nginx_dns_allows.conf
tmp=/tmp/nginx_dns_allows.tmp
out=${scriptDir}.nginx_dns_allows.output

rm -f "$tmp"

while read -r line; do
  if [[ -n $line ]]; then
    ip=$(getent ahosts $line | awk '{print $1; exit}')
    if [[ -n $ip ]]; then
      echo "allow $ip; # from $line" >> "$tmp"
    fi
  fi
done < "$in"

if ! diff -q "$tmp" "$out"; then
	 mv -f "$tmp" "$out"
	 systemctl reload nginx
fi
