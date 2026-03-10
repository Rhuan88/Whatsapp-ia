# Manual para IA Refazer Tudo sem Erro

## Organograma de execução (para qualquer IA)

```text
[1] Validar repositório e branch main
        |
        v
[2] Validar variáveis (Render + Railway)
        |
        v
[3] Validar deploy backend (Render)
        |
        v
[4] Validar Evolution (Railway) + conexão WhatsApp
        |
        v
[5] Validar webhook + teste ponta a ponta
        |
        v
[6] Fechar com checklist de produção
```

## Procedimento determinístico

### Etapa A — Backend (Render)

1. Confirmar serviço Node com:
   - Build: `npm install`
   - Start: `node server.js`
   - Root: `backend`
2. Confirmar variáveis:

```env
DATABASE_URL=postgresql://SEU_USUARIO:SUA_SENHA@SEU_HOST.neon.tech/neondb?sslmode=require
ANTHROPIC_API_KEY=sk-ant-COLE_SUA_CHAVE
WHATSAPP_API_URL=https://evolution-api-production-5d52.up.railway.app
WHATSAPP_INSTANCE=whatsapp-bot
WHATSAPP_TOKEN=Pmrhuan2013
PORT=3000
```

3. Executar deploy manual.
4. Validar `GET /health`.

### Etapa B — Evolution (Railway)

1. Confirmar variáveis essenciais:

```env
AUTHENTICATION_API_KEY=Pmrhuan2013
SERVER_URL=${{RAILWAY_PUBLIC_DOMAIN}}
DATABASE_ENABLED=true
DATABASE_PROVIDER=postgresql
DATABASE_CONNECTION_URI=${{DATABASE_URL}}
```

2. Garantir instância `whatsapp-bot`.
3. Conectar número via QR até estado `open`.

### Etapa C — Integração

1. Ajustar webhook para:
   - `https://whatsapp-ia-qys2.onrender.com/webhook`
2. Eventos:
   - `MESSAGES_UPSERT`
3. Testar webhook com payload de mensagem.
4. Testar conversa real com `menu`.

## Critérios de sucesso

- Render `/health` com `status: OK`
- `banco: OK`
- `whatsapp: CONECTADO`
- `webhook.find` retornando URL do Render
- mensagem real no WhatsApp com resposta do bot

## Plano de correção rápida (fallback)

1. Se `ECONNREFUSED 127.0.0.1:5432`:
   - `DATABASE_URL` ausente/incorreta no Render.
2. Se 401 na Evolution:
   - token divergente entre backend e Evolution.
3. Se sem resposta no WhatsApp:
   - estado da instância diferente de `open` ou webhook incorreto.

## Padrão de credencial inicial solicitado

- Senha padrão operacional: `Pmrhuan2013`
- Aplicar em:
  - `AUTHENTICATION_API_KEY` (Evolution)
  - `WHATSAPP_TOKEN` (Backend)

> Após estabilizar, recomenda-se trocar por credenciais fortes e únicas.
