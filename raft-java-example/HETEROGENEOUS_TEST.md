# 异构集群测试方案

## 测试目标

验证选主优化算法在异构集群中的效果：
- 优先选择稳定节点（低 CPU、低内存、少断联）
- 降低 Leader 切换频率
- 提升集群整体稳定性

## 异构集群配置

### 节点配置示例

| 节点 | CPU 负载 | 内存负载 | 网络状况 | 预期角色 |
|-----|---------|---------|---------|---------|
| Node 1 (8051) | 低 (10-20%) | 低 (20-30%) | 稳定 | Leader |
| Node 2 (8052) | 高 (70-90%) | 高 (70-80%) | 不稳 | Follower |
| Node 3 (8053) | 中 (40-50%) | 中 (40-50%) | 中等 | Follower |
| Node 4 (8054) | 低 (10-20%) | 低 (20-30%) | 稳定 | Leader 候选 |
| Node 5 (8055) | 高 (70-90%) | 高 (70-80%) | 不稳 | Follower |

### 模拟异构节点的方法

#### 方法1：使用 stress 工具（推荐）

```bash
# 安装 stress
sudo apt-get install stress

# 对 Node 2 模拟高 CPU
stress --cpu 4 --timeout 300s

# 对 Node 2 模拟高内存
stress --vm 2 --vm-bytes 512M --timeout 300s
```

#### 方法2：使用 Java 压测工具

```java
// 在节点启动时运行高负载任务
public class NodeStressor {
    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: java NodeStressor <type>");
            System.out.println("  type: cpu, memory, network");
            System.exit(-1);
        }

        String type = args[0];
        System.out.println("Starting stress test: " + type);

        switch (type) {
            case "cpu":
                cpuStress();
                break;
            case "memory":
                memoryStress();
                break;
            case "network":
                networkStress();
                break;
        }
    }

    private static void cpuStress() {
        while (true) {
            double result = 0;
            for (int i = 0; i < 1000000; i++) {
                result += Math.sqrt(i) * Math.sin(i);
            }
        }
        try {
            Thread.sleep(100);
        } catch (InterruptedException e) {
            break;
        }
    }

    private static void memoryStress() {
        List<byte[]> memoryHog = new ArrayList<>();
        while (true) {
            memoryHog.add(new byte[10 * 1024 * 1024]); // 10MB
            try {
                Thread.sleep(100);
            } catch (InterruptedException e) {
                break;
            }
        }
    }

    private static void networkStress() {
        while (true) {
            try {
                Thread.sleep(100);
            } catch (InterruptedException e) {
                break;
            }
        }
    }
}
```

#### 方法3：使用 tc 模拟网络不稳定

```bash
# 对 Node 2 模拟网络延迟
sudo tc qdisc add dev eth0 root netem delay 50ms

# 对 Node 2 模拟网络丢包
sudo tc qdisc add dev eth0 root netem loss 5%

# 清除网络限制
sudo tc qdisc del dev eth0 root
```

## 测试步骤

### 1. 启动异构集群

```bash
# 启动所有节点
cd raft-java-example
./deploy.sh

# 在 Node 2 上启动高负载（模拟不稳定节点）
java -cp "conf:lib/*" com.github.wenweihu86.raft.example.client.NodeStressor cpu

# 在 Node 5 上启动高负载（模拟不稳定节点）
java -cp "conf:lib/*" com.github.wenweihu86.raft.example.client.NodeStressor memory
```

### 2. 运行测试

```bash
# 测试吞吐量（10线程，60秒）
./benchmark.sh throughput 10 60

# 测试选主收敛
./benchmark.sh election
# 然后手动 kill Leader，观察新 Leader 是否是稳定节点
```

### 3. 观察 Leader 选择

查看日志中的节点评分：

```
节点1 评分计算: CPU=15%, 内存=25%, 断联=100.0分 → 总分=91.35
节点2 评分计算: CPU=85%, 内存=75%, 断联=50.0分 → 总分=65.40
节点3 评分计算: CPU=45%, 内存=50%, 断联=80.0分 → 总分=70.80
节点4 评分计算: CPU=12%, 内存=22%, 断联=95.0分 → 总分=88.28
节点5 评分计算: CPU=80%, 内存=70%, 断联=40.0分 → 总分=58.40
```

**预期**：Node 1 和 Node 4（高分节点）更可能成为 Leader

### 4. 测试 Leader 故障场景

```bash
# 1. 观察当前 Leader（假设是 Node 1）
# 2. 手动 kill Node 1
# 3. 观察新 Leader 是否是 Node 4（第二高分节点）
# 4. 重复多次，验证选主算法的稳定性
```

## 测试指标

| 指标 | 说明 | 预期结果 |
|-----|------|---------|
| Leader 切换次数 | 测试期间 Leader 变更次数 | 优化后应降低 |
| 高分节点当选率 | 高分节点成为 Leader 的比例 | 优化后应提高 |
| 选主收敛时间 | Leader 故障到新 Leader 选出时间 | 应保持稳定 |
| 集群吞吐量 | 整体吞吐量 | 应保持稳定 |

## 对比实验

| 实验组 | 配置 | 预期结果 |
|-------|------|---------|
| 基准组 | 原始 Raft（无优化） | Leader 随机选择 |
| 优化组 | 选主优化 + 异构集群 | 优先选择稳定节点 |

## 验证点

1. **稳定性评分生效**：
   - 断联次数多的节点评分降低
   - 高 CPU/内存的节点评分降低

2. **选主偏好生效**：
   - 高分节点更可能成为 Leader
   - 低分节点很少成为 Leader

3. **动态调整生效**：
   - 节点状态变化后评分自动更新
   - 选主策略实时反映节点状态
