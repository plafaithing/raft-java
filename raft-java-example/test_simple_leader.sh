#!/bin/bash

cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

echo "Simple leader detection test..."

# 检查每个节点
for port in 8051 8052 8053 8054 8055; do
    echo "Checking port $port..."
    
    # 检查端口是否在监听
    if ! ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:$((port-8050)) " > /dev/null; then
        echo "  Port $port is not listening"
        continue
    fi
    
    echo "  Port $port is listening"
    
    # 运行GetLeader并保存结果
    java -cp env/client/lib/*:target/classes com.github.wenweihu86.raft.example.client.GetLeader 127.0.0.1:$port 2>&1 | grep "127.0.0.1:" | head -1
done

echo "Done!"
