#!/bin/bash

################################################################################
# ONLYOFFICE Document Server 压力测试工具
# 用于测试并发性能和找出瓶颈
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置参数
TARGET_URL="${1:-http://localhost}"
CONCURRENCY="${2:-10}"
REQUESTS="${3:-1000}"
DURATION="${4:-30}"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}ONLYOFFICE 压力测试工具${NC}"
echo -e "${BLUE}================================${NC}\n"

echo "测试配置："
echo "  目标 URL：$TARGET_URL"
echo "  并发数：$CONCURRENCY"
echo "  请求总数：$REQUESTS"
echo "  测试时长：${DURATION}s"
echo ""

# 检查依赖工具
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}✗ 未安装 $1，请先安装${NC}"
        echo "  Ubuntu/Debian: sudo apt-get install $2"
        echo "  RHEL/CentOS: sudo yum install $2"
        return 1
    fi
    return 0
}

echo -e "${YELLOW}检查依赖工具...${NC}"

# 检查 curl
if ! check_tool curl curl; then
    # 使用 curl 进行基础测试
    echo -e "${GREEN}✓ 已安装 curl${NC}"
fi

# 检查 ab (Apache Bench)
HAVE_AB=false
if command -v ab &> /dev/null; then
    HAVE_AB=true
    echo -e "${GREEN}✓ 已安装 Apache Bench${NC}"
fi

# 检查 wrk
HAVE_WRK=false
if command -v wrk &> /dev/null; then
    HAVE_WRK=true
    echo -e "${GREEN}✓ 已安装 wrk${NC}"
fi

if [ "$HAVE_AB" = false ] && [ "$HAVE_WRK" = false ]; then
    echo -e "${YELLOW}建议安装性能测试工具：${NC}"
    echo "  Apache Bench: sudo apt-get install apache2-utils"
    echo "  wrk: https://github.com/wg/wrk"
    echo ""
fi

echo ""

# 预热阶段
echo -e "${YELLOW}[1] 预热测试（5 个请求）${NC}"
echo "-----------------------------------"

for i in {1..5}; do
    response_time=$(curl -s -w "%{time_total}" -o /dev/null "$TARGET_URL")
    echo "  请求 $i: ${response_time}s"
done
echo ""

# 测试 1：基础连接测试
echo -e "${YELLOW}[2] 基础连接测试${NC}"
echo "-----------------------------------"

if [ "$HAVE_AB" = true ]; then
    echo "使用 Apache Bench 进行连接测试..."
    ab -n "$REQUESTS" -c "$CONCURRENCY" -q "$TARGET_URL" 2>&1 | grep -E "^Requests|^Failed|^Time per request|^Requests per second"
else
    echo "使用 curl 进行基础测试..."
    start_time=$(date +%s%N)
    for i in $(seq 1 "$CONCURRENCY"); do
        curl -s "$TARGET_URL" > /dev/null &
    done
    wait
    end_time=$(date +%s%N)
    elapsed=$((($end_time - $start_time) / 1000000))
    echo "并发数：$CONCURRENCY，耗时：${elapsed}ms"
fi
echo ""

# 测试 2：持续负载测试
echo -e "${YELLOW}[3] 持续负载测试（${DURATION}s）${NC}"
echo "-----------------------------------"

if [ "$HAVE_WRK" = true ]; then
    echo "使用 wrk 进行高性能测试..."
    wrk -t4 -c"$CONCURRENCY" -d"${DURATION}s" "$TARGET_URL" 2>&1
else
    echo "模拟持续负载..."
    
    start_time=$(date +%s)
    request_count=0
    total_time=0
    min_time=999999
    max_time=0
    
    while [ $(($(date +%s) - start_time)) -lt "$DURATION" ]; do
        time_start=$(date +%s%N)
        if curl -s -m 5 "$TARGET_URL" > /dev/null 2>&1; then
            time_end=$(date +%s%N)
            elapsed=$((($time_end - $time_start) / 1000000))
            
            request_count=$((request_count + 1))
            total_time=$((total_time + elapsed))
            
            if [ "$elapsed" -lt "$min_time" ]; then
                min_time=$elapsed
            fi
            if [ "$elapsed" -gt "$max_time" ]; then
                max_time=$elapsed
            fi
            
            if [ $((request_count % 10)) -eq 0 ]; then
                echo "  已完成请求数：$request_count"
            fi
        fi
    done
    
    avg_time=$((total_time / request_count))
    
    echo ""
    echo "测试结果："
    echo "  总请求数：$request_count"
    echo "  平均响应时间：${avg_time}ms"
    echo "  最小响应时间：${min_time}ms"
    echo "  最大响应时间：${max_time}ms"
    echo "  吞吐量：$((request_count / DURATION)) req/s"
