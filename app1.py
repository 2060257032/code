# 创建全新的app.py文件，添加Web界面
cat > app.py << 'EOF'
from flask import Flask, render_template, jsonify, request
import redis
import datetime
import time

# 创建Flask应用
app = Flask(__name__)

# 连接Redis数据库
redis_client = redis.Redis(host='localhost', port=6379)

# 初始化计数器（如果不存在）
if not redis_client.exists('visitor_count'):
    redis_client.set('visitor_count', 0)

# ============ 基本功能页面 ============

@app.route('/')
def home():
    """首页 - 简单欢迎页面"""
    count = redis_client.incr('visitor_count')
    return f'Hello! Visitor count: {count}'

# ============ 仪表板页面 ============

@app.route('/dashboard')
def dashboard():
    """主仪表板页面 - 可视化统计"""
    count = redis_client.get('visitor_count') or 0
    count = int(count)
    
    # 获取最近访问时间
    last_visit = redis_client.get('last_visit') or '从未访问'
    if last_visit != '从未访问':
        last_visit = time.ctime(float(last_visit))
    
    return render_template_string(dashboard_html, 
                                 count=count,
                                 last_visit=last_visit,
                                 server_time=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

# ============ API接口 ============

@app.route('/api/visitors')
def api_visitors():
    """获取访问计数API"""
    count = redis_client.get('visitor_count') or 0
    return jsonify({
        'visitor_count': int(count),
        'timestamp': datetime.datetime.now().isoformat()
    })

@app.route('/api/stats')
def api_stats():
    """获取详细统计API"""
    count = redis_client.get('visitor_count') or 0
    uptime_seconds = int(time.time() - app_start_time)
    
    # 转换为易读格式
    hours, remainder = divmod(uptime_seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    uptime_str = f"{hours}小时{minutes}分钟{seconds}秒"
    
    return jsonify({
        'visitor_count': int(count),
        'server_time': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        'uptime': uptime_str,
        'status': 'running',
        'redis_connected': redis_client.ping()
    })

@app.route('/health')
def health():
    """健康检查接口"""
    try:
        redis_ok = redis_client.ping()
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.datetime.now().isoformat(),
            'services': {
                'redis': 'connected' if redis_ok else 'disconnected',
                'web': 'running'
            }
        })
    except:
        return jsonify({
            'status': 'unhealthy',
            'error': 'Redis connection failed'
        }), 500

# ============ 管理功能 ============

@app.route('/api/reset', methods=['POST'])
def reset_counter():
    """重置计数器"""
    redis_client.set('visitor_count', 0)
    redis_client.set('last_reset', time.time())
    return jsonify({
        'status': 'success',
        'message': '计数器已重置为0',
        'timestamp': datetime.datetime.now().isoformat()
    })

@app.route('/api/record_visit', methods=['POST'])
def record_visit():
    """记录访问"""
    redis_client.incr('visitor_count')
    redis_client.set('last_visit', time.time())
    return jsonify({
        'status': 'success',
        'new_count': int(redis_client.get('visitor_count') or 0)
    })

# ============ 错误处理 ============

@app.errorhandler(404)
def page_not_found(e):
    return jsonify({
        'error': '页面不存在',
        'code': 404,
        'message': '请求的URL未找到'
    }), 404

@app.errorhandler(500)
def internal_server_error(e):
    return jsonify({
        'error': '服务器内部错误',
        'code': 500,
        'message': '服务器遇到意外错误'
    }), 500

# ============ 仪表板HTML模板 ============

