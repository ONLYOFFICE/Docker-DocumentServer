#!/bin/bash

# 🚀 ONLYOFFICE Document Server 企业级监控快速部署脚本
# 一键启动所有监控服务

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件..."
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        exit 1
    fi
    log_success "Docker 已安装"
    
    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装"
        exit 1
    fi
    log_success "Docker Compose 已安装"
    
    # 检查必要的文件
    required_files=(
        "docker-compose-monitoring.yml"
        "prometheus.yml"
        "alert_rules.yml"
        "grafana-dashboard.json"
        "alertmanager.yml"
        "logstash.conf"
        "enterprise-monitoring.sh"
        "enterprise-logging.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "缺少文件: $file"
            exit 1
        fi
    done
    log_success "所有必要文件已找到"
}

# 检查端口可用性
check_ports() {
    log_info "检查端口可用性..."
    
    ports=(80 443 9090 3000 9093 5601 5672 15672 6379 5432)
    
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log_warning "端口 $port 已被占用"
        fi
    done
    log_success "端口检查完成"
}

# 创建必要的目录
setup_directories() {
    log_info "创建必要的目录..."
    
    mkdir -p /var/lib/onlyoffice/monitoring
    mkdir -p /var/log/onlyoffice
    mkdir -p /etc/onlyoffice/prometheus
    
    chmod 755 /var/lib/onlyoffice/monitoring
    chmod 755 /var/log/onlyoffice
    
    log_success "目录创建完成"
}

# 启动 Docker Compose 服务
start_services() {
    log_info "启动 Docker Compose 服务..."
    
    docker-compose -f docker-compose-monitoring.yml up -d
    
    log_success "Docker Compose 服务已启动"
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务就绪..."
    
    # 等待 Prometheus
    log_info "等待 Prometheus..."
    for i in {1..30}; do
        if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
            log_success "Prometheus 已就绪"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Prometheus 启动超时"
            return 1
        fi
        sleep 1
    done
    
    # 等待 Grafana
    log_info "等待 Grafana..."
    for i in {1..30}; do
        if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
            log_success "Grafana 已就绪"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Grafana 启动超时"
            return 1
        fi
        sleep 1
    done
    
    # 等待 Elasticsearch
    log_info "等待 Elasticsearch..."
    for i in {1..30}; do
        if curl -s http://localhost:9200 > /dev/null 2>&1; then
            log_success "Elasticsearch 已就绪"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Elasticsearch 启动超时"
            return 1
        fi
        sleep 1
    done
    
    log_success "所有服务已就绪"
}

# 配置 Grafana 数据源
setup_grafana() {
    log_info "配置 Grafana 数据源..."
    
    # 创建 Prometheus 数据源
    curl -s -X POST http://admin:admin123@localhost:3000/api/datasources \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Prometheus",
            "type": "prometheus",
            "url": "http://prometheus:9090",
            "access": "proxy",
            "isDefault": true
        }' > /dev/null
    
    log_success "Grafana 数据源已配置"
}

# 初始化监控系统
setup_monitoring() {
    log_info "初始化监控系统..."
    
    # 启动监控脚本
    docker exec documentserver bash -c '/app/ds/enterprise-monitoring.sh endpoint' > /dev/null 2>&1 || true
    docker exec documentserver bash -c '/app/ds/enterprise-monitoring.sh start' > /dev/null 2>&1 || true
    
    log_success "监控系统已初始化"
}

# 初始化日志系统
setup_logging() {
    log_info "初始化日志系统..."
    
    docker exec documentserver bash -c '/app/ds/enterprise-logging.sh init' > /dev/null 2>&1 || true
    
    log_success "日志系统已初始化"
}

# 显示服务状态
show_status() {
    log_info "服务状态概览"
    echo ""
    
    docker-compose -f docker-compose-monitoring.yml ps
    
    echo ""
}

# 显示访问信息
show_urls() {
    log_info "服务访问地址"
    echo ""
    echo "  📄 ONLYOFFICE Document Server"
    echo "     ${BLUE}http://localhost${NC}"
    echo ""
    echo "  📊 Prometheus (指标和查询)"
    echo "     ${BLUE}http://localhost:9090${NC}"
    echo ""
    echo "  📈 Grafana (仪表板和可视化)"
    echo "     ${BLUE}http://localhost:3000${NC}"
    echo "     用户名: ${YELLOW}admin${NC}"
    echo "     密码: ${YELLOW}admin123${NC}"
    echo ""
    echo "  🔔 Alertmanager (告警管理)"
    echo "     ${BLUE}http://localhost:9093${NC}"
    echo ""
    echo "  📋 Kibana (日志查询)"
    echo "     ${BLUE}http://localhost:5601${NC}"
    echo ""
    echo "  🐰 RabbitMQ 管理"
    echo "     ${BLUE}http://localhost:15672${NC}"
    echo "     用户名: ${YELLOW}guest${NC}"
    echo "     密码: ${YELLOW}guest${NC}"
    echo ""
}

# 显示常用命令
show_commands() {
    log_info "常用命令"
    echo ""
    echo "  查看日志:"
    echo "    ${YELLOW}docker logs documentserver${NC}"
    echo ""
    echo "  查看监控指标:"
    echo "    ${YELLOW}curl http://localhost:9090/metrics${NC}"
    echo ""
    echo "  查询审计日志:"
    echo "    ${YELLOW}docker exec documentserver /app/ds/enterprise-logging.sh query audit | tail -10${NC}"
    echo ""
    echo "  停止所有服务:"
    echo "    ${YELLOW}docker-compose -f docker-compose-monitoring.yml down${NC}"
    echo ""
    echo "  查看容器资源使用:"
    echo "    ${YELLOW}docker stats${NC}"
    echo ""
    echo "  重新启动特定服务:"
    echo "    ${YELLOW}docker-compose -f docker-compose-monitoring.yml restart documentserver${NC}"
    echo ""
}

# 主程序
main() {
    echo ""
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║   ONLYOFFICE Document Server 企业级监控快速部署             ║"
    echo "║   版本: 1.0                                               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    log_info "开始部署流程..."
    echo ""
    
    check_prerequisites
    echo ""
    
    check_ports
    echo ""
    
    setup_directories
    echo ""
    
    start_services
    echo ""
    
    wait_for_services
    echo ""
    
    setup_grafana
    echo ""
    
    setup_monitoring
    echo ""
    
    setup_logging
    echo ""
    
    show_status
    echo ""
    
    show_urls
    echo ""
    
    show_commands
    echo ""
    
    log_success "部署完成！🎉"
    echo ""
    echo -e "${GREEN}所有服务已启动并就绪！${NC}"
    echo ""
}

# 处理脚本参数
case "${1:-}" in
    stop)
        log_info "停止所有服务..."
        docker-compose -f docker-compose-monitoring.yml down
        log_success "所有服务已停止"
        ;;
    restart)
        log_info "重启所有服务..."
        docker-compose -f docker-compose-monitoring.yml restart
        log_success "所有服务已重启"
        ;;
    status)
        show_status
        ;;
    logs)
        docker-compose -f docker-compose-monitoring.yml logs -f
        ;;
    *)
        main
        ;;
esac
