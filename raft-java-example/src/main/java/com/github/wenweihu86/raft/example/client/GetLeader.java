package com.github.wenweihu86.raft.example.client;

import com.baidu.brpc.client.BrpcProxy;
import com.baidu.brpc.client.RpcClient;
import com.github.wenweihu86.raft.proto.RaftProto;
import com.github.wenweihu86.raft.service.RaftClientService;

public class GetLeader {
    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Usage: java GetLeader <serverAddress>");
            System.err.println("Example: java GetLeader 127.0.0.1:8051");
            System.exit(1);
        }

        String serverAddress = "list://" + args[0];

        RpcClient rpcClient = new RpcClient(serverAddress);
        RaftClientService raftClientService = BrpcProxy.getProxy(rpcClient, RaftClientService.class);

        try {
            RaftProto.GetLeaderRequest request = RaftProto.GetLeaderRequest.newBuilder().build();
            RaftProto.GetLeaderResponse response = raftClientService.getLeader(request);

            if (response.getResCode() == RaftProto.ResCode.RES_CODE_SUCCESS) {
                RaftProto.Endpoint leader = response.getLeader();
                System.out.println(leader.getHost() + ":" + leader.getPort());
            } else {
                System.out.println("unknown");
            }
        } catch (Exception e) {
            System.out.println("unknown");
        } finally {
            rpcClient.stop();
        }
    }
}
