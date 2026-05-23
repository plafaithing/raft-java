#!/bin/bash

RAFT_HOME=$(cd "$(dirname "$0")" && pwd)
CLUSTER="list://127.0.0.1:8051,127.0.0.1:8052,127.0.0.1:8053,127.0.0.1:8054,127.0.0.1:8055,127.0.0.1:8056,127.0.0.1:8057"

echo "=========================================="
echo "  Raft Performance Benchmark Tool"
echo "=========================================="
echo ""
echo "Usage: $0 <test_type> [options]"
echo ""
echo "Test Types:"
echo "  throughput   - Test throughput (requests/sec)"
echo "  election     - Test leader election convergence time"
echo "  hetero      - Test heterogeneous cluster (leader preference)"
echo "  stress       - Start node stressor (cpu/memory/network)"
echo "  all         - Run all tests"
echo ""
echo "Examples:"
echo "  $0 throughput 10 60   # 10 threads, 60 seconds"
echo "  $0 election              # Test leader election (kill leader manually)"
echo "  $0 stress cpu             # Simulate high CPU load on this node"
echo "  $0 stress memory          # Simulate high memory usage on this node"
echo "  $0 hetero 10 60       # Test heterogeneous cluster"
echo ""

if [ $# -lt 1 ]; then
    exit 0
fi

TEST_TYPE=$1

cd $RAFT_HOME

case $TEST_TYPE in
    throughput)
        THREAD_NUM=${2:-10}
        DURATION=${3:-60}
        echo "Running Throughput Test..."
        echo "Threads: $THREAD_NUM, Duration: ${DURATION}s"
        java -cp "target/raft-java-example-1.9.0.jar:env/client/lib/*" com.github.wenweihu86.raft.example.client.ThroughputBenchmark \
            "$CLUSTER" $THREAD_NUM $DURATION
        ;;
    election)
        echo "Running Leader Election Test..."
        echo "Please kill the leader process manually to trigger election."
        java -cp "target/raft-java-example-1.9.0.jar:env/client/lib/*" com.github.wenweihu86.raft.example.client.LeaderElectionTest \
            "$CLUSTER" 8051
        ;;
    all)
        echo "Running All Tests..."
        echo ""
        echo "=== 1. Throughput Test (10 threads, 60s) ==="
        java -cp "target/raft-java-example-1.9.0.jar:env/client/lib/*" com.github.wenweihu86.raft.example.client.ThroughputBenchmark \
            "$CLUSTER" 10 60
        ;;
    hetero)
        THREAD_NUM=${2:-10}
        DURATION=${3:-60}
        echo "Running Heterogeneous Cluster Test..."
        echo "Threads: $THREAD_NUM, Duration: ${DURATION}s"
        java -cp "target/raft-java-example-1.9.0.jar:env/client/lib/*" com.github.wenweihu86.raft.example.client.HeterogeneousClusterTest \
            "$CLUSTER" $DURATION
        ;;
    stress)
        STRESS_TYPE=${2:-cpu}
        echo "Starting Node Stressor..."
        echo "Stress type: $STRESS_TYPE"
        java -cp "target/raft-java-example-1.9.0.jar:env/client/lib/*" com.github.wenweihu86.raft.example.client.NodeStressor \
            "$STRESS_TYPE"
        ;;
    *)
        echo "Unknown test type: $TEST_TYPE"
        exit 1
        ;;
esac
