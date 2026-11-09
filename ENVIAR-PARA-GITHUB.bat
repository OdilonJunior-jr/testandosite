@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\enviar-github.ps1"
if errorlevel 1 (
 echo.
 echo FALHA - confira as mensagens acima.
)
echo.
pause
