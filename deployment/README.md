# 🐳 部署和编排

本文件夹包含 ONLYOFFICE Document Server 及其完整监控堆栈的部署配置。

## 📁 文件夹结构

```
deployment/
├── docker-compose-monitoring.yml    # 完整的 11 个服务堆栈
├── docker-compose.yml               # 基础应用堆栈
├── deploy-monitoring.sh             # 一键部署脚本
├── run-document-server.sh           # 应用启动脚本
└── README.md                         # 本文件
```

## 📂 文件说明

### docker-compose-monitoring.yml

**完整的企业级监控堆栈**

包含 11 个服务：

**核心服务 (4个)**:
- `documentserver` - ONLYOFFICE Document Server
- `onlyoffice-postgresql` - PostgreSQL 15 数据库
- `onlyoffice-rabbitmq` - RabbitMQ 消息队列
- `onlyoffice-redis` - Redis 缓存

**监控服务 (6个)**:
- `prometheus` - 指标存储和查询
- `grafana` - 仪表板可视化
- `alertmanager` - 告警管理
- `node-exporter` - 系统指标
- `cadvisor` - 容器监控
- `postgres-exporter` - 数据库指标

**日志服务 (3个)**:
- `elasticsearch` - 日志存储
- `logstash` - 日志处理
- `kibana` - 日志查询界面

### docker-compose.yml

**基础应用堆栈** (仅包含应用和必要的中间件)

### deploy-monitoring.sh

**一键部署脚本**

自动执行：
- ✓ 前置条件检查 (Docker, Docker Compose)
- ✓ 必要文件验证
- ✓ 目录创建
- ✓ 容器启动
- ✓ 服务验证
- ✓ Grafana 初始化
- ✓ 监控和日志初始化

### run-document-server.sh

**应用启动脚本**

负责：
- SSL 配置
- 数据库初始化
- 环境变量设置
- Supervisor 进程管理

## 🚀 快速部署

### 方式 1: 完整监控堆栈 (推荐)

```bash
# 进入部署目录
cd deployment

# 运行一键部署脚本
chmod +x deploy-monitoring.sh
./deploy-monitoring.sh

# 等待 30 秒后访问:
# - Document Server: http://localhost
# - Grafana: http://localhost:3000 (admin/admin123)
# - Prometheus: http://localhost:9090
# - Kibana: http://localhost:5601
```

### 方式 2: 手动启动

```bash
# 启动完整堆栈
docker-compose -f docker-compose-monitoring.yml up -d

# 或仅启动基础堆栈
docker-compose -f docker-compose.yml up -d
```

### 方式 3: 使用脚本参数

```bash
# 查看帮助
./deploy-monitoring.sh --help

# 停止服务
./deploy-monitoring.sh stop

# 重启服务
./deploy-monitoring.sh restart

# 查看状态
./deploy-monitoring.sh status

# 查看日志
./deploy-monitoring.sh logs
```

## 📊 服务配置

### 核心应用配置

```yaml
documentserver:
  image: onlyoffice/documentserver:latest
  ports:
    - "80:80"          # HTTP
    - "443:443"        # HTTPS
    - "9090:9090"      # 监控指标端点
  environment:
    - DS_EDITION=community
    - POSTGRES_SERVER_HOST=onlyoffice-postgresql
    - RABBITMQ_SERVER_HOST=onlyoffice-rabbitmq
    - REDIS_SERVER_HOST=onlyoffice-redis
```

### 数据库配置

```yaml
onlyoffice-postgresql:
  image: postgres:15-alpine
  environment:
    - POSTGRES_DB=onlyoffice
    - POSTGRES_USER=onlyoffice
    - POSTGRES_PASSWORD=onlyoffice
  command:
    - "postgres"
    - "-c"
    - "max_connections=100"
```

### 监控堆栈配置

```yaml
prometheus:
  # 采集间隔: 30 秒
  # 数据保留: 30 天
  # 告警规则: 已配置

grafana:
  # 默认用户: admin
  # 默认密码: admin123
  # 预定义仪表板: 10 个面板

alertmanager:
  # 告警聚合和分组
  # 多渠道通知 (邮件/Slack/钉钉)

elasticsearch:
  # 日志索引: 每日分区
  # 数据保留: 30 天
```

