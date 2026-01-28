#!/bin/bash

################################################################################
# ONLYOFFICE Document Server 容量规划计算器
# 基于硬件配置和业务需求计算最优部署方案
################################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    cat << EOF
${BLUE}ONLYOFFICE 容量规划计算器${NC}

用法：
  $0 <cpu_cores> <memory_gb> [--concurrent-users <number>] [--peak-multiplier <factor>]

参数说明：
  cpu_cores         CPU 核心数（必需）
  memory_gb         内存大小（GB，必需）
  
可选参数：
  --concurrent-users <number>    预期并发用户数（默认：自动计算）
  --peak-multiplier <factor>     峰值流量倍数（默认：2）
  --help                         显示此帮助信息

示例：
  $0 4 4                                    # 4核4GB 服务器
  $0 8 16 --concurrent-users 100            # 8核16GB，100 个并发用户
  $0 16 32 --peak-multiplier 3              # 16核32GB，峰值 3x

EOF
}

# 检查参数
if [ $# -lt 2 ]; then
    show_help
    exit 1
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

CPU_CORES="$1"
MEMORY_GB="$2"

CONCURRENT_USERS=""
PEAK_MULTIPLIER=2

# 解析可选参数
while [ $# -gt 2 ]; do
    case "$3" in
        --concurrent-users)
            CONCURRENT_USERS="$4"
            shift 2
            ;;
        --peak-multiplier)
            PEAK_MULTIPLIER="$4"
            shift 2
            ;;
        *)
            echo "未知参数：$3"
            exit 1
            ;;
    esac
done

# 验证输入
if ! [[ "$CPU_CORES" =~ ^[0-9]+$ ]] || [ "$CPU_CORES" -lt 1 ]; then
    echo -e "${RED}错误：CPU 核心数必须是正整数${NC}"
    exit 1
fi

if ! [[ "$MEMORY_GB" =~ ^[0-9]+$ ]] || [ "$MEMORY_GB" -lt 1 ]; then
    echo -e "${RED}错误：内存大小必须是正整数${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ONLYOFFICE Document Server 容量规划  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# 第一部分：输入硬件配置
echo -e "${CYAN}【硬件配置】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CPU 核心数：        $CPU_CORES"
echo "内存大小：          ${MEMORY_GB}GB"
echo ""

# 第二部分：自动计算各项限制
echo -e "${CYAN}【系统限制分析】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. 文件描述符限制
# 假设调优后的值
FD_LIMIT=131072
if [ "$CPU_CORES" -lt 4 ]; then
    FD_LIMIT=65536
fi

echo "• 文件描述符限制（调优后）"
echo "    推荐值：$FD_LIMIT"
echo ""

# 2. Nginx Worker 配置
NGINX_WORKERS=$CPU_CORES
NGINX_CONNECTIONS=$((FD_LIMIT / CPU_CORES))

# 每个 worker 的连接数不应超过 65536
if [ "$NGINX_CONNECTIONS" -gt 65536 ]; then
    NGINX_CONNECTIONS=65536
fi

NGINX_MAX_CONN=$((NGINX_WORKERS * NGINX_CONNECTIONS))

echo "• Nginx 配置"
echo "    Worker 进程数：$NGINX_WORKERS"
echo "    每个 Worker 最大连接：$NGINX_CONNECTIONS"
echo "    Nginx 最大并发连接：$NGINX_MAX_CONN"
echo ""

# 3. 数据库连接限制
# 计算基于内存的数据库连接数
DB_BASE_CONN=100
if [ "$MEMORY_GB" -ge 4 ]; then
    DB_BASE_CONN=150
fi
if [ "$MEMORY_GB" -ge 8 ]; then
    DB_BASE_CONN=200
fi
if [ "$MEMORY_GB" -ge 16 ]; then
    DB_BASE_CONN=300
fi
if [ "$MEMORY_GB" -ge 32 ]; then
    DB_BASE_CONN=500
fi

