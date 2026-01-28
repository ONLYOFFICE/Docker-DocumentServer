# ONLYOFFICE Document Server 并发性能完整指南

这个文件夹包含了用于分析、测试和优化 ONLYOFFICE Document Server 并发性能的完整工具集。

## 📚 文档和工具清单

### 1. **CONCURRENT_PERFORMANCE_ANALYSIS.md** 📖
详细的理论分析文档，包括：
- 并发限制因素分解
- 不同硬件配置下的性能表现
- 各种场景的并发上限计算
- 优化指南和监控建议

**快速启用**：
```bash
cat CONCURRENT_PERFORMANCE_ANALYSIS.md
```

### 2. **performance-diagnosis.sh** 🔍
系统诊断工具，用于分析当前配置的瓶颈

**用法**：
```bash
# 在容器内执行
docker exec <container_id> bash performance-diagnosis.sh

# 或者直接运行
bash performance-diagnosis.sh
```

**输出内容**：
- 系统资源信息（CPU、内存、交换空间）
- 文件描述符限制
- Nginx 配置情况
- 数据库连接状态
- 当前网络连接数
- 瓶颈分析和优化建议

**示例输出**：
```
[1] 系统资源信息
CPU 核心数：8
总内存：16GB
可用内存：12GB

[2] 文件描述符限制
软限制：65536
硬限制：131072
✓ 文件描述符配置良好

[3] Nginx 配置
Worker 进程数：8
Worker 最大连接数：32768
Nginx 理论最大并发：262144

[7] 并发能力评估
理论并发上限（瓶颈）：180
```

### 3. **performance-test.sh** ⚡
性能压力测试工具，支持多种测试场景

**用法**：
```bash
# 基础压力测试（1000 个请求，并发 10）
bash performance-test.sh http://localhost 10 1000

# 高并发测试（30 秒，并发 100）
bash performance-test.sh http://localhost 100 0 30

# 完整示例
bash performance-test.sh http://your-server.com 50 5000 30
```

**参数说明**：
- 参数 1：目标 URL（默认：http://localhost）
- 参数 2：并发数（默认：10）
- 参数 3：请求总数（默认：1000）
- 参数 4：测试时长（秒，默认：30）

**测试包括**：
1. 预热测试（5 个请求）
2. 基础连接测试
3. 持续负载测试
4. 并发增长测试
5. 长连接测试
6. 数据库连接检查
7. 性能分析和建议

**示例输出**：
```
[3] 持续负载测试（30s）
测试结果：
  总请求数：1245
  平均响应时间：24ms
  最小响应时间：12ms
  最大响应时间：156ms
  吞吐量：41 req/s

[4] 并发数递增测试
并发数 | 成功率 | 平均响应时间 | 最大响应时间
--------|--------|-------------|----------
  1    | 100%   |      18ms   |      25ms
  5    |  100%  |      22ms   |      45ms
  10   |  100%  |      28ms   |      78ms
  20   |  99%   |      35ms   |      145ms
```

### 4. **capacity-planning.sh** 📊
容量规划计算器，基于硬件配置计算最优部署方案

**用法**：
```bash
# 查看帮助
bash capacity-planning.sh --help

# 4 核 4GB 内存的服务器
bash capacity-planning.sh 4 4

# 8 核 16GB 内存，预期 100 个并发用户
bash capacity-planning.sh 8 16 --concurrent-users 100

# 16 核 32GB 内存，峰值 3 倍流量
bash capacity-planning.sh 16 32 --peak-multiplier 3
```

**参数说明**：
- 参数 1：CPU 核心数（必需）
- 参数 2：内存大小（GB，必需）
- `--concurrent-users <number>`：预期并发用户数
- `--peak-multiplier <factor>`：峰值流量倍数（默认：2）

**输出内容**：
- 硬件配置分析
- 系统限制分析
- 并发能力计算
- 业务场景分析
- 推荐配置参数
- Docker 启动命令
- 数据库配置建议
- 监控指标
- 成本估算
- 升级建议

**示例输出**：
```
【系统限制分析】
• 文件描述符限制（调优后）
    推荐值：131072

• Nginx 配置
    Worker 进程数：8
    每个 Worker 最大连接：16384
    Nginx 最大并发连接：131072

• 数据库连接限制
    max_connections：200
    可用连接数：190

【并发能力计算】
理论并发上限：180 用户
主要瓶颈：数据库连接

【业务场景分析】
预期并发用户数：180
  • 正常工作时间并发：108 用户
  • 峰值时刻并发：216 用户
  • 日均请求数：约 17280 次
  • 峰值吞吐量：432 req/s
```

---

## 🚀 快速开始指南

