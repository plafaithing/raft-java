#!/bin/bash

# 设置 node3 网络不稳定

echo "=========================================="
echo "  设置 node3 网络不稳定"
echo "=========================================="
echo ""

# 检查是否有 root 权限
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 权限运行此脚本"
    echo "使用方法: sudo $0"
    exit 1
fi

# 网络接口名称
INTERFACE="eth0"

# 延迟配置（毫秒）
DELAY_MS=${1:-100}  # 默认 100ms
JITTER_MS=${2:-50}   # 默认 50ms 抖动
LOSS_PERCENT=${3:-10}  # 默认 10% 丢包率

echo "配置参数："
echo "  网络接口: $INTERFACE"
echo "  延迟: ${DELAY_MS}ms"
echo "  抖动: ${JITTER_MS}ms"
echo "  丢包率: ${LOSS_PERCENT}%"
echo ""

# 检查 tc 命令是否可用
if ! command -v tc &> /dev/null; then
    echo "错误: tc 命令不可用"
    echo "请安装 iproute2: sudo apt-get install iproute2"
    exit 1
fi

# 清除现有的 qdisc
echo "清除现有的 qdisc..."
tc qdisc del dev $INTERFACE root 2>/dev/null
echo "✓ 清除完成"
echo ""

# 添加 netem qdisc（延迟 + 抖动 + 丢包）
echo "添加网络不稳定配置..."
tc qdisc add dev $INTERFACE root netem delay ${DELAY_MS}ms ${JITTER_MS}ms loss ${LOSS_PERCENT}%
echo "✓ 配置完成"
echo ""

# 显示配置
echo "当前网络配置："
tc qdisc show dev $INTERFACE
echo ""

echo "=========================================="
echo "  node3 网络不稳定已配置"
echo "=========================================="
echo ""
echo "恢复网络: sudo ./restore_network.sh"
