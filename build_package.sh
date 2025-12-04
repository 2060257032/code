
#!/bin/bash

# ============================================
# 云测试平台项目打包脚本
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 加载版本信息
source VERSION
FULL_VERSION="${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}"
PACKAGE_NAME="${PROJECT_NAME}-v${FULL_VERSION}-${BUILD_DATE}"
PACKAGE_DIR="../dist/${PACKAGE_NAME}"

# 显示横幅
show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║           项目打包系统 v${FULL_VERSION}                 ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 清理旧的打包文件
clean_old_packages() {
    echo -e "${BLUE}[1/6] 清理旧的打包文件...${NC}"
    
    if [ -d "../dist" ]; then
        echo -e "  删除旧的dist目录..."
        rm -rf ../dist
    fi
    
    mkdir -p ../dist
    echo -e "  ${GREEN}✓ 清理完成${NC}"
}

# 创建打包目录结构
create_package_structure() {
    echo -e "${BLUE}[2/6] 创建打包目录结构...${NC}"
    
    # 创建主目录
    mkdir -p "$PACKAGE_DIR"
    
    # 创建标准目录结构
    mkdir -p "$PACKAGE_DIR/app"
    mkdir -p "$PACKAGE_DIR/tests"
    mkdir -p "$PACKAGE_DIR/scripts"
    mkdir -p "$PACKAGE_DIR/docs"
    mkdir -p "$PACKAGE_DIR/config"
    mkdir -p "$PACKAGE_DIR/logs"
    mkdir -p "$PACKAGE_DIR/data"
    
    echo -e "  ${GREEN}✓ 目录结构创建完成${NC}"
}

