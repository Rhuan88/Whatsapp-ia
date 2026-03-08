// ============================================================
// BOT WHATSAPP — SISTEMA DE REGISTROS OFICIAIS
// Otimizado para BM MOB (Brigada Militar RS)
// Backend Node.js — Deploy: Render.com + Neon PostgreSQL
// ============================================================

require('dotenv').config();
const crypto = require('crypto');
const express = require('express');
const rateLimit = require('express-rate-limit');
const { Pool } = require('pg');
const axios = require('axios');

const app = express();
app.use(express.json());

// ─── Banco de Dados ───────────────────────────────────────────
const db = new Pool(
  process.env.DATABASE_URL
    ? { connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } }
    : {
        host: process.env.DB_HOST || 'localhost',
        port: process.env.DB_PORT || 5432,
        database: process.env.DB_NAME || 'bot_ocorrencias',
        user: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASSWORD || 'senha',
      }
);

// ─── Inicializa Banco ─────────────────────────────────────────
async function inicializarBanco() {
  await db.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);

  await db.query(`CREATE TABLE IF NOT EXISTS solicitantes (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telefone    VARCHAR(20) UNIQUE NOT NULL,
    nome        VARCHAR(150),
    criado_em   TIMESTAMP DEFAULT NOW()
  )`);

  await db.query(`CREATE TABLE IF NOT EXISTS boletins_ocorrencia (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    protocolo        VARCHAR(30) UNIQUE NOT NULL,
    solicitante_id   UUID REFERENCES solicitantes(id),
    tipo_ocorrencia  VARCHAR(100) NOT NULL DEFAULT 'A CLASSIFICAR',
    relato_original  TEXT NOT NULL,
    documento_gerado TEXT NOT NULL,
    status           VARCHAR(30) DEFAULT 'REGISTRADO',
    criado_em        TIMESTAMP DEFAULT NOW()
  )`);

  await db.query(`CREATE TABLE IF NOT EXISTS ordens_servico (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero_os         VARCHAR(30) UNIQUE NOT NULL,
    solicitante_id    UUID REFERENCES solicitantes(id),
    tipo_servico      VARCHAR(100) NOT NULL,
    descricao_problema TEXT NOT NULL,
    documento_gerado  TEXT NOT NULL,
    status            VARCHAR(30) DEFAULT 'ABERTA',
    responsavel       VARCHAR(150),
    criado_em         TIMESTAMP DEFAULT NOW()
  )`);

  await db.query(`CREATE TABLE IF NOT EXISTS conversas (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telefone       VARCHAR(20) UNIQUE NOT NULL,
    estado_atual   VARCHAR(50) DEFAULT 'INICIO',
    contexto       JSONB DEFAULT '{}',
    ultima_msg     TIMESTAMP DEFAULT NOW()
  )`);

  await db.query(`CREATE TABLE IF NOT EXISTS mensagens (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telefone   VARCHAR(20) NOT NULL,
    direcao    VARCHAR(10) NOT NULL,
    conteudo   TEXT NOT NULL,
    enviado_em TIMESTAMP DEFAULT NOW()
  )`);

  await db.query(`
    CREATE OR REPLACE VIEW vw_historico AS
    SELECT s.telefone, 'BOLETIM' AS tipo,
           bo.protocolo AS numero, bo.tipo_ocorrencia AS categoria,
           bo.status, bo.criado_em AS data_registro
    FROM solicitantes s JOIN boletins_ocorrencia bo ON bo.solicitante_id = s.id
    UNION ALL
    SELECT s.telefone, 'ORDEM_SERVICO' AS tipo,
           os.numero_os AS numero, os.tipo_servico AS categoria,
           os.status, os.criado_em AS data_registro
    FROM solicitantes s JOIN ordens_servico os ON os.solicitante_id = s.id
  `);

  console.log('✅ Banco inicializado');
}

// ─── Helpers ──────────────────────────────────────────────────
const gerarProtocolo = () =>
  `BO-${new Date().getFullYear()}-${Math.floor(Math.random()*9999999).toString().padStart(7,'0')}`;

