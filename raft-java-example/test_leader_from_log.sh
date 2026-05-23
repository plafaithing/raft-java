#!/bin/bash

cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

get_current_leader_from_log() {
    local leader=""
    
    for i in 1 2 3 4 5; do
        local log_file="env/example$i/nohup.out"
        if [ ! -f "$log_file" ]; then
            continue
        fi
        
        local result=$(tail -100 "$log_file" | grep -E "become leader|state=LEADER" | tail -1)
        if [ -n "$result" ]; then
            leader="node$i"
            break
        fi
    done
    
    if [ -z "$leader" ]; then
        echo "unknown"
    else
        echo "$leader"
    fi
}

echo "Testing get_current_leader_from_log..."
leader=$(get_current_leader_from_log)
echo "Current leader: $leader"
