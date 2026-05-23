#!/bin/bash

# Raft 异构集群模拟脚本 (WSL/cgroup v2)
# 使用 cgroup v2 来限制不同节点的资源

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CGROUP_ROOT="/sys/fs/cgroup"
RAFT_CGROUP="$CGROUP_ROOT/raft"

echo "=========================================="
echo "  Raft Heterogeneous Cluster Setup (v2)"
echo "=========================================="
echo ""

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# 检查 cgroup v2
if [ ! -d "$CGROUP_ROOT" ]; then
    echo -e "${RED}ERROR: cgroup v2 not found${NC}"
    exit 1
fi

# 创建 cgroups
create_cgroup() {
    local name=$1
    local cpu_weight=$2
    local memory_max=$3
    
    echo "Creating cgroup: $name"
    echo "  CPU weight: $cpu_weight"
    echo "  Memory max: $memory_max"
    
    local cgroup_path="$RAFT_CGROUP/$name"
    
    # 创建 cgroup 目录
    mkdir -p "$cgroup_path"
    
    # 启用控制器（cgroup v2 关键步骤）
    echo "+cpu +memory" > "$RAFT_CGROUP/cgroup.subtree_control"
    
    # 设置 CPU 权重（1-10000，默认 100）
    if [ "$cpu_weight" != "default" ]; then
        echo $cpu_weight > "$cgroup_path/cpu.weight"
    fi
    
    # 设置内存限制
    if [ "$memory_max" != "max" ]; then
        # 将内存限制转换为字节格式
        local memory_bytes=$(echo "$memory_max" | awk '{
            if ($1 ~ /G$/) {
                printf "%.0f", $1 * 1024 * 1024 * 1024
            } else if ($1 ~ /M$/) {
                printf "%.0f", $1 * 1024 * 1024
            } else if ($1 ~ /K$/) {
                printf "%.0f", $1 * 1024
            } else {
                printf "%.0f", $1
            }
        }')
        echo $memory_bytes > "$cgroup_path/memory.max"
    fi
    
    echo -e "${GREEN}✓ Cgroup created: $cgroup_path${NC}"
}

