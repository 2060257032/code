
#!/bin/bash

# 云测试平台项目优化脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║               项目优化工具                          ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 优化Python代码
optimize_python_code() {
    echo -e "${YELLOW}[1/5] 优化Python代码...${NC}"
    
    # 检查并安装优化工具
    if ! pip3 list | grep -q "black"; then
        echo -e "  安装代码格式化工具..."
        pip3 install black pylint autopep8
    fi
    
    # 格式化代码
    if command -v black &> /dev/null; then
        echo -e "  格式化Python代码..."
        black ../app/*.py --line-length 79 2>/dev/null || true
    fi
    
    # 检查代码规范
    if command -v pylint &> /dev/null; then
        echo -e "  检查代码规范..."
        pylint ../app/*.py --rcfile=/dev/null 2>/dev/null | tail -20 || true
    fi
    
    echo -e "  ${GREEN}✓ Python代码优化完成${NC}"
}

# 优化脚本文件
optimize_shell_scripts() {
    echo -e "${YELLOW}[2/5] 优化Shell脚本...${NC}"
    
    # 检查脚本语法
    echo -e "  检查脚本语法..."
    for script in ../scripts/*.sh; do
        if [ -f "$script" ]; then
            if bash -n "$script" 2>/dev/null; then
                echo -e "    ${GREEN}✓ $(basename $script) 语法正确${NC}"
            else
                echo -e "    ${RED}✗ $(basename $script) 语法错误${NC}"
            fi
        fi
    done
    
    # 添加shebang
    echo -e "  添加脚本头..."
    for script in ../scripts/*.sh; do
        if [ -f "$script" ] && ! head -1 "$script" | grep -q "^#!/bin/bash"; then
            sed -i '1i#!/bin/bash' "$script"
        fi
    done
    
    echo -e "  ${GREEN}✓ Shell脚本优化完成${NC}"
}

# 优化项目结构
optimize_project_structure() {
    echo -e "${YELLOW}[3/5] 优化项目结构...${NC}"
    
    # 创建必要的目录
    echo -e "  创建标准目录..."
    mkdir -p ../config
    mkdir -p ../data/backups
    mkdir -p ../docs/images
    
    # 移动配置文件
    echo -e "  整理配置文件..."
    if [ -f ../.env ]; then
        mv ../.env ../config/
        echo -e "    ${GREEN}✓ 移动 .env 到 config/ 目录${NC}"
    fi
    
    # 创建.gitignore
    echo -e "  创建.gitignore文件..."
    if [ ! -f ../.gitignore ]; then
        cat > ../.gitignore << 'GITIGNOREEOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/

# Logs
logs/
*.log

# Data
data/
*.db
*.sqlite3

# Temporary files
tmp/
*.tmp
*.temp

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Build
dist/
build/
*.egg-info/

# Docker
*.tar.gz
*.zip
GITIGNOREEOF
        echo -e "    ${GREEN}✓ .gitignore 创建完成${NC}"
    fi
    
    echo -e "  ${GREEN}✓ 项目结构优化完成${NC}"
}

# 优化性能
optimize_performance() {
    echo -e "${YELLOW}[4/5] 优化性能配置...${NC}"
    
    # Redis配置优化
    echo -e "  优化Redis配置..."
    if [ -f /etc/redis/redis.conf ]; then
        sudo sed -i 's/^# maxmemory .*/maxmemory 256mb/' /etc/redis/redis.conf 2>/dev/null || true
        sudo sed -i 's/^# maxmemory-policy .*/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf 2>/dev/null || true
        sudo systemctl restart redis 2>/dev/null || true
    fi
    
    # 优化Flask配置
    echo -e "  优化Flask配置..."
    if [ -f ../app/app.py ]; then
        # 检查是否已启用生产配置
        if ! grep -q "debug=False" ../app/app.py; then
            echo -e "    ${YELLOW}提示: 生产环境请设置 debug=False${NC}"
        fi
    fi
    
    # 创建性能配置文件
    cat > ../config/performance.conf << 'PERFEOF'
# 性能优化配置
[application]
workers=4
threads=2
timeout=30

[redis]
max_connections=100
timeout=5

[logging]
level=INFO
max_size=10MB
backup_count=5
PERFEOF
    
    echo -e "  ${GREEN}✓ 性能优化完成${NC}"
}

# 生成项目报告
generate_project_report() {
    echo -e "${YELLOW}[5/5] 生成项目报告...${NC}"
    
    local report_file="../docs/project_report.md"
    
    cat > "$report_file" << 'REPORTEOF'
# 云测试平台项目报告

## 项目概述
- **项目名称**: 基于KVM与Docker的CI/CD自动化测试平台
- **版本**: 1.0.0
- **生成时间**: __TIMESTAMP__

## 项目结构

## 代码统计
__CODE_STATS__

## 功能特性
__FEATURES__

## 性能指标
__PERFORMANCE__

## 优化建议
__SUGGESTIONS__
REPORTEOF
    
    # 收集信息
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local project_tree=$(find ../ -type f -name "*.py" -o -name "*.sh" -o -name "*.md" | head -20 | sed 's/\.\.\///g' | sed 's/^/    /')
    local code_stats=$(find ../ -name "*.py" -exec wc -l {} + | tail -1 | awk '{print "Python代码行数: " $1}')
    local features=$(grep -h "def " ../app/*.py | wc -l)
    local suggestions=""
    
    # 替换占位符
    sed -i "s/__TIMESTAMP__/$timestamp/g" "$report_file"
    sed -i "s/__PROJECT_TREE__/$project_tree/g" "$report_file"
    sed -i "s/__CODE_STATS__/$code_stats/g" "$report_file"
    sed -i "s/__FEATURES__/API接口数量: $features/g" "$report_file"
    
    # 添加优化建议
    if ! grep -q "debug=False" ../app/app.py 2>/dev/null; then
        suggestions+="- 生产环境建议设置 debug=False\n"
    fi
    
    if [ ! -f "../tests/__init__.py" ]; then
        suggestions+="- 建议添加测试包初始化文件\n"
    fi
    
    if [ -z "$suggestions" ]; then
        suggestions="暂无优化建议，项目结构良好"
    fi
    
    sed -i "s/__SUGGESTIONS__/$suggestions/g" "$report_file"
    
    echo -e "  ${GREEN}✓ 项目报告生成完成: $report_file${NC}"
}

# 显示优化结果
show_optimization_result() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                   优化完成！                        ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${BLUE}✅ 完成的优化:${NC}"
    echo "  1. Python代码格式化与规范检查"
    echo "  2. Shell脚本语法检查与标准化"
    echo "  3. 项目目录结构整理"
    echo "  4. 性能配置优化"
    echo "  5. 项目报告生成"
    echo ""
    
    echo -e "${BLUE}📁 生成的文件:${NC}"
    echo "  • docs/project_report.md - 项目详细报告"
    echo "  • config/performance.conf - 性能配置文件"
    echo "  • .gitignore - Git忽略文件"
    echo ""
    
    echo -e "${YELLOW}💡 下一步建议:${NC}"
    echo "  • 运行测试套件: ./test_suite/integration_test.sh"
    echo "  • 打包项目: ./packaging/build_package.sh"
    echo "  • 部署到生产环境"
    echo ""
}

# 主优化流程
main() {
    show_banner
    
    # 执行优化步骤
    optimize_python_code
    optimize_shell_scripts
    optimize_project_structure
    optimize_performance
    generate_project_report
    
    # 显示结果
    show_optimization_result
}

main "$@"
