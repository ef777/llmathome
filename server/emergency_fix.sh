#!/bin/bash
# websocket_fix.sh - WebSocket sorununu düzelt

echo "🔌 WebSocket Sorununu Düzeltme"
echo "=============================="

PROJECT_DIR="/var/www/kodlama-asistani"
cd "$PROJECT_DIR"

# 1. Servisi durdur
echo "🛑 Servisi durduruyor..."
sudo systemctl stop kodlama-asistani

# 2. WebSocket çalışan app.py oluştur
echo "🔧 WebSocket düzeltilmiş app.py oluşturuluyor..."
cat > app.py << 'EOF'
#!/usr/bin/env python3
from flask import Flask, jsonify
import logging
import threading
import asyncio
import websockets
import json
import uuid
from datetime import datetime
import os
import sys
import psutil
import time

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class WorkingWebSocketServer:
    def __init__(self):
        self.clients = {}
        self.stats = {"start_time": datetime.now(), "total_clients": 0}
        self.server = None
        
    async def register_client(self, websocket, client_type):
        client_id = str(uuid.uuid4())
        self.clients[client_id] = {
            "websocket": websocket,
            "type": client_type,
            "connected_at": datetime.now()
        }
        self.stats["total_clients"] += 1
        logger.info(f"✅ Client registered: {client_id[:8]} ({client_type})")
        return client_id
    
    async def unregister_client(self, client_id):
        if client_id in self.clients:
            del self.clients[client_id]
            logger.info(f"❌ Client disconnected: {client_id[:8]}")
    
    async def handle_client(self, websocket, path):
        client_id = None
        logger.info(f"🔗 New WebSocket connection from {websocket.remote_address}")
        
        try:
            async for message in websocket:
                try:
                    data = json.loads(message)
                    logger.info(f"📨 Received message: {data.get('type')}")
                    
                    if data.get("type") == "register":
                        client_type = data.get("client_type", "unknown")
                        client_id = await self.register_client(websocket, client_type)
                        response = {
                            "type": "registered",
                            "client_id": client_id,
                            "server_time": datetime.now().isoformat(),
                            "message": "Successfully connected to WebSocket server"
                        }
                        await websocket.send(json.dumps(response))
                        logger.info(f"✅ Registration response sent to {client_id[:8]}")
                        
                    elif data.get("type") == "ping":
                        response = {
                            "type": "pong",
                            "timestamp": datetime.now().isoformat()
                        }
                        await websocket.send(json.dumps(response))
                        logger.info(f"🏓 Pong sent to client")
                        
                    elif data.get("type") == "test":
                        response = {
                            "type": "test_response",
                            "message": "WebSocket test successful!",
                            "timestamp": datetime.now().isoformat()
                        }
                        await websocket.send(json.dumps(response))
                        logger.info(f"🧪 Test response sent")
                        
                except json.JSONDecodeError as e:
                    logger.error(f"❌ Invalid JSON received: {e}")
                except Exception as e:
                    logger.error(f"❌ Message handling error: {e}")
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info(f"🔌 WebSocket connection closed normally")
        except Exception as e:
            logger.error(f"❌ WebSocket error: {e}")
        finally:
            if client_id:
                await self.unregister_client(client_id)

    async def start_server(self):
        try:
            logger.info("🚀 Starting WebSocket server on 0.0.0.0:8765...")
            self.server = await websockets.serve(
                self.handle_client,
                "0.0.0.0", 
                8765,
                ping_interval=30,
                ping_timeout=10
            )
            logger.info("✅ WebSocket server started successfully on port 8765")
            return self.server
        except Exception as e:
            logger.error(f"❌ Failed to start WebSocket server: {e}")
            raise

websocket_server = None

def run_websocket_server():
    global websocket_server
    
    def websocket_thread():
        try:
            logger.info("🔄 WebSocket thread starting...")
            
            # Yeni event loop oluştur
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            websocket_server = WorkingWebSocketServer()
            
            # Server'ı başlat
            server = loop.run_until_complete(websocket_server.start_server())
            
            logger.info("🔄 WebSocket server running, waiting for connections...")
            
            # Server'ı çalışır durumda tut
            loop.run_until_complete(server.wait_closed())
            
        except Exception as e:
            logger.error(f"❌ WebSocket thread error: {e}")
            import traceback
            traceback.print_exc()
    
    # Thread'i başlat
    thread = threading.Thread(target=websocket_thread, daemon=True)
    thread.start()
    logger.info("🚀 WebSocket thread started")
    return thread

