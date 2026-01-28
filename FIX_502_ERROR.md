# 🔧 502 错误修复报告

**问题日期**：2026-01-28  
**问题状态**：✅ 已解决  
**修复方法**：启动缺失的服务 + 自动启动配置  

---

## 📋 问题描述

访问以下地址返回 **502 Bad Gateway** 错误：
- `https://bug-free-memory-wrxwp964qrpcg4q7-80.app.github.dev/admin/`
- `https://bug-free-memory-wrxwp964qrpcg4q7-80.app.github.dev/example/`

---

## 🔍 根本原因

### 诊断过程
```bash
$ docker-compose ps
# 容器状态：全部运行正常 ✅

$ docker exec onlyoffice-documentserver supervisorctl status
# 发现问题！⚠️
ds:adminpanel      STOPPED   Not started
ds:example         STOPPED   Not started
ds:converter       RUNNING   ✅
ds:docservice      RUNNING   ✅
```

### 问题原因
两个服务的 Supervisor 配置中包含：
```ini
[program:adminpanel]
autostart=false    ← 不自动启动

[program:example]
autostart=false    ← 不自动启动
```

**后果**：当 Document Server 容器启动时，这两个关键服务没有自动启动，导致对应的端点返回 502。

---

## ✅ 修复方案

### 步骤 1：立即启动缺失的服务
```bash
docker exec onlyoffice-documentserver supervisorctl start ds:adminpanel ds:example
# 结果：
# ds:adminpanel: started
# ds:example: started
```

### 步骤 2：验证修复
```bash
curl -w "Admin Panel: HTTP %{http_code}\n" -o /dev/null http://localhost/admin/
# Admin Panel: HTTP 200  ✅

curl -w "Example: HTTP %{http_code}\n" -o /dev/null http://localhost/example/
# Example: HTTP 200  ✅
```

### 步骤 3：永久修复（防止重启后再次出现）

**修改文件**：[run-document-server.sh](run-document-server.sh#L801-L810)

**修改内容**：在启动 supervisor 后添加自动启动这两个服务
```bash
# 之前
service supervisor start

# 之后
service supervisor start

# Wait for supervisor to be ready, then start adminpanel and example services
sleep 2
supervisorctl start ds:adminpanel ds:example
```

**重新构建容器**：
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

---

## 🎯 结果

### 修复前
```
Admin Panel:  ❌ 502 Bad Gateway
Example:      ❌ 502 Bad Gateway
```

### 修复后
```
Admin Panel:  ✅ HTTP 200 OK
Example:      ✅ HTTP 200 OK
```

### Supervisor 状态
```
ds:adminpanel    RUNNING  pid 766, uptime 0:00:25  ✅
ds:converter     RUNNING  pid 754, uptime 0:00:26  ✅
ds:docservice    RUNNING  pid 753, uptime 0:00:26  ✅
ds:example       RUNNING  pid 788, uptime 0:00:23  ✅
```

---

## 📊 修复要点

| 项目 | 详情 |
|------|------|
| **问题根因** | adminpanel 和 example 服务配置 `autostart=false` |
| **症状** | 访问 /admin/ 和 /example/ 返回 502 |
| **临时修复** | 手动运行 `supervisorctl start` 命令 |
| **永久修复** | 修改 run-document-server.sh 脚本，在启动 supervisor 后自动启动这两个服务 |
| **测试结果** | 所有服务正常运行，HTTP 200 返回 |
| **容器重启** | ✅ 修复后重启容器，服务仍自动启动 |

---

## 🚀 防止措施

为避免类似问题再次出现：

1. **定期检查 Supervisor 服务状态**
   ```bash
   docker exec onlyoffice-documentserver supervisorctl status
   ```

2. **监控 HTTP 502 错误**
   建议配置告警监控 `/admin/` 和 `/example/` 端点的可用性

3. **自动化检查脚本**
   ```bash
   # 在容器启动后验证所有关键服务都已启动
   docker exec onlyoffice-documentserver supervisorctl status | grep RUNNING
   ```

---

## 📝 修改文件清单

- [x] [run-document-server.sh](run-document-server.sh) - 添加自动启动逻辑
- [x] 重新构建 Docker 镜像 - 应用修改
- [x] 测试验证 - 所有服务正常运行

---

## 🔗 相关配置文件

### Supervisor 配置位置
```
/etc/supervisor/conf.d/ds-adminpanel.conf  - Admin Panel 配置
/etc/supervisor/conf.d/ds-example.conf     - Example 配置
```

### 日志位置
```
/var/log/onlyoffice/documentserver/adminpanel/  - Admin Panel 日志
/var/log/onlyoffice/documentserver-example/     - Example 日志
/var/log/supervisor/supervisord.log             - Supervisor 主日志
```

---

**修复完成日期**：2026-01-28  
**修复人员**：自动诊断和修复系统  
**测试状态**：✅ 通过  
