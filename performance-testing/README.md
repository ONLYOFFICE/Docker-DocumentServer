# 🏃 性能测试工具集

本文件夹包含为 ONLYOFFICE Document Server 设计的完整性能测试和并发测试工具。

## 📁 文件夹结构

```
performance-testing/
├── scripts/          # 性能测试脚本
├── docs/             # 测试文档和报告
└── results/          # 测试结果存储 (自动生成)
```

## 📂 各文件夹说明

### scripts/ (测试脚本)

| 脚本 | 功能 | 输出 |
|------|------|------|
| `performance-test.sh` | 完整的性能测试工具 | 响应时间、吞吐量、成功率统计 |
| `concurrency-test.sh` | 并发连接测试 | 并发用户数与系统性能关系 |
| `performance-diagnosis.sh` | 性能诊断工具 | 瓶颈分析、资源使用诊断 |
| `capacity-planning.sh` | 容量规划工具 | 最大容量估算、扩容建议 |

### docs/ (文档)

| 文档 | 长度 | 内容 |
|------|------|------|
| `README_PERFORMANCE.md` | 9.5 KB | 性能工具使用指南 |
| `PERFORMANCE_TOOLS_README.md` | 8 KB | 工具详细说明 |
| `CONCURRENT_PERFORMANCE_SUMMARY.md` | 10 KB | 并发测试总结报告 |

## 🎯 测试场景

### 场景 1: 正常负载测试

```bash
./scripts/performance-test.sh --mode normal --duration 300 --concurrency 100
```

**预期结果**:
- 吞吐量: 80+ req/s
- 响应时间: 200-300ms
- 成功率: >99%
- CPU: <70%
- 内存: <75%

### 场景 2: 峰值负载测试

```bash
./scripts/performance-test.sh --mode peak --duration 120 --concurrency 200
```

**预期结果**:
- 吞吐量: 100-120 req/s
- 响应时间: 400-500ms
- 成功率: >95%
- CPU: <90%
- 内存: <85%

### 场景 3: 并发连接测试

```bash
./scripts/concurrency-test.sh --max-users 1000 --ramp-up 60
```

**预期结果**:
- 最大并发用户: 200+
- 连接保持率: >98%
- 内存泄漏: 无

### 场景 4: 持久连接测试

```bash
./scripts/performance-test.sh --mode sustained --duration 1800 --concurrency 100
```

**预期结果**:
- 30 分钟无崩溃
- 内存增长: <100MB
- 错误率: <1%

## 🔍 快速开始

### 步骤 1: 查看可用脚本

```bash
ls -la scripts/
```

### 步骤 2: 运行简单测试

```bash
# 最简单的用法 (使用默认参数)
./scripts/performance-test.sh

# 查看帮助
./scripts/performance-test.sh --help
```

### 步骤 3: 分析结果

```bash
# 查看测试输出
cat results/performance_test_*.log

# 获取诊断信息
./scripts/performance-diagnosis.sh
```

## 📊 测试指标

本工具集收集以下指标：

### 性能指标
- 平均响应时间
- P50 响应时间
- P95 响应时间
- P99 响应时间
- 最小/最大响应时间

### 吞吐量指标
- 请求/秒 (req/s)
- 字节/秒 (bytes/s)
- 成功请求数
- 失败请求数
- 成功率

### 资源指标
- CPU 使用率
- 内存使用率
- 磁盘 I/O
- 网络带宽
- 开放文件数

### 并发指标
- 活跃连接数
- 平均连接时间
- 连接建立速率
- 连接断开速率
- 连接超时数

## 🚀 常用命令

### 基础性能测试

```bash
# 100 个并发用户, 5 分钟
./scripts/performance-test.sh \
  --concurrency 100 \
  --duration 300 \
  --mode normal

# 200 个并发用户, 2 分钟 (峰值)
./scripts/performance-test.sh \
  --concurrency 200 \
  --duration 120 \
  --mode peak
```

### 并发连接测试

```bash
# 测试最多能承受多少并发用户
./scripts/concurrency-test.sh \
  --max-users 1000 \
  --ramp-up 60

# 逐步增加并发, 找到性能拐点
./scripts/concurrency-test.sh \
  --step 50 \
  --max-users 500
```

### 性能诊断

```bash
# 进行全面诊断
./scripts/performance-diagnosis.sh

# 生成诊断报告
./scripts/performance-diagnosis.sh --report

# 分析特定时间范围
./scripts/performance-diagnosis.sh --since "2026-01-28 10:00" --until "2026-01-28 11:00"
```

### 容量规划

```bash
# 基于历史数据进行容量规划
./scripts/capacity-planning.sh

# 获取扩容建议
./scripts/capacity-planning.sh --growth-rate 0.2 --months 12
```

## 📈 测试报告

### 自动生成的报告

```
results/
├── performance_test_2026-01-28_10-30-45.log
├── concurrency_test_2026-01-28_10-35-20.log
├── diagnosis_report_2026-01-28_11-00-00.txt
└── capacity_plan_2026-01-28_11-30-00.txt
```

