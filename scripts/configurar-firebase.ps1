param(
  [string]$ProjectId,
  [string]$Nome,
  [string]$Regiao = "southamerica-east1",
  [switch]$ProjetoExistente,
  [switch]$BancoExistente
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $Root

function ExecutarFirebase([string[]]$Argumentos) {
  $preferencia = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & firebase.cmd @Argumentos; $codigo = $LASTEXITCODE }
  finally { $ErrorActionPreference = $preferencia }
  if ($codigo -ne 0) {
    throw "Falha no comando firebase $($Argumentos -join ' ') (codigo $codigo). O processo foi interrompido."
  }
}
function Etapa([string]$Descricao) { Write-Host "`n=== $Descricao ===" -ForegroundColor Cyan }

# O retorno 404 indica que o banco ainda nao existe. Outras falhas serao
# tratadas na tentativa de criacao, sem alterar outro projeto.
function BancoDefaultExiste([string]$Id) {
  $antigo = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & firebase 'firestore:databases:get' '(default)' '--project' $Id '--json' 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
  } finally {
    $ErrorActionPreference = $antigo
  }
}

function CriarBancoComAjuda([string]$Id, [string]$Local) {
  if (BancoDefaultExiste $Id) {
    Write-Host 'Banco (default) ja existe. A criacao sera ignorada.' -ForegroundColor Green
    return
  }

  # Primeiro tenta a CLI, que pode funcionar sem intervencao.
  & firebase 'firestore:databases:create' '(default)' "--location=$Local" '--project' $Id
  if ($LASTEXITCODE -eq 0) { return }

  # Em maquinas com Google Cloud CLI autorizado, habilita API automaticamente.
  $Gcloud = Get-Command 'gcloud.cmd' -ErrorAction SilentlyContinue
  if ($Gcloud) {
    Write-Host 'Tentando habilitar Cloud Firestore API automaticamente com gcloud...' -ForegroundColor Cyan
    & $Gcloud.Source 'services' 'enable' 'firestore.googleapis.com' '--project' $Id
    if ($LASTEXITCODE -eq 0) {
      Start-Sleep -Seconds 8
      & firebase 'firestore:databases:create' '(default)' "--location=$Local" '--project' $Id
      if ($LASTEXITCODE -eq 0 -or (BancoDefaultExiste $Id)) { return }
    }
  }

  # Se a API exigir acesso/faturamento, so o titular pode autorizar.
  # Projetos recem-criados podem estar com a API Firestore desativada.
  # A ativacao depende da autorizacao da conta no Google Cloud.
  $url = "https://console.cloud.google.com/apis/library/firestore.googleapis.com?project=$Id"
  Write-Host "`nSe apareceu ERRO 403 de API desativada, ative Cloud Firestore API:" -ForegroundColor Yellow
  Write-Host $url -ForegroundColor Cyan
  Write-Host 'Se a falha foi de permissao/faturamento, verifique tambem esses requisitos.' -ForegroundColor Yellow
  try { Start-Process $url } catch { Write-Host 'Abra o endereco acima manualmente.' }
  Read-Host 'Depois de clicar ATIVAR e aguardar a ativacao, pressione ENTER para tentar novamente'

  if (BancoDefaultExiste $Id) {
    Write-Host 'Banco (default) detectado na retomada.' -ForegroundColor Green
    return
  }
  & firebase 'firestore:databases:create' '(default)' "--location=$Local" '--project' $Id
  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao criar Firestore no projeto $Id. Confirme que a API esta ativada no link informado e que a conta tem permissao. Execute RETOMAR-FIREBASE.bat para continuar SEM recriar o projeto."
  }
}


if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  throw "Firebase CLI nao encontrado. Instale primeiro: npm install -g firebase-tools"
}
if ([string]::IsNullOrWhiteSpace($ProjectId)) {
  $ProjectId = Read-Host "ID EXCLUSIVO do novo projeto (ex: agenda-cliente-2026-a1)"
}
if ([string]::IsNullOrWhiteSpace($Nome)) {
  $Nome = Read-Host "Nome de exibicao do sistema (ex: Agenda Cliente)"
}
if ($ProjectId -notmatch '^[a-z][a-z0-9-]{4,28}[a-z0-9]$' -or $ProjectId -match '--') {
  throw "ID invalido. Use 6-30 caracteres: letras minusculas, numeros e hifens; comece por letra e termine por letra/numero, sem hifens consecutivos."
}
if ([string]::IsNullOrWhiteSpace($Nome)) { throw "Nome do sistema obrigatorio." }

