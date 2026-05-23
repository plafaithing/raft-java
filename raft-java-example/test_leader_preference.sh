#!/bin/bash

# 异构集群 Leader 偏好测试脚本
# 手动触发选举，重复 10 次

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Heterogeneous Cluster Leader Preference Test"
echo "=========================================="
echo ""

# 检查集群是否运行
check_cluster() {
    local running_count=0
    for port in 8051 8052 8053 8054 8055; do
        if ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:$((port-8050)) " > /dev/null; then
            running_count=$((running_count + 1))
        fi
    done
    
    if [ "$running_count" -lt 3 ]; then
        echo -e "${RED}ERROR: Cluster is not running (only $running_count/5 nodes)${NC}"
        echo "Please start the cluster first."
        exit 1
    fi
}

check_cluster

# 端口到节点名称的映射
declare -A port_to_node
port_to_node[8051]="node1"
port_to_node[8052]="node2"
port_to_node[8053]="node3"
port_to_node[8054]="node4"
port_to_node[8055]="node5"

# 节点名称到端口的映射
declare -A node_to_port
node_to_port[node1]=8051
node_to_port[node2]=8052
node_to_port[node3]=8053
node_to_port[node4]=8054
node_to_port[node5]=8055

# 获取当前 leader
get_current_leader() {
    local timeout_seconds=60
    local start_time=$(date +%s)
    local elapsed=0
    
    while [ $elapsed -lt $timeout_seconds ]; do
        for port in 8051 8052 8053 8054 8055; do
            # 检查端口是否在监听
            if ! ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:$((port-8050)) " > /dev/null; then
                continue
            fi
            
            # 使用GetLeader程序查询leader（带timeout）
            local result=$(timeout 5 java -cp env/client/lib/*:target/classes com.github.wenweihu86.raft.example.client.GetLeader 127.0.0.1:$port 2>/dev/null | grep "127.0.0.1:" | head -1)
            
            if [ -n "$result" ]; then
                # 将端口号转换为节点名称
                case "$result" in
                    "127.0.0.1:8051") echo "node1" ;;
                    "127.0.0.1:8052") echo "node2" ;;
                    "127.0.0.1:8053") echo "node3" ;;
                    "127.0.0.1:8054") echo "node4" ;;
                    "127.0.0.1:8055") echo "node5" ;;
                    *) echo "unknown" ;;
                esac
                return 0
            fi
        done
        
        sleep 1
        elapsed=$(( $(date +%s) - start_time ))
    done
    
    echo "unknown"
    return 1
}

# 根据 leader 获取端口
get_leader_port() {
    local leader=$1
    echo "${node_to_port[$leader]}"
}

# 根据 leader 获取 PID
get_leader_pid() {
    local leader=$1
    local port=$(get_leader_port "$leader")
    local pid=$(netstat -tlnp 2>/dev/null | grep ":${port} " | awk '{print $7}' | head -1 | cut -d'/' -f1)
    echo "$pid"
}

# 手动触发选举
trigger_election() {
    local test_num=$1
    
    echo "=========================================="
    echo "  Test $test_num"
    echo "=========================================="

    # 绑定进程到 cgroup
    # sudo ./setup_hetero_v2.sh bind > /dev/null 2>&1
    
    # 获取当前 leader
    echo "正在获取当前 leader..."
    local current_leader=$(get_current_leader)
    echo "当前 leader: $current_leader"
    
    if [ "$current_leader" = "unknown" ]; then
        echo -e "${RED}ERROR: Cannot find current leader${NC}"
        return 1
    fi
    
    # 获取端口
    local port=$(get_leader_port "$current_leader")
    echo "端口: $port"
    
    # 获取 PID
    local pid=$(get_leader_pid "$current_leader")
    echo "PID: $pid"
    
    if [ -z "$pid" ]; then
        echo -e "${RED}ERROR: Cannot find PID for port $port${NC}"
        return 1
    fi
    
    # Kill leader
    echo "Killing leader..."
    kill -9 $pid
    
    # 等待新 leader 选举
    echo "等待新 leader 选举..."
    sleep 5
    
    # 查看新 leader
    local new_leader=$(get_current_leader)
    echo "新 leader: $new_leader"
    
    # 记录结果到 CSV 文件
    echo "$test_num,$current_leader,$new_leader" >> leader_election_log.csv
    
    # 记录结果到数组
    old_leaders+=("$current_leader")
    new_leaders+=("$new_leader")
    
    # 重启被 kill 的节点
    echo "重启被 kill 的节点..."
    
    # 先 kill 掉该端口的所有进程
    #echo "清理端口 $port 的旧进程..."
    #lsof -ti:$port 2>/dev/null | xargs -r kill -9 2>/dev/null || true
    
    # 等待端口释放
    echo "等待端口 $port 释放..."
    local max_wait=30
    local wait_count=0
    while [ $wait_count -lt $max_wait ]; do
        if ! ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:$((port-8050)) " > /dev/null; then
            echo "端口 $port 已释放"
            break
        fi
        sleep 1
        wait_count=$((wait_count + 1))
    done
    
    if [ $wait_count -ge $max_wait ]; then
        echo -e "${RED}ERROR: Port $port did not release after ${max_wait}s${NC}"
        return 1
    fi
    
    # 重启被 kill 的节点
    echo "重启被 kill 的节点..."
    # 重启节点
    local example_dir=$(echo "$current_leader" | sed 's/node/example/')
    local current_dir=$(pwd)
    cd env/$example_dir
    
    # 根据节点类型决定是否带压力参数
    local stress_type="none"
    case "$current_leader" in
        "node2") stress_type="cpu" ;;
        "node5") stress_type="memory" ;;
    esac
    
    nohup ./bin/run_server.sh ./data "127.0.0.1:8051:1,127.0.0.1:8052:2,127.0.0.1:8053:3,127.0.0.1:8054:4,127.0.0.1:8055:5" "127.0.0.1:$port:${current_leader#node}" $stress_type  &
    cd "$current_dir"
    
    # 等待节点启动
    echo "等待节点 $current_leader 启动..."
    local max_wait=30
    local wait_count=0
    while [ $wait_count -lt $max_wait ]; do
        if ps -ef | grep "ServerMain" | grep -v grep | grep " 127.0.0.1:${port}:$((port-8050)) " > /dev/null; then
            echo "节点 $current_leader 已启动（端口 $port 正在监听）"
            break
        fi
        sleep 1
        wait_count=$((wait_count + 1))
    done
    
    if [ $wait_count -ge $max_wait ]; then
        echo -e "${RED}ERROR: Node $current_leader failed to start (port $port not listening after ${max_wait}s)${NC}"
        return 1
    fi
    
    # 重新绑定进程到 cgroup
    echo "重新绑定进程到 cgroup..."
    sudo ./setup_hetero_v2.sh bind > /dev/null 2>&1
    
    # 等待集群恢复
    echo "等待集群恢复..."
    sleep 10
    
    # 验证集群是否恢复
    local verify_leader=$(get_current_leader)
    if [ "$verify_leader" = "unknown" ]; then
        echo -e "${RED}WARNING: Cluster may not have recovered properly${NC}"
    else
        echo "集群已恢复，当前leader: $verify_leader"
    fi
    
    echo -e "${GREEN}✓ Test $test_num completed${NC}"
    echo ""
}

# 清理日志
rm -f leader_election_log.csv
echo "test_num,old_leader,new_leader" > leader_election_log.csv

# 声明数组来记录 leader 切换信息
declare -a leader_transitions
declare -a old_leaders
declare -a new_leaders

# 压力任务已经在 Java 进程内部运行（通过 start_raft_with_stress.sh 启动）
# 不需要启动外部压力工具

# 重复 20 次
for i in {1..50}; do
    trigger_election $i
done

# 统计结果
echo "=========================================="
echo "  Leader Election Results"
echo "=========================================="
echo ""

echo "Leader 分布："
declare -A leader_count
for i in $(seq 0 $((${#new_leaders[@]} - 1))); do
    leader=${new_leaders[$i]}
    leader_count[$leader]=$((${leader_count[$leader]:-0} + 1))
done

for i in 1 2 3 4 5; do
    node="node$i"
    count=${leader_count[$node]:-0}
    if [ "$count" -gt 0 ]; then
        echo "   $count $node"
    fi
done

echo ""
echo "Leader 切换详情："
cat leader_election_log.csv

echo ""
echo "Leader 切换统计："
total_count=${#new_leaders[@]}
echo "总切换次数: $total_count"

echo ""
echo -e "${GREEN}✓ Test completed${NC}"
echo ""
echo "Results saved to: leader_election_log.csv"
