@echo off
setlocal
cd /d "%~dp0"
title Reparacao segura do frontend - Firebase e Vercel
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\reparar-vercel.ps1"
if errorlevel 1 (
  echo.
  echo Erro na validacao ou publicacao. Confira a mensagem acima.
) else (
  echo.
  echo Verificacao e comando de publicacao finalizados.
)
pause
