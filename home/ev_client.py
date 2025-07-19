#!/usr/bin/env python3
# ev_client.py - Windows ev makinesinde çalışacak LLM client

import asyncio
import websockets
import json
import requests
import logging
from datetime import datetime
import colorama
from colorama import Fore, Style, Back
import os
import sys
import time
import traceback

# Renkli terminal için
colorama.init()

# Konfigürasyonu import et
try:
    from config import *
except ImportError:
    print(f"{Fore.RED}❌ config.py dosyası bulunamadı!{Style.RESET_ALL}")
    print("Lütfen config.py dosyasını oluşturun.")
    input("Devam etmek için Enter'a basın...")
    sys.exit(1)

# Logging ayarları
def setup_logging():
    """Logging sistemini kur"""
    log_format = '%(asctime)s - %(levelname)s - %(message)s'
    
    handlers = [
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
    ]
    
    if not DEBUG_MODE:
        handlers.append(logging.StreamHandler())
    
    logging.basicConfig(
        level=getattr(logging, LOG_LEVEL),
        format=log_format,
        handlers=handlers
    )
    
    return logging.getLogger(__name__)

logger = setup_logging()

def print_colored(message, color=Fore.WHITE, style=Style.NORMAL):
    """Renkli yazdırma"""
    if COLORED_OUTPUT:
        print(f"{style}{color}{message}{Style.RESET_ALL}")
    else:
        print(message)

def print_status(status, message):
    """Durum yazdırma"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    
    colors = {
        "INFO": Fore.BLUE,
        "SUCCESS": Fore.GREEN, 
        "WARNING": Fore.YELLOW,
        "ERROR": Fore.RED,
        "DEBUG": Fore.MAGENTA
    }
    
    color = colors.get(status, Fore.WHITE)
    print_colored(f"[{timestamp}] [{status}] {message}", color)

def print_banner():
    """Başlangıç banner'ı"""
    banner = f"""
{Fore.CYAN}╔═══════════════════════════════════════════════════════════════╗
║                    🤖 KODLAMA ASISTANI                       ║
║                     Windows Ev Client                        ║
║                                                               ║
║  GPU: GTX 1050 Ti 4GB     Model: DeepSeek Coder 6.7B        ║
║  Platform: Windows        WebSocket: Real-time               ║
╚═══════════════════════════════════════════════════════════════╝{Style.RESET_ALL}
"""
    print(banner)

def print_system_info():
    """Sistem bilgilerini göster"""
    print_colored("\n" + "="*60, Fore.CYAN)
    print_colored("📊 SİSTEM BİLGİLERİ", Fore.CYAN, Style.BRIGHT)
    print_colored("="*60, Fore.CYAN)
    
    print_colored(f"📂 Çalışma dizini: {os.getcwd()}", Fore.YELLOW)
    print_colored(f"🌐 Sunucu adresi: {SUNUCU_IP}:{WEBSOCKET_PORT}", Fore.YELLOW)
    print_colored(f"🤖 Model: {DEFAULT_MODEL}", Fore.YELLOW)
    print_colored(f"🔗 Ollama URL: {OLLAMA_URL}", Fore.YELLOW)
    print_colored(f"📋 Log dosyası: {LOG_FILE}", Fore.YELLOW)
    print_colored(f"🎚️ Profil: {'FAST' if ACTIVE_PROFILE == FAST_PARAMS else 'QUALITY' if ACTIVE_PROFILE == QUALITY_PARAMS else 'NORMAL'}", Fore.YELLOW)
    print_colored("="*60 + "\n", Fore.CYAN)

