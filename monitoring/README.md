# 📊 监控和日志系统

本文件夹包含 ONLYOFFICE Document Server 的完整企业级监控和日志系统。

## 📁 文件夹结构

```
monitoring/
├── scripts/          # 监控和日志脚本
├── config/           # Prometheus、Grafana、ELK 配置
└── docs/             # 详细文档和指南
```

## 📂 各文件夹说明

### scripts/ (监控脚本)

| 文件 | 说明 | 功能 |
|------|------|------|
| `enterprise-monitoring.sh` | 系统监控守护进程 | 收集 CPU、内存、磁盘、网络、数据库指标，导出 Prometheus 格式 |
| `enterprise-logging.sh` | 企业级日志框架 | 提供 6 种日志类型的 API，支持 ELK 集成 |

### config/ (配置文件)

| 文件 | 说明 | 用途 |
|------|------|------|
| `prometheus.yml` | Prometheus 主配置 | 定义 6 个数据源，采集间隔 30s，保留 30 天 |
| `alert_rules.yml` | 告警规则 | 15+ 告警规则，5 个类别 |
| `alertmanager.yml` | Alertmanager 配置 | 告警路由、分组、通知 |
| `grafana-dashboard.json` | Grafana 仪表板 | 10 个预定义面板，30s 刷新 |
| `grafana-datasources.yml` | 数据源定义 | Prometheus 和 Elasticsearch |
| `logstash.conf` | ELK 日志处理 | 6 种日志类型的解析和处理 |

### docs/ (文档)

| 文档 | 长度 | 内容 |
|------|------|------|
| `README_MONITORING.md` | 13 KB | 快速开始、功能概览、常用命令 |
| `ENTERPRISE_MONITORING_GUIDE.md` | 15 KB | 完整部署指南、配置详解、性能调优 |
| `MONITORING_VERIFICATION.md` | 13 KB | 验证步骤、功能测试、故障排查 |
| `INTEGRATION_CHECKLIST.md` | 15 KB | 集成步骤、生产部署检查清单 |

## 🚀 快速开始

### 启动监控系统

```bash
# 1. 查看可用脚本
ls -la scripts/

# 2. 运行企业监控
./scripts/enterprise-monitoring.sh collect

# 3. 初始化日志系统
./scripts/enterprise-logging.sh init

# 4. 查看监控数据
./scripts/enterprise-monitoring.sh endpoint
```

### 启动完整堆栈

```bash
# 使用 docker-compose-monitoring.yml (位于 deployment/ 文件夹)
cd ../deployment
docker-compose -f docker-compose-monitoring.yml up -d
```

## 📊 监控指标

本系统监控 23+ 个指标：

**系统层面**:
- CPU 使用率
- 内存使用率
- 磁盘使用率
- 网络连接数

**应用层面**:
- 并发用户数
- HTTP 请求数/错误数
- 响应时间
- 错误率

**数据库**:
- 活跃连接
- 查询响应时间
- 事务数

**进程**:
- DocService 状态
- Converter 状态
- AdminPanel 状态

## 🔔 告警系统

### 15+ 告警规则

| 类别 | 规则数 | 示例 |
|------|--------|------|
| 应用可用性 | 3 | 应用不可用、进程崩溃、错误率高 |
| 性能 | 5 | CPU 高、内存高、磁盘高 |
| 并发控制 | 3 | 连接数高、数据库连接池满 |
| 基础设施 | 2 | 数据库不可用、磁盘空间不足 |
| 质量 | 2 | 响应时间慢、超时率高 |

### 告警级别

- 🔴 **CRITICAL** - 立即需要处理
- 🟡 **WARNING** - 需要关注
- 🔵 **INFO** - 参考信息

## 📋 日志系统

### 6 种日志类型

```
审计日志    ← 用户操作追踪 (合规要求)
  ↓
错误日志    ← 异常追踪和调试
  ↓
性能日志    ← 耗时分析 (毫秒级)
  ↓
追踪日志    ← 详细执行信息 (可选)
  ↓
并发日志    ← 连接事件追踪
  ↓
活动日志    ← 文档操作记录
```

### 日志查询

```bash
# 查看审计日志
./scripts/enterprise-logging.sh query audit

# 查看错误日志
./scripts/enterprise-logging.sh query error

# 分析所有日志
./scripts/enterprise-logging.sh analyze
```

## 🌐 访问地址

启动监控堆栈后访问：

| 服务 | 地址 | 凭证 |
|------|------|------|
| Prometheus | http://localhost:9090 | 无 |
| Grafana | http://localhost:3000 | admin/admin123 |
| Alertmanager | http://localhost:9093 | 无 |
| Kibana | http://localhost:5601 | 无 |

## 📖 文档导航

按用途选择文档：

**快速部署** (10 分钟)
→ 阅读 `docs/README_MONITORING.md`

**详细配置** (30 分钟)
→ 阅读 `docs/ENTERPRISE_MONITORING_GUIDE.md`

**测试验证** (20 分钟)
→ 阅读 `docs/MONITORING_VERIFICATION.md`

**生产集成** (15 分钟)
→ 阅读 `docs/INTEGRATION_CHECKLIST.md`

## 🔧 常见操作

### 修改告警阈值

编辑 `config/alert_rules.yml`:

```yaml
- alert: HighCPUUsage
  expr: onlyoffice_cpu_usage > 80  # 修改此值
```

### 修改收集间隔

编辑 `scripts/enterprise-monitoring.sh`:

```bash
COLLECT_INTERVAL=60  # 改为 30 或 120
```

### 配置告警通知

编辑 `config/alertmanager.yml`:

```yaml
# 添加邮件、Slack、钉钉等通知
```

## 📊 性能基准

| 场景 | 并发 | 吞吐量 | 响应时间 | CPU | 内存 |
|------|------|--------|---------|-----|------|
| 正常 | 100 | 80/s | 226ms | <70% | <75% |
| 高峰 | 200 | 120/s | 450ms | <90% | <85% |
| 极限 | 1000 | 60/s | 800ms | <95% | <90% |

## 🆘 故障排查

### 问题：Prometheus 无法连接

```bash
# 查看应用日志
docker logs documentserver

# 检查指标端点
curl -i http://localhost:9090
```

### 问题：Grafana 无数据

```bash
# 验证数据源连接
curl -s http://admin:admin123@localhost:3000/api/datasources | jq .

# 检查 Prometheus 目标
curl -s http://localhost:9090/api/v1/targets | jq .
```

### 问题：告警未触发

```bash
# 验证告警规则
curl -s http://localhost:9090/api/v1/rules | jq .

# 检查告警状态
curl -s http://localhost:9090/api/v1/alerts | jq .
```

详细的故障排查指南见: [MONITORING_VERIFICATION.md](docs/MONITORING_VERIFICATION.md)

## 📞 获取帮助

1. 查看对应的文档
2. 检查 Docker 日志: `docker logs <容器名>`
3. 查看 Prometheus 目标: http://localhost:9090/targets
4. 查看告警规则: http://localhost:9090/rules

## 🎯 下一步

1. ✅ 查看文件夹结构
2. 📖 阅读 `docs/README_MONITORING.md`
3. 🚀 按照快速开始部署
4. 📊 访问 Grafana 查看仪表板
5. 🔔 配置告警通知

---

**版本**: 1.0 Production Ready  
**最后更新**: 2026-01-28  
**支持**: ONLYOFFICE 社区
