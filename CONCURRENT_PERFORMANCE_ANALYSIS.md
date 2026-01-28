# ONLYOFFICE Document Server 并发性能分析

## 一、理论并发上限分析

### 1. 并发限制因素分解

ONLYOFFICE Document Server 的并发上限受多个因素影响，需要分层理解：

```
总体并发 = min(
    Nginx 并发连接数,
    数据库连接数,
    Node.js 进程处理能力,
    系统文件描述符限制,
    内存限制,
    消息队列处理能力
)
```

### 2. 各层级限制详解

#### **第一层：系统文件描述符限制（FD Limit）**
- **默认配置**：`ulimit -n` 返回系统允许的最大文件描述符数
- **代码实现**：
  ```bash
  LIMIT=$(ulimit -n)
  [ $LIMIT -gt 1048576 ] && LIMIT=1048576  # 最大上限 1048576
  NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-$LIMIT}
  ```
- **典型值**：
  - 系统默认：1024 - 4096
  - 调优后：65536 - 131072
  - 理论最大：1048576（约 100 万）

#### **第二层：Nginx Worker 配置**
- **Worker 进程数**：
  ```bash
  NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-1}
  ```
  - 默认值：1（未配置时）
  - 推荐值：CPU 核心数（可通过环境变量调整）

- **每个 Worker 的最大连接数**：
  ```bash
  NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-$LIMIT}
  ```
  - 受文件描述符限制
  - 默认等于系统 FD 限制

- **Nginx 总并发计算**：
  ```
  Nginx 最大并发 = NGINX_WORKER_PROCESSES × NGINX_WORKER_CONNECTIONS
  ```

#### **第三层：数据库连接限制**
PostgreSQL 默认配置：
- **max_connections**：100（Docker 中通常为默认值）
- **实际可用连接**：max_connections - 超级用户预留连接

RabbitMQ 连接数：
```bash
RABBIT_CONNECTIONS=${RABBIT_CONNECTIONS:-$LIMIT}
```

#### **第四层：Node.js 进程限制**
- **Supervisor 管理的进程**：
  - `docservice`：文档处理主服务
  - `converter`：文件格式转换
  - `metrics`：性能指标收集
  - `adminpanel`：管理面板
- 每个进程的内存占用：~50-100MB

#### **第五层：内存约束**
- **推荐最小内存**：4GB
- **实际需求**：
  - Nginx：~50MB
  - PostgreSQL：~200-500MB（取决于缓冲区大小）
  - RabbitMQ：~100-200MB
  - Node.js 进程（4 个）：~200-400MB
  - 系统预留：~500MB

---

## 二、并发上限计算

### 场景 1：最小配置（4核 CPU，4GB 内存）
```
假设：
- ulimit -n = 65536（调优后）
- CPU 核心数 = 4
- 数据库最大连接 = 100

Nginx 并发 = 4 × 65536 = 262,144

受限于：
- 数据库连接：~80-100（留余量）
- 内存：约 500 并发用户（每个用户占用 ~8MB）

实际理论上限 ≈ 100 并发用户（受数据库连接限制）
```

### 场景 2：中等配置（8核 CPU，16GB 内存）
```
假设：
- ulimit -n = 131072（调优后）
- CPU 核心数 = 8  
- 数据库最大连接 = 200

Nginx 并发 = 8 × 131072 = 1,048,576

受限于：
- 数据库连接：~180（留余量）
- 内存：约 2000 并发用户

实际理论上限 ≈ 180 并发用户（受数据库连接限制）
```

### 场景 3：高性能配置（16核 CPU，32GB 内存）
```
假设：
- ulimit -n = 1048576（最大限制）
- CPU 核心数 = 16
- 数据库最大连接 = 500

Nginx 并发 = 16 × 1048576 = 16,777,216（理论）

受限于：
- 数据库连接：~450（留余量）
- 内存：约 4000 并发用户

实际理论上限 ≈ 450 并发用户（受数据库连接限制）
```

---

## 三、不同硬件配置下的性能表现

### 性能对标指标
| 指标 | 含义 | 参考值 |
|------|------|--------|
| **吞吐量 (RPS)** | 每秒请求数 | 100-500 RPS |
| **响应时间 (P95)** | 95% 请求响应时间 | <500ms |
| **内存占用** | 单个并发用户占用内存 | ~5-10MB |
| **CPU 利用率** | 理想目标 | 60-80% |

