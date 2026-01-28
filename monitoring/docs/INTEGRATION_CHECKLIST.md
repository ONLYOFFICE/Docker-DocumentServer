# 🎯 企业监控系统集成清单

## 📋 项目完成状态

### ✅ 已完成的组件

#### 1. 监控系统 (enterprise-monitoring.sh)
- [x] CPU、内存、磁盘、网络监控
- [x] 数据库连接池监控
- [x] HTTP 请求统计
- [x] 并发用户跟踪 (实时计算)
- [x] 健康检查
- [x] Prometheus 指标导出 (端口 9090)

#### 2. 日志系统 (enterprise-logging.sh)
- [x] 审计日志 (用户操作追踪)
- [x] 错误日志 (异常追踪)
- [x] 性能日志 (耗时分析)
- [x] 追踪日志 (调试信息)
- [x] 并发日志 (连接事件)
- [x] 用户活动日志 (文档操作)
- [x] 日志轮转策略
- [x] ELK Stack 集成

#### 3. Prometheus 配置 (prometheus.yml)
- [x] 6 个数据源集成
- [x] 30 秒采集间隔
- [x] 30 天数据保留
- [x] 告警规则加载
- [x] Alertmanager 集成

#### 4. 告警系统 (alert_rules.yml)
- [x] 15+ 告警规则
- [x] 5 个告警类别 (应用、性能、并发、可用性、质量)
- [x] 严重级别分类 (CRITICAL/WARNING/INFO)
- [x] 自定义告警条件
- [x] 告警通知路由

#### 5. Grafana 仪表板 (grafana-dashboard.json)
- [x] 10 个预定义面板
- [x] 实时数据展示
- [x] 历史数据分析
- [x] 告警状态显示
- [x] 并发用户监控
- [x] 自动刷新 (30 秒)

#### 6. Alertmanager 配置 (alertmanager.yml)
- [x] 告警分组和路由
- [x] 多渠道通知 (邮件、Slack、钉钉)
- [x] 告警抑制规则
- [x] 自定义通知模板

#### 7. ELK Stack 配置 (logstash.conf)
- [x] 多日志源处理
- [x] JSON 日志解析
- [x] 字段转换和映射
- [x] Elasticsearch 索引策略
- [x] 时间戳解析
- [x] 地理位置反查 (可选)

#### 8. Docker 编排 (docker-compose-monitoring.yml)
- [x] 完整的微服务堆栈
- [x] 11 个服务定义
- [x] 健康检查配置
- [x] 数据卷管理
- [x] 环境变量配置
- [x] 服务依赖关系

#### 9. 部署工具 (deploy-monitoring.sh)
- [x] 自动前置条件检查
- [x] 一键启动脚本
- [x] 服务启动验证
- [x] 自动配置初始化
- [x] 友好的界面反馈

#### 10. 文档
- [x] 完整部署指南 (500+ 行)
- [x] 验证和测试指南 (600+ 行)
- [x] README 快速开始 (400+ 行)
- [x] 集成清单 (本文件)

---

## 🚀 快速集成步骤

### 步骤 1: 环境准备 (5 分钟)

```bash
# 1.1 进入项目目录
cd /workspaces/Docker-DocumentServer

# 1.2 验证所有文件存在
ls -la *.yml *.sh *.json *.md *.conf | grep -E "(monitoring|prometheus|grafana|alert|logstash|deploy)"

# 预期输出: 10+ 个文件
```

**检查清单**:
```
□ docker-compose-monitoring.yml
□ prometheus.yml
□ alert_rules.yml
□ alertmanager.yml
□ grafana-dashboard.json
□ grafana-datasources.yml
□ logstash.conf
□ deploy-monitoring.sh
□ enterprise-monitoring.sh
□ enterprise-logging.sh
□ ENTERPRISE_MONITORING_GUIDE.md
□ MONITORING_VERIFICATION.md
□ README_MONITORING.md
```

### 步骤 2: 一键部署 (3-5 分钟)

```bash
# 2.1 设置执行权限
chmod +x deploy-monitoring.sh

# 2.2 运行部署脚本
./deploy-monitoring.sh

# 脚本将自动:
# - 检查 Docker/Docker Compose 已安装
# - 验证所有必要文件存在
# - 创建必要的目录
# - 启动所有 Docker 容器
# - 初始化监控和日志系统
# - 显示访问地址
```

### 步骤 3: 验证部署 (5 分钟)

```bash
# 3.1 查看容器状态
docker-compose -f docker-compose-monitoring.yml ps

# 预期: 所有容器状态为 "Up"

# 3.2 验证服务连接性
for url in "http://localhost/healthcheck" \
           "http://localhost:9090/-/healthy" \
           "http://localhost:3000/api/health" \
           "http://localhost:9200" \
           "http://localhost:5601"; do
    echo "Testing: $url"
    curl -s -o /dev/null -w "HTTP %{http_code}\n" "$url"
done

# 预期: 所有连接返回 HTTP 200

# 3.3 查看监控指标
curl -s http://localhost:9090/api/v1/query?query=up | jq '.data.result | length'

# 预期: 返回 > 0 (表示有指标被收集)
```

