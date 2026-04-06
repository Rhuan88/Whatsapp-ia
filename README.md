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

## Ativar WhatsApp

Após o deploy, conecte o número do WhatsApp ao bot:

### Linux/Mac:
```bash
cd scripts
./ativar-whatsapp.sh
```

### Windows:
```powershell
.\gerar-qr-code.ps1
```

O script irá:
1. Gerar o QR Code
2. Abrir no navegador automaticamente
3. Monitorar a conexão até confirmar

Escaneie o QR Code com o WhatsApp do celular que será usado como bot.

### Verificar Conexão

Para verificar se tudo está funcionando:

```bash
cd scripts
./verificar-conexao.sh
```

Este script verifica:
- Status do backend (Render)
- Status da conexão do WhatsApp (Evolution API)
- Configuração do webhook

## Observação de segurança

Nunca versionar `.env` e rotacionar credenciais após qualquer exposição.
