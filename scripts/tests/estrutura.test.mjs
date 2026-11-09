import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (file) => readFileSync(path.join(root, file), 'utf8');

test('arquivos React essenciais', () => {
  for (const file of ['src/main.jsx','src/App.jsx','src/styles.css','src/firebase.js',
    'src/firebaseConfig.json','index.html','package.json','vite.config.js','vercel.json']) {
    assert.ok(existsSync(path.join(root, file)), `Falta ${file}`);
  }
});
test('Firebase isolado e Authentication declarados', () => {
  const cfg = JSON.parse(read('firebase.json'));
  assert.equal(cfg.auth.providers.emailPassword, true);
  assert.equal(cfg.firestore.rules, 'firestore.rules');
  assert.equal(cfg.firestore.indexes, 'firestore.indexes.json');
  const rules = read('firestore.rules');
  assert.match(rules, /request\.auth != null && request\.auth\.uid == userId/);
  assert.doesNotMatch(rules, /allow read, write: if true/);
  const sdk = JSON.parse(read('src/firebaseConfig.json'));
  assert.equal(typeof sdk.projectId, 'string');
});
test('AUTOPILOTO unico e guardas', () => {
  for (const f of ['AUTOMATIZAR-TUDO.bat', 'scripts/autopilot.ps1',
    'scripts/configurar-firebase.ps1', 'scripts/enviar-github.ps1',
    '.github/workflows/verificar-build.yml']) assert.ok(existsSync(path.join(root, f)));
  const auto = read('scripts/autopilot.ps1');
  assert.match(auto, /auth,firestore/);
  assert.match(auto, /GarantirBancoFirestore/);
  assert.match(auto, /firestore:databases:create/);
  assert.match(auto, /gh\.exe/);
  assert.match(auto, /git','connect/);
  assert.match(auto, /Firebase nao foi conectado/);
  assert.match(auto, /Protecao: \.firebaserc aponta/);
  assert.match(auto, /run','check/);
});
test('Mensagens Firebase explicitas para diagnostico', () => {
  assert.match(read('src/App.jsx'), /auth\/configuration-not-found/);
  assert.match(read('src/App.jsx'), /auth\/operation-not-allowed/);
  assert.match(read('src/App.jsx'), /codigo: /);
});
test('Arquivos privados nunca sao enviados', () => {
  const ignore = read('.gitignore');
  for (const entry of ['node_modules/', 'dist/', '.vercel/', '.env', '.autopilot.json'])
    assert.ok(ignore.includes(entry));
  const send = read('scripts/enviar-github.ps1');
  assert.match(send, /git.*ls-files|ls-files/s);
  assert.match(send, /FIREBASE DIVERGENTE/);
});
