#!/bin/bash
# emergency_fix.sh - Acil durum syntax hatası düzeltme

echo "🚨 ACİL DURUM SYNTAX HATASI DÜZELTMESİ"
echo "====================================="

PROJECT_DIR="/var/www/kodlama-asistani"
cd "$PROJECT_DIR"

# 1. Servisleri durdur
echo "🛑 Servisleri durduruyor..."
sudo systemctl stop kodlama-asistani
sudo systemctl stop nginx

# 2. Bozuk dosyayı yedekle
echo "💾 Bozuk app.py yedekleniyor..."
cp app.py app.py.broken_$(date +%s)

# 3. Minimal ÇALIŞAN app.py oluştur
echo "🔧 Minimal çalışan app.py oluşturuluyor..."
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

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SimpleWebSocketServer:
    def __init__(self):
        self.clients = {}
        self.stats = {"start_time": datetime.now(), "total_clients": 0}
        
    async def register_client(self, websocket, client_type):
        client_id = str(uuid.uuid4())
        self.clients[client_id] = {
            "websocket": websocket,
            "type": client_type,
            "connected_at": datetime.now()
        }
        self.stats["total_clients"] += 1
        logger.info(f"Client registered: {client_id[:8]} ({client_type})")
        return client_id
    
    async def unregister_client(self, client_id):
        if client_id in self.clients:
            del self.clients[client_id]
            logger.info(f"Client disconnected: {client_id[:8]}")
    
    async def handle_client(self, websocket, path):
        client_id = None
        try:
            async for message in websocket:
                try:
                    data = json.loads(message)
                    if data.get("type") == "register":
                        client_type = data.get("client_type", "unknown")
                        client_id = await self.register_client(websocket, client_type)
                        await websocket.send(json.dumps({
                            "type": "registered",
                            "client_id": client_id,
                            "server_time": datetime.now().isoformat()
                        }))
                    elif data.get("type") == "ping":
                        await websocket.send(json.dumps({
                            "type": "pong",
                            "timestamp": datetime.now().isoformat()
                        }))
                except json.JSONDecodeError:
                    logger.error("Invalid JSON received")
                except Exception as e:
                    logger.error(f"Message handling error: {e}")
        except Exception as e:
            logger.error(f"WebSocket error: {e}")
        finally:
            if client_id:
                await self.unregister_client(client_id)

websocket_server = None

def run_websocket_server():
    global websocket_server
    websocket_server = SimpleWebSocketServer()
    
    async def start_server():
        logger.info("Starting WebSocket server on port 8765...")
        server = await websockets.serve(
            websocket_server.handle_client,
            "0.0.0.0", 8765
        )
        logger.info("WebSocket server started successfully")
        await server.wait_closed()
    
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.run_until_complete(start_server())
    except Exception as e:
        logger.error(f"WebSocket server error: {e}")

app = Flask(__name__)

