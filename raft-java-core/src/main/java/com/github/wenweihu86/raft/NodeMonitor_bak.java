package com.github.wenweihu86.raft;
import oshi.SystemInfo;               // 系统信息入口类
import oshi.hardware.CentralProcessor; // CPU信息
import oshi.hardware.GlobalMemory;     // 内存信息
import oshi.hardware.HardwareAbstractionLayer; // 硬件抽象层
import java.util.Map;                   // Map接口
import java.util.concurrent.ConcurrentHashMap; // 线程安全的Map实现
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.function.BiFunction;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.googlecode.protobuf.format.JsonFormat;


// 新增 NodeMonitor.java
public class NodeMonitor_bak {
    private final Integer nodeId = 0;
    private final Map<Integer, Integer> disconnectHistory = new ConcurrentHashMap<>();
    private final SystemInfo systemInfo;
    private static final Logger LOG = LoggerFactory.getLogger(NodeMonitor.class);
    private static final JsonFormat jsonFormat = new JsonFormat();

    public NodeMonitor_bak() {
        try {
            systemInfo = new SystemInfo();
            scheduleDisconnectDecay();
        } catch (Exception e) {
            throw new RuntimeException("Failed to initialize OSHI", e);
        }
    }
    
    // 获取CPU使用率（使用OSHI库）
    public double getCpuUsage() {
        CentralProcessor processor = systemInfo.getHardware().getProcessor();
        long[] prevTicks = processor.getSystemCpuLoadTicks();
        try {
            Thread.sleep(100); // 采样间隔
        } catch (InterruptedException ignored) {}
        double cpuLoad = processor.getSystemCpuLoadBetweenTicks(prevTicks);
        return cpuLoad * 100; // 百分比
    }

    // 获取内存使用率
    public double getMemoryUsage() {
        GlobalMemory memory = systemInfo.getHardware().getMemory();
        double used = memory.getTotal() - memory.getAvailable();
        return (used / memory.getTotal()) * 100;
    }

    // 记录节点断联次数（在心跳响应失败时调用）
    public void recordDisconnect(Integer nodeId) {
        disconnectHistory.put(nodeId, disconnectHistory.getOrDefault(nodeId, 0) + 1);
    }

    // 获取节点稳定性评分（断联次数越少，评分越高）
    public double getStabilityScore(Integer nodeId) {
        int disconnects = disconnectHistory.getOrDefault(nodeId, 0);
        return Math.max(0, 100 - disconnects * 10); // 每次断联扣10分
    }

    @FunctionalInterface
    public interface TriFunction<T, U, R> {
        R apply(T t, U u);
    }

    // 在 NodeMonitor 中添加定时任务
    public void scheduleDisconnectDecay() {
        Executors.newScheduledThreadPool(1).scheduleAtFixedRate(() -> {
            disconnectHistory.replaceAll((nodeId, count) -> Math.max(0, count / 2));
        }, 1, 1, TimeUnit.HOURS); // 每小时衰减一次
        //记录日志
        LOG.info("Disconnect counts decayed: {}", disconnectHistory);
        /*Executors.newScheduledThreadPool(1).scheduleAtFixedRate(
            new Runnable() {
            @Override
            public void run() {
            // 使用自定义的三元函数接口
                disconnectHistory.replaceAll(new BiFunction<Integer, Integer, Integer>() {
                    @Override
                    public Integer apply(Integer nodeId, Integer count) {
                        return Math.max(0, count / 2);
                    }
                });
            }     
        },
        1,
        1,
        TimeUnit.HOURS
        );*/
    }
}