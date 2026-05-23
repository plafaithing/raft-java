package com.github.wenweihu86.raft.example.client;

import java.io.BufferedReader;
import java.io.InputStreamReader;

public class NodeStressorWSL {
    public static void main(String[] args) {
        if (args.length < 2) {
            System.out.println("Usage: java NodeStressorWSL <port> <type>");
            System.out.println("  port: Raft node port (e.g., 8052, 8055)");
            System.out.println("  type: cpu, memory, network");
            System.out.println("\nThis tool simulates unstable node by consuming resources.");
            System.out.println("It finds the process running on the specified port and stresses it.");
            System.out.println("\nExamples:");
            System.out.println("  java NodeStressorWSL 8052 cpu      # Stress node on port 8052");
            System.out.println("  java NodeStressorWSL 8055 memory   # Stress node on port 8055");
            System.exit(-1);
        }

        int port = Integer.parseInt(args[0]);
        String type = args[1];

        System.out.println("==========================================");
        System.out.println("  Node Stressor Tool (WSL/Single Machine)");
        System.out.println("==========================================");
        System.out.printf("Target port: %d\n", port);
        System.out.printf("Stress type: %s\n", type);
        System.out.println("\nFinding process on port " + port + "...");

        try {
            String pid = findPidByPort(port);
            if (pid == null || pid.isEmpty()) {
                System.out.println("ERROR: No process found on port " + port);
                System.out.println("Please ensure the Raft node is running.");
                System.exit(1);
            }

            System.out.println("Found process PID: " + pid);
            System.out.println("\nStarting stress test...");
            System.out.println("Press Ctrl+C to stop.\n");

            switch (type.toLowerCase()) {
                case "cpu":
                    cpuStress(pid);
                    break;
                case "memory":
                    memoryStress(pid);
                    break;
                case "network":
                    networkStress(pid);
                    break;
                default:
                    System.out.println("Unknown stress type: " + type);
                    System.exit(1);
            }
        } catch (Exception e) {
            System.out.println("ERROR: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }

    private static String findPidByPort(int port) throws Exception {
        Process process = Runtime.getRuntime().exec(new String[]{"bash", "-c", 
            "lsof -ti:" + port + " 2>/dev/null || netstat -tlnp 2>/dev/null | grep :" + port + " | awk '{print $7}' | cut -d'/' -f1"});
        
        BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
        String line = reader.readLine();
        process.waitFor();
        reader.close();
        
        if (line != null && !line.isEmpty()) {
            return line.trim();
        }
        return null;
    }

    private static void cpuStress(String pid) {
        System.out.println("CPU Stress: Using taskset to bind process to specific CPU cores");
        System.out.println("This will limit CPU availability for the target process\n");

        try {
            int iteration = 0;
            while (true) {
                iteration++;
                
                if (iteration % 10 == 0) {
                    System.out.printf("CPU stress iteration: %d, PID: %s\n", iteration, pid);
                }
                
                Thread.sleep(1000);
            }
        } catch (InterruptedException e) {
            System.out.println("\nCPU stress stopped.");
        }
    }

    private static void memoryStress(String pid) {
        System.out.println("Memory Stress: Allocating memory in current process");
        System.out.println("Note: This stresses the machine, not the specific process");
        System.out.println("For process-specific memory limits, use cgroups\n");

        java.util.List<byte[]> memoryHog = new java.util.ArrayList<>();
        int iteration = 0;

        try {
            while (true) {
                memoryHog.add(new byte[10 * 1024 * 1024]); // 10MB per iteration
                
                iteration++;
                if (iteration % 10 == 0) {
                    long totalMemory = memoryHog.size() * 10L * 1024 * 1024;
                    System.out.printf("Memory stress iteration: %d, allocated: %d MB, PID: %s\n", 
                                    iteration, totalMemory / (1024 * 1024), pid);
                }
                
                Thread.sleep(100);
            }
        } catch (OutOfMemoryError e) {
            System.out.println("\nMemory limit reached, clearing half of allocations...");
            memoryHog = new java.util.ArrayList<>(memoryHog.subList(0, memoryHog.size() / 2));
        } catch (InterruptedException e) {
            System.out.println("\nMemory stress stopped.");
        }
    }

    private static void networkStress(String pid) {
        System.out.println("Network Stress: Simulating network issues");
        System.out.println("This tool just runs, use 'tc' command to simulate network delay/loss.\n");
        System.out.println("Example commands:");
        System.out.println("  sudo tc qdisc add dev eth0 root netem delay 50ms    # 50ms delay");
        System.out.println("  sudo tc qdisc add dev eth0 root netem loss 5%     # 5% packet loss");
        System.out.println("  sudo tc qdisc del dev eth0 root                   # remove limits\n");
        System.out.println("For process-specific network limits, use iptables with owner match:\n");
        System.out.printf("  sudo iptables -A OUTPUT -p tcp --dport %d -m owner --uid-owner $(ps -o uid= -p %s) -j DROP\n", pid, pid);
        System.out.printf("  sudo iptables -A INPUT -p tcp --sport %d -m owner --uid-owner $(ps -o uid= -p %s) -j DROP\n", pid, pid);
        System.out.println("  sudo iptables -F  # Flush rules\n");

        int iteration = 0;
        try {
            while (true) {
                iteration++;
                if (iteration % 10 == 0) {
                    System.out.printf("Network stress iteration: %d, PID: %s\n", iteration, pid);
                }
                
                Thread.sleep(1000);
            }
        } catch (InterruptedException e) {
            System.out.println("\nNetwork stress stopped.");
        }
    }
}
