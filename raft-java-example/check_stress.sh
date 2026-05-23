#!/bin/bash

echo "=== 各节点压力类型配置 ==="
ps -ef | grep 'ServerMain' | grep -v grep | while read line; do
    node=$(echo "$line" | grep -o '127.0.0.1:80[0-9][0-9]:[0-9] ' | tail -1)
    stress=$(echo "$line" | awk '{print $NF}')
    echo "Node: $node Stress: $stress"
done