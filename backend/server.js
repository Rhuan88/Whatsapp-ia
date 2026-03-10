require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const axios = require('axios');
const app = express();
app.use(express.json());

const db = new Pool(
  process.env.DATABASE_URL
    ? { connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } }
    : { host:'localhost', database:'bot_ocorrencias', user:'postgres', password:'senha' }
);

async function inicializarBanco() {
  await db.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);
  await db.query(`CREATE TABLE IF NOT EXISTS solicitantes (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), telefone VARCHAR(20) UNIQUE NOT NULL, nome VARCHAR(150), criado_em TIMESTAMP DEFAULT NOW())`);
  await db.query(`CREATE TABLE IF NOT EXISTS boletins_ocorrencia (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), protocolo VARCHAR(30) UNIQUE NOT NULL, solicitante_id UUID, tipo_ocorrencia VARCHAR(100) DEFAULT 'A CLASSIFICAR', relato_original TEXT NOT NULL, documento_gerado TEXT NOT NULL, status VARCHAR(30) DEFAULT 'REGISTRADO', criado_em TIMESTAMP DEFAULT NOW())`);
  await db.query(`CREATE TABLE IF NOT EXISTS ordens_servico (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), numero_os VARCHAR(30) UNIQUE NOT NULL, solicitante_id UUID, tipo_servico VARCHAR(100) NOT NULL, descricao_problema TEXT NOT NULL, documento_gerado TEXT NOT NULL, status VARCHAR(30) DEFAULT 'ABERTA', criado_em TIMESTAMP DEFAULT NOW())`);
  await db.query(`CREATE TABLE IF NOT EXISTS conversas (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), telefone VARCHAR(20) UNIQUE NOT NULL, estado_atual VARCHAR(50) DEFAULT 'INICIO', contexto JSONB DEFAULT '{}', ultima_msg TIMESTAMP DEFAULT NOW())`);
  await db.query(`CREATE TABLE IF NOT EXISTS mensagens (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), telefone VARCHAR(20) NOT NULL, direcao VARCHAR(10) NOT NULL, conteudo TEXT NOT NULL, enviado_em TIMESTAMP DEFAULT NOW())`);
  await db.query(`CREATE OR REPLACE VIEW vw_historico AS SELECT s.telefone,'BOLETIM' AS tipo,bo.protocolo AS numero,bo.tipo_ocorrencia AS categoria,bo.status,bo.criado_em AS data_registro FROM solicitantes s JOIN boletins_ocorrencia bo ON bo.solicitante_id=s.id UNION ALL SELECT s.telefone,'ORDEM_SERVICO',os.numero_os,os.tipo_servico,os.status,os.criado_em FROM solicitantes s JOIN ordens_servico os ON os.solicitante_id=s.id`);
  console.log('Banco ok');
}

const gerarProtocolo = () => `BO-${new Date().getFullYear()}-${Math.floor(Math.random()*9999999).toString().padStart(7,'0')}`;
const gerarNumeroOS = () => { const d=new Date(); return `OSV-${d.getFullYear()}${String(d.getMonth()+1).padStart(2,'0')}-${Math.floor(Math.random()*99999).toString().padStart(5,'0')}`; };
const dataHoraBR = () => new Date().toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo'});

async function getConversa(tel) { const r=await db.query('SELECT * FROM conversas WHERE telefone=$1',[tel]); return r.rows[0]||null; }
async function setEstado(tel,estado,ctx={}) { await db.query(`INSERT INTO conversas(telefone,estado_atual,contexto,ultima_msg) VALUES($1,$2,$3,NOW()) ON CONFLICT(telefone) DO UPDATE SET estado_atual=$2,contexto=$3,ultima_msg=NOW()`,[tel,estado,JSON.stringify(ctx)]); }
async function getSolicitante(tel) { let r=await db.query('SELECT * FROM solicitantes WHERE telefone=$1',[tel]); if(r.rows[0])return r.rows[0]; r=await db.query('INSERT INTO solicitantes(telefone) VALUES($1) RETURNING *',[tel]); return r.rows[0]; }

async function chamarClaude(system,user) {
  const r=await axios.post('https://api.anthropic.com/v1/messages',{model:'claude-sonnet-4-20250514',max_tokens:2000,system,messages:[{role:'user',content:user}]},{headers:{'x-api-key':process.env.ANTHROPIC_API_KEY,'anthropic-version':'2023-06-01','Content-Type':'application/json'}});
  return r.data.content[0].text;
}

