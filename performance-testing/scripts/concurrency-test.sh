#!/bin/bash

# ============================================================================
# 📊 ONLYOFFICE Document Server - 并发场景测试套件
# 核心场景：在线文档编辑与查看
# ============================================================================

set -e

BASE_URL="http://localhost"
TEST_DIR="/tmp/ds-concurrency-test"
LOG_DIR="$TEST_DIR/logs"
RESULTS_FILE="$TEST_DIR/concurrency-results.json"

mkdir -p "$TEST_DIR" "$LOG_DIR"

echo "🚀 开始 ONLYOFFICE 文档编辑并发测试"
echo "📍 目标服务器: $BASE_URL"
echo "⏱️  开始时间: $(date '+%Y-%m-%d %H:%M:%S')"

# ============================================================================
# 场景 1: 文档查看并发 (Read Concurrency)
# 描述：30个用户同时查看同一文档
# ============================================================================

test_view_concurrency() {
    local num_users=30
    local log_file="$LOG_DIR/view_concurrency.log"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📖 场景 1: 文档查看并发 (30个用户同时查看)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local start_time=$(date +%s%N)
    local success=0
    local failed=0
    local total_time=0
    
    for i in $(seq 1 $num_users); do
        (
            local req_start=$(date +%s%N)
            if curl -s -m 10 "$BASE_URL/example/" > /dev/null 2>&1; then
                local req_time=$(( ($(date +%s%N) - req_start) / 1000000 ))
                echo "$req_time" >> "$log_file.tmp"
            else
                echo "ERROR" >> "$log_file.tmp"
            fi
        ) &
    done
    wait
    
    local end_time=$(date +%s%N)
    local total_duration=$(( (end_time - start_time) / 1000000 ))
    
    # 统计结果
    if [ -f "$log_file.tmp" ]; then
        success=$(grep -v "ERROR" "$log_file.tmp" | wc -l)
        failed=$(grep "ERROR" "$log_file.tmp" | wc -l)
        
        if [ $success -gt 0 ]; then
            local avg_time=$(grep -v "ERROR" "$log_file.tmp" | awk '{sum+=$1} END {print sum/NR}')
            local min_time=$(grep -v "ERROR" "$log_file.tmp" | sort -n | head -1)
            local max_time=$(grep -v "ERROR" "$log_file.tmp" | sort -rn | head -1)
            
            echo "✅ 成功请求: $success/$num_users"
            echo "❌ 失败请求: $failed/$num_users"
            echo "⏱️  总耗时: ${total_duration}ms"
            echo "📊 平均响应: ${avg_time}ms"
            echo "🔻 最小响应: ${min_time}ms"
            echo "🔺 最大响应: ${max_time}ms"
            echo "📈 吞吐量: $(echo "scale=2; $success*1000/$total_duration" | bc) req/s"
            
            # 保存结果
            cat >> "$RESULTS_FILE" << EOF
{
  "scenario": "view_concurrency",
  "description": "30个用户同时查看文档",
  "concurrent_users": $num_users,
  "success": $success,
  "failed": $failed,
  "total_duration_ms": $total_duration,
  "avg_response_ms": $avg_time,
  "min_response_ms": $min_time,
  "max_response_ms": $max_time,
  "throughput_rps": $(echo "scale=2; $success*1000/$total_duration" | bc)
},
EOF
        fi
        rm -f "$log_file.tmp"
    fi
}

# ============================================================================
# 场景 2: Admin 面板并发访问 (Admin Concurrency)
# 描述：20个管理员同时访问管理面板
# ============================================================================

test_admin_concurrency() {
    local num_users=20
    local log_file="$LOG_DIR/admin_concurrency.log"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚙️  场景 2: Admin 管理面板并发 (20个管理员同时访问)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local start_time=$(date +%s%N)
    
    for i in $(seq 1 $num_users); do
        (
            local req_start=$(date +%s%N)
            if curl -s -m 10 "$BASE_URL/admin/" > /dev/null 2>&1; then
                local req_time=$(( ($(date +%s%N) - req_start) / 1000000 ))
                echo "$req_time" >> "$log_file.tmp"
            else
                echo "ERROR" >> "$log_file.tmp"
            fi
        ) &
    done
    wait
    
    local end_time=$(date +%s%N)
    local total_duration=$(( (end_time - start_time) / 1000000 ))
    
    if [ -f "$log_file.tmp" ]; then
        local success=$(grep -v "ERROR" "$log_file.tmp" | wc -l)
        local failed=$(grep "ERROR" "$log_file.tmp" | wc -l)
        
        if [ $success -gt 0 ]; then
            local avg_time=$(grep -v "ERROR" "$log_file.tmp" | awk '{sum+=$1} END {print sum/NR}')
            local min_time=$(grep -v "ERROR" "$log_file.tmp" | sort -n | head -1)
            local max_time=$(grep -v "ERROR" "$log_file.tmp" | sort -rn | head -1)
            
            echo "✅ 成功请求: $success/$num_users"
            echo "❌ 失败请求: $failed/$num_users"
            echo "⏱️  总耗时: ${total_duration}ms"
            echo "📊 平均响应: ${avg_time}ms"
            echo "🔻 最小响应: ${min_time}ms"
            echo "🔺 最大响应: ${max_time}ms"
            echo "📈 吞吐量: $(echo "scale=2; $success*1000/$total_duration" | bc) req/s"
            
            cat >> "$RESULTS_FILE" << EOF
{
  "scenario": "admin_concurrency",
  "description": "20个管理员同时访问管理面板",
  "concurrent_users": $num_users,
  "success": $success,
  "failed": $failed,
  "total_duration_ms": $total_duration,
  "avg_response_ms": $avg_time,
  "min_response_ms": $min_time,
  "max_response_ms": $max_time,
  "throughput_rps": $(echo "scale=2; $success*1000/$total_duration" | bc)
},
EOF
        fi
        rm -f "$log_file.tmp"
    fi
}

