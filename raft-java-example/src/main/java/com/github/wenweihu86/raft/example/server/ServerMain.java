package com.github.wenweihu86.raft.example.server;

import com.baidu.brpc.server.RpcServer;
import com.github.wenweihu86.raft.RaftOptions;
import com.github.wenweihu86.raft.example.server.service.ExampleService;
import com.github.wenweihu86.raft.RaftNode;
import com.github.wenweihu86.raft.example.server.service.impl.ExampleServiceImpl;
import com.github.wenweihu86.raft.proto.RaftProto;
import com.github.wenweihu86.raft.service.RaftClientService;
import com.github.wenweihu86.raft.service.RaftConsensusService;
import com.github.wenweihu86.raft.service.impl.RaftClientServiceImpl;
import com.github.wenweihu86.raft.service.impl.RaftConsensusServiceImpl;

import java.util.ArrayList;
import java.util.List;

/**
 * Created by wenweihu86 on 2017/5/9.
 */
public class ServerMain {
    public static void main(String[] args) {
        if (args.length != 3 && args.length != 4) {
            System.out.printf("Usage: ./run_server.sh DATA_PATH CLUSTER CURRENT_NODE [STRESS_TYPE]\n");
            System.out.printf("  STRESS_TYPE: cpu, memory, or none (default: none)\n");
            System.exit(-1);
        }
        // parse args
        // raft data dir
        String dataPath = args[0];
        // peers, format is "host:port:serverId,host2:port2:serverId2"
        String servers = args[1];
        String[] splitArray = servers.split(",");
        List<RaftProto.Server> serverList = new ArrayList<>();
        for (String serverString : splitArray) {
            RaftProto.Server server = parseServer(serverString);
            serverList.add(server);
        }
        // local server
        RaftProto.Server localServer = parseServer(args[2]);
        
        // stress type (optional)
        String stressType = args.length > 3 ? args[3] : "none";

        // 初始化RPCServer
        RpcServer server = new RpcServer(localServer.getEndpoint().getPort());
        // 设置Raft选项，比如：
        // just for test snapshot
        RaftOptions raftOptions = new RaftOptions();
        raftOptions.setDataDir(dataPath);
        raftOptions.setSnapshotMinLogSize(10 * 1024);
        raftOptions.setSnapshotPeriodSeconds(30);
        raftOptions.setMaxSegmentFileSize(1024 * 1024);
        // 应用状态机
        ExampleStateMachine stateMachine = new ExampleStateMachine(raftOptions.getDataDir());
        // 初始化RaftNode
        RaftNode raftNode = new RaftNode(raftOptions, serverList, localServer, stateMachine);
        // 注册Raft节点之间相互调用的服务
        RaftConsensusService raftConsensusService = new RaftConsensusServiceImpl(raftNode);
        server.registerService(raftConsensusService);
        // 注册给Client调用的Raft服务
        RaftClientService raftClientService = new RaftClientServiceImpl(raftNode);
        server.registerService(raftClientService);
        // 注册应用自己提供的服务
        ExampleService exampleService = new ExampleServiceImpl(raftNode, stateMachine);
        server.registerService(exampleService);
        // 启动RPCServer，初始化Raft节点
        server.start();
        raftNode.init();
        
        // 启动压力任务（如果指定）
        if (!"none".equals(stressType)) {
            startStressTask(stressType);
        }
    }
    
    private static void startStressTask(String stressType) {
        System.out.println("Starting stress task: " + stressType);
        
        new Thread(() -> {
            try {
                switch (stressType.toLowerCase()) {
                    case "cpu":
                        cpuStress();
                        break;
                    case "memory":
                        memoryStress();
                        break;
                    default:
                        System.out.println("Unknown stress type: " + stressType);
                        break;
                }
            } catch (Exception e) {
                System.out.println("Stress task error: " + e.getMessage());
                e.printStackTrace();
            }
        }).start();
    }
    
    private static void cpuStress() {
        System.out.println("CPU stress started");
        while (true) {
            double result = 0;
            for (int i = 0; i < 1000000; i++) {
                result += Math.sqrt(i) * Math.sin(i);
            }
            try {
                Thread.sleep(100);
            } catch (InterruptedException e) {
                break;
            }
        }
    }
    
    private static void memoryStress() {
        System.out.println("Memory stress started");
        java.util.List<byte[]> memoryHog = new java.util.ArrayList<>();
        while (true) {
            memoryHog.add(new byte[10 * 1024 * 1024]);
            try {
                Thread.sleep(100);
            } catch (InterruptedException e) {
                break;
            }
        }
    }

    private static RaftProto.Server parseServer(String serverString) {
        String[] splitServer = serverString.split(":");
        String host = splitServer[0];
        Integer port = Integer.parseInt(splitServer[1]);
        Integer serverId = Integer.parseInt(splitServer[2]);
        RaftProto.Endpoint endPoint = RaftProto.Endpoint.newBuilder()
                .setHost(host).setPort(port).build();
        RaftProto.Server.Builder serverBuilder = RaftProto.Server.newBuilder();
        RaftProto.Server server = serverBuilder.setServerId(serverId).setEndpoint(endPoint).build();
        return server;
    }
}
