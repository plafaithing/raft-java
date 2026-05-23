#!/bin/bash

cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

get_current_leader() {
    local leader=""
    
    for port in 8051 8052 8053 8054 8055; do
        if ! ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:$((port-8050)) " > /dev/null; then
            continue
        fi
        
        local result=$(timeout 5 java -cp env/client/lib/*:target/classes com.github.wenweihu86.raft.example.client.GetLeader 127.0.0.1:$port 2>/dev/null | tail -1)
        
        if [ "$result" != "unknown" ] && [ -n "$result" ]; then
            leader=$result
            break
        fi
    done
    
    if [ -z "$leader" ]; then
        echo "unknown"
        return
    fi
    
    case "$leader" in
        "127.0.0.1:8051") echo "node1" ;;
        "127.0.0.1:8052") echo "node2" ;;
        "127.0.0.1:8053") echo "node3" ;;
        "127.0.0.1:8054") echo "node4" ;;
        "127.0.0.1:8055") echo "node5" ;;
        *) echo "unknown" ;;
    esac
}

echo "Testing get_current_leader..."
leader=$(get_current_leader)
echo "Current leader: $leader"
