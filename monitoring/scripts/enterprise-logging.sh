#!/bin/bash

# ============================================================================
# 📋 ONLYOFFICE Document Server - 企业级日志系统
# 功能：结构化日志、审计日志、性能日志、错误追踪
# ============================================================================

set -e

AUDIT_LOG="/var/log/onlyoffice/audit.log"
ERROR_LOG="/var/log/onlyoffice/error.log"
PERF_LOG="/var/log/onlyoffice/performance.log"
TRACE_LOG="/var/log/onlyoffice/trace.log"

# 确保日志目录存在
mkdir -p "$(dirname "$AUDIT_LOG")"

# ============================================================================
# 日志初始化
# ============================================================================

init_logs() {
    # 创建日志文件并设置权限
    for log_file in "$AUDIT_LOG" "$ERROR_LOG" "$PERF_LOG" "$TRACE_LOG"; do
        touch "$log_file"
        chmod 640 "$log_file"
        chown ds:ds "$log_file"
    done
    
    # 配置日志轮转
    cat > /etc/logrotate.d/onlyoffice-enterprise << 'EOF'
/var/log/onlyoffice/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 ds ds
    sharedscripts
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            nginx -s reload > /dev/null 2>&1 || true
        fi
    endscript
}
EOF
}

# ============================================================================
# 1. 审计日志 (Audit Log)
# ============================================================================

log_audit() {
    local action=$1
    local resource=$2
    local result=$3
    local details=$4
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")
    local user=${SUDO_USER:-root}
    
    cat >> "$AUDIT_LOG" << EOF
{
  "timestamp": "$timestamp",
  "event_type": "audit",
  "action": "$action",
  "resource": "$resource",
  "result": "$result",
  "user": "$user",
  "details": "$details",
  "pid": $$,
  "level": "INFO"
}
EOF
}

# ============================================================================
# 2. 错误日志 (Error Log)
# ============================================================================

log_error() {
    local error_code=$1
    local component=$2
    local message=$3
    local stacktrace=$4
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")
    
    cat >> "$ERROR_LOG" << EOF
{
  "timestamp": "$timestamp",
  "event_type": "error",
  "error_code": "$error_code",
  "component": "$component",
  "message": "$message",
  "stacktrace": "$stacktrace",
  "pid": $$,
  "level": "ERROR"
}
EOF

    # 同时输出到 syslog
    logger -t "onlyoffice-error" -p err "$component: $message (Code: $error_code)"
}

# ============================================================================
# 3. 性能日志 (Performance Log)
# ============================================================================

log_performance() {
    local operation=$1
    local duration_ms=$2
    local memory_delta=$3
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")
    
    cat >> "$PERF_LOG" << EOF
{
  "timestamp": "$timestamp",
  "event_type": "performance",
  "operation": "$operation",
  "duration_ms": $duration_ms,
  "memory_delta": $memory_delta,
  "level": "PERF"
}
EOF
}

# ============================================================================
# 4. 追踪日志 (Trace Log) - 调试用
# ============================================================================

log_trace() {
    local component=$1
    local message=$2
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")
    
    if [ "${ONLYOFFICE_DEBUG:-false}" = "true" ]; then
        cat >> "$TRACE_LOG" << EOF
{
  "timestamp": "$timestamp",
  "event_type": "trace",
  "component": "$component",
  "message": "$message",
  "pid": $$,
  "level": "DEBUG"
}
EOF
    fi
}

# ============================================================================
# 5. 并发事件日志 (Concurrency Log)
# ============================================================================

log_concurrency_event() {
    local event_type=$1  # connect, disconnect, timeout, queue_full
    local concurrent_count=$2
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")
    
    cat >> "$AUDIT_LOG" << EOF
{
  "timestamp": "$timestamp",
  "event_type": "concurrency",
  "type": "$event_type",
  "concurrent_users": $concurrent_count,
  "level": "INFO"
}
EOF
}

# ============================================================================
# 6. 用户操作日志 (User Activity Log)
# ============================================================================

log_user_activity() {
    local activity=$1  # document_open, document_edit, document_save, document_close
    local document_id=$2
    local user_id=$3
    local duration_sec=$4
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")
    
    cat >> "$AUDIT_LOG" << EOF
{
  "timestamp": "$timestamp",
  "event_type": "user_activity",
  "activity": "$activity",
  "document_id": "$document_id",
  "user_id": "$user_id",
  "duration_sec": $duration_sec,
  "level": "INFO"
}
EOF
}

# ============================================================================
# 7. 日志查询和分析
# ============================================================================