app = Flask(__name__)

@app.route('/')
def index():
    return '''
<!DOCTYPE html>
<html>
<head>
    <title>🤖 Kodlama Asistanı - WebSocket Fixed!</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial; margin: 40px; background: #f5f5f5; }
        .container { max-width: 900px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .status { padding: 15px; margin: 15px 0; border-radius: 8px; text-align: center; font-weight: bold; }
        .success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .info { background: #d1ecf1; color: #0c5460; border: 1px solid #bee5eb; }
        .warning { background: #fff3cd; color: #856404; border: 1px solid #ffeaa7; }
        .error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
        button { background: #007bff; color: white; padding: 12px 25px; border: none; border-radius: 6px; cursor: pointer; margin: 5px; font-size: 14px; }
        button:hover { background: #0056b3; }
        button:disabled { background: #6c757d; cursor: not-allowed; }
        .test-area { margin: 20px 0; padding: 20px; background: #f8f9fa; border-radius: 8px; }
        .log { background: #343a40; color: #f8f9fa; padding: 15px; border-radius: 6px; font-family: monospace; max-height: 300px; overflow-y: auto; margin: 10px 0; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        h3 { color: #495057; border-bottom: 2px solid #007bff; padding-bottom: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🤖 Kodlama Asistanı</h1>
        <h2>🔌 WebSocket Düzeltme Testi</h2>
        
        <div class="status success">
            ✅ Flask servisi çalışıyor! WebSocket sorunu düzeltildi.
        </div>
        
        <div class="grid">
            <div>
                <h3>📊 API Testleri</h3>
                <button onclick="testAPI()">🏥 Health Check</button>
                <button onclick="testStatus()">📈 Status Check</button>
                <button onclick="testSystem()">🖥️ System Info</button>
                
                <div class="test-area">
                    <h4>API Test Sonuçları:</h4>
                    <div id="api-results">Henüz test yapılmadı...</div>
                </div>
            </div>
            
            <div>
                <h3>🔌 WebSocket Testleri</h3>
                <button onclick="connectWebSocket()" id="connectBtn">🔗 Bağlan</button>
                <button onclick="sendPing()" id="pingBtn" disabled>🏓 Ping Gönder</button>
                <button onclick="sendTest()" id="testBtn" disabled>🧪 Test Mesajı</button>
                <button onclick="disconnect()" id="disconnectBtn" disabled>❌ Bağlantıyı Kes</button>
                
                <div class="status info" id="ws-status">
                    🔄 WebSocket: Henüz bağlanılmadı
                </div>
                
                <div class="test-area">
                    <h4>WebSocket Log:</h4>
                    <div class="log" id="ws-log">WebSocket logları burada görünecek...</div>
                </div>
            </div>
        </div>
        
        <div class="test-area">
            <h3>🎯 Sistem Genel Durum</h3>
            <button onclick="runFullTest()">🧪 Tam Sistem Testi</button>
            <div id="full-test-results" style="margin-top: 15px;"></div>
        </div>
    </div>

    <script>
        let ws = null;
        let wsConnected = false;
        
        function log(message, type = 'info') {
            const timestamp = new Date().toLocaleTimeString();
            const logDiv = document.getElementById('ws-log');
            const color = type === 'error' ? '#dc3545' : type === 'success' ? '#28a745' : '#17a2b8';
            logDiv.innerHTML += `<div style="color: ${color};">[${timestamp}] ${message}</div>`;
            logDiv.scrollTop = logDiv.scrollHeight;
        }
        
        function updateStatus(message, type = 'info') {
            const statusDiv = document.getElementById('ws-status');
            statusDiv.className = `status ${type}`;
            statusDiv.innerHTML = message;
        }
        
        function updateButtons() {
            document.getElementById('connectBtn').disabled = wsConnected;
            document.getElementById('pingBtn').disabled = !wsConnected;
            document.getElementById('testBtn').disabled = !wsConnected;
            document.getElementById('disconnectBtn').disabled = !wsConnected;
        }
        
        function connectWebSocket() {
            if (ws) {
                ws.close();
            }
            
            log('WebSocket bağlantısı başlatılıyor...', 'info');
            updateStatus('🔄 Bağlanıyor...', 'warning');
            
            ws = new WebSocket(`ws://${window.location.hostname}:8765`);
            
            ws.onopen = function() {
                wsConnected = true;
                log('✅ WebSocket bağlantısı başarılı!', 'success');
                updateStatus('🟢 Bağlı ve hazır!', 'success');
                updateButtons();
                
                // Register as web client
                ws.send(JSON.stringify({
                    type: 'register',
                    client_type: 'web_test_client',
                    timestamp: new Date().toISOString()
                }));
            };
            
            ws.onmessage = function(event) {
                try {
                    const data = JSON.parse(event.data);
                    log(`📨 Mesaj alındı: ${data.type}`, 'success');
                    
                    if (data.type === 'registered') {
                        log(`🎯 Client ID: ${data.client_id}`, 'info');
                    } else if (data.type === 'pong') {
                        log('🏓 Pong alındı - bağlantı sağlıklı', 'success');
                    } else if (data.type === 'test_response') {
                        log(`🧪 Test yanıtı: ${data.message}`, 'success');
                    }
                } catch (e) {
                    log(`❌ JSON parse hatası: ${e.message}`, 'error');
                }
            };
            
            ws.onclose = function(event) {
                wsConnected = false;
                log(`🔴 Bağlantı kapandı (kod: ${event.code})`, 'error');
                updateStatus('🔴 Bağlantı kapalı', 'error');
                updateButtons();
            };
            
            ws.onerror = function() {
                log('❌ WebSocket bağlantı hatası!', 'error');
                updateStatus('❌ Bağlantı hatası', 'error');
            };
        }
        
        function sendPing() {
            if (ws && wsConnected) {
                ws.send(JSON.stringify({
                    type: 'ping',
                    timestamp: new Date().toISOString()
                }));
                log('🏓 Ping gönderildi', 'info');
            }
        }
        
        function sendTest() {
            if (ws && wsConnected) {
                ws.send(JSON.stringify({
                    type: 'test',
                    message: 'Bu bir test mesajıdır',
                    timestamp: new Date().toISOString()
                }));
                log('🧪 Test mesajı gönderildi', 'info');
            }
        }
        
        function disconnect() {
            if (ws) {
                ws.close(1000, 'Manuel olarak kapatıldı');
                log('👋 Bağlantı manuel olarak kapatıldı', 'info');
            }
        }
        
        async function testAPI() {
            try {
                const response = await fetch('/api/health');
                const data = await response.json();
                document.getElementById('api-results').innerHTML = 
                    `<div class="status success">✅ Health: ${data.status} - WebSocket: ${data.websocket_server || 'unknown'}</div>`;
            } catch (error) {
                document.getElementById('api-results').innerHTML = 
                    `<div class="status error">❌ API Hatası: ${error.message}</div>`;
            }
        }
        
        async function testStatus() {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                document.getElementById('api-results').innerHTML = 
                    `<div class="status success">✅ Status: ${data.status} - Clients: ${data.clients} - Version: ${data.version}</div>`;
            } catch (error) {
                document.getElementById('api-results').innerHTML = 
                    `<div class="status error">❌ Status Hatası: ${error.message}</div>`;
            }
        }
        
        async function testSystem() {
            try {
                const response = await fetch('/api/health');
                const data = await response.json();
                const sys = data.system || {};
                document.getElementById('api-results').innerHTML = 
                    `<div class="status info">📊 CPU: ${sys.cpu_percent}% - RAM: ${sys.memory_percent}%</div>`;
            } catch (error) {
                document.getElementById('api-results').innerHTML = 
                    `<div class="status error">❌ System Hatası: ${error.message}</div>`;
            }
        }
        
        async function runFullTest() {
            const results = document.getElementById('full-test-results');
            results.innerHTML = '<div class="status info">🔄 Tam sistem testi çalışıyor...</div>';
            
            let report = '';
            
            // API Test
            try {
                const healthResponse = await fetch('/api/health');
                const healthData = await healthResponse.json();
                report += `<p>✅ API Health: ${healthData.status}</p>`;
            } catch (e) {
                report += `<p>❌ API Health: Hata</p>`;
            }
            
            // WebSocket Test
            if (wsConnected) {
                report += `<p>✅ WebSocket: Bağlı ve çalışıyor</p>`;
            } else {
                report += `<p>❌ WebSocket: Bağlı değil</p>`;
            }
            
            // Port Test
            try {
                const portResponse = await fetch('/api/status');
                if (portResponse.ok) {
                    report += `<p>✅ Port 8080: Çalışıyor</p>`;
                }
            } catch (e) {
                report += `<p>❌ Port 8080: Problem</p>`;
            }
            
            results.innerHTML = `<div class="status ${report.includes('❌') ? 'warning' : 'success'}">${report}</div>`;
        }
        
        // Otomatik başlangıç testleri
        setTimeout(function() {
            testAPI();
        }, 1000);
        
        updateButtons();
    </script>
</body>
</html>
    '''

