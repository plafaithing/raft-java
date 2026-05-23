package com.github.wenweihu86.raft.example.client;

import com.baidu.brpc.client.BrpcProxy;
import com.baidu.brpc.client.RpcClient;
import com.github.wenweihu86.raft.example.server.service.ExampleProto;
import com.github.wenweihu86.raft.example.server.service.ExampleService;
import com.googlecode.protobuf.format.JsonFormat;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicLong;

public class BenchmarkTool {
    private static final JsonFormat jsonFormat = new JsonFormat();
    private static final AtomicLong totalLatency = new AtomicLong(0);
    private static final AtomicLong successCount = new AtomicLong(0);
    private static final AtomicLong failCount = new AtomicLong(0);

    public static void main(String[] args) throws InterruptedException {
        if (args.length < 3) {
            System.out.println("Usage: java BenchmarkTool <cluster> <threadNum> <requestNum> [mode]");
            System.out.println("  mode: latency - test latency, throughput - test throughput");
            System.exit(-1);
        }

        String cluster = args[0];
        int threadNum = Integer.parseInt(args[1]);
        int requestNum = Integer.parseInt(args[2]);
        String mode = args.length > 3 ? args[3] : "throughput";

        System.out.printf("Benchmark started: cluster=%s, threads=%d, requests=%d, mode=%s\n",
                cluster, threadNum, requestNum, mode);

        RpcClient rpcClient = new RpcClient(cluster);
        ExampleService exampleService = BrpcProxy.getProxy(rpcClient, ExampleService.class);

        ExecutorService executor = Executors.newFixedThreadPool(threadNum);
        CountDownLatch latch = new CountDownLatch(threadNum);

        long testStartTime = System.currentTimeMillis();

        for (int i = 0; i < threadNum; i++) {
            final int threadId = i;
            executor.submit(() -> {
                try {
                    for (int j = 0; j < requestNum / threadNum; j++) {
                        String key = "benchmark_" + threadId + "_" + j;
                        String value = "value_" + System.nanoTime();

                        long startTime = System.currentTimeMillis();
                        try {
                            ExampleProto.SetRequest setRequest = ExampleProto.SetRequest.newBuilder()
                                    .setKey(key).setValue(value).build();
                            ExampleProto.SetResponse setResponse = exampleService.set(setRequest);

                            long latency = System.currentTimeMillis() - startTime;
                            totalLatency.addAndGet(latency);

                            if (setResponse != null && setResponse.getSuccess()) {
                                successCount.incrementAndGet();
                            } else {
                                failCount.incrementAndGet();
                            }

                            if ("latency".equals(mode)) {
                                System.out.printf("request %d: latency=%d ms, success=%b\n",
                                        j, latency, setResponse != null && setResponse.getSuccess());
                            }
                        } catch (Exception e) {
                            failCount.incrementAndGet();
                            long latency = System.currentTimeMillis() - startTime;
                            totalLatency.addAndGet(latency);
                        }
                    }
                } finally {
                    latch.countDown();
                }
            });
        }

        latch.await();
        long testEndTime = System.currentTimeMillis();
        executor.shutdown();

        long totalRequests = successCount.get() + failCount.get();
        long testDuration = testEndTime - testStartTime;
        double throughput = totalRequests * 1000.0 / testDuration;
        double avgLatency = totalRequests > 0 ? (double) totalLatency.get() / totalRequests : 0;

        System.out.println("\n========== Benchmark Results ==========");
        System.out.printf("Total time: %d ms\n", testDuration);
        System.out.printf("Total requests: %d\n", totalRequests);
        System.out.printf("Success: %d\n", successCount.get());
        System.out.printf("Failed: %d\n", failCount.get());
        System.out.printf("Throughput: %.2f requests/sec\n", throughput);
        System.out.printf("Average latency: %.2f ms\n", avgLatency);
        System.out.println("========================================");

        rpcClient.stop();
    }
}
