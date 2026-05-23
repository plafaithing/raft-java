#!/bin/bash

# Raft 异构集群模拟脚本 (WSL/单机)
# 使用 cgroups 来限制不同节点的资源

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Raft Heterogeneous Cluster Setup"
echo "=========================================="
echo ""

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# 检查 cgroups 是否可用
if ! command -v cgcreate &> /dev/null; then
    echo -e "${YELLOW}WARNING: cgroups tools not found${NC}"
    echo "Installing cgroup-tools..."
    apt-get update && apt-get install -y cgroup-tools
fi

# 创建 cgroups
create_cgroup() {
    local name=$1
    local cpu_quota=$2
    local memory_limit=$3
    
    echo "Creating cgroup: $name"
    echo "  CPU quota: $cpu_quota"
    echo "  Memory limit: $memory_limit"
    
    # 创建 cgroup
    cgcreate -g cpu,memory:/raft_$name
    
    # 设置 CPU 限制
    if [ "$cpu_quota" != "unlimited" ]; then
        cgset -r cpu.cfs_quota_us=$cpu_quota raft_$name
        cgset -r cpu.cfs_period_us=100000 raft_$name
    fi
    
    # 设置内存限制
    if [ "$memory_limit" != "unlimited" ]; then
        cgset -r memory.limit_in_bytes=$memory_limit raft_$name
    fi
    
    echo -e "${GREEN}✓ Cgroup created: raft_$name${NC}"
}

# 将进程添加到 cgroup
add_to_cgroup() {
    local port=$1
    local cgroup=$2
    
    echo "Adding process on port $port to cgroup: $cgroup"
    
    # 查找进程 PID
    local pid=$(lsof -ti:$port 2>/dev/null || netstat -tlnp 2>/dev/null | grep :$port | awk '{print $7}' | cut -d'/' -f1)
    
    if [ -z "$pid" ]; then
        echo -e "${RED}ERROR: No process found on port $port${NC}"
        return 1
    fi
    
    echo "Found PID: $pid"
    
    # 将进程添加到 cgroup
    cgclassify -g cpu,memory:$cgroup $pid
    
    echo -e "${GREEN}✓ Process $pid added to cgroup $cgroup${NC}"
}

# 清理 cgroups
cleanup_cgroups() {
    echo ""
    echo "Cleaning up cgroups..."
    
    for name in node1 node2 node3 node4 node5; do
        if cgdelete -g cpu,memory:/raft_$name 2>/dev/null; then
            echo -e "${GREEN}✓ Deleted cgroup: raft_$name${NC}"
        fi
    done
    
    echo -e "${GREEN}✓ Cleanup completed${NC}"
}

# 显示当前 cgroups 状态
show_status() {
    echo ""
    echo "=========================================="
    echo "  Current Cgroup Status"
    echo "=========================================="
    
    for name in node1 node2 node3 node4 node5; do
        echo ""
        echo "Cgroup: raft_$name"
        if [ -d /sys/fs/cgroup/cpu/raft_$name ]; then
            echo "  CPU quota: $(cat /sys/fs/cgroup/cpu/raft_$name/cpu.cfs_quota_us 2>/dev/null || echo 'N/A')"
            echo "  CPU period: $(cat /sys/fs/cgroup/cpu/raft_$name/cpu.cfs_period_us 2>/dev/null || echo 'N/A')"
        fi
        if [ -d /sys/fs/cgroup/memory/raft_$name ]; then
            echo "  Memory limit: $(cat /sys/fs/cgroup/memory/raft_$name/memory.limit_in_bytes 2>/dev/null || echo 'N/A')"
            echo "  Memory usage: $(cat /sys/fs/cgroup/memory/raft_$name/memory.usage_in_bytes 2>/dev/null || echo 'N/A')"
        fi
    done
}

# 主函数
main() {
    case "$1" in
        setup)
            echo "Setting up heterogeneous cluster cgroups..."
            echo ""
            
            # Node 1: 稳定节点（高资源）
            create_cgroup "node1" "100000" "2G"
            
            # Node 2: 不稳定节点（低 CPU）
            create_cgroup "node2" "30000" "1G"
            
            # Node 3: 中等节点
            create_cgroup "node3" "60000" "1G"
            
            # Node 4: 稳定节点（高资源）
            create_cgroup "node4" "100000" "2G"
            
            # Node 5: 不稳定节点（低内存）
            create_cgroup "node5" "50000" "512M"
            
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
            
            add_to_cgroup 8051 "raft_node1"
            add_to_cgroup 8052 "raft_node2"
            add_to_cgroup 8053 "raft_node3"
            add_to_cgroup 8054 "raft_node4"
            add_to_cgroup 8055 "raft_node5"
            
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
