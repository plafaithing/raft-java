#!/bin/bash
cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

echo "=== 选举结果分析 ==="
echo ""

echo "新Leader分布:"
echo "  node1 (正常): $(grep -c ',node1$' leader_election_log.csv) 次"
echo "  node2 (CPU压力): $(grep -c ',node2$' leader_election_log.csv) 次"
echo "  node3 (网络不稳定): $(grep -c ',node3$' leader_election_log.csv) 次"
echo "  node4 (正常): $(grep -c ',node4$' leader_election_log.csv) 次"
echo "  node5 (内存压力): $(grep -c ',node5$' leader_election_log.csv) 次"
echo "  unknown: $(grep -c ',unknown$' leader_election_log.csv) 次"
echo ""

echo "旧Leader分布:"
echo "  node1 (正常): $(grep -c '^.*,[^,]*,node1$' leader_election_log.csv | head -1 || echo 0) 次"
echo "  node2 (CPU压力): $(grep -c ',node2,' leader_election_log.csv) 次"
echo "  node3 (网络不稳定): $(grep -c ',node3,' leader_election_log.csv) 次"
echo "  node4 (正常): $(grep -c ',node4,' leader_election_log.csv) 次"
echo "  node5 (内存压力): $(grep -c ',node5,' leader_election_log.csv) 次"
echo ""

echo "压力节点成为新Leader的总次数:"
stress_count=$(grep -E ',(node2|node3|node5)$' leader_election_log.csv | wc -l)
total=$(tail -n +2 leader_election_log.csv | wc -l)
echo "  $stress_count / $total ($(echo "scale=1; $stress_count * 100 / $total" | bc)%)"