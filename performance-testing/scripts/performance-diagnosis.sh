#!/bin/bash

################################################################################
# ONLYOFFICE Document Server 并发性能测试和优化工具
# 用于诊断系统并发瓶颈和提供优化建议
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 当前配置收集
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}ONLYOFFICE 并发性能诊断工具${NC}"
echo -e "${BLUE}================================${NC}\n"

# 检查是否运行在 Docker 容器内
is_in_container() {
    [ -f /.dockerenv ] || [ -f /run/.dockerenv ]
}

# 1. 系统资源信息
echo -e "${YELLOW}[1] 系统资源信息${NC}"
echo "-----------------------------------"

CPU_CORES=$(nproc)
TOTAL_MEM=$(free -h | grep Mem | awk '{print $2}')
AVAILABLE_MEM=$(free -h | grep Mem | awk '{print $7}')
SWAP=$(free -h | grep Swap | awk '{print $2}')

echo "CPU 核心数：$CPU_CORES"
echo "总内存：$TOTAL_MEM"
echo "可用内存：$AVAILABLE_MEM"
echo "交换空间：$SWAP"
echo ""

# 2. 文件描述符限制
echo -e "${YELLOW}[2] 文件描述符限制${NC}"
echo "-----------------------------------"

if is_in_container; then
    FD_SOFT=$(ulimit -S -n)
    FD_HARD=$(ulimit -H -n)
    echo "软限制 (soft)：$FD_SOFT"
    echo "硬限制 (hard)：$FD_HARD"
    
    if [ "$FD_SOFT" -lt 65536 ]; then
        echo -e "${RED}⚠ 警告：文件描述符过低，建议设置为 65536+${NC}"
    else
        echo -e "${GREEN}✓ 文件描述符配置良好${NC}"
    fi
else
    echo "系统文件描述符限制："
    cat /proc/sys/fs/file-max
    echo ""
    echo "默认打开文件数："
    ulimit -n
fi
echo ""

# 3. Nginx 配置检查
echo -e "${YELLOW}[3] Nginx 配置${NC}"
echo "-----------------------------------"

if is_in_container; then
    if [ -f /etc/nginx/nginx.conf ]; then
        WORKER_PROCESSES=$(grep "^worker_processes" /etc/nginx/nginx.conf | awk '{print $2}' | sed 's/;//')
        WORKER_CONNECTIONS=$(grep "worker_connections" /etc/nginx/nginx.conf | awk '{print $2}' | sed 's/;//')
        
        echo "Worker 进程数：${WORKER_PROCESSES:-1}"
        echo "Worker 最大连接数：${WORKER_CONNECTIONS:-未配置}"
        
        if [ -n "$WORKER_PROCESSES" ] && [ -n "$WORKER_CONNECTIONS" ]; then
            MAX_NGINX_CONN=$((WORKER_PROCESSES * WORKER_CONNECTIONS))
            echo "Nginx 理论最大并发：$MAX_NGINX_CONN"
        fi
    fi
else
    echo "运行在容器外，跳过 Nginx 配置检查"
fi
echo ""

# 4. 数据库连接检查
echo -e "${YELLOW}[4] 数据库连接配置${NC}"
echo "-----------------------------------"

if is_in_container; then
    # 检查 PostgreSQL
    if command -v psql &> /dev/null; then
        if PGPASSWORD="${DB_PWD}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT 1" &>/dev/null 2>&1; then
            MAX_CONN=$(PGPASSWORD="${DB_PWD}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SHOW max_connections;")
            CURRENT_CONN=$(PGPASSWORD="${DB_PWD}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT count(*) FROM pg_stat_activity;")
            
            echo "数据库类型：PostgreSQL"
            echo "最大连接数：$MAX_CONN"
            echo "当前活跃连接：$CURRENT_CONN"
            
            AVAILABLE_CONN=$((MAX_CONN - CURRENT_CONN - 5))
            echo "可用连接数：$AVAILABLE_CONN"
            
            if [ "$AVAILABLE_CONN" -lt 20 ]; then
                echo -e "${RED}⚠ 警告：可用连接数较少，建议增加 max_connections${NC}"
            fi
        fi
    fi
else
    echo "运行在容器外，跳过数据库检查"
fi
echo ""

# 5. 内存使用情况
echo -e "${YELLOW}[5] 内存使用情况${NC}"
echo "-----------------------------------"

if is_in_container; then
    docker stats --no-stream $(hostname) 2>/dev/null | tail -1 || echo "无法获取容器内存信息"
else
    ps aux | head -1
    ps aux --sort=-%mem | head -6
fi
echo ""

# 6. 当前网络连接数
echo -e "${YELLOW}[6] 当前网络连接状态${NC}"
echo "-----------------------------------"

ESTABLISHED=$(netstat -an 2>/dev/null | grep ESTABLISHED | wc -l || ss -an | grep ESTAB | wc -l)
TIME_WAIT=$(netstat -an 2>/dev/null | grep TIME_WAIT | wc -l || ss -an | grep TIME-WAIT | wc -l)
CLOSE_WAIT=$(netstat -an 2>/dev/null | grep CLOSE_WAIT | wc -l || ss -an | grep CLOSE-WAIT | wc -l)

