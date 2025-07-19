#!/bin/bash
# server_install.sh - Ubuntu Sunucu Kurulum Script'i

set -e

echo "🌐 Kodlama Asistanı Sunucu Kurulumu"
echo "=================================="

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}$1${NC}"
}

# Root kontrolü
if [[ $EUID -eq 0 ]]; then
   print_error "Bu script'i root olarak çalıştırmayın!"
   print_info "Normal kullanıcı ile çalıştırın: ./server_install.sh"
   exit 1
fi

# 1. Sistem güncellemesi
print_header "📦 Sistem güncelleniyor..."
sudo apt update && sudo apt upgrade -y
print_success "Sistem güncellendi"

# 2. Gerekli paketleri yükle
print_info "Gerekli paketler yükleniyor..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    nginx \
    ufw \
    htop \
    curl \
    wget \
    unzip \
    git \
    certbot \
    python3-certbot-nginx \
    build-essential

print_success "Gerekli paketler yüklendi"

# 3. Proje dizini oluştur
print_info "Sunucu proje dizini oluşturuluyor..."
PROJECT_DIR="/var/www/kodlama-asistani"
sudo mkdir -p "$PROJECT_DIR"
sudo chown $USER:$USER "$PROJECT_DIR"
cd "$PROJECT_DIR"
print_success "Proje dizini hazır: $PROJECT_DIR"

# 4. Python sanal ortam
print_info "Python sanal ortam oluşturuluyor..."
python3 -m venv venv
source venv/bin/activate
print_success "Sanal ortam oluşturuldu"

# 5. Python paketlerini yükle
print_info "Python paketleri yükleniyor..."
cat > requirements.txt << 'EOF'
flask==2.3.3
websockets==11.0.3
gunicorn==21.2.0
gevent==23.7.0
gevent-websocket==0.10.1
requests==2.31.0
python-dotenv==1.0.0
psutil==5.9.5
EOF

pip install --upgrade pip
pip install -r requirements.txt
print_success "Python paketleri yüklendi"

# 6. Flask server dosyasını oluştur
print_info "Flask server dosyası oluşturuluyor..."
cat > app.py << 'EOF'
#!/usr/bin/env python3
# app.py - Sunucuda çalışacak Flask + WebSocket server

from flask import Flask, render_template_string, jsonify
import logging
import threading
import asyncio
import websockets
import json
import uuid
from datetime import datetime
import os

# Logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class CodeAssistantServer:
    def __init__(self):
        self.home_clients = {}  # Ev makinesi LLM client'ları
        self.web_clients = {}   # Web browser client'ları
        self.pending_requests = {}  # Bekleyen istekler
        self.stats = {
            "total_requests": 0,
            "successful_responses": 0,
            "errors": 0,
            "start_time": datetime.now()
        }
        
    async def register_client(self, websocket, client_type, client_info=None):
        client_id = str(uuid.uuid4())
            
        client_data = {
            "websocket": websocket,
            "connected_at": datetime.now(),
            "client_id": client_id,
            "client_info": client_info or {}
        }
        
        if client_type == "home_llm":
            self.home_clients[client_id] = client_data
            logger.info(f"🏠 Ev LLM client bağlandı: {client_id} - {client_info.get('system', 'Unknown')} - {client_info.get('gpu', 'Unknown GPU')}")
        elif client_type == "web_client":
            self.web_clients[client_id] = client_data
            logger.info(f"🌐 Web client bağlandı: {client_id}")
            
        return client_id
    
    async def unregister_client(self, client_id):
        if client_id in self.home_clients:
            client_info = self.home_clients[client_id]["client_info"]
            del self.home_clients[client_id]
            logger.info(f"🏠 Ev LLM client ayrıldı: {client_id}")
        elif client_id in self.web_clients:
            del self.web_clients[client_id]
            logger.info(f"🌐 Web client ayrıldı: {client_id}")
    
    async def handle_web_request(self, data, client_id):
        if not self.home_clients:
            self.stats["errors"] += 1
            return {
                "type": "error",
                "message": "🏠 Ev makinesindeki LLM servisi çevrimdışı. Lütfen ev client'ını başlatın."
            }
        
        request_id = str(uuid.uuid4())
        self.pending_requests[request_id] = {
            "web_client_id": client_id,
            "timestamp": datetime.now(),
            "prompt": data["prompt"]
        }
        
        # İlk kullanılabilir ev client'ına gönder
        home_client = list(self.home_clients.values())[0]
        
        message = {
            "type": "code_request",
            "request_id": request_id,
            "prompt": data["prompt"],
            "timestamp": datetime.now().isoformat()
        }
        
        await home_client["websocket"].send(json.dumps(message))
        self.stats["total_requests"] += 1
        
        logger.info(f"📨 Kod isteği gönderildi: {data['prompt'][:50]}... (ID: {request_id[:8]})")
        
        return {
            "type": "request_sent",
            "request_id": request_id,
            "message": "🚀 İstek ev makinesine gönderildi, yanıt bekleniyor..."
        }
    
    async def handle_home_response(self, data):
        request_id = data["request_id"]
        
        if request_id in self.pending_requests:
            request_info = self.pending_requests[request_id]
            web_client_id = request_info["web_client_id"]
            
            if web_client_id in self.web_clients:
                response = {
                    "type": "code_response",
                    "request_id": request_id,
                    "response": data["response"],
                    "timestamp": data["timestamp"]
                }
                
                web_client = self.web_clients[web_client_id]
                await web_client["websocket"].send(json.dumps(response))
                
                self.stats["successful_responses"] += 1
                logger.info(f"✅ Yanıt web client'a iletildi: {len(data['response'])} karakter (ID: {request_id[:8]})")
                
            del self.pending_requests[request_id]
    
    async def handle_client(self, websocket, path):
        client_id = None
        client_type = None
        
        try:
            async for message in websocket:
                data = json.loads(message)
                
                if data["type"] == "register":
                    client_type = data["client_type"]
                    client_info = data.get("client_info", {})
                    client_id = await self.register_client(websocket, client_type, client_info)
                    
                    await websocket.send(json.dumps({
                        "type": "registered",
                        "client_id": client_id,
                        "server_time": datetime.now().isoformat()
                    }))
                    
                elif data["type"] == "code_request" and client_id in self.web_clients:
                    response = await self.handle_web_request(data, client_id)
                    await websocket.send(json.dumps(response))
                    
                elif data["type"] == "code_response" and client_id in self.home_clients:
                    await self.handle_home_response(data)
                    
                elif data["type"] == "ping":
                    await websocket.send(json.dumps({
                        "type": "pong",
                        "timestamp": datetime.now().isoformat()
                    }))
                    
        except websockets.exceptions.ConnectionClosed:
            pass
        except Exception as e:
            logger.error(f"❌ Client işleme hatası: {e}")
        finally:
            if client_id:
                await self.unregister_client(client_id)

