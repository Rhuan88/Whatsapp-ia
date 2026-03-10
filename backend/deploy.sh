#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[1/6] Verificando Node.js..."
if ! command -v node >/dev/null 2>&1; then
  echo "❌ Node.js não encontrado. Instale Node 18+ antes de continuar."
  exit 1
fi

NODE_MAJOR="$(node -v | sed 's/v//' | cut -d. -f1)"
if [ "${NODE_MAJOR}" -lt 18 ]; then
  echo "❌ Node.js ${NODE_MAJOR} detectado. É necessário Node 18+"
  exit 1
fi

echo "[2/6] Verificando arquivo .env..."
if [ ! -f .env ]; then
  cp .env.example .env
  echo "⚠️ .env não existia. Criei a partir do .env.example."
  echo "⚠️ Edite o arquivo backend/.env com suas chaves e rode novamente."
  exit 1
fi

echo "[3/6] Instalando dependências..."
if [ -f package-lock.json ]; then
  npm ci --omit=dev
else
  npm install --omit=dev
fi

echo "[4/6] Verificando PM2..."
if ! command -v pm2 >/dev/null 2>&1; then
  echo "PM2 não encontrado. Instalando globalmente..."
  npm install -g pm2
fi

echo "[5/6] Subindo serviço com PM2..."
pm2 startOrReload ecosystem.config.js --env production
pm2 save

# Tenta configurar startup automático sem falhar o deploy se não houver sudo
pm2 startup >/dev/null 2>&1 || true

echo "[6/6] Health check local..."
if command -v curl >/dev/null 2>&1; then
  sleep 2
  curl -fsS http://127.0.0.1:${PORT:-3000}/health || true
fi

echo "✅ Deploy concluído."
echo "📌 Comandos úteis:"
echo "   pm2 status"
echo "   pm2 logs whatsapp-ia --lines 100"
echo "   pm2 restart whatsapp-ia"
