@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\publicar-vercel.ps1"
echo.
if errorlevel 1 echo Falha detectada. Leia a mensagem acima.
pause
