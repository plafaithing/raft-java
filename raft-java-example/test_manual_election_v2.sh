#!/bin/bash

cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

echo "Simple Manual Election Test"
echo "============================"

# 获取当前leader
echo "Getting current leader..."
current_leader=$(timeout 10 java -cp env/client/lib/*:target/classes com.github.wenweihu86.raft.example.client.GetLeader 127.0.0.1:8051 2>/dev/null | tail -1)
echo "Current leader: $current_leader"

if [ -z "$current_leader" ]; then
    echo "ERROR: Cannot get current leader"
    exit 1
fi

# 获取leader节点名称
case "$current_leader" in
    "127.0.0.1:8051") leader_node="node1"; leader_port=8051 ;;
    "127.0.0.1:8052") leader_node="node2"; leader_port=8052 ;;
    "127.0.0.1:8053") leader_node="node3"; leader_port=8053 ;;
    "127.0.0.1:8054") leader_node="node4"; leader_port=8054 ;;
    "127.0.0.1:8055") leader_node="node5"; leader_port=8055 ;;
    *) echo "ERROR: Unknown leader"; exit 1 ;;
esac

echo "Leader node: $leader_node (port $leader_port)"

# 获取PID
pid=$(netstat -tlnp 2>/dev/null | grep ":${leader_port} " | awk '{print $7}' | head -1 | cut -d'/' -f1)
echo "Leader PID: $pid"

if [ -z "$pid" ]; then
    echo "ERROR: Cannot get PID"
    exit 1
fi

# Kill leader
echo "Killing leader (PID $pid)..."
kill -9 $pid

# 等待新leader选举
echo "Waiting for new leader election..."
sleep 20

# 获取新leader
echo "Getting new leader..."
new_leader=$(timeout 10 java -cp env/client/lib/*:target/classes com.github.wenweihu86.raft.example.client.GetLeader 127.0.0.1:8051 2>/dev/null | tail -1)
echo "New leader: $new_leader"

if [ -z "$new_leader" ]; then
    echo "ERROR: Cannot get new leader"
    exit 1
fi

# 获取新leader节点名称
case "$new_leader" in
    "127.0.0.1:8051") new_leader_node="node1" ;;
    "127.0.0.1:8052") new_leader_node="node2" ;;
    "127.0.0.1:8053") new_leader_node="node3" ;;
    "127.0.0.1:8054") new_leader_node="node4" ;;
    "127.0.0.1:8055") new_leader_node="node5" ;;
    *) new_leader_node="unknown" ;;
esac

echo "New leader node: $new_leader_node"

# 记录结果
echo ""
echo "Test Result:"
echo "Old leader: $leader_node"
echo "New leader: $new_leader_node"

echo "1,$leader_node,$new_leader_node" >> leader_election_log.csv

echo "Done!"