# 将进程添加到 cgroup
add_to_cgroup() {
    local port=$1
    local cgroup=$2
    
    echo "Adding process on port $port to cgroup: $cgroup"
    
    # 查找进程 PID（使用 ps 查找监听指定端口的进程，精确匹配最后一个参数）
    local pid=$(ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:$((port-8050)) " | awk '{print $2}' | head -1)
    
    if [ -z "$pid" ]; then
        echo -e "${RED}ERROR: No process found on port $port${NC}"
        return 1
    fi
    
    echo "Found PID: $pid"
    
    # 将进程添加到 cgroup（写入 cgroup.procs）
    echo $pid > "$RAFT_CGROUP/$cgroup/cgroup.procs"
    
    echo -e "${GREEN}✓ Process $pid added to cgroup $cgroup${NC}"
}

# 清理 cgroups
cleanup_cgroups() {
    echo ""
    echo "Cleaning up cgroups..."
    
    if [ -d "$RAFT_CGROUP" ]; then
        # 先杀死所有子 cgroup 中的进程
        for cgroup in "$RAFT_CGROUP"/*; do
            if [ -d "$cgroup" ]; then
                if [ -f "$cgroup/cgroup.procs" ]; then
                    local pids=$(cat "$cgroup/cgroup.procs" 2>/dev/null || true)
                    if [ -n "$pids" ]; then
                        echo "Killing processes in $cgroup: $pids"
                        kill $pids 2>/dev/null || true
                    fi
                fi
            fi
        done
        
        # 删除 raft cgroup
        rmdir "$RAFT_CGROUP"/* 2>/dev/null || true
        rmdir "$RAFT_CGROUP" 2>/dev/null || true
        
        echo -e "${GREEN}✓ Cleanup completed${NC}"
    else
        echo "No cgroups to clean up"
    fi
}

# 显示当前 cgroups 状态
show_status() {
    echo ""
    echo "=========================================="
    echo "  Current Cgroup Status"
    echo "=========================================="
    
    if [ ! -d "$RAFT_CGROUP" ]; then
        echo "No raft cgroups found"
        return
    fi
    
    for name in node1 node2 node3 node4 node5; do
        local cgroup_path="$RAFT_CGROUP/$name"
        if [ -d "$cgroup_path" ]; then
            echo ""
            echo "Cgroup: $name"
            
            if [ -f "$cgroup_path/cpu.weight" ]; then
                echo "  CPU weight: $(cat $cgroup_path/cpu.weight)"
            fi
            
            if [ -f "$cgroup_path/memory.max" ]; then
                local mem_max=$(cat $cgroup_path/memory.max)
                if [ "$mem_max" = "max" ]; then
                    echo "  Memory max: unlimited"
                else
                    local mem_mb=$((mem_max / 1024 / 1024))
                    echo "  Memory max: ${mem_mb}MB"
                fi
            fi
            
            if [ -f "$cgroup_path/memory.current" ]; then
                local mem_cur=$(cat $cgroup_path/memory.current)
                local mem_mb=$((mem_cur / 1024 / 1024))
                echo "  Memory current: ${mem_mb}MB"
            fi
            
            if [ -f "$cgroup_path/cgroup.procs" ]; then
                local pids=$(cat $cgroup_path/cgroup.procs 2>/dev/null || true)
                if [ -n "$pids" ]; then
                    echo "  Processes: $pids"
                else
                    echo "  Processes: none"
                fi
            fi
        fi
    done
}

# 主函数
main() {
    case "$1" in
        setup)
            echo "Setting up heterogeneous cluster cgroups..."
            echo ""
            
            # 创建 raft 根 cgroup
            mkdir -p "$RAFT_CGROUP"
            
            # Node 1: 稳定节点（高资源）
            create_cgroup "node1" "10000" "2G"
            
            # Node 2: 不稳定节点（低 CPU，80%）
            create_cgroup "node2" "800" "1600M"
            
            # Node 3: 中等节点（网络不稳定）
            create_cgroup "node3" "5000" "1G"
            
            # Node 4: 稳定节点（高资源）
            create_cgroup "node4" "10000" "2G"
            
            # Node 5: 不稳定节点（低内存，80%）
            create_cgroup "node5" "2400" "1600M"
            
            echo ""
            echo -e "${GREEN}✓ Cgroups setup completed${NC}"
            echo ""
            echo "Next steps:"
            echo "  1. Start Raft nodes"
            echo "  2. Run: sudo $0 bind"
            echo ""
            ;;
            
        bind)
            echo "Binding processes to cgroups..."
            echo ""
            
            add_to_cgroup 8051 "node1"
            add_to_cgroup 8052 "node2"
            add_to_cgroup 8053 "node3"
            add_to_cgroup 8054 "node4"
            add_to_cgroup 8055 "node5"
            
            echo ""
            echo -e "${GREEN}✓ All processes bound to cgroups${NC}"
            echo ""
            echo "Run: sudo $0 status"
            ;;
            
        status)
            show_status
            ;;
            
        cleanup)
            cleanup_cgroups
            ;;
            
        *)
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  setup   - Create cgroups for heterogeneous cluster"
            echo "  bind    - Bind running processes to cgroups"
            echo "  status  - Show current cgroup status"
            echo "  cleanup - Remove all cgroups"
            echo ""
            echo "Example workflow:"
            echo "  1. sudo $0 setup"
            echo "  2. ./deploy.sh"
            echo "  3. sudo $0 bind"
            echo "  4. sudo $0 status"
            echo "  5. Run tests..."
            echo "  6. sudo $0 cleanup"
            exit 1
            ;;
    esac
}

main "$@"
