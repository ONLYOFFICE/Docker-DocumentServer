# 📊 企业级监控系统验证指南

## 快速验证清单

### ✅ 部署后的验证步骤

#### 1. 服务启动验证

```bash
# 查看所有容器状态
docker-compose -f docker-compose-monitoring.yml ps

# 输出应该显示:
# NAME                      STATUS              PORTS
# documentserver            Up (healthy)        80->80, 443->443, 9090->9090
# prometheus                Up                  9090->9090
# grafana                   Up                  3000->3000
# alertmanager              Up                  9093->9093
# node-exporter             Up                  9100->9100
# cadvisor                  Up                  8080->8080
# postgres-exporter         Up                  9187->9187
# elasticsearch             Up                  9200->9200, 9300->9300
# logstash                  Up
# kibana                    Up                  5601->5601
```

#### 2. 端口连接验证

```bash
# Prometheus
curl -i http://localhost:9090/-/healthy
# Expected: HTTP/1.1 200 OK

# Grafana
curl -i http://localhost:3000/api/health
# Expected: HTTP/1.1 200 OK

# Alertmanager
curl -i http://localhost:9093/-/healthy
# Expected: HTTP/1.1 200 OK

# Elasticsearch
curl -i http://localhost:9200
# Expected: HTTP/1.1 200 OK

# Document Server
curl -i http://localhost/healthcheck
# Expected: HTTP/1.1 200 OK
```

#### 3. 数据收集验证

```bash
# 查看 Prometheus 指标
curl -s http://localhost:9090/api/v1/query?query=up | jq .

# 应该看到所有 job 的状态:
# {
#   "status": "success",
#   "data": {
#     "result": [
#       {"metric": {"job": "onlyoffice-app"}, "value": [1234567890, "1"]},
#       {"metric": {"job": "node"}, "value": [1234567890, "1"]},
#       ...
#     ]
#   }
# }

# 查看收集的指标数量
curl -s http://localhost:9090/api/v1/query?query=count(up) | jq .

# 查看特定指标
curl -s 'http://localhost:9090/api/v1/query?query=onlyoffice_network_connections' | jq .
```

#### 4. 日志系统验证

```bash
# 检查日志目录
docker exec documentserver ls -la /var/log/onlyoffice/

# 应该看到:
# audit.log
# error.log
# performance.log
# trace.log
# concurrency.log
# activity.log

# 查看日志内容
docker exec documentserver tail -f /var/log/onlyoffice/audit.log

# 查询日志
docker exec documentserver /app/ds/enterprise-logging.sh query audit | head -5
```

#### 5. 告警系统验证

```bash
# 查看 Prometheus 告警规则
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[0].rules'

# 应该看到 15+ 条告警规则

# 查看告警状态
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts'

# 查看 Alertmanager 告警
curl -s http://localhost:9093/api/v1/alerts | jq .
```

#### 6. 指标端点验证

```bash
# ONLYOFFICE 应用指标
curl -s http://localhost:9090/metrics | head -20

# Node Exporter 指标
curl -s http://localhost:9100/metrics | head -20

# PostgreSQL 指标
curl -s http://localhost:9187/metrics | head -20

# Docker 指标
curl -s http://localhost:9323/metrics | head -20
```

---

## 功能测试

### 🧪 测试 1: 并发连接监控

#### 步骤 1: 生成并发连接

```bash
# 使用 Apache Bench 生成并发连接
ab -n 1000 -c 100 http://localhost/

# 或使用 wrk
wrk -t4 -c100 -d30s http://localhost/
```

#### 步骤 2: 实时检查并发指标

```bash
# 在另一个终端, 实时查询并发连接数
while true; do
  curl -s 'http://localhost:9090/api/v1/query?query=onlyoffice_network_connections' | \
    jq '.data.result[0].value[1]'
  sleep 2
done

# 或查询并发用户数 (连接数 / 3)
curl -s 'http://localhost:9090/api/v1/query?query=onlyoffice_network_connections/3' | jq .
```

#### 步骤 3: 验证 Grafana 仪表板

1. 访问 http://localhost:3000
2. 用户名: `admin`, 密码: `admin123`
3. 查看 "并发用户数" 面板
4. 应该看到实时连接数增加

### 🧪 测试 2: CPU 和内存监控

#### 步骤 1: 触发 CPU 负载

```bash
# 在 Document Server 中生成 CPU 负载
docker exec documentserver bash -c "stress --cpu 2 --timeout 60s" &

# 或使用 yes 命令
docker exec documentserver yes > /dev/null &
```