# 预留 10 个连接给系统
DB_AVAILABLE=$((DB_BASE_CONN - 10))

echo "• 数据库连接限制"
echo "    max_connections：$DB_BASE_CONN"
echo "    可用连接数：$DB_AVAILABLE"
echo ""

# 4. 内存估算
# 每个并发用户占用约 8-10MB 内存
MEMORY_PER_USER=8
ESTIMATED_BY_MEM=$((MEMORY_GB * 1024 / MEMORY_PER_USER))

# 预留系统内存（约 1GB）
USABLE_MEMORY=$((MEMORY_GB - 1))
if [ "$USABLE_MEMORY" -lt 1 ]; then
    USABLE_MEMORY=1
fi
ESTIMATED_BY_MEM=$((USABLE_MEMORY * 1024 / MEMORY_PER_USER))

echo "• 内存可支持的并发用户数"
echo "    假设每个用户占用：${MEMORY_PER_USER}MB"
echo "    可用内存：${USABLE_MEMORY}GB"
echo "    预计支持：$ESTIMATED_BY_MEM 个并发用户"
echo ""

# 第三部分：计算实际并发能力
echo -e "${CYAN}【并发能力计算】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 取各个限制的最小值
REAL_LIMIT=$DB_AVAILABLE  # 通常数据库连接是主要瓶颈

if [ "$NGINX_MAX_CONN" -lt "$REAL_LIMIT" ]; then
    REAL_LIMIT=$NGINX_MAX_CONN
    BOTTLENECK="Nginx 连接数"
fi

if [ "$ESTIMATED_BY_MEM" -lt "$REAL_LIMIT" ]; then
    REAL_LIMIT=$ESTIMATED_BY_MEM
    BOTTLENECK="内存"
fi

if [ -z "$CONCURRENT_USERS" ]; then
    CONCURRENT_USERS=$REAL_LIMIT
fi

echo "各项限制总结："
echo "  • Nginx 连接：$NGINX_MAX_CONN"
echo "  • 数据库连接：$DB_AVAILABLE"
echo "  • 内存估算：$ESTIMATED_BY_MEM"
echo ""

if [ "$REAL_LIMIT" -le 0 ]; then
    REAL_LIMIT=1
fi

echo -e "${GREEN}理论并发上限：$REAL_LIMIT 用户${NC}"
echo -e "主要瓶颈：${BOTTLENECK:-系统综合限制}${NC}"
echo ""

# 第四部分：业务场景分析
echo -e "${CYAN}【业务场景分析】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 常态并发
NORMAL_CONCURRENT=$((CONCURRENT_USERS * 60 / 100))

# 峰值并发
PEAK_CONCURRENT=$((NORMAL_CONCURRENT * PEAK_MULTIPLIER))

# 日均请求数估算（每个用户每天平均 20 个操作）
DAILY_REQUESTS=$((NORMAL_CONCURRENT * 20 * 8))  # 8 小时工作时间

# 峰值吞吐（每秒请求数）
PEAK_RPS=$((PEAK_CONCURRENT * 2))

echo "预期并发用户数：$CONCURRENT_USERS"
echo ""
echo "场景分析："
echo "  • 正常工作时间并发：$NORMAL_CONCURRENT 用户"
echo "  • 峰值时刻并发：$PEAK_CONCURRENT 用户"
echo "  • 日均请求数：约 $DAILY_REQUESTS 次"
echo "  • 峰值吞吐量：$PEAK_RPS req/s"
echo ""

# 第五部分：推荐配置
echo -e "${CYAN}【推荐配置参数】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Docker 启动命令："
echo ""
echo "docker run -d -p 80:80 -p 443:443 \\"
echo "  -e NGINX_WORKER_PROCESSES=$NGINX_WORKERS \\"
echo "  -e NGINX_WORKER_CONNECTIONS=$NGINX_CONNECTIONS \\"
echo "  -e DB_TYPE=postgres \\"
echo "  -e DB_HOST=<your-db-host> \\"
echo "  -e DB_PORT=5432 \\"
echo "  -e DB_NAME=onlyoffice \\"
echo "  -e DB_USER=onlyoffice \\"
echo "  -e DB_PWD=<password> \\"
echo "  --restart always \\"
echo "  --name documentserver \\"
echo "  onlyoffice/documentserver"
echo ""

