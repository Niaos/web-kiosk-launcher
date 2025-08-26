#!/usr/bin/env python3
"""
Web Kiosk Launcher 测试脚本
用于验证项目的基本功能
"""

import os
import sys
import subprocess
import tempfile
import shutil
from pathlib import Path

def test_imports():
    """测试导入"""
    print("测试导入...")
    try:
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
        print("✓ 所有模块导入成功")
        return True
    except ImportError as e:
        print(f"✗ 导入失败: {e}")
        return False

def test_python_version():
    """测试Python版本"""
    print("测试Python版本...")
    version = sys.version_info
    if version.major >= 3 and version.minor >= 6:
        print(f"✓ Python版本: {version.major}.{version.minor}.{version.micro}")
        return True
    else:
        print(f"✗ Python版本过低: {version.major}.{version.minor}.{version.micro}")
        return False

def test_file_structure():
    """测试文件结构"""
    print("测试文件结构...")
    required_files = [
        'server.py',
        'README.md',
        'config.example.env',
        'static/index.html',
        'static/style.css',
        'static/app.js',
        'scripts/install.sh',
        'scripts/uninstall.sh',
        'scripts/detect_browser.sh',
        'systemd/web-kiosk.service',
        'autostart/web-kiosk-autostart.desktop'
    ]
    
    missing_files = []
    for file_path in required_files:
        if not Path(file_path).exists():
            missing_files.append(file_path)
    
    if missing_files:
        print(f"✗ 缺少文件: {missing_files}")
        return False
    else:
        print("✓ 所有必需文件存在")
        return True

def test_server_syntax():
    """测试服务器语法"""
    print("测试服务器语法...")
    try:
        result = subprocess.run([sys.executable, '-m', 'py_compile', 'server.py'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("✓ 服务器语法正确")
            return True
        else:
            print(f"✗ 服务器语法错误: {result.stderr}")
            return False
    except Exception as e:
        print(f"✗ 语法检查失败: {e}")
        return False

def test_config_loading():
    """测试配置加载"""
    print("测试配置加载...")
    try:
        # 创建临时配置文件
        with tempfile.NamedTemporaryFile(mode='w', suffix='.env', delete=False) as f:
            f.write("HOST=127.0.0.1\nPORT=8787\nDEFAULT_URL=https://test.example.org\n")
            temp_env = f.name
        
        # 临时设置环境变量
        original_env = os.environ.copy()
        os.environ['HOST'] = '127.0.0.1'
        os.environ['PORT'] = '8787'
        os.environ['DEFAULT_URL'] = 'https://test.example.org'
        
        # 导入并测试配置类
        sys.path.insert(0, '.')
        from server import Config
        
        config = Config()
        
        # 验证配置
        if (config.host == '127.0.0.1' and 
            config.port == 8787 and 
            config.default_url == 'https://test.example.org'):
            print("✓ 配置加载正确")
            result = True
        else:
            print("✗ 配置加载错误")
            result = False
        
        # 清理
        os.environ.clear()
        os.environ.update(original_env)
        os.unlink(temp_env)
        
        return result
        
    except Exception as e:
        print(f"✗ 配置测试失败: {e}")
        return False

def test_url_validation():
    """测试URL验证"""
    print("测试URL验证...")
    try:
        sys.path.insert(0, '.')
        from server import BrowserManager, Config
        
        config = Config()
        browser_manager = BrowserManager(config)
        
        # 测试有效URL
        valid_urls = [
            'https://example.org',
            'http://localhost:8080',
            'https://www.google.com/search?q=test'
        ]
        
        # 测试无效URL
        invalid_urls = [
            '',
            'not-a-url',
            'ftp://example.org',
            'file:///etc/passwd'
        ]
        
        for url in valid_urls:
            if not browser_manager._validate_url(url):
                print(f"✗ 有效URL被误判: {url}")
                return False
        
        for url in invalid_urls:
            if browser_manager._validate_url(url):
                print(f"✗ 无效URL被误判: {url}")
                return False
        
        print("✓ URL验证正确")
        return True
        
    except Exception as e:
        print(f"✗ URL验证测试失败: {e}")
        return False

def test_script_permissions():
    """测试脚本权限"""
    print("测试脚本权限...")
    scripts = [
        'scripts/install.sh',
        'scripts/uninstall.sh',
        'scripts/detect_browser.sh'
    ]
    
    for script in scripts:
        if not os.access(script, os.X_OK):
            print(f"✗ 脚本无执行权限: {script}")
            return False
    
    print("✓ 所有脚本有执行权限")
    return True

def main():
    """主测试函数"""
    print("=== Web Kiosk Launcher 测试 ===")
    print()
    
    tests = [
        test_python_version,
        test_imports,
        test_file_structure,
        test_server_syntax,
        test_config_loading,
        test_url_validation,
        test_script_permissions
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        try:
            if test():
                passed += 1
        except Exception as e:
            print(f"✗ 测试异常: {e}")
        print()
    
    print("=== 测试结果 ===")
    print(f"通过: {passed}/{total}")
    
    if passed == total:
        print("🎉 所有测试通过！项目准备就绪。")
        return 0
    else:
        print("❌ 部分测试失败，请检查上述错误。")
        return 1

if __name__ == '__main__':
    sys.exit(main())
