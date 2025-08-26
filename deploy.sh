#!/bin/bash

# Web Kiosk Launcher 一键部署脚本
# 自动完成安装、配置、测试和启动

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

log_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1"
}

# 显示横幅
show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Web Kiosk Launcher                        ║"
    echo "║                        一键部署脚本                           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "此脚本将自动完成以下操作："
    echo "1. 检测系统环境"
    echo "2. 安装必要依赖"
    echo "3. 配置应用"
    echo "4. 创建系统服务"
    echo "5. 启动服务"
    echo "6. 验证功能"
    echo
}

# 检查是否为root用户
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "检测到以root用户运行"
        read -p "是否继续？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "建议以普通用户运行，将安装为用户级服务"
            exit 0
        fi
    else
        log_info "以普通用户运行，将安装为用户级服务"
    fi
}

# 检测系统环境
detect_system() {
    log_step "检测系统环境..."
    
    # 检测发行版
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        DISTRO="rhel"
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
    else
        log_error "无法检测发行版"
        exit 1
    fi
    
    # 检测架构
    ARCH=$(uname -m)
    
    # 检测Python版本
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    else
        PYTHON_VERSION="未安装"
    fi
    
    # 检测显示环境
    DISPLAY_ENV="未设置"
    if [ -n "$DISPLAY" ]; then
        DISPLAY_ENV="$DISPLAY"
    fi
    
    # 检测会话类型
    SESSION_TYPE="未知"
    if [ -n "$XDG_SESSION_TYPE" ]; then
        SESSION_TYPE="$XDG_SESSION_TYPE"
    fi
    
    log_info "系统信息："
    echo "  发行版: $DISTRO $VERSION"
    echo "  架构: $ARCH"
    echo "  Python: $PYTHON_VERSION"
    echo "  显示: $DISPLAY_ENV"
    echo "  会话类型: $SESSION_TYPE"
    echo
}

# 安装依赖
install_dependencies() {
    log_step "安装系统依赖..."
    
    case $DISTRO in
        ubuntu|debian|raspbian)
            log_info "使用 apt 安装依赖..."
            sudo apt update
            sudo apt install -y python3 python3-pip python3-venv curl wget
            
            # 安装浏览器
            if ! command -v chromium-browser &> /dev/null; then
                log_info "安装 Chromium..."
                sudo apt install -y chromium-browser
            fi
            
            # 安装图形工具
            sudo apt install -y xdotool wmctrl
            
            # 安装最小图形栈（如需要）
            if [ -z "$DISPLAY" ]; then
                log_warning "未检测到 DISPLAY 环境变量，安装最小图形栈..."
                sudo apt install -y xorg openbox
            fi
            ;;
            
        centos|rhel|alma|rocky|fedora)
            log_info "使用 dnf/yum 安装依赖..."
            if command -v dnf &> /dev/null; then
                PKG_MGR="dnf"
            else
                PKG_MGR="yum"
            fi
            
            sudo $PKG_MGR install -y python3 python3-pip curl wget
            
            # 安装浏览器
            if ! command -v chromium &> /dev/null; then
                log_info "安装 Chromium..."
                sudo $PKG_MGR install -y chromium
            fi
            
            # 安装图形工具
            sudo $PKG_MGR install -y xdotool wmctrl
            
            # 安装最小图形栈（如需要）
            if [ -z "$DISPLAY" ]; then
                log_warning "未检测到 DISPLAY 环境变量，安装最小图形栈..."
                sudo $PKG_MGR install -y xorg-x11-server-Xorg openbox
            fi
            ;;
            
        arch|manjaro)
            log_info "使用 pacman 安装依赖..."
            sudo pacman -Sy --noconfirm python python-pip curl wget
            
            # 安装浏览器
            if ! command -v chromium &> /dev/null; then
                log_info "安装 Chromium..."
                sudo pacman -S --noconfirm chromium
            fi
            
            # 安装图形工具
            sudo pacman -S --noconfirm xdotool wmctrl
            
            # 安装最小图形栈（如需要）
            if [ -z "$DISPLAY" ]; then
                log_warning "未检测到 DISPLAY 环境变量，安装最小图形栈..."
                sudo pacman -S --noconfirm xorg-server openbox
            fi
            ;;
            
        *)
            log_error "不支持的发行版: $DISTRO"
            exit 1
            ;;
    esac
    
    log_success "依赖安装完成"
}

# 检测浏览器
detect_browser() {
    log_step "检测可用浏览器..."
    
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
        log_error "未找到支持的浏览器"
        log_info "请手动安装以下浏览器之一："
        echo "  - chromium-browser (Ubuntu/Debian)"
        echo "  - chromium (CentOS/Arch)"
        echo "  - firefox"
        echo "  - surf"
        echo "  - luakit"
        exit 1
    fi
}

# 创建应用目录
create_app_directory() {
    log_step "创建应用目录..."
    
    # 选择安装位置
    if [ "$EUID" -eq 0 ]; then
        # root 用户安装到系统目录
        APP_DIR="/opt/web-kiosk-launcher"
        USER="www-data"
    else
        # 普通用户安装到用户目录
        APP_DIR="$HOME/.local/share/web-kiosk-launcher"
        USER="$USER"
    fi
    
    sudo mkdir -p "$APP_DIR"
    sudo chown $USER:$USER "$APP_DIR"
    
    log_info "应用将安装到: $APP_DIR"
}

