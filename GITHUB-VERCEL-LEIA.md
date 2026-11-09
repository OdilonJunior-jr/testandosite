# Consertar agora: GitHub → Vercel (sem Vercel CLI)

Este pacote foi preparado para seu projeto EXISTENTE `agenda-cliente-2026` no Firebase.
Nao cria Firebase, nao cria Vercel e nao apaga projeto algum.

## 1. Corrigir publicacao atual (Windows)

1. Extraia **o conteudo deste ZIP dentro de `C:\Users\junio\Desktop\firebase-padrao-zip`**, sem criar subpasta intermediaria.
2. Deixe os arquivos atuais, especialmente `src/firebaseConfig.json`, intactos.
3. Instale Git para Windows se ainda nao tiver: https://git-scm.com/downloads/win
4. Execute `ENVIAR-PARA-GITHUB.bat`.
5. Cole a URL HTTPS do repositorio GitHub **que ja esta conectado ao `testandosite` na Vercel**.
6. O script confere Firebase, baixa dependencias, executa testes/build, clona a ultima versao desse repositorio, copia os arquivos completos e verifica que `src/main.jsx` sera enviado.
7. Digite `PUBLICAR` para confirmar o commit e push. Se faltar algo, a publicacao e BLOQUEADA antes do envio.
8. A Vercel deve iniciar o deploy automaticamente se o repositorio e branch estiverem conectados. Verifique o resultado em Deployments.

Importante: caso o Git solicite autorizacao no navegador, entre na SUA conta GitHub. Nao envie tokens ou senhas pelo chat.

## 2. Verificacao unica na Vercel

No projeto `testandosite`, abra `Settings` → `Git` e confirme o repositorio GitHub do passo 5 e a branch de producao.
Em `Settings` → `Build and Deployment` ou `General` → `Root Directory`:
- Se `index.html`, `package.json` e `src` aparecem **na raiz** do GitHub, a raiz do projeto deve ser `.`.
- Se tudo esta dentro de uma subpasta no GitHub, use essa subpasta como Root Directory.

Depois do push, em `Deployments` → `Source`, confira a pasta `src`.
Nao e necessario clicar em `vercel deploy` nem enviar arquivos .bat pelo dashboard.

## 3. O que fica automatizado

A partir dai, o botao `ENVIAR-PARA-GITHUB.bat` faz: checagem → testes/build → commit/push.
GitHub integrado dispara um deploy na Vercel. O workflow `.github/workflows/verificar-build.yml` testa o projeto no GitHub tambem.

## Limites honestos

- Essa ferramenta nao consegue autorizar a conta GitHub por voce e nao conecta automaticamente um repo na Vercel se isso nao tiver sido feito.
- O build ter sucesso **nao prova** login no Firebase nem acesso ao Firestore: teste o site publicado criando uma conta, entrando e salvando uma anotacao.
- Mudancas em `firestore.rules` precisam ser publicadas pela CLI do Firebase; o GitHub/Vercel so publica o frontend. Nao sao feitos deploys de regras automaticamente neste fluxo.
- O arquivo Firebase web `src/firebaseConfig.json` contem configuracao publica do aplicativo (nao chave de conta de servico). As regras Firestore mantem a protecao dos dados.
- O ZIP de reparo nao sobrescreve `src/firebaseConfig.json`; se estiver vazio, o script para com aviso.
- Para futuros clientes, crie um Firebase separado e gere sua propria configuracao antes do primeiro push.

## Erros mais comuns

- `git.exe nao encontrado`: instale Git for Windows e feche/reabra terminal.
- `could not read Username` / erro de permissao: autentique-se no GitHub via navegador/Git Credential Manager.
- `Author identity unknown`: configure autor do Git com `git config --global user.name "Seu Nome"` e `git config --global user.email "seu-email-github"`.
- `403 permission denied` no push: verifique se voce tem acesso ao repositorio informado.
- `Failed to resolve /src/main.jsx` na Vercel mesmo apos push: confira **qual repo, commit e Root Directory** a Vercel usou no deployment.