function promptBO(protocolo) {
  return `Voce e um assistente especializado em Boletins de Ocorrencia. Com base no relato fornecido, gere um guia detalhado e estruturado para preenchimento do aplicativo de registro de ocorrencias, com o protocolo ${protocolo}. O guia deve conter: 1) Tipo de ocorrencia, 2) Dados do solicitante, 3) Dados do autor/suspeito (se houver), 4) Localizacao detalhada, 5) Descricao dos fatos em linguagem formal, 6) Objetos/veiculos envolvidos. Seja claro e objetivo, usando linguagem formal e juridica adequada.`;
}

function promptOS(numOS, tipo) {
  return `Voce e um assistente especializado em ordens de servico. Com base na descricao fornecida, gere uma Ordem de Servico formal e detalhada numero ${numOS} do tipo ${tipo}. O documento deve conter: 1) Identificacao do solicitante, 2) Descricao detalhada do problema, 3) Localizacao/setor, 4) Grau de urgencia, 5) Acoes recomendadas, 6) Observacoes relevantes. Use linguagem tecnica e formal adequada.`;
}

async function gerarBO(relato, solId, protocolo) {
  const doc = await chamarClaude(promptBO(protocolo), `Relato:\n\n${relato}`);
  await db.query(`INSERT INTO boletins_ocorrencia(protocolo,solicitante_id,tipo_ocorrencia,relato_original,documento_gerado) VALUES($1,$2,$3,$4,$5)`,[protocolo,solId,'A CLASSIFICAR',relato,doc]);
  return doc;
}

async function gerarOS(desc, solId, numOS, tipo) {
  const doc = await chamarClaude(promptOS(numOS,tipo), `Tipo: ${tipo}\n\n${desc}`);
  await db.query(`INSERT INTO ordens_servico(numero_os,solicitante_id,tipo_servico,descricao_problema,documento_gerado) VALUES($1,$2,$3,$4,$5)`,[numOS,solId,tipo,desc,doc]);
  return doc;
}

async function consultarHistorico(tel) {
  const r=await db.query(`SELECT tipo,numero,categoria,status,data_registro FROM vw_historico WHERE telefone=$1 ORDER BY data_registro DESC LIMIT 10`,[tel]);
  if(!r.rows.length) return 'Nenhum registro.\n\nDigite *menu* para voltar.';
  let msg='*Historico:*\n\n';
  r.rows.forEach(x=>{ msg+=`${x.tipo==='BOLETIM'?'🚔':'🔧'} *${x.numero}*\n   ${x.categoria} - ${x.status}\n   ${new Date(x.data_registro).toLocaleDateString('pt-BR')}\n\n`; });
  return msg+'_Digite *menu* para voltar._';
}

function menuPrincipal() {
  return '🏛️ *Sistema de Registros Oficiais*\n\n1️⃣ Gerar guia de Boletim de Ocorrencia\n2️⃣ Gerar Ordem de Servico\n3️⃣ Consultar historico\n4️⃣ Buscar por Protocolo/OS\n\n_Digite o numero da opcao._';
}

