#!/bin/bash
cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

for port in 8051 8052 8053 8054 8055; do
    echo "Testing port: $port"
    result=$(java -cp env/client/lib/*:target/classes com.github.wenweihu86.raft.example.client.GetLeader 127.0.0.1:$port 2>/dev/null | grep "127.0.0.1:" | head -1)
    echo "  Result: $result"
done