class LLMClient:
    def __init__(self):
        self.websocket = None
        self.running = False
        self.request_count = 0
        self.total_response_time = 0
        self.start_time = datetime.now()
        
    async def llm_request(self, prompt, model=DEFAULT_MODEL):
        """LLM'ye istek gönder"""
        try:
            start_time = time.time()
            print_status("INFO", f"LLM'ye gönderiliyor: {prompt[:50]}...")
            
            # İstek payload'ı
            payload = {
                "model": model,
                "prompt": prompt,
                "stream": False,
                "options": ACTIVE_PROFILE
            }
            
            response = requests.post(
                f"{OLLAMA_URL}/api/generate", 
                json=payload,
                timeout=120
            )
            
            if response.status_code == 200:
                result = response.json()["response"]
                response_time = time.time() - start_time
                self.total_response_time += response_time
                
                print_status("SUCCESS", f"Yanıt alındı: {len(result)} karakter, {response_time:.1f}s")
                logger.info(f"LLM response: {len(result)} chars, {response_time:.1f}s")
                
                return result
            else:
                error_msg = f"LLM hatası (Status: {response.status_code})"
                print_status("ERROR", error_msg)
                return error_msg
                
        except requests.exceptions.Timeout:
            error_msg = "LLM zaman aşımı (120 saniye)"
            print_status("ERROR", error_msg)
            return error_msg
        except Exception as e:
            error_msg = f"LLM isteği hatası: {str(e)}"
            print_status("ERROR", error_msg)
            logger.error(f"LLM request error: {e}")
            return error_msg
    
    async def handle_message(self, message):
        """Sunucudan gelen mesajları işle"""
        try:
            data = json.loads(message)
            
            if data["type"] == "code_request":
                self.request_count += 1
                
                # İstek başlığı
                print_colored(f"\n{'='*70}", Fore.CYAN)
                print_colored(f"📨 YENİ KOD İSTEĞİ #{self.request_count}", Fore.CYAN, Style.BRIGHT)
                print_colored(f"{'='*70}", Fore.CYAN)
                print_colored(f"🕐 Zaman: {datetime.now().strftime('%H:%M:%S')}", Fore.WHITE)
                print_colored(f"📝 Soru: {data['prompt'][:100]}{'...' if len(data['prompt']) > 100 else ''}", Fore.YELLOW)
                print_colored(f"🆔 Request ID: {data['request_id'][:8]}...", Fore.MAGENTA)
                print_colored(f"{'='*70}", Fore.CYAN)
                
                # LLM'ye gönder
                response = await self.llm_request(data["prompt"])
                
                # Yanıtı sunucuya gönder
                await self.websocket.send(json.dumps({
                    "type": "code_response",
                    "request_id": data["request_id"],
                    "response": response,
                    "timestamp": datetime.now().isoformat(),
                    "client_info": CLIENT_INFO
                }))
                
                # Başarı mesajı
                print_colored(f"\n✅ YANIT GÖNDERİLDİ #{self.request_count}", Fore.GREEN, Style.BRIGHT)
                print_colored(f"📊 Yanıt uzunluğu: {len(response)} karakter", Fore.GREEN)
                print_colored(f"📱 Web arayüzüne iletildi", Fore.GREEN)
                
                # Yanıt preview
                preview = response.replace('\n', ' ')[:200]
                print_colored(f"👀 Preview: {preview}{'...' if len(response) > 200 else ''}", Fore.WHITE)
                print_colored(f"{'='*70}\n", Fore.CYAN)
                
        except Exception as e:
            print_status("ERROR", f"Mesaj işleme hatası: {e}")
            logger.error(f"Message handling error: {e}")
            if self.websocket:
                await self.websocket.send(json.dumps({
                    "type": "error",
                    "message": str(e),
                    "timestamp": datetime.now().isoformat()
                }))
    
    def print_statistics(self):
        """İstatistikleri yazdır"""
        if self.request_count > 0:
            avg_response_time = self.total_response_time / self.request_count
            uptime = datetime.now() - self.start_time
            
            print_colored(f"\n📊 İSTATİSTİKLER", Fore.CYAN, Style.BRIGHT)
            print_colored(f"⏱️ Çalışma süresi: {str(uptime).split('.')[0]}", Fore.WHITE)
            print_colored(f"📨 Toplam istek: {self.request_count}", Fore.WHITE)
            print_colored(f"⚡ Ortalama yanıt süresi: {avg_response_time:.1f}s", Fore.WHITE)
            print_colored(f"🔥 En hızlı yanıt: {min(self.total_response_time, self.total_response_time):.1f}s" if self.request_count == 1 else "", Fore.WHITE)
    
    async def connect_to_server(self):
        """Sunucuya bağlan"""
        uri = f"ws://{SUNUCU_IP}:{WEBSOCKET_PORT}"
        
        while True:
            try:
                print_status("INFO", f"Sunucuya bağlanıyor: {uri}")
                
                async with websockets.connect(
                    uri, 
                    ping_interval=PING_INTERVAL,
                    ping_timeout=10,
                    close_timeout=10
                ) as websocket:
                    self.websocket = websocket
                    self.running = True
                    
                    # Bağlantı mesajı gönder
                    await websocket.send(json.dumps({
                        "type": "register",
                        "client_type": "home_llm",
                        "client_info": CLIENT_INFO,
                        "model": DEFAULT_MODEL,
                        "timestamp": datetime.now().isoformat()
                    }))
                    
                    # Başarı mesajı
                    print_colored("\n" + "="*70, Fore.GREEN)
                    print_status("SUCCESS", "🎉 SUNUCUYA BAŞARIYLA BAĞLANDI!")
                    print_colored(f"📱 Web arayüzü: http://{SUNUCU_IP}", Fore.CYAN, Style.BRIGHT)
                    print_colored(f"🤖 Model: {DEFAULT_MODEL}", Fore.CYAN)
                    print_colored(f"💾 VRAM Kullanımı: ~3.8GB", Fore.CYAN)
                    print_colored(f"⚡ Hazır durumdayım! Web arayüzünden kod isteklerinizi gönderin.", Fore.GREEN)
                    print_colored("="*70 + "\n", Fore.GREEN)
                    
                    print_status("INFO", "📞 Kod isteklerini bekliyorum...")
                    print_status("INFO", "🛑 Durdurmak için Ctrl+C basın\n")
                    
                    # Mesajları dinle
                    async for message in websocket:
                        await self.handle_message(message)
                        
            except websockets.exceptions.ConnectionClosed:
                print_status("WARNING", "⚠️ Bağlantı kesildi, yeniden bağlanıyor...")
                await asyncio.sleep(RECONNECT_INTERVAL)
            except Exception as e:
                print_status("ERROR", f"Bağlantı hatası: {e}")
                logger.error(f"Connection error: {e}")
                print_status("INFO", f"{RECONNECT_INTERVAL*2} saniye sonra yeniden denenecek...")
                await asyncio.sleep(RECONNECT_INTERVAL * 2)