async function processarMensagem(tel, mensagem) {
  const txt=mensagem.trim().toLowerCase();
  const conv=await getConversa(tel);
  const estado=conv?.estado_atual||'INICIO';
  const ctx=conv?.contexto||{};
  await db.query('INSERT INTO mensagens(telefone,direcao,conteudo) VALUES($1,$2,$3)',[tel,'ENTRADA',mensagem]).catch(()=>{});
  if(['menu','oi','ola','0','cancelar','voltar','start'].includes(txt)){ await setEstado(tel,'MENU',{}); return menuPrincipal(); }
  if(estado==='INICIO'||estado==='MENU'){
    if(txt==='1'){ await setEstado(tel,'BO_RELATO',{}); return '🚔 *Gerar Guia de Boletim de Ocorrencia*\n\nInforme:\n1 O que aconteceu?\n2 Quando? (data e hora)\n3 Onde? (rua, numero, bairro, cidade)\n4 Seus dados: nome, RG, telefone\n5 Autor/suspeito (caracteristicas)\n6 Testemunhas (se houver)\n7 Objetos/veiculos envolvidos\n\n_Relate livremente._\n\nDigite *0* para cancelar.'; }
    if(txt==='2'){ await setEstado(tel,'OS_TIPO',{}); return '🔧 *Ordem de Servico*\n\nTipo de servico:\n1 Eletrico\n2 Hidraulico\n3 Manutencao Geral\n4 Limpeza/Conservacao\n5 Estrutural/Civil\n6 Outro\n\nDigite o numero:'; }
    if(txt==='3') return await consultarHistorico(tel);
    if(txt==='4'){ await setEstado(tel,'BUSCA',{}); return 'Digite o protocolo (BO-...) ou numero da Ordem de Servico (OSV-...):'; }
    return menuPrincipal();
  }
  if(estado==='BO_RELATO'){
    if(mensagem.length<20) return 'Forneca mais detalhes para gerar o guia.';
    const s=await getSolicitante(tel);
    const prot=gerarProtocolo();
    const doc=await gerarBO(mensagem,s.id,prot);
    await setEstado(tel,'MENU',{});
    return `✅ *Guia de BO Gerado*\n\nProtocolo: *${prot}*\n\n${doc}\n\nDigite *menu* para voltar.`;
  }
  if(estado==='OS_TIPO'){
    const tipos={'1':'ELETRICO','2':'HIDRAULICO','3':'MANUTENCAO GERAL','4':'LIMPEZA/CONSERVACAO','5':'ESTRUTURAL/CIVIL','6':'OUTRO'};
    const tipo=tipos[txt];
    if(!tipo) return 'Opcao invalida. Digite 1 a 6:';
    await setEstado(tel,'OS_DESC',{tipoServico:tipo});
    return `🔧 *${tipo}*\n\nInforme:\n1 Qual o problema?\n2 Onde? (endereco, setor, sala)\n3 Seu nome, cargo e telefone\n4 Quando comecou?\n5 Ha urgencia ou risco?\n6 Ja houve tentativa de solucao?\n\n_Relate livremente._`;
  }
  if(estado==='OS_DESC'){
    if(mensagem.length<20) return 'Forneca mais detalhes.';
    const s=await getSolicitante(tel);
    const numOS=gerarNumeroOS();
    const tipo=ctx.tipoServico||'GERAL';
    const doc=await gerarOS(mensagem,s.id,numOS,tipo);
    await setEstado(tel,'MENU',{});
    return `✅ *Ordem de Servico Gerada*\n\nNumero: *${numOS}*\n\n${doc}\n\nGuarde o numero: *${numOS}*\n\nDigite *menu* para voltar.`;
  }
  if(estado==='BUSCA'){
    const num=mensagem.trim().toUpperCase();
    let r=await db.query(`SELECT bo.*,s.telefone FROM boletins_ocorrencia bo JOIN solicitantes s ON s.id=bo.solicitante_id WHERE bo.protocolo=$1 AND s.telefone=$2`,[num,tel]);
    if(r.rows[0]){ const bo=r.rows[0]; await setEstado(tel,'MENU',{}); return `🚔 *${bo.protocolo}*\nStatus: ${bo.status}\n\n${bo.documento_gerado}\n\nDigite *menu* para voltar.`; }
    let osCandidatos = [num];
    if (num.startsWith('OSV-')) osCandidatos.push(num.replace(/^OSV-/, 'OS-'));
    if (num.startsWith('OS-')) osCandidatos.push(num.replace(/^OS-/, 'OSV-'));
    osCandidatos = [...new Set(osCandidatos)];
    r=await db.query(`SELECT os.*,s.telefone FROM ordens_servico os JOIN solicitantes s ON s.id=os.solicitante_id WHERE os.numero_os = ANY($1::text[]) AND s.telefone=$2`,[osCandidatos,tel]);
    if(r.rows[0]){ const os=r.rows[0]; await setEstado(tel,'MENU',{}); return `🔧 *${os.numero_os}*\nTipo: ${os.tipo_servico}\nStatus: ${os.status}\n\n${os.documento_gerado}\n\nDigite *menu* para voltar.`; }
    await setEstado(tel,'MENU',{});
    return 'Nao encontrado.\n\nDigite *menu* para voltar.';
  }
  await setEstado(tel,'MENU',{});
  return menuPrincipal();
}

app.post('/webhook',async(req,res)=>{
  try{
    const body=req.body; let tel,msg;
    if(body.data?.key?.remoteJid){
      const remoteJid = body.data.key.remoteJid;
      if (remoteJid.endsWith('@g.us')) return res.sendStatus(200);
      tel=remoteJid.replace('@s.whatsapp.net','').replace('@c.us','');
      msg=body.data.message?.conversation||body.data.message?.extendedTextMessage?.text||'';
    }
    else if(body.phone&&body.text){ tel=body.phone; msg=body.text?.message||''; }
    else if(body.from&&body.body){ tel=body.from.replace('@c.us',''); msg=body.body; }
    if(!tel||!msg) return res.sendStatus(200);
    const resp=await processarMensagem(tel,msg);
    await enviarMensagem(tel,resp);
    res.sendStatus(200);
  }catch(e){ console.error(e.message); res.sendStatus(500); }
});

