#!/bin/bash
cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

for port in 8051 8052 8053 8054 8055; do
    echo "Testing port: $port"
    node_id=$((port-8050))
    pattern=" 127.0.0.1:${port}:${node_id} "
    echo "  Pattern: $pattern"
    
    if ps -ef | grep "ServerMain" | grep -v grep | grep "$pattern" > /dev/null; then
        echo "  Process found"
        result=$(timeout 3 java -cp env/client/lib/*:target/classes com.github.wenweihu86.raft.example.client.GetLeader 127.0.0.1:$port 2>/dev/null | grep "127.0.0.1:" | head -1)
        if [ -n "$result" ]; then
            echo "  GetLeader result: $result"
        else
            echo "  GetLeader TIMEOUT"
        fi
    else
        echo "  Process NOT found"
    fi
done