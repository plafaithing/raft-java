#!/bin/bash
cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

echo "=== 各节点评分情况（进程级别监控）==="
for i in 1 2 3 4 5; do
    echo ""
    echo "=== Node $i ==="
    tail -50 env/example$i/nohup.out 2>/dev/null | grep "评分计算" | tail -3
done