async function enviarMensagem(tel,msg){
  if(!process.env.WHATSAPP_API_URL){ console.log(`[-> ${tel}]: ${msg.substring(0,80)}`); return; }
  const numero = String(tel || '').replace(/\D/g, '');
  if(!numero) return;
  const url = `${process.env.WHATSAPP_API_URL}/message/sendText/${process.env.WHATSAPP_INSTANCE}`;
  const headers = { apikey: process.env.WHATSAPP_TOKEN };
  try{
    await axios.post(url,{number:numero,text:msg},{headers});
  }
  catch(_e1){
    try{
      await axios.post(url,{number:numero,textMessage:{text:msg}},{headers});
    }
    catch(e2){
      const detalhe = e2.response?.data ? ` ${JSON.stringify(e2.response.data)}` : '';
      console.error('Envio:',e2.message + detalhe);
    }
  }
}

app.get('/api/boletins',async(req,res)=>{ try{ const r=await db.query(`SELECT bo.*,s.telefone FROM boletins_ocorrencia bo JOIN solicitantes s ON s.id=bo.solicitante_id ORDER BY bo.criado_em DESC LIMIT 100`); res.json(r.rows); }catch(e){res.status(500).json({erro:e.message});} });
app.get('/api/ordens',async(req,res)=>{ try{ const r=await db.query(`SELECT os.*,s.telefone FROM ordens_servico os JOIN solicitantes s ON s.id=os.solicitante_id ORDER BY os.criado_em DESC LIMIT 100`); res.json(r.rows); }catch(e){res.status(500).json({erro:e.message});} });
app.patch('/api/ordens/:id/status',async(req,res)=>{ try{ await db.query('UPDATE ordens_servico SET status=$1 WHERE id=$2',[req.body.status,req.params.id]); res.json({ok:true}); }catch(e){res.status(500).json({erro:e.message});} });
app.get('/health',async(req,res)=>{
  const info={timestamp:new Date().toISOString(),uptime:Math.floor(process.uptime())+'s',memory:{rss:Math.round(process.memoryUsage().rss/1024/1024)+'MB',heapUsed:Math.round(process.memoryUsage().heapUsed/1024/1024)+'MB'}};
  try{ await db.query('SELECT 1'); info.banco='OK'; }catch(e){ return res.status(500).json({status:'ERRO_DB',erro:e.message,...info}); }
  if(process.env.WHATSAPP_API_URL){
    try{ await axios.get(`${process.env.WHATSAPP_API_URL}/instance/connectionState/${process.env.WHATSAPP_INSTANCE}`,{headers:{apikey:process.env.WHATSAPP_TOKEN},timeout:5000}); info.whatsapp='CONECTADO'; }
    catch(e){ info.whatsapp='DESCONECTADO'; info.whatsappErro=e.message; }
  } else { info.whatsapp='NAO_CONFIGURADO'; }
  res.json({status:'OK',...info});
});

app.get('/api/relatorio',async(req,res)=>{
  try{
    const [msgs,bols,oss,convs,ult24h]=await Promise.all([
      db.query(`SELECT direcao,COUNT(*)::int AS total FROM mensagens GROUP BY direcao`),
      db.query(`SELECT status,COUNT(*)::int AS total FROM boletins_ocorrencia GROUP BY status ORDER BY total DESC`),
      db.query(`SELECT status,COUNT(*)::int AS total FROM ordens_servico GROUP BY status ORDER BY total DESC`),
      db.query(`SELECT COUNT(*)::int AS total FROM conversas`),
      db.query(`SELECT COUNT(*)::int AS total FROM mensagens WHERE enviado_em>=NOW()-INTERVAL '24 hours'`)
    ]);
    const mensagens={}; msgs.rows.forEach(r=>mensagens[r.direcao]=r.total);
    res.json({geradoEm:new Date().toISOString(),uptime:Math.floor(process.uptime())+'s',conversasAtivas:convs.rows[0].total,mensagens,boletins:{porStatus:bols.rows},ordens:{porStatus:oss.rows},ultimasHoras24:{mensagens:ult24h.rows[0].total}});
  }catch(e){res.status(500).json({erro:e.message});}
});

app.get('/',(_,res)=>res.send('Bot de Atendimento - Online'));

const PORT=process.env.PORT||3000;
inicializarBanco().then(()=>app.listen(PORT,()=>console.log(`Porta ${PORT}`))).catch(e=>{console.error(e);process.exit(1);});