### 报告内容

**性能测试报告**:
- 测试场景配置
- 响应时间分布
- 吞吐量统计
- 错误统计
- 资源使用情况

**并发测试报告**:
- 并发用户数范围
- 每个并发级别的性能
- 性能拐点分析
- 推荐最大并发

**诊断报告**:
- 性能瓶颈识别
- 资源使用分析
- 错误原因分析
- 优化建议

**容量规划报告**:
- 当前容量评估
- 增长趋势预测
- 扩容时间建议
- 扩容方案

## 🔬 深入分析

### 分析响应时间

```bash
# 查看响应时间分布
grep "Response Time" results/*.log | sort -t: -k2 -n

# 找出最慢的请求
grep "ERROR\|TIMEOUT" results/*.log | head -20
```

### 分析并发性能

```bash
# 查看不同并发下的吞吐量
grep "Throughput" results/concurrency_test_*.log

# 找出性能拐点
awk '/Throughput|Concurrency/' results/concurrency_test_*.log | sort -k2 -n
```

### 分析资源使用

```bash
# 查看 CPU 使用趋势
grep "CPU Usage" results/*.log

# 查看内存增长
grep "Memory" results/*.log | sort -t: -k2 -n
```

## 💡 最佳实践

### 测试前准备

```bash
# 1. 清理旧的测试结果
rm -rf results/*

# 2. 重启应用确保干净状态
docker restart documentserver

# 3. 等待应用稳定
sleep 30

# 4. 验证应用健康
curl -i http://localhost/healthcheck
```

### 测试执行

```bash
# 1. 运行基准测试
./scripts/performance-test.sh --mode normal

# 2. 分析结果
./scripts/performance-diagnosis.sh --report

# 3. 如果需要, 进行并发测试
./scripts/concurrency-test.sh --max-users 500

# 4. 容量规划
./scripts/capacity-planning.sh
```

### 结果分析

```bash
# 1. 对比历次测试结果
diff results/performance_test_old.log results/performance_test_new.log

# 2. 查看趋势
tail -50 results/*.log | sort

# 3. 生成总结报告
cat results/capacity_plan_*.txt
```

## 📊 性能基准参考

根据之前的测试：

| 负载 | 并发 | 吞吐量 | 响应时间 | 成功率 | CPU | 内存 |
|------|------|--------|---------|--------|-----|------|
| 低 | 50 | 40/s | 150ms | 100% | 30% | 50% |
| 正常 | 100 | 80/s | 226ms | 100% | 70% | 75% |
| 高 | 200 | 120/s | 450ms | 98% | 90% | 85% |
| 峰值 | 500 | 80/s | 1000ms | 90% | 95% | 95% |
| 极限 | 1000 | 60/s | 1500ms | 80% | 99% | 99% |

## 🆘 常见问题

### Q: 测试结果与预期不符

**A**: 检查以下几点：
1. 应用是否正常运行: `curl http://localhost/healthcheck`
2. 数据库是否可用: `docker exec onlyoffice-postgresql psql -U onlyoffice -c "SELECT 1"`
3. 是否有其他负载: `docker stats`
4. 查看应用日志: `docker logs documentserver | tail -50`

### Q: 如何对比不同版本的性能

**A**: 
1. 运行测试并保存结果: `./scripts/performance-test.sh > results/version1.log`
2. 升级/修改代码
3. 再次运行: `./scripts/performance-test.sh > results/version2.log`
4. 对比: `diff results/version1.log results/version2.log`

### Q: 如何找到性能瓶颈

**A**: 使用诊断工具：
```bash
./scripts/performance-diagnosis.sh --report
```

查看关键指标：
- CPU 使用率 >90%? → CPU 瓶颈
- 内存使用率 >90%? → 内存瓶颈
- 错误率 >1%? → 连接或超时瓶颈
- 响应时间 >2s? → 数据库或网络瓶颈

## 📖 文档导航

| 文档 | 用途 |
|------|------|
| `docs/README_PERFORMANCE.md` | 性能工具基础用法 |
| `docs/PERFORMANCE_TOOLS_README.md` | 工具详细参数说明 |
| `docs/CONCURRENT_PERFORMANCE_SUMMARY.md` | 并发测试结果总结 |

## 🎯 典型工作流

```
1. 部署应用
   ↓
2. 运行基准测试 (performance-test.sh --mode normal)
   ↓
3. 找到性能拐点 (concurrency-test.sh)
   ↓
4. 进行诊断 (performance-diagnosis.sh --report)
   ↓
5. 识别瓶颈
   ↓
6. 优化应用
   ↓
7. 重复测试对比
   ↓
8. 生成容量规划 (capacity-planning.sh)
   ↓
9. 根据规划扩容
```

---

**版本**: 1.0  
**最后更新**: 2026-01-28  
**支持**: ONLYOFFICE 社区
