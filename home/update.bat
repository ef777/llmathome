
REM ==========================================
REM update.bat - Model ve Sistem Güncelleme
REM ==========================================

@echo off
title Kodlama Asistanı - Güncelleme
color 0D
echo.
echo  🔄 KODLAMA ASISTANI GÜNCELLEMESİ
echo  ═══════════════════════════════════════
echo.

cd /d "%~dp0"

echo  📦 Python paketleri güncelleniyor...
call venv\Scripts\activate.bat
pip install --upgrade pip
pip install --upgrade -r requirements.txt

echo.
echo  🤖 Ollama modelleri kontrol ediliyor...
ollama list

echo.
echo  💾 Model güncellemesi yapmak istiyor musunuz? (y/n)
set /p choice=Seçim: 
if /i "%choice%"=="y" (
    echo  🔄 DeepSeek Coder modeli güncelleniyor...
    ollama pull deepseek-coder:6.7b-instruct-q4_0
)

echo.
echo  🧹 Log dosyalarını temizlemek istiyor musunuz? (y/n)  
set /p choice=Seçim:
if /i "%choice%"=="y" (
    del /q ev_client.log 2>nul
    echo  ✅ Log dosyaları temizlendi
)

echo.
echo  ✅ Güncelleme tamamlandı!
pause