#### 步骤 2: 监控 CPU 使用率

```bash
# 查询 CPU 指标
curl -s 'http://localhost:9090/api/v1/query?query=onlyoffice_cpu_usage' | jq .

# 应该看到 CPU 使用率上升 (> 50%)
```

#### 步骤 3: 验证告警

```bash
# CPU 使用率 > 80% 应该触发告警
# 等待告警条件满足 (通常需要 1-5 分钟)
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.labels.alertname == "HighCPUUsage")'
```

### 🧪 测试 3: 错误日志捕获

#### 步骤 1: 模拟应用错误

```bash
# 访问不存在的端点触发 404
curl -i http://localhost/nonexistent

# 查看错误日志
docker exec documentserver tail -f /var/log/onlyoffice/error.log
```

#### 步骤 2: 验证日志内容

```bash
# 查询错误日志中的 404 错误
docker exec documentserver grep "404" /var/log/onlyoffice/error.log | wc -l
```

### 🧪 测试 4: 文档操作审计

#### 步骤 1: 创建和编辑文档

```bash
# 访问 ONLYOFFICE Web 界面并创建一个新文档
# 在浏览器中: http://localhost/welcome

# 或使用 API 创建文档
curl -X POST http://localhost/api/documents \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Document"}'
```

#### 步骤 2: 检查审计日志

```bash
# 查看审计日志
docker exec documentserver tail -f /var/log/onlyoffice/audit.log | grep -i "document"

# 应该看到类似:
# {"timestamp": "2026-01-28 10:30:45", "event_type": "audit", "action": "document_create", ...}
```

### 🧪 测试 5: 数据库连接池监控

#### 步骤 1: 查看数据库连接

```bash
# 查询数据库活跃连接
docker exec onlyoffice-postgresql psql -U onlyoffice -c \
  "SELECT count(*) as active_connections FROM pg_stat_activity;"

# 输出应该显示连接数
```

#### 步骤 2: 监控连接指标

```bash
# 查询 Prometheus 中的数据库连接
curl -s 'http://localhost:9090/api/v1/query?query=onlyoffice_database_connections' | jq .

# 应该与 PostgreSQL 查询结果一致
```

#### 步骤 3: 验证连接池告警

```bash
# 当连接 >= 100 时应触发告警
curl -s http://localhost:9090/api/v1/alerts | \
  jq '.data.alerts[] | select(.labels.alertname == "DatabaseConnectionPoolFull")'
```

---

## 日志查询示例

### 审计日志查询

```bash
# 查看所有审计事件
docker exec documentserver /app/ds/enterprise-logging.sh query audit

# 查看最近 10 个审计事件
docker exec documentserver /app/ds/enterprise-logging.sh query audit | tail -10

# 查看特定用户的操作
docker exec documentserver grep '"user": "admin"' /var/log/onlyoffice/audit.log

# 查看特定日期的操作
docker exec documentserver grep "2026-01-28" /var/log/onlyoffice/audit.log
```

### 错误日志查询

```bash
# 查看所有错误
docker exec documentserver /app/ds/enterprise-logging.sh query error

# 查看最频繁的错误代码
docker exec documentserver grep '"error_code"' /var/log/onlyoffice/error.log | \
  grep -o '"error_code": "[^"]*"' | sort | uniq -c | sort -rn

# 查看特定组件的错误
docker exec documentserver grep '"component": "converter"' /var/log/onlyoffice/error.log
```

### 性能日志查询

```bash
# 查看所有性能事件
docker exec documentserver /app/ds/enterprise-logging.sh query performance

# 计算平均响应时间
docker exec documentserver grep '"duration_ms"' /var/log/onlyoffice/performance.log | \
  grep -o '"duration_ms": [0-9]*' | \
  awk -F': ' '{sum += $2; count++} END {printf "Average: %.0f ms\n", sum/count}'

# 查看最慢的操作
docker exec documentserver grep '"duration_ms"' /var/log/onlyoffice/performance.log | \
  sort -t':' -k3 -rn | head -10
```

### 并发日志查询

```bash
# 查看并发事件
docker exec documentserver /app/ds/enterprise-logging.sh query concurrency

# 查看并发用户数峰值
docker exec documentserver grep '"concurrent_users"' /var/log/onlyoffice/concurrency.log | \
  grep -o '"concurrent_users": [0-9]*' | \
  awk -F': ' '{print $2}' | sort -n | tail -1
```

### 分析所有日志

```bash
# 运行日志分析
docker exec documentserver /app/ds/enterprise-logging.sh analyze

# 输出应该包括:
# - 总事件数
# - 错误率
# - 平均响应时间
# - 并发用户数统计
```