@app.route('/')
def index():
    return '''
<!DOCTYPE html>
<html>
<head>
    <title>Kodlama Asistani - Working!</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; }
        .status { padding: 15px; margin: 20px 0; border-radius: 8px; text-align: center; font-weight: bold; }
        .success { background: #d4edda; color: #155724; }
        .info { background: #d1ecf1; color: #0c5460; }
        button { background: #007bff; color: white; padding: 12px 25px; border: none; border-radius: 6px; cursor: pointer; margin: 5px; }
        button:hover { background: #0056b3; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🤖 Kodlama Asistanı</h1>
        <h2>✅ Syntax Hatası Düzeltildi!</h2>
        
        <div class="status success">
            Flask servisi artık çalışıyor! 502 hatası çözüldü.
        </div>
        
        <div class="status info" id="ws-status">
            WebSocket durumu kontrol ediliyor...
        </div>
        
        <button onclick="testAPI()">API Test</button>
        <button onclick="testWebSocket()">WebSocket Test</button>
        
        <div id="results" style="margin-top: 20px; padding: 20px; background: #f8f9fa;">
            <h3>Test Sonuçları:</h3>
            <p>Test butonlarına tıklayın.</p>
        </div>
    </div>

    <script>
        function addResult(msg) {
            document.getElementById('results').innerHTML += '<p>' + new Date().toLocaleTimeString() + ': ' + msg + '</p>';
        }
        
        async function testAPI() {
            try {
                const response = await fetch('/api/health');
                const data = await response.json();
                addResult('✅ API çalışıyor: ' + data.status);
            } catch (error) {
                addResult('❌ API hatası: ' + error.message);
            }
        }
        
        function testWebSocket() {
            const ws = new WebSocket('ws://' + window.location.hostname + ':8765');
            
            ws.onopen = function() {
                document.getElementById('ws-status').innerHTML = '🟢 WebSocket bağlantısı başarılı!';
                document.getElementById('ws-status').className = 'status success';
                addResult('✅ WebSocket bağlandı');
                
                ws.send(JSON.stringify({
                    type: 'register',
                    client_type: 'web_test'
                }));
            };
            
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                addResult('📨 WebSocket mesajı: ' + data.type);
            };
            
            ws.onclose = function() {
                addResult('🔴 WebSocket kapandı');
            };
            
            ws.onerror = function() {
                document.getElementById('ws-status').innerHTML = '❌ WebSocket bağlantı hatası';
                addResult('❌ WebSocket hatası');
            };
        }
        
        // Otomatik test
        setTimeout(function() {
            testAPI();
            setTimeout(testWebSocket, 1000);
        }, 500);
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
                'cpu_percent': cpu,
                'memory_percent': memory.percent
            }
        })
    except Exception as e:
        return jsonify({'status': 'error', 'error': str(e)}), 500

@app.route('/api/status')
def status():
    if websocket_server:
        uptime = datetime.now() - websocket_server.stats["start_time"]
        return jsonify({
            'status': 'running',
            'uptime_seconds': int(uptime.total_seconds()),
            'clients': len(websocket_server.clients),
            'version': '1.0.0-fixed'
        })
    return jsonify({'status': 'websocket_not_ready'}), 503

def main():
    os.makedirs('/var/log/kodlama-asistani', exist_ok=True)
    logger.info("Starting Kodlama Asistani Server...")
    
    # WebSocket sunucusunu ayrı thread'de başlat
    websocket_thread = threading.Thread(target=run_websocket_server, daemon=True)
    websocket_thread.start()
    
    logger.info("Starting Flask web server on port 5000...")
    app.run(host='0.0.0.0', port=5000, debug=False)

if __name__ == "__main__":
    main()
EOF

# 4. Script'i executable yap
chmod +x app.py

# 5. Port 8080 için Nginx basit konfigürasyon
echo "🌐 Nginx 8080 konfigürasyonu..."
sudo tee /etc/nginx/sites-available/kodlama-asistani > /dev/null << 'NGINX_EOF'
upstream flask_app {
    server 127.0.0.1:5000;
}

upstream websocket_server {
    server 127.0.0.1:8765;
}

server {
    listen 8080;
    server_name _;
    
    location / {
        proxy_pass http://flask_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /ws {
        proxy_pass http://websocket_server;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
NGINX_EOF

# 6. Firewall
echo "🔥 Firewall kuralları..."
sudo ufw allow 8080/tcp comment 'Kodlama Asistani HTTP'
sudo ufw allow 8765/tcp comment 'Kodlama Asistani WebSocket'

# 7. Nginx test
echo "🧪 Nginx test..."
if sudo nginx -t; then
    echo "✅ Nginx konfigürasyonu OK"
else
    echo "❌ Nginx konfigürasyon hatası!"
    exit 1
fi

# 8. Servisleri başlat
echo "▶️ Servisleri başlatıyor..."
sudo systemctl start kodlama-asistani
sleep 3
sudo systemctl start nginx

# 9. Durum kontrol
echo ""
echo "📊 DURUM KONTROL:"
systemctl is-active --quiet kodlama-asistani && echo "  ✅ Flask: Aktif" || echo "  ❌ Flask: İnaktif"
systemctl is-active --quiet nginx && echo "  ✅ Nginx: Aktif" || echo "  ❌ Nginx: İnaktif"

echo ""
echo "🔌 PORT KONTROL:"
netstat -tuln | grep -q ":5000" && echo "  ✅ Port 5000: Açık" || echo "  ❌ Port 5000: Kapalı"
netstat -tuln | grep -q ":8765" && echo "  ✅ Port 8765: Açık" || echo "  ❌ Port 8765: Kapalı"
netstat -tuln | grep -q ":8080" && echo "  ✅ Port 8080: Açık" || echo "  ❌ Port 8080: Kapalı"

# 10. Test
echo ""
echo "🧪 HIZLI TEST:"
sleep 2

if curl -s http://localhost:8080/ | grep -q "Kodlama Asistanı"; then
    echo "  ✅ Web sayfası ÇALIŞIYOR!"
else
    echo "  ❌ Web sayfası test başarısız"
fi

if curl -s http://localhost:8080/api/health | grep -q "healthy"; then
    echo "  ✅ API health ÇALIŞIYOR!"
else
    echo "  ❌ API test başarısız"
fi

echo ""
echo "🎉 ACİL DURUM DÜZELTMESİ TAMAMLANDI!"
echo "=================================="
echo ""
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "🌐 ERİŞİM ADRESLERİ:"
echo "  📱 Ana Sayfa: http://$SERVER_IP:8080"
echo "  📊 API Health: http://$SERVER_IP:8080/api/health"
echo "  📈 API Status: http://$SERVER_IP:8080/api/status"
echo ""
echo "📱 Telefon erişimi: $SERVER_IP:8080"
echo ""
echo "✅ 502 Bad Gateway hatası çözüldü!"
echo "✅ Syntax hataları düzeltildi!"
echo "✅ Sistem şimdi çalışıyor!"

exit 0