def test_ollama():
    """Ollama servisini test et"""
    try:
        print_status("INFO", "🔍 Ollama servisi test ediliyor...")
        response = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)
        
        if response.status_code == 200:
            models = [model["name"] for model in response.json()["models"]]
            print_status("SUCCESS", "✅ Ollama servisi çalışıyor!")
            print_colored(f"📋 Mevcut modeller: {', '.join(models) if models else 'Hiç model yok'}", Fore.CYAN)
            
            # DeepSeek model kontrolü
            if DEFAULT_MODEL in models:
                print_status("SUCCESS", f"✅ Hedef model mevcut: {DEFAULT_MODEL}")
                return True
            else:
                print_status("WARNING", f"⚠️ Hedef model bulunamadı: {DEFAULT_MODEL}")
                print_colored(f"💡 Model indirmek için: ollama pull {DEFAULT_MODEL}", Fore.YELLOW)
                return False
        else:
            print_status("ERROR", f"❌ Ollama yanıt vermiyor (Status: {response.status_code})")
            return False
            
    except Exception as e:
        print_status("ERROR", f"❌ Ollama bağlantı hatası: {e}")
        return False

def test_model():
    """Model testi"""
    try:
        print_status("INFO", "🧪 Model performans testi yapılıyor...")
        
        test_prompt = "Write a simple Python hello world program"
        start_time = time.time()
        
        response = requests.post(f"{OLLAMA_URL}/api/generate", 
            json={
                "model": DEFAULT_MODEL,
                "prompt": test_prompt,
                "stream": False,
                "options": {"temperature": 0.1, "num_ctx": 1024}
            }, timeout=60)
        
        if response.status_code == 200:
            result = response.json()["response"]
            response_time = time.time() - start_time
            
            print_status("SUCCESS", f"✅ Model testi başarılı! ({response_time:.1f}s)")
            print_colored(f"📝 Test yanıtı: {result[:100]}{'...' if len(result) > 100 else ''}", Fore.GREEN)
            
            # Performans değerlendirmesi
            if response_time < 20:
                print_colored("⚡ Mükemmel performans!", Fore.GREEN)
            elif response_time < 40:
                print_colored("✅ İyi performans", Fore.YELLOW)
            else:
                print_colored("⚠️ Yavaş performans - GPU kullanımını kontrol edin", Fore.RED)
                
            return True
        else:
            print_status("ERROR", f"❌ Model testi başarısız (Status: {response.status_code})")
            return False
            
    except Exception as e:
        print_status("ERROR", f"❌ Model test hatası: {e}")
        return False

def main():
    """Ana fonksiyon"""
    print_banner()
    print_system_info()
    
    # Konfigürasyon kontrolü
    if SUNUCU_IP == "YOUR_SERVER_IP":
        print_colored(ERROR_MESSAGES["no_server_ip"], Fore.RED)
        input("\nDevam etmek için Enter'a basın...")
        return
    
    # Sistem kontrolleri
    print_status("INFO", "🔍 Sistem kontrolleri başlıyor...")
    
    # Ollama kontrolü
    if not test_ollama():
        print_colored(ERROR_MESSAGES["ollama_not_running"], Fore.RED)
        input("\nDevam etmek için Enter'a basın...")
        return
    
    # Model testi
    if not test_model():
        print_status("WARNING", "⚠️ Model testi başarısız, yine de devam ediliyor...")
        time.sleep(2)
    
    # WebSocket client başlat
    client = LLMClient()
    
    try:
        print_status("INFO", "🚀 WebSocket client başlatılıyor...")
        asyncio.run(client.connect_to_server())
    except KeyboardInterrupt:
        print_colored(f"\n\n{Fore.YELLOW}👋 Client kullanıcı tarafından durduruldu!{Style.RESET_ALL}")
        client.print_statistics()
        print_status("INFO", "🔒 Güvenli bir şekilde kapatılıyor...")
    except Exception as e:
        print_status("ERROR", f"❌ Beklenmeyen hata: {e}")
        logger.error(f"Unexpected error: {e}")
        logger.error(traceback.format_exc())
    finally:
        print_status("INFO", "👋 Client durduruldu. İyi günler!")

if __name__ == "__main__":
    main()