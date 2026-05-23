#!/bin/bash

# 获取所有包含 "raft" 的进程 PID（排除 grep 自身）
pids=$(ps -ef | grep raft | grep -v grep | awk '{print $2}')

# 检查是否找到进程
if [ -z "$pids" ]; then
    echo "没有找到包含 'raft' 的进程"
    exit 0
fi

echo "找到以下 raft 进程："
echo "$pids"

# 逐个 kill -9
for pid in $pids; do
    echo "正在杀死进程: $pid"
    kill -9 "$pid"
done

echo "所有 raft 进程已终止"