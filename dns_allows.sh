#!/bin/bash
#
### Resolve DNS entries for use with whitelists and Nginx

scriptDir=/opt/scripts/
in=${scriptDir}.dns_allows.conf
tmpPlain=/tmp/dns_allows_plain.tmp
tmpNginx=/tmp/dns_allows_nginx.tmp
outPlain=${scriptDir}.dns_allows.plain
outNginx=${scriptDir}.dns_allows.nginx

rm -f "$tmpNginx"

while read -r line; do
  if [[ -n $line ]]; then
    ip=$(getent ahosts $line | awk '{print $1; exit}')
    if [[ -n $ip ]]; then
      echo "$ip" >> "$tmpPlain"
      echo "allow $ip; # from $line" >> "$tmpNginx"
    fi
  fi
done < "$in"

if ! diff -q "$tmpPlain" "$outPlain"; then
	 mv -f "$tmpPlain" "$outPlain"
fi

if ! diff -q "$tmpNginx" "$outNginx"; then
	 mv -f "$tmpNginx" "$outNginx"
	 systemctl reload nginx
fi
