# Corrige exclusivamente o processo de publicacao frontend na Vercel.
# Nao altera arquivos de Firebase, banco de dados, regras ou indexacao.
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $Root

function Exigir-Arquivo([string] $Relativo) {
  $Destino = Join-Path $Root $Relativo
  if (-not (Test-Path -LiteralPath $Destino -PathType Leaf)) {
    throw "Arquivo ausente: $Relativo. Extraia o ZIP diretamente na pasta que possui package.json, index.html e src."
  }
}
function Verificar-Processo([string] $Etapa) {
  if ($LASTEXITCODE -ne 0) { throw "Falha em $Etapa (codigo $LASTEXITCODE)." }
}
function Obter-Programa([string] $Nome, [string] $Instrucao) {
  $App = Get-Command $Nome -CommandType Application -ErrorAction SilentlyContinue
  if (-not $App) { throw "$Nome nao foi encontrado. $Instrucao" }
  return $App.Source
}

Write-Host '=== PUBLICACAO PRECOMPILADA - SEM RECOMPILAR NA VERCEL ===' -ForegroundColor Cyan
foreach ($Nome in @('package.json', 'index.html', 'src/main.jsx', 'src/App.jsx', 'src/firebaseConfig.json', '.firebaserc')) {
  Exigir-Arquivo $Nome
}
$Config = Get-Content -LiteralPath (Join-Path $Root 'src/firebaseConfig.json') -Raw | ConvertFrom-Json
$ProjetoFirebase = Get-Content -LiteralPath (Join-Path $Root '.firebaserc') -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($Config.projectId) -or [string]::IsNullOrWhiteSpace($ProjetoFirebase.projects.default)) {
  throw 'Projeto Firebase nao configurado; publicacao interrompida para evitar envio incorreto.'
}
if ($Config.projectId -ne $ProjetoFirebase.projects.default) {
  throw "Inconsistencia de projeto Firebase: $($Config.projectId) vs $($ProjetoFirebase.projects.default)."
}
Write-Host "Firebase existente mantido: $($Config.projectId)" -ForegroundColor Green
$Npm = Obter-Programa 'npm.cmd' 'Instale o Node.js LTS, feche e abra o terminal novamente.'
$Vercel = Obter-Programa 'vercel.cmd' 'No CMD, execute: npm.cmd install -g vercel'

Write-Host "`nCompilando frontend LOCALMENTE..." -ForegroundColor Cyan
& $Npm install --no-audit --no-fund
Verificar-Processo 'npm install'
& $Npm run build
Verificar-Processo 'npm run build'
Exigir-Arquivo 'dist/index.html'
$IndexFinal = Get-Content -LiteralPath (Join-Path $Root 'dist/index.html') -Raw
if ($IndexFinal -match '/src/main\.jsx') {
  throw 'O dist/index.html ainda aponta para o codigo-fonte. Build invalido; envio cancelado.'
}
$JsGerado = Get-ChildItem -LiteralPath (Join-Path $Root 'dist') -Recurse -Filter '*.js' -File -ErrorAction SilentlyContinue
if (-not $JsGerado) { throw 'Build sem arquivos JavaScript em dist. Envio cancelado.' }
Write-Host 'Build local valido: HTML e JavaScript compilados.' -ForegroundColor Green

$PastaVercel = Join-Path $Root '.vercel'
$Vinculo = Join-Path $PastaVercel 'project.json'
if (-not (Test-Path -LiteralPath $Vinculo -PathType Leaf)) {
  Write-Host "`nEste diretorio ainda nao esta vinculado a um projeto na Vercel." -ForegroundColor Yellow
  Write-Host 'Na proxima tela, selecione o PROJETO EXISTENTE da Vercel (nao crie outro por engano).' -ForegroundColor Yellow
  & $Vercel link
  Verificar-Processo 'vercel link'
}
if (-not (Test-Path -LiteralPath $Vinculo -PathType Leaf)) {
  throw 'Vercel nao criou .vercel/project.json. Verifique o vinculo antes de continuar.'
}
$VinculoInfo = Get-Content -LiteralPath $Vinculo -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($VinculoInfo.projectId)) {
  throw 'Vinculo Vercel invalido. .vercel/project.json sem projectId.'
}
Write-Host "`nProjeto Vercel vinculado (ID): $($VinculoInfo.projectId)" -ForegroundColor Cyan
Write-Host "Projeto Firebase: $($Config.projectId)" -ForegroundColor Cyan
Write-Host 'A publicacao sera feita em PRODUCAO para o projeto Vercel acima.' -ForegroundColor Yellow
$Resposta = Read-Host 'Confirma que e o projeto correto? Digite SIM para publicar'
if ($Resposta.Trim().ToUpperInvariant() -ne 'SIM') {
  throw 'Publicacao cancelada pelo usuario. Execute vercel link para revisar o projeto vinculado.'
}

# Cria o formato oficial da Vercel Build Output API (v3) a partir do build local.
# Nao chama 'vercel build' nem executa a recompilacao remota do Vite.
$Saida = Join-Path $PastaVercel 'output'
if (Test-Path -LiteralPath $Saida) { Remove-Item -LiteralPath $Saida -Recurse -Force }
$Estatico = Join-Path $Saida 'static'
New-Item -ItemType Directory -Path $Estatico -Force | Out-Null
Copy-Item -Path (Join-Path $Root 'dist\*') -Destination $Estatico -Recurse -Force
if (-not (Test-Path -LiteralPath (Join-Path $Estatico 'index.html') -PathType Leaf)) {
  throw 'Falha ao copiar dist/index.html para .vercel/output/static.'
}
$Json = '{"version":3,"routes":[{"handle":"filesystem"},{"src":"/.*","dest":"/index.html"}]}'
[System.IO.File]::WriteAllText((Join-Path $Saida 'config.json'), $Json, (New-Object System.Text.UTF8Encoding($false)))
$ManifestoSaida = Get-Content -LiteralPath (Join-Path $Saida 'config.json') -Raw | ConvertFrom-Json
if ($ManifestoSaida.version -ne 3) { throw 'Configuracao de saida Vercel invalida.' }

Write-Host "`nEnviando APENAS o build compilado para a Vercel..." -ForegroundColor Cyan
& $Vercel deploy --prebuilt --prod
Verificar-Processo 'vercel deploy --prebuilt --prod'
Write-Host "`nPUBLICACAO SOLICITADA COM SUCESSO. Confira a URL acima." -ForegroundColor Green
Write-Host 'Observacao: se a Vercel tambem publica pelo GitHub, futuros pushes podem iniciar outros builds.' -ForegroundColor Yellow
