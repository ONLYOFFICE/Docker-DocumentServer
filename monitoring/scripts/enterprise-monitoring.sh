#!/bin/bash

# ============================================================================
# 📊 ONLYOFFICE Document Server - 企业级监控系统
# 功能：性能指标、并发监控、系统健康检查
# ============================================================================

set -e

MONITOR_DIR="/var/lib/onlyoffice/monitoring"
METRICS_FILE="${MONITOR_DIR}/metrics.json"
LOG_DIR="/var/log/onlyoffice/monitoring"
PROMETHEUS_DIR="/etc/onlyoffice/prometheus"

mkdir -p "$MONITOR_DIR" "$LOG_DIR" "$PROMETHEUS_DIR"

# ============================================================================
# 1. 性能和并发指标收集
# ============================================================================

collect_metrics() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # 系统指标
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_total=$(free -b | grep Mem | awk '{print $2}')
    local memory_used=$(free -b | grep Mem | awk '{print $3}')
    local memory_percent=$(echo "scale=2; $memory_used*100/$memory_total" | awk '{printf "%.2f", $0}')
    
    # 磁盘指标
    local disk_usage=$(df /var/www/onlyoffice | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    
    # 网络连接
    local established_connections=$(netstat -an 2>/dev/null | grep ESTABLISHED | wc -l || echo 0)
    local time_wait_connections=$(netstat -an 2>/dev/null | grep TIME_WAIT | wc -l || echo 0)
    
    # 进程检查
    local docservice_pid=$(pgrep -f "node.*docservice" | head -1 || echo "")
    local converter_pid=$(pgrep -f "node.*converter" | head -1 || echo "")
    local adminpanel_pid=$(pgrep -f "node.*adminpanel" | head -1 || echo "")
    
    # 数据库连接
    local db_connections=$(netstat -an 2>/dev/null | grep ":5432.*ESTABLISHED" | wc -l || echo 0)
    
    # HTTP 请求统计
    local http_requests=$(tail -100 /var/log/nginx/access.log 2>/dev/null | wc -l || echo 0)
    local http_errors=$(grep -c " 5[0-9][0-9] " /var/log/nginx/access.log 2>/dev/null || echo 0)
    
    # 生成 JSON 指标
    cat > "$METRICS_FILE" << EOF
{
  "timestamp": "$timestamp",
  "system": {
    "cpu_percent": $cpu_usage,
    "memory_total_bytes": $memory_total,
    "memory_used_bytes": $memory_used,
    "memory_percent": $memory_percent,
    "disk_percent": $disk_usage
  },
  "network": {
    "established_connections": $established_connections,
    "time_wait_connections": $time_wait_connections,
    "total_connections": $((established_connections + time_wait_connections))
  },
  "processes": {
    "docservice": {
      "pid": "${docservice_pid:-null}",
      "running": $([ -n "$docservice_pid" ] && echo "true" || echo "false")
    },
    "converter": {
      "pid": "${converter_pid:-null}",
      "running": $([ -n "$converter_pid" ] && echo "true" || echo "false")
    },
    "adminpanel": {
      "pid": "${adminpanel_pid:-null}",
      "running": $([ -n "$adminpanel_pid" ] && echo "true" || echo "false")
    }
  },
  "database": {
    "connections": $db_connections
  },
  "http": {
    "requests_last_100": $http_requests,
    "errors_5xx": $http_errors
  }
}
EOF
}

# ============================================================================
# 2. 结构化日志记录
# ============================================================================

log_event() {
    local level=$1
    local component=$2
    local message=$3
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")
    
    cat >> "$LOG_DIR/audit.log" << EOF
[$timestamp] [$level] [$component] $message
EOF
}

log_metric() {
    local metric_name=$1
    local value=$2
    local labels=$3
    local timestamp=$(date +%s000)
    
    cat >> "$LOG_DIR/metrics.log" << EOF
${metric_name}${labels} $value $timestamp
EOF
}

# ============================================================================
# 3. 并发监控
# ============================================================================

monitor_concurrency() {
    local max_connections=${1:-1000}
    
    while true; do
        local current_connections=$(netstat -an 2>/dev/null | grep -E ":(80|443)" | wc -l || echo 0)
        local concurrent_users=$((current_connections / 3))  # 平均每个用户 3 个连接
        
        # 记录并发指标
        log_metric "concurrent_users" "$concurrent_users" ""
        log_metric "network_connections" "$current_connections" ""
        
        # 检查阈值
        if [ $current_connections -gt $((max_connections * 80 / 100)) ]; then
            log_event "WARN" "CONCURRENCY" "High concurrency detected: $current_connections connections (${concurrent_users} users)"
        fi
        
        # 每 30 秒收集一次
        sleep 30
    done
}

