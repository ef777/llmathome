# config.py - Kodlama Asistanı Konfigürasyonu

# ============================================
# SUNUCU AYARLARI - MUTLAKA DEĞİŞTİRİN!
# ============================================

# Sunucunuzun statik IP adresini buraya yazın
SUNUCU_IP = "YOUR_SERVER_IP"  # Örnek: "192.168.1.100" veya "203.0.113.10"

# WebSocket portu (varsayılan: 8765)
WEBSOCKET_PORT = 8765

# Flask web server portu
FLASK_PORT = 5000

# ============================================
# LLM MODEL AYARLARI
# ============================================

# Ollama API URL (localhost - değiştirmeyin)
OLLAMA_URL = "http://localhost:11434"

# Kullanılacak model (GTX 1050 Ti için optimize edilmiş)
DEFAULT_MODEL = "deepseek-coder:6.7b-instruct-q4_0"

# Alternatif modeller (daha hızlı ama daha küçük):
# "codellama:7b-instruct-q4_0"    # Meta'nın CodeLlama modeli
# "phi3:medium-4k-instruct-q4_0"  # Microsoft'un hızlı modeli

# ============================================
# MODEL PARAMETRELERİ (PERFORMANS AYARLARI)
# ============================================

MODEL_PARAMS = {
    # Yaratıcılık seviyesi (0.0 = deterministik, 1.0 = çok yaratık)
    "temperature": 0.1,
    
    # Kelime seçimi çeşitliliği (0.1-1.0)
    "top_p": 0.9,
    
    # Maksimum bağlam uzunluğu (GTX 1050 Ti için optimize)
    # 4096 = uzun kod parçaları, 2048 = daha hızlı yanıtlar
    "num_ctx": 4096,
    
    # Tekrar cezası (1.0 = yok, 1.1 = hafif ceza)
    "repeat_penalty": 1.1,
    
    # Maksimum token sayısı (0 = sınırsız)
    "num_predict": 0,
    
    # Top-k sampling (0 = kapalı)
    "top_k": 40
}

# ============================================
# GTX 1050 Ti PERFORMANS PROFILLERI
# ============================================

# Hızlı yanıt için (daha az VRAM, daha hızlı)
FAST_PARAMS = {
    "temperature": 0.05,
    "top_p": 0.8,
    "num_ctx": 2048,
    "repeat_penalty": 1.0
}

# Kaliteli yanıt için (daha çok VRAM, daha yavaş)
QUALITY_PARAMS = {
    "temperature": 0.15,
    "top_p": 0.95,
    "num_ctx": 4096,
    "repeat_penalty": 1.1
}

# Aktif profil (MODEL_PARAMS, FAST_PARAMS, veya QUALITY_PARAMS)
ACTIVE_PROFILE = MODEL_PARAMS

# ============================================
# LOGGİNG AYARLARI
# ============================================

# Log seviyesi (DEBUG, INFO, WARNING, ERROR)
LOG_LEVEL = "INFO"

# Log dosyası adı
LOG_FILE = "ev_client.log"

# Terminal'de renkli çıktı
COLORED_OUTPUT = True

# ============================================
# BAĞLANTI AYARLARI
# ============================================

# WebSocket bağlantı timeout (saniye)
CONNECTION_TIMEOUT = 30

# Yeniden bağlanma aralığı (saniye)
RECONNECT_INTERVAL = 5

# Ping interval (saniye)
PING_INTERVAL = 30

# ============================================
# SİSTEM BİLGİLERİ
# ============================================

# Client sistem bilgileri (sunucuya gönderilir)
CLIENT_INFO = {
    "system": "Windows",
    "gpu": "GTX 1050 Ti 4GB",
    "capabilities": [
        "code_generation",
        "code_review", 
        "debugging",
        "optimization",
        "explanation"
    ]
}

# ============================================
# HATA MESAJLARI
# ============================================

ERROR_MESSAGES = {
    "no_server_ip": """
❌ SUNUCU IP ADRESİ AYARLANMAMIŞ!

Bu dosyayı düzenleyip SUNUCU_IP değişkenini ayarlayın:
SUNUCU_IP = "192.168.1.100"  # Örnek IP adresi

Sunucunuzun IP adresini öğrenmek için:
- Ubuntu sunucuda: ip addr show
- Router admin panelinden kontrol edin
""",
    
    "ollama_not_running": """
❌ OLLAMA SERVİSİ ÇALIŞMIYOR!

Çözüm adımları:
1. Yeni PowerShell penceresi açın
2. 'ollama serve' komutunu çalıştırın  
3. Bu client'ı tekrar başlatın

Model indirmek için:
ollama pull deepseek-coder:6.7b-instruct-q4_0
""",
    
    "model_not_found": """
❌ MODEL BULUNAMADI!

Model indirmek için:
ollama pull deepseek-coder:6.7b-instruct-q4_0

Mevcut modelleri görmek için:
ollama list
""",
    
    "connection_failed": """
❌ SUNUCUYA BAĞLANILAMIYOR!

Kontrol edilecekler:
1. Sunucu IP adresi doğru mu?
2. Sunucuda Flask server çalışıyor mu?
3. Port 8765 açık mı?
4. İnternet bağlantısı var mı?
"""
}

# ============================================
# GELİŞMİŞ AYARLAR
# ============================================

# GPU bellek optimizasyonu
GPU_MEMORY_FRACTION = 0.9

# CPU core sayısı (0 = otomatik)
NUM_THREADS = 0

# Cache kullanımı
USE_CACHE = True

# Sistem izleme
ENABLE_MONITORING = True

# Debug modu
DEBUG_MODE = False