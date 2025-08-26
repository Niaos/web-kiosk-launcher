#!/bin/bash

# Web Kiosk Launcher 卸载脚本

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

# 确认卸载
confirm_uninstall() {
    echo "=== Web Kiosk Launcher 卸载程序 ==="
    echo
    echo "此操作将："
    echo "- 停止并禁用 systemd 服务"
    echo "- 删除应用文件"
    echo "- 删除配置文件"
    echo "- 删除日志文件"
    echo "- 删除自启动配置"
    echo
    read -p "确定要卸载 Web Kiosk Launcher 吗？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "卸载已取消"
        exit 0
    fi
}

# 停止服务
stop_service() {
    log_info "停止服务..."
    
    # 检查是否为root用户
    if [ "$EUID" -eq 0 ]; then
        # 系统级服务
        if systemctl is-active --quiet web-kiosk; then
            sudo systemctl stop web-kiosk
            log_success "系统级服务已停止"
        fi
        
        if systemctl is-enabled --quiet web-kiosk; then
            sudo systemctl disable web-kiosk
            log_success "系统级服务已禁用"
        fi
    else
        # 用户级服务
        if systemctl --user is-active --quiet web-kiosk; then
            systemctl --user stop web-kiosk
            log_success "用户级服务已停止"
        fi
        
        if systemctl --user is-enabled --quiet web-kiosk; then
            systemctl --user disable web-kiosk
            log_success "用户级服务已禁用"
        fi
    fi
}

# 删除服务文件
remove_service_file() {
    log_info "删除服务文件..."
    
    if [ "$EUID" -eq 0 ]; then
        # 系统级服务
        SERVICE_FILE="/etc/systemd/system/web-kiosk.service"
        if [ -f "$SERVICE_FILE" ]; then
            sudo rm -f "$SERVICE_FILE"
            sudo systemctl daemon-reload
            log_success "系统级服务文件已删除"
        fi
    else
        # 用户级服务
        SERVICE_FILE="$HOME/.config/systemd/user/web-kiosk.service"
        if [ -f "$SERVICE_FILE" ]; then
            rm -f "$SERVICE_FILE"
            systemctl --user daemon-reload
            log_success "用户级服务文件已删除"
        fi
    fi
}

# 删除应用文件
remove_app_files() {
    log_info "删除应用文件..."
    
    if [ "$EUID" -eq 0 ]; then
        # 系统级安装
        APP_DIR="/opt/web-kiosk-launcher"
        if [ -d "$APP_DIR" ]; then
            sudo rm -rf "$APP_DIR"
            log_success "应用目录已删除: $APP_DIR"
        fi
    else
        # 用户级安装
        APP_DIR="$HOME/.local/share/web-kiosk-launcher"
        if [ -d "$APP_DIR" ]; then
            rm -rf "$APP_DIR"
            log_success "应用目录已删除: $APP_DIR"
        fi
    fi
}

# 删除配置文件
remove_config_files() {
    log_info "删除配置文件..."
    
    # 删除.env文件
    if [ "$EUID" -eq 0 ]; then
        CONFIG_FILE="/opt/web-kiosk-launcher/.env"
    else
        CONFIG_FILE="$HOME/.local/share/web-kiosk-launcher/.env"
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        rm -f "$CONFIG_FILE"
        log_success "配置文件已删除: $CONFIG_FILE"
    fi
}

# 删除日志文件
remove_log_files() {
    log_info "删除日志文件..."
    
    LOG_DIR="$HOME/.local/share/web-kiosk-launcher"
    if [ -d "$LOG_DIR" ]; then
        rm -rf "$LOG_DIR"
        log_success "日志目录已删除: $LOG_DIR"
    fi
}

# 删除自启动配置
remove_autostart() {
    log_info "删除自启动配置..."
    
    AUTOSTART_FILE="$HOME/.config/autostart/web-kiosk-autostart.desktop"
    if [ -f "$AUTOSTART_FILE" ]; then
        rm -f "$AUTOSTART_FILE"
        log_success "自启动配置已删除: $AUTOSTART_FILE"
    fi
}

# 删除PID文件
remove_pid_file() {
    log_info "清理PID文件..."
    
    PID_FILE="/tmp/web-kiosk-browser.pid"
    if [ -f "$PID_FILE" ]; then
        rm -f "$PID_FILE"
        log_success "PID文件已删除: $PID_FILE"
    fi
}

# 检查残留文件
check_remaining_files() {
    log_info "检查残留文件..."
    
    REMAINING_FILES=()
    
    # 检查应用目录
    if [ "$EUID" -eq 0 ]; then
        if [ -d "/opt/web-kiosk-launcher" ]; then
            REMAINING_FILES+=("/opt/web-kiosk-launcher")
        fi
    else
        if [ -d "$HOME/.local/share/web-kiosk-launcher" ]; then
            REMAINING_FILES+=("$HOME/.local/share/web-kiosk-launcher")
        fi
    fi
    
    # 检查服务文件
    if [ "$EUID" -eq 0 ]; then
        if [ -f "/etc/systemd/system/web-kiosk.service" ]; then
            REMAINING_FILES+=("/etc/systemd/system/web-kiosk.service")
        fi
    else
        if [ -f "$HOME/.config/systemd/user/web-kiosk.service" ]; then
            REMAINING_FILES+=("$HOME/.config/systemd/user/web-kiosk.service")
        fi
    fi
    
    # 检查自启动文件
    if [ -f "$HOME/.config/autostart/web-kiosk-autostart.desktop" ]; then
        REMAINING_FILES+=("$HOME/.config/autostart/web-kiosk-autostart.desktop")
    fi
    
    # 检查PID文件
    if [ -f "/tmp/web-kiosk-browser.pid" ]; then
        REMAINING_FILES+=("/tmp/web-kiosk-browser.pid")
    fi
    
    if [ ${#REMAINING_FILES[@]} -eq 0 ]; then
        log_success "所有文件已清理完成"
    else
        log_warning "发现残留文件："
        for file in "${REMAINING_FILES[@]}"; do
            echo "  - $file"
        done
        echo
        read -p "是否手动删除这些文件？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for file in "${REMAINING_FILES[@]}"; do
                if [ -f "$file" ]; then
                    rm -f "$file"
                elif [ -d "$file" ]; then
                    rm -rf "$file"
                fi
                log_success "已删除: $file"
            done
        fi
    fi
}

# 显示卸载完成信息
show_uninstall_info() {
    log_success "卸载完成！"
    echo
    echo "=== 卸载总结 ==="
    echo "✓ 服务已停止并禁用"
    echo "✓ 应用文件已删除"
    echo "✓ 配置文件已删除"
    echo "✓ 日志文件已删除"
    echo "✓ 自启动配置已删除"
    echo "✓ PID文件已清理"
    echo
    echo "=== 注意事项 ==="
    echo "- 系统依赖包（如chromium、xdotool等）未被删除"
    echo "- 如需删除系统依赖，请手动执行："
    echo "  Ubuntu/Debian: sudo apt remove chromium-browser xdotool wmctrl"
    echo "  CentOS/RHEL: sudo dnf remove chromium xdotool wmctrl"
    echo "  Arch: sudo pacman -R chromium xdotool wmctrl"
    echo
    echo "感谢使用 Web Kiosk Launcher！"
}

# 主函数
main() {
    confirm_uninstall
    stop_service
    remove_service_file
    remove_app_files
    remove_config_files
    remove_log_files
    remove_autostart
    remove_pid_file
    check_remaining_files
    show_uninstall_info
}

# 运行主函数
main "$@"