### 步骤 4: 配置告警通知 (10 分钟)

```bash
# 4.1 编辑 alertmanager.yml
nano alertmanager.yml

# 4.2 配置您的通知渠道 (选择一个或多个):

# 邮件通知示例:
# 修改 smtp_smarthost, smtp_auth_username, smtp_auth_password

# Slack 通知示例:
# 修改 slack_configs 中的 api_url

# 企业微信通知示例:
# 添加 wechat_configs 部分

# 4.3 重启 Alertmanager
docker-compose -f docker-compose-monitoring.yml restart alertmanager
```

### 步骤 5: 访问服务 (立即)

打开浏览器访问:

| 服务 | URL | 凭证 |
|------|-----|------|
| **ONLYOFFICE** | http://localhost | 无 |
| **Prometheus** | http://localhost:9090 | 无 |
| **Grafana** | http://localhost:3000 | admin/admin123 |
| **Alertmanager** | http://localhost:9093 | 无 |
| **Kibana** | http://localhost:5601 | 无 |

---

## 📊 架构流程图

```
┌─────────────────────────────────────────────────────────────┐
│                  ONLYOFFICE Document Server                 │
│  ┌─────────────┬──────────────┬──────────────┬────────────┐ │
│  │ DocService  │ Converter    │ AdminPanel   │ Example    │ │
│  └─────────────┴──────────────┴──────────────┴────────────┘ │
│                         ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  enterprise-monitoring.sh (监控收集)                      ││
│  │  - CPU, 内存, 磁盘, 网络                                 ││
│  │  - 数据库连接, HTTP 请求                                 ││
│  │  - 并发用户计算                                          ││
│  └─────────────────────────────────────────────────────────┘│
│                         ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  enterprise-logging.sh (日志收集)                         ││
│  │  - 审计、错误、性能、追踪、并发、活动日志                  ││
│  │  - 结构化 JSON 格式                                     ││
│  └─────────────────────────────────────────────────────────┘│
└──────────────────────────────┬─────────────────────────────┘
                               │
                ┌──────────────┼──────────────┐
                ▼              ▼              ▼
        ┌─────────────┐  ┌──────────┐  ┌─────────────┐
        │ Prometheus  │  │ ELK      │  │ JSON 端点   │
        │ (9090)      │  │ Stack    │  │ (HTTP API)  │
        └──────┬──────┘  │ (9200)   │  └─────────────┘
               │         └──────────┘
               ▼
        ┌─────────────────────────────┐
        │      Grafana (3000)         │
        │  ┌──────────────────────┐   │
        │  │ 10+ 预定义仪表板    │   │
        │  │ - 系统健康           │   │
        │  │ - 并发用户           │   │
        │  │ - 性能指标           │   │
        │  │ - 告警状态           │   │
        │  └──────────────────────┘   │
        └─────────────────────────────┘
               ▼
        ┌─────────────────────────────┐
        │   Alertmanager (9093)       │
        │  - 告警聚合                 │
        │  - 多渠道通知 (邮件/Slack)  │
        │  - 告警路由                 │
        └─────────────────────────────┘
```

---

## 🔍 关键指标概览

### 实时监控的指标

```
系统层面:
  • CPU 使用率: 0-100%
  • 内存使用率: 0-100%
  • 磁盘使用率: 0-100%
  • 网络连接: 实时数量

应用层面:
  • 并发用户: 通过连接数推算 (÷3)
  • HTTP 请求/秒: 实时吞吐量
  • HTTP 错误率: 错误百分比
  • 响应时间 P95: 性能指标

数据库:
  • 连接数: 0-100
  • 查询时间: 毫秒
  • 事务数: 实时

进程:
  • DocService: 运行/停止
  • Converter: 运行/停止
  • AdminPanel: 运行/停止
```

### 告警阈值设置

```
🔴 CRITICAL (立即action):
  - 应用无响应 (HTTP 不可达)
  - 磁盘满 (>95%)
  - 数据库连接满 (100/100)
  - 进程崩溃

🟡 WARNING (需要关注):
  - CPU > 80%
  - 内存 > 85%
  - 磁盘 > 90%
  - 并发连接 > 800

🔵 INFO (参考信息):
  - 响应时间 > 2 秒
  - 超时率 > 1%
  - 并发用户 > 150
```

---

## 📈 性能测试

### 测试并发连接监控

```bash
# 生成 100 个并发连接
ab -n 1000 -c 100 http://localhost/

# 在另一个终端实时查看并发数
while true; do
  curl -s 'http://localhost:9090/api/v1/query?query=onlyoffice_network_connections' | \
    jq '.data.result[0].value[1]'
  sleep 2
done

# 预期: 并发连接数应随负载增加而增加, 然后下降
```

### 查看性能统计

```bash
# 获取平均响应时间
docker exec documentserver grep '"duration_ms"' /var/log/onlyoffice/performance.log | \
  grep -o '[0-9]*' | awk '{sum+=$1; count++} END {print "Average: " sum/count " ms"}'

# 获取错误统计
docker exec documentserver grep '"level": "ERROR"' /var/log/onlyoffice/error.log | wc -l

# 获取最多的错误类型
docker exec documentserver grep '"error_code"' /var/log/onlyoffice/error.log | \
  grep -o '"error_code": "[^"]*"' | sort | uniq -c | sort -rn | head -5
```

