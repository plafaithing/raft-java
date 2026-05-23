# WSL 单机模拟异构集群指南

## 问题

在 WSL 单机上运行多个 Raft 节点，如何模拟不同节点的负载差异？

## 解决方案

### 方案 1：使用 cgroups（推荐）

cgroups 可以精确控制进程的资源使用，适合在单机上模拟异构节点。

#### 安装 cgroup-tools

```bash
sudo apt-get update
sudo apt-get install -y cgroup-tools
```

#### 设置异构集群

```bash
cd raft-java-example

# 1. 创建 cgroups（需要 root 权限）
sudo ./setup_hetero.sh setup

# 2. 启动 Raft 集群
./deploy.sh

# 3. 将进程绑定到 cgroups
sudo ./setup_hetero.sh bind

# 4. 查看状态
sudo ./setup_hetero.sh status

# 5. 运行测试
./benchmark.sh throughput 10 60

# 6. 清理
sudo ./setup_hetero.sh cleanup
```

#### 节点资源配置

| 节点 | 端口 | CPU 配额 | 内存限制 | 预期角色 |
|-----|------|---------|---------|---------|
| Node 1 | 8051 | 100% (100000) | 2GB | Leader |
| Node 2 | 8052 | 30% (30000) | 1GB | Follower |
| Node 3 | 8053 | 60% (60000) | 1GB | Follower |
| Node 4 | 8054 | 100% (100000) | 2GB | Leader 候选 |
| Node 5 | 8055 | 50% (50000) | 512MB | Follower |

#### cgroups 原理

```
CPU 配额 = cpu.cfs_quota_us / cpu.cfs_period_us * 100%
例如：30000 / 100000 = 30% CPU
```

### 方案 2：使用 stress-ng

#### 安装 stress-ng

```bash
sudo apt-get install -y stress-ng
```

#### 针对特定进程

```bash
# 找到进程 PID
lsof -ti:8052

# 对该进程的 CPU 使用率进行限制（使用 cgroups）
sudo cgcreate -g cpu:/raft_node2
sudo cgset -r cpu.cfs_quota_us=30000 raft_node2
sudo cgset -r cpu.cfs_period_us=100000 raft_node2
sudo cgclassify -g cpu:raft_node2 $(lsof -ti:8052)
```

### 方案 3：使用 nice/ionice

#### 降低进程优先级

```bash
# 降低 Node 2 的 CPU 优先级
sudo renice +19 -p $(lsof -ti:8052)

# 降低 Node 2 的 I/O 优先级
sudo ionice -c 3 -p $(lsof -ti:8052)
```

### 方案 4：使用 taskset（CPU 亲和性）

#### 绑定到特定 CPU 核心

```bash
# Node 1: 绑定到 CPU 0-1
sudo taskset -cp 0-1 $(lsof -ti:8051)

# Node 2: 绑定到 CPU 2（限制资源）
sudo taskset -cp 2 $(lsof -ti:8052)

# Node 3: 绑定到 CPU 3
sudo taskset -cp 3 $(lsof -ti:8053)
```

## 完整测试流程

### 1. 准备环境

```bash
# 进入项目目录
cd d:/workplace/java/raft1/raft-java-master/raft-java-example

# 编译项目
cd ..
mvn clean package -DskipTests
cd raft-java-example

# 安装依赖
sudo apt-get install -y cgroup-tools
```

### 2. 设置异构集群

```bash
# 创建 cgroups
sudo ./setup_hetero.sh setup

# 启动集群
./deploy.sh

# 绑定进程到 cgroups
sudo ./setup_hetero.sh bind

# 查看状态
sudo ./setup_hetero.sh status
```

### 3. 运行测试

```bash
# 测试吞吐量
./benchmark.sh throughput 10 60

# 测试选主收敛
./benchmark.sh election
# 然后手动 kill Leader，观察收敛时间

# 测试异构集群
./benchmark.sh hetero 10 60
```

### 4. 观察结果

#### 查看节点评分

```bash
grep "评分计算" env/*/nohup.out
```

**预期输出**：
```
节点1 评分计算: CPU=10%, 内存=20%, 断联=100.0分 → 总分=95.00
节点2 评分计算: CPU=85%, 内存=80%, 断联=70.0分 → 总分=55.00
节点3 评分计算: CPU=50%, 内存=50%, 断联=80.0分 → 总分=70.00
节点4 评分计算: CPU=12%, 内存=22%, 断联=95.0分 → 总分=92.00
节点5 评分计算: CPU=70%, 内存=90%, 断联=60.0分 → 总分=50.00
```

#### 验证选主偏好

```bash
# 多次 kill Leader，观察新 Leader
# 预期：Node 1 和 Node 4（高分节点）更可能成为 Leader
```

### 5. 清理环境

```bash
# 停止集群
./kill_raft.sh

# 清理 cgroups
sudo ./setup_hetero.sh cleanup
```

## 故障排查

### cgroups 不工作

```bash
# 检查 cgroups 挂载
mount | grep cgroup

# 检查 cgroup-tools 是否安装
which cgcreate

# 查看内核日志
dmesg | grep cgroup
```

### 进程未绑定到 cgroups

```bash
# 检查进程是否在 cgroup 中
cat /proc/<pid>/cgroup

# 手动绑定
sudo cgclassify -g cpu,memory:raft_node2 $(lsof -ti:8052)
```

### 资源限制未生效

```bash
# 查看 cgroup 配置
cat /sys/fs/cgroup/cpu/raft_node2/cpu.cfs_quota_us
cat /sys/fs/cgroup/memory/raft_node2/memory.limit_in_bytes

# 查看 cgroup 中的进程
cat /sys/fs/cgroup/cpu/raft_node2/tasks
```

## 对比实验

### 基准组（无优化）

```bash
# 启动普通集群（不使用 cgroups）
./deploy.sh

# 运行测试
./benchmark.sh throughput 10 60
./benchmark.sh election
```

### 优化组（有优化）

```bash
# 设置异构集群
sudo ./setup_hetero.sh setup
./deploy.sh
sudo ./setup_hetero.sh bind

# 运行测试
./benchmark.sh throughput 10 60
./benchmark.sh election
```

## 预期结果

| 指标 | 基准组 | 优化组 | 提升 |
|-----|-------|-------|------|
| 吞吐量 | 1000 req/s | 1500 req/s | 50% |
| 选主收敛时间 | 500ms | 500ms | 持平 |
| Leader 切换次数 | 10 次 | 5 次 | 50% |
| 稳定节点当选率 | 20% | 80% | 300% |
