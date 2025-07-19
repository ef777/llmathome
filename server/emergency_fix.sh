#!/usr/bin/env python3
# app.py - Kodlama Asistanı TAM ÖZELLİKLİ Flask + WebSocket Server
# Ubuntu sunucuda çalışacak - WebSocket düzeltilmiş, tüm özellikler mevcut

from flask import Flask, jsonify, request
import logging
import threading
import asyncio
import websockets
import json
import uuid
from datetime import datetime
import os
import sys
import signal
import psutil
import time

# Logging ayarları
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/kodlama-asistani/app.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class CodeAssistantServer:
    """TAM ÖZELLİKLİ WebSocket server sınıfı"""
    
    def __init__(self):
        self.home_clients = {}      # Ev makinesi LLM client'ları
        self.web_clients = {}       # Web browser client'ları
        self.pending_requests = {}  # Bekleyen istekler
        self.stats = {
            "total_requests": 0,
            "successful_responses": 0,
            "errors": 0,
            "start_time": datetime.now(),
            "clients_connected": 0,
            "total_clients": 0
        }
        self.server = None
        
    async def register_client(self, websocket, client_type, client_info=None):
        """Client kaydı"""
        client_id = str(uuid.uuid4())
        
        client_data = {
            "websocket": websocket,
            "connected_at": datetime.now(),
            "client_id": client_id,
            "client_info": client_info or {},
            "last_ping": datetime.now()
        }
        
        if client_type == "home_llm":
            self.home_clients[client_id] = client_data
            system_info = client_info.get('system', 'Unknown')
            gpu_info = client_info.get('gpu', 'Unknown GPU')
            model_info = client_info.get('model', 'Unknown Model')
            logger.info(f"🏠 Ev LLM client bağlandı: {client_id[:8]} | {system_info} | {gpu_info} | {model_info}")
            
        elif client_type == "web_client":
            self.web_clients[client_id] = client_data
            user_agent = client_info.get('user_agent', 'Unknown Browser')[:50]
            logger.info(f"🌐 Web client bağlandı: {client_id[:8]} | {user_agent}")
            
        self.stats["clients_connected"] = len(self.home_clients) + len(self.web_clients)
        self.stats["total_clients"] += 1
        
        return client_id
    
    async def unregister_client(self, client_id):
        """Client kaydını sil"""
        if client_id in self.home_clients:
            del self.home_clients[client_id]
            logger.info(f"🏠 Ev LLM client ayrıldı: {client_id[:8]}")
        elif client_id in self.web_clients:
            del self.web_clients[client_id]
            logger.info(f"🌐 Web client ayrıldı: {client_id[:8]}")
            
        self.stats["clients_connected"] = len(self.home_clients) + len(self.web_clients)
    
    async def handle_web_request(self, data, client_id):
        """Web client'tan gelen kod isteğini işle"""
        if not self.home_clients:
            self.stats["errors"] += 1
            return {
                "type": "error",
                "message": "🏠 Ev makinesindeki LLM servisi çevrimdışı. Lütfen ev client'ını başlatın ve bağlantıyı kontrol edin."
            }
        
        prompt = data.get("prompt", "").strip()
        if not prompt:
            return {
                "type": "error", 
                "message": "❌ Boş kod isteği gönderilemez."
            }
            
        request_id = str(uuid.uuid4())
        self.pending_requests[request_id] = {
            "web_client_id": client_id,
            "timestamp": datetime.now(),
            "prompt": prompt
        }
        
        # İlk kullanılabilir ev client'ına gönder
        home_client = list(self.home_clients.values())[0]
        
        message = {
            "type": "code_request",
            "request_id": request_id,
            "prompt": prompt,
            "timestamp": datetime.now().isoformat(),
            "client_info": self.web_clients[client_id]["client_info"]
        }
        
        try:
            await home_client["websocket"].send(json.dumps(message))
            self.stats["total_requests"] += 1
            
            logger.info(f"📨 Kod isteği gönderildi: {prompt[:60]}{'...' if len(prompt) > 60 else ''} (ID: {request_id[:8]})")
            
            return {
                "type": "request_sent",
                "request_id": request_id,
                "message": "🚀 İstek ev makinesine gönderildi, AI düşünüyor..."
            }
        except Exception as e:
            logger.error(f"❌ Ev client'a mesaj gönderilemedi: {e}")
            return {
                "type": "error",
                "message": "🔌 Ev makinesine bağlantı sorunu. Lütfen ev client'ını kontrol edin."
            }
    
    async def handle_home_response(self, data):
        """Ev makinesinden gelen yanıtı işle"""
        request_id = data.get("request_id")
        
        if request_id in self.pending_requests:
            request_info = self.pending_requests[request_id]
            web_client_id = request_info["web_client_id"]
            
            if web_client_id in self.web_clients:
                response_text = data.get("response", "")
                
                response = {
                    "type": "code_response",
                    "request_id": request_id,
                    "response": response_text,
                    "timestamp": data.get("timestamp", datetime.now().isoformat())
                }
                
                try:
                    web_client = self.web_clients[web_client_id]
                    await web_client["websocket"].send(json.dumps(response))
                    
                    self.stats["successful_responses"] += 1
                    logger.info(f"✅ Yanıt web client'a iletildi: {len(response_text)} karakter (ID: {request_id[:8]})")
                    
                except Exception as e:
                    logger.error(f"❌ Web client'a yanıt gönderilemedi: {e}")
                    
            del self.pending_requests[request_id]
        else:
            logger.warning(f"⚠️ Bilinmeyen request_id: {request_id}")
    
    async def handle_ping_pong(self, client_id, client_type):
        """Ping-pong ile bağlantı sağlığını kontrol et"""
        clients_dict = self.home_clients if client_type == "home_llm" else self.web_clients
        
        if client_id in clients_dict:
            clients_dict[client_id]["last_ping"] = datetime.now()
    
    async def handle_client(self, websocket, path):
        """WebSocket client bağlantılarını yönet"""
        client_id = None
        client_type = None
        
        try:
            async for message in websocket:
                try:
                    data = json.loads(message)
                    message_type = data.get("type")
                    
                    if message_type == "register":
                        client_type = data.get("client_type")
                        client_info = data.get("client_info", {})
                        client_id = await self.register_client(websocket, client_type, client_info)
                        
                        await websocket.send(json.dumps({
                            "type": "registered",
                            "client_id": client_id,
                            "server_time": datetime.now().isoformat(),
                            "server_version": "1.0.0"
                        }))
                        
                    elif message_type == "code_request" and client_id in self.web_clients:
                        response = await self.handle_web_request(data, client_id)
                        await websocket.send(json.dumps(response))
                        
                    elif message_type == "code_response" and client_id in self.home_clients:
                        await self.handle_home_response(data)
                        
                    elif message_type == "ping":
                        await self.handle_ping_pong(client_id, client_type)
                        await websocket.send(json.dumps({
                            "type": "pong",
                            "timestamp": datetime.now().isoformat()
                        }))
                        
                    elif message_type == "error":
                        error_msg = data.get("message", "Bilinmeyen hata")
                        logger.error(f"❌ Client hatası ({client_id[:8] if client_id else 'Unknown'}): {error_msg}")
                        
                except json.JSONDecodeError:
                    logger.error("❌ Geçersiz JSON mesajı alındı")
                except Exception as e:
                    logger.error(f"❌ Mesaj işleme hatası: {e}")
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info(f"🔌 WebSocket bağlantısı kapatıldı: {client_id[:8] if client_id else 'Unknown'}")
        except Exception as e:
            logger.error(f"❌ WebSocket hatası: {e}")
        finally:
            if client_id:
                await self.unregister_client(client_id)

    async def start_server(self):
        """WebSocket server'ı başlat"""
        try:
            logger.info("🔌 WebSocket server başlatılıyor (port 8765)...")
            
            self.server = await websockets.serve(
                self.handle_client,
                "0.0.0.0",
                8765,
                ping_interval=30,
                ping_timeout=10,
                max_size=10**6,  # 1MB max message size
                compression=None
            )
            
            logger.info("✅ WebSocket server başarıyla başlatıldı")
            return self.server
            
        except Exception as e:
            logger.error(f"❌ WebSocket server başlatma hatası: {e}")
            raise

