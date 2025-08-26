#!/bin/bash

# 浏览器检测脚本
# 独立检测系统中可用的浏览器并返回最佳选择

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

# 浏览器检测顺序（按优先级）
BROWSERS=(
    "chromium-browser"
    "chromium"
    "google-chrome"
    "firefox"
    "surf"
    "luakit"
)

# 浏览器参数配置
declare -A BROWSER_ARGS
BROWSER_ARGS["chromium-browser"]="--kiosk --noerrdialogs --disable-session-crashed-bubble --disable-infobars --disable-translate --no-first-run --fast --fast-start --disable-gpu --disable-extensions --start-maximized"
BROWSER_ARGS["chromium"]="--kiosk --noerrdialogs --disable-session-crashed-bubble --disable-infobars --disable-translate --no-first-run --fast --fast-start --disable-gpu --disable-extensions --start-maximized"
BROWSER_ARGS["google-chrome"]="--kiosk --noerrdialogs --disable-session-crashed-bubble --disable-infobars --disable-translate --no-first-run --fast --fast-start --disable-gpu --disable-extensions --start-maximized"
BROWSER_ARGS["firefox"]="--kiosk"
BROWSER_ARGS["surf"]="-f"
BROWSER_ARGS["luakit"]="-c fullscreen"

# 检测浏览器
detect_browser() {
    log_info "检测可用浏览器..."
    
    FOUND_BROWSERS=()
    
    for browser in "${BROWSERS[@]}"; do
        if command -v "$browser" &> /dev/null; then
            FOUND_BROWSERS+=("$browser")
            log_success "找到浏览器: $browser"
        fi
    done
    
    if [ ${#FOUND_BROWSERS[@]} -eq 0 ]; then
        log_error "未找到支持的浏览器"
        return 1
    fi
    
    # 返回第一个找到的浏览器（优先级最高）
    echo "${FOUND_BROWSERS[0]}"
    return 0
}

# 获取浏览器参数
get_browser_args() {
    local browser="$1"
    
    if [ -n "${BROWSER_ARGS[$browser]}" ]; then
        echo "${BROWSER_ARGS[$browser]}"
    else
        echo ""
    fi
}

# 检测浏览器版本
get_browser_version() {
    local browser="$1"
    
    case "$browser" in
        chromium-browser|chromium|google-chrome)
            "$browser" --version 2>/dev/null | head -n1 || echo "版本未知"
            ;;
        firefox)
            firefox --version 2>/dev/null || echo "版本未知"
            ;;
        surf)
            surf -v 2>/dev/null || echo "版本未知"
            ;;
        luakit)
            luakit --version 2>/dev/null || echo "版本未知"
            ;;
        *)
            echo "版本未知"
            ;;
    esac
}

# 检测系统架构
detect_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "x86_64"
            ;;
        aarch64|arm64)
            echo "ARM64"
            ;;
        armv7l|armv6l)
            echo "ARM32"
            ;;
        *)
            echo "$arch"
            ;;
    esac
}

# 检测图形环境
detect_display() {
    if [ -n "$DISPLAY" ]; then
        echo "$DISPLAY"
    else
        echo "未设置"
    fi
}

# 检测Wayland
detect_wayland() {
    if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        echo "Wayland"
    else
        echo "X11"
    fi
}

# 生成启动命令
generate_launch_command() {
    local browser="$1"
    local url="$2"
    local enable_gpu="${3:-false}"
    
    local args="${BROWSER_ARGS[$browser]}"
    
    # 根据GPU设置调整参数
    if [ "$enable_gpu" = "false" ]; then
        # 移除GPU相关参数，添加禁用GPU参数
        args=$(echo "$args" | sed 's/--enable-gpu//g')
        if [[ "$args" != *"--disable-gpu"* ]]; then
            args="$args --disable-gpu"
        fi
    fi
    
    echo "$browser $args $url"
}

# 显示详细信息
show_detailed_info() {
    local browser="$1"
    
    echo
    echo "=== 浏览器详细信息 ==="
    echo "名称: $browser"
    echo "版本: $(get_browser_version "$browser")"
    echo "参数: $(get_browser_args "$browser")"
    echo "架构: $(detect_arch)"
    echo "显示: $(detect_display)"
    echo "会话类型: $(detect_wayland)"
    echo
}

# 显示所有可用浏览器
show_all_browsers() {
    echo
    echo "=== 所有可用浏览器 ==="
    
    for browser in "${BROWSERS[@]}"; do
        if command -v "$browser" &> /dev/null; then
            echo "✓ $browser ($(get_browser_version "$browser"))"
        else
            echo "✗ $browser (未安装)"
        fi
    done
    echo
}

# 测试浏览器启动
test_browser_launch() {
    local browser="$1"
    local test_url="https://example.org"
    
    log_info "测试浏览器启动: $browser"
    
    # 检查DISPLAY
    if [ -z "$DISPLAY" ]; then
        log_error "未设置DISPLAY环境变量"
        return 1
    fi
    
    # 尝试启动浏览器（短暂运行后关闭）
    local launch_cmd=$(generate_launch_command "$browser" "$test_url" "false")
    
    log_info "执行命令: $launch_cmd"
    
    # 启动浏览器并等待短暂时间
    timeout 5s bash -c "$launch_cmd" &
    local pid=$!
    
    # 等待2秒
    sleep 2
    
    # 检查进程是否还在运行
    if kill -0 "$pid" 2>/dev/null; then
        log_success "浏览器启动成功 (PID: $pid)"
        # 关闭浏览器
        kill "$pid" 2>/dev/null
        return 0
    else
        log_error "浏览器启动失败"
        return 1
    fi
}

# 主函数
main() {
    local action="${1:-detect}"
    
    case "$action" in
        detect)
            # 检测最佳浏览器
            browser=$(detect_browser)
            if [ $? -eq 0 ]; then
                echo "$browser"
                show_detailed_info "$browser"
            else
                exit 1
            fi
            ;;
            
        list)
            # 列出所有浏览器
            show_all_browsers
            ;;
            
        test)
            # 测试浏览器启动
            browser=$(detect_browser)
            if [ $? -eq 0 ]; then
                test_browser_launch "$browser"
            else
                exit 1
            fi
            ;;
            
        launch)
            # 生成启动命令
            browser=$(detect_browser)
            if [ $? -eq 0 ]; then
                local url="${2:-https://example.org}"
                local enable_gpu="${3:-false}"
                generate_launch_command "$browser" "$url" "$enable_gpu"
            else
                exit 1
            fi
            ;;
            
        info)
            # 显示详细信息
            browser=$(detect_browser)
            if [ $? -eq 0 ]; then
                show_detailed_info "$browser"
                show_all_browsers
            else
                exit 1
            fi
            ;;
            
        help|--help|-h)
            # 显示帮助信息
            echo "浏览器检测脚本"
            echo
            echo "用法: $0 [命令] [参数]"
            echo
            echo "命令:"
            echo "  detect    检测最佳浏览器（默认）"
            echo "  list      列出所有可用浏览器"
            echo "  test      测试浏览器启动"
            echo "  launch URL [enable_gpu]  生成启动命令"
            echo "  info      显示详细信息"
            echo "  help      显示此帮助信息"
            echo
            echo "示例:"
            echo "  $0                    # 检测最佳浏览器"
            echo "  $0 list               # 列出所有浏览器"
            echo "  $0 test               # 测试启动"
            echo "  $0 launch https://example.org  # 生成启动命令"
            echo "  $0 launch https://example.org true  # 启用GPU"
            ;;
            
        *)
            log_error "未知命令: $action"
            echo "使用 '$0 help' 查看帮助信息"
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
