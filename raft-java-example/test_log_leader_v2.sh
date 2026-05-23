#!/bin/bash

cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

get_current_leader_from_log() {
    for i in 1 2 3 4 5; do
        local log_file="env/example$i/nohup.out"
        if [ ! -f "$log_file" ]; then
            continue
        fi
        
        # 查找最近的getLeader响应
        local result=$(tail -100 "$log_file" | grep "getLeader response" | tail -1)
        if [ -n "$result" ]; then
            # 从响应中提取端口号
            local port=$(echo "$result" | grep -oP '"port":\s*\K\d+')
            if [ -n "$port" ]; then
                case "$port" in
                    "8051") echo "node1" ;;
                    "8052") echo "node2" ;;
                    "8053") echo "node3" ;;
                    "8054") echo "node4" ;;
                    "8055") echo "node5" ;;
                    *) echo "unknown" ;;
                esac
                return 0
            fi
        fi
    done
    
    echo "unknown"
    return 1
}

echo "Testing get_current_leader_from_log..."
leader=$(get_current_leader_from_log)
echo "Current leader: $leader"