const gerarNumeroOS = () => {
  const d = new Date();
  return `OS-${d.getFullYear()}${String(d.getMonth()+1).padStart(2,'0')}-${Math.floor(Math.random()*99999).toString().padStart(5,'0')}`;
};

const dataHoraBR = () => new Date().toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' });

// ─── Estado de Conversa ───────────────────────────────────────
async function getConversa(telefone) {
  const r = await db.query('SELECT * FROM conversas WHERE telefone=$1', [telefone]);
  return r.rows[0] || null;
}

async function setEstado(telefone, estado, contexto = {}) {
  await db.query(
    `INSERT INTO conversas(telefone,estado_atual,contexto,ultima_msg)
     VALUES($1,$2,$3,NOW())
     ON CONFLICT(telefone) DO UPDATE
     SET estado_atual=$2, contexto=$3, ultima_msg=NOW()`,
    [telefone, estado, JSON.stringify(contexto)]
  );
}

async function getSolicitante(telefone) {
  let r = await db.query('SELECT * FROM solicitantes WHERE telefone=$1', [telefone]);
  if (r.rows[0]) return r.rows[0];
  r = await db.query('INSERT INTO solicitantes(telefone) VALUES($1) RETURNING *', [telefone]);
  return r.rows[0];
}

// ─── Claude API ───────────────────────────────────────────────
async function chamarClaude(system, user) {
  const r = await axios.post(
    'https://api.anthropic.com/v1/messages',
    {
      model: 'claude-sonnet-4-20250514',
      max_tokens: 2000,
      system,
      messages: [{ role: 'user', content: user }],
    },
    {
      headers: {
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
    }
  );
  return r.data.content[0].text;
}

// ─── PROMPT BO — otimizado para BM MOB ───────────────────────
function promptBO(protocolo) {
  return `Você é assistente especializado em registro de ocorrências policiais.
Com base no relato, gere um GUIA DE PREENCHIMENTO estruturado campo a campo,
na exata ordem das telas do sistema BM MOB (Brigada Militar do RS — PROCERGS/SIOSP).

REGRAS ABSOLUTAS:
- Relate APENAS os fatos narrados. Nunca adicione embasamento legal, artigos ou tipificações.
- Linguagem formal, objetiva, impessoal (terceira pessoa).
- Terminologia: "declarante", "comunicante", "locus delicti", "parte contrária", "autor do fato".
- Campos não informados: escreva exatamente "NÃO INFORMADO".
- Forma (Tentado/Consumado): CONSUMADO se o fato ocorreu plenamente; TENTADO se foi interrompido.
- Narrativa: máximo 500 caracteres por parágrafo (limite do BM MOB). Dividir se necessário.
- Ao final da narrativa, informe a contagem estimada de caracteres.

ESTRUTURA OBRIGATÓRIA — siga esta ordem exata:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 GUIA DE PREENCHIMENTO — BM MOB
Protocolo: ${protocolo}
Gerado em: {{DATA_HORA}}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔷 TELA 1 — DADOS GERAIS
┌──────────────────────────────────
│ Órgão de Registro : [inferir pela cidade/região — ex: BM · 1º BPM · Porto Alegre/RS]
│ Operação          : NÃO INFORMADO
│ Forma de Comunicação: [Rádio · Fone · Pessoal — inferir pelo relato]
│ Data/Hora Comunicação: [conforme relatado]
└──────────────────────────────────

🔷 TELA 2 — FATO
┌──────────────────────────────────
│ Natureza / Fato   : [identificar — ex: FURTO / ROUBO / LESÃO CORPORAL / DANO / etc.]
│ Forma             : [TENTADO / CONSUMADO]
│ Fatos Complementares: [agravantes ou contexto adicional — ou NÃO INFORMADO]
└──────────────────────────────────

🔷 TELA 3 — LOCAL DO FATO (locus delicti)
┌──────────────────────────────────
│ Cidade            : [conforme relatado]
│ UF                : [conforme relatado ou inferir]
│ Logradouro        : [rua/avenida conforme relatado]
│ Número            : [conforme relatado ou NÃO INFORMADO]
│ Bairro            : [conforme relatado]
│ Complemento       : [conforme relatado ou NÃO INFORMADO]
│ Tipo de Local     : [Via Pública / Residência / Comércio / Estacionamento / etc.]
│ Tipo Estabelecimento: [se aplicável ou NÃO INFORMADO]
└──────────────────────────────────

🔷 TELA 4 — PARTICIPANTES

  ► DECLARANTE / VÍTIMA
┌──────────────────────────────────
│ Participação      : VÍTIMA
│ Nome              : [conforme relatado]
│ RG                : [conforme relatado ou NÃO INFORMADO]
│ Data Nascimento   : [conforme relatado ou NÃO INFORMADO]
│ Nome da Mãe       : [conforme relatado ou NÃO INFORMADO]
│ Sexo              : [conforme relatado ou NÃO INFORMADO]
│ Nacionalidade     : [conforme relatado ou BRASILEIRO(A)]
│ End. Residencial  : [conforme relatado ou NÃO INFORMADO]
│ Telefone          : [conforme relatado ou NÃO INFORMADO]
│ Condição Física   : [ILESA / FERIDA / MORTA — conforme relatado]
│ Local Atendimento : [conforme relatado ou NÃO INFORMADO]
└──────────────────────────────────

  ► AUTOR / SUSPEITO
┌──────────────────────────────────
│ Participação      : AUTOR
│ Nome              : [conforme relatado ou NÃO INFORMADO]
│ RG                : [conforme relatado ou NÃO INFORMADO]
│ Características   : [conforme relatado — cor pele, cabelo, estatura, roupas, etc.]
│ Alcunha           : [conforme relatado ou NÃO INFORMADO]
└──────────────────────────────────

  ► TESTEMUNHA 1 (se informado)
┌──────────────────────────────────
│ Nome              : [conforme relatado ou NÃO INFORMADO]
│ Endereço          : [conforme relatado ou NÃO INFORMADO]
│ RG                : [conforme relatado ou NÃO INFORMADO]
│ Telefone          : [conforme relatado ou NÃO INFORMADO]
└──────────────────────────────────

🔷 TELA 5 — HISTÓRICO / NARRATIVA
┌──────────────────────────────────
│ ⚠️  Limite BM MOB: 500 caracteres por campo. Dividir em parágrafos se necessário.
│
│ Narrativa (Parte 1):
│ [Relato em 3ª pessoa, formal, somente os fatos narrados. Sem embasamento legal.]
│
│ Narrativa (Parte 2 — se necessário):
│ [Continuação]
│
│ Caracteres estimados: [informar contagem total]
└──────────────────────────────────

🔷 TELA 6 — OBJETOS / DOCUMENTOS
┌──────────────────────────────────
│ Objetos / Bens Subtraídos: [conforme relatado ou NÃO INFORMADO]
│ Veículos Envolvidos      : [conforme relatado ou NÃO INFORMADO]
│ Armas Envolvidas         : [conforme relatado ou NÃO INFORMADO]
│ Outros Órgãos Acionados  : [SAMU / Bombeiros / PC / etc. — ou NÃO INFORMADO]
└──────────────────────────────────

🔷 ASSINATURA (preencher presencialmente no BM MOB)
┌──────────────────────────────────
│ Policial Atendente : _______________________________
│ Matrícula          : _______________________________
└──────────────────────────────────`;
}

// ─── PROMPT OS — campo a campo ────────────────────────────────
function promptOS(numeroOS, tipoServico) {
  const hoje = new Date().toLocaleDateString('pt-BR');
  return `Você é assistente especializado em gestão e registro de ordens de serviço.
Com base na solicitação, gere um documento estruturado campo a campo para preenchimento
em sistema administrativo interno.

REGRAS ABSOLUTAS:
- Descreva APENAS o que foi relatado. Sem diagnósticos técnicos ou embasamentos normativos.
- Linguagem formal, objetiva, impessoal (terceira pessoa).
- Terminologia: "solicitante", "local de intervenção", "natureza do problema", "serviço demandado".
- Campos não informados: escreva "NÃO INFORMADO".
- Prioridade URGENTE: quando houver risco, "sem energia", "vazamento", "acidente" ou urgência explícita.
- Prioridade ALTA: problema impactando funcionamento sem risco imediato.
- Prioridade NORMAL: solicitação rotineira sem impacto crítico.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 ORDEM DE SERVIÇO
Número OS : ${numeroOS}
Abertura  : ${hoje}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔷 BLOCO 1 — IDENTIFICAÇÃO
┌──────────────────────────────────
│ Número OS         : ${numeroOS}
│ Data de Abertura  : ${hoje}
│ Tipo de Serviço   : ${tipoServico}
│ Prioridade        : [URGENTE / ALTA / NORMAL — inferir pelo relato]
└──────────────────────────────────

🔷 BLOCO 2 — SOLICITANTE
┌──────────────────────────────────
│ Nome / Razão Social: [conforme relatado ou NÃO INFORMADO]
│ Cargo / Função    : [conforme relatado ou NÃO INFORMADO]
│ Setor / Depto     : [conforme relatado ou NÃO INFORMADO]
│ Telefone Contato  : [conforme relatado ou NÃO INFORMADO]
└──────────────────────────────────

🔷 BLOCO 3 — LOCAL DE INTERVENÇÃO
┌──────────────────────────────────
│ Endereço / Local  : [conforme relatado]
│ Setor / Andar     : [conforme relatado ou NÃO INFORMADO]
│ Sala / Área       : [conforme relatado ou NÃO INFORMADO]
│ Ponto Referência  : [conforme relatado ou NÃO INFORMADO]
└──────────────────────────────────

🔷 BLOCO 4 — DESCRIÇÃO DO PROBLEMA
┌──────────────────────────────────
│ Natureza do Problema:
│ [Descrever em terceira pessoa somente o que foi narrado.
│  Sem diagnóstico técnico ou prescrição de solução.]
│
│ Quando Iniciou    : [conforme relatado ou NÃO INFORMADO]
│ Tentativa Anterior: [Sim / Não / NÃO INFORMADO]
│ Risco Imediato    : [Sim / Não — inferir pelo relato]
└──────────────────────────────────

🔷 BLOCO 5 — SERVIÇO DEMANDADO
┌──────────────────────────────────
│ Serviço Solicitado:
│ [O que o solicitante pede que seja feito — sem prescrever solução técnica]
│
│ Materiais Mencionados: [conforme relatado ou NÃO INFORMADO]
│ Equipamentos Envolvidos: [conforme relatado ou NÃO INFORMADO]
└──────────────────────────────────

🔷 BLOCO 6 — EXECUÇÃO ✏️ (preencher pelo técnico)
┌──────────────────────────────────
│ Responsável Técnico : ________________________________
│ Data Atendimento    : ________________________________
│ Data Conclusão      : ________________________________
│ Status              : [ ] ABERTA  [ ] EM ANDAMENTO  [ ] CONCLUÍDA
│ Observações         : ________________________________
└──────────────────────────────────

🔷 ASSINATURA ✏️ (preencher presencialmente)
┌──────────────────────────────────
│ Solicitante  : ____________________  Data: __________
│ Responsável  : ____________________  Data: __________
└──────────────────────────────────`;
}

// ─── Gerar Boletim ────────────────────────────────────────────
async function gerarBO(relato, solicitanteId, protocolo) {
  const system = promptBO(protocolo).replace('{{DATA_HORA}}', dataHoraBR());
  const documento = await chamarClaude(system, `Relato do declarante:\n\n${relato}`);

  await db.query(
    `INSERT INTO boletins_ocorrencia
     (protocolo,solicitante_id,tipo_ocorrencia,relato_original,documento_gerado)
     VALUES($1,$2,$3,$4,$5)`,
    [protocolo, solicitanteId, 'A CLASSIFICAR', relato, documento]
  );
  return documento;
}

// ─── Gerar Ordem de Serviço ───────────────────────────────────
async function gerarOS(descricao, solicitanteId, numeroOS, tipoServico) {
  const system = promptOS(numeroOS, tipoServico);
  const documento = await chamarClaude(
    system, `Tipo: ${tipoServico}\n\nDescrição do solicitante:\n\n${descricao}`
  );

  await db.query(
    `INSERT INTO ordens_servico
     (numero_os,solicitante_id,tipo_servico,descricao_problema,documento_gerado)
     VALUES($1,$2,$3,$4,$5)`,
    [numeroOS, solicitanteId, tipoServico, descricao, documento]
  );
  return documento;
}

// ─── Histórico ────────────────────────────────────────────────
async function consultarHistorico(telefone) {
  const r = await db.query(
    `SELECT tipo,numero,categoria,status,data_registro
     FROM vw_historico WHERE telefone=$1
     ORDER BY data_registro DESC LIMIT 10`,
    [telefone]
  );

  if (!r.rows.length)
    return '📋 Nenhum registro encontrado.\n\nDigite *menu* para voltar.';

  let msg = '📋 *Seu Histórico de Registros:*\n\n';
  r.rows.forEach(row => {
    const icon = row.tipo === 'BOLETIM' ? '🚔' : '🔧';
    const label = row.tipo === 'BOLETIM' ? 'Boletim' : 'Ordem de Serviço';
    const data = new Date(row.data_registro).toLocaleDateString('pt-BR');
    msg += `${icon} *${label}*\n`;
    msg += `   Nº: \`${row.numero}\`\n`;
    msg += `   Tipo: ${row.categoria}\n`;
    msg += `   Status: *${row.status}*\n`;
    msg += `   Data: ${data}\n\n`;
  });
  return msg + `_Digite *menu* para voltar._`;
}

// ─── Busca por protocolo ──────────────────────────────────────
async function buscarProtocolo(telefone, num) {
  // Busca BO
  let r = await db.query(
    `SELECT bo.*,s.telefone FROM boletins_ocorrencia bo
     JOIN solicitantes s ON s.id=bo.solicitante_id
     WHERE bo.protocolo=$1 AND s.telefone=$2`,
    [num, telefone]
  );
  if (r.rows[0]) {
    const bo = r.rows[0];
    return (
      `🚔 *Boletim Encontrado*\n\n` +
      `Protocolo: *${bo.protocolo}*\n` +
      `Status: *${bo.status}*\n` +
      `Registrado: ${new Date(bo.criado_em).toLocaleDateString('pt-BR')}\n\n` +
      `━━━━━━━━━━━━━━━━━━━━\n\n${bo.documento_gerado}\n\n` +
      `Digite *menu* para voltar.`
    );
  }

  // Busca OS
  r = await db.query(
    `SELECT os.*,s.telefone FROM ordens_servico os
     JOIN solicitantes s ON s.id=os.solicitante_id
     WHERE os.numero_os=$1 AND s.telefone=$2`,
    [num, telefone]
  );
  if (r.rows[0]) {
    const os = r.rows[0];
    return (
      `🔧 *Ordem de Serviço Encontrada*\n\n` +
      `Número: *${os.numero_os}*\n` +
      `Tipo: *${os.tipo_servico}*\n` +
      `Status: *${os.status}*\n` +
      `Registrado: ${new Date(os.criado_em).toLocaleDateString('pt-BR')}\n\n` +
      `━━━━━━━━━━━━━━━━━━━━\n\n${os.documento_gerado}\n\n` +
      `Digite *menu* para voltar.`
    );
  }

  return '❌ Protocolo não encontrado ou não pertence a este número.\n\nDigite *menu* para voltar.';
}

// ─── Menu Principal ───────────────────────────────────────────
function menuPrincipal() {
  return (
    `🏛️ *Sistema de Registros Oficiais*\n` +
    `_BM MOB · Brigada Militar RS_\n\n` +
    `O que deseja fazer?\n\n` +
    `1️⃣ Gerar guia de BO para BM MOB\n` +
    `2️⃣ Gerar Ordem de Serviço\n` +
    `3️⃣ Consultar meu histórico\n` +
    `4️⃣ Buscar por Protocolo / Nº OS\n\n` +
    `_O documento gerado mostra cada campo na ordem\nexata das telas do BM MOB._\n\n` +
    `_Digite o número da opção._`
  );
}

// ─── Processamento Central ────────────────────────────────────
async function processarMensagem(telefone, mensagem) {
  const texto = mensagem.trim().toLowerCase();
  const conversa = await getConversa(telefone);
  const estado = conversa?.estado_atual || 'INICIO';
  const contexto = conversa?.contexto || {};

  // Log entrada
  await db.query(
    'INSERT INTO mensagens(telefone,direcao,conteudo) VALUES($1,$2,$3)',
    [telefone, 'ENTRADA', mensagem]
  ).catch(() => {});

  // Reset
  const resetWords = ['menu','inicio','oi','olá','ola','0','cancelar','voltar','start'];
  if (resetWords.includes(texto)) {
    await setEstado(telefone, 'MENU', {});
    return menuPrincipal();
  }

  // ── MENU ──────────────────────────────────────────────────
  if (estado === 'INICIO' || estado === 'MENU') {
    if (texto === '1') {
      await setEstado(telefone, 'BO_RELATO', {});
      return (
        `🚔 *Gerar Guia de BO — BM MOB*\n\n` +
        `Para gerar o guia completo campo a campo, informe:\n\n` +
        `1️⃣ *O que aconteceu?*\n` +
        `2️⃣ *Quando?* (data e hora)\n` +
        `3️⃣ *Onde?* (rua, nº, bairro, cidade)\n` +
        `4️⃣ *Seus dados:* nome, RG, telefone\n` +
        `5️⃣ *Autor/suspeito* (se souber: nome, características físicas)\n` +
        `6️⃣ *Testemunhas* (nome e contato, se houver)\n` +
        `7️⃣ *Objetos, veículos ou armas* envolvidos (se houver)\n\n` +
        `_Relate livremente. O guia será gerado na ordem das telas do BM MOB._\n\n` +
        `📌 Digite *0* para cancelar.`
      );
    }

    if (texto === '2') {
      await setEstado(telefone, 'OS_TIPO', {});
      return (
        `🔧 *Gerar Ordem de Serviço*\n\n` +
        `Selecione o tipo de serviço:\n\n` +
        `1️⃣ Elétrico\n` +
        `2️⃣ Hidráulico\n` +
        `3️⃣ Manutenção Geral\n` +
        `4️⃣ Limpeza / Conservação\n` +
        `5️⃣ Estrutural / Civil\n` +
        `6️⃣ Outro\n\n` +
        `Digite o número:`
      );
    }

    if (texto === '3') return await consultarHistorico(telefone);

    if (texto === '4') {
      await setEstado(telefone, 'BUSCA', {});
      return `🔍 Digite o número do protocolo (BO-...) ou da OS (OS-...):`;
    }

    return menuPrincipal();
  }

  // ── BO — RELATO ────────────────────────────────────────────
  if (estado === 'BO_RELATO') {
    if (mensagem.length < 20)
      return `⚠️ Forneça mais detalhes sobre o ocorrido para gerar o guia completo.`;

    const s = await getSolicitante(telefone);
    const protocolo = gerarProtocolo();

    const documento = await gerarBO(mensagem, s.id, protocolo);
    await setEstado(telefone, 'MENU', {});

    return (
      `✅ *Guia de BO Gerado*\n\n` +
      `📋 *Protocolo: ${protocolo}*\n\n` +
      `━━━━━━━━━━━━━━━━━━━━\n\n` +
      `${documento}\n\n` +
      `━━━━━━━━━━━━━━━━━━━━\n\n` +
      `📌 _Abra o BM MOB e preencha cada campo conforme o guia acima, tela por tela._\n\n` +
      `Digite *menu* para voltar.`
    );
  }

  // ── OS — TIPO ──────────────────────────────────────────────
  if (estado === 'OS_TIPO') {
    const tipos = {
      '1': 'ELÉTRICO',
      '2': 'HIDRÁULICO',
      '3': 'MANUTENÇÃO GERAL',
      '4': 'LIMPEZA / CONSERVAÇÃO',
      '5': 'ESTRUTURAL / CIVIL',
      '6': 'OUTRO',
    };
    const tipo = tipos[texto];
    if (!tipo) return `⚠️ Opção inválida. Digite um número de 1 a 6:`;

    await setEstado(telefone, 'OS_DESC', { tipoServico: tipo });
    return (
      `🔧 *Serviço: ${tipo}*\n\n` +
      `Para gerar o guia completo, informe:\n\n` +
      `1️⃣ *Qual o problema?* (descreva o que está ocorrendo)\n` +
      `2️⃣ *Onde?* (endereço, setor, andar, sala)\n` +
      `3️⃣ *Seu nome, cargo e telefone*\n` +
      `4️⃣ *Quando começou?*\n` +
      `5️⃣ *Há urgência ou risco imediato?*\n` +
      `6️⃣ *Já houve tentativa de solução?*\n\n` +
      `_Relate livremente._`
    );
  }

  // ── OS — DESCRIÇÃO ─────────────────────────────────────────
  if (estado === 'OS_DESC') {
    if (mensagem.length < 20)
      return `⚠️ Forneça mais detalhes para gerar a ordem de serviço.`;

    const s = await getSolicitante(telefone);
    const numeroOS = gerarNumeroOS();
    const tipo = contexto.tipoServico || 'GERAL';

    const documento = await gerarOS(mensagem, s.id, numeroOS, tipo);
    await setEstado(telefone, 'MENU', {});

    return (
      `✅ *Ordem de Serviço Gerada*\n\n` +
      `🔧 *Número: ${numeroOS}*\n\n` +
      `━━━━━━━━━━━━━━━━━━━━\n\n` +
      `${documento}\n\n` +
      `━━━━━━━━━━━━━━━━━━━━\n\n` +
      `📌 _Guarde o número: *${numeroOS}*_\n\n` +
      `Digite *menu* para voltar.`
    );
  }

  // ── BUSCA ──────────────────────────────────────────────────
  if (estado === 'BUSCA') {
    const num = mensagem.trim().toUpperCase();
    const resultado = await buscarProtocolo(telefone, num);
    await setEstado(telefone, 'MENU', {});
    return resultado;
  }

  await setEstado(telefone, 'MENU', {});
  return menuPrincipal();
}

// ─── Webhook ──────────────────────────────────────────────────
app.post('/webhook', async (req, res) => {
  try {
    const body = req.body;
    let telefone, mensagem;

    // Evolution API
    if (body.data?.key?.remoteJid) {
      telefone = body.data.key.remoteJid.replace('@s.whatsapp.net', '');
      mensagem = body.data.message?.conversation
              || body.data.message?.extendedTextMessage?.text || '';
    }
    // Z-API
    else if (body.phone && body.text) {
      telefone = body.phone;
      mensagem = body.text?.message || '';
    }
    // WPPConnect
    else if (body.from && body.body) {
      telefone = body.from.replace('@c.us', '');
      mensagem = body.body;
    }

    if (!telefone || !mensagem) return res.sendStatus(200);

    const resposta = await processarMensagem(telefone, mensagem);
    await enviarMensagem(telefone, resposta);

    res.sendStatus(200);
  } catch (err) {
    console.error('❌ Webhook error:', err.message);
    res.sendStatus(500);
  }
});

// ─── Envio WhatsApp ───────────────────────────────────────────
async function enviarMensagem(telefone, mensagem) {
  if (!process.env.WHATSAPP_API_URL) {
    // Modo dev: exibir no console
    console.log(`\n[→ ${telefone}]:\n${mensagem.substring(0, 120)}...\n`);
    return;
  }
  try {
    await axios.post(
      `${process.env.WHATSAPP_API_URL}/message/sendText/${process.env.WHATSAPP_INSTANCE}`,
      { number: telefone, text: mensagem },
      { headers: { apikey: process.env.WHATSAPP_TOKEN } }
    );
  } catch (err) {
    console.error('Erro envio WhatsApp:', err.message);
  }
}

// ─── Autenticação do Painel Admin ────────────────────────────
const adminRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
});

