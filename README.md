# Whatsapp-ia

Projeto de atendimento via WhatsApp com backend Node.js, Evolution API, Neon PostgreSQL e Claude.

## Documentação oficial (única)

- `GUIA_PASSO_A_PASSO.md` → execução completa do início ao fim.
- `MANUAL_IA_REFAZER.md` → manual técnico para qualquer IA reproduzir sem erro.

## Estrutura principal

- `backend/` → aplicação Node.js (webhook, APIs, banco, IA)
- `render.yaml` → configuração de deploy no Render
- `railway-env-vars.txt` → variáveis base da Evolution no Railway
- `scripts/` → utilitários de operação

## Deploy

- Backend: Render (`backend`, build `npm install`, start `node server.js`)
- Evolution API: Railway

## Observação de segurança

Nunca versionar `.env` e rotacionar credenciais após qualquer exposição.