# 复制项目文件
copy_project_files() {
    echo -e "${BLUE}[3/6] 复制项目文件...${NC}"
    
    # 复制应用代码
    echo -e "  复制应用代码..."
    cp -r ../app/* "$PACKAGE_DIR/app/" 2>/dev/null || true
    
    # 复制测试代码
    echo -e "  复制测试代码..."
    cp -r ../tests/* "$PACKAGE_DIR/tests/" 2>/dev/null || true
    
    # 复制脚本（排除打包脚本本身）
    echo -e "  复制管理脚本..."
    find ../scripts -name "*.sh" -exec cp {} "$PACKAGE_DIR/scripts/" \; 2>/dev/null || true
    
    # 复制文档
    echo -e "  复制项目文档..."
    cp ../README.md "$PACKAGE_DIR/"
    cp ../docs/* "$PACKAGE_DIR/docs/" 2>/dev/null || true
    
    # 复制配置文件
    echo -e "  复制配置文件..."
    cp ../.env "$PACKAGE_DIR/config/" 2>/dev/null || true
    cp ../requirements.txt "$PACKAGE_DIR/" 2>/dev/null || true
    
    echo -e "  ${GREEN}✓ 文件复制完成${NC}"
}

# 生成安装脚本
generate_install_script() {
    echo -e "${BLUE}[4/6] 生成安装脚本...${NC}"
    
    cat > "$PACKAGE_DIR/install.sh" << 'INSTEOF'
#!/bin/bash

# 云测试平台安装脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║           云测试平台安装程序                        ║"
    echo "║                版本: __VERSION__                     ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 显示许可协议
show_license() {
    echo -e "${YELLOW}"
    echo "软件许可协议"
    echo "============"
    echo ""
    echo "1. 本软件仅供学习和研究使用"
    echo "2. 禁止用于商业用途"
    echo "3. 作者不对使用本软件造成的任何损失负责"
    echo "4. 安装即表示同意以上条款"
    echo -e "${NC}"
    echo ""
    
    read -p "是否同意许可协议？ (y/N): " -r agree
    if [[ ! "$agree" =~ ^[Yy]$ ]]; then
        echo -e "${RED}安装取消${NC}"
        exit 1
    fi
}

# 选择安装目录
select_install_dir() {
    echo ""
    echo -e "${BLUE}选择安装目录:${NC}"
    echo "1. 当前目录 ($(pwd))"
    echo "2. /opt/cloud-test-platform"
    echo "3. 自定义目录"
    echo ""
    
    read -p "请选择 (1-3): " -r choice
    
    case $choice in
        1)
            INSTALL_DIR="$(pwd)"
            ;;
        2)
            INSTALL_DIR="/opt/cloud-test-platform"
            sudo mkdir -p "$INSTALL_DIR"
            ;;
        3)
            read -p "请输入自定义目录路径: " -r custom_dir
            INSTALL_DIR="$custom_dir"
            mkdir -p "$INSTALL_DIR"
            ;;
        *)
            echo -e "${RED}无效选择，使用当前目录${NC}"
            INSTALL_DIR="$(pwd)"
            ;;
    esac
    
    echo -e "${GREEN}安装目录: ${INSTALL_DIR}${NC}"
}

# 检查系统要求
check_system_requirements() {
    echo ""
    echo -e "${BLUE}检查系统要求...${NC}"
    
    # 检查Python
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}错误: Python3 未安装${NC}"
        echo "请先安装 Python3: sudo apt install python3"
        exit 1
    fi
    
    # 检查pip
    if ! command -v pip3 &> /dev/null; then
        echo -e "${YELLOW}警告: pip3 未安装，尝试安装...${NC}"
        sudo apt install -y python3-pip
    fi
    
    # 检查Redis
    if ! command -v redis-cli &> /dev/null; then
        echo -e "${YELLOW}Redis 未安装，将在安装过程中安装${NC}"
    fi
    
    echo -e "${GREEN}✓ 系统检查通过${NC}"
}

# 执行安装
perform_installation() {
    echo ""
    echo -e "${BLUE}开始安装...${NC}"
    
    # 复制文件
    echo -e "  复制文件到 ${INSTALL_DIR}..."
    cp -r ./* "$INSTALL_DIR/"
    cd "$INSTALL_DIR"
    
    # 安装Python依赖
    echo -e "  安装Python依赖..."
    pip3 install -r requirements.txt
    
    # 安装Redis（如果需要）
    if ! command -v redis-cli &> /dev/null; then
        echo -e "  安装Redis..."
        sudo apt update
        sudo apt install -y redis-server
        sudo systemctl start redis
        sudo systemctl enable redis
    fi
    
    # 设置权限
    echo -e "  设置文件权限..."
    chmod +x scripts/*.sh
    
    echo -e "${GREEN}✓ 安装完成${NC}"
}

# 启动服务
start_services() {
    echo ""
    echo -e "${BLUE}启动服务...${NC}"
    
    # 运行部署脚本
    if [ -f "scripts/deploy.sh" ]; then
        echo -e "  运行部署脚本..."
        ./scripts/deploy.sh
    else
        echo -e "${YELLOW}警告: 未找到部署脚本，手动启动...${NC}"
        cd app
        nohup python3 app.py > ../logs/app.log 2>&1 &
        echo $! > ../tmp/app.pid
        cd ..
    fi
    
    echo -e "${GREEN}✓ 服务启动完成${NC}"
}

# 显示安装结果
show_installation_result() {
    echo ""
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                🎉 安装成功！ 🎉                     ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo ""
    echo -e "${BLUE}📋 安装摘要:${NC}"
    echo "   版本: __VERSION__"
    echo "   目录: $INSTALL_DIR"
    echo "   时间: $(date)"
    echo ""
    
    echo -e "${BLUE}🔗 访问地址:${NC}"
    echo "   首页:      http://localhost:5000"
    echo "   仪表板:    http://localhost:5000/dashboard"
    echo "   API文档:   http://localhost:5000/api/visitors"
    echo ""
    
    echo -e "${BLUE}⚡ 管理命令:${NC}"
    echo "   查看状态:  $INSTALL_DIR/scripts/status.sh"
    echo "   停止服务:  $INSTALL_DIR/scripts/stop.sh"
    echo "   重启服务:  $INSTALL_DIR/scripts/restart.sh"
    echo "   查看日志:  $INSTALL_DIR/scripts/logs.sh"
    echo ""
    
    echo -e "${YELLOW}💡 提示: 打开浏览器访问仪表板开始使用！${NC}"
}

# 主安装流程
main() {
    show_banner
    show_license
    select_install_dir
    check_system_requirements
    perform_installation
    start_services
    show_installation_result
}

# 替换版本号
sed -i "s/__VERSION__/${FULL_VERSION}/g" install.sh

main "$@"
INSTEOF
    
    # 使安装脚本可执行
    chmod +x "$PACKAGE_DIR/install.sh"
    
    # 替换版本号
    sed -i "s/__VERSION__/$FULL_VERSION/g" "$PACKAGE_DIR/install.sh"
    
    echo -e "  ${GREEN}✓ 安装脚本生成完成${NC}"
}

# 生成卸载脚本
generate_uninstall_script() {
    echo -e "${BLUE}[5/6] 生成卸载脚本...${NC}"
    
    cat > "$PACKAGE_DIR/uninstall.sh" << 'UNINSTEOF'
#!/bin/bash

# 云测试平台卸载脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║              警告：卸载操作不可逆！                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# 确认卸载
read -p "确定要卸载云测试平台吗？这将删除所有相关文件！ (yes/no): " -r confirm
if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}卸载取消${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}[1/4] 停止服务...${NC}"

# 停止应用
if [ -f "tmp/app.pid" ]; then
    APP_PID=$(cat tmp/app.pid)
    kill $APP_PID 2>/dev/null || true
    echo -e "  Flask应用已停止"
fi

# 停止Redis（可选）
read -p "是否停止Redis服务？ (y/N): " -r stop_redis
if [[ "$stop_redis" =~ ^[Yy]$ ]]; then
    sudo systemctl stop redis 2>/dev/null || true
    echo -e "  Redis服务已停止"
fi

echo -e "${BLUE}[2/4] 删除项目文件...${NC}"

# 获取安装目录
INSTALL_DIR=$(pwd)
echo -e "  安装目录: $INSTALL_DIR"

# 确认删除
read -p "确定要删除目录 $INSTALL_DIR 吗？ (yes/no): " -r delete_dir
if [ "$delete_dir" = "yes" ]; then
    cd ..
    rm -rf "$INSTALL_DIR"
    echo -e "  项目文件已删除"
else
    echo -e "  保留项目文件"
fi

echo -e "${BLUE}[3/4] 清理系统...${NC}"

# 清理Python包（可选）
read -p "是否卸载Python依赖包？ (y/N): " -r uninstall_pip
if [[ "$uninstall_pip" =~ ^[Yy]$ ]]; then
    if [ -f "requirements.txt" ]; then
        pip3 uninstall -r requirements.txt -y 2>/dev/null || true
        echo -e "  Python依赖已清理"
    fi
fi

# 清理Redis（可选）
read -p "是否卸载Redis？ (y/N): " -r uninstall_redis
if [[ "$uninstall_redis" =~ ^[Yy]$ ]]; then
    sudo apt remove -y redis-server 2>/dev/null || true
    echo -e "  Redis已卸载"
fi

echo -e "${BLUE}[4/4] 完成清理...${NC}"

# 清理日志
sudo rm -f /var/log/cloud-test-platform.log 2>/dev/null || true

echo ""
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║                🗑️  卸载完成！ 🗑️                    ║"
    echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${YELLOW}提示: 系统清理完成，感谢使用云测试平台！${NC}"
UNINSTEOF
    
    chmod +x "$PACKAGE_DIR/uninstall.sh"
    echo -e "  ${GREEN}✓ 卸载脚本生成完成${NC}"
}

# 创建压缩包
create_archive() {
    echo -e "${BLUE}[6/6] 创建发布包...${NC}"
    
    cd ../dist
    
    # 创建tar.gz包
    echo -e "  创建 tar.gz 包..."
    tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"
    
    # 创建zip包
    echo -e "  创建 zip 包..."
    zip -rq "${PACKAGE_NAME}.zip" "$PACKAGE_NAME"
    
    # 计算文件大小
    TAR_SIZE=$(du -h "${PACKAGE_NAME}.tar.gz" | cut -f1)
    ZIP_SIZE=$(du -h "${PACKAGE_NAME}.zip" | cut -f1)
    
    # 清理临时目录
    rm -rf "$PACKAGE_NAME"
    
    cd ..
    
    echo -e "  ${GREEN}✓ 打包完成${NC}"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                  打包结果                          ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}📦 生成的文件:${NC}"
    echo -e "  ${GREEN}dist/${PACKAGE_NAME}.tar.gz${NC} (${TAR_SIZE})"
    echo -e "  ${GREEN}dist/${PACKAGE_NAME}.zip${NC} (${ZIP_SIZE})"
    echo ""
    echo -e "${BLUE}📋 包内容:${NC}"
    echo "  • 完整项目代码"
    echo "  • 自动化管理脚本"
    echo "  • 安装/卸载程序"
    echo "  • 详细文档"
    echo "  • 配置文件"
    echo ""
    echo -e "${YELLOW}💡 提示: 将压缩包分享给其他人即可一键安装！${NC}"
}

# 主打包流程
main() {
    show_banner
    clean_old_packages
    create_package_structure
    copy_project_files
    generate_install_script
    generate_uninstall_script
    create_archive
}

main "$@"


chmod +x build_package.sh
