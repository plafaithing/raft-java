#!/bin/bash
for port in 8051 8052 8053 8054 8055; do
    node_id=$((port-8050))
    echo "Port: $port, Node ID: $node_id"
    pid=$(ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:${node_id} " | awk '{print $2}' | head -1)
    echo "  PID: $pid"
done