---

## 性能测试

### 📈 测试场景 1: 正常负载

```bash
# 100 个并发用户, 持续 5 分钟
wrk -t4 -c100 -d300s http://localhost/

# 预期结果:
# - 成功率 > 99%
# - 平均响应时间 < 500ms
# - CPU 使用率 < 70%
# - 内存使用率 < 75%
```

### 📈 测试场景 2: 峰值负载

```bash
# 200 个并发用户, 持续 2 分钟
wrk -t4 -c200 -d120s http://localhost/

# 预期结果:
# - 成功率 > 95%
# - 平均响应时间 < 1s
# - CPU 使用率 < 90%
# - 数据库连接 < 100
```

### 📈 测试场景 3: 持久连接

```bash
# 1000 个并发连接, 持续 10 分钟
wrk -t4 -c1000 -d600s http://localhost/

# 预期结果:
# - 连接保持稳定
# - 没有连接泄漏
# - 内存增长缓慢 (< 100MB 增长)
# - 无错误日志
```

---

## 故障排查

### ❓ 问题: 监控指标不更新

**原因可能**: 
- 监控进程未启动
- 指标收集失败
- 权限问题

**解决方案**:
```bash
# 检查监控进程
docker exec documentserver ps aux | grep enterprise-monitoring

# 查看监控日志
docker logs documentserver | grep -i monitoring

# 重启监控
docker exec documentserver /app/ds/enterprise-monitoring.sh start

# 检查指标文件
docker exec documentserver cat /var/lib/onlyoffice/monitoring/metrics.json
```

### ❓ 问题: Prometheus 无法连接到指标端点

**原因可能**:
- 应用服务未就绪
- 端口被占用
- 防火墙规则

**解决方案**:
```bash
# 检查应用是否运行
docker exec documentserver ps aux | grep node

# 检查端口是否开放
netstat -tuln | grep 9090

# 手动访问指标端点
curl -i http://localhost:9090/metrics

# 查看 Prometheus 日志
docker logs prometheus | tail -50
```

### ❓ 问题: Grafana 仪表板无数据

**原因可能**:
- 数据源未正确配置
- Prometheus 未收集到数据
- 仪表板查询错误

**解决方案**:
```bash
# 检查 Grafana 数据源
curl -s http://admin:admin123@localhost:3000/api/datasources | jq .

# 验证 Prometheus 数据源
curl -s http://admin:admin123@localhost:3000/api/datasources/1 | jq '.name'

# 测试数据源连接
curl -s http://admin:admin123@localhost:3000/api/datasources/1/health | jq .

# 查看仪表板定义
curl -s http://admin:admin123@localhost:3000/api/dashboards/db/onlyoffice | jq '.dashboard.panels[0]'
```

### ❓ 问题: 告警未触发

**原因可能**:
- 告警规则语法错误
- 条件未满足
- Alertmanager 未正确配置

**解决方案**:
```bash
# 验证告警规则语法
docker exec prometheus promtool check rules /etc/prometheus/alert_rules.yml

# 查看 Prometheus 告警规则
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups'

# 检查告警是否激活
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | {alertname, state, value}'

# 查看 Alertmanager 日志
docker logs alertmanager | tail -50

# 测试 Alertmanager 配置
docker exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
```

---

## 生产清单

- [ ] 所有服务已启动并验证
- [ ] 监控指标已正确收集
- [ ] 日志系统已初始化
- [ ] 告警规则已验证并激活
- [ ] Grafana 仪表板已配置
- [ ] 数据源连接正常
- [ ] 备份策略已制定
- [ ] 团队已培训
- [ ] 文档已准备
- [ ] 高可用性已配置 (可选)
- [ ] ELK Stack 已集成 (可选)
- [ ] 告警通知已配置 (邮件/Slack/钉钉)

---

## 下一步

1. **配置告警通知**
   - 编辑 `alertmanager.yml`
   - 配置邮件/Slack/钉钉通知

2. **创建自定义仪表板**
   - 在 Grafana 中创建新仪表板
   - 根据业务需求添加面板

3. **集成 ELK Stack**
   - 配置 Filebeat 收集应用日志
   - 在 Kibana 中创建日志分析仪表板

4. **性能调优**
   - 根据负载调整参数
   - 优化数据库查询
   - 增加缓存层

5. **高可用性部署**
   - 配置 Prometheus 联邦
   - 使用 Prometheus 高可用副本
   - 配置 Grafana 高可用

---

**验证完成！🎉** 系统已准备好用于生产环境。
