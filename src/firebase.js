import { initializeApp } from 'firebase/app';
import { getAuth, browserLocalPersistence, setPersistence } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import firebaseConfig from './firebaseConfig.json';

export function validFirebaseConfig(cfg) {
  return Boolean(cfg && ['apiKey', 'authDomain', 'projectId', 'appId']
    .every((field) => typeof cfg[field] === 'string' && cfg[field].trim()));
}

export const configured = validFirebaseConfig(firebaseConfig);
export const app = configured ? initializeApp(firebaseConfig) : null;
export const auth = app ? getAuth(app) : null;
export const db = app ? getFirestore(app) : null;

// Firebase Auth usa persistencia local no navegador quando suportado.
export const authReady = auth
  ? setPersistence(auth, browserLocalPersistence).catch((error) => {
      console.warn('Persistencia local indisponivel:', error.code || error.message);
    })
  : Promise.resolve();