@app.route('/api/health')
def health():
    try:
        cpu = psutil.cpu_percent(interval=0.1)
        memory = psutil.virtual_memory()
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'websocket_server': 'running' if websocket_server else 'not_running',
            'system': {
                'cpu_percent': round(cpu, 1),
                'memory_percent': round(memory.percent, 1)
            },
            'ports': {
                'flask': 5000,
                'websocket': 8765,
                'nginx': 8080
            }
        })
    except Exception as e:
        return jsonify({
            'status': 'error', 
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500

@app.route('/api/status')
def status():
    if websocket_server:
        uptime = datetime.now() - websocket_server.stats["start_time"]
        return jsonify({
            'status': 'running',
            'uptime_seconds': int(uptime.total_seconds()),
            'uptime_human': str(uptime).split('.')[0],
            'clients': len(websocket_server.clients),
            'total_clients': websocket_server.stats["total_clients"],
            'version': '1.0.0-websocket-fixed',
            'server_time': datetime.now().isoformat()
        })
    return jsonify({
        'status': 'websocket_not_ready',
        'message': 'WebSocket server is starting...'
    }), 503

def main():
    os.makedirs('/var/log/kodlama-asistani', exist_ok=True)
    
    logger.info("🚀 Starting Kodlama Asistani Server with WebSocket fix...")
    
    # WebSocket sunucusunu başlat
    logger.info("🔌 Starting WebSocket server thread...")
    websocket_thread = run_websocket_server()
    
    # WebSocket'in başlaması için biraz bekle
    time.sleep(2)
    
    logger.info("🌐 Starting Flask web server on port 5000...")
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)

if __name__ == "__main__":
    main()
EOF

# 3. Script'i executable yap
chmod +x app.py

# 4. Servisi başlat
echo "▶️ Servisi yeniden başlatıyor..."
sudo systemctl start kodlama-asistani

# 5. Biraz bekle
echo "⏱️ WebSocket başlaması için 10 saniye bekleniyor..."
sleep 10

# 6. Durum kontrol
echo ""
echo "📊 DURUM KONTROL:"
systemctl is-active --quiet kodlama-asistani && echo "  ✅ Flask: Aktif" || echo "  ❌ Flask: İnaktif"

echo ""
echo "🔌 PORT KONTROL:"
netstat -tuln | grep -q ":5000" && echo "  ✅ Port 5000 (Flask): Açık" || echo "  ❌ Port 5000: Kapalı"
netstat -tuln | grep -q ":8765" && echo "  ✅ Port 8765 (WebSocket): Açık" || echo "  ❌ Port 8765: Kapalı"
netstat -tuln | grep -q ":8080" && echo "  ✅ Port 8080 (HTTP): Açık" || echo "  ❌ Port 8080: Kapalı"

# 7. WebSocket özel test
echo ""
echo "🧪 WEBSOCKET TEST:"
if netstat -tuln | grep -q ":8765"; then
    echo "  ✅ WebSocket portu AÇIK!"
    
    # Process kontrolü
    if pgrep -f "kodlama-asistani" > /dev/null; then
        echo "  ✅ Kodlama Asistanı süreci ÇALIŞIYOR!"
    else
        echo "  ❌ Süreç bulunamadı"
    fi
    
else
    echo "  ❌ WebSocket portu hala kapalı"
    echo "  🔍 Log kontrol edelim:"
    sudo journalctl -u kodlama-asistani --lines=10 --no-pager
fi

# 8. Web testi
echo ""
echo "🌐 WEB TEST:"
if curl -s http://localhost:8080/ | grep -q "WebSocket Fixed"; then
    echo "  ✅ Web sayfası yeni sürümle ÇALIŞIYOR!"
else
    echo "  ❌ Web sayfası güncel değil"
fi

echo ""
echo "🎉 WEBSOCKET DÜZELTMESİ TAMAMLANDI!"
echo "=================================="
echo ""
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "🌐 ERİŞİM ADRESLERİ:"
echo "  📱 Ana Sayfa (Yeni): http://$SERVER_IP:8080"
echo "  🔌 WebSocket Test: http://$SERVER_IP:8080 (WebSocket test butonları)"
echo "  📊 API Health: http://$SERVER_IP:8080/api/health"
echo ""
echo "🧪 WebSocket test için web sayfasında 'Bağlan' butonuna tıklayın!"

exit 0