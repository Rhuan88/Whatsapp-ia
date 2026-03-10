# CHECKLIST UNIVERSAL DE ERROS/LOGS (PARA IA)

Use este checklist em qualquer incidente do projeto WhatsApp-ia.

## 0) Regra de triagem

Sempre coletar nesta ordem:
1. Mensagem de erro exata
2. Endpoint/ação que falhou
3. Últimos logs relevantes (20-100 linhas)
4. Estado do serviço (health)
5. Estado da integração WhatsApp (connectionState + webhook)

---

## 1) Saúde do backend (Render)

- Testar: `GET /health`
- Esperado:
  - `status: OK`
  - `banco: OK`
  - `whatsapp: CONECTADO` (ou motivo claro)

### Se falhar
- `ECONNREFUSED 127.0.0.1:5432`:
  - `DATABASE_URL` ausente ou inválida no Render.
- `status: ERRO_DB`:
  - credenciais Neon inválidas/expiradas.
- timeout/503:
  - serviço suspenso, dormindo ou deploy quebrado.

---

## 2) Logs de deploy (Render)

Verificar no log de deploy:
- Build:
  - `npm install` sem falhas
- Runtime:
  - `node server.js`
  - `Banco ok`
  - `Porta 3000`

### Se não aparecer "Banco ok"
- erro de conexão no PostgreSQL
- variáveis faltando

### Se iniciar e cair em loop
- exceção em inicialização
- variável inválida em runtime

---

## 3) Variáveis obrigatórias (Render)

Conferir existência e nome exato:
- `DATABASE_URL`
- `ANTHROPIC_API_KEY`
- `WHATSAPP_API_URL`
- `WHATSAPP_INSTANCE`
- `WHATSAPP_TOKEN`
- `PORT`

Erros comuns:
- nome errado (ex.: `DATABASEURL`)
- valor vazio
- espaços extras
- credencial antiga após rotação

---

## 4) Evolution API (Railway)

Checar:
- `instance/connectionState/<instancia>`
- `webhook/find/<instancia>`

Esperado:
- estado `open`
- webhook apontando para backend Render `/webhook`
- evento `MESSAGES_UPSERT`

### Se 401
- API key divergente (`AUTHENTICATION_API_KEY` vs backend token).

### Se `state` != `open`
- reconectar via QR Code.

---

## 5) Webhook ponta a ponta

Enviar payload de teste para `/webhook`.

Esperado:
- HTTP 200
- resposta do bot enviada ao número de origem

### Se 200 sem resposta no WhatsApp
- número/JID inválido
- instância desconectada
- token da Evolution inválido

---

## 6) Erros de IA (Anthropic)

- 401/403: chave inválida ou sem permissão
- 429: limite atingido
- timeout: rede/provedor instável

Ação:
- validar `ANTHROPIC_API_KEY`
- testar crédito/limites no painel Anthropic

---

## 7) Critério de encerramento do incidente

Só considerar resolvido quando:
- `/health` em OK
- instância WhatsApp em `open`
- webhook correto e ativo
- mensagem `menu` respondendo no WhatsApp real

---

## 8) Pós-incidente (obrigatório)

- Registrar causa raiz
- Registrar correção aplicada
- Atualizar documentação relevante
- Rotacionar credenciais se houve exposição
