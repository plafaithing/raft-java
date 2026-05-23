#!/bin/bash

for pid in $(ps -ef | grep 'ServerMain' | grep -v grep | awk '{print $2}'); do
    echo "PID: $pid"
    ls -l /proc/$pid/cwd 2>/dev/null | awk '{print "  CWD: " $NF}'
done