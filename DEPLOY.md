# 🚀 DEPLOY COMPLETO — BM MOB Bot

## Visão Geral

```
GitHub ──► Render.com (backend Node.js)
                │
                ├── Neon.tech (PostgreSQL gratuito)
                ├── Anthropic API (Claude)
                └── WhatsApp API (Evolution API / Z-API)
```

---

## PASSO 1 — GitHub

```bash
git init
git add .
git commit -m "BM MOB Bot v1"
git remote add origin https://github.com/SEU_USUARIO/bmmob-bot.git
git push -u origin main
```

---

## PASSO 2 — Banco de Dados (Neon.tech)

1. Acesse **https://neon.tech** → criar conta gratuita
2. Criar projeto → região **South America (São Paulo)**
3. Copiar a **Connection String**:
   ```
   postgresql://usuario:senha@ep-xxx.sa-east-1.aws.neon.tech/nomedb?sslmode=require
   ```
4. Guardar — será usada no Render

> ✅ O bot cria todas as tabelas automaticamente na primeira execução

---

## PASSO 3 — Deploy (Render.com)

1. Acesse **https://render.com** → criar conta gratuita
2. **New → Web Service → Connect GitHub**
3. Selecionar o repositório `bmmob-bot`
4. Configurar:
   - **Root Directory:** `backend`
   - **Build Command:** `npm install`
   - **Start Command:** `node server.js`
   - **Plan:** Free

5. Em **Environment Variables**, adicionar:

| Variável | Valor |
|---|---|
| `DATABASE_URL` | (string do Neon.tech) |
| `ANTHROPIC_API_KEY` | `sk-ant-...` |
| `WHATSAPP_API_URL` | URL da sua Evolution API |
| `WHATSAPP_INSTANCE` | nome da instância |
| `WHATSAPP_TOKEN` | token da API |

6. **Create Web Service** → aguardar deploy (~3 min)
7. Copiar a URL gerada: `https://bmmob-bot.onrender.com`

---

## PASSO 4 — WhatsApp (Evolution API)

### Opção A — Docker (VPS próprio)
```bash
docker run -d \
  --name evolution-api \
  -p 8080:8080 \
  -e AUTHENTICATION_API_KEY=meu_token_secreto \
  atendai/evolution-api:latest
```

Criar instância:
```bash
curl -X POST http://SEU_IP:8080/instance/create \
  -H "apikey: meu_token_secreto" \
  -H "Content-Type: application/json" \
  -d '{"instanceName":"bmmob","qrcode":true}'
```

Configurar webhook:
```bash
curl -X POST http://SEU_IP:8080/webhook/set/bmmob \
  -H "apikey: meu_token_secreto" \
  -H "Content-Type: application/json" \
  -d '{
    "webhook": {
      "enabled": true,
      "url": "https://bmmob-bot.onrender.com/webhook",
      "events": ["MESSAGES_UPSERT"]
    }
  }'
```

### Opção B — Z-API (sem servidor, pago)
- https://z-api.io → criar instância
- Webhook → apontar para `https://bmmob-bot.onrender.com/webhook`

---

## PASSO 5 — Manter Render Acordado (UptimeRobot)

O plano gratuito do Render dorme após 15min sem requisições.

1. Acesse **https://uptimerobot.com** → conta gratuita
2. **Add New Monitor:**
   - Type: **HTTP(S)**
   - URL: `https://bmmob-bot.onrender.com/health`
   - Interval: **5 minutes**
3. Salvar → o bot ficará acordado 24/7

---

## PASSO 6 — Verificar

```bash
# Health check
curl https://bmmob-bot.onrender.com/health

# Listar boletins
curl https://bmmob-bot.onrender.com/api/boletins

# Listar ordens
curl https://bmmob-bot.onrender.com/api/ordens
```

---

## Fluxo do Bot no WhatsApp

```
Usuário: oi
Bot: Menu → 1=Gerar guia BO / 2=OS / 3=Histórico / 4=Buscar

Usuário: 1
Bot: Solicita relato completo

Usuário: [relato livre com todos os detalhes]
Bot: Gera guia campo a campo na ordem das telas do BM MOB:
     TELA 1 · TELA 2 · TELA 3 · TELA 4 · TELA 5 · TELA 6
     Protocolo: BO-2025-XXXXXXX

Usuário: Abre o BM MOB e preenche tela por tela ✅
```

---

## Custos (tudo gratuito)

| Serviço | Plano | Custo |
|---|---|---|
| Render.com | Free | R$ 0 |
| Neon.tech | Free Tier (3GB) | R$ 0 |
| Anthropic API | Pago por uso | ~R$ 0,01/BO |
| Evolution API | Self-hosted | R$ 0 |
| UptimeRobot | Free (50 monitors) | R$ 0 |

---

## Reset de palavras

O usuário pode digitar a qualquer momento:
- `menu` `oi` `olá` `start` `0` `cancelar` `voltar`
