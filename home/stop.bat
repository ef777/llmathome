
REM ==========================================
REM stop.bat - Kodlama Asistanı Durdurma  
REM ==========================================

@echo off
title Kodlama Asistanı - Durdur
color 0C
echo.
echo  🛑 Kodlama Asistani Durduruluyor...
echo.

REM Python süreçlerini durdur
echo  📝 Python client süreçleri durduruluyor...
taskkill /f /im "python.exe" /fi "windowtitle eq Kodlama Asistani*" 2>nul

REM Ollama süreçlerini durdur  
echo  🤖 Ollama süreçleri durduruluyor...
taskkill /f /im "ollama.exe" 2>nul

echo.
echo  ✅ Tum süreçler durduruldu.
echo  📋 Log dosyalari korundu.
echo.
pause