function autenticarAdmin(req, res, next) {
  const adminToken = process.env.ADMIN_TOKEN;
  if (!adminToken) {
    return res.status(500).json({ erro: 'ADMIN_TOKEN não configurado no servidor.' });
  }
  const authHeader = req.headers['authorization'] || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : authHeader;
  let igual = false;
  try {
    igual = token.length === adminToken.length &&
      crypto.timingSafeEqual(Buffer.from(token), Buffer.from(adminToken));
  } catch (_) {
    igual = false;
  }
  if (!igual) {
    return res.status(401).json({ erro: 'Não autorizado.' });
  }
  next();
}

// ─── REST API para painel admin ───────────────────────────────
app.get('/api/boletins', adminRateLimit, autenticarAdmin, async (req, res) => {
  try {
    const { status } = req.query;
    let q = `SELECT bo.*,s.telefone FROM boletins_ocorrencia bo
             JOIN solicitantes s ON s.id=bo.solicitante_id`;
    const p = [];
    if (status) { q += ` WHERE bo.status=$1`; p.push(status); }
    q += ' ORDER BY bo.criado_em DESC LIMIT 100';
    res.json((await db.query(q, p)).rows);
  } catch (e) { res.status(500).json({ erro: e.message }); }
});

app.get('/api/ordens', adminRateLimit, autenticarAdmin, async (req, res) => {
  try {
    const { status } = req.query;
    let q = `SELECT os.*,s.telefone FROM ordens_servico os
             JOIN solicitantes s ON s.id=os.solicitante_id`;
    const p = [];
    if (status) { q += ` WHERE os.status=$1`; p.push(status); }
    q += ' ORDER BY os.criado_em DESC LIMIT 100';
    res.json((await db.query(q, p)).rows);
  } catch (e) { res.status(500).json({ erro: e.message }); }
});

