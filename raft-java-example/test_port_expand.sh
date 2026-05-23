#!/bin/bash
port=8052
echo "port: $port"
echo "port-8050: $((port-8050))"
echo "Pattern: 127.0.0.1:${port}:$((port-8050)) "
ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:$((port-8050)) "