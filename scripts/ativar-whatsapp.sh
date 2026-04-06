#!/bin/bash

# Script de Ativação do Bot Estive
# Este script gera o QR Code e conecta o número do WhatsApp à instância

set -e

# Configurações padrão (podem ser sobrescritas via variáveis de ambiente)
API_URL="${WHATSAPP_API_URL:-https://evolution-api-production-5d52.up.railway.app}"
INSTANCE_NAME="${WHATSAPP_INSTANCE:-bot-estive}"
API_KEY="${WHATSAPP_TOKEN:-Pmrhuan2013}"

echo ""
echo "=========================================="
echo "  ATIVAÇÃO DO BOT ESTIVE"
echo "=========================================="
echo ""
echo "API URL: $API_URL"
echo "Instância: $INSTANCE_NAME"
echo ""

# Passo 1: Verificar se a instância existe
echo "[1/5] Verificando instância..."
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "apikey: $API_KEY" \
  "$API_URL/instance/connectionState/$INSTANCE_NAME")

if [ "$STATUS_CODE" != "200" ]; then
  echo "⚠️  Instância não encontrada ou não acessível (HTTP $STATUS_CODE)"
  echo ""
  echo "Criando nova instância '$INSTANCE_NAME'..."

  CREATE_RESPONSE=$(curl -s -X POST \
    -H "apikey: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"instanceName\":\"$INSTANCE_NAME\",\"qrcode\":true}" \
    "$API_URL/instance/create")

  echo "✅ Instância criada"
  echo ""
fi

# Passo 2: Conectar e gerar QR Code
echo "[2/5] Gerando QR Code..."
QR_RESPONSE=$(curl -s -X GET \
  -H "apikey: $API_KEY" \
  "$API_URL/instance/connect/$INSTANCE_NAME")

# Extrair QR Code Base64
QR_BASE64=$(echo "$QR_RESPONSE" | grep -o '"base64":"[^"]*"' | cut -d'"' -f4 || echo "")
if [ -z "$QR_BASE64" ]; then
  QR_BASE64=$(echo "$QR_RESPONSE" | grep -o '"qrcode":{"base64":"[^"]*"' | grep -o '"base64":"[^"]*"' | cut -d'"' -f4 || echo "")
fi

if [ -z "$QR_BASE64" ]; then
  echo "❌ Não foi possível obter o QR Code"
  echo "Resposta da API:"
  echo "$QR_RESPONSE"
  exit 1
fi

# Passo 3: Salvar QR Code em arquivo HTML
QR_FILE="/tmp/whatsapp-qr-$(date +%s).html"
echo "[3/5] Salvando QR Code em $QR_FILE..."

cat > "$QR_FILE" << EOF
<!DOCTYPE html>
<html lang='pt-BR'>
<head>
<meta charset='utf-8'>
<title>QR Code WhatsApp - $INSTANCE_NAME</title>
<meta http-equiv="refresh" content="60">
<style>
body{display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;background:#0f172a;font-family:Arial,sans-serif;color:#fff}
.container{max-width:600px;padding:20px}
.card{background:#111827;padding:32px;border-radius:16px;text-align:center;box-shadow:0 12px 30px rgba(0,0,0,.35)}
h1{margin:0 0 16px;font-size:24px;color:#f1f5f9}
.qr-container{background:#fff;padding:16px;border-radius:12px;margin:24px auto;display:inline-block}
img{width:320px;height:320px;display:block}
.info{margin-top:24px;padding:16px;background:#1e293b;border-radius:8px;text-align:left}
.info p{margin:8px 0;font-size:14px;line-height:1.6}
code{color:#93c5fd;background:#0f172a;padding:2px 6px;border-radius:4px;font-size:13px}
.instructions{margin-top:24px;text-align:left;color:#cbd5e1;font-size:14px;line-height:1.8}
.instructions ol{padding-left:20px}
.instructions li{margin:8px 0}
.warning{background:#7c2d12;padding:12px;border-radius:8px;margin-top:16px;font-size:13px;color:#fed7aa}
</style>
</head>
<body>
<div class='container'>
  <div class='card'>
    <h1>🔗 Conectar Bot Estive</h1>
    <div class='qr-container'>
      <img src='$QR_BASE64' alt='QR Code WhatsApp'/>
    </div>

    <div class='info'>
      <p><strong>Instância:</strong> <code>$INSTANCE_NAME</code></p>
      <p><strong>Status:</strong> Aguardando escaneamento...</p>
    </div>

    <div class='instructions'>
      <strong>📱 Como conectar:</strong>
      <ol>
        <li>Abra o WhatsApp no celular que será usado como bot</li>
        <li>Vá em <strong>Menu (⋮)</strong> → <strong>Aparelhos conectados</strong></li>
        <li>Toque em <strong>Conectar um aparelho</strong></li>
        <li>Escaneie o QR Code acima</li>
        <li>Aguarde a confirmação de conexão</li>
      </ol>
    </div>

    <div class='warning'>
      ⚠️ Este QR Code expira em 60 segundos e a página será recarregada automaticamente.
    </div>
  </div>
</div>
</body>
</html>
EOF

echo "✅ QR Code salvo"
echo ""

# Passo 4: Tentar abrir no navegador
echo "[4/5] Tentando abrir QR Code no navegador..."
if command -v xdg-open &> /dev/null; then
  xdg-open "$QR_FILE" 2>/dev/null &
  echo "✅ Navegador aberto"
elif command -v open &> /dev/null; then
  open "$QR_FILE" 2>/dev/null &
  echo "✅ Navegador aberto"
else
  echo "⚠️  Não foi possível abrir automaticamente"
  echo "   Abra manualmente: $QR_FILE"
fi

echo ""
echo "=========================================="
echo "  QR CODE GERADO COM SUCESSO!"
echo "=========================================="
echo ""
echo "📱 Escaneie o QR Code com o WhatsApp"
echo ""
echo "Arquivo: $QR_FILE"
echo ""

# Passo 5: Monitorar conexão
echo "[5/5] Monitorando conexão (aguarde até 60s)..."
echo ""

for i in {1..12}; do
  sleep 5
  STATE_RESPONSE=$(curl -s -H "apikey: $API_KEY" \
    "$API_URL/instance/connectionState/$INSTANCE_NAME")

  STATE=$(echo "$STATE_RESPONSE" | grep -o '"state":"[^"]*"' | cut -d'"' -f4 || echo "")

  if [ -z "$STATE" ]; then
    STATE=$(echo "$STATE_RESPONSE" | grep -o '"instance":{"state":"[^"]*"' | grep -o '"state":"[^"]*"' | cut -d'"' -f4 || echo "")
  fi

  echo "   Tentativa $i/12: Estado = $STATE"

  if [ "$STATE" = "open" ] || [ "$STATE" = "connected" ]; then
    echo ""
    echo "=========================================="
    echo "  ✅ WHATSAPP CONECTADO COM SUCESSO!"
    echo "=========================================="
    echo ""
    echo "O bot está pronto para receber mensagens."
    echo ""
    echo "🧪 Teste enviando 'menu' para o número conectado"
    echo ""
    exit 0
  fi
done

echo ""
echo "⚠️  Tempo esgotado. Verifique:"
echo "   1. Se o QR Code foi escaneado corretamente"
echo "   2. Se o celular está com internet"
echo "   3. Execute o script novamente se necessário"
echo ""
echo "Para verificar o status manualmente:"
echo "curl -H 'apikey: $API_KEY' '$API_URL/instance/connectionState/$INSTANCE_NAME'"
echo ""