# ============================================================================
# 4. 健康检查
# ============================================================================

health_check() {
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/info/info.json)
    local docservice_running=$(pgrep -f "node.*docservice" > /dev/null && echo "true" || echo "false")
    local db_running=$(pg_isready -h localhost -p 5432 -U onlyoffice > /dev/null 2>&1 && echo "true" || echo "false")
    
    local overall_status="healthy"
    
    if [ "$http_status" != "200" ] || [ "$docservice_running" = "false" ] || [ "$db_running" = "false" ]; then
        overall_status="unhealthy"
        log_event "ERROR" "HEALTH_CHECK" "Service unhealthy - HTTP:$http_status DocService:$docservice_running DB:$db_running"
    fi
    
    cat > "${MONITOR_DIR}/health.json" << EOF
{
  "status": "$overall_status",
  "http_status": $http_status,
  "docservice_running": $docservice_running,
  "database_running": $db_running,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# ============================================================================
# 5. Prometheus 指标导出
# ============================================================================

export_prometheus_metrics() {
    local metrics=""
    
    if [ -f "$METRICS_FILE" ]; then
        local json_data=$(cat "$METRICS_FILE")
        
        # 系统指标
        metrics="${metrics}# HELP onlyoffice_cpu_usage CPU usage percentage
# TYPE onlyoffice_cpu_usage gauge
onlyoffice_cpu_usage $(echo "$json_data" | jq '.system.cpu_percent')

# HELP onlyoffice_memory_percent Memory usage percentage
# TYPE onlyoffice_memory_percent gauge
onlyoffice_memory_percent $(echo "$json_data" | jq '.system.memory_percent')

# HELP onlyoffice_disk_percent Disk usage percentage
# TYPE onlyoffice_disk_percent gauge
onlyoffice_disk_percent $(echo "$json_data" | jq '.system.disk_percent')

# HELP onlyoffice_network_connections Active network connections
# TYPE onlyoffice_network_connections gauge
onlyoffice_network_connections $(echo "$json_data" | jq '.network.total_connections')

# HELP onlyoffice_database_connections Active database connections
# TYPE onlyoffice_database_connections gauge
onlyoffice_database_connections $(echo "$json_data" | jq '.database.connections')

# HELP onlyoffice_http_requests HTTP requests processed
# TYPE onlyoffice_http_requests counter
onlyoffice_http_requests $(echo "$json_data" | jq '.http.requests_last_100')

# HELP onlyoffice_http_errors HTTP 5xx errors
# TYPE onlyoffice_http_errors counter
onlyoffice_http_errors $(echo "$json_data" | jq '.http.errors_5xx')
"
    fi
    
    echo "$metrics" > "${PROMETHEUS_DIR}/metrics.txt"
}

# ============================================================================
# 6. 启动监控守护进程
# ============================================================================

start_monitoring() {
    # 定期收集指标
    (
        while true; do
            collect_metrics
            export_prometheus_metrics
            health_check
            sleep 60
        done
    ) &
    echo $! > "${MONITOR_DIR}/collector.pid"
    
    # 并发监控
    monitor_concurrency &
    echo $! > "${MONITOR_DIR}/concurrency.pid"
    
    log_event "INFO" "MONITOR" "Monitoring system started"
}

# ============================================================================
# 7. HTTP 指标端点
# ============================================================================

setup_metrics_endpoint() {
    cat > /etc/nginx/conf.d/metrics.conf << 'NGINX_EOF'
server {
    listen 9090;
    listen [::]:9090;
    server_name localhost;

    location /metrics {
        alias /etc/onlyoffice/prometheus/metrics.txt;
        default_type text/plain;
    }

    location /health {
        alias /var/lib/onlyoffice/monitoring/health.json;
        default_type application/json;
    }

    location /metrics/json {
        alias /var/lib/onlyoffice/monitoring/metrics.json;
        default_type application/json;
    }
}
NGINX_EOF

    nginx -s reload 2>/dev/null || true
}

# ============================================================================
# 主程序
# ============================================================================

case "${1:-collect}" in
    collect)
        collect_metrics
        cat "$METRICS_FILE"
        ;;
    health)
        health_check
        cat "${MONITOR_DIR}/health.json"
        ;;
    prometheus)
        export_prometheus_metrics
        cat "${PROMETHEUS_DIR}/metrics.txt"
        ;;
    start)
        start_monitoring
        ;;
    endpoint)
        setup_metrics_endpoint
        ;;
    *)
        echo "Usage: $0 {collect|health|prometheus|start|endpoint}"
        ;;
esac
