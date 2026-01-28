#!/bin/bash

echo "📁 开始组织文件..."
echo ""

# 1. 监控和日志系统
echo "📊 1. 移动监控和日志相关文件..."
mv -v enterprise-monitoring.sh monitoring/scripts/ 2>/dev/null
mv -v enterprise-logging.sh monitoring/scripts/ 2>/dev/null
mv -v prometheus.yml monitoring/config/ 2>/dev/null
mv -v alert_rules.yml monitoring/config/ 2>/dev/null
mv -v alertmanager.yml monitoring/config/ 2>/dev/null
mv -v grafana-dashboard.json monitoring/config/ 2>/dev/null
mv -v grafana-datasources.yml monitoring/config/ 2>/dev/null
mv -v logstash.conf monitoring/config/ 2>/dev/null
mv -v README_MONITORING.md monitoring/docs/ 2>/dev/null
mv -v ENTERPRISE_MONITORING_GUIDE.md monitoring/docs/ 2>/dev/null
mv -v MONITORING_VERIFICATION.md monitoring/docs/ 2>/dev/null
mv -v INTEGRATION_CHECKLIST.md monitoring/docs/ 2>/dev/null

# 2. 性能测试相关
echo "🏃 2. 移动性能测试相关文件..."
mv -v performance-test.sh performance-testing/scripts/ 2>/dev/null
mv -v performance-diagnosis.sh performance-testing/scripts/ 2>/dev/null
mv -v concurrency-test.sh performance-testing/scripts/ 2>/dev/null
mv -v capacity-planning.sh performance-testing/scripts/ 2>/dev/null
mv -v README_PERFORMANCE.md performance-testing/docs/ 2>/dev/null
mv -v PERFORMANCE_TOOLS_README.md performance-testing/docs/ 2>/dev/null
mv -v CONCURRENT_PERFORMANCE_SUMMARY.md performance-testing/docs/ 2>/dev/null

# 3. 部署相关
echo "🐳 3. 移动部署相关文件..."
mv -v docker-compose-monitoring.yml deployment/ 2>/dev/null
mv -v deploy-monitoring.sh deployment/ 2>/dev/null

# 4. 安全审计
echo "🔐 4. 移动安全审计相关文件..."
mv -v SECURITY_AUDIT.sh security/scripts/ 2>/dev/null

echo ""
echo "✅ 文件组织完成！"
