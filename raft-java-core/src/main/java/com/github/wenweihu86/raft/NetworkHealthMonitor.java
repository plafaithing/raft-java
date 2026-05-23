package com.github.wenweihu86.raft;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 网络健康监测器（EMA算法实现）
 * 记录各Peer的RPC成功率和平均延迟
 */
public class NetworkHealthMonitor {
    // Peer健康状态记录
    private static class PeerHealth {
        double successRate = 1.0;  // 成功率（0.0~1.0）
        long avgLatencyMs = 0;    // 平均延迟（毫秒）
    }

    private static final int DEFAULT_BATCH_SIZE = 5;
    private static final int MAX_BATCH_SIZE = 20;
    private static final int MIN_BATCH_SIZE = 1;

    private final Map<String, PeerHealth> peerHealthMap = new ConcurrentHashMap<>();
    private final double alpha; // EMA平滑系数

    public NetworkHealthMonitor(double smoothingFactor) {
        this.alpha = smoothingFactor;
    }

    /**
     * 记录RPC调用结果
     * @param peerId 节点ID
     * @param success 是否成功
     * @param latencyMs 延迟毫秒数
     */
    public void recordRpcResult(int peerId, boolean success, long latencyMs) {
        String peerKey = "peer-" + peerId;
        peerHealthMap.compute(peerKey, (k, v) -> {
            PeerHealth health = (v == null) ? new PeerHealth() : v;
            // EMA更新算法
            health.successRate = alpha * (success ? 1.0 : 0.0) + (1 - alpha) * health.successRate;
            health.avgLatencyMs = (long) (alpha * latencyMs + (1 - alpha) * health.avgLatencyMs);
            return health;
        });
    }

    /**
     * 获取当前推荐的批量大小
     */
    public int getRecommendedBatchSize() {
        if (peerHealthMap.isEmpty()) {
            return MAX_BATCH_SIZE; // 初始阶段使用优等批量
        }

        // 计算集群最差节点的网络质量
        double minSuccessRate = peerHealthMap.values().stream()
                .mapToDouble(h -> h.successRate)
                .min().orElse(0);
        
        long maxLatency = peerHealthMap.values().stream()
                .mapToLong(h -> h.avgLatencyMs)
                .max().orElse(Long.MAX_VALUE);

        // 动态调整策略
        if (minSuccessRate < 0.6 || maxLatency > 200) {
            return MIN_BATCH_SIZE; // 网络差时单条发送
        } else if (minSuccessRate > 0.9 && maxLatency < 50) {
            return MAX_BATCH_SIZE; // 网络极佳时最大批量
        } else {
            return DEFAULT_BATCH_SIZE; // 默认中等批量
        }
    }

    /**
     * 检查集群网络是否总体健康
     */
    public boolean isNetworkStable() {
        return peerHealthMap.values().stream()
                .allMatch(h -> h.successRate > 0.8 && h.avgLatencyMs < 100);
    }
}