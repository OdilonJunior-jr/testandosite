#Requires -Version 5.1
param(
  [ValidateSet('menu','corrigir','novo','atualizar')][string]$Modo = 'menu',
  [string]$RepoUrl = '',
  [string]$ProjectId = '',
  [string]$Nome = ''
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root

function Etapa([string]$msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Falhar([string]$msg) { throw $msg }
function Exe([string]$path, [string[]]$argumentos) {
  $preferencia = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $path @argumentos
    $codigo = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $preferencia
  }
  if ($codigo -ne 0) { Falhar "Falha ($codigo) ao executar $([IO.Path]::GetFileName($path)) $($argumentos -join ' ')" }
}
# Windows PowerShell 5.1: stderr redirecionado + ErrorActionPreference=Stop
# pode encerrar o script mesmo quando a CLI so exibe progresso.
# Esta funcao captura stdout/stderr e decide pela saida numerica da CLI.
function ConsultarCLI([string]$Bin, [string[]]$ArgumentosCLI) {
  $preferencia = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $saida = (& $Bin @ArgumentosCLI 2>&1 | Out-String).Trim()
    $codigo = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $preferencia
  }
  return [pscustomobject]@{ OK = ($codigo -eq 0); Codigo = $codigo; Saida = $saida }
}
function Comando([string]$nome, [string]$instalar) {
  $bin = Get-Command $nome -ErrorAction SilentlyContinue
  if (-not $bin) {
    if ($nome -eq 'firebase.cmd' -or $nome -eq 'vercel.cmd') {
      $npm = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
      if ($npm) {
        $pacote = if ($nome -eq 'firebase.cmd') { 'firebase-tools' } else { 'vercel' }
        Write-Host "Instalando ferramenta oficial $pacote (uma unica vez)..." -ForegroundColor Cyan
        & $npm.Source 'install' '-g' $pacote
        if ($LASTEXITCODE -eq 0) { $bin = Get-Command $nome -ErrorAction SilentlyContinue }
      }
    }
    if (-not $bin -and $nome -eq 'gh.exe') {
      $winget = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
      if ($winget) {
        Write-Host 'Instalando GitHub CLI com winget...' -ForegroundColor Cyan
        & $winget.Source 'install' '--id' 'GitHub.cli' '--exact' '--accept-package-agreements' '--accept-source-agreements'
        $bin = Get-Command $nome -ErrorAction SilentlyContinue
      }
    }
    if (-not $bin) { Falhar "$nome nao encontrado. Instale: $instalar. Se ja instalou, feche e abra o terminal para atualizar o PATH." }
  }
  return $bin.Source
}
function ArquivosObrigatorios() {
  foreach ($f in @('src/main.jsx','src/App.jsx','src/firebase.js','src/firebaseConfig.json',
      'index.html','package.json','firebase.json','firestore.rules','firestore.indexes.json',
      'vercel.json','vite.config.js')) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $f) -PathType Leaf)) {
      Falhar "Arquivo ausente: $f. Extraia o ZIP completo na raiz do projeto."
    }
  }
}
function ConfigFirebase([switch]$PermitidoVazio) {
  $cfg = Get-Content -LiteralPath (Join-Path $Root 'src/firebaseConfig.json') -Raw | ConvertFrom-Json
  if ([string]::IsNullOrWhiteSpace([string]$cfg.projectId)) {
    if ($PermitidoVazio) { return $null }
    Falhar 'Firebase nao foi conectado: src/firebaseConfig.json sem projectId. Use o modo NOVO.'
  }
  foreach ($prop in @('apiKey','authDomain','projectId','appId')) {
    if ([string]::IsNullOrWhiteSpace([string]$cfg.$prop)) { Falhar "Configuracao Firebase incompleta: $prop" }
  }
  $rc = Join-Path $Root '.firebaserc'
  if (Test-Path -LiteralPath $rc) {
    $rcfg = Get-Content -LiteralPath $rc -Raw | ConvertFrom-Json
    if ($rcfg.projects.default -and $rcfg.projects.default -ne $cfg.projectId) {
      Falhar "Protecao: .firebaserc aponta para $($rcfg.projects.default), mas frontend aponta para $($cfg.projectId)."
    }
  }
  return $cfg
}
function ValidarLocal() {
  Etapa 'Validando arquivos, testes e BUILD antes de qualquer push'
  ArquivosObrigatorios
  $npm = Comando 'npm.cmd' 'https://nodejs.org/'
  if (Test-Path -LiteralPath (Join-Path $Root 'package-lock.json')) {
    Exe $npm @('ci')
  } else {
    Exe $npm @('install')
  }
  Exe $npm @('run','check')
  Write-Host 'BUILD LOCAL OK. Nenhum arquivo essencial esta faltando.' -ForegroundColor Green
}
function AutenticarFirebase() {
  $f = Comando 'firebase.cmd' 'npm.cmd install -g firebase-tools'
  Etapa 'Verificando acesso a Firebase (sem ocultar falhas)'
  $ver = ConsultarCLI $f @('projects:list')
  if (-not $ver.OK) {
    Write-Host "Nao foi possivel listar projetos Firebase (codigo $($ver.Codigo))." -ForegroundColor Yellow
    if ($ver.Saida) { Write-Host $ver.Saida -ForegroundColor Yellow }
    Write-Host 'Abrindo autenticacao oficial da Firebase CLI; selecione a conta correta.' -ForegroundColor Cyan
    Exe $f @('login')
    $ver = ConsultarCLI $f @('projects:list')
    if (-not $ver.OK) {
      if ($ver.Saida) { Write-Host $ver.Saida -ForegroundColor Yellow }
      Falhar "Firebase continua sem acesso (codigo $($ver.Codigo)). Verifique a conta ativa com firebase.cmd login:list e, se preciso, firebase.cmd login:use. Se houver HTTP 403, confirme permissoes e APIs no console Google."
    }
  }
  Write-Host 'Firebase CLI autenticada e com acesso aos projetos.' -ForegroundColor Green
  return $f
}
function GarantirAuthConfig() {
  $file = Join-Path $Root 'firebase.json'
  $data = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
  $updated = $false
  if (-not ($data.PSObject.Properties.Name -contains 'auth')) {
    $data | Add-Member -MemberType NoteProperty -Name 'auth' -Value ([pscustomobject]@{ providers=([pscustomobject]@{emailPassword=$true}) })
    $updated = $true
  } else {
    if (-not ($data.auth.PSObject.Properties.Name -contains 'providers')) {
      $data.auth | Add-Member -MemberType NoteProperty -Name 'providers' -Value ([pscustomobject]@{ emailPassword=$true })
      $updated = $true
    } elseif (-not ($data.auth.providers.PSObject.Properties.Name -contains 'emailPassword')) {
      $data.auth.providers | Add-Member -MemberType NoteProperty -Name 'emailPassword' -Value $true
      $updated = $true
    } elseif ($data.auth.providers.emailPassword -ne $true) {
      $data.auth.providers.emailPassword = $true
      $updated = $true
    }
  }
  if ($updated) {
    $backup = Join-Path $Root ('firebase.json.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Copy-Item -LiteralPath $file -Destination $backup
    [IO.File]::WriteAllText($file, ($data | ConvertTo-Json -Depth 40), (New-Object Text.UTF8Encoding($false)))
    Write-Host "Firebase Authentication Email/Senha adicionado sem apagar outras configuracoes. Backup: $backup" -ForegroundColor Green
  }
}
function GarantirBancoFirestore([string]$id, [string]$f) {
  Etapa "Conferindo banco Firestore (default) de $id"
  $probe = ConsultarCLI $f @('firestore:databases:get', '(default)', '--project', $id, '--json')
  if ($probe.OK) {
    Write-Host 'Banco existente: nenhum dado sera apagado ou recriado.' -ForegroundColor Green
    return
  }
  Write-Host "Consulta ao Firestore retornou codigo $($probe.Codigo):" -ForegroundColor Yellow
  if ($probe.Saida) { Write-Host $probe.Saida -ForegroundColor Yellow }
  # Nao confundir falta de permissao com banco inexistente.
  $apiDesativada = ($probe.Saida -match 'has not been used|SERVICE_DISABLED|API.*disabled|API.*desativad|enable it by visiting')
  if ((-not $apiDesativada) -and ($probe.Saida -match '403|PERMISSION_DENIED|permission denied|insufficient permission|unauthorized|401')) {
    Falhar 'A conta nao tem permissao suficiente para consultar Firestore. Confira projeto, Google account e papeis no Firebase antes de continuar.'
  }
  if ($apiDesativada) { Write-Host 'API Firestore desativada; tentando habilitar na etapa automatizada.' -ForegroundColor Yellow }
  Write-Host 'Banco nao foi confirmado. Tentando criar automaticamente em southamerica-east1...' -ForegroundColor Yellow
  & $f 'firestore:databases:create' '(default)' '--location=southamerica-east1' '--project' $id
  if ($LASTEXITCODE -eq 0) { return }
  # Projetos recem-criados podem precisar da API firestore.googleapis.com ativada.
  $cloud = Get-Command 'gcloud.cmd' -ErrorAction SilentlyContinue
  if ($cloud) {
    Write-Host 'Tentando ativar Cloud Firestore API com gcloud...' -ForegroundColor Cyan
    & $cloud.Source 'services' 'enable' 'firestore.googleapis.com' '--project' $id
    if ($LASTEXITCODE -eq 0) {
      Start-Sleep -Seconds 10
      & $f 'firestore:databases:create' '(default)' '--location=southamerica-east1' '--project' $id
      if ($LASTEXITCODE -eq 0) { return }
    }
  }
  $probe = ConsultarCLI $f @('firestore:databases:get', '(default)', '--project', $id, '--json')
  if ($probe.OK) { return } # criacao pode ter concluido com timeout
  $url = "https://console.cloud.google.com/apis/library/firestore.googleapis.com?project=$id"
  Write-Host "A API Firestore pode estar desativada ou a conta nao ter permissao: $url" -ForegroundColor Yellow
  try { Start-Process $url } catch { }
  [void](Read-Host 'Se precisar, ative a API nesse link e pressione ENTER para retomar')
  $probe = ConsultarCLI $f @('firestore:databases:get', '(default)', '--project', $id, '--json')
  if ($probe.OK) { return }
  & $f 'firestore:databases:create' '(default)' '--location=southamerica-east1' '--project' $id
  if ($LASTEXITCODE -ne 0) { Falhar 'Firestore nao foi criado. Confira permissao, API e faturamento no Google Cloud; execute o instalador novamente para retomar.' }
}
function AplicarFirebase([string]$id) {
  Etapa "Configurando Auth E-mail/Senha, banco, regras e indices no Firebase: $id"
  $f = AutenticarFirebase
  GarantirAuthConfig
  GarantirBancoFirestore $id $f
  # A CLI permite declarar provedores de login no firebase.json, alem de regras Firestore.
  # O ID explicito impede configurar outro Firebase por engano.
  Exe $f @('deploy','--only','auth,firestore','--project',$id)
  Write-Host 'Provedores e regras publicados. Login e Firestore ainda precisam do teste real no site.' -ForegroundColor Green
}
function RepoValid([string]$url) {
  return ($url -match '^https://github\.com/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+(?:\.git)?$')
}
function ResolverRepo() {
  if (-not [string]::IsNullOrWhiteSpace($RepoUrl)) {
    if (-not (RepoValid $RepoUrl)) { Falhar 'URL de repositorio GitHub invalida.' }
    return $RepoUrl.Trim().TrimEnd('/')
  }
  $path = Join-Path $Root '.autopilot.json'
  if (Test-Path -LiteralPath $path) {
    $s = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($s.firebaseId -eq (ConfigFirebase).projectId -and (RepoValid $s.repoUrl)) {
      Write-Host "GitHub salvo para este Firebase: $($s.repoUrl)" -ForegroundColor Green
      $script:RepoReconhecido = $true
      return $s.repoUrl
    }
  }
  $url = (Read-Host 'Cole a URL HTTPS do repositorio GitHub que esta conectado na Vercel').Trim()
  if (-not (RepoValid $url)) { Falhar 'Use uma URL como https://github.com/usuario/repositorio' }
  return $url.TrimEnd('/')
}
function SalvarRepo([string]$id, [string]$url) {
  $path = Join-Path $Root '.autopilot.json'
  $info = @{ firebaseId=$id; repoUrl=$url } | ConvertTo-Json
  [IO.File]::WriteAllText($path, $info, (New-Object Text.UTF8Encoding($false)))
}
function EnviarExistente([string]$id) {
  $url = ResolverRepo
  Etapa 'Conferindo GitHub e preparando commit seguro'
  [void](Comando 'git.exe' 'https://git-scm.com/downloads/win')
  Write-Host "Destino: $url" -ForegroundColor Yellow
  # Script V6 clona o repositorio existente e exige a palavra PUBLICAR para push.
  & (Join-Path $PSScriptRoot 'enviar-github.ps1') -RepoUrl $url -AutoConfirm:$script:RepoReconhecido
  if (-not $?) { Falhar 'Nao foi possivel executar o script de envio ao GitHub.' }
  SalvarRepo $id $url
  Write-Host "`nPronto para deploy automatico SE o repositorio acima estiver conectado a Vercel." -ForegroundColor Green
  Write-Host 'Aguarde Vercel > Deployments e teste criar conta e salvar uma anotacao.' -ForegroundColor Yellow
}
function ConfigurarNovo() {
  Etapa 'Novo sistema: um Firebase, GitHub e Vercel exclusivos'
  $cfg = ConfigFirebase -PermitidoVazio
  $retomando = $false
  if ($cfg) {
    Write-Host "Esta pasta ja esta ligada ao Firebase $($cfg.projectId)." -ForegroundColor Yellow
    if ($ProjectId -and $ProjectId -ne $cfg.projectId) { Falhar 'Protecao: esta pasta esta ligada a outro Firebase.' }
    $resposta = (Read-Host 'Digite RETOMAR para continuar este mesmo sistema; qualquer outra coisa cancela').Trim()
    if ($resposta -cne 'RETOMAR') { Falhar 'Cancelado: para um novo cliente use outra copia limpa do ZIP.' }
    $ProjectId = $cfg.projectId
    $retomando = $true
  }
  if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    $ProjectId = (Read-Host 'ID unico Firebase (ex: site-joao-2026)').Trim()
  }
  if ([string]::IsNullOrWhiteSpace($Nome)) { $Nome = (Read-Host 'Nome do sistema (ex: Site Joao)').Trim() }
  if ($ProjectId -notmatch '^[a-z][a-z0-9-]{4,28}[a-z0-9]$' -or $ProjectId -match '--') {
    Falhar 'ID invalido: de 6 a 30 caracteres, letras minusculas, numeros ou hifens.'
  }
  [void](Comando 'firebase.cmd' 'npm.cmd install -g firebase-tools')
  [void](Comando 'git.exe' 'https://git-scm.com/downloads/win')
  [void](Comando 'gh.exe' 'winget install --id GitHub.cli --exact')
  [void](Comando 'vercel.cmd' 'npm.cmd install -g vercel')
  Etapa 'Criando Firebase e registrando app web'
  if ($retomando) {
    & (Join-Path $PSScriptRoot 'configurar-firebase.ps1') -ProjectId $ProjectId -Nome $Nome -ProjetoExistente
  } else {
    & (Join-Path $PSScriptRoot 'configurar-firebase.ps1') -ProjectId $ProjectId -Nome $Nome
  }
  if (-not $?) { Falhar 'Configuracao do Firebase falhou. Corrija antes de tentar GitHub.' }
  $real = ConfigFirebase
  if ($real.projectId -ne $ProjectId) { Falhar 'ID do Firebase nao confere. Publicacao interrompida.' }
  AplicarFirebase $ProjectId
  ValidarLocal

  Etapa 'Preparando autenticacao GitHub'
  $gh = Comando 'gh.exe' 'winget install --id GitHub.cli --exact'
  $statusGh = ConsultarCLI $gh @('auth','status')
  if (-not $statusGh.OK) { Exe $gh @('auth','login') }
  $git = Comando 'git.exe' 'https://git-scm.com/downloads/win'
  if (-not (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
    Exe $git @('init','-b','main')
  } elseif (-not $retomando) {
    Falhar 'A pasta contem outro historico Git; use outra copia limpa do ZIP.'
  }
  Exe $git @('add','--all')
  foreach ($f in @('src/main.jsx','src/App.jsx','src/firebaseConfig.json','index.html')) {
    $arquivoNoGit = ConsultarCLI $git @('ls-files', '--error-unmatch', '--', $f)
    if (-not $arquivoNoGit.OK) { Falhar "Git ignora $f. Corrija .gitignore antes de prosseguir." }
  }
  & $git 'diff' '--cached' '--quiet'
  if ($LASTEXITCODE -ne 0) {
    Exe $git @('commit','-m',"feat: configurar $ProjectId com Firebase e frontend completo")
  }
  Etapa 'Criando ou reutilizando repositorio GitHub PRIVADO'
  $origem = ConsultarCLI $git @('remote', 'get-url', 'origin')
  if ($origem.OK) {
    Write-Host 'Repositorio GitHub ja vinculado nesta pasta. Reutilizando remote origin.' -ForegroundColor Green
    Exe $git @('push','-u','origin','main')
  } else {
    Exe $gh @('repo','create',$ProjectId,'--private','--source','.','--remote','origin','--push')
  }
  Etapa 'Vinculando GitHub e Vercel (autorize uma vez)'
  $v = Comando 'vercel.cmd' 'npm.cmd install -g vercel'
  $vercelLogin = ConsultarCLI $v @('whoami')
  if (-not $vercelLogin.OK) { Exe $v @('login') }
  Write-Host 'Na proxima pergunta, crie/seleciona o projeto Vercel deste NOVO cliente.' -ForegroundColor Yellow
  Exe $v @('link')
  Exe $v @('git','connect','--yes')
  # Gera um evento de push APOS conectar GitHub-Vercel, caso integracao nao de deploy do primeiro commit.
  Exe $git @('commit','--allow-empty','-m','chore: iniciar primeiro deploy Vercel')
  Exe $git @('push','origin','main')
  $remote = (& $git 'remote' 'get-url' 'origin' | Out-String).Trim()
  if ($remote -match '^git@github\.com:(.+?)(?:\.git)?$') { $remote = 'https://github.com/' + $Matches[1] }
  SalvarRepo $ProjectId $remote
  Write-Host "`nFINALIZADO: GitHub configurado e push executado para $remote" -ForegroundColor Green
  Write-Host 'A Vercel deve iniciar um deployment. Confirme o status READY e valide login e Firestore no navegador.' -ForegroundColor Yellow
}
try {
  Etapa 'AUTOPILOTO FIREBASE + GITHUB + VERCEL - V9'
  Write-Host "Pasta: $Root"
  if ($Modo -eq 'menu') {
    Write-Host '1 - CORRIGIR meu sistema atual (Firebase/Auth + GitHub -> Vercel)'
    Write-Host '2 - NOVO sistema isolado, do zero ate GitHub e Vercel'
    Write-Host '3 - ATUALIZAR somente codigo, com validacao e GitHub'
    $escolha = (Read-Host 'Digite 1, 2 ou 3').Trim()
    switch ($escolha) { '1' {$Modo='corrigir'} '2' {$Modo='novo'} '3' {$Modo='atualizar'} default {Falhar 'Opcao invalida.'} }
  }
  ArquivosObrigatorios
  if ($Modo -eq 'novo') {
    ConfigurarNovo
  } else {
    $cfg = ConfigFirebase
    Write-Host "Firebase detectado: $($cfg.projectId)" -ForegroundColor Green
    if ($Modo -eq 'corrigir') { AplicarFirebase $cfg.projectId }
    ValidarLocal
    EnviarExistente $cfg.projectId
  }
  Write-Host "`nROTINA FINALIZADA SEM ERRO LOCAL." -ForegroundColor Green
  Write-Host 'Nao foi realizado teste real de cadastro e banco no navegador. Faca esse teste na URL publicada.' -ForegroundColor Yellow
} catch {
  Write-Host "`nERRO: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host 'Nenhum projeto Firebase sera excluido automaticamente. Corrija a etapa e execute novamente.' -ForegroundColor Yellow
  exit 1
}
