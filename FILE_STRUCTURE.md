# 📚 项目结构导航

> **ONLYOFFICE Document Server 企业级解决方案** - 完整项目结构指南

## 🎯 项目总览

```
Docker-DocumentServer/
│
├── 📊 monitoring/                      ← 监控和日志系统
│   ├── scripts/                        # 监控脚本
│   │   ├── enterprise-monitoring.sh   # 系统监控守护进程
│   │   └── enterprise-logging.sh      # 企业级日志框架
│   ├── config/                         # Prometheus/Grafana/ELK 配置
│   │   ├── prometheus.yml
│   │   ├── alert_rules.yml
│   │   ├── alertmanager.yml
│   │   ├── grafana-dashboard.json
│   │   ├── grafana-datasources.yml
│   │   └── logstash.conf
│   ├── docs/                           # 监控系统文档
│   │   ├── README_MONITORING.md
│   │   ├── ENTERPRISE_MONITORING_GUIDE.md
│   │   ├── MONITORING_VERIFICATION.md
│   │   └── INTEGRATION_CHECKLIST.md
│   └── README.md                       # 监控系统快速指南
│
├── 🏃 performance-testing/             ← 性能测试工具集
│   ├── scripts/                        # 测试脚本
│   │   ├── performance-test.sh        # 性能测试
│   │   ├── concurrency-test.sh        # 并发测试
│   │   ├── performance-diagnosis.sh   # 诊断工具
│   │   └── capacity-planning.sh       # 容量规划
│   ├── docs/                           # 测试文档
│   │   ├── README_PERFORMANCE.md
│   │   ├── PERFORMANCE_TOOLS_README.md
│   │   └── CONCURRENT_PERFORMANCE_SUMMARY.md
│   ├── results/                        # 测试结果 (自动生成)
│   └── README.md                       # 测试工具快速指南
│
├── 🐳 deployment/                      ← 部署和编排
│   ├── docker-compose-monitoring.yml   # 完整的 11 个服务堆栈
│   ├── docker-compose.yml              # 基础应用堆栈
│   ├── deploy-monitoring.sh            # 一键部署脚本
│   ├── run-document-server.sh          # 应用启动脚本
│   └── README.md                       # 部署指南
│
├── 🔐 security/                        ← 安全审计
│   ├── scripts/                        # 安全脚本
│   │   └── SECURITY_AUDIT.sh          # 完整的安全审计工具
│   ├── docs/                           # 安全文档
│   │   └── (安全报告)
│   └── README.md                       # 安全指南
│
├── 📖 总体文档
│   ├── PROJECT_SUMMARY.md              # 项目完整总结
│   ├── README.md                       # 主 README
│   ├── DEPLOYMENT_STATUS.txt           # 部署状态报告
│   └── FILE_STRUCTURE.md               # 本文件
│
├── 🐳 Docker 配置 (核心文件)
│   ├── docker-bake.hcl                 # Docker Bake 配置
│   ├── Dockerfile                      # Docker 镜像定义
│   └── production.dockerfile           # 生产镜像定义
│
└── 🔧 其他
    ├── Makefile                        # 构建脚本
    ├── LICENSE.txt
    └── tests/                          # 测试配置
```

## 🗂️ 文件夹详细说明

### 1️⃣ monitoring/ - 监控和日志系统

**用途**: 企业级实时监控和日志收集

**何时使用**:
- ✅ 需要实时监控系统性能
- ✅ 需要追踪用户操作审计
- ✅ 需要调试错误和性能问题
- ✅ 需要生成可视化仪表板
- ✅ 需要设置告警和通知

**快速开始**:
```bash
cd monitoring
cat README.md              # 查看使用指南
./scripts/enterprise-monitoring.sh collect  # 收集指标
```

**包含内容**:
- 23+ 监控指标
- 6 种日志类型
- 15+ 告警规则
- 10 个 Grafana 仪表板面板

---

### 2️⃣ performance-testing/ - 性能测试

**用途**: 性能评估和容量规划

**何时使用**:
- ✅ 需要评估系统性能
- ✅ 需要找到性能瓶颈
- ✅ 需要进行压力测试
- ✅ 需要规划扩容方案
- ✅ 需要验证优化效果