### 第一步：诊断当前系统
```bash
# 在运行的容器内执行诊断
docker exec onlyoffice-documentserver bash /path/to/performance-diagnosis.sh
```

### 第二步：根据硬件规划容量
```bash
# 假设您有 8 核 16GB 的服务器
bash capacity-planning.sh 8 16
```

### 第三步：进行性能基准测试
```bash
# 执行性能测试
bash performance-test.sh http://localhost 50 5000 30
```

### 第四步：根据结果优化配置
根据诊断和测试结果，调整 Docker 运行参数和系统配置。

---

## 📈 典型并发能力参考表

| 硬件配置 | 理论并发 | 推荐用户数 | 适用场景 | 成本 |
|---------|--------|---------|--------|------|
| 2C2GB | 10-20 | 10-20 | 测试/演示 | ⭐ |
| 4C4GB | 30-50 | 20-50 | 小型团队 | ⭐⭐ |
| 8C16GB | 100-180 | 50-150 | 中型企业 | ⭐⭐⭐ |
| 16C32GB | 300-450 | 200-400 | 大型企业 | ⭐⭐⭐⭐ |
| 32C64GB | 800+ | 600+ | 企业级高可用 | ⭐⭐⭐⭐⭐ |

---

## 🔧 常用优化命令

### 1. 增加文件描述符限制
```bash
# 在宿主机上
echo "* soft nofile 131072" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 1048576" | sudo tee -a /etc/security/limits.conf
```

### 2. 优化 TCP 参数
```bash
sudo sysctl -w net.core.somaxconn=65535
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=65535
sudo sysctl -w net.ipv4.ip_local_port_range="1024 65535"
```

### 3. 启动时应用最优配置
```bash
docker run -d \
  -p 80:80 -p 443:443 \
  -e NGINX_WORKER_PROCESSES=8 \
  -e NGINX_WORKER_CONNECTIONS=32768 \
  -e DB_TYPE=postgres \
  -e DB_HOST=db-host \
  -e DB_PORT=5432 \
  -e DB_NAME=onlyoffice \
  -e DB_USER=onlyoffice \
  --restart always \
  --name documentserver \
  onlyoffice/documentserver
```

---

## 📊 性能监控命令

### 实时监控系统资源
```bash
# 容器内
docker stats documentserver

# 宿主机
watch -n 1 'docker stats documentserver'
```

### 监控网络连接
```bash
# 实时连接数
watch -n 1 'netstat -an | grep ESTABLISHED | wc -l'

# 连接分布
netstat -an | grep ESTABLISHED | awk '{print $6}' | sort | uniq -c | sort -rn
```

### 数据库连接监控
```bash
# 进入数据库容器
docker exec -it onlyoffice-postgresql psql -U onlyoffice

# 查询活跃连接
SELECT count(*) FROM pg_stat_activity;

# 查询每个数据库的连接数
SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;
```

---

## 🐛 常见问题诊断

### 问题 1：并发数只有 20 左右
**可能原因**：
- 数据库连接数不足
- 文件描述符限制过低
- Nginx Worker 进程数过少

**诊断命令**：
```bash
bash performance-diagnosis.sh
```

### 问题 2：响应时间很慢
**可能原因**：
- 磁盘 I/O 瓶颈
- 数据库查询性能问题
- 内存不足导致频繁交换

**诊断**：
```bash
# 查看磁盘 I/O
iostat -x 1

# 查看内存使用
free -h
docker stats documentserver
```

### 问题 3：高并发时服务崩溃
**可能原因**：
- 内存溢出
- 连接泄漏
- 资源限制触发

**诊断**：
```bash
# 检查系统日志
docker logs documentserver | tail -100

# 查看数据库日志
docker exec onlyoffice-postgresql tail -100 /var/log/postgresql/postgresql.log
```

---

## 📚 更多资源

- [ONLYOFFICE 官方文档](https://api.onlyoffice.com/)
- [Docker 官方文档](https://docs.docker.com/)
- [PostgreSQL 性能优化](https://www.postgresql.org/docs/current/performance.html)
- [Nginx 性能优化](http://nginx.org/en/docs/http/ngx_http_core_module.html)

---

## 💡 最佳实践建议

1. **测试优先**：在生产环境上线前，进行充分的性能测试
2. **监控完整**：建立实时监控系统，关注关键指标
3. **容量规划**：根据实际业务量提前规划硬件配置
4. **定期优化**：根据生产数据定期调整配置参数
5. **文档记录**：记录每次优化的效果，建立知识库

---

**最后更新**：2026-01-28  
**工具版本**：1.0  
**维护者**：ONLYOFFICE 社区
