
#!/bin/bash

# 云测试平台性能监控脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 监控配置
MONITOR_INTERVAL=2  # 监控间隔（秒）
LOG_FILE="../logs/performance.log"
MAX_LOG_SIZE=10485760  # 10MB

# 清理旧日志
cleanup_log() {
    if [ -f "$LOG_FILE" ]; then
        local size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE")
        if [ $size -gt $MAX_LOG_SIZE ]; then
            echo "$(date) - 日志文件过大，清空" > "$LOG_FILE"
        fi
    fi
}

# 收集系统指标
collect_system_metrics() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # CPU使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    # 内存使用
    local mem_total=$(free -m | awk '/^Mem:/ {print $2}')
    local mem_used=$(free -m | awk '/^Mem:/ {print $3}')
    local mem_percent=$((mem_used * 100 / mem_total))
    
    # 磁盘使用
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    echo "$timestamp,SYSTEM,CPU=$cpu_usage%,MEM=$mem_percent%,DISK=$disk_usage%"
}

# 收集应用指标
collect_application_metrics() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 检查应用是否运行
    if ! pgrep -f "python3.*app.py" > /dev/null; then
        echo "$timestamp,APPLICATION,STATUS=stopped"
        return
    fi
    
    local app_pid=$(pgrep -f "python3.*app.py" | head -1)
    
    # 获取应用内存使用
    local app_mem=$(ps -p $app_pid -o rss= 2>/dev/null || echo "0")
    app_mem=$((app_mem / 1024))  # 转换为MB
    
    # 获取应用CPU使用
    local app_cpu=$(ps -p $app_pid -o %cpu= 2>/dev/null || echo "0")
    
    # 测试响应时间
    local start_time=$(date +%s%3N)
    if curl -s --max-time 2 http://localhost:5000/health > /dev/null; then
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        local status="running"
    else
        local response_time="timeout"
        local status="unresponsive"
    fi
    
    # 获取访问计数
    local visit_count="N/A"
    if [ "$status" = "running" ]; then
        visit_count=$(curl -s http://localhost:5000/api/visitors 2>/dev/null | grep -o '"visitor_count":[0-9]*' | cut -d: -f2 || echo "N/A")
    fi
    
    echo "$timestamp,APPLICATION,STATUS=$status,CPU=$app_cpu%,MEM=${app_mem}MB,RESPONSE=${response_time}ms,VISITS=$visit_count"
}

# 收集Redis指标
collect_redis_metrics() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if ! systemctl is-active --quiet redis; then
        echo "$timestamp,REDIS,STATUS=stopped"
        return
    fi
    
    # 获取Redis内存使用
    local redis_mem=$(redis-cli info memory 2>/dev/null | grep "used_memory_human" | cut -d: -f2 | tr -d '\r' || echo "0")
    
    # 获取Redis连接数
    local redis_conn=$(redis-cli info clients 2>/dev/null | grep "connected_clients" | cut -d: -f2 | tr -d '\r' || echo "0")
    
    # 获取Redis命中率
    local redis_hits=$(redis-cli info stats 2>/dev/null | grep "keyspace_hits" | cut -d: -f2 | tr -d '\r' || echo "0")
    local redis_misses=$(redis-cli info stats 2>/dev/null | grep "keyspace_misses" | cut -d: -f2 | tr -d '\r' || echo "0")
    
    local hit_rate="N/A"
    if [ "$redis_hits" -gt 0 ] && [ "$redis_misses" -gt 0 ]; then
        local total=$((redis_hits + redis_misses))
        hit_rate=$((redis_hits * 100 / total))
    fi
    
    echo "$timestamp,REDIS,STATUS=running,MEM=$redis_mem,CONNECTIONS=$redis_conn,HIT_RATE=${hit_rate}%"
}

# 显示实时监控面板
show_monitor_dashboard() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║           云测试平台 - 性能监控面板                 ║"
    echo "║            按 Ctrl+C 退出监控                       ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 显示当前时间
    echo -e "${BLUE}🕒 监控时间:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${BLUE}📊 监控间隔:${NC} 每 ${MONITOR_INTERVAL} 秒刷新"
    echo ""
}