**快速开始**:
```bash
cd performance-testing
cat README.md                        # 查看使用指南
./scripts/performance-test.sh        # 运行性能测试
./scripts/concurrency-test.sh        # 并发测试
```

**包含工具**:
- 性能测试工具
- 并发压力测试
- 性能诊断工具
- 容量规划工具

---

### 3️⃣ deployment/ - 部署和编排

**用途**: Docker 容器编排和应用部署

**何时使用**:
- ✅ 首次部署应用
- ✅ 部署完整的监控堆栈
- ✅ 更新配置或升级版本
- ✅ 管理多个服务

**快速开始**:
```bash
cd deployment
cat README.md                    # 查看部署指南
./deploy-monitoring.sh           # 一键部署
```

**包含内容**:
- Docker Compose 配置
- 11 个服务的完整堆栈
- 一键部署脚本
- 应用启动脚本

---

### 4️⃣ security/ - 安全审计

**用途**: 安全漏洞检测和审计

**何时使用**:
- ✅ 部署前的安全检查
- ✅ 定期的安全审计 (月度)
- ✅ 发现和修复安全问题
- ✅ 合规性检查

**快速开始**:
```bash
cd security
cat README.md                   # 查看安全指南
./scripts/SECURITY_AUDIT.sh     # 运行安全审计
```

**包含内容**:
- 代码安全扫描
- 依赖漏洞检查
- 配置安全审计
- 运行时安全检查

---

## 🎯 按场景选择工作路径

### 场景 1: 我要快速启动监控系统

```
1. cd deployment
2. ./deploy-monitoring.sh
3. 访问 http://localhost:3000
4. 查看 monitoring/README.md 了解如何使用
```

**用时**: 5 分钟

---

### 场景 2: 我要进行性能测试

```
1. 确保应用已启动 (docker ps)
2. cd performance-testing
3. ./scripts/performance-test.sh --concurrency 100
4. 查看输出结果
5. 查看 docs/ 中的详细文档
```

**用时**: 10-30 分钟

---

### 场景 3: 我要进行安全审计

```
1. cd security
2. ./scripts/SECURITY_AUDIT.sh
3. 查看审计结果
4. 根据 README.md 修复发现的问题
```

**用时**: 15 分钟

---

### 场景 4: 我要自定义告警规则

```
1. cd monitoring/config
2. 编辑 alert_rules.yml
3. 验证语法: promtool check rules alert_rules.yml
4. 重启 Prometheus: docker-compose restart prometheus
```

**用时**: 10 分钟

---

### 场景 5: 我要查找性能瓶颈

```
1. cd performance-testing
2. ./scripts/performance-diagnosis.sh --report
3. 查看报告中的建议
4. 根据建议优化系统
```

**用时**: 20-30 分钟

---

## 📚 文档导航地图

### 我想了解整个项目

```
1. 阅读 PROJECT_SUMMARY.md (5分钟总览)
2. 阅读 README.md (详细介绍)
3. 查看各文件夹的 README.md (深入了解)
```

### 我想快速启动

```
1. 查看 deployment/README.md (部署指南)
2. 运行 deploy-monitoring.sh
3. 查看 monitoring/README.md (使用指南)
```

### 我想深入学习

```
1. monitoring/docs/README_MONITORING.md
2. monitoring/docs/ENTERPRISE_MONITORING_GUIDE.md
3. monitoring/docs/MONITORING_VERIFICATION.md
4. performance-testing/docs/*
5. security/README.md
```

### 我需要故障排查

```
1. monitoring/docs/MONITORING_VERIFICATION.md
2. deployment/README.md 中的常见问题
3. Docker 日志: docker logs <容器>
4. 应用日志: /var/log/onlyoffice/
```

---

## 🚀 推荐的学习路径

### 第 1 天: 基础部署

- ✅ 阅读 PROJECT_SUMMARY.md
- ✅ 运行 deployment/deploy-monitoring.sh
- ✅ 访问 Grafana 仪表板
- ✅ 阅读 monitoring/README.md

### 第 2 天: 性能测试

