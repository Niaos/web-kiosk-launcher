#!/usr/bin/env python3
"""
Web Kiosk Launcher Server
极简的本地Web服务，用于在Linux系统上通过浏览器全屏打开指定URL
"""

import os
import sys
import json
import time
import signal
import subprocess
import threading
from pathlib import Path
from urllib.parse import urlparse, parse_qs
from http.server import HTTPServer, BaseHTTPRequestHandler
import logging
from datetime import datetime

# 配置常量
DEFAULT_HOST = '127.0.0.1'
DEFAULT_PORT = 8787
DEFAULT_URL = 'https://example.org'
PID_FILE = '/tmp/web-kiosk-browser.pid'
LOG_DIR = Path.home() / '.local' / 'share' / 'web-kiosk-launcher'
LOG_FILE = LOG_DIR / 'launcher.log'

# 浏览器检测顺序
BROWSERS = [
    ('chromium-browser', ['--kiosk', '--noerrdialogs', '--disable-session-crashed-bubble', 
                         '--disable-infobars', '--disable-translate', '--no-first-run', 
                         '--fast', '--fast-start', '--disable-gpu', '--disable-extensions', 
                         '--start-maximized']),
    ('chromium', ['--kiosk', '--noerrdialogs', '--disable-session-crashed-bubble', 
                  '--disable-infobars', '--disable-translate', '--no-first-run', 
                  '--fast', '--fast-start', '--disable-gpu', '--disable-extensions', 
                  '--start-maximized']),
    ('google-chrome', ['--kiosk', '--noerrdialogs', '--disable-session-crashed-bubble', 
                       '--disable-infobars', '--disable-translate', '--no-first-run', 
                       '--fast', '--fast-start', '--disable-gpu', '--disable-extensions', 
                       '--start-maximized']),
    ('firefox', ['--kiosk']),
    ('surf', ['-f']),
    ('luakit', ['-c', 'fullscreen'])
]