# Global WebSocket server instance
websocket_server = None

def run_websocket_server():
    global websocket_server
    websocket_server = CodeAssistantServer()
    
    start_server = websockets.serve(
        websocket_server.handle_client,
        "0.0.0.0",
        8765,
        ping_interval=30,
        ping_timeout=10
    )
    
    logger.info("🔌 WebSocket server başlatılıyor (port 8765)...")
    
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(start_server)
    loop.run_forever()

# Flask app
app = Flask(__name__)

@app.route('/')
def index():
    try:
        with open('templates/index.html', 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        return "❌ Web arayüzü dosyası bulunamadı. Kurulum tamamlanmamış olabilir."

@app.route('/api/status')
def api_status():
    if websocket_server:
        uptime = datetime.now() - websocket_server.stats["start_time"]
        return jsonify({
            'status': 'running',
            'home_clients': len(websocket_server.home_clients),
            'web_clients': len(websocket_server.web_clients), 
            'pending_requests': len(websocket_server.pending_requests),
            'stats': websocket_server.stats,
            'uptime_seconds': int(uptime.total_seconds())
        })
    return jsonify({'status': 'not_ready'})

@app.route('/api/health')
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })

if __name__ == "__main__":
    # WebSocket server'ı ayrı thread'de başlat
    websocket_thread = threading.Thread(target=run_websocket_server, daemon=True)
    websocket_thread.start()
    
    # Flask server'ı başlat
    logger.info("🌐 Flask web server başlatılıyor (port 5000)...")
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

print_success "Flask server dosyası oluşturuldu"

# 7. Templates dizini oluştur
print_info "Web arayüzü dosyaları oluşturuluyor..."
mkdir -p templates static/css static/js