$configPath = Join-Path $Root 'src/firebaseConfig.json'
$existing = Get-Content $configPath -Raw | ConvertFrom-Json
$configJaPronta = -not [string]::IsNullOrWhiteSpace($existing.projectId)
if ($configJaPronta) {
  if (-not $ProjetoExistente -or $existing.projectId -ne $ProjectId) {
    throw "Este ZIP ja esta conectado ao projeto '$($existing.projectId)'. Para retomar esse MESMO projeto, use -ProjetoExistente e o mesmo -ProjectId. Para outro cliente, use copia limpa."
  }
  Write-Host "Configuracao existente verificada para $ProjectId. Registro web sera preservado." -ForegroundColor Yellow
}

Etapa 'Autenticacao na sua conta Google'
# Evita o erro NativeCommandError (PowerShell 5.1) causado pelo progresso
# de firebase projects:list no stderr redirecionado.
$preferencia = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  & firebase.cmd 'projects:list'
  $codigoProjetos = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $preferencia
}
if ($codigoProjetos -ne 0) {
  ExecutarFirebase @('login')
  $preferencia = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & firebase.cmd 'projects:list'; $codigoProjetos = $LASTEXITCODE }
  finally { $ErrorActionPreference = $preferencia }
  if ($codigoProjetos -ne 0) { throw 'Firebase CLI continua sem listar projetos. Confira a conta ativa com firebase.cmd login:list e as permissoes no console Firebase.' }
}

if (-not $ProjetoExistente) {
  Etapa "Criando NOVO projeto Firebase: $ProjectId"
  ExecutarFirebase @('projects:create', $ProjectId, '--display-name', $Nome)
} else {
  Etapa 'Reutilizando projeto informado (sem criar outro)'
}

if (-not $configJaPronta) {
  Etapa 'Registrando aplicativo web'
  ExecutarFirebase @('apps:create', 'WEB', "$Nome - Web", '--project', $ProjectId)

  Etapa 'Obtendo configuracao automaticamente'
  $tempConfig = Join-Path $Root 'firebase-js-config.json'
  if (Test-Path $tempConfig) { throw 'Arquivo firebase-js-config.json ja existe: remova somente se tiver certeza de que e temporario.' }
  try {
    ExecutarFirebase @('apps:sdkconfig', 'WEB', '--project', $ProjectId, '--out', $tempConfig)
    if (-not (Test-Path $tempConfig)) { throw 'Firebase CLI nao gerou o arquivo de configuracao.' }
    $cfg = Get-Content $tempConfig -Raw | ConvertFrom-Json
    foreach ($campo in @('apiKey','authDomain','projectId','appId')) {
      if ([string]::IsNullOrWhiteSpace($cfg.$campo)) { throw "Campo '$campo' nao encontrado na configuracao gerada pelo Firebase." }
    }
    if ($cfg.projectId -ne $ProjectId) { throw 'ERRO DE SEGURANCA: O ID recebido do Firebase nao corresponde ao ID solicitado.' }
    Copy-Item $tempConfig $configPath -Force
  } finally {
    if (Test-Path $tempConfig) { Remove-Item $tempConfig }
  }
} else {
  Etapa 'Mantendo configuracao WEB do projeto ja iniciada'
}

Etapa 'Preparando associacao EXPLICITA ao projeto'
$rcPath = Join-Path $Root '.firebaserc'
$rcJson = @{ projects = @{ default = $ProjectId } } | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($rcPath, $rcJson, (New-Object System.Text.UTF8Encoding($false)))

if (-not $BancoExistente) {
  Etapa "Criando Firestore (default) na regiao $Regiao"
  CriarBancoComAjuda $ProjectId $Regiao
} else {
  Etapa 'Usando banco Firestore existente'
}

Etapa 'Publicando regras e indices (sem acesso publico)'
ExecutarFirebase @('deploy', '--only', 'firestore', '--project', $ProjectId)

$readyPath = Join-Path $Root '.firebase-deploy-ready.json'
$readyJson = @{ projectId = $ProjectId; deployFinishedUtc = [DateTime]::UtcNow.ToString('o') } | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText($readyPath, $readyJson, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "`nESTRUTURA FIREBASE CONFIGURADA!" -ForegroundColor Green
Write-Host "Projeto: $ProjectId"
Write-Host "Console: https://console.firebase.google.com/project/$ProjectId/overview"
Write-Host 'Proxima etapa automatica: ativar Email/Senha e vincular GitHub e Vercel.' -ForegroundColor Cyan
