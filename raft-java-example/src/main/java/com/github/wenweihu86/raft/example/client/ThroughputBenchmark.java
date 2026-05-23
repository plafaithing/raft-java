package com.github.wenweihu86.raft.example.client;

import com.baidu.brpc.client.BrpcProxy;
import com.baidu.brpc.client.RpcClient;
import com.baidu.brpc.client.RpcClientOptions;
import com.github.wenweihu86.raft.example.server.service.ExampleProto;
import com.github.wenweihu86.raft.example.server.service.ExampleService;
import com.googlecode.protobuf.format.JsonFormat;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

public class ThroughputBenchmark {
    private static final JsonFormat jsonFormat = new JsonFormat();
    private static final AtomicLong successCount = new AtomicLong(0);
    private static final AtomicLong failCount = new AtomicLong(0);
    private static final AtomicLong totalBytes = new AtomicLong(0);

    public static void main(String[] args) throws InterruptedException {
        if (args.length < 3) {
            System.out.println("Usage: java ThroughputBenchmark <cluster> <threadNum> <durationSeconds>");
            System.out.println("  cluster: Raft cluster address, e.g., list://127.0.0.1:8051,127.0.0.1:8052");
            System.out.println("  threadNum: Number of concurrent threads");
            System.out.println("  durationSeconds: Test duration in seconds");
            System.out.println("\nExample:");
            System.out.println("  java ThroughputBenchmark list://127.0.0.1:8051,127.0.0.1:8052 10 60");
            System.out.println("\nThis test measures:");
            System.out.println("  - Throughput: requests per second");
            System.out.println("  - Network efficiency: bytes per request");
            System.exit(-1);
        }

        String cluster = args[0];
        int threadNum = Integer.parseInt(args[1]);
        int durationSeconds = Integer.parseInt(args[2]);

        System.out.println("==========================================");
        System.out.println("  Raft Throughput Benchmark");
        System.out.println("==========================================");
        System.out.printf("Cluster: %s\n", cluster);
        System.out.printf("Threads: %d\n", threadNum);
        System.out.printf("Duration: %d seconds\n", durationSeconds);
        System.out.println("\nStarting benchmark...\n");

        RpcClientOptions clientOptions = new RpcClientOptions();
        clientOptions.setConnectTimeoutMillis(2000);
        clientOptions.setReadTimeoutMillis(10000);
        clientOptions.setWriteTimeoutMillis(2000);
        RpcClient rpcClient = new RpcClient(cluster, clientOptions);
        ExampleService exampleService = BrpcProxy.getProxy(rpcClient, ExampleService.class);

        ExecutorService executor = Executors.newFixedThreadPool(threadNum);
        CountDownLatch latch = new CountDownLatch(threadNum);
        AtomicBoolean running = new AtomicBoolean(true);

        long testStartTime = System.currentTimeMillis();

        for (int i = 0; i < threadNum; i++) {
            final int threadId = i;
            final AtomicBoolean finalRunning = running;
            executor.submit(() -> {
                try {
                    int requestCount = 0;
                    while (finalRunning.get()) {
                        String key = "bench_" + threadId + "_" + requestCount;
                        String value = "v" + System.nanoTime();

                        try {
                            ExampleProto.SetRequest setRequest = ExampleProto.SetRequest.newBuilder()
                                    .setKey(key).setValue(value).build();
                            ExampleProto.SetResponse setResponse = exampleService.set(setRequest);

                            if (setResponse != null && setResponse.getSuccess()) {
                                successCount.incrementAndGet();
                                totalBytes.addAndGet(setRequest.getSerializedSize());
                            } else {
                                failCount.incrementAndGet();
                            }
                            requestCount++;
                        } catch (Exception e) {
                            failCount.incrementAndGet();
                        }
                    }
                } finally {
                    latch.countDown();
                }
            });
        }

        Thread.sleep(durationSeconds * 1000L);
        running.set(false);
        latch.await();
        executor.shutdown();

        long testEndTime = System.currentTimeMillis();
        long testDuration = testEndTime - testStartTime;
        long totalRequests = successCount.get() + failCount.get();
        double throughput = totalRequests * 1000.0 / testDuration;
        double successRate = totalRequests > 0 ? (double) successCount.get() / totalRequests * 100 : 0;
        double avgBytesPerRequest = totalRequests > 0 ? (double) totalBytes.get() / totalRequests : 0;

        System.out.println("\n========== Benchmark Results ==========");
        System.out.printf("Test duration: %d ms (%.2f seconds)\n", testDuration, testDuration / 1000.0);
        System.out.printf("Total requests: %d\n", totalRequests);
        System.out.printf("Successful: %d\n", successCount.get());
        System.out.printf("Failed: %d\n", failCount.get());
        System.out.printf("Success rate: %.2f%%\n", successRate);
        System.out.printf("Throughput: %.2f requests/sec\n", throughput);
        System.out.printf("Total bytes: %d\n", totalBytes.get());
        System.out.printf("Avg bytes/request: %.2f\n", avgBytesPerRequest);
        System.out.println("========================================");

        rpcClient.stop();
    }
}