# 8. HTML template dosyası oluştur
cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🤖 Kodlama Asistanı</title>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/themes/prism-tomorrow.min.css" rel="stylesheet">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/components/prism-core.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/plugins/autoloader/prism-autoloader.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        
        .container { 
            max-width: 1400px; 
            margin: 0 auto; 
            padding: 20px; 
            min-height: 100vh; 
            display: flex; 
            flex-direction: column; 
        }
        
        .header { 
            background: rgba(255, 255, 255, 0.95); 
            border-radius: 20px; 
            padding: 25px; 
            margin-bottom: 25px; 
            backdrop-filter: blur(15px); 
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
            text-align: center; 
        }
        
        .header h1 { 
            color: #4c51bf; 
            margin-bottom: 15px; 
            font-size: 2.5rem; 
            font-weight: 700;
            text-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .header p {
            color: #6b7280;
            font-size: 1.1rem;
            margin-bottom: 15px;
        }
        
        .status { 
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 10px 20px; 
            border-radius: 25px; 
            font-weight: bold; 
            font-size: 0.95rem; 
            transition: all 0.3s ease;
        }
        
        .status.connected { 
            background: #d1fae5; 
            color: #065f46; 
            border: 2px solid #10b981;
        }
        
        .status.disconnected { 
            background: #fef2f2; 
            color: #991b1b;
            border: 2px solid #ef4444;
        }
        
        .status.connecting { 
            background: #fef3c7; 
            color: #92400e;
            border: 2px solid #f59e0b;
        }
        
        .status-indicator {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            animation: pulse 2s infinite;
        }
        
        .connected .status-indicator { background: #10b981; }
        .disconnected .status-indicator { background: #ef4444; }
        .connecting .status-indicator { background: #f59e0b; }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        .main-content { 
            flex: 1; 
            display: grid; 
            grid-template-columns: 1fr 1fr; 
            gap: 25px; 
            margin-bottom: 25px; 
        }
        
        .input-section, .output-section { 
            background: rgba(255, 255, 255, 0.95); 
            border-radius: 20px; 
            padding: 25px; 
            backdrop-filter: blur(15px); 
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1); 
            display: flex; 
            flex-direction: column; 
        }
        
        .section-title { 
            font-size: 1.4rem; 
            font-weight: bold; 
            margin-bottom: 20px; 
            color: #4c51bf; 
            border-bottom: 3px solid #4c51bf; 
            padding-bottom: 10px; 
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .prompt-input { 
            width: 100%; 
            min-height: 220px; 
            border: 2px solid #e5e7eb; 
            border-radius: 15px; 
            padding: 20px; 
            font-family: 'JetBrains Mono', 'Fira Code', 'Consolas', monospace; 
            font-size: 14px; 
            resize: vertical; 
            transition: all 0.3s ease; 
            flex: 1;
            line-height: 1.6;
        }
        
        .prompt-input:focus { 
            outline: none; 
            border-color: #4c51bf; 
            box-shadow: 0 0 20px rgba(76, 81, 191, 0.2);
            transform: translateY(-2px);
        }
        
        .controls { 
            margin-top: 20px; 
            display: flex; 
            gap: 15px; 
            align-items: center; 
            flex-wrap: wrap;
        }
        
        .send-btn { 
            background: linear-gradient(135deg, #4c51bf 0%, #667eea 100%); 
            color: white; 
            border: none; 
            padding: 15px 30px; 
            border-radius: 30px; 
            font-weight: bold; 
            cursor: pointer; 
            transition: all 0.3s ease; 
            font-size: 1rem;
            display: flex;
            align-items: center;
            gap: 8px;
            box-shadow: 0 4px 15px rgba(76, 81, 191, 0.3);
        }
        
        .send-btn:hover:not(:disabled) { 
            transform: translateY(-3px); 
            box-shadow: 0 8px 25px rgba(76, 81, 191, 0.4);
        }
        
        .send-btn:disabled { 
            opacity: 0.6; 
            cursor: not-allowed; 
            transform: none;
        }
        
        .clear-btn { 
            background: #6b7280; 
            color: white; 
            border: none; 
            padding: 15px 25px; 
            border-radius: 30px; 
            cursor: pointer; 
            transition: all 0.3s ease;
            font-weight: 500;
        }
        
        .clear-btn:hover { 
            background: #4b5563;
            transform: translateY(-2px);
        }
        
        .output-area { 
            flex: 1; 
            border: 2px solid #e5e7eb; 
            border-radius: 15px; 
            padding: 20px; 
            background: #f9fafb; 
            overflow-y: auto; 
            min-height: 350px;
            max-height: 600px;
        }
        
        .loading { 
            display: inline-block; 
            width: 20px; 
            height: 20px; 
            border: 3px solid #f3f4f6; 
            border-top: 3px solid #4c51bf; 
            border-radius: 50%; 
            animation: spin 1s linear infinite; 
            margin-right: 10px; 
        }
        
        @keyframes spin { 
            0% { transform: rotate(0deg); } 
            100% { transform: rotate(360deg); } 
        }
        
        .response { 
            margin-bottom: 25px; 
            padding: 20px; 
            border-radius: 15px; 
            border-left: 5px solid #4c51bf; 
            background: white; 
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
            transition: transform 0.2s ease;
        }
        
        .response:hover {
            transform: translateY(-2px);
        }
        
        .response-header { 
            font-weight: bold; 
            color: #4c51bf; 
            margin-bottom: 15px; 
            font-size: 0.95rem;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .code-block { 
            background: #1f2937; 
            color: #f9fafb; 
            padding: 20px; 
            border-radius: 12px; 
            overflow-x: auto; 
            margin: 15px 0; 
            font-family: 'JetBrains Mono', 'Fira Code', 'Consolas', monospace; 
            font-size: 13px;
            line-height: 1.6;
            box-shadow: 0 4px 10px rgba(0,0,0,0.1);
        }
        
        .quick-prompts { 
            display: flex; 
            flex-wrap: wrap; 
            gap: 10px; 
            margin-top: 15px; 
        }
        
        .quick-prompt { 
            background: #f3f4f6; 
            border: 2px solid #e5e7eb; 
            border-radius: 20px; 
            padding: 8px 16px; 
            font-size: 0.85rem; 
            cursor: pointer; 
            transition: all 0.3s ease;
            font-weight: 500;
        }
        
        .quick-prompt:hover { 
            background: #4c51bf; 
            color: white;
            border-color: #4c51bf;
            transform: translateY(-2px);
        }
        
        .footer {
            text-align: center;
            padding: 20px;
            color: rgba(255,255,255,0.8);
            font-size: 0.9rem;
        }
        
        @media (max-width: 768px) { 
            .main-content { 
                grid-template-columns: 1fr; 
            } 
            
            .header h1 { 
                font-size: 2rem; 
            } 
            
            .controls { 
                flex-direction: column; 
                align-items: stretch; 
            } 
            
            .send-btn, .clear-btn { 
                width: 100%; 
                margin-bottom: 10px; 
            }
            
            .container {
                padding: 15px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 Kodlama Asistanı</h1>
            <p>GTX 1050 Ti • DeepSeek Coder 6.7B • Kişisel AI Asistanınız</p>
            <div class="status connecting" id="status">
                <div class="status-indicator"></div>
                <span>Bağlanıyor...</span>
            </div>
        </div>
        
        <div class="main-content">
            <div class="input-section">
                <div class="section-title">
                    <span>📝</span>
                    <span>Kod İsteği</span>
                </div>
                <textarea class="prompt-input" id="promptInput" placeholder="Kodlama sorunuzu buraya yazın...

Örnek sorular:
• Python'da CSV dosyası okuma kodu yaz
• React'ta responsive navbar component'i oluştur  
• Bu JavaScript kodundaki hatayı bul ve düzelt
• SQL sorgusu optimizasyon önerileri ver
• Docker container nasıl oluşturulur?"></textarea>
                
                <div class="controls">
                    <button class="send-btn" id="sendBtn">
                        <span>🚀</span>
                        <span id="sendText">Gönder</span>
                    </button>
                    <button class="clear-btn" id="clearBtn">🧹 Temizle</button>
                </div>
                
                <div class="quick-prompts">
                    <div class="quick-prompt" data-prompt="Python'da pandas kullanarak CSV dosyası işleme">🐍 Python CSV</div>
                    <div class="quick-prompt" data-prompt="React'ta modern state yönetimi hooks ile">⚛️ React Hooks</div>
                    <div class="quick-prompt" data-prompt="JavaScript'te async/await ile API çağrısı">🌐 API Call</div>
                    <div class="quick-prompt" data-prompt="SQL sorgusu performans optimizasyonu">🗄️ SQL Optimize</div>
                    <div class="quick-prompt" data-prompt="Docker multi-stage build örneği">🐳 Docker</div>
                    <div class="quick-prompt" data-prompt="Git workflow ve branch strategy">📋 Git Workflow</div>
                </div>
            </div>
            
            <div class="output-section">
                <div class="section-title">
                    <span>💬</span>
                    <span>AI Yanıtları</span>
                </div>
                <div class="output-area" id="outputArea">
                    <div style="text-align: center; color: #6b7280; margin-top: 60px;">
                        <p style="font-size: 1.1rem; margin-bottom: 10px;">🎯 Hazırım!</p>
                        <p style="font-size: 0.95rem; margin-bottom: 15px;">Kodlama sorunuzu yazın ve çözümü alın</p>
                        <div style="font-size: 0.8rem; color: #9ca3af;">
                            <p>🤖 Model: DeepSeek Coder 6.7B</p>
                            <p>🎮 GPU: GTX 1050 Ti 4GB</p>
                            <p>⚡ Yanıt süresi: ~15-30 saniye</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>Made with ❤️ for developers • Powered by your GTX 1050 Ti</p>
        </div>
    </div>

    <script>
        class CodeAssistant {
            constructor() {
                this.ws = null;
                this.isConnected = false;
                this.reconnectAttempts = 0;
                this.maxReconnectAttempts = 10;
                this.initElements();
                this.bindEvents();
                this.connect();
            }
            
            initElements() {
                this.statusEl = document.getElementById('status');
                this.promptInput = document.getElementById('promptInput');
                this.sendBtn = document.getElementById('sendBtn');
                this.sendText = document.getElementById('sendText');
                this.clearBtn = document.getElementById('clearBtn');
                this.outputArea = document.getElementById('outputArea');
            }
            
            bindEvents() {
                this.sendBtn.addEventListener('click', () => this.sendPrompt());
                this.clearBtn.addEventListener('click', () => this.clearOutput());
                
                this.promptInput.addEventListener('keydown', (e) => {
                    if (e.ctrlKey && e.key === 'Enter') {
                        this.sendPrompt();
                    }
                });
                
                document.querySelectorAll('.quick-prompt').forEach(btn => {
                    btn.addEventListener('click', () => {
                        this.promptInput.value = btn.dataset.prompt;
                        this.promptInput.focus();
                    });
                });
            }
            
            connect() {
                const wsUrl = `ws://${window.location.hostname}:8765`;
                
                try {
                    this.ws = new WebSocket(wsUrl);
                    
                    this.ws.onopen = () => {
                        this.isConnected = true;
                        this.reconnectAttempts = 0;
                        this.updateStatus('connected', '🟢 Bağlı & Hazır');
                        
                        this.ws.send(JSON.stringify({
                            type: 'register',
                            client_type: 'web_client',
                            user_agent: navigator.userAgent,
                            timestamp: new Date().toISOString()
                        }));
                    };
                    
                    this.ws.onmessage = (event) => {
                        const data = JSON.parse(event.data);
                        this.handleMessage(data);
                    };
                    
                    this.ws.onclose = () => {
                        this.isConnected = false;
                        this.updateStatus('disconnected', '🔴 Bağlantı Kesildi');
                        
                        if (this.reconnectAttempts < this.maxReconnectAttempts) {
                            this.reconnectAttempts++;
                            setTimeout(() => this.connect(), 3000 * this.reconnectAttempts);
                        }
                    };
                    
                    this.ws.onerror = () => {
                        this.updateStatus('disconnected', '❌ Bağlantı Hatası');
                    };
                    
                } catch (error) {
                    this.updateStatus('disconnected', '❌ Bağlantı Hatası');
                    setTimeout(() => this.connect(), 5000);
                }
            }
            
            updateStatus(type, text) {
                this.statusEl.className = `status ${type}`;
                this.statusEl.innerHTML = `
                    <div class="status-indicator"></div>
                    <span>${text}</span>
                `;
            }
            
            handleMessage(data) {
                switch (data.type) {
                    case 'registered':
                        console.log('✅ Client registered:', data.client_id);
                        break;
                        
                    case 'request_sent':
                        this.showLoading(data.request_id);
                        break;
                        
                    case 'code_response':
                        this.showResponse(data);
                        break;
                        
                    case 'error':
                        this.showError(data.message);
                        break;
                        
                    case 'pong':
                        console.log('📡 Pong received');
                        break;
                }
            }
            
            sendPrompt() {
                const prompt = this.promptInput.value.trim();
                
                if (!prompt) {
                    this.promptInput.focus();
                    return;
                }
                
                if (!this.isConnected) {
                    this.showError('🔴 Sunucuya bağlı değilsiniz. Lütfen bekleyin...');
                    return;
                }
                
                this.ws.send(JSON.stringify({
                    type: 'code_request',
                    prompt: prompt,
                    timestamp: new Date().toISOString()
                }));
                
                this.sendBtn.disabled = true;
                this.sendText.innerHTML = '<div class="loading"></div>Gönderiliyor...';
            }
            
            showLoading(requestId) {
                const loadingDiv = document.createElement('div');
                loadingDiv.className = 'response';
                loadingDiv.id = `response-${requestId}`;
                loadingDiv.innerHTML = `
                    <div class="response-header">
                        <span>🔄</span>
                        <span>İşleniyor... (${new Date().toLocaleTimeString()})</span>
                    </div>
                    <div style="display: flex; align-items: center; gap: 10px; color: #6b7280;">
                        <div class="loading"></div>
                        <span>Ev makinesindeki GTX 1050 Ti'den yanıt bekleniyor...</span>
                    </div>
                `;
                
                this.outputArea.appendChild(loadingDiv);
                this.outputArea.scrollTop = this.outputArea.scrollHeight;
            }
            
            showResponse(data) {
                const responseEl = document.getElementById(`response-${data.request_id}`) || 
                    this.createResponseElement(data.request_id);
                
                const formattedResponse = this.formatResponse(data.response);
                
                responseEl.innerHTML = `
                    <div class="response-header">
                        <span>✅</span>
                        <span>AI Yanıtı (${new Date(data.timestamp).toLocaleTimeString()})</span>
                    </div>
                    <div>${formattedResponse}</div>
                `;
                
                this.resetSendButton();
                this.outputArea.scrollTop = this.outputArea.scrollHeight;
                
                // Syntax highlighting
                Prism.highlightAllUnder(responseEl);
            }
            
            createResponseElement(requestId) {
                const responseDiv = document.createElement('div');
                responseDiv.className = 'response';
                responseDiv.id = `response-${requestId}`;
                this.outputArea.appendChild(responseDiv);
                return responseDiv;
            }
            
            formatResponse(text) {
                return text.replace(/```(\w+)?\n([\s\S]*?)```/g, (match, lang, code) => {
                    return `<pre class="code-block"><code class="language-${lang || 'text'}">${this.escapeHtml(code.trim())}</code></pre>`;
                }).replace(/`([^`]+)`/g, '<code style="background: #f1f3f4; padding: 2px 6px; border-radius: 4px; font-family: monospace;">$1</code>')
                .replace(/\n/g, '<br>');
            }
            
            escapeHtml(text) {
                const div = document.createElement('div');
                div.textContent = text;
                return div.innerHTML;
            }
            
            showError(message) {
                const errorDiv = document.createElement('div');
                errorDiv.className = 'response';
                errorDiv.style.borderLeftColor = '#ef4444';
                errorDiv.innerHTML = `
                    <div class="response-header" style="color: #ef4444;">
                        <span>❌</span>
                        <span>Hata</span>
                    </div>
                    <div style="color: #dc2626; margin-bottom: 10px;">${message}</div>
                    <div style="font-size: 0.9rem; color: #6b7280;">
                        💡 <strong>Çözüm önerileri:</strong><br>
                        • Ev makinesindeki client'ın çalıştığından emin olun<br>
                        • config.py dosyasında sunucu IP'sinin doğru olduğunu kontrol edin<br>
                        • Ollama servisinin aktif olduğunu kontrol edin
                    </div>
                `;
                
                this.outputArea.appendChild(errorDiv);
                this.resetSendButton();
                this.outputArea.scrollTop = this.outputArea.scrollHeight;
            }
            
            resetSendButton() {
                this.sendBtn.disabled = false;
                this.sendText.innerHTML = '<span>🚀</span><span>Gönder</span>';
            }
            
            clearOutput() {
                this.outputArea.innerHTML = `
                    <div style="text-align: center; color: #6b7280; margin-top: 60px;">
                        <p style="font-size: 1.1rem;">🧹 Yanıtlar temizlendi</p>
                        <p style="font-size: 0.9rem; margin-top: 10px;">Yeni sorularınızı yazabilirsiniz</p>
                    </div>
                `;
            }
        }
        
        // Initialize when page loads
        document.addEventListener('DOMContentLoaded', () => {
            new CodeAssistant();
        });
    </script>
</body>
</html>
EOF

print_success "Web arayüzü dosyaları oluşturuldu"

# 9. Gunicorn konfigürasyonu
print_info "Gunicorn konfigürasyonu oluşturuluyor..."
cat > gunicorn.conf.py << 'EOF'
# Gunicorn configuration
bind = "0.0.0.0:5000"
workers = 2
worker_class = "gevent"
worker_connections = 1000
timeout = 120
keepalive = 2
max_requests = 1000
max_requests_jitter = 50
preload_app = True
access_logfile = "/var/log/kodlama-asistani/access.log"
error_logfile = "/var/log/kodlama-asistani/error.log"
EOF

# Log dizini oluştur
sudo mkdir -p /var/log/kodlama-asistani
sudo chown $USER:$USER /var/log/kodlama-asistani

print_success "Gunicorn konfigürasyonu oluşturuldu"

# 10. Systemd servis dosyası
print_info "Systemd servisi oluşturuluyor..."
sudo tee /etc/systemd/system/kodlama-asistani.service > /dev/null << EOF
[Unit]
Description=Kodlama Asistanı Flask Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin
ExecStart=$PROJECT_DIR/venv/bin/gunicorn --config gunicorn.conf.py app:app
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

print_success "Systemd servisi oluşturuldu"

# 11. Nginx konfigürasyonu
print_info "Nginx konfigürasyonu oluşturuluyor..."
SERVER_NAME=$(hostname -I | awk '{print $1}')

sudo tee /etc/nginx/sites-available/kodlama-asistani > /dev/null << EOF
upstream flask_app {
    server 127.0.0.1:5000;
}

upstream websocket_server {
    server 127.0.0.1:8765;
}

server {
    listen 80;
    server_name $SERVER_NAME _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' https: data: 'unsafe-inline' 'unsafe-eval';" always;

    # Flask app proxy
    location / {
        proxy_pass http://flask_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # CORS headers
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
        add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range" always;
        
        if (\$request_method = 'OPTIONS') {
            return 204;
        }
    }

    # WebSocket proxy
    location /ws {
        proxy_pass http://websocket_server;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }

    # Static files
    location /static {
        alias $PROJECT_DIR/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # API endpoints
    location /api {
        proxy_pass http://flask_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types 
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/json
        application/xml+rss
        application/atom+xml
        image/svg+xml;
        
    # Rate limiting
    location /api/ {
        limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/m;
        limit_req zone=api burst=5 nodelay;
    }
}
EOF

# Nginx site'ı etkinleştir
sudo ln -sf /etc/nginx/sites-available/kodlama-asistani /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

print_success "Nginx konfigürasyonu oluşturuldu"

# 12. Firewall konfigürasyonu
print_info "Firewall konfigürasyonu..."
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw allow 5000
sudo ufw allow 8765

print_success "Firewall konfigürasyonu tamamlandı"

# 13. Yönetim script'leri oluştur
print_info "Yönetim script'leri oluşturuluyor..."

# Başlangıç script'i
cat > start_server.sh << 'EOF'
#!/bin/bash
echo "🌐 Kodlama Asistanı Sunucu Başlatılıyor..."

# Servisleri başlat
sudo systemctl start kodlama-asistani
sudo systemctl start nginx

# Durum kontrolü
sleep 3

echo "📊 Servis Durumları:"
if systemctl is-active --quiet kodlama-asistani; then
    echo "  ✅ Flask server çalışıyor"
else
    echo "  ❌ Flask server başlatılamadı"
    echo "📋 Logları görmek için: sudo journalctl -u kodlama-asistani --lines=20"
fi

if systemctl is-active --quiet nginx; then
    echo "  ✅ Nginx çalışıyor"
else
    echo "  ❌ Nginx başlatılamadı"
    echo "📋 Logları görmek için: sudo journalctl -u nginx --lines=20"
fi

# Port kontrolleri
echo "🔌 Port Kontrolleri:"
netstat -tuln | grep -q ":5000" && echo "  ✅ Port 5000 (Flask) açık" || echo "  ❌ Port 5000 kapalı"
netstat -tuln | grep -q ":8765" && echo "  ✅ Port 8765 (WebSocket) açık" || echo "  ❌ Port 8765 kapalı"
netstat -tuln | grep -q ":80" && echo "  ✅ Port 80 (HTTP) açık" || echo "  ❌ Port 80 kapalı"

echo ""
echo "🌍 Erişim Adresleri:"
echo "  📱 Web Arayüzü: http://$(hostname -I | awk '{print $1}')"
echo "  📊 API Status: http://$(hostname -I | awk '{print $1}')/api/status"
echo "  🏥 Health Check: http://$(hostname -I | awk '{print $1}')/api/health"
echo ""
echo "📝 Telefon erişimi için yukarıdaki IP adresini tarayıcınızda açın"
EOF

chmod +x start_server.sh

# Durdurma script'i
cat > stop_server.sh << 'EOF'
#!/bin/bash
echo "🛑 Kodlama Asistanı Sunucu Durduruluyor..."

sudo systemctl stop kodlama-asistani
sudo systemctl stop nginx

echo "✅ Tüm servisler durduruldu."
echo "📋 Logları görmek için:"
echo "  • Flask: sudo journalctl -u kodlama-asistani"
echo "  • Nginx: sudo journalctl -u nginx"
EOF

chmod +x stop_server.sh

# Durum script'i
cat > status.sh << 'EOF'
#!/bin/bash
echo "📊 Kodlama Asistanı Sunucu Durumu"
echo "================================"

echo "🔧 Servisler:"
systemctl is-active --quiet kodlama-asistani && echo "  ✅ Flask Server: Aktif" || echo "  ❌ Flask Server: Aktif değil"
systemctl is-active --quiet nginx && echo "  ✅ Nginx: Aktif" || echo "  ❌ Nginx: Aktif değil"

echo "🔌 Portlar:"
netstat -tuln | grep -q ":5000" && echo "  ✅ Port 5000 (Flask): Açık" || echo "  ❌ Port 5000: Kapalı"
netstat -tuln | grep -q ":8765" && echo "  ✅ Port 8765 (WebSocket): Açık" || echo "  ❌ Port 8765: Kapalı"
netstat -tuln | grep -q ":80" && echo "  ✅ Port 80 (HTTP): Açık" || echo "  ❌ Port 80: Kapalı"

echo "💾 Disk Kullanımı:"
echo "  📂 Proje: $(du -sh $PWD | cut -f1)"
echo "  📋 Loglar: $(du -sh /var/log/kodlama-asistani 2>/dev/null | cut -f1 || echo '0B')"

echo "🌐 Erişim:"
IP=$(hostname -I | awk '{print $1}')
echo "  📱 Web Arayüzü: http://$IP"
echo "  📊 API Status: http://$IP/api/status"

echo "📈 Son 5 dakikadaki istekler:"
sudo tail -n 50 /var/log/kodlama-asistani/access.log 2>/dev/null | grep "$(date +'%d/%b/%Y:%H:%M')" | wc -l || echo "0"

# API Status Check
if command -v curl &> /dev/null; then
    echo "🏥 API Health Check:"
    curl -s "http://localhost/api/health" | python3 -m json.tool 2>/dev/null || echo "  ❌ API yanıt vermiyor"
fi
EOF

chmod +x status.sh

# Log görüntüleme script'i
cat > logs.sh << 'EOF'
#!/bin/bash
echo "📋 Kodlama Asistanı Logları"
echo "=========================="

echo "🌐 Flask Server Logları (Son 20):"
sudo journalctl -u kodlama-asistani --lines=20 --no-pager

echo -e "\n📊 Nginx Error Logları (Son 10):"
sudo tail -10 /var/log/nginx/error.log 2>/dev/null || echo "Log dosyası bulunamadı"

echo -e "\n🔍 Nginx Access Logları (Son 10):"
sudo tail -10 /var/log/nginx/access.log 2>/dev/null || echo "Log dosyası bulunamadı"

echo -e "\n📈 Uygulama Logları (Son 20):"
sudo tail -20 /var/log/kodlama-asistani/error.log 2>/dev/null || echo "Log dosyası bulunamadı"

echo -e "\n📊 Sistem kaynak kullanımı:"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
echo "RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "Disk: $(df -h / | awk '/\// {print $3 "/" $2 " (" $5 ")"}')"
EOF

chmod +x logs.sh

# SSL kurulum script'i
cat > setup_ssl.sh << 'EOF'
#!/bin/bash
echo "🔒 SSL Sertifikası Kurulumu"
echo "==========================="

read -p "🌐 Domain adınızı girin (örn: example.com): " DOMAIN

if [[ -z "$DOMAIN" ]]; then
    echo "❌ Domain adresi gerekli!"
    exit 1
fi

echo "📝 Domain: $DOMAIN"
read -p "🤔 Devam etmek istiyor musunuz? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# DNS kontrolü
echo "🔍 DNS kontrolü yapılıyor..."
if ! nslookup $DOMAIN > /dev/null 2>&1; then
    echo "⚠️ DNS kaydı bulunamadı. Devam etmek istiyor musunuz? (y/n)"
    read -p "" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Nginx konfigürasyonunu güncelle
echo "🔧 Nginx konfigürasyonu güncelleniyor..."
sudo sed -i "s/server_name .*/server_name $DOMAIN;/" /etc/nginx/sites-available/kodlama-asistani

# Nginx'i test et ve yeniden başlat
if sudo nginx -t; then
    sudo systemctl reload nginx
    echo "✅ Nginx konfigürasyonu güncellendi"
else
    echo "❌ Nginx konfigürasyonu hatası!"
    exit 1
fi

# SSL sertifikası al
echo "🔒 SSL sertifikası alınıyor..."
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN

if [ $? -eq 0 ]; then
    echo "🎉 SSL kurulumu tamamlandı!"
    echo "🌍 HTTPS erişim: https://$DOMAIN"
    
    # Auto-renewal test
    echo "🔄 Otomatik yenileme testi..."
    sudo certbot renew --dry-run
else
    echo "❌ SSL kurulumu başarısız!"
    echo "🔧 Manuel çözüm: sudo certbot --nginx -d $DOMAIN"
fi
EOF

chmod +x setup_ssl.sh

print_success "Yönetim script'leri oluşturuldu"

# 14. Servisleri etkinleştir
print_info "Servisleri etkinleştiriliyor..."
sudo systemctl daemon-reload
sudo systemctl enable kodlama-asistani
sudo systemctl enable nginx

# 15. Nginx test
print_info "Nginx konfigürasyonu test ediliyor..."
if sudo nginx -t; then
    print_success "Nginx konfigürasyonu geçerli"
else
    print_error "Nginx konfigürasyonu hatası!"
    exit 1
fi

# 16. İlk başlatma
print_info "Servisleri başlatıyor..."
sudo systemctl start kodlama-asistani
sudo systemctl start nginx

# Başlatma kontrolü
sleep 5
if systemctl is-active --quiet kodlama-asistani && systemctl is-active --quiet nginx; then
    print_success "Tüm servisler başarıyla başlatıldı!"
else
    print_warning "Bazı servisler başlatılamadı, logları kontrol edin"
fi

# 17. Kurulum tamamlandı
print_header "🎉 SUNUCU KURULUMU TAMAMLANDI!"
echo "======================================="
echo ""
print_success "📂 Proje dizini: $PROJECT_DIR"
print_success "🌍 Erişim adresi: http://$(hostname -I | awk '{print $1}')"
print_success "📱 Telefon erişimi: Web tarayıcınızda yukarıdaki adrese gidin"
echo ""
print_header "📋 YÖNETİM KOMUTLARI:"
echo "▶️ Başlat: ./start_server.sh"
echo "⏹️ Durdur: ./stop_server.sh"
echo "📊 Durum: ./status.sh"
echo "📋 Loglar: ./logs.sh"
echo "🔒 SSL: ./setup_ssl.sh (opsiyonel)"
echo ""
print_header "🔧 SERVİS YÖNETİMİ:"
echo "• systemctl status kodlama-asistani"
echo "• systemctl restart kodlama-asistani"
echo "• systemctl logs kodlama-asistani"
echo ""
print_warning "✅ Güvenlik duvarı ayarlandı. Gerekli portlar açıldı."
print_info "🏠 Ev makinesinde client'ı başlatabilirsiniz!"
echo ""
print_header "🧪 TEST:"
echo "curl http://$(hostname -I | awk '{print $1}')/api/health"
echo ""
echo "🎯 Artık Windows ev makinesinden bağlanabilirsiniz!"