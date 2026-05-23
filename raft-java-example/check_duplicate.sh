#!/bin/bash
ps -ef | grep "ServerMain" | grep -v grep | while read line; do
    node=$(echo "$line" | grep -o '127.0.0.1:80[0-9][0-9]:[0-9] ' | tail -1)
    echo "$node"
done | sort | uniq -c