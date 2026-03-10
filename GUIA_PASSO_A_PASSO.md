# Guia Único (Início ao Fim) — WhatsApp-ia

## Organograma da solução

```text
Usuário WhatsApp
   |
   v
Evolution API (Railway)
   |
   v
Webhook -> Backend Node (Render)
   |
   +--> Neon PostgreSQL (dados)
   |
   +--> Anthropic Claude (geração de texto)
```

## 1) Credenciais e padrões

Use este padrão para configuração inicial:

- AUTHENTICATION_API_KEY (Evolution): `Pmrhuan2013`
- WHATSAPP_TOKEN (Backend): `Pmrhuan2013`

Variáveis obrigatórias no Backend (Render):

```env
DATABASE_URL=postgresql://SEU_USUARIO:SUA_SENHA@SEU_HOST.neon.tech/neondb?sslmode=require
ANTHROPIC_API_KEY=sk-ant-COLE_SUA_CHAVE
WHATSAPP_API_URL=https://evolution-api-production-5d52.up.railway.app
WHATSAPP_INSTANCE=whatsapp-bot
WHATSAPP_TOKEN=Pmrhuan2013
PORT=3000
```

## 2) Subir Evolution API (Railway)

No serviço da Evolution, configure:

```env
AUTHENTICATION_API_KEY=Pmrhuan2013
SERVER_URL=${{RAILWAY_PUBLIC_DOMAIN}}
WEBSOCKET_ENABLED=true
CONFIG_SESSION_PHONE_CLIENT=Bot Atendimento
DATABASE_ENABLED=true
DATABASE_PROVIDER=postgresql
DATABASE_CONNECTION_URI=${{DATABASE_URL}}
DEL_INSTANCE=false
STORE_MESSAGES=true
STORE_MESSAGE_UP=true
STORE_CONTACTS=true
STORE_CHATS=true
CLEANUP_MESSAGES=true
```

## 3) Subir Backend (Render)

- Repositório: `Rhuan88/Whatsapp-ia`
- Root Directory: `backend`
- Build Command: `npm install`
- Start Command: `node server.js`
- Branch: `main`

Depois, em **Environment Variables**, adicionar todas as variáveis do item 1.

## 4) Conectar número do WhatsApp

1. Criar/usar instância `whatsapp-bot` na Evolution
2. Gerar QR Code
3. No celular do número oficial:
   - WhatsApp > Aparelhos conectados > Conectar aparelho
   - Escanear QR
4. Confirmar estado `open`

## 5) Configurar webhook

Webhook da instância deve ser:

`https://whatsapp-ia-qys2.onrender.com/webhook`

Evento:
- `MESSAGES_UPSERT`

## 6) Testes finais

### Health backend

`GET https://whatsapp-ia-qys2.onrender.com/health`

Esperado:
- `status: OK`
- `banco: OK`
- `whatsapp: CONECTADO`

### Teste funcional

Enviar no WhatsApp conectado:
- `menu`

Esperado: resposta do bot com menu principal.

## 7) Operação diária

- Render free pode “dormir” por inatividade.
- Railway e Render devem permanecer sem erro de deploy.
- Se parar resposta: validar `/health`, estado da instância e webhook.

## 8) Rotina de segurança

- Rotacionar chaves periodicamente.
- Nunca versionar `.env`.
- Em caso de exposição: regenerar credenciais imediatamente.