# 显示指标（带颜色）
display_metric() {
    local metric_type=$1
    local metric_value=$2
    local warning_threshold=$3
    local critical_threshold=$4
    
    if [[ "$metric_value" =~ ^[0-9]+$ ]]; then
        if [ "$metric_value" -ge "$critical_threshold" ]; then
            echo -e "${RED}$metric_type: $metric_value${NC}"
        elif [ "$metric_value" -ge "$warning_threshold" ]; then
            echo -e "${YELLOW}$metric_type: $metric_value${NC}"
        else
            echo -e "${GREEN}$metric_type: $metric_value${NC}"
        fi
    else
        echo -e "${BLUE}$metric_type: $metric_value${NC}"
    fi
}

# 主监控循环
monitor_loop() {
    while true; do
        # 收集所有指标
        local system_metrics=$(collect_system_metrics)
        local app_metrics=$(collect_application_metrics)
        local redis_metrics=$(collect_redis_metrics)
        
        # 保存到日志
        echo "$system_metrics" >> "$LOG_FILE"
        echo "$app_metrics" >> "$LOG_FILE"
        echo "$redis_metrics" >> "$LOG_FILE"
        
        # 解析指标
        local cpu_usage=$(echo "$system_metrics" | grep -o 'CPU=[0-9.]*' | cut -d= -f2)
        local mem_percent=$(echo "$system_metrics" | grep -o 'MEM=[0-9.]*' | cut -d= -f2)
        local app_status=$(echo "$app_metrics" | grep -o 'STATUS=[a-z]*' | cut -d= -f2)
        local response_time=$(echo "$app_metrics" | grep -o 'RESPONSE=[0-9]*' | cut -d= -f2)
        local visits=$(echo "$app_metrics" | grep -o 'VISITS=[0-9]*' | cut -d= -f2)
        local redis_status=$(echo "$redis_metrics" | grep -o 'STATUS=[a-z]*' | cut -d= -f2)
        local redis_conn=$(echo "$redis_metrics" | grep -o 'CONNECTIONS=[0-9]*' | cut -d= -f2)
        
        # 显示监控面板
        show_monitor_dashboard
        
        # 显示系统指标
        echo -e "${YELLOW}[系统资源]${NC}"
        display_metric "CPU使用率" "$cpu_usage" 70 90
        display_metric "内存使用率" "$mem_percent" 75 90
        echo ""
        
        # 显示应用指标
        echo -e "${YELLOW}[应用状态]${NC}"
        if [ "$app_status" = "running" ]; then
            echo -e "${GREEN}状态: 运行中${NC}"
            display_metric "响应时间" "$response_time" 500 1000
            echo -e "${CYAN}访问计数: $visits${NC}"
        elif [ "$app_status" = "unresponsive" ]; then
            echo -e "${RED}状态: 无响应${NC}"
        else
            echo -e "${RED}状态: 停止${NC}"
        fi
        echo ""
        
        # 显示Redis指标
        echo -e "${YELLOW}[Redis状态]${NC}"
        if [ "$redis_status" = "running" ]; then
            echo -e "${GREEN}状态: 运行中${NC}"
            echo -e "${BLUE}连接数: $redis_conn${NC}"
        else
            echo -e "${RED}状态: 停止${NC}"
        fi
        echo ""
        
        # 显示提示
        echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}📈 监控日志:${NC} $LOG_FILE"
        echo -e "${BLUE}🔄 下次刷新:${NC} ${MONITOR_INTERVAL} 秒后"
        
        # 等待
        sleep $MONITOR_INTERVAL
    done
}

# 启动监控
main() {
    # 创建日志目录
    mkdir -p ../logs
    
    # 清理旧日志
    cleanup_log
    
    # 开始监控
    echo -e "${GREEN}开始性能监控...${NC}"
    echo -e "${YELLOW}按 Ctrl+C 停止监控${NC}"
    echo ""
    
    monitor_loop
}

# 捕获Ctrl+C
trap 'echo -e "\n${YELLOW}监控已停止${NC}"; exit 0' INT

main "$@"


chmod +x performance_monitor.sh
