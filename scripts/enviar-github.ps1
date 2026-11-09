#Requires -Version 5.1
param([string]$RepoUrl = "", [switch]$AutoConfirm)
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $Root

function Etapa([string]$Msg) { Write-Host "`n=== $Msg ===" -ForegroundColor Cyan }
function Falhar([string]$Msg) { throw $Msg }
function Executar([string]$Bin, [string[]]$CliArgs) {
  & $Bin @CliArgs
  if ($LASTEXITCODE -ne 0) {
    Falhar "Comando falhou: $Bin $($CliArgs -join ' ') (codigo $LASTEXITCODE)"
  }
}

Etapa 'Conferindo requisitos e arquivos locais'
$Git = Get-Command 'git.exe' -ErrorAction SilentlyContinue
$Npm = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
if (-not $Git) { Falhar 'Git para Windows nao encontrado. Instale https://git-scm.com/downloads/win e abra novamente o arquivo .bat.' }
if (-not $Npm) { Falhar 'Node.js/npm nao encontrado. Instale a versao LTS em https://nodejs.org e abra novamente o arquivo .bat.' }

# Recupera somente arquivos que realmente estao faltando, sem substituir suas edicoes.
$Backup = Join-Path $Root '_codigo_reserva'
foreach ($rel in @('src/main.jsx','src/App.jsx','src/firebase.js','src/styles.css','index.html','vite.config.js','vercel.json')) {
  $target = Join-Path $Root $rel
  if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    $origin = Join-Path $Backup $rel
    if (-not (Test-Path -LiteralPath $origin -PathType Leaf)) { Falhar "Arquivo obrigatorio ausente: $rel. Extraia o ZIP na pasta do projeto." }
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Copy-Item -LiteralPath $origin -Destination $target
    Write-Host "Restaurado: $rel" -ForegroundColor Yellow
  }
}
foreach ($rel in @('package.json','src/firebaseConfig.json','firestore.rules')) {
  if (-not (Test-Path -LiteralPath (Join-Path $Root $rel) -PathType Leaf)) { Falhar "Nao encontrei $rel na pasta: $Root" }
}
$Config = Get-Content -LiteralPath (Join-Path $Root 'src/firebaseConfig.json') -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$Config.projectId) -or
    [string]::IsNullOrWhiteSpace([string]$Config.apiKey) -or
    [string]::IsNullOrWhiteSpace([string]$Config.appId)) {
  Falhar 'Firebase ainda sem configuracao real. Preserve o firebaseConfig.json do projeto agenda-cliente-2026 ja configurado.'
}
$RcPath = Join-Path $Root '.firebaserc'
if (Test-Path -LiteralPath $RcPath) {
  $Rc = Get-Content -LiteralPath $RcPath -Raw | ConvertFrom-Json
  if ($Rc.projects.default -and $Rc.projects.default -ne $Config.projectId) {
    Falhar "FIREBASE DIVERGENTE: arquivo .firebaserc=$($Rc.projects.default), frontend=$($Config.projectId). Nao publico dados cruzados entre clientes."
  }
}
Write-Host "Firebase preservado: $($Config.projectId)" -ForegroundColor Green
Etapa 'Validando o aplicativo ANTES de enviar ao GitHub'
if (Test-Path -LiteralPath (Join-Path $Root 'package-lock.json')) {
  Executar $Npm.Source @('ci')
} else {
  Executar $Npm.Source @('install')
}
Executar $Npm.Source @('run','check')

if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
  Write-Host 'Cole a URL HTTPS do seu repositorio GitHub existente, por exemplo:' -ForegroundColor Yellow
  Write-Host 'https://github.com/seu-usuario/seu-repositorio' -ForegroundColor Cyan
  $RepoUrl = Read-Host 'URL do repositorio'
}
$RepoUrl = $RepoUrl.Trim().TrimEnd('/')
if ($RepoUrl -notmatch '^https://github\.com/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+(?:\.git)?$') {
  Falhar 'URL invalida. Use a URL HTTPS do repositorio GitHub, nao a URL da Vercel.'
}

