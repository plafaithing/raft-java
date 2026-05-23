#!/bin/bash

cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

echo "Step 1: Testing netstat..."
for port in 8051 8052 8053 8054 8055; do
    if ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:$((port-8050)) " > /dev/null; then
        echo "  Port $port is listening"
    else
        echo "  Port $port is not listening"
    fi
done

echo ""
echo "Step 2: Testing GetLeader on port 8051..."
result=$(timeout 10 java -cp env/client/lib/*:target/classes com.github.wenweihu86.raft.example.client.GetLeader 127.0.0.1:8051 2>&1 | grep -E '^(127\.0\.0\.1:|unknown)$' | tail -1)
echo "  Result: $result"

echo ""
echo "Step 3: Converting result to node name..."
case "$result" in
    "127.0.0.1:8051") echo "  node1" ;;
    "127.0.0.1:8052") echo "  node2" ;;
    "127.0.0.1:8053") echo "  node3" ;;
    "127.0.0.1:8054") echo "  node4" ;;
    "127.0.0.1:8055") echo "  node5" ;;
    *) echo "  unknown" ;;
esac

echo ""
echo "All tests completed!"
