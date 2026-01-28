# ONLYOFFICE Document Server 并发性能快速参考卡

## 🎯 核心概念

### 并发上限公式
```
实际并发 = min(
    Nginx 连接 = Worker进程数 × 单Worker连接数,
    数据库连接 = max_connections - 系统预留,
    内存支持 = 可用内存 / 人均占用,
    FD 限制 = ulimit -n
)
```

### 性能指标目标
| 指标 | 目标值 | 说明 |
|------|--------|------|
| CPU 利用率 | 60-80% | 留出 20% 峰值余量 |
| 内存利用率 | 70-85% | 避免频繁交换 |
| 响应时间 P95 | <500ms | 用户体验阈值 |
| 吞吐量 | 100-500 RPS | 取决于操作复杂度 |
| 数据库连接 | <85% | 留出 15% 应急余量 |

---

## 🚀 快速诊断（3 步）

### 步骤 1：诊断系统瓶颈（5 分钟）
```bash
# 进入容器
docker exec -it <container_id> bash

# 运行诊断
./performance-diagnosis.sh

# 查看瓶颈所在（输出最后）
# → 理论并发上限：180
# → 主要瓶颈：数据库连接
```

### 步骤 2：规划容量（2 分钟）
```bash
# 根据硬件配置规划
./capacity-planning.sh 8 16

# 输出：
# → 理论并发上限：180 用户
# → Docker 启动命令
# → 数据库配置建议
```

### 步骤 3：性能测试（10 分钟）
```bash
# 执行压力测试
./performance-test.sh http://localhost 50 5000 30

# 查看结果：
# → 总请求数、成功率
# → 响应时间分布
# → 并发数递增曲线
```

---

## 📋 常见配置速查

### 配置 1：4 核 4GB（入门级）
```bash
# 启动命令
docker run -d \
  -e NGINX_WORKER_PROCESSES=4 \
  -e NGINX_WORKER_CONNECTIONS=8192 \
  onlyoffice/documentserver

# 预期能力
# → 并发用户：20-50
# → 吞吐量：100-250 RPS
# → 成本：¥1,200/年
```

### 配置 2：8 核 16GB（推荐生产）
```bash
# 启动命令
docker run -d \
  -e NGINX_WORKER_PROCESSES=8 \
  -e NGINX_WORKER_CONNECTIONS=32768 \
  -e DB_TYPE=postgres \
  -e DB_HOST=db-server \
  onlyoffice/documentserver

# 预期能力
# → 并发用户：50-150
# → 吞吐量：250-500 RPS
# → 成本：¥3,600/年
```

### 配置 3：16 核 32GB（高性能）
```bash
# 启动命令
docker run -d \
  -e NGINX_WORKER_PROCESSES=16 \
  -e NGINX_WORKER_CONNECTIONS=65536 \
  -e DB_TYPE=postgres \
  -e DB_HOST=db-server \
  onlyoffice/documentserver

# 预期能力
# → 并发用户：200-500
# → 吞吐量：500-1000 RPS
# → 成本：¥10,800/年
```

---

## 🔧 性能优化检查清单

- [ ] 文件描述符限制已调整（ulimit -n >= 65536）
- [ ] Nginx Worker 进程数 = CPU 核心数
- [ ] 数据库 max_connections >= 200（生产环境）
- [ ] PostgreSQL shared_buffers = 内存/4
- [ ] 使用外部 Redis 缓存
- [ ] 使用外部 PostgreSQL（不在容器内）
- [ ] 启用监控告警系统
- [ ] 配置日志轮转
- [ ] 定期备份数据库
- [ ] 进行压力测试验证

---

## 📊 性能基准数据

### 按硬件级别

| 硬件 | 并发用户 | RPS | 响应时间 | 推荐场景 |
|-----|--------|-----|--------|--------|
| 2C2G | 10-20 | 50-100 | 300-500ms | 测试 |
| 4C4G | 20-50 | 100-250 | 200-400ms | 小团队 |
| 8C16G | 50-150 | 250-500 | 150-300ms | 中企业 ⭐ |
| 16C32G | 200-500 | 500-1000 | 100-200ms | 大企业 |
| 32C64G | 800+ | 1000+ | <100ms | 超大型 |

