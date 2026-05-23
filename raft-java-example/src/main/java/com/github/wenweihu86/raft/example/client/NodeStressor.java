package com.github.wenweihu86.raft.example.client;

import java.util.ArrayList;
import java.util.List;

public class NodeStressor {
    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: java NodeStressor <type>");
            System.out.println("  type: cpu, memory, network");
            System.out.println("\nThis tool simulates unstable node by consuming resources.");
            System.out.println("Use this to create heterogeneous cluster for testing leader election.");
            System.out.println("\nExamples:");
            System.out.println("  java NodeStressor cpu      # Simulate high CPU load");
            System.out.println("  java NodeStressor memory   # Simulate high memory usage");
            System.out.println("  java NodeStressor network   # Simulate network issues");
            System.exit(-1);
        }

        String type = args[0];

        System.out.println("==========================================");
        System.out.println("  Node Stressor Tool");
        System.out.println("==========================================");
        System.out.printf("Stress type: %s\n", type);
        System.out.println("\nStarting stress test...");
        System.out.println("Press Ctrl+C to stop.\n");

        switch (type.toLowerCase()) {
            case "cpu":
                cpuStress();
                break;
            case "memory":
                memoryStress();
                break;
            case "network":
                networkStress();
                break;
            default:
                System.out.println("Unknown stress type: " + type);
                System.exit(1);
        }
    }

    private static void cpuStress() {
        System.out.println("CPU Stress: Running intensive calculations...");
        System.out.println("This will consume ~70-90% CPU\n");

        int iteration = 0;
        while (true) {
            double result = 0;
            for (int i = 0; i < 1000000; i++) {
                result += Math.sqrt(i) * Math.sin(i) * Math.cos(i);
            }
            
            iteration++;
            if (iteration % 10 == 0) {
                System.out.printf("CPU stress iteration: %d, result: %.2f\n", iteration, result);
            }
            
            try {
                Thread.sleep(100);
            } catch (InterruptedException e) {
                System.out.println("\nCPU stress stopped.");
                return;
            }
        }
    }

    private static void memoryStress() {
        System.out.println("Memory Stress: Allocating memory...");
        System.out.println("This will consume ~70-80% memory\n");

        List<byte[]> memoryHog = new ArrayList<>();
        int iteration = 0;

        while (true) {
            try {
                memoryHog.add(new byte[10 * 1024 * 1024]); // 10MB per iteration
                
                iteration++;
                if (iteration % 10 == 0) {
                    long totalMemory = memoryHog.size() * 10L * 1024 * 1024;
                    System.out.printf("Memory stress iteration: %d, allocated: %d MB\n", 
                                    iteration, totalMemory / (1024 * 1024));
                }
                
                Thread.sleep(100);
            } catch (OutOfMemoryError e) {
                System.out.println("\nMemory limit reached, clearing half of allocations...");
                memoryHog = new ArrayList<>(memoryHog.subList(0, memoryHog.size() / 2));
            } catch (InterruptedException e) {
                System.out.println("\nMemory stress stopped.");
                return;
            }
        }
    }

    private static void networkStress() {
        System.out.println("Network Stress: Simulating network issues...");
        System.out.println("This tool just runs, use 'tc' command to simulate network delay/loss.\n");
        System.out.println("Example commands:");
        System.out.println("  sudo tc qdisc add dev eth0 root netem delay 50ms    # 50ms delay");
        System.out.println("  sudo tc qdisc add dev eth0 root netem loss 5%     # 5% packet loss");
        System.out.println("  sudo tc qdisc del dev eth0 root                   # remove limits\n");

        int iteration = 0;
        while (true) {
            iteration++;
            if (iteration % 10 == 0) {
                System.out.printf("Network stress iteration: %d\n", iteration);
            }
            
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                System.out.println("\nNetwork stress stopped.");
                return;
            }
        }
    }
}
