#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: ./node_stressor.sh <node> <type>"
    echo "  node: node1, node2, node3, node4, node5"
    echo "  type: cpu, memory"
    exit 1
fi

NODE=$1
TYPE=$2

# 获取节点的 PID
case "$NODE" in
    "node1") PORT=8051 ;;
    "node2") PORT=8052 ;;
    "node3") PORT=8053 ;;
    "node4") PORT=8054 ;;
    "node5") PORT=8055 ;;
    *) echo "Unknown node: $NODE"; exit 1 ;;
esac

# 查找进程 PID
PID=$(netstat -tlnp 2>/dev/null | grep ":$PORT " | awk '{print $7}' | cut -d'/' -f1 | head -1)

if [ -z "$PID" ]; then
    echo "ERROR: No process found for $NODE (port $PORT)"
    exit 1
fi

echo "=========================================="
echo "  Node Stressor Tool"
echo "=========================================="
echo ""
echo "Node: $NODE"
echo "Type: $TYPE"
echo "PID: $PID"
echo ""

# 使用 taskset 将压力任务绑定到节点的 CPU 核心
case "$TYPE" in
    "cpu")
        echo "Starting CPU stress for $NODE..."
        echo "Target: 80% CPU usage"
        echo ""
        
        # 启动 CPU 压力任务
        while true; do
            result=0
            for i in $(seq 1 100000); do
                result=$(echo "$result + $i" | bc 2>/dev/null || echo $((result + i)))
            done
            sleep 0.1
        done
        
        ;;
        
    "memory")
        echo "Starting memory stress for $NODE..."
        echo "Target: 80% memory usage"
        echo ""
        
        # 启动内存压力任务
        MEMORY_HOG_DIR="/tmp/memory_hog_$NODE"
        mkdir -p "$MEMORY_HOG_DIR"
        
        while true; do
            # 分配 100MB 内存
            dd if=/dev/zero of="$MEMORY_HOG_DIR/$(date +%s%N).dat" bs=100M count=1 2>/dev/null
            sleep 1
        done
        
        ;;
        
    *)
        echo "Unknown stress type: $TYPE"
        exit 1
        ;;
esac