query_logs() {
    local log_type=$1
    local filter=${2:-""}
    local limit=${3:-100}
    
    case "$log_type" in
        audit)
            grep -i "audit" "$AUDIT_LOG" 2>/dev/null | tail -$limit
            ;;
        error)
            tail -$limit "$ERROR_LOG" 2>/dev/null
            ;;
        performance)
            tail -$limit "$PERF_LOG" 2>/dev/null
            ;;
        concurrency)
            grep -i "concurrency" "$AUDIT_LOG" 2>/dev/null | tail -$limit
            ;;
        all)
            tail -$limit "$AUDIT_LOG" "$ERROR_LOG" "$PERF_LOG" 2>/dev/null | sort
            ;;
        *)
            echo "Unknown log type: $log_type"
            return 1
            ;;
    esac
}

# ============================================================================
# 8. 日志统计
# ============================================================================

analyze_logs() {
    echo "=== 日志分析报告 ==="
    echo ""
    
    echo "📊 错误统计："
    grep -o '"error_code": "[^"]*"' "$ERROR_LOG" 2>/dev/null | cut -d'"' -f4 | sort | uniq -c | sort -rn || echo "No errors"
    echo ""
    
    echo "📈 性能统计："
    if [ -f "$PERF_LOG" ]; then
        echo "平均响应时间："
        grep "duration_ms" "$PERF_LOG" 2>/dev/null | grep -o '"duration_ms": [0-9]*' | awk '{sum+=$3; count++} END {if (count>0) printf "%.2f ms\n", sum/count}' || echo "N/A"
    fi
    echo ""
    
    echo "👥 并发统计："
    grep "concurrent_users" "$AUDIT_LOG" 2>/dev/null | grep -o '"concurrent_users": [0-9]*' | awk '{sum+=$3; count++; max=($3>max)?$3:max} END {if (count>0) printf "平均: %d, 最大: %d\n", sum/count, max}' || echo "N/A"
    echo ""
    
    echo "📅 日志大小："
    du -h "$AUDIT_LOG" "$ERROR_LOG" "$PERF_LOG" 2>/dev/null | awk '{sum+=$1} END {print "总大小: " sum}'
}

# ============================================================================
# 9. 日志集中化 (ELK Stack 集成)
# ============================================================================

setup_elk_integration() {
    cat > /etc/filebeat/filebeat.yml << 'EOF'
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/onlyoffice/audit.log
  fields:
    log_type: audit
    service: onlyoffice-documentserver

- type: log
  enabled: true
  paths:
    - /var/log/onlyoffice/error.log
  fields:
    log_type: error
    service: onlyoffice-documentserver

- type: log
  enabled: true
  paths:
    - /var/log/onlyoffice/performance.log
  fields:
    log_type: performance
    service: onlyoffice-documentserver

output.elasticsearch:
  hosts: ["${ELASTICSEARCH_HOST:-localhost:9200}"]
  index: "onlyoffice-%{+yyyy.MM.dd}"

processors:
  - add_docker_metadata:
  - add_fields:
      target: ''
      fields:
        environment: production
EOF
}

# ============================================================================
# 主程序
# ============================================================================

case "${1:-help}" in
    init)
        init_logs
        echo "✅ 日志系统初始化完成"
        ;;
    audit)
        log_audit "$2" "$3" "$4" "$5"
        ;;
    error)
        log_error "$2" "$3" "$4" "$5"
        ;;
    perf)
        log_performance "$2" "$3" "$4"
        ;;
    trace)
        log_trace "$2" "$3"
        ;;
    concurrency)
        log_concurrency_event "$2" "$3"
        ;;
    activity)
        log_user_activity "$2" "$3" "$4" "$5"
        ;;
    query)
        query_logs "$2" "$3" "$4"
        ;;
    analyze)
        analyze_logs
        ;;
    elk)
        setup_elk_integration
        echo "✅ ELK 集成配置完成"
        ;;
    *)
        echo "企业级日志系统"
        echo ""
        echo "使用方法："
        echo "  $0 init                               # 初始化日志系统"
        echo "  $0 audit <action> <resource> <result> # 记录审计日志"
        echo "  $0 error <code> <component> <message> # 记录错误日志"
        echo "  $0 perf <operation> <duration_ms>     # 记录性能日志"
        echo "  $0 trace <component> <message>        # 记录追踪日志"
        echo "  $0 concurrency <type> <count>         # 记录并发事件"
        echo "  $0 activity <activity> <doc_id> <uid> # 记录用户活动"
        echo "  $0 query <type> [filter] [limit]      # 查询日志"
        echo "  $0 analyze                            # 分析日志"
        echo "  $0 elk                                # 配置 ELK 集成"
        ;;
esac
