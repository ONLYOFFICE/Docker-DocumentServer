# 🔐 安全审计

本文件夹包含 ONLYOFFICE Document Server 的安全审计工具和文档。

## 📁 文件夹结构

```
security/
├── scripts/         # 安全审计脚本
└── docs/            # 安全报告和指南
```

## 📂 文件说明

### scripts/ (安全脚本)

| 脚本 | 功能 | 输出 |
|------|------|------|
| `SECURITY_AUDIT.sh` | 完整的安全审计工具 | 597 行详细审计报告 |

## 🔒 安全审计工具

### SECURITY_AUDIT.sh

**全面的安全审计框架**

审计内容包括：

#### 1. 代码安全扫描
- ✓ 后门检测
- ✓ 恶意代码扫描
- ✓ SQL 注入风险
- ✓ 命令注入风险
- ✓ 路径遍历风险
- ✓ XSS 风险检测

#### 2. 依赖安全检查
- ✓ 已知漏洞扫描
- ✓ 过时依赖检测
- ✓ 许可证合规性

#### 3. 配置安全
- ✓ 默认凭证检查
- ✓ 弱密码检测
- ✓ 不安全的配置
- ✓ SSL/TLS 配置

#### 4. 运行时安全
- ✓ 进程权限检查
- ✓ 文件权限检查
- ✓ SELinux 状态
- ✓ AppArmor 配置

#### 5. 日志和审计
- ✓ 审计日志完整性
- ✓ 日志保留策略
- ✓ 访问日志检查

## 🚀 快速使用

### 基础审计

```bash
# 运行完整审计
./scripts/SECURITY_AUDIT.sh

# 输出到文件
./scripts/SECURITY_AUDIT.sh > security_audit_$(date +%Y%m%d).log
```

### 指定审计项

```bash
# 仅扫描代码
./scripts/SECURITY_AUDIT.sh --code-only

# 仅检查依赖
./scripts/SECURITY_AUDIT.sh --deps-only

# 仅检查配置
./scripts/SECURITY_AUDIT.sh --config-only

# 仅检查运行时
./scripts/SECURITY_AUDIT.sh --runtime-only
```

### 生成报告

```bash
# 生成 HTML 报告
./scripts/SECURITY_AUDIT.sh --format html > security_report.html

# 生成 JSON 报告
./scripts/SECURITY_AUDIT.sh --format json > security_report.json

# 生成 PDF 报告 (需要 wkhtmltopdf)
./scripts/SECURITY_AUDIT.sh --format pdf > security_report.pdf
```

## 📊 审计结果解读

### 严重级别

| 级别 | 说明 | 例子 | 处理方式 |
|------|------|------|---------|
| 🔴 CRITICAL | 立即修复 | 后门、硬编码密钥 | 紧急修复 |
| 🟠 HIGH | 尽快修复 | SQL 注入、权限提升 | 本周内修复 |
| 🟡 MEDIUM | 计划修复 | 弱密码、过时依赖 | 本月内修复 |
| 🟢 LOW | 改进建议 | 日志不完整、建议 | 持续改进 |

### 审计输出示例

```
╔═════════════════════════════════════════╗
║    安全审计报告 - ONLYOFFICE           ║
║    时间: 2026-01-28 10:30:00            ║
╚═════════════════════════════════════════╝

【代码安全扫描】
├─ ✅ 后门检测: PASS (未发现)
├─ ✅ SQL注入: PASS (0 个风险)
├─ ⚠️  XSS 检测: 2 个低风险发现
└─ ✅ 命令注入: PASS

【依赖安全】
├─ ✅ 已知漏洞: PASS
├─ ⚠️  过时依赖: 3 个需要更新
└─ ✅ 许可证: PASS

【配置安全】
├─ ✅ 默认凭证: PASS
├─ ⚠️  密码策略: 建议启用 MFA
└─ ✅ SSL/TLS: PASS

【运行时安全】
├─ ✅ 进程权限: PASS
├─ ✅ 文件权限: PASS
└─ ✅ SELinux: ENFORCING

【审计评分】
总体安全得分: 8.5/10
建议等级: 低风险可投入生产
```

## 🔍 常见安全问题及解决

### 问题 1: 发现 SQL 注入风险

**原因**: 用户输入未经过适当的参数化处理

**解决方案**:
```javascript
// ❌ 不安全
const query = `SELECT * FROM users WHERE id = ${userId}`;

// ✅ 安全
const query = 'SELECT * FROM users WHERE id = $1';
db.query(query, [userId]);
```

### 问题 2: 发现硬编码密钥

**原因**: 密钥/令牌直接写在代码中

**解决方案**:
```bash
# 移动到环境变量
export DB_PASSWORD="your_secure_password"

# 从环境读取
const password = process.env.DB_PASSWORD;
```

### 问题 3: 默认凭证未修改

**原因**: 使用了默认的用户名和密码

**解决方案**:
```bash
# Grafana
./deploy-monitoring.sh
# 然后修改默认密码

# PostgreSQL
docker exec onlyoffice-postgresql psql -U postgres -c \
  "ALTER USER onlyoffice WITH PASSWORD 'new_secure_password';"

# RabbitMQ
docker exec onlyoffice-rabbitmq rabbitmqctl change_password guest new_password
```