# 复制文件
copy_files() {
    log_step "复制应用文件..."
    
    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    
    # 复制文件
    sudo cp -r "$PROJECT_DIR"/* "$APP_DIR/"
    sudo chown -R $USER:$USER "$APP_DIR"
    sudo chmod +x "$APP_DIR/server.py"
    sudo chmod +x "$APP_DIR/scripts/"*.sh
    sudo chmod +x "$APP_DIR/deploy.sh"
    sudo chmod +x "$APP_DIR/start.sh"
    
    log_success "文件复制完成"
}

# 创建配置文件
create_config() {
    log_step "创建配置文件..."
    
    CONFIG_FILE="$APP_DIR/.env"
    
    # 询问用户配置
    echo
    log_info "配置 Web Kiosk Launcher"
    echo
    
    # 默认URL
    read -p "默认URL (默认: https://example.org): " DEFAULT_URL
    DEFAULT_URL=${DEFAULT_URL:-https://example.org}
    
    # 监听地址
    read -p "监听地址 (默认: 127.0.0.1): " HOST
    HOST=${HOST:-127.0.0.1}
    
    # 监听端口
    read -p "监听端口 (默认: 8787): " PORT
    PORT=${PORT:-8787}
    
    # 是否启用GPU
    read -p "是否启用GPU加速？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ENABLE_GPU="true"
    else
        ENABLE_GPU="false"
    fi
    
    # 是否启用Basic Auth
    read -p "是否启用HTTP Basic Auth？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BASIC_AUTH="true"
        read -p "用户名 (默认: admin): " BASIC_AUTH_USER
        BASIC_AUTH_USER=${BASIC_AUTH_USER:-admin}
        read -s -p "密码: " BASIC_AUTH_PASS
        echo
    else
        BASIC_AUTH="false"
        BASIC_AUTH_USER="admin"
        BASIC_AUTH_PASS="password"
    fi
    
    # 创建配置文件
    cat > "$CONFIG_FILE" << EOF
# Web Kiosk Launcher 配置文件

# 服务配置
HOST=$HOST
PORT=$PORT

# 默认URL
DEFAULT_URL=$DEFAULT_URL

# 浏览器配置
ENABLE_GPU=$ENABLE_GPU
REUSE_INSTANCE=true

# 安全配置
BASIC_AUTH=$BASIC_AUTH
BASIC_AUTH_USER=$BASIC_AUTH_USER
BASIC_AUTH_PASS=$BASIC_AUTH_PASS

# URL白名单（可选，用逗号分隔）
# ALLOW_LIST=example.com,google.com
EOF
    
    sudo chown $USER:$USER "$CONFIG_FILE"
    log_success "配置文件创建完成: $CONFIG_FILE"
}

# 创建systemd服务
create_systemd_service() {
    log_step "创建 systemd 服务..."
    
    if [ "$EUID" -eq 0 ]; then
        # 系统级服务
        SERVICE_FILE="/etc/systemd/system/web-kiosk.service"
        SERVICE_USER="www-data"
    else
        # 用户级服务
        SERVICE_FILE="$HOME/.config/systemd/user/web-kiosk.service"
        mkdir -p "$(dirname "$SERVICE_FILE")"
        SERVICE_USER="$USER"
    fi
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Web Kiosk Launcher
Documentation=https://github.com/your-repo/web-kiosk-launcher
After=network.target graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
Environment=DISPLAY=:0
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/bin/python3 $APP_DIR/server.py
Restart=on-failure
RestartSec=5
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载 systemd
    if [ "$EUID" -eq 0 ]; then
        sudo systemctl daemon-reload
        sudo systemctl enable web-kiosk
        log_success "系统级服务已创建并启用"
    else
        systemctl --user daemon-reload
        systemctl --user enable web-kiosk
        log_success "用户级服务已创建并启用"
    fi
}

# 创建自启动配置
create_autostart() {
    log_step "创建自启动配置..."
    
    read -p "是否在图形会话登录时自动打开默认URL？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        AUTOSTART_DIR="$HOME/.config/autostart"
        mkdir -p "$AUTOSTART_DIR"
        
        cat > "$AUTOSTART_DIR/web-kiosk-autostart.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Web Kiosk Launcher
Comment=Auto-start web kiosk launcher with default URL
Exec=curl -X POST http://127.0.0.1:8787/open -d "url=$DEFAULT_URL"
Terminal=false
X-GNOME-Autostart-enabled=true
Hidden=false
NoDisplay=false
X-GNOME-Autostart-Delay=10
OnlyShowIn=GNOME;KDE;XFCE;LXDE;MATE;
EOF
        
        log_success "自启动配置已创建: $AUTOSTART_DIR/web-kiosk-autostart.desktop"
    else
        log_info "跳过自启动配置"
    fi
}

# 设置权限
set_permissions() {
    log_step "设置文件权限..."
    
    sudo chown -R $USER:$USER "$APP_DIR"
    sudo chmod +x "$APP_DIR/server.py"
    sudo chmod +x "$APP_DIR/scripts/"*.sh
    sudo chmod +x "$APP_DIR/deploy.sh"
    sudo chmod +x "$APP_DIR/start.sh"
    
    # 创建日志目录
    LOG_DIR="$HOME/.local/share/web-kiosk-launcher"
    mkdir -p "$LOG_DIR"
    sudo chown $USER:$USER "$LOG_DIR"
    
    log_success "权限设置完成"
}

# 测试安装
test_installation() {
    log_step "测试安装..."
    
    # 检查Python
    if ! python3 --version &> /dev/null; then
        log_error "Python3 未正确安装"
        return 1
    fi
    
    # 检查浏览器
    detect_browser
    
    # 检查DISPLAY
    if [ -z "$DISPLAY" ]; then
        log_warning "未检测到 DISPLAY 环境变量"
        log_info "请确保图形环境已启动"
    else
        log_success "图形环境检测正常: $DISPLAY"
    fi
    
    # 运行项目测试
    if [ -f "$APP_DIR/test.py" ]; then
        log_info "运行项目测试..."
        cd "$APP_DIR"
        python3 test.py
        if [ $? -eq 0 ]; then
            log_success "项目测试通过"
        else
            log_warning "项目测试失败，但继续部署"
        fi
    fi
    
    log_success "安装测试完成"
}

# 启动服务
start_service() {
    log_step "启动服务..."
    
    if [ "$EUID" -eq 0 ]; then
        # 系统级服务
        sudo systemctl start web-kiosk
        sleep 2
        if systemctl is-active --quiet web-kiosk; then
            log_success "系统级服务启动成功"
        else
            log_error "系统级服务启动失败"
            sudo systemctl status web-kiosk
            return 1
        fi
    else
        # 用户级服务
        systemctl --user start web-kiosk
        sleep 2
        if systemctl --user is-active --quiet web-kiosk; then
            log_success "用户级服务启动成功"
        else
            log_error "用户级服务启动失败"
            systemctl --user status web-kiosk
            return 1
        fi
    fi
}

# 验证功能
verify_functionality() {
    log_step "验证功能..."
    
    # 等待服务启动
    sleep 3
    
    # 测试Web界面
    log_info "测试Web界面..."
    if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8787" | grep -q "200"; then
        log_success "Web界面访问正常"
    else
        log_error "Web界面访问失败"
        return 1
    fi
    
    # 测试API接口
    log_info "测试API接口..."
    if curl -s -X POST "http://127.0.0.1:8787/close" | grep -q '"ok"'; then
        log_success "API接口测试通过"
    else
        log_warning "API接口测试失败，但服务可能正常运行"
    fi
    
    log_success "功能验证完成"
}

# 显示部署信息
show_deployment_info() {
    log_success "部署完成！"
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                        部署信息                               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    echo "应用目录: $APP_DIR"
    echo "配置文件: $APP_DIR/.env"
    echo "日志文件: $LOG_DIR/launcher.log"
    echo "访问地址: http://127.0.0.1:8787"
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                        使用方法                               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    if [ "$EUID" -eq 0 ]; then
        echo "启动服务: sudo systemctl start web-kiosk"
        echo "停止服务: sudo systemctl stop web-kiosk"
        echo "查看状态: sudo systemctl status web-kiosk"
        echo "查看日志: sudo journalctl -u web-kiosk -f"
        echo "开机自启: sudo systemctl enable web-kiosk"
    else
        echo "启动服务: systemctl --user start web-kiosk"
        echo "停止服务: systemctl --user stop web-kiosk"
        echo "查看状态: systemctl --user status web-kiosk"
        echo "查看日志: journalctl --user -u web-kiosk -f"
        echo "开机自启: systemctl --user enable web-kiosk"
    fi
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                        下一步操作                             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    echo "1. 打开浏览器访问: http://127.0.0.1:8787"
    echo "2. 输入要打开的URL"
    echo "3. 点击'打开'按钮"
    echo "4. 浏览器将在全屏模式下打开指定URL"
    echo
    echo "如需修改配置，请编辑: $APP_DIR/.env"
    echo
}

# 清理函数
cleanup() {
    log_info "清理临时文件..."
    # 可以在这里添加清理逻辑
}

# 错误处理
error_handler() {
    log_error "部署过程中发生错误"
    log_info "请检查上述错误信息并重试"
    cleanup
    exit 1
}

# 设置错误处理
trap error_handler ERR

# 主函数
main() {
    show_banner
    check_root
    detect_system
    
    # 确认继续
    echo
    read -p "是否继续部署？(Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "部署已取消"
        exit 0
    fi
    
    # 执行部署步骤
    install_dependencies
    detect_browser
    create_app_directory
    copy_files
    create_config
    create_systemd_service
    create_autostart
    set_permissions
    test_installation
    start_service
    verify_functionality
    show_deployment_info
    
    log_success "🎉 一键部署完成！"
}

# 运行主函数
main "$@"
