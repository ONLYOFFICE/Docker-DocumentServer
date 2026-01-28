# CHANGELOG

## 2026-01-28 — 按用途整理文件并添加 README 和导航文档

提交: `0e237e6`

主要变更：
- 创建并按用途分类存放以下四大目录：`monitoring/`、`performance-testing/`、`deployment/`、`security/`。
- 为每个目录添加 `README.md` 快速指南及若干详细文档（监控、性能测试、部署与安全）。
- 新增 `FILE_STRUCTURE.md` 作为项目导航指南。
- 新增并移动若干脚本、配置与示例文件（Prometheus、Alertmanager、Grafana、Logstash 等）。

影响文件（摘要）：
- 新增或移动 40 个文件；包括脚本、YAML 配置、JSON 仪表板和多篇文档。

目的：
- 将项目从分散文件集合整理为按功能划分的模块化结构，便于团队协作、部署和运维。

回退说明：
- 如需回退，可使用 `git revert 0e237e6` 或检查变更详情：

```bash
git show --name-only 0e237e6
```

更多信息：参见 `FILE_STRUCTURE.md` 和每个目录下的 `README.md`。
