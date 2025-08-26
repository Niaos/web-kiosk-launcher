# Web Kiosk Launcher 部署指南

## 快速开始

### 方法一：一键部署（推荐）

```bash
# 1. 下载项目
git clone <repository-url>
cd web-kiosk-launcher

# 2. 运行一键部署脚本
chmod +x deploy.sh
./deploy.sh
```

一键部署脚本将自动完成：
- 检测系统环境
- 安装必要依赖
- 配置应用
- 创建系统服务
- 启动服务
- 验证功能

### 方法二：快速测试

```bash
# 1. 下载项目
git clone <repository-url>
cd web-kiosk-launcher

# 2. 运行快速部署脚本
chmod +x quick-deploy.sh
./quick-deploy.sh
```

快速部署脚本适用于：
- 开发测试
- 快速验证功能
- 不需要系统服务的场景

### 方法三：手动部署

```bash
# 1. 安装依赖
sudo apt update
sudo apt install python3 python3-pip chromium-browser xdotool wmctrl

# 2. 创建配置文件
cp config.example.env .env

# 3. 启动服务
python3 server.py
```

## 部署脚本说明

### deploy.sh（完整部署）

**功能特点：**
- 完整的系统检测和依赖安装
- 交互式配置
- 自动创建 systemd 服务
- 自动启动和验证
- 支持开机自启
- 详细的日志输出

**使用场景：**
- 生产环境部署
- 需要系统服务的场景
- 需要开机自启的场景

**配置选项：**
- 默认URL
- 监听地址和端口
- GPU加速开关
- HTTP Basic Auth
- 自启动配置

### quick-deploy.sh（快速部署）

**功能特点：**
- 简化的依赖检查
- 默认配置
- 直接启动服务
- 适合快速测试

**使用场景：**
- 开发测试
- 功能验证
- 临时使用

## 系统要求

### 基本要求
- Linux 系统（支持 Debian/Ubuntu、CentOS/Alma、Arch 等）
- Python 3.6+
- 图形环境（X11 或 Wayland）
- 至少一个支持的浏览器

### 支持的浏览器
按优先级排序：
1. chromium-browser（Ubuntu/Debian）
2. chromium（CentOS/Arch）
3. google-chrome
4. firefox
5. surf
6. luakit

### 图形环境
- X11 会话（推荐）
- Wayland 会话（通过 XWayland）
- 最小图形栈：xorg + openbox

## 安装依赖

### Ubuntu/Debian/树莓派OS
```bash
sudo apt update
sudo apt install python3 python3-pip chromium-browser xdotool wmctrl
```

### CentOS/Alma/Rocky
```bash
sudo dnf install python3 python3-pip chromium xdotool wmctrl
```

### Arch/Manjaro
```bash
sudo pacman -S python python-pip chromium xdotool wmctrl
```

## 配置说明

### 配置文件位置
- 开发模式：`./.env`
- 系统安装：`/opt/web-kiosk-launcher/.env`
- 用户安装：`~/.local/share/web-kiosk-launcher/.env`

### 主要配置项
```bash
# 服务配置
HOST=127.0.0.1          # 监听地址
PORT=8787               # 监听端口

# 默认URL
DEFAULT_URL=https://example.org

# 浏览器配置
ENABLE_GPU=false        # 是否启用GPU加速
REUSE_INSTANCE=true     # 是否复用相同URL的实例

# 安全配置
BASIC_AUTH=false        # 是否启用HTTP Basic Auth
BASIC_AUTH_USER=admin   # Basic Auth 用户名
BASIC_AUTH_PASS=password # Basic Auth 密码

# URL白名单（可选）
# ALLOW_LIST=example.com,google.com
```

## 服务管理

### 系统级服务（root安装）
```bash
# 启动服务
sudo systemctl start web-kiosk

# 停止服务
sudo systemctl stop web-kiosk

# 查看状态
sudo systemctl status web-kiosk

# 查看日志
sudo journalctl -u web-kiosk -f

# 开机自启
sudo systemctl enable web-kiosk

# 禁用开机自启
sudo systemctl disable web-kiosk
```

### 用户级服务（普通用户安装）
```bash
# 启动服务
systemctl --user start web-kiosk

# 停止服务
systemctl --user stop web-kiosk

# 查看状态
systemctl --user status web-kiosk

# 查看日志
journalctl --user -u web-kiosk -f

# 开机自启
systemctl --user enable web-kiosk

# 禁用开机自启
systemctl --user disable web-kiosk
```