# Global WebSocket server instance
websocket_server = None

def run_websocket_server():
    """WebSocket server'ı ayrı thread'de çalıştır"""
    global websocket_server
    
    def websocket_thread():
        try:
            logger.info("🚀 WebSocket thread başlatılıyor...")
            
            # Yeni event loop oluştur
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            websocket_server = CodeAssistantServer()
            
            # Server'ı başlat ve çalışır durumda tut
            server = loop.run_until_complete(websocket_server.start_server())
            logger.info("🔄 WebSocket server çalışıyor, bağlantılar bekleniyor...")
            loop.run_until_complete(server.wait_closed())
            
        except Exception as e:
            logger.error(f"❌ WebSocket thread hatası: {e}")
            import traceback
            traceback.print_exc()
    
    # Thread'i başlat
    thread = threading.Thread(target=websocket_thread, daemon=True)
    thread.start()
    logger.info("✅ WebSocket thread başlatıldı")
    return thread

# Flask uygulaması
app = Flask(__name__)
app.config['SECRET_KEY'] = 'kodlama-asistani-secret-key-2025'

# TAM ÖZELLİKLİ HTML Template
HTML_TEMPLATE = '''<!DOCTYPE html>
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
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
            line-height: 1.6;
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
            padding: 30px; 
            margin-bottom: 25px; 
            backdrop-filter: blur(15px); 
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
            text-align: center; 
            border: 1px solid rgba(255, 255, 255, 0.2);
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
            margin-bottom: 20px;
            font-weight: 500;
        }
        
        .status { 
            display: inline-flex;
            align-items: center;
            gap: 10px;
            padding: 12px 24px; 
            border-radius: 25px; 
            font-weight: bold; 
            font-size: 0.95rem; 
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        }
        
        .status.connected { 
            background: linear-gradient(135deg, #d1fae5, #a7f3d0); 
            color: #065f46; 
            border: 2px solid #10b981;
        }
        
        .status.disconnected { 
            background: linear-gradient(135deg, #fef2f2, #fecaca); 
            color: #991b1b;
            border: 2px solid #ef4444;
        }
        
        .status.connecting { 
            background: linear-gradient(135deg, #fef3c7, #fde68a); 
            color: #92400e;
            border: 2px solid #f59e0b;
        }
        
        .status-indicator {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            animation: pulse 2s infinite;
        }
        
        .connected .status-indicator { background: #10b981; }
        .disconnected .status-indicator { background: #ef4444; }
        .connecting .status-indicator { background: #f59e0b; }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.7; transform: scale(1.1); }
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
            padding: 30px; 
            backdrop-filter: blur(15px); 
            box-shadow: 0 15px 50px rgba(0, 0, 0, 0.1); 
            display: flex; 
            flex-direction: column;
            border: 1px solid rgba(255, 255, 255, 0.2);
            transition: transform 0.3s ease;
        }
        
        .input-section:hover, .output-section:hover {
            transform: translateY(-5px);
        }
        
        .section-title { 
            font-size: 1.4rem; 
            font-weight: bold; 
            margin-bottom: 20px; 
            color: #4c51bf; 
            border-bottom: 3px solid #4c51bf; 
            padding-bottom: 12px; 
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .prompt-input { 
            width: 100%; 
            min-height: 240px; 
            border: 2px solid #e5e7eb; 
            border-radius: 15px; 
            padding: 20px; 
            font-family: 'JetBrains Mono', 'Fira Code', 'Consolas', 'SF Mono', monospace; 
            font-size: 14px; 
            resize: vertical; 
            transition: all 0.3s ease; 
            flex: 1;
            line-height: 1.6;
            background: #fafafa;
        }
        
        .prompt-input:focus { 
            outline: none; 
            border-color: #4c51bf; 
            box-shadow: 0 0 25px rgba(76, 81, 191, 0.2);
            transform: translateY(-2px);
            background: white;
        }
        
        .prompt-input::placeholder {
            color: #9ca3af;
            font-style: italic;
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
            padding: 15px 35px; 
            border-radius: 30px; 
            font-weight: bold; 
            cursor: pointer; 
            transition: all 0.3s ease; 
            font-size: 1rem;
            display: flex;
            align-items: center;
            gap: 10px;
            box-shadow: 0 6px 20px rgba(76, 81, 191, 0.3);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .send-btn:hover:not(:disabled) { 
            transform: translateY(-3px); 
            box-shadow: 0 10px 30px rgba(76, 81, 191, 0.4);
            filter: brightness(1.1);
        }
        
        .send-btn:active:not(:disabled) {
            transform: translateY(-1px);
        }
        
        .send-btn:disabled { 
            opacity: 0.6; 
            cursor: not-allowed; 
            transform: none;
            filter: none;
        }
        
        .clear-btn { 
            background: linear-gradient(135deg, #6b7280, #4b5563); 
            color: white; 
            border: none; 
            padding: 15px 25px; 
            border-radius: 30px; 
            cursor: pointer; 
            transition: all 0.3s ease;
            font-weight: 500;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .clear-btn:hover { 
            background: linear-gradient(135deg, #4b5563, #374151);
            transform: translateY(-2px);
        }
        
        .output-area { 
            flex: 1; 
            border: 2px solid #e5e7eb; 
            border-radius: 15px; 
            padding: 25px; 
            background: #f9fafb; 
            overflow-y: auto; 
            min-height: 400px;
            max-height: 600px;
            scroll-behavior: smooth;
        }
        
        .output-area::-webkit-scrollbar {
            width: 8px;
        }
        
        .output-area::-webkit-scrollbar-track {
            background: #f1f1f1;
            border-radius: 10px;
        }
        
        .output-area::-webkit-scrollbar-thumb {
            background: #c1c1c1;
            border-radius: 10px;
        }
        
        .output-area::-webkit-scrollbar-thumb:hover {
            background: #a1a1a1;
        }
        
        .loading { 
            display: inline-block; 
            width: 22px; 
            height: 22px; 
            border: 3px solid #f3f4f6; 
            border-top: 3px solid #4c51bf; 
            border-radius: 50%; 
            animation: spin 1s linear infinite; 
            margin-right: 12px; 
        }
        
        @keyframes spin { 
            0% { transform: rotate(0deg); } 
            100% { transform: rotate(360deg); } 
        }
        
        .response { 
            margin-bottom: 25px; 
            padding: 25px; 
            border-radius: 15px; 
            border-left: 5px solid #4c51bf; 
            background: white; 
            box-shadow: 0 5px 20px rgba(0, 0, 0, 0.08);
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }
        
        .response::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 2px;
            background: linear-gradient(90deg, #4c51bf, #667eea);
        }
        
        .response:hover {
            transform: translateY(-3px);
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.12);
        }
        
        .response-header { 
            font-weight: bold; 
            color: #4c51bf; 
            margin-bottom: 15px; 
            font-size: 1rem;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .code-block { 
            background: #1f2937; 
            color: #f9fafb; 
            padding: 25px; 
            border-radius: 12px; 
            overflow-x: auto; 
            margin: 15px 0; 
            font-family: 'JetBrains Mono', 'Fira Code', 'Consolas', 'SF Mono', monospace; 
            font-size: 13px;
            line-height: 1.6;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            position: relative;
        }
        
        .code-block::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(90deg, #10b981, #34d399);
        }
        
        .quick-prompts { 
            display: flex; 
            flex-wrap: wrap; 
            gap: 12px; 
            margin-top: 20px; 
        }
        
        .quick-prompt { 
            background: linear-gradient(135deg, #f8fafc, #f1f5f9); 
            border: 2px solid #e2e8f0; 
            border-radius: 25px; 
            padding: 10px 18px; 
            font-size: 0.85rem; 
            cursor: pointer; 
            transition: all 0.3s ease;
            font-weight: 500;
            white-space: nowrap;
        }
        
        .quick-prompt:hover { 
            background: linear-gradient(135deg, #4c51bf, #667eea); 
            color: white;
            border-color: #4c51bf;
            transform: translateY(-2px);
            box-shadow: 0 4px 15px rgba(76, 81, 191, 0.3);
        }
        
        .footer {
            text-align: center;
            padding: 25px;
            color: rgba(255,255,255,0.9);
            font-size: 0.9rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 15px;
            backdrop-filter: blur(10px);
        }
        
        .error-response {
            border-left-color: #ef4444;
            background: linear-gradient(135deg, #fef2f2, #fecaca);
        }
        
        .error-response .response-header {
            color: #dc2626;
        }
        
        .success-glow {
            animation: successGlow 0.5s ease-in-out;
        }
        
        @keyframes successGlow {
            0% { box-shadow: 0 5px 20px rgba(0, 0, 0, 0.08); }
            50% { box-shadow: 0 5px 20px rgba(16, 185, 129, 0.3); }
            100% { box-shadow: 0 5px 20px rgba(0, 0, 0, 0.08); }
        }
        
        @media (max-width: 768px) { 
            .main-content { 
                grid-template-columns: 1fr; 
                gap: 20px;
            } 
            
            .header h1 { 
                font-size: 2rem; 
            }
            
            .header p {
                font-size: 1rem;
            }
            
            .controls { 
                flex-direction: column; 
                align-items: stretch; 
            } 
            
            .send-btn, .clear-btn { 
                width: 100%; 
                justify-content: center;
                margin-bottom: 10px; 
            }
            
            .container {
                padding: 15px;
            }
            
            .input-section, .output-section {
                padding: 20px;
            }
            
            .quick-prompts {
                justify-content: center;
            }
        }
        
        @media (max-width: 480px) {
            .quick-prompt {
                font-size: 0.8rem;
                padding: 8px 14px;
            }
            
            .prompt-input {
                min-height: 200px;
                font-size: 13px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 Kodlama Asistanı</h1>
            <p>GTX 1050 Ti • DeepSeek Coder 6.7B • Port 8080 • Tam Özellikli</p>
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

🎯 Örnek sorular:
• Python'da CSV dosyası okuma ve işleme kodu
• React'ta responsive navbar component'i oluştur  
• JavaScript'te async/await ile API çağrısı
• SQL sorgusu performans optimizasyonu
• Docker multi-stage build örneği
• Git workflow ve best practices

💡 İpucu: Ctrl+Enter ile hızlı gönderim"></textarea>
                
                <div class="controls">
                    <button class="send-btn" id="sendBtn">
                        <span>🚀</span>
                        <span id="sendText">Gönder</span>
                    </button>
                    <button class="clear-btn" id="clearBtn">
                        <span>🧹</span>
                        <span>Temizle</span>
                    </button>
                </div>
                
                <div class="quick-prompts">
                    <div class="quick-prompt" data-prompt="Python'da pandas kullanarak CSV dosyası işleme ve analiz kodu yaz">🐍 Python CSV</div>
                    <div class="quick-prompt" data-prompt="React'ta modern state yönetimi hooks kullanarak component yaz">⚛️ React Hooks</div>
                    <div class="quick-prompt" data-prompt="JavaScript'te async/await ile REST API çağrısı ve hata yönetimi">🌐 API Call</div>
                    <div class="quick-prompt" data-prompt="SQL sorgusu performans optimizasyonu teknikleri ve indexleme">🗄️ SQL Optimize</div>
                    <div class="quick-prompt" data-prompt="Docker multi-stage build ile Node.js uygulaması containerize etme">🐳 Docker</div>
                    <div class="quick-prompt" data-prompt="Git workflow, branching strategy ve best practices">📋 Git Flow</div>
                </div>
            </div>
            
            <div class="output-section">
                <div class="section-title">
                    <span>💬</span>
                    <span>AI Yanıtları</span>
                </div>
                <div class="output-area" id="outputArea">
                    <div style="text-align: center; color: #6b7280; margin-top: 80px;">
                        <div style="font-size: 3rem; margin-bottom: 20px;">🎯</div>
                        <p style="font-size: 1.2rem; margin-bottom: 15px; font-weight: 600;">Hazırım!</p>
                        <p style="font-size: 1rem; margin-bottom: 20px; color: #9ca3af;">Kodlama sorunuzu yazın ve profesyonel çözümü alın</p>
                        <div style="font-size: 0.85rem; color: #9ca3af; line-height: 1.8;">
                            <p>🤖 <strong>Model:</strong> DeepSeek Coder 6.7B</p>
                            <p>🎮 <strong>GPU:</strong> GTX 1050 Ti 4GB</p>
                            <p>🌐 <strong>Port:</strong> 8080 (WebSocket: 8765)</p>
                            <p>⚡ <strong>Yanıt süresi:</strong> ~15-30 saniye</p>
                            <p>🎯 <strong>Diller:</strong> Python, JS, React, SQL, Docker, Git</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>Made with ❤️ for developers • Powered by GTX 1050 Ti • DeepSeek Coder AI • WebSocket Fixed</p>
        </div>
    </div>

    <script>
        class CodeAssistant {
            constructor() {
                this.ws = null;
                this.isConnected = false;
                this.reconnectAttempts = 0;
                this.maxReconnectAttempts = 10;
                this.reconnectDelay = 3000;
                this.requestCount = 0;
                this.initElements();
                this.bindEvents();
                this.connect();
                this.startHeartbeat();
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
                        e.preventDefault();
                        this.sendPrompt();
                    }
                });
                
                this.promptInput.addEventListener('input', () => {
                    this.adjustTextareaHeight();
                });
                
                document.querySelectorAll('.quick-prompt').forEach(btn => {
                    btn.addEventListener('click', () => {
                        this.promptInput.value = btn.dataset.prompt;
                        this.promptInput.focus();
                        this.adjustTextareaHeight();
                    });
                });
                
                // Visibility change detection
                document.addEventListener('visibilitychange', () => {
                    if (document.visibilityState === 'visible' && !this.isConnected) {
                        this.connect();
                    }
                });
            }
            
            adjustTextareaHeight() {
                const textarea = this.promptInput;
                textarea.style.height = 'auto';
                textarea.style.height = Math.max(240, textarea.scrollHeight) + 'px';
            }
            
            connect() {
                if (this.ws && this.ws.readyState === WebSocket.CONNECTING) {
                    return;
                }
                
                const wsUrl = `ws://${window.location.hostname}:8765`;
                
                try {
                    this.updateStatus('connecting', '🔄 Bağlanıyor...');
                    this.ws = new WebSocket(wsUrl);
                    
                    this.ws.onopen = () => {
                        this.isConnected = true;
                        this.reconnectAttempts = 0;
                        this.updateStatus('connected', '🟢 Bağlı & Hazır');
                        
                        this.ws.send(JSON.stringify({
                            type: 'register',
                            client_type: 'web_client',
                            client_info: {
                                user_agent: navigator.userAgent,
                                screen_resolution: `${screen.width}x${screen.height}`,
                                language: navigator.language,
                                platform: navigator.platform
                            },
                            timestamp: new Date().toISOString()
                        }));
                        
                        this.showWelcomeMessage();
                    };
                    
                    this.ws.onmessage = (event) => {
                        try {
                            const data = JSON.parse(event.data);
                            this.handleMessage(data);
                        } catch (e) {
                            console.error('JSON parse error:', e);
                        }
                    };
                    
                    this.ws.onclose = (event) => {
                        this.isConnected = false;
                        console.log('WebSocket closed:', event.code, event.reason);
                        
                        if (event.code !== 1000) { // Not normal closure
                            this.updateStatus('disconnected', '🔴 Bağlantı Kesildi');
                            this.scheduleReconnect();
                        }
                    };
                    
                    this.ws.onerror = (error) => {
                        console.error('WebSocket error:', error);
                        this.updateStatus('disconnected', '❌ Bağlantı Hatası');
                    };
                    
                } catch (error) {
                    console.error('WebSocket connection error:', error);
                    this.updateStatus('disconnected', '❌ Bağlantı Hatası');
                    this.scheduleReconnect();
                }
            }
            
            scheduleReconnect() {
                if (this.reconnectAttempts < this.maxReconnectAttempts) {
                    this.reconnectAttempts++;
                    const delay = this.reconnectDelay * Math.min(this.reconnectAttempts, 5);
                    
                    setTimeout(() => {
                        if (!this.isConnected) {
                            console.log(`Reconnection attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts}`);
                            this.connect();
                        }
                    }, delay);
                } else {
                    this.updateStatus('disconnected', '❌ Bağlantı Başarısız');
                    this.showConnectionError();
                }
            }
            
            startHeartbeat() {
                setInterval(() => {
                    if (this.isConnected && this.ws.readyState === WebSocket.OPEN) {
                        this.ws.send(JSON.stringify({
                            type: 'ping',
                            timestamp: new Date().toISOString()
                        }));
                    }
                }, 30000); // 30 seconds
            }
            
            updateStatus(type, text) {
                this.statusEl.className = `status ${type}`;
                this.statusEl.innerHTML = `
                    <div class="status-indicator"></div>
                    <span>${text}</span>
                `;
            }
            
            showWelcomeMessage() {
                const welcomeDiv = document.createElement('div');
                welcomeDiv.className = 'response success-glow';
                welcomeDiv.innerHTML = `
                    <div class="response-header">
                        <span>🎉</span>
                        <span>Bağlantı Başarılı! (${new Date().toLocaleTimeString()})</span>
                    </div>
                    <div style="color: #059669;">
                        <p>✅ WebSocket sunucusuna başarıyla bağlandım!</p>
                        <p>🤖 DeepSeek Coder 6.7B modeli ev makinenizde hazır olduğunda</p>
                        <p>⚡ Kodlama sorularınızı sorabilir ve AI yanıtları alabilirsiniz</p>
                        <p style="margin-top: 10px; color: #6b7280; font-size: 0.9rem;">
                            💡 Ev makinenizdeki client'ı başlatmayı unutmayın!
                        </p>
                    </div>
                `;
                
                this.outputArea.appendChild(welcomeDiv);
                this.outputArea.scrollTop = this.outputArea.scrollHeight;
                
                // Auto-remove welcome message after 8 seconds
                setTimeout(() => {
                    if (welcomeDiv.parentNode) {
                        welcomeDiv.remove();
                    }
                }, 8000);
            }
            
            showConnectionError() {
                const errorDiv = document.createElement('div');
                errorDiv.className = 'response error-response';
                errorDiv.innerHTML = `
                    <div class="response-header">
                        <span>❌</span>
                        <span>WebSocket Bağlantı Hatası</span>
                    </div>
                    <div style="color: #dc2626;">
                        <p><strong>WebSocket sunucusuna bağlanamadım!</strong></p>
                        <p style="margin-top: 10px;">🔧 <strong>Kontrol edilecekler:</strong></p>
                        <ul style="margin-left: 20px; margin-top: 5px;">
                            <li>WebSocket server çalışıyor mu? (Port 8765)</li>
                            <li>İnternet bağlantısı stabil mi?</li>
                            <li>Firewall WebSocket portunu engelliyor mu?</li>
                        </ul>
                        <p style="margin-top: 10px;">🔄 Sayfa yenilemeyi deneyin</p>
                    </div>
                `;
                
                this.outputArea.appendChild(errorDiv);
                this.outputArea.scrollTop = this.outputArea.scrollHeight;
            }
            
            handleMessage(data) {
                switch (data.type) {
                    case 'registered':
                        console.log('✅ Client registered successfully:', data.client_id);
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
                        // Heartbeat response
                        break;
                        
                    default:
                        console.log('Unknown message type:', data.type);
                }
            }
            
            sendPrompt() {
                const prompt = this.promptInput.value.trim();
                
                if (!prompt) {
                    this.promptInput.focus();
                    this.showError('❌ Lütfen bir kod isteği yazın');
                    return;
                }
                
                if (!this.isConnected) {
                    this.showError('🔴 WebSocket sunucusuna bağlı değilsiniz. Lütfen bağlantıyı kontrol edin.');
                    return;
                }
                
                if (this.ws.readyState !== WebSocket.OPEN) {
                    this.showError('🔌 WebSocket bağlantısı hazır değil. Lütfen bekleyin.');
                    return;
                }
                
                this.requestCount++;
                
                try {
                    this.ws.send(JSON.stringify({
                        type: 'code_request',
                        prompt: prompt,
                        request_count: this.requestCount,
                        timestamp: new Date().toISOString()
                    }));
                    
                    this.sendBtn.disabled = true;
                    this.sendText.innerHTML = '<div class="loading"></div>Gönderiliyor...';
                    this.promptInput.style.opacity = '0.7';
                    
                } catch (error) {
                    console.error('Send error:', error);
                    this.showError('❌ Mesaj gönderilemedi. Bağlantıyı kontrol edin.');
                    this.resetSendButton();
                }
            }
            
            showLoading(requestId) {
                const loadingDiv = document.createElement('div');
                loadingDiv.className = 'response';
                loadingDiv.id = `response-${requestId}`;
                loadingDiv.innerHTML = `
                    <div class="response-header">
                        <span>🔄</span>
                        <span>AI Düşünüyor... (${new Date().toLocaleTimeString()})</span>
                    </div>
                    <div style="display: flex; align-items: center; gap: 12px; color: #6b7280;">
                        <div class="loading"></div>
                        <div>
                            <p>İstek ev makinesindeki GTX 1050 Ti'ye gönderildi...</p>
                            <p style="font-size: 0.9rem; margin-top: 5px; color: #9ca3af;">
                                ⏱️ DeepSeek Coder 6.7B modeli düşünüyor...
                            </p>
                        </div>
                    </div>
                `;
                
                this.outputArea.appendChild(loadingDiv);
                this.outputArea.scrollTop = this.outputArea.scrollHeight;
            }
            
            showResponse(data) {
                const responseEl = document.getElementById(`response-${data.request_id}`) || 
                    this.createResponseElement(data.request_id);
                
                const formattedResponse = this.formatResponse(data.response);
                const responseTime = new Date(data.timestamp);
                
                responseEl.className = 'response success-glow';
                responseEl.innerHTML = `
                    <div class="response-header">
                        <span>✅</span>
                        <span>AI Yanıtı (${responseTime.toLocaleTimeString()})</span>
                    </div>
                    <div>${formattedResponse}</div>
                    <div style="margin-top: 15px; padding-top: 15px; border-top: 1px solid #e5e7eb; font-size: 0.85rem; color: #6b7280;">
                        💡 Yanıt yararlı mıydı? Başka sorularınız varsa çekinmeyin!
                    </div>
                `;
                
                this.resetSendButton();
                this.outputArea.scrollTop = this.outputArea.scrollHeight;
                
                // Syntax highlighting
                setTimeout(() => {
                    if (typeof Prism !== 'undefined') {
                        Prism.highlightAllUnder(responseEl);
                    }
                }, 100);
            }
            
            createResponseElement(requestId) {
                const responseDiv = document.createElement('div');
                responseDiv.className = 'response';
                responseDiv.id = `response-${requestId}`;
                this.outputArea.appendChild(responseDiv);
                return responseDiv;
            }
            
            formatResponse(text) {
                // Enhanced code block detection
                return text
                    .replace(/```(\w+)?\n([\s\S]*?)```/g, (match, lang, code) => {
                        return `<pre class="code-block"><code class="language-${lang || 'text'}">${this.escapeHtml(code.trim())}</code></pre>`;
                    })
                    .replace(/`([^`\n]+)`/g, '<code style="background: #f1f3f4; padding: 3px 6px; border-radius: 4px; font-family: monospace; font-size: 0.9em;">$1</code>')
                    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
                    .replace(/\*(.*?)\*/g, '<em>$1</em>')
                    .replace(/\n\n/g, '</p><p>')
                    .replace(/\n/g, '<br>')
                    .replace(/^/, '<p>')
                    .replace(/$/, '</p>');
            }
            
            escapeHtml(text) {
                const div = document.createElement('div');
                div.textContent = text;
                return div.innerHTML;
            }
            
            showError(message) {
                const errorDiv = document.createElement('div');
                errorDiv.className = 'response error-response';
                errorDiv.innerHTML = `
                    <div class="response-header">
                        <span>❌</span>
                        <span>Hata</span>
                    </div>
                    <div style="color: #dc2626; margin-bottom: 15px;">${message}</div>
                    <div style="font-size: 0.9rem; color: #6b7280;">
                        💡 <strong>Çözüm önerileri:</strong><br>
                        • Ev makinesindeki client'ın çalıştığından emin olun<br>
                        • DeepSeek Coder modelinin yüklendiğini kontrol edin<br>
                        • İnternet bağlantınızı kontrol edin<br>
                        • WebSocket bağlantısını yenileyin
                    </div>
                `;
                
                this.outputArea.appendChild(errorDiv);
                this.resetSendButton();
                this.outputArea.scrollTop = this.outputArea.scrollHeight;
            }
            
            resetSendButton() {
                this.sendBtn.disabled = false;
                this.sendText.innerHTML = 'Gönder';
                this.promptInput.style.opacity = '1';
            }
            
            clearOutput() {
                this.outputArea.innerHTML = `
                    <div style="text-align: center; color: #6b7280; margin-top: 80px;">
                        <div style="font-size: 3rem; margin-bottom: 20px;">🧹</div>
                        <p style="font-size: 1.2rem; margin-bottom: 10px; font-weight: 600;">Yanıtlar temizlendi</p>
                        <p style="font-size: 1rem; color: #9ca3af;">Yeni sorularınızı yazabilirsiniz</p>
                    </div>
                `;
            }
        }
        
        // Initialize when page loads
        document.addEventListener('DOMContentLoaded', () => {
            window.codeAssistant = new CodeAssistant();
        });
        
        // Handle page unload
        window.addEventListener('beforeunload', () => {
            if (window.codeAssistant && window.codeAssistant.ws) {
                window.codeAssistant.ws.close(1000, 'Page unload');
            }
        });
    </script>
</body>
</html>'''

