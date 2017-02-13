#!/bin/sh
#
### Zabbix sender implementation in bourne shell
#
# Requires: nc

usage() {
echo -n "Usage:
  zabbix_sender.sh -z server [-p port] -s host -k key -o value
  zabbix_sender.sh -z server [-p port] -i input-file"
exit 1
}

# Check if nc is available
if ! which nc >/dev/null; then
  echo "nc is not avaiable, cannot continue"
  exit 1
fi

# Check first if any arguments were provided
if [ $# -eq 0 ]; then
  usage
fi

# Put the arguments in variables
while [ $# -gt 0 ]; do
case "$1" in
  -z|--zabbix-server)
    serverHost="$2"
    shift 2
  ;;
  -p|--port)
    serverPort="$2"
    shift 2
  ;;
  -s|--host)
    clientHost="$2"
    shift 2
  ;;
  -k|--key)
    itemKey="$2"
    shift 2
  ;;
  -o|--value)
    itemValue="$2"
    shift 2
  ;;
  -i|--input-file)
    inputFile="$2"
    shift 2
  ;;
  *)
    echo help
    exit 1
  ;;
esac
done

# Check if server was specified
if [ -z "$serverHost" ]; then
  echo "Server hostname or IP must be specified"
  echo ""
  usage
fi

# Check if port was specified, if not, set to default
if [ -z "$serverPort" ]; then
  serverPort="10051"
fi

# Check if input file or key/value pair was specified
if [ -n "$inputFile" ]; then
  # Begin JSON
  query='{"request":"sender data","data":['
  # Iterate over all lines in $inputFile and add the items to the JSON object
  while read line; do
    query=$query'{"host":'\"$(echo $line | cut -d' ' -f1)\"',"key":'\"$(echo $line | cut -d' ' -f2)\"',"value":'\"$(echo $line | cut -d' ' -f3-)\"'},'
  done < $inputFile
  # Remove last , and end JSON
  query=${query%?}']}'
  # Send it to the server
  response=$(echo $query | nc $serverHost $serverPort)
  echo "Server response: $response"
elif [ -n "$itemKey" ] && [ -n "$itemValue" ]; then
  response=$(echo '{"request":"sender data","data":[{"host":'\"$clientHost\"',"key":'\"$itemKey\"',"value":'\"$itemValue\"'}]}' | nc $serverHost $serverPort)
  echo "Server response: $response"
else
  echo "Either input file or key/value pair must be specified"
  echo ""
  usage
fi
