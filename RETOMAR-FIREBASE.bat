@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Retomando instalacao do Firebase no projeto JA CRIADO...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $cfg = Get-Content '.\src\firebaseConfig.json' -Raw | ConvertFrom-Json; if ([string]::IsNullOrWhiteSpace($cfg.projectId)) { throw 'ID do projeto nao encontrado. Execute CONFIGURAR-FIREBASE.bat na copia original ou informe o ID manualmente no PowerShell.' }; & '.\scripts\configurar-firebase.ps1' -ProjectId $cfg.projectId -Nome 'Retomada do sistema' -ProjetoExistente"
echo.
if errorlevel 1 echo Falha na retomada. Confira a mensagem acima.
pause
