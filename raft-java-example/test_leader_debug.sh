#!/bin/bash

cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

echo "Testing GetLeader with temporary file..."

for port in 8051 8052 8053 8054 8055; do
    echo "Checking port $port..."
    if ! ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:$((port-8050)) " > /dev/null; then
        echo "  Port $port is not listening"
        continue
    fi
    
    echo "  Port $port is listening"
    echo "  Querying leader..."
    tmp_file="/tmp/get_leader_$port.txt"
    timeout 15 java -cp env/client/lib/*:target/classes com.github.wenweihu86.raft.example.client.GetLeader 127.0.0.1:$port 2>&1 > "$tmp_file"
    result=$(grep "127.0.0.1:" "$tmp_file" | tail -1)
    rm -f "$tmp_file"
    echo "  Result: $result"
    
    if [ "$result" != "unknown" ] && [ -n "$result" ]; then
        case "$result" in
            "127.0.0.1:8051") echo "  Leader: node1" ;;
            "127.0.0.1:8052") echo "  Leader: node2" ;;
            "127.0.0.1:8053") echo "  Leader: node3" ;;
            "127.0.0.1:8054") echo "  Leader: node4" ;;
            "127.0.0.1:8055") echo "  Leader: node5" ;;
            *) echo "  Leader: unknown" ;;
        esac
        break
    fi
done

echo "Done!"
