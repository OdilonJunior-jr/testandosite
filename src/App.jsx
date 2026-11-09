import { useEffect, useState } from 'react';
import { ArrowRight, Check, CircleAlert, Database, FilePlus2, Fingerprint, Layers3, LockKeyhole, LogOut, Plus, ShieldCheck, Trash2, Zap } from 'lucide-react';
import { createUserWithEmailAndPassword, onAuthStateChanged, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { addDoc, collection, deleteDoc, doc, onSnapshot, orderBy, query, serverTimestamp } from 'firebase/firestore';
import { auth, authReady, configured, db } from './firebase';

function friendlyError(error) {
  const messages = {
    'auth/email-already-in-use': 'Este e-mail já possui cadastro.',
    'auth/invalid-email': 'Confira o endereço de e-mail.',
    'auth/weak-password': 'Use uma senha com pelo menos 6 caracteres.',
    'auth/invalid-credential': 'E-mail ou senha incorretos.',
    'auth/operation-not-allowed': 'Ative E-mail/Senha no Firebase Authentication.',
    'permission-denied': 'Sem permissão. Confira as regras publicadas do Firestore.',
    'failed-precondition': 'O Firestore ainda não está disponível ou precisa de um índice.',
    'unavailable': 'Serviço temporariamente indisponível. Tente novamente.',
  };
  return messages[error?.code] || 'Não foi possível concluir. Confira a configuração e tente novamente.';
}

function Brand() {
  return <span className="brand"><span className="brand-mark"><Layers3 size={19}/></span> projeto<span className="brand-bold">base</span><span className="brand-dot">.</span></span>;
}

function MissingSetup() {
  return <div className="screen"><header className="topbar container"><Brand/><span className="top-tag">MODELO REUTILIZÁVEL</span></header>
    <main className="container hero-wrap"><div className="hero-copy"><div className="eyebrow"><span className="eyebrow-circle"/> FIREBASE + REACT</div>
      <h1>Uma base sólida para seu <em>próximo projeto.</em></h1>
      <p>O frontend já está estruturado. Execute o instalador para criar um Firebase independente, conectar o banco e publicar as regras.</p>
      <div className="setup-instructions"><div><span className="step">01</span> Abra <strong>CONFIGURAR-FIREBASE.bat</strong> no Windows</div><div><span className="step">02</span> Informe o ID exclusivo e o nome do sistema</div><div><span className="step">03</span> Habilite E-mail/Senha no console Firebase</div><div><span className="step">04</span> Execute <strong>PUBLICAR-VERCEL.bat</strong></div></div>
      <p className="note">Enquanto não houver configuração válida, nenhuma conexão com banco é iniciada.</p>
    </div><aside className="feature-panel"><div className="panel-header"><span>ARQUITETURA DO PROJETO</span><span className="status"><span/> PRONTA PARA CONFIGURAR</span></div>
    <div className="feature"><div className="feature-icon"><Fingerprint size={19}/></div><div><strong>Autenticação</strong><p>Cadastro, login e sessão persistente</p></div><Check size={18} className="check"/></div>
    <div className="feature"><div className="feature-icon"><Database size={19}/></div><div><strong>Banco Firestore</strong><p>Dados particulares por usuário</p></div><Check size={18} className="check"/></div>
    <div className="feature"><div className="feature-icon"><ShieldCheck size={19}/></div><div><strong>Regras de segurança</strong><p>Negar acesso não autorizado</p></div><Check size={18} className="check"/></div>
    <div className="feature"><div className="feature-icon"><Zap size={19}/></div><div><strong>Publicação</strong><p>Preparado para Vercel</p></div><Check size={18} className="check"/></div>
    <div className="panel-footer"><LockKeyhole size={16}/> Um Firebase isolado por sistema</div></aside></main><footer className="container footer">MODELO BASE • SEM DADOS REAIS • v1.0</footer></div>;
}

function AuthScreen() {
  const [mode, setMode] = useState('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function submit(ev) {
    ev.preventDefault(); setError(''); setBusy(true);
    try {
      await authReady;
      if (mode === 'register') await createUserWithEmailAndPassword(auth, email.trim(), password);
      else await signInWithEmailAndPassword(auth, email.trim(), password);
    } catch (err) { setError(friendlyError(err)); } finally { setBusy(false); }
  }

  return <div className="screen"><header className="topbar container"><Brand/><span className="top-tag">ÁREA DEMONSTRATIVA</span></header>
    <main className="container auth-layout"><section className="intro"><div className="eyebrow"><span className="eyebrow-circle"/> AMBIENTE FUNCIONAL</div><h1>Seu sistema, com <em>acesso seguro.</em></h1><p>Esta aplicação demonstra autenticação real e operações de leitura e gravação no Firestore, sem compartilhar dados entre usuários.</p><div className="secure-note"><ShieldCheck size={20}/><div><strong>Dados isolados</strong><span>Cada conta vê somente as suas anotações.</span></div></div></section>
    <section className="auth-card"><div className="card-overline">{mode === 'login' ? 'ACESSAR SISTEMA' : 'CRIAR CONTA DE TESTE'}</div><h2>{mode === 'login' ? 'Bem-vindo de volta.' : 'Vamos começar.'}</h2><p>{mode === 'login' ? 'Entre com sua conta para continuar.' : 'Crie uma conta para testar a integração.'}</p>
    <form onSubmit={submit}><label>E-mail<input type="email" required autoComplete="email" placeholder="seu@email.com" value={email} onChange={(e)=>setEmail(e.target.value)}/></label><label>Senha<input type="password" minLength={6} required autoComplete={mode === 'login' ? 'current-password' : 'new-password'} placeholder="Mínimo de 6 caracteres" value={password} onChange={(e)=>setPassword(e.target.value)}/></label>
    {error && <div role="alert" className="alert"><CircleAlert size={17}/>{error}</div>}
    <button className="primary-btn" type="submit" disabled={busy}>{busy ? 'Processando...' : mode === 'login' ? 'Entrar no sistema' : 'Criar conta'}<ArrowRight size={18}/></button></form>
    <button className="text-link" onClick={()=>{setMode(mode === 'login'?'register':'login');setError('')}}>{mode === 'login' ? 'Não tem conta? Criar uma conta' : 'Já tenho uma conta. Entrar'}</button></section></main><footer className="container footer">AUTENTICAÇÃO FIREBASE • BANCO FIRESTORE</footer></div>;
}

function Dashboard({ user }) {
  const [notes, setNotes] = useState([]);
  const [draft, setDraft] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true); setError('');
    const notesRef = collection(db, 'usuarios', user.uid, 'anotacoes');
    const unsubscribe = onSnapshot(query(notesRef, orderBy('criadoEm', 'desc')),
      (snapshot) => {setNotes(snapshot.docs.map(item => ({id:item.id,...item.data()})));setLoading(false);},
      (err) => {setError(friendlyError(err));setLoading(false);});
    return () => unsubscribe();
  }, [user.uid]);

  async function addNote(ev) {
    ev.preventDefault();const text = draft.trim();
    if (!text || text.length > 180) return;
    setBusy(true);setError('');
    try { await addDoc(collection(db,'usuarios',user.uid,'anotacoes'),{texto:text,criadoEm:serverTimestamp()});setDraft(''); }
    catch(err){setError(friendlyError(err));} finally{setBusy(false);}
  }
  async function removeNote(id) {
    setError('');
    try {await deleteDoc(doc(db,'usuarios',user.uid,'anotacoes',id));}
    catch(err){setError(friendlyError(err));}
  }
  return <div className="screen dashboard-screen"><header className="topbar container"><Brand/><button className="logout" onClick={()=>signOut(auth).catch(err=>setError(friendlyError(err)))}>Sair <LogOut size={17}/></button></header>
  <main className="container dash-main"><div className="dash-head"><div><div className="eyebrow"><span className="eyebrow-circle"/> PROJETO CONECTADO</div><h1>Seu espaço.</h1><p>Leitura e gravação em tempo real no Firebase Firestore.</p></div><div className="user-pill"><span className="user-avatar">{user.email?.slice(0,1).toUpperCase()}</span><div><small>LOGADO COMO</small><span>{user.email}</span></div></div></div>
  <div className="dash-columns"><section className="dash-card"><div className="dash-card-header"><FilePlus2 size={19}/><strong>Nova anotação</strong></div><p>Faça um teste. O conteúdo ficará salvo no seu banco Firestore.</p><form onSubmit={addNote}><label className="sr-only" htmlFor="note">Texto da anotação</label><textarea id="note" maxLength={180} value={draft} onChange={e=>setDraft(e.target.value)} placeholder="Digite alguma coisa para salvar..."/><div className="form-actions"><span>{draft.length}/180 caracteres</span><button className="primary-btn" type="submit" disabled={busy || !draft.trim()}><Plus size={18}/>{busy ? 'Salvando...' : 'Salvar'}</button></div></form></section>
  <section className="dash-card"><div className="dash-card-header"><Database size={19}/><strong>Anotações salvas</strong><span className="count">{notes.length}</span></div>{error && <div className="alert"><CircleAlert size={16}/>{error}</div>}{loading ? <div className="empty">Carregando seus dados...</div> : notes.length === 0 ? <div className="empty"><Database size={26}/><strong>Nenhuma anotação</strong><span>Adicione uma anotação para testar o banco.</span></div> : <ul className="notes">{notes.map((note)=><li key={note.id}><div><span>{note.texto}</span><small>{note.criadoEm?.toDate ? note.criadoEm.toDate().toLocaleString('pt-BR') : 'Salvando...'}</small></div><button type="button" aria-label="Excluir anotação" title="Excluir anotação" onClick={()=>removeNote(note.id)}><Trash2 size={17}/></button></li>)}</ul>}</section></div><div className="bottom-caption"><ShieldCheck size={16}/> Acesso protegido pelas regras do Firestore, não apenas pela interface.</div></main></div>;
}

export default function App() {
  const [state, setState] = useState({ loading: configured, user: null });
  useEffect(() => {
    if (!auth) return;
    let stop = () => {};
    let mounted = true;
    authReady.then(() => {if(mounted) stop=onAuthStateChanged(auth,(user)=>setState({loading:false,user}),()=>setState({loading:false,user:null}));});
    return () => {mounted = false;stop();};
  }, []);
  if (!configured) return <MissingSetup/>;
  if (state.loading) return <div className="loading-screen">Abrindo seu sistema...</div>;
  return state.user ? <Dashboard user={state.user}/> : <AuthScreen/>;
}