Etapa 'Clonando o repositorio GitHub SEM apagar o historico'
$Temp = Join-Path ([IO.Path]::GetTempPath()) ('firebase-github-' + [Guid]::NewGuid().ToString('N'))
Executar $Git.Source @('clone', $RepoUrl, $Temp)
$Branch = ((& $Git.Source '-C' $Temp 'branch' '--show-current') | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { Falhar 'Nao foi possivel ler o branch do repositorio.' }
if (-not $Branch) {
  $Branch = 'main'
  Executar $Git.Source @('-C', $Temp, 'checkout', '-b', $Branch)
}
Write-Host "Repositorio: $RepoUrl" -ForegroundColor Green
Write-Host "Branch: $Branch" -ForegroundColor Green

Etapa 'Copiando TODOS os arquivos do frontend e automacao'
foreach ($folder in @('src','scripts','.github')) {
  $sourceDir = Join-Path $Root $folder
  if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) { continue }
  foreach ($item in Get-ChildItem -LiteralPath $sourceDir -File -Recurse -Force) {
    $rel = $item.FullName.Substring($Root.Length).TrimStart([char]'\',[char]'/')
    $destination = Join-Path $Temp $rel
    $parent = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Copy-Item -LiteralPath $item.FullName -Destination $destination -Force
  }
}
$rootFiles = @('.gitignore','.firebaserc','index.html','package.json','package-lock.json',
  'vite.config.js','vercel.json','firebase.json','firestore.rules','firestore.indexes.json',
  'README.md','CONFIGURAR-FIREBASE.bat','RETOMAR-FIREBASE.bat','GITHUB-VERCEL-LEIA.md',
  'ENVIAR-PARA-GITHUB.bat','CORRIGIR-E-PUBLICAR.bat','PUBLICAR-VERCEL.bat',
  'AUTOMATIZAR-TUDO.bat','README_AUTOMACAO.md')
foreach ($rel in $rootFiles) {
  $origin = Join-Path $Root $rel
  if (Test-Path -LiteralPath $origin -PathType Leaf) {
    Copy-Item -LiteralPath $origin -Destination (Join-Path $Temp $rel) -Force
  }
}
# Mantem a configuracao publica do Firebase para o frontend Vite.
# NUNCA enviar .env, credenciais de servico, .vercel, node_modules ou dist.
Executar $Git.Source @('-C', $Temp, 'add', '--all')
foreach ($rel in @('src/main.jsx','src/App.jsx','src/firebase.js','src/firebaseConfig.json','index.html','package.json')) {
  & $Git.Source '-C' $Temp 'ls-files' '--error-unmatch' '--' $rel 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { Falhar "BLOQUEADO: o Git NAO vai enviar $rel. Confira .gitignore e o repositorio." }
  Write-Host "Confirmado no envio Git: $rel" -ForegroundColor Green
}
$diff = (& $Git.Source '-C' $Temp 'status' '--short' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { Falhar 'Falha ao conferir alteracoes no Git.' }
if (-not $diff) {
  Write-Host 'O repositorio ja tem estes arquivos. Nao ha mudancas para enviar.' -ForegroundColor Green
  Write-Host 'Se o erro persistir, confira o Root Directory e o repositorio conectado em Vercel > Settings > Git.' -ForegroundColor Yellow
  exit 0
}

Write-Host "`nArquivos que serao alterados no GitHub:" -ForegroundColor Cyan
Write-Host $diff
Write-Host "`nCONFIRA: $RepoUrl (branch $Branch)" -ForegroundColor Yellow
if (-not $AutoConfirm) {
  $Confirmacao = Read-Host 'Digite PUBLICAR para criar commit e enviar ao GitHub'
  if ($Confirmacao -cne 'PUBLICAR') { Write-Host 'Cancelado. NADA foi enviado ao GitHub.' -ForegroundColor Yellow; exit 0 }
} else {
  Write-Host 'Destino GitHub ja autorizado para este Firebase: publicando automaticamente.' -ForegroundColor Green
}
Etapa 'Enviando para o GitHub'
Executar $Git.Source @('-C', $Temp, 'commit', '-m', 'fix: enviar frontend completo e validar build para Vercel')
Executar $Git.Source @('-C', $Temp, 'push', 'origin', "HEAD:$Branch")
$Sha = ((& $Git.Source '-C' $Temp 'rev-parse' '--short' 'HEAD') | Out-String).Trim()
Write-Host "`nSUCESSO: commit $Sha enviado ao GitHub." -ForegroundColor Green
Write-Host "Repositorio: $RepoUrl" -ForegroundColor Green
Write-Host 'Se esse repositorio estiver conectado a Vercel, o novo deploy sera iniciado automaticamente.' -ForegroundColor Yellow
Write-Host 'Abra Vercel > Deployments para verificar status e testar o site e o Firebase.' -ForegroundColor Yellow
