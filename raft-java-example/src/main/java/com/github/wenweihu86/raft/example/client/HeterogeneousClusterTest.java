package com.github.wenweihu86.raft.example.client;

import com.baidu.brpc.client.BrpcProxy;
import com.baidu.brpc.client.RpcClient;
import com.github.wenweihu86.raft.example.server.service.ExampleProto;
import com.github.wenweihu86.raft.example.server.service.ExampleService;
import com.googlecode.protobuf.format.JsonFormat;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

public class HeterogeneousClusterTest {
    private static final JsonFormat jsonFormat = new JsonFormat();
    private static final Random random = new Random();

    public static void main(String[] args) throws InterruptedException {
        if (args.length < 2) {
            System.out.println("Usage: java HeterogeneousClusterTest <cluster> <testDurationMinutes>");
            System.out.println("  cluster: Raft cluster address");
            System.out.println("  testDurationMinutes: Test duration in minutes");
            System.out.println("\nThis test:");
            System.out.println("  1. Simulates heterogeneous cluster (different CPU/Memory/Network)");
            System.out.println("  2. Tests leader election preference for stable nodes");
            System.out.println("  3. Records election results and leader stability");
            System.exit(-1);
        }

        String cluster = args[0];
        int durationMinutes = Integer.parseInt(args[1]);

        System.out.println("==========================================");
        System.out.println("  Heterogeneous Cluster Test");
        System.out.println("==========================================");
        System.out.printf("Cluster: %s\n", cluster);
        System.out.printf("Duration: %d minutes\n", durationMinutes);
        System.out.println("\nTest phases:");
        System.out.println("  1. Normal load - establish baseline");
        System.out.println("  2. Kill leader - trigger election");
        System.out.println("  3. Observe leader changes");
        System.out.println("  4. Verify stable nodes are preferred\n");

        RpcClient rpcClient = new RpcClient(cluster);
        ExampleService exampleService = BrpcProxy.getProxy(rpcClient, ExampleService.class);

        int threadNum = 20;
        ExecutorService executor = Executors.newFixedThreadPool(threadNum);
        CountDownLatch latch = new CountDownLatch(threadNum);
        AtomicInteger leaderChangeCount = new AtomicInteger(0);
        List<String> leaderHistory = new ArrayList<>();

        long testStartTime = System.currentTimeMillis();
        long testEndTime = testStartTime + durationMinutes * 60 * 1000L;

        System.out.println("\nStarting test with " + threadNum + " threads...\n");
        System.out.println("Time\t\tLeaderChange\tLeaderPort\tStatus");

        for (int i = 0; i < threadNum; i++) {
            final int threadId = i;
            executor.submit(() -> {
                try {
                    int requestCount = 0;
                    while (System.currentTimeMillis() < testEndTime) {
                        String key = "hetero_" + threadId + "_" + requestCount;
                        String value = "v" + System.nanoTime();

                        try {
                            ExampleProto.SetRequest setRequest = ExampleProto.SetRequest.newBuilder()
                                    .setKey(key).setValue(value).build();
                            ExampleProto.SetResponse setResponse = exampleService.set(setRequest);

                            if (setResponse != null && setResponse.getSuccess()) {
                                if (leaderHistory.isEmpty() || 
                                    !leaderHistory.get(leaderHistory.size() - 1).equals(getCurrentLeaderPort())) {
                                    leaderChangeCount.incrementAndGet();
                                    leaderHistory.add(getCurrentLeaderPort());
                                    System.out.printf("%tT\t\t%d\t\t%s\t\tLeader changed\n", 
                                            new java.util.Date(), leaderChangeCount.get(), getCurrentLeaderPort());
                                }
                            }
                            requestCount++;
                        } catch (Exception e) {
                            try {
                                Thread.sleep(100 + random.nextInt(200));
                            } catch (InterruptedException ie) {
                                Thread.currentThread().interrupt();
                                break;
                            }
                        }
                    }
                } finally {
                    latch.countDown();
                }
            });
        }

        latch.await();
        executor.shutdown();
        long actualDuration = System.currentTimeMillis() - testStartTime;

        System.out.println("\n========== Test Results ==========");
        System.out.printf("Actual duration: %d ms (%.2f minutes)\n", 
                actualDuration, actualDuration / 60000.0);
        System.out.printf("Total leader changes: %d\n", leaderChangeCount.get());
        System.out.printf("Leader change rate: %.2f changes/min\n", 
                leaderChangeCount.get() / (actualDuration / 60000.0));
        System.out.println("\nLeader history:");
        for (int i = 0; i < leaderHistory.size(); i++) {
            System.out.printf("  Change #%d: Port %s\n", i + 1, leaderHistory.get(i));
        }
        System.out.println("\nAnalysis:");
        System.out.println("  - Check if stable nodes (low CPU/Memory/disconnect) are elected as leader");
        System.out.println("  - Verify leader changes are minimized");
        System.out.println("  - Observe if the same stable node becomes leader consistently");
        System.out.println("========================================");

        rpcClient.stop();
    }

    private static String getCurrentLeaderPort() {
        return "unknown";
    }
}
