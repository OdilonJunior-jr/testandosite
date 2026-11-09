$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $Root

function Confirmar-Codigo([string] $Etapa) {
  if ($LASTEXITCODE -ne 0) { throw "Falha em $Etapa (codigo $LASTEXITCODE)." }
}
function Checar-Arquivo([string] $Relativo) {
  $Caminho = Join-Path $Root $Relativo
  if (-not (Test-Path -LiteralPath $Caminho -PathType Leaf)) {
    throw "Arquivo necessario ausente: $Relativo. Extraia a correcao NA PASTA principal do projeto (a mesma que contem package.json)."
  }
}

Write-Host "`n=== REPARAR APENAS O FRONTEND - SEM MODIFICAR FIREBASE ===" -ForegroundColor Cyan
Checar-Arquivo 'package.json'
$Manifesto = Get-Content -LiteralPath (Join-Path $Root 'package.json') -Raw | ConvertFrom-Json
if (-not $Manifesto.scripts.build) { throw 'package.json nao possui script build. Verifique a pasta do projeto.' }

# Recupera SOMENTE arquivos ausentes. Nenhum arquivo existente e sobrescrito.
$ArquivosRecuperaveis = @('src/main.jsx', 'src/App.jsx', 'src/firebase.js', 'src/styles.css', 'index.html')
foreach ($Relativo in $ArquivosRecuperaveis) {
  $Destino = Join-Path $Root $Relativo
  $Origem = Join-Path (Join-Path $Root '_restauracao') $Relativo
  if (-not (Test-Path -LiteralPath $Destino -PathType Leaf)) {
    if (-not (Test-Path -LiteralPath $Origem -PathType Leaf)) { throw "Arquivo de recuperacao ausente: $Relativo" }
    $Pasta = Split-Path -Parent $Destino
    if (-not (Test-Path -LiteralPath $Pasta)) { New-Item -ItemType Directory -Path $Pasta -Force | Out-Null }
    Copy-Item -LiteralPath $Origem -Destination $Destino
    Write-Host "Restaurado: $Relativo" -ForegroundColor Yellow
  } else {
    Write-Host "Preservado: $Relativo" -ForegroundColor DarkGreen
  }
}
foreach ($Relativo in $ArquivosRecuperaveis) { Checar-Arquivo $Relativo }
Checar-Arquivo 'src/firebaseConfig.json'
Checar-Arquivo '.firebaserc'
$Cfg = Get-Content -LiteralPath (Join-Path $Root 'src/firebaseConfig.json') -Raw | ConvertFrom-Json
$RC = Get-Content -LiteralPath (Join-Path $Root '.firebaserc') -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($Cfg.projectId)) { throw 'Firebase nao foi configurado. Esta correcao nao define nem substitui a configuracao Firebase.' }
if ($Cfg.projectId -ne $RC.projects.default) {
  throw "IDs Firebase divergentes: frontend '$($Cfg.projectId)' e .firebaserc '$($RC.projects.default)'. Publicacao cancelada."
}
Write-Host "Projeto Firebase preservado: $($Cfg.projectId)" -ForegroundColor Green

# Verifica a ausencia de codigo no repositorio Git (causa comum do erro Vercel).
$Git = Get-Command 'git.exe' -CommandType Application -ErrorAction SilentlyContinue
if ($Git -and (Test-Path (Join-Path $Root '.git'))) {
    $Rastreado = & $Git.Source ls-files src/main.jsx
    if (-not $Rastreado) {
      Write-Host "`nAVISO: src/main.jsx NAO esta versionado no Git." -ForegroundColor Yellow
      Write-Host 'Se a Vercel publica pelo GitHub, inclua a pasta src no repositorio e faca commit/push.' -ForegroundColor Yellow
    } else {
      Write-Host 'src/main.jsx esta versionado no Git.' -ForegroundColor Green
    }
}

$Npm = Get-Command 'npm.cmd' -CommandType Application -ErrorAction SilentlyContinue
if (-not $Npm) { throw 'npm.cmd nao encontrado. Instale Node.js LTS e reabra o terminal.' }
$Vercel = Get-Command 'vercel.cmd' -CommandType Application -ErrorAction SilentlyContinue
if (-not $Vercel) { throw 'vercel.cmd nao encontrado. No CMD, execute: npm.cmd install -g vercel' }

Write-Host "`nInstalando dependencias (npm.cmd)..." -ForegroundColor Cyan
& $Npm.Source install --no-audit --no-fund
Confirmar-Codigo 'npm install'
Write-Host "`nValidando build local antes de enviar..." -ForegroundColor Cyan
& $Npm.Source run build
Confirmar-Codigo 'npm run build'
Checar-Arquivo 'dist/index.html'
Write-Host "`nBUILD OK. Publicando do diretorio correto: $Root" -ForegroundColor Green
Write-Host 'Caso apareca pergunta para vincular o projeto Vercel, escolha o projeto correto.' -ForegroundColor Yellow
& $Vercel.Source --prod
Confirmar-Codigo 'vercel --prod'
Write-Host "`nPublicacao executada. Abra a URL e teste login e Firestore." -ForegroundColor Green
