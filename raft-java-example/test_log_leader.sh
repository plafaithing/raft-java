#!/bin/bash

cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

get_current_leader_simple() {
    for i in 1 2 3 4 5; do
        local log_file="env/example$i/nohup.out"
        if [ ! -f "$log_file" ]; then
            continue
        fi
        
        # 查找最近的状态信息
        local result=$(tail -50 "$log_file" | grep -E "state=LEADER|become leader" | tail -1)
        if [ -n "$result" ]; then
            echo "node$i"
            return 0
        fi
    done
    
    echo "unknown"
    return 1
}

echo "Testing get_current_leader_simple..."
leader=$(get_current_leader_simple)
echo "Current leader: $leader"
