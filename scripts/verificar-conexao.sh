#!/bin/bash

# Script de Verificação de Conexão do Bot Estive
# Este script verifica o status da conexão do WhatsApp e dos serviços

set -e

# Configurações padrão
API_URL="${WHATSAPP_API_URL:-https://evolution-api-production-5d52.up.railway.app}"
INSTANCE_NAME="${WHATSAPP_INSTANCE:-bot-estive}"
API_KEY="${WHATSAPP_TOKEN:-Pmrhuan2013}"
BACKEND_URL="${BACKEND_URL:-https://whatsapp-ia-qys2.onrender.com}"

echo ""
echo "=========================================="
echo "  VERIFICAÇÃO DE CONEXÃO - BOT ESTIVE"
echo "=========================================="
echo ""

# 1. Verificar backend
echo "[1/3] Verificando Backend..."
echo "URL: $BACKEND_URL"
echo ""

BACKEND_RESPONSE=$(curl -s "$BACKEND_URL/health" || echo '{"erro":"Não foi possível conectar"}')
echo "$BACKEND_RESPONSE" | grep -q '"status":"OK"' && BACKEND_STATUS="✅ ONLINE" || BACKEND_STATUS="❌ OFFLINE"

echo "Status do Backend: $BACKEND_STATUS"
echo ""
echo "Detalhes:"
echo "$BACKEND_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$BACKEND_RESPONSE"
echo ""

# 2. Verificar Evolution API
echo "[2/3] Verificando Evolution API..."
echo "URL: $API_URL"
echo "Instância: $INSTANCE_NAME"
echo ""

EVOLUTION_RESPONSE=$(curl -s -H "apikey: $API_KEY" "$API_URL/instance/connectionState/$INSTANCE_NAME" || echo '{"erro":"Não foi possível conectar"}')
echo "$EVOLUTION_RESPONSE" | grep -q '"state":"open"' && EVOLUTION_STATUS="✅ CONECTADO" || EVOLUTION_STATUS="❌ DESCONECTADO"

echo "Status Evolution API: $EVOLUTION_STATUS"
echo ""
echo "Detalhes:"
echo "$EVOLUTION_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$EVOLUTION_RESPONSE"
echo ""

# 3. Verificar webhook
echo "[3/3] Verificando Webhook..."
echo ""

WEBHOOK_RESPONSE=$(curl -s -H "apikey: $API_KEY" "$API_URL/webhook/find/$INSTANCE_NAME" || echo '{"erro":"Não foi possível verificar webhook"}')
echo "$WEBHOOK_RESPONSE" | grep -q '"enabled":true' && WEBHOOK_STATUS="✅ CONFIGURADO" || WEBHOOK_STATUS="⚠️  NÃO CONFIGURADO"

echo "Status Webhook: $WEBHOOK_STATUS"
echo ""
echo "Detalhes:"
echo "$WEBHOOK_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$WEBHOOK_RESPONSE"
echo ""

# Resumo final
echo "=========================================="
echo "  RESUMO"
echo "=========================================="
echo ""
echo "Backend:       $BACKEND_STATUS"
echo "Evolution API: $EVOLUTION_STATUS"
echo "Webhook:       $WEBHOOK_STATUS"
echo ""

# Determinar status geral
if [[ "$BACKEND_STATUS" == "✅ ONLINE" ]] && [[ "$EVOLUTION_STATUS" == "✅ CONECTADO" ]] && [[ "$WEBHOOK_STATUS" == "✅ CONFIGURADO" ]]; then
  echo "🎉 SISTEMA TOTALMENTE OPERACIONAL!"
  echo ""
  echo "O Bot Estive está pronto para receber mensagens."
  echo "Teste enviando 'menu' para o número conectado."
  echo ""
  exit 0
else
  echo "⚠️  SISTEMA COM PROBLEMAS"
  echo ""

  if [[ "$BACKEND_STATUS" != "✅ ONLINE" ]]; then
    echo "❌ Backend offline:"
    echo "   - Verifique se o serviço está rodando no Render"
    echo "   - Verifique as variáveis de ambiente"
    echo "   - Consulte os logs no Render Dashboard"
    echo ""
  fi

  if [[ "$EVOLUTION_STATUS" != "✅ CONECTADO" ]]; then
    echo "❌ WhatsApp desconectado:"
    echo "   - Execute: ./scripts/ativar-whatsapp.sh"
    echo "   - Ou no Windows: .\\gerar-qr-code.ps1"
    echo "   - Escaneie o QR Code com o WhatsApp"
    echo ""
  fi

  if [[ "$WEBHOOK_STATUS" != "✅ CONFIGURADO" ]]; then
    echo "⚠️  Webhook não configurado:"
    echo "   - Execute o comando abaixo para configurar:"
    echo ""
    echo "   curl -X POST \\"
    echo "     -H 'apikey: $API_KEY' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"url\":\"$BACKEND_URL/webhook\",\"events\":[\"MESSAGES_UPSERT\"],\"enabled\":true}' \\"
    echo "     $API_URL/webhook/set/$INSTANCE_NAME"
    echo ""
  fi

  exit 1
fi
