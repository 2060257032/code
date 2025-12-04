
#!/bin/bash

# 云测试平台集成测试脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 测试记录
test_pass() {
    echo -e "  ${GREEN}✓ $1${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

test_fail() {
    echo -e "  ${RED}✗ $1${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# 显示测试横幅
show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║             集成测试套件 v1.0                       ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 测试1：环境检查
test_environment() {
    echo -e "${YELLOW}[测试1] 环境检查${NC}"
    
    # 检查Python
    if command -v python3 &> /dev/null; then
        test_pass "Python3 已安装 ($(python3 --version))"
    else
        test_fail "Python3 未安装"
    fi
    
    # 检查pip
    if command -v pip3 &> /dev/null; then
        test_pass "pip3 已安装 ($(pip3 --version | cut -d' ' -f2))"
    else
        test_fail "pip3 未安装"
    fi
    
    # 检查Redis
    if command -v redis-cli &> /dev/null; then
        test_pass "Redis 已安装 ($(redis-cli --version | cut -d' ' -f2))"
    else
        test_fail "Redis 未安装"
    fi
    
    echo ""
}

# 测试2：项目结构
test_project_structure() {
    echo -e "${YELLOW}[测试2] 项目结构检查${NC}"
    
    local required_files=(
        "app/app.py"
        "app/requirements.txt"
        "scripts/deploy.sh"
        "scripts/stop.sh"
        "scripts/status.sh"
        "README.md"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "../$file" ]; then
            test_pass "文件存在: $file"
        else
            test_fail "文件缺失: $file"
        fi
    done
    
    local required_dirs=(
        "app"
        "scripts"
        "tests"
        "logs"
        "tmp"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "../$dir" ]; then
            test_pass "目录存在: $dir"
        else
            test_fail "目录缺失: $dir"
        fi
    done
    
    echo ""
}

# 测试3：Python依赖
test_python_dependencies() {
    echo -e "${YELLOW}[测试3] Python依赖检查${NC}"
    
    if [ -f "../app/requirements.txt" ]; then
        # 检查主要依赖
        local required_packages=(
            "Flask"
            "redis"
            "Werkzeug"
        )
        
        for pkg in "${required_packages[@]}"; do
            if pip3 list | grep -q "$pkg"; then
                version=$(pip3 list | grep "$pkg" | awk '{print $2}')
                test_pass "$pkg 已安装 ($version)"
            else
                test_fail "$pkg 未安装"
            fi
        done
    else
        test_fail "requirements.txt 不存在"
    fi
    
    echo ""
}

# 测试4：服务功能
test_services() {
    echo -e "${YELLOW}[测试4] 服务功能测试${NC}"
    
    # 启动服务（如果未运行）
    if ! pgrep -f "python3.*app.py" > /dev/null; then
        echo -e "  启动应用服务..."
        cd ../app
        nohup python3 app.py > ../logs/test.log 2>&1 &
        APP_PID=$!
        sleep 5
        cd ../test_suite
    else
        APP_PID=$(pgrep -f "python3.*app.py" | head -1)
    fi
    
    # 测试API端点
    local endpoints=(
        "/"
        "/api/visitors"
        "/health"
        "/api/stats"
        "/dashboard"
    )
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s --max-time 5 "http://localhost:5000$endpoint" > /dev/null; then
            test_pass "端点可访问: $endpoint"
        else
            test_fail "端点不可访问: $endpoint"
        fi
    done
    
    # 测试具体功能
    echo -e "  测试具体功能..."
    
    # 测试首页
    if curl -s http://localhost:5000/ | grep -q "Hello"; then
        test_pass "首页功能正常"
    else
        test_fail "首页功能异常"
    fi
    
    # 测试API返回JSON
    if curl -s http://localhost:5000/api/visitors | python3 -m json.tool > /dev/null 2>&1; then
        test_pass "API返回有效JSON"
    else
        test_fail "API返回无效JSON"
    fi
    
    # 测试健康检查
    if curl -s http://localhost:5000/health | grep -q '"status"'; then
        test_pass "健康检查正常"
    else
        test_fail "健康检查异常"
    fi
    
    # 停止测试服务
    if [ -n "$APP_PID" ]; then
        kill $APP_PID 2>/dev/null || true
    fi
    
    echo ""
}

# 测试5：管理脚本
test_management_scripts() {
    echo -e "${YELLOW}[测试5] 管理脚本测试${NC}"
    
    local scripts=(
        "../scripts/deploy.sh"
        "../scripts/stop.sh"
        "../scripts/status.sh"
        "../scripts/restart.sh"
        "../scripts/logs.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            # 检查脚本语法
            if bash -n "$script" 2>/dev/null; then
                test_pass "脚本语法正确: $(basename $script)"
            else
                test_fail "脚本语法错误: $(basename $script)"
            fi
            
            # 检查执行权限
            if [ -x "$script" ]; then
                test_pass "脚本有执行权限: $(basename $script)"
            else
                test_fail "脚本无执行权限: $(basename $script)"
            fi
        else
            test_fail "脚本不存在: $(basename $script)"
        fi
    done
    
    echo ""
}

# 测试6：性能测试
test_performance() {
    echo -e "${YELLOW}[测试6] 性能测试${NC}"
    
    # 启动服务
    echo -e "  启动服务进行性能测试..."
    cd ../app
    nohup python3 app.py > ../logs/performance.log 2>&1 &
    APP_PID=$!
    sleep 5
    cd ../test_suite
    
    # 测试响应时间
    echo -e "  测试API响应时间..."
    
    local start_time=$(date +%s%3N)
    curl -s http://localhost:5000/health > /dev/null
    local end_time=$(date +%s%3N)
    local response_time=$((end_time - start_time))
    
    if [ $response_time -lt 1000 ]; then
        test_pass "响应时间正常: ${response_time}ms"
    else
        test_fail "响应时间较慢: ${response_time}ms"
    fi
    
    # 测试并发能力（简单版）
    echo -e "  测试并发能力..."
    local success_count=0
    for i in {1..10}; do
        if curl -s --max-time 2 http://localhost:5000/api/visitors > /dev/null; then
            success_count=$((success_count + 1))
        fi
    done
    
    if [ $success_count -ge 8 ]; then
        test_pass "并发测试通过: $success_count/10 成功"
    else
        test_fail "并发测试失败: $success_count/10 成功"
    fi
    
    # 停止服务
    kill $APP_PID 2>/dev/null || true
    
    echo ""
}

# 显示测试结果
show_results() {
    echo -e "${CYAN}"
    echo "══════════════════════════════════════════════════════"
    echo "                    测试结果                         "
    echo "══════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    echo ""
    echo -e "${BLUE}📊 测试统计:${NC}"
    echo "  总测试数: $TOTAL_TESTS"
    echo "  通过: $PASSED_TESTS"
    echo "  失败: $FAILED_TESTS"
    
    local pass_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    
    echo "  通过率: ${pass_rate}%"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}"
        echo "╔══════════════════════════════════════════════════════╗"
        echo "║            🎉 所有测试通过！ 🎉                     ║"
        echo "╚══════════════════════════════════════════════════════╝"
        echo -e "${NC}"
    else
        echo -e "${YELLOW}"
        echo "╔══════════════════════════════════════════════════════╗"
        echo "║            ⚠️  发现 $FAILED_TESTS 个问题 ⚠️           ║"
        echo "╚══════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo -e "${RED}建议: 请检查失败的测试项并进行修复${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
}

# 主测试流程
main() {
    show_banner
    
    # 运行所有测试
    test_environment
    test_project_structure
    test_python_dependencies
    test_services
    test_management_scripts
    test_performance
    
    # 显示结果
    show_results
}

main "$@"

