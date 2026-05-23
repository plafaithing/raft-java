#!/bin/bash
port=8051
node_id=$((port-8050))
echo "Port: $port"
echo "Node ID: $node_id"
echo "Pattern: 127.0.0.1:${port}:${node_id} "

ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:${node_id} " | awk '{print $2}' | head -1