### 性能测试数据模板
```
场景：50 并发用户，持续 30 秒
目标 URL：http://your-server/

预期结果：
✓ 成功率：99%+ 
✓ 平均响应时间：< 300ms
✓ P95 响应时间：< 500ms
✓ P99 响应时间：< 800ms
✓ 吞吐量：> 200 RPS
```

---

## 🐛 故障排查快速指南

### 问题：并发数上不去（<20）
```bash
# 1. 检查文件描述符
ulimit -n
# → 如果 < 65536，运行：
ulimit -n 131072

# 2. 检查数据库连接
docker exec postgresql psql -U onlyoffice \
  -c "SELECT count(*) FROM pg_stat_activity;"
# → 如果接近 max_connections，增加该值

# 3. 检查 Nginx 配置
grep worker_connections /etc/nginx/nginx.conf
# → 应该 >= 32768
```

### 问题：响应时间慢
```bash
# 1. 查看 CPU 使用率
docker stats documentserver

# 2. 查看内存使用
free -h

# 3. 查看数据库性能
docker exec postgresql psql -U onlyoffice -c \
  "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"

# 4. 查看磁盘 I/O
iostat -x 1
```

### 问题：高并发时崩溃
```bash
# 1. 查看日志
docker logs -f documentserver | tail -50

# 2. 检查是否 OOM（内存溢出）
docker inspect documentserver | grep -i oom

# 3. 查看系统日志
docker logs documentserver 2>&1 | grep -i "error\|exception"
```

---

## 💾 配置文件位置

| 配置项 | 位置 | 调整方法 |
|-------|------|--------|
| Nginx Workers | /etc/nginx/nginx.conf | 环境变量 NGINX_WORKER_PROCESSES |
| DB 连接 | PostgreSQL postgresql.conf | 直接编辑或数据库配置 |
| 文件描述符 | /etc/security/limits.conf | 系统级别修改 |
| TCP 参数 | /etc/sysctl.conf | sysctl 命令 |
| 应用配置 | /etc/onlyoffice/documentserver | JSON 配置文件 |

---

## 📈 扩容判断标准

**何时应该升级硬件**：
- CPU 利用率持续 > 85%
- 内存利用率持续 > 90%
- P95 响应时间 > 800ms
- 数据库连接接近上限（>85%）
- 磁盘 I/O 持续高于 70%

**何时应该水平扩展**：
- 单机已达到配置上限
- 需要冗余和高可用
- 地理分布式部署

---

## 🛠 实用命令速查

```bash
# 实时监控
watch -n 1 'docker stats documentserver'

# 查看并发连接数
netstat -an | grep ESTABLISHED | wc -l

# 查看进程占用资源
ps aux --sort=-%mem | head -10

# 测试服务响应
curl -v http://localhost/info/info.json

# 性能基准测试（需要 apache2-utils）
ab -n 1000 -c 50 http://localhost/

# 高性能测试（需要 wrk）
wrk -t4 -c100 -d30s http://localhost/
```

---

## 📚 深入学习资源

- **CONCURRENT_PERFORMANCE_ANALYSIS.md** - 详细理论分析
- **PERFORMANCE_TOOLS_README.md** - 工具使用完全指南
- **performance-diagnosis.sh** - 系统诊断脚本
- **performance-test.sh** - 压力测试脚本
- **capacity-planning.sh** - 容量规划计算器

---

## 💡 最重要的 5 个优化

1. **增加文件描述符** `ulimit -n 131072`
2. **设置 Worker 进程数** `NGINX_WORKER_PROCESSES=CPU核心数`
3. **使用外部数据库** 不要在容器内运行 PostgreSQL
4. **增加数据库连接** `max_connections >= 200`
5. **启用监控** 实时监控关键指标，及时发现问题

---

**快速决策表**：需要多大的服务器？

- 10-20 人协作 → **2C2G** ✓
- 20-50 人协作 → **4C4G** ✓ 推荐
- 50-150 人协作 → **8C16G** ✓ 推荐
- 150+ 人协作 → **16C32G+** ✓ 企业级

---

*最后更新：2026-01-28*  
*建议保存此页面作为快速参考*
