#!/bin/bash
cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

echo "=== 各节点评分情况 ==="
for i in 1 2 3 4 5; do
    echo ""
    echo "=== Node $i ==="
    grep "节点$i 评分计算" env/example$i/nohup.out | tail -5
done