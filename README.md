# MODELO-BASE · Firebase + React + Vercel

Modelo reutilizável para **um Firebase por sistema**, usando a **mesma conta Google**. Inclui aplicação React funcional, exemplo de cadastro/login com Firebase Authentication, anotações em Firestore em tempo real e regras de segurança por usuário.

> **Importante:** este ZIP não cria recursos em sua conta sozinho. Você precisa autorizar a CLI no seu computador, aceitar qualquer exigência da conta Google/Firebase e habilitar o provedor de autenticação uma vez no Console. Após essas etapas, o frontend pode ser publicado na Vercel.

## Requisitos (uma única vez por computador)

1. Instale Node.js LTS (versão compatível com a indicada em `package.json`).
2. Abra o **Terminal ou PowerShell** e execute:

   ```powershell
   npm install -g firebase-tools vercel
   ```

3. Tenha acesso à sua conta Firebase e Vercel. A CLI abre o navegador durante o login.

## Instalação para NOVO sistema (Windows)

1. **Extraia o ZIP** em uma pasta exclusiva do sistema. Não reutilize a mesma pasta para dois clientes.
2. Clique em **`CONFIGURAR-FIREBASE.bat`**.
3. Quando solicitado, entre na **sua conta Google** e informe:
   - ID único, exemplo: `agenda-cliente-2026-a1` (não poderá ser trocado depois)
   - Nome do sistema, exemplo: `Agenda Cliente`
4. O instalador fará, nesta ordem:
   - Criação do projeto Firebase na sua conta Google
   - Registro de um aplicativo Web
   - Captura da configuração pública do SDK em `src/firebaseConfig.json`
   - Associação explícita àquele projeto no `.firebaserc`
   - Criação do banco Firestore `(default)` em `southamerica-east1` por padrão
   - Publicação das regras de segurança e índices do Firestore
   - Geração de um marcador local de implantação concluída (a publicação na Vercel é bloqueada caso a etapa anterior falhe)
5. Acesse o **Console Firebase** desse projeto > **Authentication > Sign-in method** > habilite **Email/Password**. Sem isso, o cadastro/login retornará um erro. Se não quiser login no projeto real, remova essa funcionalidade ao customizar o modelo.
6. Clique em **`PUBLICAR-VERCEL.bat`**. Faça login na Vercel, confirme o novo projeto quando solicitado e aguarde a publicação.
7. No site publicado, **crie um usuário de teste, salve e exclua uma anotação**, atualize a página e teste novamente.

**Para testar localmente:** abra um terminal na pasta do projeto, rode `npm install` e `npm run dev`. Para conferir o projeto use `npm run check`.

## Retomar uma instalação interrompida

O script **não foi projetado para ser repetido cegamente**. Se a criação do projeto Firebase foi concluída, mas falhou depois, você pode invocar diretamente o PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\configurar-firebase.ps1 -ProjectId "ID-JA-CRIADO" -Nome "Nome do sistema" -ProjetoExistente
```

Se **o banco também já existir**, adicione `-BancoExistente`. Se o SDK já tiver sido salvo em `src/firebaseConfig.json`, o instalador preservará esse mesmo aplicativo WEB; se ainda não tiver sido salvo, um aplicativo WEB poderá ser registrado novamente na retomada. **Não execute este comando em um projeto Firebase que contenha dados de outro cliente**: a publicação de regras poderá sobrescrever regras existentes. Para um sistema novo, prefira começar do zero com um ID novo.

## Estrutura

```text
firebase-padrao-zip/
├── CONFIGURAR-FIREBASE.bat         # Configuração guiada Firebase (Windows)
├── PUBLICAR-VERCEL.bat            # Validação + deploy Vercel (Windows)
├── scripts/
│   ├── configurar-firebase.ps1    # CLI Firebase (projeto, web app, DB e regras)
│   ├── publicar-vercel.ps1       # Deploy do frontend
│   └── tests/estrutura.test.mjs  # Verificações locais automatizadas
├── src/
│   ├── App.jsx                   # UI de login e anotações
│   ├── firebase.js               # Integração SDK e persistência local
│   ├── firebaseConfig.json       # Dados do app web preenchidos pela CLI
│   └── styles.css                # Estilo responsivo
├── firestore.rules               # Firestore bloqueado por padrão
├── firestore.indexes.json        # Índices
├── firebase.json                 # Infraestrutura Firebase
├── vercel.json                   # Publicação SPA Vercel
└── package.json                  # Dependências
```

## Regras de segurança e limites

- **Segurança:** só é permitida a leitura/gravação de `usuarios/{UID}/anotacoes/{ID}` pelo próprio usuário. Todo o resto é negado por padrão. Não use `allow read, write: if true` em produção.
- **Exemplo didático:** cadastro livre é adequado para testar, mas **não é um painel administrativo pronto para clientes**. Para projetos reais, personalize papéis, convite de usuários, validações de negócio, bloqueios e testes de regras antes de publicar. Não confie apenas em esconder elementos na interface.
- **Configuração pública:** os campos do Firebase web SDK (inclusive a API key do SDK) identificam o app no cliente e **não são credenciais administrativas**. Proteja o backend com regras e não coloque tokens privados nem chaves de serviço no frontend.
- **Firestore:** as coleções de exemplo surgem automaticamente na primeira gravação. Não existe um schema relacional pré-criado; o ZIP inclui regras e estrutura de documentos como código.
- **Custo:** quotas e faturamento podem limitar a criação de projetos, a região Firestore ou outros serviços. Não habilite recursos pagos sem consultar custos. Cloud Functions e integrações com provedores externos exigem configuração específica.
- **Autorização:** nenhum login de conta Google, criação de banco, ativação de método de login ou deploy em ambiente remoto foi executado durante a geração deste arquivo; esses passos acontecerão na sua máquina.
- **Domínio:** se adicionar autenticação via Google/OAuth, redirecionamento ou links por e-mail futuramente, configure os domínios autorizados em Authentication.

## Como usar o padrão em futuros projetos

Para cada novo cliente, parta de uma **cópia limpa desse ZIP**, desenvolva a interface e o backend sob medida e execute a configuração com um **novo ID Firebase**. Não altere os recursos de um sistema anterior. Se a solução exigir Firestore, substitua a coleção de exemplo por coleções, regras, índices, scripts e testes adequados à lógica do novo sistema.

**Documentação oficial:** https://firebase.google.com/docs/cli | https://firebase.google.com/docs/firestore/manage-databases | https://vercel.com/docs/projects/deploy-from-cli
