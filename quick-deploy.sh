#!/bin/bash

# Web Kiosk Launcher 快速部署脚本
# 简化版，用于快速测试和开发

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示横幅
show_banner() {
    echo -e "${BLUE}"
    echo "=== Web Kiosk Launcher 快速部署 ==="
    echo -e "${NC}"
    echo "此脚本将快速部署 Web Kiosk Launcher 用于测试"
    echo
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    # 检查Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 未安装，请先安装 Python3"
        exit 1
    fi
    
    # 检查浏览器
    BROWSERS=("chromium-browser" "chromium" "google-chrome" "firefox" "surf" "luakit")
    FOUND_BROWSER=""
    
    for browser in "${BROWSERS[@]}"; do
        if command -v $browser &> /dev/null; then
            FOUND_BROWSER=$browser
            log_success "找到浏览器: $browser"
            break
        fi
    done
    
    if [ -z "$FOUND_BROWSER" ]; then
        log_warning "未找到支持的浏览器，请安装 Chromium 或 Firefox"
        log_info "Debian/Ubuntu: sudo apt install chromium"
        log_info "Debian/Ubuntu: sudo apt install firefox-esr"
        log_info "CentOS/RHEL: sudo dnf install chromium"
        log_info "Arch: sudo pacman -S chromium"
    fi
    
    # 检查DISPLAY
    if [ -z "$DISPLAY" ]; then
        log_warning "未设置 DISPLAY 环境变量"
        log_info "请确保图形环境已启动"
    else
        log_success "显示环境: $DISPLAY"
    fi
}

# 创建配置文件
create_config() {
    log_info "创建配置文件..."
    
    if [ ! -f ".env" ]; then
        cat > .env << EOF
# Web Kiosk Launcher 配置文件

# 服务配置
HOST=127.0.0.1
PORT=8787

# 默认URL
DEFAULT_URL=https://example.org

# 浏览器配置
ENABLE_GPU=false
REUSE_INSTANCE=true

# 安全配置
BASIC_AUTH=false
BASIC_AUTH_USER=admin
BASIC_AUTH_PASS=password

# URL白名单（可选，用逗号分隔）
# ALLOW_LIST=example.com,google.com
EOF
        log_success "配置文件已创建: .env"
    else
        log_info "配置文件已存在: .env"
    fi
}

# 设置权限
set_permissions() {
    log_info "设置文件权限..."
    
    chmod +x server.py
    chmod +x scripts/*.sh
    chmod +x start.sh
    chmod +x deploy.sh
    chmod +x quick-deploy.sh
    
    log_success "权限设置完成"
}

# 运行测试
run_tests() {
    log_info "运行测试..."
    
    if [ -f "test.py" ]; then
        python3 test.py
        if [ $? -eq 0 ]; then
            log_success "测试通过"
        else
            log_warning "测试失败，但继续部署"
        fi
    else
        log_info "跳过测试（test.py 不存在）"
    fi
}

# 启动服务
start_service() {
    log_info "启动服务..."
    log_info "访问地址: http://127.0.0.1:8787"
    log_info "按 Ctrl+C 停止服务"
    echo
    
    python3 server.py
}

# 主函数
main() {
    show_banner
    check_dependencies
    create_config
    set_permissions
    run_tests
    start_service
}

# 运行主函数
main "$@"