# ============================================================================
# 场景 3: 混合工作负载 (Mixed Workload)
# 描述：50个用户 - 70%查看，30%访问管理
# ============================================================================

test_mixed_workload() {
    local num_users=50
    local view_percent=70
    local admin_percent=30
    local log_file="$LOG_DIR/mixed_workload.log"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 场景 3: 混合工作负载 (50个用户，70%查看+30%管理)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local start_time=$(date +%s%N)
    
    for i in $(seq 1 $num_users); do
        (
            local req_start=$(date +%s%N)
            local rand=$((RANDOM % 100))
            
            if [ $rand -lt $view_percent ]; then
                endpoint="$BASE_URL/example/"
            else
                endpoint="$BASE_URL/admin/"
            fi
            
            if curl -s -m 10 "$endpoint" > /dev/null 2>&1; then
                local req_time=$(( ($(date +%s%N) - req_start) / 1000000 ))
                echo "$req_time" >> "$log_file.tmp"
            else
                echo "ERROR" >> "$log_file.tmp"
            fi
        ) &
    done
    wait
    
    local end_time=$(date +%s%N)
    local total_duration=$(( (end_time - start_time) / 1000000 ))
    
    if [ -f "$log_file.tmp" ]; then
        local success=$(grep -v "ERROR" "$log_file.tmp" | wc -l)
        local failed=$(grep "ERROR" "$log_file.tmp" | wc -l)
        
        if [ $success -gt 0 ]; then
            local avg_time=$(grep -v "ERROR" "$log_file.tmp" | awk '{sum+=$1} END {print sum/NR}')
            local min_time=$(grep -v "ERROR" "$log_file.tmp" | sort -n | head -1)
            local max_time=$(grep -v "ERROR" "$log_file.tmp" | sort -rn | head -1)
            
            echo "✅ 成功请求: $success/$num_users"
            echo "❌ 失败请求: $failed/$num_users"
            echo "⏱️  总耗时: ${total_duration}ms"
            echo "📊 平均响应: ${avg_time}ms"
            echo "🔻 最小响应: ${min_time}ms"
            echo "🔺 最大响应: ${max_time}ms"
            echo "📈 吞吐量: $(echo "scale=2; $success*1000/$total_duration" | bc) req/s"
            
            cat >> "$RESULTS_FILE" << EOF
{
  "scenario": "mixed_workload",
  "description": "50个用户混合负载：70%查看+30%管理",
  "concurrent_users": $num_users,
  "success": $success,
  "failed": $failed,
  "total_duration_ms": $total_duration,
  "avg_response_ms": $avg_time,
  "min_response_ms": $min_time,
  "max_response_ms": $max_time,
  "throughput_rps": $(echo "scale=2; $success*1000/$total_duration" | bc)
},
EOF
        fi
        rm -f "$log_file.tmp"
    fi
}

# ============================================================================
# 场景 4: 持续高负载 (Sustained Load)
# 描述：持续30秒的高并发请求
# ============================================================================

