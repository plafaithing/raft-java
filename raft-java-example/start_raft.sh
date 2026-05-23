#!/bin/bash

echo "=========================================="
echo "  启动 Raft 集群"
echo "=========================================="
echo ""

cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

# 停止所有节点
echo "停止所有节点..."
pkill -f 'run_server.sh' 2>/dev/null || true
sleep 2

# 启动 node1
echo "启动 node1..."
cd env/example1
nohup ./bin/run_server.sh ./data "127.0.0.1:8051:1,127.0.0.1:8052:2,127.0.0.1:8053:3,127.0.0.1:8054:4,127.0.0.1:8055:5,127.0.0.1:8056:6,127.0.0.1:8057:7" "127.0.0.1:8051:1" none > nohup.out 2>&1 &
cd ../..

# 启动 node2（CPU 压力）
echo "启动 node2（CPU 压力）..."
cd env/example2
nohup ./bin/run_server.sh ./data "127.0.0.1:8051:1,127.0.0.1:8052:2,127.0.0.1:8053:3,127.0.0.1:8054:4,127.0.0.1:8055:5,127.0.0.1:8056:6,127.0.0.1:8057:7" "127.0.0.1:8052:2" none > nohup.out 2>&1 &
cd ../..

# 启动 node3
echo "启动 node3..."
cd env/example3
nohup ./bin/run_server.sh ./data "127.0.0.1:8051:1,127.0.0.1:8052:2,127.0.0.1:8053:3,127.0.0.1:8054:4,127.0.0.1:8055:5,127.0.0.1:8056:6,127.0.0.1:8057:7" "127.0.0.1:8053:3" none > nohup.out 2>&1 &
cd ../..

# 启动 node4
echo "启动 node4..."
cd env/example4
nohup ./bin/run_server.sh ./data "127.0.0.1:8051:1,127.0.0.1:8052:2,127.0.0.1:8053:3,127.0.0.1:8054:4,127.0.0.1:8055:5,127.0.0.1:8056:6,127.0.0.1:8057:7" "127.0.0.1:8054:4" none > nohup.out 2>&1 &
cd ../..

# 启动 node5（内存压力）
echo "启动 node5（内存压力）..."
cd env/example5
nohup ./bin/run_server.sh ./data "127.0.0.1:8051:1,127.0.0.1:8052:2,127.0.0.1:8053:3,127.0.0.1:8054:4,127.0.0.1:8055:5,127.0.0.1:8056:6,127.0.0.1:8057:7" "127.0.0.1:8055:5" none > nohup.out 2>&1 &
cd ../..

# 启动 node6
echo "启动 node6..."
cd env/example6
nohup ./bin/run_server.sh ./data "127.0.0.1:8051:1,127.0.0.1:8052:2,127.0.0.1:8053:3,127.0.0.1:8054:4,127.0.0.1:8055:5,127.0.0.1:8056:6,127.0.0.1:8057:7" "127.0.0.1:8056:6" none > nohup.out 2>&1 &
cd ../..

# 启动 node7（内存压力）
echo "启动 node7（内存压力）..."
cd env/example7
nohup ./bin/run_server.sh ./data "127.0.0.1:8051:1,127.0.0.1:8052:2,127.0.0.1:8053:3,127.0.0.1:8054:4,127.0.0.1:8055:5,127.0.0.1:8056:6,127.0.0.1:8057:7" "127.0.0.1:8057:7" none > nohup.out 2>&1 &
cd ../..

echo ""
echo "等待节点启动..."
sleep 10

echo ""
echo "检查节点状态..."
for port in 8051 8052 8053 8054 8055 8056 8057; do
    if ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:$((port-8050)) " > /dev/null; then
        echo "  node$((port - 8050)) (端口 $port): 运行中"
    else
        echo "  node$((port - 8050)) (端口 $port): 未运行"
    fi
done

echo ""
echo "=========================================="
echo "  Raft 集群已启动"
echo "=========================================="
