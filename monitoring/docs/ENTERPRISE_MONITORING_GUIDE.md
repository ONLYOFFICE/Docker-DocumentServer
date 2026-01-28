# 🚀 ONLYOFFICE Document Server - 企业级监控和日志系统部署指南

**版本**：1.0  
**发布日期**：2026-01-28  
**适用场景**：大型企业生产部署

---

## 📋 目录

1. [概述](#概述)
2. [架构设计](#架构设计)
3. [快速部署](#快速部署)
4. [配置详解](#配置详解)
5. [监控指标](#监控指标)
6. [告警规则](#告警规则)
7. [日志管理](#日志管理)
8. [故障排查](#故障排查)
9. [性能调优](#性能调优)

---

## 概述

### 核心功能

```
🎯 监控系统
├─ 实时性能监控
├─ 并发连接监控
├─ 资源使用监控
└─ 应用健康检查

📋 日志系统
├─ 审计日志（Audit Log）
├─ 错误日志（Error Log）
├─ 性能日志（Performance Log）
├─ 追踪日志（Trace Log）
└─ 用户活动日志

📊 数据可视化
├─ Prometheus 指标存储
├─ Grafana 仪表板
├─ 告警管理
└─ 历史数据分析
```

### 监控指标覆盖范围

| 类型 | 指标 | 告警阈值 |
|------|------|---------|
| **并发** | 用户数、连接数、请求队列 | >200u / >800conn / full |
| **性能** | 响应时间、吞吐量、CPU | >2s / <100rps / >80% |
| **资源** | 内存、磁盘、网络 | >85% / >90% / >800Mbps |
| **可用性** | 进程、数据库、HTTP 状态 | Down / Down / 5xx |

---

## 架构设计

### 系统架构

```
┌─────────────────────────────────────────────────────┐
│        ONLYOFFICE Document Server                   │
│  ┌──────────────┬──────────────┬──────────────┐    │
│  │ DocService   │  Converter   │  AdminPanel  │    │
│  └──────────────┴──────────────┴──────────────┘    │
│           │                                         │
│  ┌────────▼────────────────────────────────────┐   │
│  │ 企业级监控和日志系统                        │   │
│  │  ├─ Monitoring Agent (9090)                │   │
│  │  ├─ Logging Framework                      │   │
│  │  └─ Metrics Collector                      │   │
│  └────────┬────────────────────────────────────┘   │
└───────────┼─────────────────────────────────────────┘
            │
            ├─► Prometheus (9090) ──────┐
            │                            │
            ├─► ELK Stack               │
            │   ├─ Elasticsearch        │
            │   ├─ Logstash             │
            │   └─ Kibana               │
            │                            │
            └─► Grafana (3000) ◄────────┘
                ├─ 仪表板
                ├─ 告警管理
                └─ 历史分析
```

### 数据流

```
应用层
  │
  ├─ 性能指标 ────────┐
  ├─ 并发信息 ────────┼──► 监控收集器
  ├─ 错误事件 ────────┤    (enterprise-monitoring.sh)
  └─ 用户活动 ────────┘
                       │
                    ┌──▼──┐
                    │JSON │
                    └──┬──┘
                       │
            ┌──────────┼──────────┐
            │          │          │
            ▼          ▼          ▼
        Prometheus  ELK    JSON端点
        指标存储    日志    HTTP API
            │       │         │
            └───────┼─────────┘
                    │
                 Grafana
                  仪表板
```

---

## 快速部署

### 步骤 1: 安装监控系统

```bash
# 复制监控脚本
cp enterprise-monitoring.sh /app/ds/
chmod +x /app/ds/enterprise-monitoring.sh

# 初始化监控
/app/ds/enterprise-monitoring.sh endpoint

# 启动监控守护进程
/app/ds/enterprise-monitoring.sh start
```

### 步骤 2: 安装日志系统

```bash
# 复制日志脚本
cp enterprise-logging.sh /app/ds/
chmod +x /app/ds/enterprise-logging.sh

# 初始化日志
/app/ds/enterprise-logging.sh init

# 验证日志系统
/app/ds/enterprise-logging.sh query audit | head -10
```

### 步骤 3: 部署 Prometheus

```bash
# 复制 Prometheus 配置
cp prometheus.yml /etc/onlyoffice/prometheus/
cp alert_rules.yml /etc/onlyoffice/prometheus/

# 启动 Prometheus
docker run -d \
  --name prometheus \
  -p 9090:9090 \
  -v /etc/onlyoffice/prometheus:/etc/prometheus \
  prom/prometheus
```

### 步骤 4: 部署 Grafana

```bash
# 启动 Grafana
docker run -d \
  --name grafana \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  grafana/grafana

# 导入仪表板
curl -X POST http://localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @grafana-dashboard.json
```

### 步骤 5: 部署 ELK Stack (可选)

```bash
# Elasticsearch
docker run -d \
  --name elasticsearch \
  -p 9200:9200 \
  -e "discovery.type=single-node" \
  docker.elastic.co/elasticsearch/elasticsearch:8.0.0

# Kibana
docker run -d \
  --name kibana \
  -p 5601:5601 \
  -e "ELASTICSEARCH_HOSTS=http://elasticsearch:9200" \
  docker.elastic.co/kibana/kibana:8.0.0
```

---

## 配置详解

### 监控收集间隔

```bash
# 编辑 enterprise-monitoring.sh 中的参数
COLLECT_INTERVAL=60  # 60 秒收集一次
ALERT_CHECK=30       # 30 秒检查一次告警
```

### 日志轮转策略

```bash
# /etc/logrotate.d/onlyoffice-enterprise
/var/log/onlyoffice/*.log {
    daily              # 每日轮转
    missingok          # 日志不存在不报错
    rotate 30          # 保留 30 个备份
    compress           # 压缩旧日志
    delaycompress      # 延迟压缩
    notifempty         # 空日志不轮转
}
```

### 性能阈值调整

```bash
# 编辑告警规则 alert_rules.yml

# CPU 告警阈值
- alert: HighCPUUsage
  expr: onlyoffice_cpu_usage > 80  # 修改为你需要的值

# 内存告警阈值
- alert: HighMemoryUsage
  expr: onlyoffice_memory_percent > 85

# 并发告警阈值
- alert: HighConcurrentConnections
  expr: onlyoffice_network_connections > 800
```

---

## 监控指标

### 系统指标

| 指标 | 说明 | 单位 | 告警 |
|------|------|------|------|
| `onlyoffice_cpu_usage` | CPU 使用率 | % | >80% |
| `onlyoffice_memory_percent` | 内存使用率 | % | >85% |
| `onlyoffice_disk_percent` | 磁盘使用率 | % | >90% |

### 并发指标

| 指标 | 说明 | 单位 | 告警 |
|------|------|------|------|
| `onlyoffice_network_connections` | 活跃连接数 | 个 | >800 |
| `concurrent_users` | 并发用户数 | 个 | >200 |
| `onlyoffice_database_connections` | 数据库连接 | 个 | ≥100 |

### 性能指标

| 指标 | 说明 | 单位 | 目标 |
|------|------|------|------|
| `onlyoffice_http_requests` | HTTP 请求数 | 个 | - |
| `onlyoffice_http_errors` | HTTP 错误数 | 个 | <1% |
| `response_time_p95` | P95 响应时间 | ms | <2000 |

### 进程指标

| 指标 | 说明 | 值 |
|------|------|-----|
| `onlyoffice_docservice_running` | DocService 运行状态 | 0/1 |
| `onlyoffice_converter_running` | Converter 运行状态 | 0/1 |
| `onlyoffice_adminpanel_running` | AdminPanel 运行状态 | 0/1 |

---

## 告警规则

### 关键告警

#### 1. 应用不可用

```yaml
alert: OnlyofficeApplicationDown
condition: up{job="onlyoffice-app"} == 0
duration: 1 分钟
severity: 🔴 CRITICAL
action: 立即重启服务，检查日志
```

#### 2. 并发连接过高

```yaml
alert: HighConcurrentConnections
condition: onlyoffice_network_connections > 800
duration: 5 分钟
severity: 🟡 WARNING
action: 检查是否存在连接泄漏，考虑扩容
```

#### 3. 数据库连接池满

```yaml
alert: DatabaseConnectionPoolFull
condition: onlyoffice_database_connections >= 100
duration: 1 分钟
severity: 🔴 CRITICAL
action: 立即检查数据库，可能需要增加连接池
```

#### 4. 高 HTTP 错误率

```yaml
alert: HighErrorRate
condition: rate(onlyoffice_http_errors[5m]) > 5
duration: 5 分钟
severity: 🟡 WARNING
action: 检查应用日志，查找错误原因
```

### 自定义告警

```bash
# 添加新告警规则到 alert_rules.yml
- alert: CustomAlert
  expr: your_metric > threshold
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "告警摘要"
    description: "告警描述"
```

---

## 日志管理

### 日志类型

#### 1. 审计日志 (Audit Log)

```json
{
  "timestamp": "2026-01-28 10:30:45",
  "event_type": "audit",
  "action": "document_open",
  "resource": "doc_12345",
  "result": "success",
  "user": "admin",
  "level": "INFO"
}
```

用途：追踪用户操作、安全审计、合规检查

#### 2. 错误日志 (Error Log)

```json
{
  "timestamp": "2026-01-28 10:30:45",
  "event_type": "error",
  "error_code": "DB_CONN_FAILED",
  "component": "converter",
  "message": "Failed to connect to database",
  "level": "ERROR"
}
```

用途：调试问题、错误追踪、根因分析

#### 3. 性能日志 (Performance Log)

```json
{
  "timestamp": "2026-01-28 10:30:45",
  "event_type": "performance",
  "operation": "document_convert",
  "duration_ms": 1250,
  "memory_delta": 15728640,
  "level": "PERF"
}
```

用途：性能分析、瓶颈识别、优化建议

#### 4. 并发日志 (Concurrency Log)

```json
{
  "timestamp": "2026-01-28 10:30:45",
  "event_type": "concurrency",
  "type": "connection_threshold_warning",
  "concurrent_users": 180,
  "level": "WARN"
}
```

用途：并发分析、容量规划、扩展决策

### 日志查询

```bash
# 查询审计日志
/app/ds/enterprise-logging.sh query audit | tail -50

# 查询错误日志
/app/ds/enterprise-logging.sh query error | tail -20

# 查询性能日志
/app/ds/enterprise-logging.sh query performance | tail -100

# 查询并发事件
/app/ds/enterprise-logging.sh query concurrency

# 分析所有日志
/app/ds/enterprise-logging.sh analyze
```

### 日志分析

```bash
# 错误统计
grep "error_code" /var/log/onlyoffice/error.log | \
  cut -d'"' -f4 | sort | uniq -c | sort -rn

# 性能统计
grep "duration_ms" /var/log/onlyoffice/performance.log | \
  grep -o '"duration_ms": [0-9]*' | \
  awk '{sum+=$3; count++} END {printf "Average: %.0fms\n", sum/count}'

# 并发趋势
grep "concurrent_users" /var/log/onlyoffice/audit.log | \
  grep -o '"concurrent_users": [0-9]*' | \
  sort -t':' -k2 -n
```

---

## 故障排查

### 常见问题

#### 1. 监控指标不更新

```bash
# 检查监控进程
ps aux | grep enterprise-monitoring

# 检查指标文件
cat /var/lib/onlyoffice/monitoring/metrics.json

# 重启监控
pkill -f enterprise-monitoring
/app/ds/enterprise-monitoring.sh start
```

#### 2. 日志文件过大

```bash
# 手动轮转日志
logrotate -f /etc/logrotate.d/onlyoffice-enterprise

# 查看日志大小
du -h /var/log/onlyoffice/

# 清理旧日志
find /var/log/onlyoffice -name "*.log*" -mtime +30 -delete
```

#### 3. 告警不生效

```bash
# 检查 Prometheus 状态
curl http://localhost:9090/api/v1/targets

# 验证告警规则语法
promtool check rules /etc/onlyoffice/prometheus/alert_rules.yml

# 查看告警状态
curl http://localhost:9090/api/v1/alerts
```

#### 4. 性能指标高

```bash
# 分析 CPU 使用
top -b -n 1 | head -15

# 分析内存使用
free -h

# 查看进程
ps aux | grep -E "node|convert"

# 检查数据库连接
docker exec onlyoffice-postgresql psql -U onlyoffice -c "SELECT count(*) FROM pg_stat_activity;"
```

---

## 性能调优

### 监控系统性能影响

| 操作 | CPU 影响 | 内存影响 | 建议 |
|------|---------|---------|------|
| 收集系统指标 | <1% | <5MB | 每 60s |
| 并发监控 | <1% | <2MB | 每 30s |
| 日志写入 | <2% | <10MB | 异步写 |

### 优化建议

1. **调整收集间隔**
```bash
# 增加间隔以减少开销
COLLECT_INTERVAL=120  # 2 分钟
ALERT_CHECK=60        # 1 分钟
```

2. **启用日志采样**
```bash
# 仅记录 10% 的 TRACE 日志
SAMPLE_RATE=0.1
```

3. **使用异步日志**
```bash
# 日志写入后立即返回，后台异步处理
ASYNC_LOG=true
```

4. **配置日志轮转**
```bash
# 每天轮转，保留最近 30 天
rotate 30
daily
```

---

## 集成示例

### 与 Kubernetes 集成

```yaml
apiVersion: v1
kind: Service
metadata:
  name: onlyoffice-metrics
spec:
  selector:
    app: onlyoffice
  ports:
    - name: metrics
      port: 9090
      targetPort: 9090
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: onlyoffice
spec:
  selector:
    matchLabels:
      app: onlyoffice
  endpoints:
    - port: metrics
      interval: 30s
```

### 与 ELK Stack 集成

```yaml
# logstash 配置
input {
  file {
    path => "/var/log/onlyoffice/*.log"
    start_position => "beginning"
  }
}

filter {
  json {
    source => "message"
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "onlyoffice-%{+YYYY.MM.dd}"
  }
}
```

---

## 仪表板示例

### 主仪表板

- 系统健康状态
- 并发用户数（实时图表）
- CPU/内存/磁盘使用率
- HTTP 请求数和错误率
- 活跃进程状态
- 最新告警

### 性能仪表板

- 响应时间分布
- 吞吐量趋势
- 错误率趋势
- 资源使用趋势
- 性能瓶颈识别

### 并发分析仪表板

- 并发用户数趋势
- 连接数分布
- 数据库连接池利用率
- 高峰时段分析
- 容量规划建议

---

## 生产检查清单

```
□ 监控系统已正确部署
□ 所有关键告警已启用
□ 日志系统已初始化
□ Prometheus 正在运行
□ Grafana 仪表板已导入
□ 告警通知已配置（邮件/短信）
□ ELK 集成已完成（如需要）
□ 日志轮转已配置
□ 备份策略已制定
□ 团队已培训
```

---

**部署完成！** 🎉

现在您可以：
- 访问 Prometheus: http://localhost:9090
- 访问 Grafana: http://localhost:3000 (默认密码: admin)
- 查询日志: `/app/ds/enterprise-logging.sh query audit`
- 查看指标: `/app/ds/enterprise-monitoring.sh collect`
