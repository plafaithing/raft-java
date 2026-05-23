#!/bin/bash

cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

echo "Testing single port..."

port=8051

echo "Checking port $port..."
if ! ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:$((port-8050)) " > /dev/null; then
    echo "  Port $port is not listening"
    exit 1
fi

echo "  Port $port is listening"
echo "  Running GetLeader..."

# 直接运行GetLeader并捕获输出
output=$(java -cp env/client/lib/*:target/classes com.github.wenweihu86.raft.example.client.GetLeader 127.0.0.1:$port 2>&1)

echo "  Output:"
echo "$output" | head -20

echo ""
echo "  Extracting leader address..."
leader=$(echo "$output" | grep "127.0.0.1:" | head -1)
echo "  Leader: $leader"

if [ -n "$leader" ]; then
    case "$leader" in
        "127.0.0.1:8051") echo "  Node: node1" ;;
        "127.0.0.1:8052") echo "  Node: node2" ;;
        "127.0.0.1:8053") echo "  Node: node3" ;;
        "127.0.0.1:8054") echo "  Node: node4" ;;
        "127.0.0.1:8055") echo "  Node: node5" ;;
        *) echo "  Node: unknown" ;;
    esac
fi

echo "Done!"