test_sustained_load() {
    local duration_sec=30
    local concurrent_workers=15
    local log_file="$LOG_DIR/sustained_load.log"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚡ 场景 4: 持续高负载 (30秒内15个并发工作进程)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local endpoints=("$BASE_URL/example/" "$BASE_URL/admin/")
    local start_time=$(date +%s)
    local end_time=$((start_time + duration_sec))
    local total_requests=0
    local success=0
    local failed=0
    
    # 启动持续负载测试
    for worker in $(seq 1 $concurrent_workers); do
        (
            while [ $(date +%s) -lt $end_time ]; do
                local endpoint=${endpoints[$((RANDOM % ${#endpoints[@]}))]}
                local req_start=$(date +%s%N)
                
                if curl -s -m 5 "$endpoint" > /dev/null 2>&1; then
                    local req_time=$(( ($(date +%s%N) - req_start) / 1000000 ))
                    echo "$req_time" >> "$log_file.tmp"
                else
                    echo "ERROR" >> "$log_file.tmp"
                fi
                total_requests=$((total_requests + 1))
            done
        ) &
    done
    wait
    
    local actual_duration=$(( $(date +%s) - start_time ))
    
    if [ -f "$log_file.tmp" ]; then
        success=$(grep -v "ERROR" "$log_file.tmp" | wc -l)
        failed=$(grep "ERROR" "$log_file.tmp" | wc -l)
        
        if [ $success -gt 0 ]; then
            local avg_time=$(grep -v "ERROR" "$log_file.tmp" | awk '{sum+=$1} END {print sum/NR}')
            local min_time=$(grep -v "ERROR" "$log_file.tmp" | sort -n | head -1)
            local max_time=$(grep -v "ERROR" "$log_file.tmp" | sort -rn | head -1)
            
            echo "✅ 成功请求: $success/$((success+failed))"
            echo "❌ 失败请求: $failed/$((success+failed))"
            echo "⏱️  实际持续: ${actual_duration}秒"
            echo "📊 平均响应: ${avg_time}ms"
            echo "🔻 最小响应: ${min_time}ms"
            echo "🔺 最大响应: ${max_time}ms"
            echo "📈 吞吐量: $(echo "scale=2; $success/$actual_duration" | bc) req/s"
            
            cat >> "$RESULTS_FILE" << EOF
{
  "scenario": "sustained_load",
  "description": "持续30秒高负载测试",
  "concurrent_workers": $concurrent_workers,
  "actual_duration_sec": $actual_duration,
  "success": $success,
  "failed": $failed,
  "total_requests": $((success+failed)),
  "avg_response_ms": $avg_time,
  "min_response_ms": $min_time,
  "max_response_ms": $max_time,
  "throughput_rps": $(echo "scale=2; $success/$actual_duration" | bc)
},
EOF
        fi
        rm -f "$log_file.tmp"
    fi
}

# ============================================================================
# 场景 5: 峰值模拟 (Peak Burst)
# 描述：短时间内100个并发请求，模拟流量峰值
# ============================================================================

test_peak_burst() {
    local num_users=100
    local log_file="$LOG_DIR/peak_burst.log"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔥 场景 5: 峰值模拟 (100个用户短时间并发访问)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local start_time=$(date +%s%N)
    
    for i in $(seq 1 $num_users); do
        (
            local req_start=$(date +%s%N)
            if curl -s -m 15 "$BASE_URL/example/" > /dev/null 2>&1; then
                local req_time=$(( ($(date +%s%N) - req_start) / 1000000 ))
                echo "$req_time" >> "$log_file.tmp"
            else
                echo "ERROR" >> "$log_file.tmp"
            fi
        ) &
    done
    wait
    
    local end_time=$(date +%s%N)
    local total_duration=$(( (end_time - start_time) / 1000000 ))
    
    if [ -f "$log_file.tmp" ]; then
        local success=$(grep -v "ERROR" "$log_file.tmp" | wc -l)
        local failed=$(grep "ERROR" "$log_file.tmp" | wc -l)
        
        if [ $success -gt 0 ]; then
            local avg_time=$(grep -v "ERROR" "$log_file.tmp" | awk '{sum+=$1} END {print sum/NR}')
            local min_time=$(grep -v "ERROR" "$log_file.tmp" | sort -n | head -1)
            local max_time=$(grep -v "ERROR" "$log_file.tmp" | sort -rn | head -1)
            local p95_time=$(grep -v "ERROR" "$log_file.tmp" | sort -n | awk '{a[NR]=$1} END {n=int(NR*0.95); print a[n]}')
            
            echo "✅ 成功请求: $success/$num_users"
            echo "❌ 失败请求: $failed/$num_users"
            echo "⏱️  总耗时: ${total_duration}ms"
            echo "📊 平均响应: ${avg_time}ms"
            echo "🔻 最小响应: ${min_time}ms"
            echo "🔺 最大响应: ${max_time}ms"
            echo "📊 P95 响应: ${p95_time}ms"
            echo "📈 吞吐量: $(echo "scale=2; $success*1000/$total_duration" | bc) req/s"
            
            cat >> "$RESULTS_FILE" << EOF
{
  "scenario": "peak_burst",
  "description": "100个用户峰值并发测试",
  "concurrent_users": $num_users,
  "success": $success,
  "failed": $failed,
  "total_duration_ms": $total_duration,
  "avg_response_ms": $avg_time,
  "min_response_ms": $min_time,
  "max_response_ms": $max_time,
  "p95_response_ms": $p95_time,
  "throughput_rps": $(echo "scale=2; $success*1000/$total_duration" | bc)
},
EOF
        fi
        rm -f "$log_file.tmp"
    fi
}

# ============================================================================
# 执行所有测试
# ============================================================================

# 初始化结果文件
echo "[" > "$RESULTS_FILE"

# 执行测试
test_view_concurrency
test_admin_concurrency
test_mixed_workload
test_sustained_load
test_peak_burst

# 移除最后一个逗号并关闭JSON
sed -i '$ s/,$//' "$RESULTS_FILE"
echo "]" >> "$RESULTS_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 所有测试完成！"
echo "📊 结果文件: $RESULTS_FILE"
echo "📁 日志目录: $LOG_DIR"
echo "⏱️  完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 显示结果摘要
echo ""
echo "📈 测试结果摘要："
cat "$RESULTS_FILE"
