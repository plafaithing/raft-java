#!/bin/bash

echo "=========================================="
echo "  高延迟网络环境配置"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 权限运行此脚本"
    echo "使用方法: sudo $0 [delay_ms] [jitter_ms]"
    exit 1
fi

DELAY_MS=${1:-100}
JITTER_MS=${2:-10}

INTERFACES="eth0 lo"

echo "配置参数："
echo "  延迟: ${DELAY_MS}ms"
echo "  抖动: ${JITTER_MS}ms"
echo "  目标接口: $INTERFACES"
echo ""

if ! command -v tc &> /dev/null; then
    echo "错误: tc 命令不可用"
    echo "请安装 iproute2: sudo apt-get install iproute2"
    exit 1
fi

for INTERFACE in $INTERFACES; do
    echo "配置接口: $INTERFACE"
    tc qdisc del dev $INTERFACE root 2>/dev/null
    tc qdisc add dev $INTERFACE root netem delay ${DELAY_MS}ms ${JITTER_MS}ms
    echo "✓ $INTERFACE 配置完成"
    tc qdisc show dev $INTERFACE
    echo ""
done

echo "=========================================="
echo "  高延迟网络环境已配置"
echo "=========================================="
echo ""
echo "验证延迟: ping -c 3 127.0.0.1"
echo "恢复网络: sudo ./restore_network.sh"
