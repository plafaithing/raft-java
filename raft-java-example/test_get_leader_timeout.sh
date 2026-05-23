#!/bin/bash

cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

echo "Testing GetLeader for each node with longer timeout..."

for port in 8051 8052 8053 8054 8055; do
    echo "Checking port $port..."
    if ! ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:$((port-8050)) " > /dev/null; then
        echo "  Port $port is not listening"
        continue
    fi
    
    echo "  Port $port is listening"
    echo "  Querying leader..."
    result=$(timeout 10 java -cp env/client/lib/*:target/classes com.github.wenweihu86.raft.example.client.GetLeader 127.0.0.1:$port 2>&1 | grep -E '^(127\.0\.0\.1:|unknown)$' | tail -1)
    echo "  Result: $result"
done
