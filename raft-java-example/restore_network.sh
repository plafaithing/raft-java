#!/bin/bash

echo "=========================================="
echo "  恢复网络配置"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 权限运行此脚本"
    echo "使用方法: sudo $0"
    exit 1
fi

INTERFACES="eth0 lo"

echo "清除高延迟网络配置..."
for INTERFACE in $INTERFACES; do
    tc qdisc del dev $INTERFACE root 2>/dev/null
    echo "✓ $INTERFACE 已恢复"
done
echo ""

echo "当前网络配置："
for INTERFACE in $INTERFACES; do
    echo "--- $INTERFACE ---"
    tc qdisc show dev $INTERFACE
done
echo ""

echo "=========================================="
echo "  网络配置已恢复"
echo "=========================================="
