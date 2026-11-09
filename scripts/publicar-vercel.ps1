$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root

# No Windows, invocar apenas "npm" dentro do PowerShell pode selecionar
# um wrapper npm.ps1 ou outro comando no PATH. Usar os .cmd explicitamente
# evita ambiguidades e tambem funciona no Windows PowerShell 5.1.
$NodeCmd = Get-Command 'node.exe' -CommandType Application -ErrorAction SilentlyContinue
$NpmCmd = Get-Command 'npm.cmd' -CommandType Application -ErrorAction SilentlyContinue
$VercelCmd = Get-Command 'vercel.cmd' -CommandType Application -ErrorAction SilentlyContinue
if (-not $NodeCmd) { throw 'Node.js nao encontrado no PATH. Instale Node.js LTS e abra o instalador novamente.' }
if (-not $NpmCmd) { throw 'npm.cmd nao encontrado no PATH. Reinstale Node.js LTS e abra um NOVO terminal.' }
if (-not $VercelCmd) { throw 'vercel.cmd nao encontrado. Em um CMD, execute: npm.cmd install -g vercel' }

$configPath = Join-Path $Root 'src/firebaseConfig.json'
if (-not (Test-Path $configPath)) { throw 'Arquivo src/firebaseConfig.json nao encontrado. Esta e a pasta correta do projeto?' }
$config = Get-Content $configPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($config.projectId)) { throw 'Firebase ainda nao configurado. Conclua CONFIGURAR-FIREBASE.bat ou RETOMAR-FIREBASE.bat primeiro.' }
if (-not (Test-Path (Join-Path $Root '.firebaserc'))) { throw 'Arquivo .firebaserc nao encontrado. Configure Firebase antes.' }
$rc = Get-Content (Join-Path $Root '.firebaserc') -Raw | ConvertFrom-Json
if ($rc.projects.default -ne $config.projectId) { throw 'IDs divergentes entre configuracao Firebase e .firebaserc. Publicacao bloqueada.' }
$readyPath = Join-Path $Root '.firebase-deploy-ready.json'
if (-not (Test-Path $readyPath)) { throw 'Backend Firestore ainda nao confirmado como implantado. Conclua RETOMAR-FIREBASE.bat.' }
$ready = Get-Content $readyPath -Raw | ConvertFrom-Json
if ($ready.projectId -ne $config.projectId) { throw 'Verificacao de deploy do backend nao corresponde ao projeto Firebase. Publicacao bloqueada.' }

Write-Host "`nUsando npm.cmd de: $($NpmCmd.Source)" -ForegroundColor DarkCyan
& $NpmCmd.Source --version
if ($LASTEXITCODE -ne 0) { throw 'npm.cmd nao conseguiu informar a versao. Verifique a instalacao do Node.js.' }

Write-Host "`nInstalando dependencias..." -ForegroundColor Cyan
& $NpmCmd.Source install --no-audit --no-fund
if ($LASTEXITCODE -ne 0) {
  throw 'Falha no npm.cmd install. Execute npm.cmd install manualmente no CMD desta pasta para ver a causa.'
}
Write-Host "`nValidando codigo e gerando build..." -ForegroundColor Cyan
& $NpmCmd.Source run check
if ($LASTEXITCODE -ne 0) { throw 'Falha no npm.cmd run check. Publicacao interrompida.' }
Write-Host "`nPublicando frontend na Vercel. Confirme a conta e o projeto quando solicitado..." -ForegroundColor Cyan
& $VercelCmd.Source --prod
if ($LASTEXITCODE -ne 0) { throw 'Falha na publicacao Vercel.' }
Write-Host "`nFrontend publicado. Confira login, Firestore e dominio na Vercel." -ForegroundColor Green