class Config:
    """配置管理类"""
    
    def __init__(self):
        self.host = DEFAULT_HOST
        self.port = DEFAULT_PORT
        self.default_url = DEFAULT_URL
        self.enable_gpu = False
        self.reuse_instance = True
        self.basic_auth = False
        self.basic_auth_user = 'admin'
        self.basic_auth_pass = 'password'
        self.allow_list = []
        self._load_env()
    
    def _load_env(self):
        """从环境变量和.env文件加载配置"""
        # 加载.env文件
        env_file = Path('.env')
        if env_file.exists():
            with open(env_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        os.environ[key] = value
        
        # 从环境变量读取配置
        self.host = os.environ.get('HOST', self.host)
        self.port = int(os.environ.get('PORT', self.port))
        self.default_url = os.environ.get('DEFAULT_URL', self.default_url)
        self.enable_gpu = os.environ.get('ENABLE_GPU', 'false').lower() == 'true'
        self.reuse_instance = os.environ.get('REUSE_INSTANCE', 'true').lower() == 'true'
        self.basic_auth = os.environ.get('BASIC_AUTH', 'false').lower() == 'true'
        self.basic_auth_user = os.environ.get('BASIC_AUTH_USER', self.basic_auth_user)
        self.basic_auth_pass = os.environ.get('BASIC_AUTH_PASS', self.basic_auth_pass)
        
        allow_list_str = os.environ.get('ALLOW_LIST', '')
        if allow_list_str:
            self.allow_list = [domain.strip() for domain in allow_list_str.split(',')]

class BrowserManager:
    """浏览器管理类"""
    
    def __init__(self, config):
        self.config = config
        self.current_pid = None
        self.current_url = None
        self.browser_cmd = None
        self._detect_browser()
    
    def _detect_browser(self):
        """检测可用的浏览器"""
        for browser_name, default_args in BROWSERS:
            try:
                result = subprocess.run(['which', browser_name], 
                                      capture_output=True, text=True, check=True)
                self.browser_cmd = browser_name
                self.browser_args = default_args
                
                # 根据GPU配置调整参数
                if not self.config.enable_gpu:
                    self.browser_args = [arg for arg in self.browser_args 
                                        if not arg.startswith('--enable-gpu')]
                    if '--disable-gpu' not in self.browser_args:
                        self.browser_args.append('--disable-gpu')
                
                logging.info(f"Detected browser: {browser_name}")
                return
            except subprocess.CalledProcessError:
                continue
        
        logging.error("No browser found")
        self.browser_cmd = None
    
    def _get_browser_pid(self):
        """获取当前浏览器进程PID"""
        if not os.path.exists(PID_FILE):
            return None
        
        try:
            with open(PID_FILE, 'r') as f:
                pid = int(f.read().strip())
            
            # 检查进程是否还存在
            try:
                os.kill(pid, 0)
                return pid
            except OSError:
                # 进程不存在，删除PID文件
                os.remove(PID_FILE)
                return None
        except (ValueError, IOError):
            return None
    
    def _save_browser_pid(self, pid):
        """保存浏览器进程PID"""
        with open(PID_FILE, 'w') as f:
            f.write(str(pid))
        self.current_pid = pid
    
    def _kill_browser(self, timeout=5):
        """关闭浏览器进程"""
        pid = self._get_browser_pid()
        if not pid:
            return True
        
        try:
            # 发送SIGTERM
            os.kill(pid, signal.SIGTERM)
            
            # 等待进程结束
            start_time = time.time()
            while time.time() - start_time < timeout:
                try:
                    os.kill(pid, 0)
                    time.sleep(0.1)
                except OSError:
                    # 进程已结束
                    break
            
            # 如果进程仍在运行，发送SIGKILL
            try:
                os.kill(pid, signal.SIGKILL)
                logging.info(f"Force killed browser process {pid}")
            except OSError:
                pass
            
            # 清理PID文件
            if os.path.exists(PID_FILE):
                os.remove(PID_FILE)
            
            self.current_pid = None
            self.current_url = None
            return True
            
        except OSError as e:
            logging.error(f"Failed to kill browser process: {e}")
            return False
    
    def open_url(self, url):
        """打开指定URL"""
        # 验证URL
        if not self._validate_url(url):
            return False, "Invalid URL"
        
        # 检查白名单
        if self.config.allow_list and not self._check_whitelist(url):
            return False, "URL not in whitelist"
        
        # 检查是否复用实例
        if (self.config.reuse_instance and 
            self.current_url == url and 
            self._get_browser_pid()):
            return True, "URL already open"
        
        # 关闭现有浏览器
        self._kill_browser()
        
        # 检查显示环境
        if not self._check_display():
            return False, "No display available"
        
        # 启动浏览器
        try:
            cmd = [self.browser_cmd] + self.browser_args + [url]
            process = subprocess.Popen(cmd, close_fds=True)
            
            self._save_browser_pid(process.pid)
            self.current_url = url
            
            logging.info(f"Launched browser {self.browser_cmd} with PID {process.pid} for URL {url}")
            return True, f"Launched {self.browser_cmd}"
            
        except Exception as e:
            logging.error(f"Failed to launch browser: {e}")
            return False, f"Failed to launch browser: {e}"
    
    def close_browser(self):
        """关闭浏览器"""
        success = self._kill_browser()
        if success:
            logging.info("Browser closed successfully")
            return True, "Browser closed"
        else:
            return False, "Failed to close browser"
    
    def _validate_url(self, url):
        """验证URL格式"""
        if not url:
            return False
        
        if not url.startswith(('http://', 'https://')):
            return False
        
        try:
            parsed = urlparse(url)
            return bool(parsed.netloc)
        except:
            return False
    
    def _check_whitelist(self, url):
        """检查URL是否在白名单中"""
        if not self.config.allow_list:
            return True
        
        try:
            domain = urlparse(url).netloc
            return any(allowed in domain for allowed in self.config.allow_list)
        except:
            return False
    
    def _check_display(self):
        """检查显示环境"""
        display = os.environ.get('DISPLAY')
        if not display:
            return False
        
        # 检查X11服务器是否运行
        try:
            subprocess.run(['xset', 'q'], capture_output=True, check=True, timeout=5)
            return True
        except:
            return False

class WebKioskHandler(BaseHTTPRequestHandler):
    """HTTP请求处理器"""
    
    def __init__(self, *args, browser_manager=None, config=None, **kwargs):
        self.browser_manager = browser_manager
        self.config = config
        super().__init__(*args, **kwargs)
    
    def do_GET(self):
        """处理GET请求"""
        if self.path == '/':
            self._serve_index()
        elif self.path.startswith('/static/'):
            self._serve_static()
        else:
            self._send_error(404, "Not Found")
    
    def do_POST(self):
        """处理POST请求"""
        if self.path == '/open':
            self._handle_open()
        elif self.path == '/close':
            self._handle_close()
        else:
            self._send_error(404, "Not Found")
    
    def _serve_index(self):
        """提供主页"""
        try:
            with open('static/index.html', 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 替换默认URL
            content = content.replace('{{DEFAULT_URL}}', self.config.default_url)
            
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(content.encode('utf-8'))
            
        except Exception as e:
            logging.error(f"Failed to serve index: {e}")
            self._send_error(500, "Internal Server Error")
    
    def _serve_static(self):
        """提供静态文件"""
        try:
            file_path = self.path[1:]  # 移除开头的'/'
            
            if file_path.endswith('.css'):
                content_type = 'text/css'
            elif file_path.endswith('.js'):
                content_type = 'application/javascript'
            else:
                content_type = 'text/plain'
            
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            self.send_response(200)
            self.send_header('Content-Type', f'{content_type}; charset=utf-8')
            self.end_headers()
            self.wfile.write(content.encode('utf-8'))
            
        except Exception as e:
            logging.error(f"Failed to serve static file {self.path}: {e}")
            self._send_error(404, "File Not Found")
    
    def _handle_open(self):
        """处理打开URL请求"""
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length).decode('utf-8')
            
            # 解析POST数据
            params = parse_qs(post_data)
            url = params.get('url', [''])[0]
            
            if not url:
                self._send_json_response(False, "URL is required")
                return
            
            success, message = self.browser_manager.open_url(url)
            self._send_json_response(success, message, {
                'launched': url,
                'browser': self.browser_manager.browser_cmd
            })
            
        except Exception as e:
            logging.error(f"Failed to handle open request: {e}")
            self._send_json_response(False, f"Internal error: {e}")
    
    def _handle_close(self):
        """处理关闭浏览器请求"""
        try:
            success, message = self.browser_manager.close_browser()
            self._send_json_response(success, message)
            
        except Exception as e:
            logging.error(f"Failed to handle close request: {e}")
            self._send_json_response(False, f"Internal error: {e}")
    
    def _send_json_response(self, success, message, extra_data=None):
        """发送JSON响应"""
        response = {
            'ok': success,
            'message': message
        }
        
        if extra_data:
            response.update(extra_data)
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(response).encode('utf-8'))
    
    def _send_error(self, code, message):
        """发送错误响应"""
        self.send_response(code)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.end_headers()
        self.wfile.write(message.encode('utf-8'))
    
    def log_message(self, format, *args):
        """重写日志方法"""
        logging.info(f"{self.address_string()} - {format % args}")

def setup_logging():
    """设置日志"""
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(LOG_FILE),
            logging.StreamHandler(sys.stdout)
        ]
    )

def main():
    """主函数"""
    setup_logging()
    
    # 加载配置
    config = Config()
    
    # 初始化浏览器管理器
    browser_manager = BrowserManager(config)
    
    if not browser_manager.browser_cmd:
        logging.error("No browser available. Please install chromium-browser, firefox, or another supported browser.")
        sys.exit(1)
    
    # 创建HTTP服务器
    class Handler(WebKioskHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, browser_manager=browser_manager, config=config, **kwargs)
    
    server = HTTPServer((config.host, config.port), Handler)
    
    logging.info(f"Starting Web Kiosk Launcher on {config.host}:{config.port}")
    logging.info(f"Default URL: {config.default_url}")
    logging.info(f"Browser: {browser_manager.browser_cmd}")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logging.info("Shutting down server...")
        server.shutdown()
        browser_manager.close_browser()

if __name__ == '__main__':
    main()