dashboard_html = '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>云测试平台 - 仪表板</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Segoe UI', 'Microsoft YaHei', sans-serif;
        }
        
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(90deg, #4f46e5, #7c3aed);
            color: white;
            padding: 30px 40px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 15px;
        }
        
        .header h1 i {
            font-size: 2.2rem;
        }
        
        .subtitle {
            font-size: 1.1rem;
            opacity: 0.9;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 25px;
            padding: 40px;
        }
        
        .stat-card {
            background: white;
            border-radius: 15px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08);
            border: 1px solid #e5e7eb;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.15);
        }
        
        .stat-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: linear-gradient(90deg, #4f46e5, #7c3aed);
        }
        
        .stat-icon {
            width: 60px;
            height: 60px;
            background: linear-gradient(135deg, #4f46e5, #7c3aed);
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 20px;
            color: white;
            font-size: 1.8rem;
        }
        
        .stat-title {
            font-size: 1rem;
            color: #6b7280;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 10px;
            font-weight: 600;
        }
        
        .stat-value {
            font-size: 3rem;
            font-weight: 800;
            color: #1f2937;
            margin-bottom: 5px;
            line-height: 1;
        }
        
        .stat-unit {
            font-size: 1rem;
            color: #9ca3af;
        }
        
        .stat-description {
            color: #6b7280;
            font-size: 0.95rem;
            margin-top: 15px;
            line-height: 1.5;
        }
        
        .controls {
            display: flex;
            gap: 15px;
            margin-top: 25px;
            flex-wrap: wrap;
        }
        
        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 10px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 1rem;
            display: inline-flex;
            align-items: center;
            gap: 8px;
        }
        
        .btn-primary {
            background: linear-gradient(90deg, #4f46e5, #7c3aed);
            color: white;
        }
        
        .btn-primary:hover {
            background: linear-gradient(90deg, #4338ca, #6d28d9);
            transform: scale(1.05);
        }
        
        .btn-secondary {
            background: #f3f4f6;
            color: #374151;
        }
        
        .btn-secondary:hover {
            background: #e5e7eb;
            transform: scale(1.05);
        }
        
        .btn-danger {
            background: linear-gradient(90deg, #ef4444, #dc2626);
            color: white;
        }
        
        .btn-danger:hover {
            background: linear-gradient(90deg, #dc2626, #b91c1c);
            transform: scale(1.05);
        }
        
        .footer {
            text-align: center;
            padding: 30px;
            color: #6b7280;
            border-top: 1px solid #e5e7eb;
            background: #f9fafb;
        }
        
        .footer a {
            color: #4f46e5;
            text-decoration: none;
            font-weight: 600;
        }
        
        .footer a:hover {
            text-decoration: underline;
        }
        
        .status-badge {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.85rem;
            font-weight: 600;
            margin-left: 10px;
        }
        
        .status-online {
            background: #d1fae5;
            color: #065f46;
        }
        
        .status-offline {
            background: #fee2e2;
            color: #991b1b;
        }
        
        @media (max-width: 768px) {
            .header h1 {
                font-size: 2rem;
            }
            
            .stats-grid {
                padding: 20px;
                grid-template-columns: 1fr;
            }
            
            .stat-value {
                font-size: 2.5rem;
            }
        }
        
        .loading {
            display: none;
            text-align: center;
            padding: 20px;
            color: #6b7280;
        }
        
        .loading.active {
            display: block;
        }
    </style>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>
                <i class="fas fa-cloud"></i>
                云测试平台 - 仪表板
            </h1>
            <p class="subtitle">基于KVM与Docker的CI/CD自动化测试平台</p>
        </header>
        
        <div class="loading" id="loading">
            <i class="fas fa-spinner fa-spin fa-2x"></i>
            <p style="margin-top: 10px;">加载数据中...</p>
        </div>
        
        <div class="stats-grid" id="statsGrid">
            <!-- 卡片1：访问统计 -->
            <div class="stat-card">
                <div class="stat-icon">
                    <i class="fas fa-users"></i>
                </div>
                <div class="stat-title">总访问量</div>
                <div class="stat-value" id="visitorCount">{{ count }}</div>
                <div class="stat-unit">次访问</div>
                <div class="stat-description">
                    自服务启动以来的总访问次数。每次刷新页面或调用API都会增加计数。
                </div>
                <div class="controls">
                    <button class="btn btn-primary" onclick="refreshData()">
                        <i class="fas fa-sync-alt"></i> 刷新数据
                    </button>
                    <button class="btn btn-secondary" onclick="simulateVisit()">
                        <i class="fas fa-mouse-pointer"></i> 模拟访问
                    </button>
                </div>
            </div>
            
            <!-- 卡片2：系统状态 -->
            <div class="stat-card">
                <div class="stat-icon">
                    <i class="fas fa-server"></i>
                </div>
                <div class="stat-title">系统状态</div>
                <div class="stat-value" id="systemStatus">正常</div>
                <div class="stat-unit">
                    <span class="status-badge status-online" id="statusBadge">在线</span>
                </div>
                <div class="stat-description">
                    <div>服务器时间: <span id="serverTime">{{ server_time }}</span></div>
                    <div>最后访问: <span id="lastVisit">{{ last_visit }}</span></div>
                    <div>运行时长: <span id="uptime">计算中...</span></div>
                </div>
                <div class="controls">
                    <button class="btn btn-primary" onclick="checkHealth()">
                        <i class="fas fa-heartbeat"></i> 健康检查
                    </button>
                    <button class="btn btn-secondary" onclick="showStats()">
                        <i class="fas fa-chart-bar"></i> 详细统计
                    </button>
                </div>
            </div>
            
            <!-- 卡片3：平台信息 -->
            <div class="stat-card">
                <div class="stat-icon">
                    <i class="fas fa-code"></i>
                </div>
                <div class="stat-title">平台信息</div>
                <div class="stat-value">v1.0</div>
                <div class="stat-unit">当前版本</div>
                <div class="stat-description">
                    <strong>技术栈:</strong><br>
                    • Python Flask + Redis<br>
                    • Docker容器化<br>
                    • KVM虚拟化<br>
                    • 自动化测试
                </div>
                <div class="controls">
                    <button class="btn btn-danger" onclick="resetCounter()">
                        <i class="fas fa-redo"></i> 重置计数器
                    </button>
                    <button class="btn btn-secondary" onclick="goToHome()">
                        <i class="fas fa-home"></i> 返回首页
                    </button>
                </div>
            </div>
        </div>
        
        <footer class="footer">
            <p>
                <i class="fas fa-copyright"></i> 2025 云测试平台项目
                | 基于KVM与Docker的CI/CD自动化测试平台
                | <a href="/">首页</a> | <a href="/api/visitors">API</a> | <a href="/health">健康检查</a>
            </p>
            <p style="margin-top: 10px; font-size: 0.9rem;">
                <i class="fas fa-info-circle"></i>
                仪表板每30秒自动刷新数据 | 最后更新: <span id="lastUpdate">刚刚</span>
            </p>
        </footer>
    </div>
    
    <script>
        // 页面加载完成后执行
        document.addEventListener('DOMContentLoaded', function() {
            // 显示加载中
            document.getElementById('loading').classList.add('active');
            
            // 初始加载数据
            loadStats();
            
            // 设置定时刷新（每30秒）
            setInterval(loadStats, 30000);
            
            // 更新最后更新时间
            updateLastUpdateTime();
        });
        
        // 加载统计数据
        function loadStats() {
            fetch('/api/stats')
                .then(response => response.json())
                .then(data => {
                    // 更新访问计数
                    document.getElementById('visitorCount').textContent = data.visitor_count;
                    
                    // 更新服务器时间
                    document.getElementById('serverTime').textContent = data.server_time;
                    
                    // 更新运行时长
                    document.getElementById('uptime').textContent = data.uptime;
                    
                    // 更新系统状态
                    document.getElementById('systemStatus').textContent = data.status === 'running' ? '正常' : '异常';
                    document.getElementById('statusBadge').textContent = data.status === 'running' ? '在线' : '离线';
                    document.getElementById('statusBadge').className = data.status === 'running' ? 
                        'status-badge status-online' : 'status-badge status-offline';
                    
                    // 隐藏加载中
                    document.getElementById('loading').classList.remove('active');
                    
                    // 更新最后更新时间
                    updateLastUpdateTime();
                })
                .catch(error => {
                    console.error('加载数据失败:', error);
                    document.getElementById('loading').innerHTML = 
                        '<i class="fas fa-exclamation-triangle"></i><p>加载失败，请检查网络连接</p>';
                });
        }
        
        // 刷新数据
        function refreshData() {
            document.getElementById('loading').classList.add('active');
            loadStats();
        }
        
        // 模拟访问
        function simulateVisit() {
            fetch('/api/record_visit', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    alert(`模拟访问成功！新计数: ${data.new_count}`);
                    loadStats();
                })
                .catch(error => {
                    alert('模拟访问失败: ' + error);
                });
        }
        
        // 健康检查
        function checkHealth() {
            fetch('/health')
                .then(response => response.json())
                .then(data => {
                    const status = data.status === 'healthy' ? '健康' : '异常';
                    const redisStatus = data.services.redis === 'connected' ? '已连接' : '未连接';
                    alert(`健康检查结果:\n状态: ${status}\nRedis: ${redisStatus}\n时间: ${data.timestamp}`);
                })
                .catch(error => {
                    alert('健康检查失败: ' + error);
                });
        }
        
        // 显示详细统计
        function showStats() {
            fetch('/api/stats')
                .then(response => response.json())
                .then(data => {
                    const statsText = `📊 详细统计信息:\n\n` +
                                    `访问计数: ${data.visitor_count}\n` +
                                    `服务器时间: ${data.server_time}\n` +
                                    `运行时长: ${data.uptime}\n` +
                                    `系统状态: ${data.status}\n` +
                                    `Redis连接: ${data.redis_connected ? '正常' : '异常'}`;
                    alert(statsText);
                })
                .catch(error => {
                    alert('获取统计信息失败: ' + error);
                });
        }
        
        // 重置计数器
        function resetCounter() {
            if (confirm('确定要重置访问计数器吗？这将把计数归零。')) {
                fetch('/api/reset', { method: 'POST' })
                    .then(response => response.json())
                    .then(data => {
                        alert(data.message);
                        loadStats();
                    })
                    .catch(error => {
                        alert('重置失败: ' + error);
                    });
            }
        }
        
        // 返回首页
        function goToHome() {
            window.location.href = '/';
        }
        
        // 更新最后更新时间
        function updateLastUpdateTime() {
            const now = new Date();
            const timeStr = now.toLocaleTimeString('zh-CN', { 
                hour: '2-digit', 
                minute: '2-digit',
                second: '2-digit'
            });
            document.getElementById('lastUpdate').textContent = timeStr;
        }
        
        // 键盘快捷键
        document.addEventListener('keydown', function(event) {
            // F5 刷新
            if (event.key === 'F5') {
                event.preventDefault();
                refreshData();
            }
            // Ctrl+R 刷新
            if (event.ctrlKey && event.key === 'r') {
                event.preventDefault();
                refreshData();
            }
        });
    </script>
</body>
</html>
'''

# ============ 应用启动 ============

if __name__ == '__main__':
    # 记录应用启动时间
    app_start_time = time.time()
    
    print("=" * 60)
    print("🚀 云测试平台启动中...")
    print("📡 访问地址: http://localhost:5000")
    print("📊 仪表板: http://localhost:5000/dashboard")
    print("🔧 API文档: http://localhost:5000/api/visitors")
    print("🏥 健康检查: http://localhost:5000/health")
    print("=" * 60)
    
    # 启动Flask应用
    app.run(
        host='0.0.0.0',  # 监听所有网络接口
        port=5000,       # 端口号
        debug=True,      # 调试模式（生产环境应设为False）
        threaded=True    # 多线程支持
    )
EOF
