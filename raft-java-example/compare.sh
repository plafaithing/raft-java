#!/bin/bash

# Raft 优化对比脚本

echo "=========================================="
echo "  Raft 优化对比测试"
echo "=========================================="
echo ""

BASELINE_FILE="baseline_results.txt"
OPTIMIZED_FILE="optimized_results.txt"

# 检查基准结果是否存在
if [ ! -f "$BASELINE_FILE" ]; then
    echo "错误：基准结果文件不存在：$BASELINE_FILE"
    echo ""
    echo "请先运行基准测试："
    echo "  ./benchmark.sh throughput 10 60 > $BASELINE_FILE"
    exit 1
fi

echo "当前基准值（未优化）："
echo "=========================================="
cat "$BASELINE_FILE" | grep -E "Throughput|Success rate|Avg bytes/request"
echo ""

# 询问是否运行优化测试
read -p "是否运行优化版本测试？(y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "运行优化版本测试..."
    echo ""
    
    # 运行优化测试
    ./benchmark.sh throughput 10 60 > "$OPTIMIZED_FILE"
    
    echo ""
    echo "优化版本测试完成！"
    echo ""
fi

# 检查优化结果是否存在
if [ -f "$OPTIMIZED_FILE" ]; then
    echo "优化版本结果："
    echo "=========================================="
    cat "$OPTIMIZED_FILE" | grep -E "Throughput|Success rate|Avg bytes/request"
    echo ""
    
    # 提取指标
    BASELINE_THROUGHPUT=$(cat "$BASELINE_FILE" | grep "Throughput" | awk '{print $3}')
    OPTIMIZED_THROUGHPUT=$(cat "$OPTIMIZED_FILE" | grep "Throughput" | awk '{print $3}')
    
    BASELINE_SUCCESS=$(cat "$BASELINE_FILE" | grep "Success rate" | awk '{print $3}')
    OPTIMIZED_SUCCESS=$(cat "$OPTIMIZED_FILE" | grep "Success rate" | awk '{print $3}')
    
    BASELINE_BYTES=$(cat "$BASELINE_FILE" | grep "Avg bytes/request" | awk '{print $4}')
    OPTIMIZED_BYTES=$(cat "$OPTIMIZED_FILE" | grep "Avg bytes/request" | awk '{print $4}')
    
    # 计算提升
    THROUGHPUT_IMPROVEMENT=$(echo "scale=2; ($OPTIMIZED_THROUGHPUT - $BASELINE_THROUGHPUT) / $BASELINE_THROUGHPUT * 100" | bc)
    
    echo "=========================================="
    echo "  对比结果"
    echo "=========================================="
    echo ""
    printf "%-20s %12s %12s %12s\n" "指标" "基准值" "优化值" "提升"
    echo "------------------------------------------------------------"
    printf "%-20s %12.2f %12.2f %12.2f\n" "吞吐量 (req/s)" "$BASELINE_THROUGHPUT" "$OPTIMIZED_THROUGHPUT" "$THROUGHPUT_IMPROVEMENT%"
    printf "%-20s %12s %12s\n" "成功率" "$BASELINE_SUCCESS" "$OPTIMIZED_SUCCESS"
    printf "%-20s %12.2f %12.2f\n" "平均字节/请求" "$BASELINE_BYTES" "$OPTIMIZED_BYTES"
    echo ""
    
    # 判断优化效果
    if (( $(echo "$THROUGHPUT_IMPROVEMENT > 0" | bc -l) )); then
        echo "✅ 吞吐量提升了 ${THROUGHPUT_IMPROVEMENT}%"
    else
        echo "❌ 吞吐量下降了 ${THROUGHPUT_IMPROVEMENT}%"
    fi
    
    echo ""
    echo "详细结果文件："
    echo "  基准值：$BASELINE_FILE"
    echo "  优化值：$OPTIMIZED_FILE"
else
    echo ""
    echo "优化结果文件不存在：$OPTIMIZED_FILE"
    echo ""
    echo "运行优化测试："
    echo "  ./benchmark.sh throughput 10 60 > $OPTIMIZED_FILE"
    echo ""
    echo "然后重新运行此脚本："
    echo "  ./compare.sh"
fi