### 配置方案对比

#### **方案 A：入门级（2核 2GB）**
```
主要用途：开发、测试、文档演示
硬件配置：
- CPU：2 核
- 内存：2GB
- 存储：20GB

性能表现：
- 并发用户数：10-20
- 吞吐量：50-100 RPS
- 响应时间 P95：300-500ms
- CPU 利用率：40-60%
- 内存利用率：60-80%

限制瓶颈：
- 内存（最大）
- 数据库连接（受限）
- CPU 处理能力

适配场景：
✓ 小型团队（<20人）
✓ 功能测试
✗ 生产环境
```

#### **方案 B：小型团队（4核 4GB）** ⭐ 推荐
```
主要用途：小型生产环境
硬件配置：
- CPU：4 核
- 内存：4GB
- 存储：40GB

性能表现：
- 并发用户数：20-50
- 吞吐量：100-250 RPS
- 响应时间 P95：200-400ms
- CPU 利用率：50-75%
- 内存利用率：70-85%

推荐优化：
- ulimit -n 调整为 65536
- nginx worker_processes = 4
- PostgreSQL max_connections = 100

适配场景：
✓ 小型团队（20-50人）
✓ 日常协作编辑
✓ 基础生产环境
```

#### **方案 C：中型企业（8核 16GB）** ⭐ 推荐
```
主要用途：生产环境
硬件配置：
- CPU：8 核
- 内存：16GB
- 存储：100GB

性能表现：
- 并发用户数：50-150
- 吞吐量：250-500 RPS
- 响应时间 P95：150-300ms
- CPU 利用率：60-80%
- 内存利用率：70-85%

推荐优化：
- ulimit -n 调整为 131072
- nginx worker_processes = 8
- PostgreSQL max_connections = 200
- 使用外部 Redis 缓存

适配场景：
✓ 中型团队（50-200人）
✓ 高并发编辑场景
✓ 稳定生产环境
```

#### **方案 D：大型企业（16核+ 32GB+）**
```
主要用途：高可用生产环境
硬件配置：
- CPU：16+ 核
- 内存：32GB+
- 存储：200GB+

性能表现：
- 并发用户数：200-500+
- 吞吐量：500-1000+ RPS
- 响应时间 P95：100-200ms
- CPU 利用率：70-85%
- 内存利用率：75-90%

推荐优化：
- ulimit -n 调整为 1048576
- nginx worker_processes = CPU 核心数
- PostgreSQL max_connections = 500+
- 使用外部 Redis 集群
- 使用 HAProxy 做负载均衡
- 数据库读写分离

适配场景：
✓ 大型企业（200+人）
✓ 24/7 高可用需求
✓ 多部门协作
✓ 分布式部署
```

---

## 四、并发优化指南

### 系统层面优化

#### 1. 提高文件描述符限制
```bash
# 临时设置（容器内）
ulimit -n 131072

# 永久设置（宿主机）
# 编辑 /etc/security/limits.conf
* soft nofile 131072
* hard nofile 1048576

# 编辑 /etc/security/limits.d/90-nproc.conf
* soft nofile 131072
* hard nofile 1048576
```

#### 2. 调整 Nginx 配置
```bash
# 通过环境变量设置
docker run -e NGINX_WORKER_PROCESSES=8 \
           -e NGINX_WORKER_CONNECTIONS=32768 \
           onlyoffice/documentserver
```

#### 3. 优化 TCP 参数
```bash
# 增加 TCP 连接队列
sysctl -w net.core.somaxconn=65535
sysctl -w net.ipv4.tcp_max_syn_backlog=65535

# 增加可用端口范围
sysctl -w net.ipv4.ip_local_port_range="1024 65535"

# 启用 TCP 快速回收
sysctl -w net.ipv4.tcp_tw_recycle=1
sysctl -w net.ipv4.tcp_tw_reuse=1
```

### 应用层面优化

#### 1. 数据库连接池优化
```bash
# 增加 PostgreSQL max_connections
docker run -e DB_TYPE=postgres \
           -e DB_HOST=your-db \
           onlyoffice/documentserver

# PostgreSQL 配置
# 编辑 postgresql.conf
max_connections = 200          # 根据硬件调整
shared_buffers = 512MB         # 16GB 内存推荐 4GB
effective_cache_size = 8GB     # 内存的 1/2 到 3/4
```