- ✅ 阅读 performance-testing/README.md
- ✅ 运行基本性能测试
- ✅ 分析测试结果
- ✅ 进行并发测试

### 第 3 天: 安全审计

- ✅ 运行安全审计
- ✅ 修复发现的问题
- ✅ 阅读 security/README.md
- ✅ 配置安全最佳实践

### 第 4-5 天: 深入配置

- ✅ 自定义告警规则
- ✅ 创建自定义仪表板
- ✅ 配置告警通知
- ✅ 设置 ELK 日志分析

---

## 📊 文件统计

| 类型 | 数量 | 说明 |
|------|------|------|
| Shell 脚本 | 9 | 监控、测试、部署、审计 |
| YAML 配置 | 5 | Prometheus、Grafana、Alertmanager |
| JSON 配置 | 1 | Grafana 仪表板 |
| 文档 | 15+ | Markdown 文档 |
| Docker 配置 | 3 | docker-compose 和 Dockerfile |

**总计**: 30+ 个文件

---

## 🔄 工作流程

```
┌─────────────────────────────────────────────────────────┐
│                    部署应用                              │
│              deployment/deploy-monitoring.sh             │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
   📊 实时监控               🏃 性能测试
   monitoring/              performance-testing/
   
   ├─ 仪表板               ├─ 基准测试
   ├─ 告警                 ├─ 并发测试
   ├─ 日志                 ├─ 诊断
   └─ 指标                 └─ 容量规划
        │                         │
        └────────────┬────────────┘
                     │
                     ▼
            🔍 识别改进机会
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
    📈 优化应用              🔐 安全审计
                             security/
                             
                             ├─ 代码扫描
                             ├─ 依赖检查
                             ├─ 配置审计
                             └─ 运行时检查
                             
                     │
                     ▼
            ✅ 生产部署
```

---

## 🛠️ 常用命令快速参考

### 监控相关

```bash
cd monitoring
./scripts/enterprise-monitoring.sh collect    # 收集指标
./scripts/enterprise-logging.sh query audit   # 查询审计日志
```

### 性能测试

```bash
cd performance-testing
./scripts/performance-test.sh                 # 性能测试
./scripts/concurrency-test.sh                 # 并发测试
```

### 部署相关

```bash
cd deployment
./deploy-monitoring.sh                        # 一键部署
docker-compose -f docker-compose-monitoring.yml ps  # 查看状态
```

### 安全审计

```bash
cd security
./scripts/SECURITY_AUDIT.sh                   # 运行审计
```

---

## 📞 如何获取帮助

### 我需要快速答案

1. 查看相应文件夹的 README.md
2. 搜索关键词
3. 查看文档中的常见问题

### 我需要详细指导

1. 查看相应的 docs/ 文件夹
2. 按照步骤进行
3. 查看示例代码

### 我遇到了问题

1. 查看故障排查部分
2. 查看日志文件
3. 运行诊断工具
4. 查看错误信息

---

## 🎓 学习资源

### 内部资源

- PROJECT_SUMMARY.md - 完整项目说明
- 各文件夹的 README.md - 具体使用指南
- docs/ 文件夹 - 详细技术文档

### 外部资源

- Prometheus 文档: https://prometheus.io/docs/
- Grafana 文档: https://grafana.com/docs/
- Docker 文档: https://docs.docker.com/
- ELK Stack 文档: https://www.elastic.co/guide/

---

## ✅ 生产检查清单

在将系统投入生产前：

- [ ] 完成部署
- [ ] 验证所有 11 个服务正常运行
- [ ] 运行性能测试验证容量
- [ ] 运行安全审计
- [ ] 配置告警通知
- [ ] 进行备份测试
- [ ] 文档团队培训
- [ ] 建立应急响应计划

---

**版本**: 1.0 Production Ready  
**最后更新**: 2026-01-28  
**支持**: ONLYOFFICE 社区

---

现在您应该能够：
- ✅ 快速找到需要的文件和工具
- ✅ 理解每个文件夹的用途
- ✅ 按照推荐路径学习系统
- ✅ 独立完成部署、测试和维护工作

祝您使用愉快! 🚀
