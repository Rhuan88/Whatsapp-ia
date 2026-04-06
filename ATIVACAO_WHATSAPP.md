# Guia de Ativação do WhatsApp Bot

Este guia explica como ativar e conectar o número do WhatsApp ao bot.

## Pré-requisitos

Antes de ativar o WhatsApp, certifique-se que:

✅ Backend está deployado no Render e rodando
✅ Evolution API está deployada no Railway
✅ Variáveis de ambiente configuradas corretamente
✅ Webhook configurado para apontar ao backend

## Passo a Passo

### 1. Verificar se os serviços estão online

```bash
# Verificar backend
curl https://whatsapp-ia-qys2.onrender.com/health

# Deve retornar: {"status":"OK","banco":"OK",...}
```

### 2. Ativar WhatsApp

#### No Linux/Mac:

```bash
cd scripts
./ativar-whatsapp.sh
```

#### No Windows:

```powershell
.\gerar-qr-code.ps1
```

#### Sem acesso aos scripts:

Use curl diretamente:

```bash
# Gerar QR Code
curl -H "apikey: Pmrhuan2013" \
  https://evolution-api-production-5d52.up.railway.app/instance/connect/whatsapp-bot

# O retorno conterá o QR Code em base64
```

### 3. Escanear QR Code

1. Abra o WhatsApp no celular
2. Vá em **Menu (⋮)** → **Aparelhos conectados**
3. Toque em **Conectar um aparelho**
4. Escaneie o QR Code exibido
5. Aguarde a confirmação

### 4. Verificar Conexão

```bash
# Verificar estado da conexão
curl -H "apikey: Pmrhuan2013" \
  https://evolution-api-production-5d52.up.railway.app/instance/connectionState/whatsapp-bot

# Deve retornar: {"state":"open"} ou {"instance":{"state":"open"}}
```

Ou verifique o health do backend:

```bash
curl https://whatsapp-ia-qys2.onrender.com/health

# Deve retornar: {...,"whatsapp":"CONECTADO"}
```

### 5. Testar o Bot

Envie uma mensagem de qualquer número para o WhatsApp conectado:

```
menu
```

Você deve receber:

```
🏛️ Sistema de Registros Oficiais

1️⃣ Gerar guia de Boletim de Ocorrência
2️⃣ Gerar Ordem de Serviço
3️⃣ Consultar histórico
4️⃣ Buscar por Protocolo/OS

Digite o número da opção.
```

## Solução de Problemas

### QR Code expirou

- QR Codes expiram em 60 segundos
- Execute o script novamente para gerar novo QR

### "Instância não encontrada"

```bash
# Criar instância manualmente
curl -X POST \
  -H "apikey: Pmrhuan2013" \
  -H "Content-Type: application/json" \
  -d '{"instanceName":"whatsapp-bot","qrcode":true}' \
  https://evolution-api-production-5d52.up.railway.app/instance/create
```

### WhatsApp desconecta sozinho

1. Verifique se o celular está com internet estável
2. Verifique se não há outros dispositivos conectados ao mesmo número
3. Reconecte usando o script de ativação

### Webhook não funciona

```bash
# Verificar configuração do webhook
curl -H "apikey: Pmrhuan2013" \
  https://evolution-api-production-5d52.up.railway.app/webhook/find/whatsapp-bot

# Configurar webhook (se necessário)
curl -X POST \
  -H "apikey: Pmrhuan2013" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://whatsapp-ia-qys2.onrender.com/webhook",
    "events": ["MESSAGES_UPSERT"],
    "enabled": true
  }' \
  https://evolution-api-production-5d52.up.railway.app/webhook/set/whatsapp-bot
```

## Reativar WhatsApp

Se o WhatsApp desconectar, basta executar novamente o script de ativação:

```bash
# Linux/Mac
cd scripts
./ativar-whatsapp.sh

# Windows
.\gerar-qr-code.ps1
```

## Comandos Úteis

### Ver logs da instância
```bash
curl -H "apikey: Pmrhuan2013" \
  https://evolution-api-production-5d52.up.railway.app/instance/fetchInstances
```

### Desconectar WhatsApp
```bash
curl -X DELETE \
  -H "apikey: Pmrhuan2013" \
  https://evolution-api-production-5d52.up.railway.app/instance/logout/whatsapp-bot
```

### Deletar instância
```bash
curl -X DELETE \
  -H "apikey: Pmrhuan2013" \
  https://evolution-api-production-5d52.up.railway.app/instance/delete/whatsapp-bot
```

## Segurança

⚠️ **IMPORTANTE:**

- Nunca compartilhe o QR Code com terceiros
- O QR Code dá acesso completo ao WhatsApp
- Rotacione a `AUTHENTICATION_API_KEY` periodicamente
- Mantenha as credenciais em ambiente seguro
- Nunca commite arquivos `.env` no git

## Suporte

Se encontrar problemas:

1. Verifique os logs do backend no Render
2. Verifique os logs da Evolution API no Railway
3. Consulte o `GUIA_PASSO_A_PASSO.md` para configuração completa
4. Use o `CHECKLIST_IA_ERROS_LOGS.md` para debugging