# Flask route'ları
@app.route('/')
def index():
    """Ana sayfa - TAM ÖZELLİKLİ HTML template döndür"""
    return HTML_TEMPLATE

@app.route('/api/status')
def api_status():
    """API durumu endpoint'i"""
    if websocket_server:
        uptime = datetime.now() - websocket_server.stats["start_time"]
        
        return jsonify({
            'status': 'running',
            'uptime_seconds': int(uptime.total_seconds()),
            'uptime_human': str(uptime).split('.')[0],
            'clients': {
                'home_clients': len(websocket_server.home_clients),
                'web_clients': len(websocket_server.web_clients),
                'total_connected': len(websocket_server.home_clients) + len(websocket_server.web_clients)
            },
            'requests': {
                'pending': len(websocket_server.pending_requests),
                'total': websocket_server.stats["total_requests"],
                'successful': websocket_server.stats["successful_responses"],
                'errors': websocket_server.stats["errors"]
            },
            'server_info': {
                'version': '1.0.0-full-working',
                'python_version': sys.version,
                'server_time': datetime.now().isoformat(),
                'ports': {
                    'flask': 5000,
                    'websocket': 8765,
                    'nginx': 8080
                }
            }
        })
    return jsonify({'status': 'websocket_not_ready'}), 503

@app.route('/api/health')
def health_check():
    """Sağlık kontrolü endpoint'i"""
    try:
        # Sistem sağlığı kontrolleri
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        health_status = {
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'version': '1.0.0-full-working',
            'websocket_server': 'running' if websocket_server else 'not_running',
            'system': {
                'cpu_percent': cpu_percent,
                'memory_percent': memory.percent,
                'disk_percent': (disk.used / disk.total) * 100,
                'memory_available_gb': round(memory.available / (1024**3), 2)
            }
        }
        
        # Sağlık durumu kontrolü
        if cpu_percent > 90:
            health_status['warnings'] = health_status.get('warnings', [])
            health_status['warnings'].append('High CPU usage')
        
        if memory.percent > 90:
            health_status['warnings'] = health_status.get('warnings', [])
            health_status['warnings'].append('High memory usage')
        
        return jsonify(health_status)
        
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500

