#!/bin/bash

# Web Kiosk Launcher 快速启动脚本
# 用于开发和测试

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 检查Python
check_python() {
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 未安装"
        exit 1
    fi
    
    version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    log_info "Python版本: $version"
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    # 检查浏览器
    browsers=("chromium-browser" "chromium" "google-chrome" "firefox" "surf" "luakit")
    found_browser=""
    
    for browser in "${browsers[@]}"; do
        if command -v "$browser" &> /dev/null; then
            found_browser="$browser"
            log_success "找到浏览器: $browser"
            break
        fi
    done
    
    if [ -z "$found_browser" ]; then
        log_warning "未找到支持的浏览器"
        log_info "请安装以下浏览器之一："
        echo "  - chromium-browser (Ubuntu/Debian)"
        echo "  - chromium (CentOS/Arch)"
        echo "  - firefox"
        echo "  - surf"
        echo "  - luakit"
    fi
    
    # 检查图形工具
    if ! command -v xdotool &> /dev/null; then
        log_warning "xdotool 未安装"
    fi
    
    if ! command -v wmctrl &> /dev/null; then
        log_warning "wmctrl 未安装"
    fi
}

# 检查显示环境
check_display() {
    if [ -z "$DISPLAY" ]; then
        log_error "未设置 DISPLAY 环境变量"
        log_info "请确保图形环境已启动"
        exit 1
    fi
    
    log_info "显示环境: $DISPLAY"
}

# 创建配置文件
create_config() {
    if [ ! -f ".env" ]; then
        log_info "创建配置文件..."
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

# 运行测试
run_tests() {
    if [ -f "test.py" ]; then
        log_info "运行测试..."
        python3 test.py
        if [ $? -eq 0 ]; then
            log_success "测试通过"
        else
            log_warning "测试失败，但继续启动"
        fi
    fi
}

# 启动服务器
start_server() {
    log_info "启动 Web Kiosk Launcher..."
    log_info "访问地址: http://127.0.0.1:8787"
    log_info "按 Ctrl+C 停止服务器"
    echo
    
    python3 server.py
}

# 主函数
main() {
    echo "=== Web Kiosk Launcher 快速启动 ==="
    echo
    
    check_python
    check_dependencies
    check_display
    create_config
    run_tests
    start_server
}

# 运行主函数
main "$@"