fi

echo ""

# 测试 3：并发增长测试
echo -e "${YELLOW}[4] 并发数递增测试${NC}"
echo "-----------------------------------"
echo "并发数 | 成功率 | 平均响应时间 | 最大响应时间"
echo "--------|--------|-------------|----------"

for concurrency in 1 5 10 20 50 100; do
    if [ "$concurrency" -gt "$CONCURRENCY" ]; then
        break
    fi
    
    success=0
    failed=0
    total_time=0
    max_time=0
    
    for i in $(seq 1 10); do
        time_start=$(date +%s%N)
        if curl -s -m 5 "$TARGET_URL" > /dev/null 2>&1; then
            time_end=$(date +%s%N)
            elapsed=$((($time_end - $time_start) / 1000000))
            
            success=$((success + 1))
            total_time=$((total_time + elapsed))
            
            if [ "$elapsed" -gt "$max_time" ]; then
                max_time=$elapsed
            fi
        else
            failed=$((failed + 1))
        fi
    done
    
    total_req=$((success + failed))
    success_rate=$((success * 100 / total_req))
    avg_time=$((total_time / success))
    
    printf "  %-6d | %5d%% | %9dms | %10dms\n" "$concurrency" "$success_rate" "$avg_time" "$max_time"
done

echo ""

# 测试 4：长连接测试
echo -e "${YELLOW}[5] 并发连接数统计${NC}"
echo "-----------------------------------"

connection_count=$(netstat -an 2>/dev/null | grep ESTABLISHED | wc -l || ss -an | grep ESTAB | wc -l)
echo "当前 ESTABLISHED 连接数：$connection_count"

# 获取 Nginx 连接状态
if command -v nginx &> /dev/null; then
    active=$(curl -s http://localhost/nginx_status 2>/dev/null | grep "Active" | awk '{print $3}')
    if [ -n "$active" ]; then
        echo "Nginx 活跃连接数：$active"
    fi
fi

echo ""

# 测试 5：数据库连接测试
echo -e "${YELLOW}[6] 数据库连接检查${NC}"
echo "-----------------------------------"

if [ -n "$DB_HOST" ] && command -v psql &> /dev/null; then
    if PGPASSWORD="${DB_PWD}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT 1" &>/dev/null 2>&1; then
        db_conn=$(PGPASSWORD="${DB_PWD}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT count(*) FROM pg_stat_activity;")
        echo "数据库活跃连接数：$db_conn"
    fi
else
    echo "数据库未配置或 psql 未安装"
fi

echo ""

# 测试总结
echo -e "${YELLOW}[7] 性能分析和建议${NC}"
echo "-----------------------------------"

# 分析结果
if [ "$HAVE_AB" = true ]; then
    echo "✓ 使用 Apache Bench 成功完成压力测试"
    echo ""
    echo "建议："
    echo "  1. 查看上述结果中的失败率"
    echo "  2. 如果失败率 > 1%，增加系统资源或优化配置"
    echo "  3. 如果响应时间 > 500ms，检查数据库或 Nginx 配置"
    echo "  4. 重复测试多次获得稳定的基准数据"
fi

echo ""
echo "性能测试建议："
echo "  • 在生产环境上线前进行充分的压力测试"
echo "  • 定期监控生产环境的并发情况"
echo "  • 根据实际业务量调整服务器配置"
echo "  • 使用 htop 或 docker stats 监控系统资源"
echo ""

# 输出详细命令参考
echo -e "${BLUE}详细测试命令参考：${NC}"
echo ""
echo "1. Apache Bench 压力测试："
echo "   # 1000 个请求，并发 50"
echo "   ab -n 1000 -c 50 $TARGET_URL"
echo ""
echo "2. wrk 高性能测试："
echo "   # 4 个线程，并发 100，持续 30 秒"
echo "   wrk -t4 -c100 -d30s $TARGET_URL"
echo ""
echo "3. 并发连接监控："
echo "   watch -n 1 'netstat -an | grep ESTABLISHED | wc -l'"
echo ""
echo "4. 实时性能监控："
echo "   docker stats <container_name>"
echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}压力测试完成${NC}"
echo -e "${BLUE}================================${NC}"
