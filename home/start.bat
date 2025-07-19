REM ==========================================
REM start.bat - Kodlama Asistanı Başlatma
REM ==========================================

@echo off
title Kodlama Asistanı - Ev Client
color 0B
echo.
echo  ╔═══════════════════════════════════════════════════════════════╗
echo  ║                    🤖 KODLAMA ASISTANI                       ║
echo  ║                     Windows Ev Client                        ║
echo  ╚═══════════════════════════════════════════════════════════════╝
echo.
echo  📁 Proje dizini: %CD%
echo  🐍 Python sanal ortami aktif ediliyor...

cd /d "%~dp0"

REM Sanal ortami aktif et
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
    echo  ✅ Sanal ortam aktif edildi
) else (
    echo  ❌ Sanal ortam bulunamadi!
    echo  💡 Lutfen install.ps1 script'ini calistirin
    pause
    exit /b 1
)

echo.
echo  🧠 LLM Client baslatiliyor...
echo  📱 Web arayuzu: http://SUNUCU_IP_ADRESINIZ
echo.
echo  ⚠️  Bu pencereyi kapatmayin! Client calismaya devam ediyor...
echo  🛑 Durdurmak icin Ctrl+C basin
echo.

REM Python client'i bashlat
python ev_client.py

echo.
echo  👋 Client durduruldu.
echo  📊 Log dosyasini kontrol edin: ev_client.log
pause


