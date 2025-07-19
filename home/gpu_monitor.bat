
REM ==========================================
REM gpu_monitor.bat - GPU İzleme
REM ==========================================

@echo off
title GPU Monitoring - Kodlama Asistanı
color 0A
echo.
echo  📊 GPU KULLANIM İZLEME
echo  ═══════════════════════════════════════
echo  GPU: GTX 1050 Ti 4GB
echo  Model: DeepSeek Coder 6.7B
echo  Çıkmak için Ctrl+C basın
echo.

:loop
echo  %date% %time%
nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>nul
if %errorlevel% neq 0 (
    echo  ❌ nvidia-smi bulunamadı
    pause
    exit /b 1
)
echo  ───────────────────────────────────────
timeout /t 3 >nul
goto loop