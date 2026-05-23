package com.github.wenweihu86.raft.example.client;

import com.baidu.brpc.client.BrpcProxy;
import com.baidu.brpc.client.RpcClient;
import com.github.wenweihu86.raft.example.server.service.ExampleProto;
import com.github.wenweihu86.raft.example.server.service.ExampleService;

public class LeaderElectionTest {
    public static void main(String[] args) {
        if (args.length < 2) {
            System.out.println("Usage: java LeaderElectionTest <cluster> <leaderPort>");
            System.out.println("  This tool measures leader election convergence time.");
            System.out.println("  Steps:");
            System.out.println("  1. Start the test - it will continuously send requests");
            System.out.println("  2. Kill the leader process manually");
            System.out.println("  3. Observe the convergence time in output");
            System.exit(-1);
        }

        String cluster = args[0];
        int leaderPort = Integer.parseInt(args[1]);

        System.out.println("Leader Election Convergence Test");
        System.out.println("================================");
        System.out.printf("Cluster: %s\n", cluster);
        System.out.printf("Expected Leader Port: %d\n", leaderPort);
        System.out.println("\nInstructions:");
        System.out.println("1. This test will continuously send write requests");
        System.out.println("2. Manually kill the leader process (Ctrl+C or kill command)");
        System.out.println("3. The test will detect leader change and measure convergence time\n");

        RpcClient rpcClient = new RpcClient(cluster);
        ExampleService exampleService = BrpcProxy.getProxy(rpcClient, ExampleService.class);

        long lastSuccessTime = System.currentTimeMillis();
        long leaderDownTime = 0;
        long newLeaderTime = 0;
        boolean leaderDown = false;
        int requestCount = 0;

        System.out.println("Starting continuous requests...");
        System.out.println("Time\t\tRequest#\tLatency(ms)\tStatus");

        while (true) {
            try {
                String key = "election_test_" + requestCount;
                String value = "value_" + System.currentTimeMillis();

                long startTime = System.currentTimeMillis();
                ExampleProto.SetRequest setRequest = ExampleProto.SetRequest.newBuilder()
                        .setKey(key).setValue(value).build();
                ExampleProto.SetResponse setResponse = exampleService.set(setRequest);
                long latency = System.currentTimeMillis() - startTime;

                if (setResponse != null && setResponse.getSuccess()) {
                    if (leaderDown) {
                        newLeaderTime = System.currentTimeMillis();
                        long convergenceTime = newLeaderTime - leaderDownTime;
                        System.out.printf("\n========== Leader Election Result ==========\n");
                        System.out.printf("Leader down detected at: %d ms\n", leaderDownTime);
                        System.out.printf("New leader elected at: %d ms\n", newLeaderTime);
                        System.out.printf("Convergence time: %d ms\n", convergenceTime);
                        System.out.println("============================================\n");
                        leaderDown = false;
                    }
                    lastSuccessTime = System.currentTimeMillis();
                    System.out.printf("%tT\t%d\t\t%d\t\tSUCCESS\n", 
                            new java.util.Date(), requestCount, latency);
                } else {
                    if (!leaderDown) {
                        leaderDown = true;
                        leaderDownTime = System.currentTimeMillis();
                        System.out.printf("\n!!! Leader failure detected at %tT !!!\n", 
                                new java.util.Date());
                    }
                    System.out.printf("%tT\t%d\t\t%d\t\tFAILED (no leader)\n", 
                            new java.util.Date(), requestCount, latency);
                }

                requestCount++;
                Thread.sleep(100);

            } catch (Exception e) {
                if (!leaderDown) {
                    leaderDown = true;
                    leaderDownTime = System.currentTimeMillis();
                    System.out.printf("\n!!! Leader failure detected at %tT !!!\n", 
                            new java.util.Date());
                }
                System.out.printf("%tT\t%d\t\t--\t\tERROR: %s\n", 
                        new java.util.Date(), requestCount, e.getMessage());
                try {
                    Thread.sleep(500);
                } catch (InterruptedException ie) {
                    break;
                }
            }
        }
    }
}