### 问题 4: SSL/TLS 配置不安全

**原因**: 使用了已过期或弱密钥

**解决方案**:
```bash
# 生成新的自签名证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/onlyoffice/certs/key.pem \
  -out /etc/onlyoffice/certs/cert.pem

# 使用正式的 CA 证书 (生产环境)
# 从受信任的 CA 申请证书
```

### 问题 5: 日志不完整或权限过高

**原因**: 日志配置不当，审计追踪不完整

**解决方案**:
```bash
# 启用完整的审计日志
export ONLYOFFICE_AUDIT_LOG=true

# 配置日志文件权限
chmod 640 /var/log/onlyoffice/*.log

# 设置日志保留策略
logrotate -f /etc/logrotate.d/onlyoffice
```

## 📋 安全检查清单

### 部署前

- [ ] 运行完整的安全审计: `./scripts/SECURITY_AUDIT.sh`
- [ ] 查看审计报告，处理所有高危问题
- [ ] 修改所有默认凭证
- [ ] 启用 HTTPS/SSL
- [ ] 配置防火墙规则
- [ ] 禁用不必要的服务
- [ ] 启用日志审计
- [ ] 配置备份策略

### 部署时

- [ ] 创建非 root 用户运行应用
- [ ] 限制文件和目录权限
- [ ] 启用 SELinux/AppArmor
- [ ] 配置网络隔离
- [ ] 启用 SSL/TLS
- [ ] 配置资源限制
- [ ] 启用健康检查

### 部署后

- [ ] 定期运行安全审计 (周/月)
- [ ] 监控安全日志
- [ ] 及时更新依赖
- [ ] 定期备份数据
- [ ] 测试灾难恢复程序
- [ ] 参加安全培训
- [ ] 维护安全文档

## 🛡️ 安全最佳实践

### 1. 最小权限原则

```bash
# 运行应用的用户应该只有必要权限
useradd -m -u 1000 onlyoffice
chown -R onlyoffice:onlyoffice /app/onlyoffice
chmod 750 /app/onlyoffice
```

### 2. 深度防御

```
网络防护层 (防火墙)
  ↓
应用防护层 (WAF/IDS)
  ↓
应用层 (认证/授权)
  ↓
数据层 (加密)
  ↓
审计层 (日志)
```

### 3. 安全通信

```bash
# 启用 HTTPS
export SSL_ENABLED=true
export SSL_CERTIFICATE=/etc/onlyoffice/certs/cert.pem
export SSL_KEY=/etc/onlyoffice/certs/key.pem

# 启用 HSTS
export HSTS_MAX_AGE=31536000

# 禁用不安全的协议
export TLS_MIN_VERSION=1.2
```

### 4. 数据保护

```bash
# 启用数据加密
export DATABASE_ENCRYPTION=true

# 启用备份加密
export BACKUP_ENCRYPTION=true
gpg --encrypt backup.sql

# 启用审计日志加密
export AUDIT_LOG_ENCRYPTION=true
```

### 5. 访问控制

```bash
# 启用 MFA
export MFA_ENABLED=true

# 配置 RBAC
export RBAC_ENABLED=true

# 启用 SSO (使用 LDAP/OAuth)
export SSO_ENABLED=true
export LDAP_SERVER=ldap://your-ldap-server
```

## 📊 安全指标

### 推荐的安全评分

| 指标 | 目标 | 检查方法 |
|------|------|---------|
| 后门检测 | 0 个发现 | 代码审计 |
| SQL 注入 | 0 个风险 | 代码扫描 |
| 已知漏洞 | 0 个 CRITICAL | 依赖检查 |
| 默认凭证 | 已修改 | 配置审计 |
| SSL/TLS | A 级及以上 | SSL Labs 检查 |
| 权限设置 | 符合最小权限 | 权限审计 |

### 运行时监控

```bash
# 监控文件完整性
aide --init
aide --check

# 监控进程
ps aux | grep onlyoffice

# 监控网络连接
netstat -tuln | grep LISTEN

# 查看日志
tail -f /var/log/onlyoffice/audit.log
```

## 📖 相关文档

### 内部文档

- `../monitoring/docs/` - 审计日志配置
- `../deployment/README.md` - 安全部署指南

### 外部资源

- OWASP Top 10
- CIS Benchmarks
- NIST Cybersecurity Framework
- PCI DSS

## 🔐 应急响应

如果发现安全问题：

1. **立即隔离** 受影响的系统
2. **保留日志** 用于分析
3. **评估影响** 范围和严重性
4. **采取行动** 修复漏洞
5. **验证修复** 重新运行审计
6. **文档记录** 问题和解决方案
7. **事后分析** 防止再次发生

## 📞 获取帮助

遇到安全问题？

1. 查看审计报告中的具体建议
2. 查看本文件夹中的解决方案
3. 参考 OWASP 指南
4. 联系安全团队

---

**版本**: 1.0  
**最后更新**: 2026-01-28  
**建议**: 定期 (月度) 运行安全审计
**支持**: ONLYOFFICE 社区
