@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\autopilot.ps1" %*
echo.
if errorlevel 1 echo [ERRO] Etapa interrompida: leia a mensagem acima. Nenhum sucesso foi presumido.
pause
