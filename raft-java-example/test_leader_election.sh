#!/bin/bash

# Leader 选举测试脚本

echo "=========================================="
echo "  Leader Election Test"
echo "=========================================="
echo ""

# 检查参数
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <test_type>"
    echo ""
    echo "Test Types:"
    echo "  convergence  - Test leader election convergence time"
    echo "  hetero      - Test heterogeneous cluster leader preference"
    echo "  stability    - Test leader stability under high concurrency"
    echo ""
    echo "Examples:"
    echo "  $0 convergence"
    echo "  $0 hetero"
    echo "  $0 stability"
    exit 1
fi

TEST_TYPE=$1
CLUSTER="list://127.0.0.1:8051,127.0.0.1:8052,127.0.0.1:8053,127.0.0.1:8054,127.0.0.1:8055"

# 测试 Leader 选举收敛时间
test_convergence() {
    echo "=========================================="
    echo "  Test: Leader Election Convergence Time"
    echo "=========================================="
    echo ""
    
    echo "测试步骤："
    echo "1. 等待 leader 选举完成"
    echo "2. 手动 kill leader"
    echo "3. 观察新的 leader 选举"
    echo "4. 记录 leader 选举收敛时间"
    echo ""
    
    echo "运行 Leader 选举测试..."
    java -cp env/client/lib/*:target/classes \
        com.github.wenweihu86.raft.example.client.LeaderElectionTest \
        $CLUSTER
    
    echo ""
    echo "测试完成！"
    echo ""
    echo "请查看日志：env/example1/nohup.out"
    echo "查找 'become leader' 日志"
}

# 测试异构集群 Leader 偏好
test_hetero() {
    echo "=========================================="
    echo "  Test: Heterogeneous Cluster Leader Preference"
    echo "=========================================="
    echo ""
    
    echo "测试环境："
    echo "  node1: 稳定（无压力）"
    echo "  node2: 高 CPU 压力（80%）"
    echo "  node3: 网络不稳定（随机断开）"
    echo "  node4: 稳定（无压力）"
    echo "  node5: 高内存压力（80%）"
    echo ""
    
    echo "配置异构环境..."
    sudo ./setup_hetero_v2.sh
    
    echo "等待集群启动..."
    sleep 10
    
    echo "运行异构集群测试（10 线程，60 秒）..."
    java -cp env/client/lib/*:target/classes \
        com.github.wenweihu86.raft.example.client.HeterogeneousClusterTest \
        $CLUSTER 10 60
    
    echo ""
    echo "测试完成！"
    echo ""
    echo "请查看日志：env/example1/nohup.out"
    echo "查找 'become leader' 日志"
    echo "查找 'leader' 日志"
}

# 测试高并发下的 Leader 稳定性
test_stability() {
    echo "=========================================="
    echo "  Test: Leader Stability Under High Concurrency"
    echo "=========================================="
    echo ""
    
    echo "运行高并发吞吐量测试（40 线程，60 秒）..."
    ./benchmark.sh throughput 40 60 > leader_stability_test.txt
    
    echo ""
    echo "分析 Leader 切换..."
    echo ""
    
    # 统计 Leader 切换次数
    LEADER_SWITCH_COUNT=$(grep "become leader" env/example1/nohup.out | wc -l)
    echo "Leader 切换次数：$LEADER_SWITCH_COUNT"
    
    # 统计 Leader 分布
    echo ""
    echo "Leader 分布："
    grep "become leader" env/example1/nohup.out | awk '{print $NF}' | sort | uniq -c
    
    echo ""
    echo "测试完成！"
    echo ""
    echo "请查看详细结果：leader_stability_test.txt"
}

# 根据测试类型执行测试
case $TEST_TYPE in
    convergence)
        test_convergence
        ;;
    hetero)
        test_hetero
        ;;
    stability)
        test_stability
        ;;
    *)
        echo "错误：未知的测试类型 '$TEST_TYPE'"
        echo "支持的测试类型：convergence, hetero, stability"
        exit 1
        ;;
esac
