

REM ==========================================
REM install_model.bat - Alternatif Model Kurulumu
REM ==========================================

@echo off
title Model Kurulumu - Kodlama Asistanı
color 0F
echo.
echo  🤖 ALTERNATİF MODEL KURULUMU
echo  ═══════════════════════════════════════
echo.
echo  GTX 1050 Ti için önerilen modeller:
echo.
echo  1. DeepSeek Coder 6.7B (Varsayılan) - En iyi kalite
echo  2. CodeLlama 7B - Meta'nın modeli  
echo  3. Phi-3 Medium - En hızlı yanıtlar
echo.
echo  Hangi modeli kurmak istiyorsunuz?
set /p choice=Seçim (1-3): 

if "%choice%"=="1" (
    echo  📥 DeepSeek Coder 6.7B indiriliyor...
    ollama pull deepseek-coder:6.7b-instruct-q4_0
) else if "%choice%"=="2" (
    echo  📥 CodeLlama 7B indiriliyor...
    ollama pull codellama:7b-instruct-q4_0
) else if "%choice%"=="3" (
    echo  📥 Phi-3 Medium indiriliyor...
    ollama pull phi3:medium-4k-instruct-q4_0
) else (
    echo  ❌ Geçersiz seçim!
    pause
    exit /b 1
)

echo.
echo  ✅ Model kurulumu tamamlandı!
echo  🔧 config.py dosyasında DEFAULT_MODEL değişkenini güncelleyin
echo.
ollama list
pause