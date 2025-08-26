/**
 * Web Kiosk Launcher 前端逻辑
 */

class WebKioskApp {
    constructor() {
        this.urlInput = document.getElementById('url-input');
        this.openBtn = document.getElementById('open-btn');
        this.closeBtn = document.getElementById('close-btn');
        this.fullscreenToggle = document.getElementById('fullscreen-toggle');
        this.statusDiv = document.getElementById('status');
        
        this.init();
    }
    
    init() {
        // 绑定事件
        this.openBtn.addEventListener('click', () => this.openUrl());
        this.closeBtn.addEventListener('click', () => this.closeBrowser());
        this.urlInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.openUrl();
            }
        });
        
        // 自动聚焦到输入框
        this.urlInput.focus();
        
        // 显示初始状态
        this.showStatus('准备就绪', 'info');
    }
    
    async openUrl() {
        const url = this.urlInput.value.trim();
        
        if (!url) {
            this.showStatus('请输入有效的网址', 'error');
            this.urlInput.focus();
            return;
        }
        
        if (!this.isValidUrl(url)) {
            this.showStatus('请输入有效的网址（以 http:// 或 https:// 开头）', 'error');
            this.urlInput.focus();
            return;
        }
        
        this.setLoading(true);
        
        try {
            const response = await fetch('/open', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: `url=${encodeURIComponent(url)}`
            });
            
            const data = await response.json();
            
            if (data.ok) {
                this.showStatus(`成功打开: ${data.launched}`, 'success');
                // 清空输入框
                this.urlInput.value = '';
            } else {
                this.showStatus(`打开失败: ${data.message}`, 'error');
            }
        } catch (error) {
            console.error('请求失败:', error);
            this.showStatus('网络请求失败，请检查服务器状态', 'error');
        } finally {
            this.setLoading(false);
        }
    }
    
    async closeBrowser() {
        this.setLoading(true);
        
        try {
            const response = await fetch('/close', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                }
            });
            
            const data = await response.json();
            
            if (data.ok) {
                this.showStatus('浏览器已关闭', 'success');
            } else {
                this.showStatus(`关闭失败: ${data.message}`, 'error');
            }
        } catch (error) {
            console.error('请求失败:', error);
            this.showStatus('网络请求失败，请检查服务器状态', 'error');
        } finally {
            this.setLoading(false);
        }
    }
    
    isValidUrl(url) {
        try {
            const urlObj = new URL(url);
            return urlObj.protocol === 'http:' || urlObj.protocol === 'https:';
        } catch {
            return false;
        }
    }
    
    setLoading(loading) {
        if (loading) {
            this.openBtn.disabled = true;
            this.closeBtn.disabled = true;
            this.openBtn.innerHTML = '<span class="loading"></span>处理中...';
            this.closeBtn.innerHTML = '<span class="loading"></span>处理中...';
        } else {
            this.openBtn.disabled = false;
            this.closeBtn.disabled = false;
            this.openBtn.innerHTML = '打开';
            this.closeBtn.innerHTML = '关闭当前页面';
        }
    }
    
    showStatus(message, type = 'info') {
        this.statusDiv.textContent = message;
        this.statusDiv.className = `status ${type}`;
        
        // 自动隐藏成功消息
        if (type === 'success') {
            setTimeout(() => {
                this.statusDiv.classList.add('hidden');
            }, 3000);
        } else {
            this.statusDiv.classList.remove('hidden');
        }
    }
    
    // 工具方法：显示错误
    showError(message) {
        this.showStatus(message, 'error');
    }
    
    // 工具方法：显示成功
    showSuccess(message) {
        this.showStatus(message, 'success');
    }
    
    // 工具方法：显示信息
    showInfo(message) {
        this.showStatus(message, 'info');
    }
}

// 页面加载完成后初始化应用
document.addEventListener('DOMContentLoaded', () => {
    new WebKioskApp();
});

// 添加一些键盘快捷键
document.addEventListener('keydown', (e) => {
    // Ctrl+Enter 或 Cmd+Enter 打开URL
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
        e.preventDefault();
        const app = window.webKioskApp;
        if (app) {
            app.openUrl();
        }
    }
    
    // Escape 键关闭浏览器
    if (e.key === 'Escape') {
        e.preventDefault();
        const app = window.webKioskApp;
        if (app) {
            app.closeBrowser();
        }
    }
});

// 添加网络状态检测
window.addEventListener('online', () => {
    const app = window.webKioskApp;
    if (app) {
        app.showInfo('网络连接已恢复');
    }
});

window.addEventListener('offline', () => {
    const app = window.webKioskApp;
    if (app) {
        app.showError('网络连接已断开');
    }
});