echo "数据库配置建议（PostgreSQL）："
echo ""
echo "  max_connections = $DB_BASE_CONN"

# 计算 shared_buffers
SHARED_BUFFERS=$((MEMORY_GB / 4))
if [ "$SHARED_BUFFERS" -lt 1 ]; then
    SHARED_BUFFERS=1
fi
if [ "$SHARED_BUFFERS" -gt 16 ]; then
    SHARED_BUFFERS=16
fi

echo "  shared_buffers = ${SHARED_BUFFERS}GB"

EFFECTIVE_CACHE=$((MEMORY_GB * 3 / 4))
echo "  effective_cache_size = ${EFFECTIVE_CACHE}GB"

echo ""

# 第六部分：监控建议
echo -e "${CYAN}【监控建议】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "关键监控指标："
echo "  • CPU 利用率（目标：60-80%）"
echo "  • 内存利用率（目标：70-85%）"
echo "  • 数据库连接数（<= $((DB_BASE_CONN - 10))）"
echo "  • Nginx 活跃连接数（<= $NGINX_MAX_CONN）"
echo "  • 磁盘 I/O（特别是数据库日志）"
echo "  • 网络 I/O（上行/下行带宽）"
echo ""

# 第七部分：成本估算
echo -e "${CYAN}【成本估算】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

case "$CPU_CORES:$MEMORY_GB" in
    1:1|1:2|2:1|2:2)
        PRICE_LEVEL="⭐ 低（~¥300-600/年）"
        RATING="测试/演示"
        ;;
    2:4|4:4|4:8)
        PRICE_LEVEL="⭐⭐ 中低（~¥1,200/年）"
        RATING="小型生产环境"
        ;;
    8:8|8:16|8:32)
        PRICE_LEVEL="⭐⭐⭐ 中等（~¥3,600/年）"
        RATING="中型生产环境"
        ;;
    16:16|16:32|16:64)
        PRICE_LEVEL="⭐⭐⭐⭐ 中高（~¥10,800/年）"
        RATING="大型生产环境"
        ;;
    *)
        PRICE_LEVEL="⭐⭐⭐⭐⭐ 企业级（>¥10,800/年）"
        RATING="企业级高可用"
        ;;
esac

echo "成本等级：$PRICE_LEVEL"
echo "适配场景：$RATING"
echo ""

# 第八部分：升级建议
echo -e "${CYAN}【升级建议】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

NEXT_CPU=$((CPU_CORES * 2))
NEXT_MEM=$((MEMORY_GB * 2))

echo "当前配置支持约 $REAL_LIMIT 个并发用户。"
echo ""
echo "如需支持更多用户，升级建议："
echo "  下一阶段：${NEXT_CPU} 核 ${NEXT_MEM}GB 内存"
echo "  水平扩展：使用 HAProxy 负载均衡多个服务实例"
echo "  垂直优化：分离数据库、缓存等服务到独立服务器"
echo ""

# 第九部分：快速参考表
echo -e "${CYAN}【快速参考表】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat << EOF
并发用户 | 推荐 CPU | 推荐内存 | 推荐配置
---------|---------|---------|------------------
  1-20  |   2 核   |   2 GB  | 测试/演示环境
 20-50  |   4 核   |   4 GB  | 小型团队 ⭐ 推荐
50-150  |   8 核   |  16 GB  | 中型企业 ⭐ 推荐
150-300 |  12 核   |  24 GB  | 大型企业
 300+   |  16 核   |  32 GB  | 企业级高可用

EOF

echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        规划完成，祝您使用愉快！        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
