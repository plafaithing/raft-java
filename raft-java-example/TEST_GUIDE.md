# Raft 优化测试指南

## 快速开始

```bash
# 1. 编译项目
cd d:/workplace/java/raft1/raft-java-master
mvn clean package -DskipTests

# 2. 启动集群
cd raft-java-example
./deploy.sh

# 3. 运行测试
./benchmark.sh throughput 10 60
```

## 测试工具说明

### 1. 吞吐量测试

**目的**：测试日志同步优化的吞吐量提升效果

**运行**：
```bash
./benchmark.sh throughput <threads> <durationSeconds>
```

**参数**：
- `threads`: 并发线程数（默认 10）
- `durationSeconds`: 测试持续时间（默认 60）

**输出**：
```
========== Benchmark Results ==========
Test duration: 60000 ms (60.00 seconds)
Total requests: 12000
Successful: 11950
Failed: 50
Success rate: 99.58%
Throughput: 200.00 requests/sec
Total bytes: 1200000
Avg bytes/request: 100.00
========================================
```

### 2. 选主收敛时间测试

**目的**：测试 Leader 故障后的收敛时间

**运行**：
```bash
./benchmark.sh election
```

**操作**：
1. 观察输出中的连续 `SUCCESS`
2. 手动 kill Leader 进程
3. 观察收敛时间输出

**输出**：
```
!!! Leader failure detected at 2026-03-08 10:00:03 !!!
Convergence time: 600 ms
```

### 3. 异构集群测试

**目的**：测试选主优化在异构集群中的效果

**场景**：构造不同 CPU/内存/网络状况的节点

**运行**：
```bash
# 在不稳定节点上运行压力工具
./benchmark.sh stress cpu      # 高 CPU 压力
./benchmark.sh stress memory   # 高内存压力

# 运行异构集群测试
./benchmark.sh hetero <threads> <durationMinutes>
```

**预期**：
- 高分节点（低 CPU、低内存、少断联）更可能成为 Leader
- Leader 切换频率降低
- 集群整体稳定性提升

### 4. 节点压力测试

**目的**：模拟异构节点

**运行**：
```bash
./benchmark.sh stress <type>
```

**类型**：
- `cpu`: 高 CPU 负载（~70-90%）
- `memory`: 高内存使用（~70-80%）
- `network`: 网络压力（配合 tc 命令）

**网络模拟命令**：
```bash
# 模拟延迟
sudo tc qdisc add dev eth0 root netem delay 50ms

# 模拟丢包
sudo tc qdisc add dev eth0 root netem loss 5%

# 清除限制
sudo tc qdisc del dev eth0 root
```

## 完整测试流程

### 基准测试（无优化）

1. 启动原始集群
2. 运行吞吐量测试
3. 运行选主测试
4. 记录结果

### 优化测试（有优化）

1. 启动异构集群：
   - Node 1: 正常
   - Node 2: 高 CPU（`./benchmark.sh stress cpu`）
   - Node 3: 高内存（`./benchmark.sh stress memory`）
   - Node 4: 正常
   - Node 5: 高 CPU + 高内存

2. 运行吞吐量测试
3. 运行选主测试
4. 观察 Leader 选择是否偏向稳定节点
5. 记录结果

## 对比指标

| 指标 | 基准 | 优化 | 提升 |
|-----|------|------|------|
| 吞吐量 | X req/s | Y req/s | (Y-X)/X |
| 选主收敛时间 | X ms | Y ms | (Y-X)/X |
| Leader 切换次数 | N 次 | M 次 | (M-N)/N |
| 稳定节点当选率 | - | P% | 新增指标 |

## 故障排查

### 编译错误

```bash
# 检查 Java 版本
java -version

# 清理并重新编译
mvn clean compile

# 查看详细错误
mvn compile -X
```

### 运行时错误

**连接失败**：
- 检查集群是否启动
- 检查端口是否正确

**Leader 故障未检测**：
- 确认 kill 了正确的进程
- 查看节点日志

**评分未生效**：
- 查看 `NodeMonitor` 日志
- 检查 CPU/内存监控是否正常

## 日志分析

### 查看节点评分

```bash
# 查看节点评分日志
grep "评分计算" raft-java-example/env/example1/nohup.out
```

**示例输出**：
```
节点1 评分计算: CPU=15%, 内存=25%, 断联=100.0分 → 总分=91.35
节点2 评分计算: CPU=85%, 内存=75%, 断联=50.0分 → 总分=65.40
```

### 查看选主过程

```bash
# 查看选举日志
grep "Running for election" raft-java-example/env/*/nohup.out
```

## 预期结果

### 吞吐量提升

- **基准**：1000 req/s
- **优化**：1500-2000 req/s
- **提升**：50-100%

### 选主优化

- **基准**：Leader 随机选择
- **优化**：优先选择稳定节点
- **效果**：Leader 切换次数降低 50%+
