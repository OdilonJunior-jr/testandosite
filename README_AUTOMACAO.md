# PUBLICADOR AUTOMATICO V8 — FIREBASE + GITHUB + VERCEL

## Este e o fluxo completo, com UM instalador

1. **Firebase:** identifica projeto existente ou cria um separado, registra app web, cria (ou preserva) banco Firestore, ativa Authentication E-mail/Senha pelo `firebase.json` e publica regras e indices.
2. **Frontend:** confere `src/main.jsx`, instala dependencias, executa testes e build. Se falhar, para ANTES de publicar.
3. **GitHub:** copia TODOS os arquivos essenciais (`src/` inclusive) e faz push no repositorio existente. Para um sistema novo, cria repositorio PRIVADO com `gh`.
4. **Vercel:** projeto existente ja vinculado ao GitHub publica automaticamente apos o push; para novo projeto, o script executa `vercel link` e `vercel git connect --yes` e dispara push.
5. **Validacao final:** confirma build e upload local. Validacao de cadastro, login e banco reais depende de executar o teste no site publicado.

## ARRUMAR O SISTEMA ATUAL `agenda-cliente-2026` / `testandosite`

1. Extraia **CORRECAO_AUTOMATICA_SISTEMA_ATUAL_V8.zip** dentro de `C:\Users\junio\Desktop\firebase-padrao-zip`, aceitando substituir somente arquivos de automacao/diagnostico. Nao apague `src/firebaseConfig.json` ou `.firebaserc`.
2. Execute **`CORRIGIR-SISTEMA-ATUAL.bat`**. O instalador detectara `agenda-cliente-2026` a partir da sua configuracao local. Ele NAO cria outro projeto Firebase.
3. Na primeira utilizacao, autorize Firebase e GitHub pelas CLIs, se solicitado. O instalador pode instalar a Firebase CLI se Node.js ja estiver instalado, mas Git para Windows deve estar disponivel.
4. Cole **a URL GitHub do repositorio que esta conectado ao `testandosite` na Vercel**, nao a URL do site. Na primeira vez, digite `PUBLICAR` para confirmar o destino. Nao sera preciso reenviar a pasta `src` manualmente.
5. Quando o site for atualizado, teste **cadastro, login, salvar anotacao e atualizar a pagina**. A tela mostrara erros especificos caso a integracao Firebase falhe.

## PARA NOVOS PROJETOS DE CLIENTES

1. Extraia **MODELO_AUTOMATICO_COMPLETO_V8.zip** numa pasta NOVA, uma por cliente.
2. Execute **`AUTOMATIZAR-TUDO.bat`** e escolha `2 - NOVO sistema`.
3. Escolha um ID exclusivo do Firebase e nome do sistema. Autorize Google/GitHub/Vercel quando as CLIs oficiais pedirem, apenas no primeiro acesso ou quando a sessao expirar.
4. O instalador configura Firebase, banco e login, instala dependencias, verifica o frontend, cria repositorio GitHub privado e vincula a Vercel. Se alguma etapa falhar, veja o erro e execute de novo; nao exclua o projeto criado.
5. Para atualizacoes futuras na mesma pasta, execute `AUTOMATIZAR-TUDO.bat` e escolha `3 - ATUALIZAR`.

## REALIDADE SOBRE A AUTOMACAO

- Sem tokens fornecidos por chat e sem APIs pagas de IA. A automacao usa as **CLIs oficiais** das tres plataformas, que podem requerer permissao, login no navegador e eventuais custos/cotas dos servicos.
- Se a API Firestore devolver 403, a rotina tenta ativar via `gcloud` se instalado/autorizado. Caso contrario, abre a pagina oficial para autorizacao do titular, depois retoma sem recriar o projeto.
- Projeto criado no Firebase e conta de login funcionando sao coisas diferentes. Apos o deploy, execute um teste de cadastro e gravacao real — o script nao vai afirmar que estao funcionando sem esse teste.
- Nao apaga banco, nao modifica usuarios existentes e nao coloca segredos de servidor em repositorios GitHub. `src/firebaseConfig.json` contem identificadores publicos do SDK web, nao uma senha.
- Se GitHub e Vercel ainda nao estiverem vinculados no projeto antigo, conclua o vinculo uma unica vez na Vercel. O script nao tenta conectar outro projeto Vercel existente por adivinhacao.
- A pasta `.github/workflows` valida o build em pushes e PRs. A integracao Vercel/GitHub dispara deploy independentemente das verificacoes do Actions; o script interrompe pushes locais se o build falhar.

**Requisitos**: Windows 10/11, Node.js LTS, Git para Windows, acesso do titular a Firebase/GitHub/Vercel; para criacao de novos repositorios, GitHub CLI; para novos projetos Vercel, Vercel CLI. O instalador tenta instalar CLIs Node e GitHub via `winget` quando possivel. Nunca pede token secreto diretamente.

Documentacao oficial:
- https://firebase.google.com/docs/auth/configure-providers-cli
- https://firebase.google.com/docs/cli
- https://firebase.google.com/docs/firestore/manage-databases
- https://cli.github.com/manual/gh_repo_create
- https://vercel.com/docs/cli/git
