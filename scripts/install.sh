#!/bin/bash

# Web Kiosk Launcher 安装脚本
# 支持 Debian/Ubuntu、CentOS/Alma、Arch 等发行版

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

# 检测发行版
detect_distro() {
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
    
    log_info "检测到发行版: $DISTRO $VERSION"
}

# 检测架构
detect_arch() {
    ARCH=$(uname -m)
    log_info "检测到架构: $ARCH"
}

# 安装依赖包
install_dependencies() {
    log_info "安装系统依赖..."
    
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
}

# 检测浏览器
detect_browser() {
    log_info "检测可用浏览器..."
    
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
        log_error "未找到支持的浏览器，请手动安装 Chromium 或 Firefox"
        exit 1
    fi
}

# 创建应用目录
create_app_directory() {
    log_info "创建应用目录..."
    
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
    log_info "复制应用文件..."
    
    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    
    # 复制文件
    sudo cp -r "$PROJECT_DIR"/* "$APP_DIR/"
    sudo chown -R $USER:$USER "$APP_DIR"
    sudo chmod +x "$APP_DIR/server.py"
    sudo chmod +x "$APP_DIR/scripts/"*.sh
    
    log_success "文件复制完成"
}

# 创建配置文件
create_config() {
    log_info "创建配置文件..."
    
    CONFIG_FILE="$APP_DIR/.env"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
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
        
        sudo chown $USER:$USER "$CONFIG_FILE"
        log_success "配置文件创建完成: $CONFIG_FILE"
    else
        log_info "配置文件已存在: $CONFIG_FILE"
    fi
}

# 创建systemd服务
create_systemd_service() {
    log_info "创建 systemd 服务..."
    
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
After=network.target graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
Environment=DISPLAY=:0
ExecStart=/usr/bin/python3 $APP_DIR/server.py
Restart=on-failure
RestartSec=5

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
    log_info "创建自启动配置..."
    
    AUTOSTART_DIR="$HOME/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"
    
    cat > "$AUTOSTART_DIR/web-kiosk-autostart.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Web Kiosk Launcher
Comment=Auto-start web kiosk launcher
Exec=curl -X POST http://127.0.0.1:8787/open -d "url=https://example.org"
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
    
    log_success "自启动配置已创建: $AUTOSTART_DIR/web-kiosk-autostart.desktop"
    log_warning "请根据需要修改默认URL"
}

# 设置权限
set_permissions() {
    log_info "设置文件权限..."
    
    sudo chown -R $USER:$USER "$APP_DIR"
    sudo chmod +x "$APP_DIR/server.py"
    sudo chmod +x "$APP_DIR/scripts/"*.sh
    
    # 创建日志目录
    LOG_DIR="$HOME/.local/share/web-kiosk-launcher"
    mkdir -p "$LOG_DIR"
    sudo chown $USER:$USER "$LOG_DIR"
}

# 测试安装
test_installation() {
    log_info "测试安装..."
    
    # 检查Python
    if ! python3 --version &> /dev/null; then
        log_error "Python3 未正确安装"
        exit 1
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
    
    log_success "安装测试完成"
}

# 显示安装信息
show_installation_info() {
    log_success "安装完成！"
    echo
    echo "=== 安装信息 ==="
    echo "应用目录: $APP_DIR"
    echo "配置文件: $APP_DIR/.env"
    echo "日志文件: $LOG_DIR/launcher.log"
    echo
    echo "=== 使用方法 ==="
    if [ "$EUID" -eq 0 ]; then
        echo "启动服务: sudo systemctl start web-kiosk"
        echo "停止服务: sudo systemctl stop web-kiosk"
        echo "查看状态: sudo systemctl status web-kiosk"
        echo "查看日志: sudo journalctl -u web-kiosk -f"
    else
        echo "启动服务: systemctl --user start web-kiosk"
        echo "停止服务: systemctl --user stop web-kiosk"
        echo "查看状态: systemctl --user status web-kiosk"
        echo "查看日志: journalctl --user -u web-kiosk -f"
    fi
    echo
    echo "访问地址: http://127.0.0.1:8787"
    echo
    echo "=== 下一步 ==="
    echo "1. 编辑配置文件: nano $APP_DIR/.env"
    echo "2. 启动服务"
    echo "3. 访问 Web 界面"
    echo "4. 输入URL并测试"
}

# 主函数
main() {
    echo "=== Web Kiosk Launcher 安装程序 ==="
    echo
    
    # 检查是否为root用户
    if [ "$EUID" -eq 0 ]; then
        log_warning "以root用户运行，将安装为系统服务"
    else
        log_info "以普通用户运行，将安装为用户服务"
    fi
    
    # 执行安装步骤
    detect_distro
    detect_arch
    install_dependencies
    detect_browser
    create_app_directory
    copy_files
    create_config
    create_systemd_service
    create_autostart
    set_permissions
    test_installation
    show_installation_info
}

# 运行主函数
main "$@"