#### 2. RabbitMQ 性能调优
```bash
# 通过环境变量设置连接限制
docker run -e RABBIT_CONNECTIONS=32768 \
           onlyoffice/documentserver
```

#### 3. Redis 缓存优化
```bash
# 启用 Redis 缓存
docker run -e REDIS_SERVER_HOST=redis-host \
           -e REDIS_SERVER_PORT=6379 \
           onlyoffice/documentserver
```

### 监控和调试

#### 1. 实时监控并发数
```bash
# 查看 Nginx 连接数
netstat -an | grep ESTABLISHED | wc -l

# 查看数据库连接
docker exec <db_container> psql -U onlyoffice -c \
  "SELECT count(*) FROM pg_stat_activity;"

# 监控内存使用
docker stats <container_name>
```

#### 2. 性能测试
```bash
# 使用 Apache Bench 进行压力测试
ab -n 10000 -c 100 http://localhost/health

# 使用 wrk 进行更复杂的性能测试
wrk -t4 -c100 -d30s http://localhost/
```

---

## 五、容量规划建议

### 根据用户数选择配置

| 并发用户数 | 推荐配置 | 成本等级 | 备注 |
|-----------|---------|--------|------|
| 1-20 | 2C2G | ⭐ | 测试/演示 |
| 20-50 | 4C4G | ⭐⭐ | **最佳性价比** |
| 50-150 | 8C16G | ⭐⭐⭐ | **推荐** |
| 150-300 | 12C24G | ⭐⭐⭐⭐ | 高性能 |
| 300+ | 16C32G+ | ⭐⭐⭐⭐⭐ | 企业级 |

### 预算规划（云服务器 1 年成本估算）
```
方案 A（2C2G）：~¥600/年
方案 B（4C4G）：~¥1,200/年（推荐）
方案 C（8C16G）：~¥3,600/年
方案 D（16C32G）：~¥10,800/年
```

---

## 六、常见问题解答

### Q1：为什么我的服务并发数只有 20 左右？
**A**：可能原因：
- 数据库连接数不足（PostgreSQL max_connections 默认 100）
- 文件描述符限制未调整（系统默认 1024）
- Nginx worker 进程数配置不当（默认 1）

**解决方案**：
```bash
# 检查当前设置
ulimit -n                          # 查看 FD 限制
docker exec <ds_container> \
  ps aux | grep -i docservice     # 查看进程数
```

### Q2：如何从 20 并发扩展到 100 并发？
**A**：需要同时调整多个参数：
1. 增加 CPU 核心（4→8）
2. 增加内存（4GB→16GB）
3. 调整 ulimit -n（1024→65536）
4. 增加 NGINX_WORKER_PROCESSES（1→8）
5. 增加数据库连接（100→200）

### Q3：内存不足时如何处理？
**A**：
- 启用外部 Redis 缓存减少内存占用
- 优化 PostgreSQL buffer_pool 大小
- 使用容器内存限制和 swap

### Q4：如何监控是否达到并发上限？
**A**：
- 查看 `ESTABLISHED` 连接数
- 监控 PostgreSQL 活跃连接
- 查看应用日志中的连接池警告
- 使用 `top` 监控 CPU 和内存利用率

---

## 七、部署建议总结

### ✅ DO（应该做）
1. 根据用户数提前规划硬件配置
2. 定期监控系统资源使用情况
3. 使用外部数据库和 Redis（生产环境）
4. 配置 HAProxy 做负载均衡（>100 并发）
5. 建立监控告警机制

### ❌ DON'T（不应该做）
1. 在 2C2G 上部署生产环境
2. 忽视文件描述符限制
3. 单点部署企业关键应用
4. 不做性能测试直接上线
5. 长期运行不优化性能参数

---

## 八、参考资源

- [ONLYOFFICE 官方文档](https://api.onlyoffice.com/)
- [Nginx 性能优化](http://nginx.org/en/docs/)
- [PostgreSQL 容量规划](https://www.postgresql.org/docs/)
- [Docker 资源限制](https://docs.docker.com/config/containers/resource_constraints/)
