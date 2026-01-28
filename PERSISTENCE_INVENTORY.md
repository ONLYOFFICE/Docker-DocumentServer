# PERSISTENCE_INVENTORY.md

> 本文件汇总了本项目涉及的所有持久化存储组件，包括数据库、缓存、消息队列、时序数据库、日志索引等，便于运维、备份与恢复。

---

## 1. 关系型数据库

### PostgreSQL（主数据库）
- 服务名：`onlyoffice-postgresql`
- 镜像：`postgres:15-alpine`
- 端口：5432
- 卷：`onlyoffice-postgres-data`
- 备份：
  ```bash
  docker exec onlyoffice-postgresql pg_dump -U onlyoffice onlyoffice > backup.sql
  ```
- 恢复：
  ```bash
  docker exec -i onlyoffice-postgresql psql -U onlyoffice onlyoffice < backup.sql
  ```

### 兼容性测试数据库（可选）
- MySQL、MariaDB、MSSQL、Oracle、达梦（见 `tests/` 目录下各 compose 文件）

---

## 2. 非关系型数据库 / 缓存

### Redis
- 服务名：`onlyoffice-redis`
- 镜像：`redis:alpine`
- 端口：6379
- 卷：`onlyoffice-redis-data`
- 备份：
  ```bash
  docker exec onlyoffice-redis redis-cli save
  docker cp onlyoffice-redis:/data/dump.rdb ./redis-backup.rdb
  ```
- 恢复：
  ```bash
  docker cp ./redis-backup.rdb onlyoffice-redis:/data/dump.rdb
  docker restart onlyoffice-redis
  ```

---

## 3. 消息队列

### RabbitMQ
- 服务名：`onlyoffice-rabbitmq`
- 镜像：`rabbitmq:3`
- 端口：5672（AMQP），15672（管理）
- 持久化卷：如有自定义可在 compose 文件中指定
- 备份/恢复：建议使用管理界面导出/导入定义

---

## 4. 时序数据库 / 指标存储

### Prometheus
- 服务名：`prometheus`
- 镜像：`prom/prometheus:latest`
- 端口：9090
- 卷：`prometheus-data`
- 备份：
  ```bash
  docker cp prometheus:/prometheus ./prometheus-backup
  ```
- 恢复：
  ```bash
  docker cp ./prometheus-backup prometheus:/prometheus
  docker restart prometheus
  ```

---

## 5. 日志索引 / 检索

### Elasticsearch
- 服务名：`elasticsearch`
- 镜像：`elasticsearch:8.11.1`（示例）
- 端口：9200
- 卷：`elasticsearch-data`
- 备份：
  ```bash
  # 需配置快照仓库
  curl -XPUT 'http://localhost:9200/_snapshot/my_backup' -H 'Content-Type: application/json' -d '{"type": "fs", "settings": {"location": "/usr/share/elasticsearch/backup"}}'
  curl -XPUT 'http://localhost:9200/_snapshot/my_backup/snapshot_1?wait_for_completion=true'
  ```
- 恢复：
  ```bash
  curl -XPOST 'http://localhost:9200/_snapshot/my_backup/snapshot_1/_restore'
  ```

---

## 6. 可视化配置

### Grafana
- 服务名：`grafana`
- 镜像：`grafana/grafana:latest`
- 端口：3000
- 卷：`grafana-data`
- 备份：
  ```bash
  docker cp grafana:/var/lib/grafana ./grafana-backup
  ```
- 恢复：
  ```bash
  docker cp ./grafana-backup grafana:/var/lib/grafana
  docker restart grafana
  ```

---

## 7. 卷声明（docker-compose 示例）

```yaml
volumes:
  onlyoffice-postgres-data:
  onlyoffice-redis-data:
  prometheus-data:
  grafana-data:
  elasticsearch-data:
```

---

## 8. 参考
- 详细配置见 `deployment/README.md`、`monitoring/config/`、`tests/` 目录
- 备份/恢复命令可根据实际部署路径调整

---

如需扩展存储方案或自动化备份脚本，可在本文件下方补充。