## 🔌 端口映射

### Web 服务

| 服务 | 端口 | 说明 |
|------|------|------|
| Document Server | 80/443 | HTTP/HTTPS |
| Grafana | 3000 | 仪表板 |
| Kibana | 5601 | 日志查询 |
| Prometheus | 9090 | 指标查询 |
| Alertmanager | 9093 | 告警管理 |

### 监控端点

| 端点 | 端口 | 用途 |
|------|------|------|
| 应用监控 | 9090 | 自定义指标 |
| Node Exporter | 9100 | 系统指标 |
| PostgreSQL Exporter | 9187 | 数据库指标 |
| cAdvisor | 8080 | 容器监控 |
| Docker Metrics | 9323 | 引擎监控 |
| Elasticsearch | 9200 | 日志存储 |

### 内部服务

| 服务 | 端口 | 说明 |
|------|------|------|
| PostgreSQL | 5432 | 数据库 (内部) |
| Redis | 6379 | 缓存 (内部) |
| RabbitMQ API | 5672 | 消息队列 (内部) |
| RabbitMQ 管理 | 15672 | 管理界面 |

## 🔧 常用命令

### 查看容器状态

```bash
# 列出所有容器
docker-compose -f docker-compose-monitoring.yml ps

# 查看实时日志
docker-compose -f docker-compose-monitoring.yml logs -f

# 查看特定服务日志
docker logs documentserver
docker logs prometheus
docker logs grafana
```

### 管理容器

```bash
# 启动所有服务
docker-compose -f docker-compose-monitoring.yml up -d

# 停止所有服务
docker-compose -f docker-compose-monitoring.yml down

# 重启特定服务
docker-compose -f docker-compose-monitoring.yml restart documentserver

# 查看容器资源使用
docker stats

# 进入容器
docker exec -it documentserver bash
```

### 数据库操作

```bash
# 连接 PostgreSQL
docker exec -it onlyoffice-postgresql psql -U onlyoffice -d onlyoffice

# 备份数据库
docker exec onlyoffice-postgresql pg_dump -U onlyoffice onlyoffice > backup.sql

# 恢复数据库
docker exec -i onlyoffice-postgresql psql -U onlyoffice onlyoffice < backup.sql
```

## 📦 环境变量

### 应用配置

```bash
# 数据库
POSTGRES_SERVER_HOST=onlyoffice-postgresql
POSTGRES_SERVER_PORT=5432
POSTGRES_SERVER_DB_NAME=onlyoffice
POSTGRES_SERVER_DB_USER=onlyoffice
POSTGRES_SERVER_DB_PASSWORD=onlyoffice

# 消息队列
RABBITMQ_SERVER_HOST=onlyoffice-rabbitmq
RABBITMQ_SERVER_PORT=5672
RABBITMQ_SERVER_USER=guest
RABBITMQ_SERVER_PASSWORD=guest

# 缓存
REDIS_SERVER_HOST=onlyoffice-redis
REDIS_SERVER_PORT=6379
```

### 监控配置

```bash
# 启用监控
ONLYOFFICE_MONITORING_ENABLED=true

# 启用日志
ONLYOFFICE_LOGGING_ENABLED=true

# 启用调试 (会产生大量日志)
ONLYOFFICE_DEBUG=false
```

## 🔒 安全配置

### 生产部署建议

```yaml
# 1. 修改默认密码
grafana:
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=YOUR_STRONG_PASSWORD

# 2. 启用 HTTPS
documentserver:
  environment:
    - SSL_CERTIFICATE_PATH=/etc/onlyoffice/certs/cert.pem
    - SSL_KEY_PATH=/etc/onlyoffice/certs/key.pem

# 3. 配置防火墙
# 仅允许必要的端口

# 4. 设置资源限制
services:
  documentserver:
    resources:
      limits:
        cpus: '4'
        memory: 8G
```

