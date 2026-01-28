#!/bin/bash

# 安全审计脚本

echo "🔐 ONLYOFFICE Document Server 代码安全审计"
echo "=============================================="
echo ""

RISK_REPORT=""
ISSUES_FOUND=0

# 检查 1: eval 命令使用
echo "📍 检查 1: eval 命令使用 (可能的代码注入风险)"
eval_usage=$(grep -rn "eval " . --include="*.sh" --exclude-dir=.git 2>/dev/null || echo "")
if [ -n "$eval_usage" ]; then
    echo "⚠️  发现 eval 命令："
    echo "$eval_usage" | head -5
    echo ""
    RISK_REPORT="${RISK_REPORT}[⚠️  MEDIUM] eval 命令使用：可能的变量注入风险\n"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
else
    echo "✅ 未发现 eval 命令"
    echo ""
fi

# 检查 2: 超级用户访问权限 (chmod 777)
echo "📍 检查 2: 过度宽松的文件权限"
chmod_777=$(grep -rn "chmod.*777" . --include="*.sh" --include="Dockerfile*" 2>/dev/null || echo "")
if [ -n "$chmod_777" ]; then
    echo "⚠️  发现 chmod 777："
    echo "$chmod_777"
    echo ""
    RISK_REPORT="${RISK_REPORT}[⚠️  MEDIUM] chmod 777 使用：过度宽松权限\n"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
else
    echo "✅ 未发现 chmod 777"
    echo ""
fi

# 检查 3: 反向shell模式
echo "📍 检查 3: 反向shell模式检测"
reverse_shell=$(grep -rn "bash -i\|nc -e\|/bin/bash.*&\s*/dev/tcp\|exec.*&" . --include="*.sh" 2>/dev/null || echo "")
if [ -n "$reverse_shell" ]; then
    echo "⚠️  发现可疑的反向shell模式："
    echo "$reverse_shell"
    echo ""
    RISK_REPORT="${RISK_REPORT}[🔴 HIGH] 反向shell检测：可能的后门\n"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
else
    echo "✅ 未发现反向shell模式"
    echo ""
fi

# 检查 4: 远程代码执行 (curl | bash)
echo "📍 检查 4: 远程代码执行模式"
remote_exec=$(grep -rn "curl.*|.*bash\|wget.*-O.*|.*bash\|curl.*-s.*|.*sh" . --include="*.sh" --include="Dockerfile*" 2>/dev/null || echo "")
if [ -n "$remote_exec" ]; then
    echo "⚠️  发现远程执行模式："
    echo "$remote_exec" | head -3
    echo ""
    RISK_REPORT="${RISK_REPORT}[🔴 HIGH] 远程执行风险：未验证的代码下载\n"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
else
    echo "✅ 未发现 curl|bash 模式"
    echo ""
fi

# 检查 5: 硬编码的密钥
echo "📍 检查 5: 硬编码的密钥和凭证"
secrets=$(grep -rn "password\|secret\|key\|token" . --include="*.sh" --include="*.js" --include="Dockerfile*" 2>/dev/null | grep -i "=\|export\|:=" | head -10 || echo "")
if [ -n "$secrets" ]; then
    echo "ℹ️  检测到密钥相关字符串 (需要进一步审查)："
    echo "$secrets" | head -5
    echo ""
fi

# 检查 6: sed -i 与用户输入组合
echo "📍 检查 6: sed/awk 与环境变量组合 (注入风险)"
sed_injection=$(grep -rn "sed.*\${" . --include="*.sh" 2>/dev/null || echo "")
if [ -n "$sed_injection" ]; then
    echo "⚠️  发现 sed 与环境变量的组合："
    echo "$sed_injection" | head -3
    echo ""
    RISK_REPORT="${RISK_REPORT}[⚠️  MEDIUM] sed 注入风险：环境变量未充分转义\n"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
else
    echo "✅ sed 使用相对安全"
    echo ""
fi

# 检查 7: 不安全的find命令
echo "📍 检查 7: find -exec 安全性"
find_exec=$(grep -rn "find.*-exec" . --include="*.sh" 2>/dev/null | head -5 || echo "")
if [ -n "$find_exec" ]; then
    echo "ℹ️  检测到 find -exec："
    echo "$find_exec" | head -3
    echo ""
fi

# 检查 8: 日志文件写入权限
echo "📍 检查 8: 日志文件和临时文件权限"
tmpdir=$(grep -rn "/tmp\|/var/tmp" . --include="*.sh" 2>/dev/null || echo "")
if [ -n "$tmpdir" ]; then
    echo "ℹ️  检测到临时文件使用："
    echo "$tmpdir" | head -3
    echo ""
fi

# 检查 9: 使用 set -e 进行错误处理
echo "📍 检查 9: 错误处理机制"
set_e=$(head -20 run-document-server.sh | grep "set -e" || echo "")
if [ -z "$set_e" ]; then
    echo "⚠️  脚本未使用 'set -e'，可能继续执行失败的命令"
    RISK_REPORT="${RISK_REPORT}[ℹ️  INFO] 缺少 'set -e'：潜在的错误隐藏\n"
else
    echo "✅ 脚本正确使用错误处理"
    echo ""
fi

# 检查 10: 奇怪的网络连接
echo "📍 检查 10: 奇怪的网络连接"
network=$(grep -rn "nc -l\|telnet\|/dev/tcp" . --include="*.sh" 2>/dev/null || echo "")
if [ -n "$network" ]; then
    echo "ℹ️  检测到网络操作："
    echo "$network"
    echo ""
fi

echo ""
echo "=============================================="
echo "✅ 审计完成"
echo "发现问题数: $ISSUES_FOUND"
echo ""
