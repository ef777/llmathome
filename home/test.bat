
REM ==========================================
REM test.bat - Sistem Testleri
REM ==========================================

@echo off
title Test - Kodlama Asistanı
color 0E
echo.
echo  🧪 SİSTEM TESTLERİ BAŞLIYOR...
echo  ═══════════════════════════════════════
echo.

cd /d "%~dp0"

REM Sanal ortami aktif et
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
) else (
    echo  ❌ Sanal ortam bulunamadi!
    pause
    exit /b 1
)

echo  📋 Python testi...
python --version
if %errorlevel% neq 0 (
    echo  ❌ Python bulunamadi!
    pause
    exit /b 1
)
echo  ✅ Python OK
echo.

echo  📋 Python paket testi...
python -c "import websockets, requests, colorama; print('✅ Paketler OK')" 2>nul
if %errorlevel% neq 0 (
    echo  ❌ Python paketleri eksik!
    echo  💡 Çözüm: pip install -r requirements.txt
    pause
    exit /b 1
)
echo.

echo  📋 Ollama testi...
ollama list 2>nul
if %errorlevel% neq 0 (
    echo  ❌ Ollama bulunamadi veya çalışmiyor!
    echo  💡 Çözüm: ollama serve komutunu başka pencerede çalıştırın
    pause
    exit /b 1
)
echo  ✅ Ollama OK
echo.

echo  📋 Model testi (Bu biraz zaman alabilir)...
echo  Test sorusu: "Write a simple Python hello world"
echo.

python -c "
import requests
import time
try:
    start = time.time()
    response = requests.post('http://localhost:11434/api/generate', 
        json={
            'model': 'deepseek-coder:6.7b-instruct-q4_0',
            'prompt': 'Write a simple Python hello world program',
            'stream': False,
            'options': {'temperature': 0.1, 'num_ctx': 1024}
        }, timeout=60)
    
    if response.status_code == 200:
        result = response.json()['response']
        elapsed = time.time() - start
        print(f'✅ Model test başarılı! ({elapsed:.1f}s)')
        print(f'📝 Yanıt: {result[:150]}...' if len(result) > 150 else f'📝 Yanıt: {result}')
        
        if elapsed < 20:
            print('⚡ Mükemmel performans!')
        elif elapsed < 40:
            print('✅ İyi performans')
        else:
            print('⚠️ Yavaş performans - GPU kullanımını kontrol edin')
    else:
        print(f'❌ Model test başarısız - Status: {response.status_code}')
except Exception as e:
    print(f'❌ Test hatası: {str(e)}')
    print('💡 Ollama serve komutunun çalıştığından emin olun')
"

echo.
echo  📋 Konfigürasyon testi...
if exist "config.py" (
    python -c "
from config import *
if SUNUCU_IP == 'YOUR_SERVER_IP':
    print('❌ SUNUCU_IP ayarlanmamış!')
    print('💡 config.py dosyasını düzenleyin')
else:
    print(f'✅ Sunucu IP: {SUNUCU_IP}')
    print(f'✅ Model: {DEFAULT_MODEL}')
    print(f'✅ WebSocket Port: {WEBSOCKET_PORT}')
" 2>nul
) else (
    echo  ❌ config.py bulunamadi!
)

echo.
echo  📋 GPU testi...
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader,nounits 2>nul
if %errorlevel% neq 0 (
    echo  ⚠️ nvidia-smi bulunamadi veya GPU tespit edilemedi
) else (
    echo  ✅ GPU tespit edildi
)

echo.
echo  🎉 TEST TAMAMLANDI!
echo  ═══════════════════════════════════════
echo.
echo  📂 Log dosyası: ev_client.log
echo  🔧 Konfigürasyon: config.py  
echo  ▶️ Başlatma: start.bat
echo.
pause