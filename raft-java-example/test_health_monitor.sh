#!/bin/bash

echo "=========================================="
echo "  测试节点健康监控和选举"
echo "=========================================="

# 获取当前leader
echo "获取当前leader..."
LEADER=$(java -cp env/client/lib/*:target/classes com.github.wenweihu86.raft.example.client.GetLeader 127.0.0.1:8051 2>/dev/null | grep "127.0.0.1" | head -1)
echo "当前leader: $LEADER"

# 获取leader的node id
if [[ "$LEADER" == *"8051"* ]]; then
    LEADER_ID=1
elif [[ "$LEADER" == *"8052"* ]]; then
    LEADER_ID=2
elif [[ "$LEADER" == *"8053"* ]]; then
    LEADER_ID=3
elif [[ "$LEADER" == *"8054"* ]]; then
    LEADER_ID=4
elif [[ "$LEADER" == *"8055"* ]]; then
    LEADER_ID=5
else
    echo "无法识别leader"
    exit 1
fi

echo "Leader ID: $LEADER_ID"

# 杀掉leader
echo "杀掉leader (node$LEADER_ID)..."
pkill -f "ServerMain.*127.0.0.1:805$LEADER_ID"

# 等待选举
echo "等待选举完成..."
sleep 10

# 获取新leader
echo "获取新leader..."
NEW_LEADER=$(java -cp env/client/lib/*:target/classes com.github.wenweihu86.raft.example.client.GetLeader 127.0.0.1:8051 2>/dev/null | grep "127.0.0.1" | head -1)
echo "新leader: $NEW_LEADER"

# 获取新leader的node id
if [[ "$NEW_LEADER" == *"8051"* ]]; then
    NEW_LEADER_ID=1
elif [[ "$NEW_LEADER" == *"8052"* ]]; then
    NEW_LEADER_ID=2
elif [[ "$NEW_LEADER" == *"8053"* ]]; then
    NEW_LEADER_ID=3
elif [[ "$NEW_LEADER" == *"8054"* ]]; then
    NEW_LEADER_ID=4
elif [[ "$NEW_LEADER" == *"8055"* ]]; then
    NEW_LEADER_ID=5
else
    echo "无法识别新leader"
    exit 1
fi

echo "新Leader ID: $NEW_LEADER_ID"

# 重启被杀掉的节点
echo "重启node$LEADER_ID..."
cd env/example$LEADER_ID
STRESS_TYPE="none"
if [ $LEADER_ID -eq 2 ]; then
    STRESS_TYPE="cpu"
elif [ $LEADER_ID -eq 5 ]; then
    STRESS_TYPE="memory"
fi

nohup ./bin/run_server.sh ./data "127.0.0.1:8051:1,127.0.0.1:8052:2,127.0.0.1:8053:3,127.0.0.1:8054:4,127.0.0.1:8055:5" "127.0.0.1:805$LEADER_ID:$LEADER_ID" $STRESS_TYPE > nohup.out 2>&1 &
cd /mnt/d/workplace/java/raft1/raft-java-master

echo "等待节点重启..."
sleep 10

echo "=========================================="
echo "  测试完成"
echo "=========================================="
echo "原leader: node$LEADER_ID ($LEADER)"
echo "新leader: node$NEW_LEADER_ID ($NEW_LEADER)"