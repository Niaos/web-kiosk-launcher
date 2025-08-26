# Web Kiosk Launcher

一个极简的本地Web服务，用于在Linux系统上通过浏览器全屏打开指定URL。

## 功能特性

- 🖥️ 极简Web界面，输入URL即可全屏打开
- 🚀 低内存占用，适配ARM和x86_64架构
- 🔄 自动管理浏览器实例，避免重复启动
- 🛡️ 支持X11和Wayland（通过XWayland）
- ⚡ 一键安装脚本和systemd服务配置
- 🔒 可选HTTP Basic Auth保护
- 📝 完整的日志记录

## 系统要求

- Linux系统（支持Debian/Ubuntu、CentOS/Alma、Arch等）
- Python 3.6+
- 图形环境（X11或Wayland）
- 至少一个浏览器（Chromium/Chrome、Firefox、surf、luakit）

## 快速安装

### 一键安装（推荐）

```bash
git clone <repository-url>
cd web-kiosk-launcher
chmod +x scripts/install.sh
./scripts/install.sh
```

### 手动安装

#### Debian/Ubuntu/树莓派OS

```bash
# 安装依赖
sudo apt update
sudo apt install python3 python3-pip chromium-browser xdotool wmctrl

# 安装最小图形栈（如需要）
sudo apt install xorg openbox

# 启动服务
sudo systemctl enable web-kiosk
sudo systemctl start web-kiosk
```

#### CentOS/Alma/Rocky

```bash
# 安装依赖
sudo dnf install python3 python3-pip chromium xdotool wmctrl

# 安装最小图形栈（如需要）
sudo dnf install xorg-x11-server-Xorg openbox

# 启动服务
sudo systemctl enable web-kiosk
sudo systemctl start web-kiosk
```

#### Arch/Manjaro

```bash
# 安装依赖
sudo pacman -S python python-pip chromium xdotool wmctrl

# 安装最小图形栈（如需要）
sudo pacman -S xorg-server openbox

# 启动服务
sudo systemctl enable web-kiosk
sudo systemctl start web-kiosk
```

## 使用方法

### 启动服务

```bash
# 系统级服务
sudo systemctl start web-kiosk

# 或用户级服务
systemctl --user start web-kiosk
```

### 访问Web界面

打开浏览器访问：http://127.0.0.1:8787

### 基本操作

1. 在输入框中输入要打开的URL
2. 点击"打开"按钮
3. 浏览器将在全屏模式下打开指定URL
4. 使用"关闭当前页面"按钮关闭浏览器

### 配置选项

复制配置文件：

```bash
cp config.example.env .env
```

编辑 `.env` 文件：

```bash
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

# URL白名单（可选）
ALLOW_LIST=example.com,google.com
```

## API接口

### GET /
返回Web界面HTML页面

### POST /open
打开指定URL

参数：
- `url` (必填): 要打开的URL

响应：
```json
{
  "ok": true,
  "launched": "https://example.org",
  "browser": "chromium-browser"
}
```

### POST /close
关闭当前浏览器实例

响应：
```json
{
  "ok": true,
  "message": "Browser closed"
}
```

## 故障排除

### 常见问题

#### 1. 无DISPLAY环境变量

**症状**: 启动时提示"No DISPLAY available"

**解决方案**:
```bash
# 检查DISPLAY变量
echo $DISPLAY

# 如果没有，设置DISPLAY
export DISPLAY=:0

# 或安装最小图形栈
sudo apt install xorg openbox
```

#### 2. 无可用浏览器

**症状**: 启动时提示"No browser found"

**解决方案**:
```bash
# 安装Chromium
sudo apt install chromium-browser

# 或安装Firefox
sudo apt install firefox-esr
```

#### 3. Wayland环境

**症状**: 在Wayland会话中无法正常显示

**解决方案**:
```bash
# 使用XWayland
export DISPLAY=:0
export XDG_SESSION_TYPE=x11

# 或使用Firefox的kiosk模式
```

#### 4. 权限问题

**症状**: systemd服务启动失败

**解决方案**:
```bash
# 检查服务状态
sudo systemctl status web-kiosk

# 查看日志
sudo journalctl -u web-kiosk -f

# 确保文件权限正确
sudo chown -R www-data:www-data /opt/web-kiosk-launcher
```

### 日志查看

```bash
# 查看服务日志
sudo journalctl -u web-kiosk -f

# 查看应用日志
tail -f ~/.local/share/web-kiosk-launcher/launcher.log
```

### 资源监控

```bash
# 查看进程
ps aux | grep web-kiosk

# 查看内存使用
pmap $(pgrep -f web-kiosk)

# 实时监控
htop
```

## 高级配置

### Kiosk模式

要启用开机自动打开默认URL：

```bash
# 复制autostart文件
cp autostart/web-kiosk-autostart.desktop ~/.config/autostart/

# 编辑文件设置默认URL
nano ~/.config/autostart/web-kiosk-autostart.desktop
```

### 网络访问

要允许局域网访问：

```bash
# 编辑.env文件
HOST=0.0.0.0

# 启用Basic Auth
BASIC_AUTH=true
BASIC_AUTH_USER=admin
BASIC_AUTH_PASS=your_password
```

### ARM设备优化

对于树莓派等ARM设备：

```bash
# 禁用GPU加速
ENABLE_GPU=false

# 降低分辨率
# 在浏览器启动参数中添加 --window-size=1024,768
```

## 卸载

```bash
# 运行卸载脚本
./scripts/uninstall.sh

# 或手动卸载
sudo systemctl stop web-kiosk
sudo systemctl disable web-kiosk
sudo rm -rf /opt/web-kiosk-launcher
```

## 开发

### 本地开发

```bash
# 克隆项目
git clone <repository-url>
cd web-kiosk-launcher

# 安装依赖
pip install -r requirements.txt

# 运行开发服务器
python server.py
```

### 项目结构

```
web-kiosk-launcher/
├── README.md              # 项目文档
├── server.py              # 主服务器
├── static/                # 静态文件
│   ├── index.html         # Web界面
│   ├── style.css          # 样式
│   └── app.js             # 前端逻辑
├── scripts/               # 安装脚本
│   ├── install.sh         # 安装脚本
│   ├── uninstall.sh       # 卸载脚本
│   └── detect_browser.sh  # 浏览器检测
├── systemd/               # systemd配置
│   └── web-kiosk.service  # 服务文件
├── autostart/             # 自启动配置
│   └── web-kiosk-autostart.desktop
├── config.example.env     # 配置示例
└── .env                   # 运行配置
```

## 许可证



## 贡献

欢迎提交Issue和Pull Request！