### 备份配置

```bash
# 备份所有配置
tar -czf onlyoffice-backup-$(date +%Y%m%d).tar.gz \
  monitoring/config \
  deployment

# 备份数据库
docker exec onlyoffice-postgresql pg_dump -U onlyoffice onlyoffice | \
  gzip > onlyoffice-db-$(date +%Y%m%d).sql.gz
```

## 🆘 常见问题

### Q: 如何修改端口映射

**A**: 编辑 `docker-compose-monitoring.yml`:

```yaml
services:
  documentserver:
    ports:
      - "8080:80"    # 从 80 改为 8080
      - "8443:443"   # 从 443 改为 8443

  grafana:
    ports:
      - "13000:3000" # 从 3000 改为 13000
```

然后重启：
```bash
docker-compose -f docker-compose-monitoring.yml down
docker-compose -f docker-compose-monitoring.yml up -d
```

### Q: 如何持久化数据

**A**: 检查数据卷配置：

```yaml
volumes:
  onlyoffice-data:           # 应用数据
  onlyoffice-postgres-data:  # 数据库
  onlyoffice-redis-data:     # 缓存
  prometheus-data:           # 监控数据
  grafana-data:              # Grafana 设置
  elasticsearch-data:        # 日志
```

数据自动保存在 Docker 卷中。

### Q: 如何增加资源限制

**A**: 修改 `docker-compose-monitoring.yml`:

```yaml
services:
  documentserver:
    resources:
      limits:
        cpus: '8'        # CPU 核数
        memory: 16G      # 内存大小
```

### Q: 如何清理旧数据

**A**:
```bash
# 清理 Prometheus 数据 (保留最近 7 天)
# 编辑 docker-compose-monitoring.yml
# 修改: "--storage.tsdb.retention.time=7d"

# 清理 Elasticsearch 日志 (保留最近 7 天)
# 在 Kibana 中配置索引生命周期管理

# 清理 Docker 系统数据
docker system prune -a --volumes
```

## 📈 扩展部署

### 添加新监控端点

```yaml
# 在 docker-compose-monitoring.yml 中添加
new-exporter:
  image: your-exporter:latest
  ports:
    - "9999:9999"
  networks:
    - onlyoffice-network
```

在 `../monitoring/config/prometheus.yml` 中添加：

```yaml
scrape_configs:
  - job_name: 'new-exporter'
    static_configs:
      - targets: ['new-exporter:9999']
```

### 多节点部署

```yaml
# 使用 Compose 文件变量实现多节点
services:
  documentserver-1:
    image: onlyoffice/documentserver:latest
    environment:
      - NODE_ID=node-1
  
  documentserver-2:
    image: onlyoffice/documentserver:latest
    environment:
      - NODE_ID=node-2
```

配合 HAProxy 或 Nginx 进行负载均衡。

## 📖 文档导航

相关文档：

| 文档 | 位置 | 内容 |
|------|------|------|
| 监控指南 | `../monitoring/docs/` | 完整的监控系统文档 |
| 性能测试 | `../performance-testing/docs/` | 性能测试工具文档 |
| 安全审计 | `../security/` | 安全配置指南 |

## 🎯 典型部署流程

```
1. 准备环境
   ├─ 检查 Docker/Docker Compose
   ├─ 创建工作目录
   └─ 准备配置文件

2. 启动应用
   ├─ 运行 deploy-monitoring.sh
   ├─ 等待服务启动 (30s)
   └─ 验证健康检查

3. 初始化监控
   ├─ 配置 Grafana 仪表板
   ├─ 验证 Prometheus 数据
   └─ 启用告警通知

4. 生产运维
   ├─ 定期备份数据
   ├─ 监控告警
   ├─ 性能分析
   └─ 容量规划

5. 故障处理
   ├─ 查看日志
   ├─ 诊断问题
   ├─ 恢复服务
   └─ 文档更新
```

---

**版本**: 1.0 Production Ready  
**最后更新**: 2026-01-28  
**支持**: ONLYOFFICE 社区
