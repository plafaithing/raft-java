package com.github.wenweihu86.raft.example.server.service.impl;

import com.baidu.brpc.client.BrpcProxy;
import com.baidu.brpc.client.RpcClient;
import com.baidu.brpc.client.RpcClientOptions;
import com.baidu.brpc.client.instance.Endpoint;
import com.github.wenweihu86.raft.Peer;
import com.github.wenweihu86.raft.example.server.ExampleStateMachine;
import com.github.wenweihu86.raft.example.server.service.ExampleProto;
import com.github.wenweihu86.raft.example.server.service.ExampleService;
import com.github.wenweihu86.raft.RaftNode;
import com.github.wenweihu86.raft.proto.RaftProto;
import com.googlecode.protobuf.format.JsonFormat;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

/**
 * Created by wenweihu86 on 2017/5/9.
 */
public class ExampleServiceImpl implements ExampleService {

    private static final Logger LOG = LoggerFactory.getLogger(ExampleServiceImpl.class);
    private static JsonFormat jsonFormat = new JsonFormat();

    private RaftNode raftNode;
    private ExampleStateMachine stateMachine;
    private ExampleService leaderExampleService = null;
    private int leaderId = -1;
    private RpcClient leaderRpcClient = null;
    private Lock leaderLock = new ReentrantLock();

    public ExampleServiceImpl(RaftNode raftNode, ExampleStateMachine stateMachine) {
        this.raftNode = raftNode;
        this.stateMachine = stateMachine;
    }

    /*private void onLeaderChangeEvent() {
        if (raftNode.getLeaderId() != -1
                && raftNode.getLeaderId() != raftNode.getLocalServer().getServerId()
                && leaderId != raftNode.getLeaderId()) {
            leaderLock.lock();
            if (leaderId != -1 && leaderRpcClient != null) {
                leaderRpcClient.stop();
                leaderRpcClient = null;
                leaderId = -1;
            }
            leaderId = raftNode.getLeaderId();
            Peer peer = raftNode.getPeerMap().get(leaderId);
            Endpoint endpoint = new Endpoint(peer.getServer().getEndpoint().getHost(),
                    peer.getServer().getEndpoint().getPort());
            RpcClientOptions rpcClientOptions = new RpcClientOptions();
            rpcClientOptions.setGlobalThreadPoolSharing(true);
            leaderRpcClient = new RpcClient(endpoint, rpcClientOptions);
            leaderLock.unlock();
        }
    }*/

    /*private void onLeaderChangeEvent() {
        int currentLeaderId = raftNode.getLeaderId();
        int localServerId = raftNode.getLocalServer().getServerId();
        // 1. 快速路径检查：无需处理 Leader 变更
        if (currentLeaderId == -1 || currentLeaderId == localServerId || currentLeaderId == leaderId) {
            return;
        }
    
        leaderLock.lock();
        try {
            // 2. 双重检查锁（Double-Checked Locking）
            if (currentLeaderId == leaderId) {
                return;
            }
    
            // 3. 关闭旧的 RpcClient
            if (leaderRpcClient != null) {
                leaderRpcClient.stop();
                leaderRpcClient = null;
                LOG.info("Closed old RpcClient for leaderId={}", leaderId);
            }
    
            // 4. 获取新 Leader 的地址信息
            Peer newLeaderPeer = raftNode.getPeerMap().get(currentLeaderId);
            if (newLeaderPeer == null) {
                LOG.error("Leader peer not found for leaderId={}", currentLeaderId);
                return;
            }
    
            //Endpoint newLeaderEndpoint = newLeaderPeer.getServer().getEndpoint();
            Endpoint endpoint = new Endpoint(newLeaderPeer.getServer().getEndpoint().getHost(),
            newLeaderPeer.getServer().getEndpoint().getPort());
            String leaderAddress = String.format("%s:%d", endpoint.getIp(), endpoint.getPort());
    
            // 5. 创建新的 RpcClient（复用配置）
            RpcClientOptions options = new RpcClientOptions();
            options.setGlobalThreadPoolSharing(true);
            leaderRpcClient = new RpcClient(endpoint, options);
            //leaderRpcClient = new RpcClient("list://" + leaderAddress, options);
            //leaderRpcClient.addService(ExampleService.class); // 确保服务接口注册
    
            // 6. 更新 Leader ID
            leaderId = currentLeaderId;
            LOG.info("Updated RpcClient for new leaderId={}, address={}", leaderId, leaderAddress);
        } catch (Exception ex) {
            LOG.error("Failed to update RpcClient for leaderId={}", currentLeaderId, ex);
        } finally {
            leaderLock.unlock();
        }
    }*/
    private void onLeaderChangeEvent() {
        if (raftNode.getLeaderId() != -1
                && raftNode.getLeaderId() != raftNode.getLocalServer().getServerId()
                && leaderId != raftNode.getLeaderId()) {
            leaderLock.lock();
            try {
                if (leaderRpcClient != null) {
                    leaderRpcClient.stop();
                }
                leaderId = raftNode.getLeaderId();
                Peer peer = raftNode.getPeerMap().get(leaderId);
                Endpoint endpoint = new Endpoint(
                    peer.getServer().getEndpoint().getHost(),
                    peer.getServer().getEndpoint().getPort());
                RpcClientOptions rpcClientOptions = new RpcClientOptions();
                rpcClientOptions.setGlobalThreadPoolSharing(true);
                leaderRpcClient = new RpcClient(endpoint, rpcClientOptions);
                leaderExampleService = BrpcProxy.getProxy(leaderRpcClient, ExampleService.class); // 创建一次
            } finally {
                leaderLock.unlock();
            }
        }
    }
    @Override
    public ExampleProto.SetResponse set(ExampleProto.SetRequest request) {
        ExampleProto.SetResponse.Builder responseBuilder = ExampleProto.SetResponse.newBuilder();
        // 如果自己不是leader，将写请求转发给leader
        if (raftNode.getLeaderId() <= 0) {
            responseBuilder.setSuccess(false);
        } else if (raftNode.getLeaderId() != raftNode.getLocalServer().getServerId()) {
            onLeaderChangeEvent();
            if (leaderExampleService != null) { // 使用已缓存的实例
                LOG.info("----------------onLeaderChangeEvent-----------");
                ExampleProto.SetResponse responseFromLeader = leaderExampleService.set(request);
                responseBuilder.mergeFrom(responseFromLeader);
            } else {
                responseBuilder.setSuccess(false);
            }
        } else {
            // 数据同步写入raft集群
            byte[] data = request.toByteArray();
            LOG.info("----------------isleader()-----------");
            boolean success = raftNode.replicate(data, RaftProto.EntryType.ENTRY_TYPE_DATA);
            LOG.info("----------------isleader() done-----------");
            responseBuilder.setSuccess(success);
        }

        ExampleProto.SetResponse response = responseBuilder.build();
        LOG.info("set request, request={}, response={}", jsonFormat.printToString(request),
                jsonFormat.printToString(response));
        return response;
    }

    @Override
    public ExampleProto.GetResponse get(ExampleProto.GetRequest request) {
        ExampleProto.GetResponse response = stateMachine.get(request);
        LOG.info("get request, request={}, response={}", jsonFormat.printToString(request),
                jsonFormat.printToString(response));
        return response;
    }

}