@app.route('/api/clients')
def api_clients():
    """Bağlı client'ları listele"""
    if not websocket_server:
        return jsonify({'error': 'WebSocket server not running'}), 503
    
    clients_info = {
        'home_clients': [],
        'web_clients': [],
        'summary': {
            'total_home': len(websocket_server.home_clients),
            'total_web': len(websocket_server.web_clients),
            'total_all': len(websocket_server.home_clients) + len(websocket_server.web_clients)
        }
    }
    
    # Ev client'ları
    for client_id, client_data in websocket_server.home_clients.items():
        clients_info['home_clients'].append({
            'id': client_id[:8],
            'connected_at': client_data['connected_at'].isoformat(),
            'system': client_data['client_info'].get('system', 'Unknown'),
            'gpu': client_data['client_info'].get('gpu', 'Unknown'),
            'model': client_data['client_info'].get('model', 'Unknown')
        })
    
    # Web client'ları
    for client_id, client_data in websocket_server.web_clients.items():
        clients_info['web_clients'].append({
            'id': client_id[:8], 
            'connected_at': client_data['connected_at'].isoformat(),
            'user_agent': client_data['client_info'].get('user_agent', 'Unknown')[:50]
        })
    
    return jsonify(clients_info)

@app.errorhandler(404)
def not_found(error):
    """404 hata sayfası"""
    return jsonify({
        'error': 'Endpoint not found',
        'available_endpoints': [
            '/ - Ana sayfa (TAM ÖZELLİKLİ)',
            '/api/status - Sistem durumu',
            '/api/health - Sağlık kontrolü', 
            '/api/clients - Bağlı client\'lar'
        ]
    }), 404