## 使用方法

### Web界面
1. 打开浏览器访问：`http://127.0.0.1:8787`
2. 在输入框中输入要打开的URL
3. 点击"打开"按钮
4. 浏览器将在全屏模式下打开指定URL

### API接口
```bash
# 打开URL
curl -X POST http://127.0.0.1:8787/open -d "url=https://www.example.org"

# 关闭浏览器
curl -X POST http://127.0.0.1:8787/close
```

### 键盘快捷键
- `Ctrl+Enter` 或 `Cmd+Enter`：打开URL
- `Escape`：关闭浏览器

## 故障排除

### 常见问题

#### 1. 无DISPLAY环境变量
**症状：** 启动时提示"No display available"

**解决方案：**
```bash
# 检查DISPLAY变量
echo $DISPLAY

# 如果没有，设置DISPLAY
export DISPLAY=:0

# 或安装最小图形栈
sudo apt install xorg openbox
startx
```

#### 2. 无可用浏览器
**症状：** 启动时提示"No browser found"

**解决方案：**
```bash
# 安装Chromium
sudo apt install chromium-browser

# 或安装Firefox
sudo apt install firefox-esr
```

#### 3. 服务启动失败
**症状：** systemctl status 显示失败

**解决方案：**
```bash
# 查看详细日志
sudo journalctl -u web-kiosk -f

# 检查配置文件
cat /opt/web-kiosk-launcher/.env

# 检查权限
ls -la /opt/web-kiosk-launcher/
```

#### 4. 端口被占用
**症状：** 启动时提示端口被占用

**解决方案：**
```bash
# 查看端口占用
sudo netstat -tlnp | grep 8787

# 修改配置文件中的端口
nano .env
# 修改 PORT=8788
```

### 日志查看
```bash
# 应用日志
tail -f ~/.local/share/web-kiosk-launcher/launcher.log

# 服务日志（系统级）
sudo journalctl -u web-kiosk -f

# 服务日志（用户级）
journalctl --user -u web-kiosk -f
```

### 调试模式
```bash
# 直接运行服务器查看详细输出
python3 server.py

# 或启用详细日志
export PYTHONUNBUFFERED=1
python3 server.py
```

## 卸载

### 使用卸载脚本
```bash
cd web-kiosk-launcher
./scripts/uninstall.sh
```

### 手动卸载
```bash
# 停止服务
sudo systemctl stop web-kiosk
sudo systemctl disable web-kiosk

# 删除文件
sudo rm -rf /opt/web-kiosk-launcher
sudo rm -f /etc/systemd/system/web-kiosk.service

# 重新加载systemd
sudo systemctl daemon-reload
```

## 高级配置

### 局域网访问
```bash
# 修改配置文件
HOST=0.0.0.0

# 启用Basic Auth
BASIC_AUTH=true
BASIC_AUTH_USER=admin
BASIC_AUTH_PASS=your_secure_password
```

### URL白名单
```bash
# 只允许访问特定域名
ALLOW_LIST=example.com,google.com,github.com
```

### ARM设备优化
```bash
# 禁用GPU加速
ENABLE_GPU=false

# 降低分辨率（在浏览器启动参数中添加）
# --window-size=1024,768
```

### 自启动配置
```bash
# 复制自启动文件
cp autostart/web-kiosk-autostart.desktop ~/.config/autostart/

# 编辑默认URL
nano ~/.config/autostart/web-kiosk-autostart.desktop
```

## 性能优化

### 内存优化
- 禁用GPU加速：`ENABLE_GPU=false`
- 启用实例复用：`REUSE_INSTANCE=true`
- 使用轻量浏览器：surf、luakit

### 启动优化
- 使用SSD存储
- 预加载常用URL
- 配置浏览器缓存

### 网络优化
- 使用本地DNS
- 配置代理（如需要）
- 启用HTTP/2

## 安全建议

### 基本安全
- 使用HTTPS URL
- 启用Basic Auth（如需要）
- 配置URL白名单
- 定期更新依赖

### 网络安全
- 限制访问IP
- 使用防火墙
- 监控访问日志
- 定期备份配置

### 系统安全
- 使用非root用户运行
- 限制文件权限
- 启用SELinux（如适用）
- 定期安全更新
