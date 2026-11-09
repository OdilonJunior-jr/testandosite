@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo ERRO: Windows PowerShell nao encontrado.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\publicar-prebuilt.ps1"
if errorlevel 1 (
  echo.
  echo A publicacao nao foi concluida. Consulte o erro acima.
  pause
  exit /b 1
)
echo.
echo Processo de publicacao concluido. Abra a URL exibida e teste o site.
pause