@app.errorhandler(500) 
def internal_error(error):
    """500 hata sayfası"""
    logger.error(f"Internal server error: {error}")
    return jsonify({
        'error': 'Internal server error',
        'timestamp': datetime.now().isoformat()
    }), 500

def signal_handler(signum, frame):
    """Graceful shutdown"""
    logger.info(f"Signal {signum} received, shutting down gracefully...")
    sys.exit(0)

def main():
    """Ana fonksiyon"""
    # Signal handler'ları kaydet
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Log dizini oluştur
    os.makedirs('/var/log/kodlama-asistani', exist_ok=True)
    
    logger.info("🚀 Kodlama Asistanı TAM ÖZELLİKLİ Server başlatılıyor...")
    
    # WebSocket server'ı ayrı thread'de başlat
    logger.info("🔌 WebSocket server thread başlatılıyor...")
    websocket_thread = run_websocket_server()
    
    # WebSocket'in başlaması için biraz bekle
    time.sleep(3)
    
    # Flask server'ı başlat
    logger.info("🌐 Flask web server başlatılıyor (port 5000)...")
    
    # Production için Gunicorn kullanılacak, development için Flask
    if os.getenv('FLASK_ENV') == 'development':
        app.run(host='0.0.0.0', port=5000, debug=True, threaded=True)
    else:
        # Gunicorn ile production'da çalışacak
        app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)

if __name__ == "__main__":
    main()