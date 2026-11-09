import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (name) => readFileSync(path.join(root, name), 'utf8');

test('configuracao Firebase e arquivos de infraestrutura', () => {
  const cfg = JSON.parse(read('firebase.json'));
  assert.equal(cfg.firestore.rules, 'firestore.rules');
  assert.equal(cfg.firestore.indexes, 'firestore.indexes.json');
  assert.ok(existsSync(path.join(root, 'firestore.rules')));
  assert.deepEqual(JSON.parse(read('firestore.indexes.json')).indexes, []);
});

test('regras exigem autenticacao e isolamento por usuario', () => {
  const rules = read('firestore.rules');
  assert.match(rules, /request\.auth != null && request\.auth\.uid == userId/);
  assert.match(rules, /match \/usuarios\/\{userId\}\/anotacoes\/\{noteId\}/);
  assert.doesNotMatch(rules, /allow read, write: if true/);
  assert.match(rules, /request\.resource\.data\.criadoEm == request\.time/);
});

test('frontend e scripts do pacote disponiveis', () => {
  for (const file of ['src/App.jsx', 'src/main.jsx', 'src/firebase.js', 'src/firebaseConfig.json',
    'CONFIGURAR-FIREBASE.bat', 'PUBLICAR-VERCEL.bat', 'scripts/configurar-firebase.ps1',
    'scripts/publicar-vercel.ps1', 'vercel.json', 'index.html']) {
    assert.ok(existsSync(path.join(root, file)), `faltando ${file}`);
  }
  const cfg = JSON.parse(read('src/firebaseConfig.json'));
  assert.equal(typeof cfg.projectId, 'string');
});

test('script barra configuracao conectada a outro cliente', () => {
  assert.match(read('scripts/configurar-firebase.ps1'), /ja esta conectado ao projeto/);
  assert.match(read('scripts/publicar-vercel.ps1'), /IDs divergentes/);
});