app.patch('/api/ordens/:id/status', adminRateLimit, autenticarAdmin, async (req, res) => {
  try {
    const { status, responsavel } = req.body;
    await db.query(
      'UPDATE ordens_servico SET status=$1,responsavel=$2 WHERE id=$3',
      [status, responsavel, req.params.id]
    );
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ erro: e.message }); }
});

app.patch('/api/boletins/:id/status', adminRateLimit, autenticarAdmin, async (req, res) => {
  try {
    await db.query(
      'UPDATE boletins_ocorrencia SET status=$1 WHERE id=$2',
      [req.body.status, req.params.id]
    );
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ erro: e.message }); }
});

// ─── Health & Root ────────────────────────────────────────────
app.get('/health', async (req, res) => {
  try {
    await db.query('SELECT 1');
    res.json({ status: 'OK', uptime: Math.floor(process.uptime()) + 's' });
  } catch {
    res.status(500).json({ status: 'ERRO_DB' });
  }
});

app.get('/', (_, res) =>
  res.send('🏛️ Bot Registros Oficiais — BM MOB · Online')
);

// ─── Start ────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
inicializarBanco()
  .then(() => app.listen(PORT, () =>
    console.log(`\n🚀 Servidor na porta ${PORT}\n📡 Webhook: POST /webhook\n❤️  Health:  GET /health\n`)
  ))
  .catch(err => { console.error('❌ Erro ao iniciar:', err); process.exit(1); });