echo "ESTABLISHED 连接数：$ESTABLISHED"
echo "TIME_WAIT 连接数：$TIME_WAIT"
echo "CLOSE_WAIT 连接数：$CLOSE_WAIT"
echo ""

# 7. 并发能力评估
echo -e "${YELLOW}[7] 并发能力评估${NC}"
echo "-----------------------------------"

# 根据配置计算理论并发上限
if is_in_container; then
    # 计算各个限制因素
    FD_LIMIT=$FD_SOFT
    WORKER_PROC=${WORKER_PROCESSES:-1}
    WORKER_CONN=${WORKER_CONNECTIONS:-$FD_LIMIT}
    
    NGINX_LIMIT=$((WORKER_PROC * WORKER_CONN))
    
    # 从环境变量获取数据库连接数
    DB_MAX_CONN=${DB_MAX_CONNECTIONS:-100}
    
    # 根据内存估算
    MEM_GB=$(free -g | grep Mem | awk '{print $2}')
    ESTIMATED_USERS=$((MEM_GB * 10))  # 每 GB 大约 10 个并发用户
    
    echo "FD 限制并发：$FD_LIMIT"
    echo "Nginx 限制并发：$NGINX_LIMIT"
    echo "数据库限制并发：$DB_MAX_CONN"
    echo "内存估算并发用户：$ESTIMATED_USERS"
    echo ""
    
    # 计算最小值作为真实上限
    REAL_LIMIT=$(echo -e "$FD_LIMIT\n$NGINX_LIMIT\n$DB_MAX_CONN\n$ESTIMATED_USERS" | sort -n | head -1)
    echo -e "${GREEN}理论并发上限（瓶颈）：$REAL_LIMIT${NC}"
else
    echo "运行在容器外，无法进行完整评估"
fi
echo ""

# 8. 性能优化建议
echo -e "${YELLOW}[8] 性能优化建议${NC}"
echo "-----------------------------------"

SUGGESTIONS=()

if is_in_container; then
    # 检查 FD 限制
    if [ "$FD_SOFT" -lt 65536 ]; then
        SUGGESTIONS+=("增加文件描述符限制：ulimit -n 65536")
    fi
    
    # 检查 Worker 进程数
    if [ "${WORKER_PROCESSES:-1}" -lt "$CPU_CORES" ]; then
        SUGGESTIONS+=("增加 Nginx Worker 进程数：NGINX_WORKER_PROCESSES=$CPU_CORES")
    fi
    
    # 检查数据库连接
    if [ "$AVAILABLE_CONN" -lt 20 ]; then
        SUGGESTIONS+=("增加数据库最大连接数：max_connections = 200")
    fi
    
    # 检查内存
    if [ "$MEM_GB" -lt 4 ]; then
        SUGGESTIONS+=("增加服务器内存：当前 ${TOTAL_MEM}，建议至少 4GB")
    elif [ "$MEM_GB" -lt 8 ]; then
        SUGGESTIONS+=("建议增加内存到 8GB 以支持更多并发")
    fi
    
    if [ ${#SUGGESTIONS[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ 系统配置良好，暂无优化建议${NC}"
    else
        for i in "${!SUGGESTIONS[@]}"; do
            echo "$((i+1)). ${SUGGESTIONS[$i]}"
        done
    fi
else
    echo "运行在容器外，请登录容器后运行此脚本"
fi
echo ""

# 9. 快速优化命令参考
echo -e "${YELLOW}[9] 快速优化命令${NC}"
echo "-----------------------------------"
echo "增加文件描述符限制："
echo "  docker run -e NGINX_WORKER_CONNECTIONS=65536 onlyoffice/documentserver"
echo ""
echo "设置 Nginx Worker 进程数："
echo "  docker run -e NGINX_WORKER_PROCESSES=4 onlyoffice/documentserver"
echo ""
echo "增加数据库连接数："
echo "  在 PostgreSQL 配置中设置: max_connections = 200"
echo ""
echo "完整启动命令示例："
echo "  docker run -d -p 80:80 -p 443:443 \\"
echo "    -e NGINX_WORKER_PROCESSES=4 \\"
echo "    -e NGINX_WORKER_CONNECTIONS=32768 \\"
echo "    -e DB_TYPE=postgres \\"
echo "    -e DB_HOST=your-db-host \\"
echo "    -e DB_MAX_CONNECTIONS=200 \\"
echo "    --name documentserver \\"
echo "    onlyoffice/documentserver"
echo ""

# 10. 性能基准测试
echo -e "${YELLOW}[10] 性能基准测试${NC}"
echo "-----------------------------------"

if command -v curl &> /dev/null; then
    echo "测试服务健康状态..."
    if curl -s http://localhost:8000/info/info.json > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 服务健康${NC}"
    else
        echo -e "${RED}✗ 服务不可达${NC}"
    fi
else
    echo "curl 未安装，跳过健康检查"
fi

echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}诊断完成${NC}"
echo -e "${BLUE}================================${NC}"

# 生成诊断报告
echo ""
echo "诊断报告已生成，您可以："
echo "1. 根据上述建议优化系统配置"
echo "2. 进行压力测试验证性能改进"
echo "3. 监控生产环境的实际并发情况"
echo ""