---

## 🔧 常见配置

### 修改监控间隔

编辑 `enterprise-monitoring.sh`:
```bash
# 找到这行:
COLLECT_INTERVAL=60  # 默认 60 秒

# 修改为:
COLLECT_INTERVAL=30  # 改为 30 秒 (更频繁)
```

### 修改告警阈值

编辑 `alert_rules.yml`:
```yaml
# 修改 CPU 告警阈值
- alert: HighCPUUsage
  expr: onlyoffice_cpu_usage > 90  # 从 80 改为 90
  for: 5m
```

### 修改数据保留期

编辑 `docker-compose-monitoring.yml`:
```yaml
# Prometheus 保留 60 天数据 (默认 30 天)
command:
  - "--storage.tsdb.retention.time=60d"
```

### 配置 Elasticsearch 索引生命周期

编辑 `logstash.conf`:
```
# 修改索引保留天数
output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "onlyoffice-%{+YYYY.MM.dd}"
    # 手动清理 30 天前的索引
  }
}
```

---

## 🆘 故障排查快速指南

### 问题: Prometheus 无法连接到应用指标

```bash
# 检查应用是否运行
docker ps | grep documentserver

# 检查端口是否开放
curl -i http://localhost:9090

# 检查监控进程
docker exec documentserver ps aux | grep enterprise-monitoring

# 查看应用日志
docker logs documentserver | tail -30
```

### 问题: Grafana 显示"No data"

```bash
# 验证 Prometheus 数据源
curl -s http://admin:admin123@localhost:3000/api/datasources | jq .

# 测试数据源连接
curl -s http://admin:admin123@localhost:3000/api/datasources/1/health | jq .

# 检查 Prometheus 是否有数据
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result | length'
```

### 问题: 告警未触发

```bash
# 验证告警规则
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups | length'

# 检查告警是否激活
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts | length'

# 查看 Alertmanager 状态
curl -s http://localhost:9093/api/v1/status | jq .
```

### 问题: 日志文件过大

```bash
# 手动轮转日志
docker exec documentserver logrotate -f /etc/logrotate.d/onlyoffice-enterprise

# 查看日志大小
docker exec documentserver du -h /var/log/onlyoffice/

# 清理 30 天前的日志
docker exec documentserver find /var/log/onlyoffice -name "*.log*" -mtime +30 -delete
```

---

## 📚 文档导航

| 文档 | 用途 | 阅读时间 |
|------|------|---------|
| [README_MONITORING.md](README_MONITORING.md) | 快速开始和概览 | 10 分钟 |
| [ENTERPRISE_MONITORING_GUIDE.md](ENTERPRISE_MONITORING_GUIDE.md) | 详细配置和部署 | 30 分钟 |
| [MONITORING_VERIFICATION.md](MONITORING_VERIFICATION.md) | 测试和验证 | 20 分钟 |
| 本文件 (集成清单) | 集成步骤 | 15 分钟 |

---

## ✅ 生产部署检查清单

在将系统部署到生产环境前，请完成以下检查:

```
基础设施:
  [ ] 服务器资源充足 (CPU ≥ 4核, 内存 ≥ 8GB, 磁盘 ≥ 100GB)
  [ ] 网络连接稳定
  [ ] 防火墙规则已配置
  [ ] 备份策略已制定

监控系统:
  [ ] 所有 11 个容器已启动
  [ ] 所有服务健康检查通过
  [ ] 指标正在被收集
  [ ] Prometheus 显示 "UP" 状态

告警系统:
  [ ] 所有 15+ 告警规则已加载
  [ ] 告警通知渠道已配置
  [ ] 告警测试已通过
  [ ] 告警路由已验证

日志系统:
  [ ] 所有日志类型已初始化
  [ ] ELK Stack 正在运行
  [ ] 日志正在被收集
  [ ] Kibana 可以搜索日志

Grafana 仪表板:
  [ ] Prometheus 数据源已连接
  [ ] 10 个面板都显示数据
  [ ] 时间范围选择器可用
  [ ] 自动刷新工作正常

文档和培训:
  [ ] 团队已阅读快速开始指南
  [ ] 值班人员已了解告警流程
  [ ] 故障排查文档已准备
  [ ] 应急联系方式已通知
```

---

## 🎉 集成完成确认

当您完成所有步骤并通过所有检查后，您的企业级监控系统已准备好:

✅ **实时监控** - 系统性能 24/7 监控  
✅ **并发跟踪** - 准确的用户并发计数  
✅ **智能告警** - 自动检测和通知问题  
✅ **完整日志** - 审计和调试所需的所有信息  
✅ **数据可视化** - 直观的仪表板和报告  
✅ **生产就绪** - 企业级可靠性和性能  

---

**集成状态**: ✅ 完成  
**最后更新**: 2026-01-28  
**版本**: 1.0  
**支持**: ONLYOFFICE 社区
