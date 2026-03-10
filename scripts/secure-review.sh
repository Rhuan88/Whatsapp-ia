#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"

failures=0

echo "[1/6] Verificando arquivos sensíveis versionados..."
if git -C "$ROOT_DIR" ls-files | grep -E '(^|/)\.env$' >/dev/null; then
  echo "❌ Encontrado .env versionado no Git."
  failures=$((failures+1))
else
  echo "✅ .env não está versionado."
fi

echo "[2/6] Scanner simples de padrões de segredo..."
if grep -RInE "(sk-ant-|AKIA[0-9A-Z]{16}|xox[baprs]-|-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----|postgres(ql)?://[^[:space:]]+:[^[:space:]]+@)" "$ROOT_DIR" \
  --exclude-dir=node_modules --exclude-dir=.git --exclude="*.md" --exclude="*.example"; then
  echo "❌ Possível segredo encontrado. Revise as linhas acima."
  failures=$((failures+1))
else
  echo "✅ Nenhum padrão de segredo detectado (scan básico)."
fi

echo "[3/6] Verificando Node.js >= 18..."
if ! command -v node >/dev/null 2>&1; then
  echo "❌ Node.js não encontrado."
  failures=$((failures+1))
else
  NODE_MAJOR="$(node -v | sed 's/v//' | cut -d. -f1)"
  if [ "$NODE_MAJOR" -lt 18 ]; then
    echo "❌ Node.js $NODE_MAJOR detectado; precisa de 18+."
    failures=$((failures+1))
  else
    echo "✅ Node.js $(node -v)"
  fi
fi

echo "[4/6] Instalando dependências backend..."
if [ -f "$BACKEND_DIR/package-lock.json" ]; then
  npm --prefix "$BACKEND_DIR" ci
else
  npm --prefix "$BACKEND_DIR" install
fi

echo "[5/6] Verificação de sintaxe..."
if node -c "$BACKEND_DIR/server.js"; then
  echo "✅ Sintaxe do server.js OK"
else
  echo "❌ Erro de sintaxe em server.js"
  failures=$((failures+1))
fi

echo "[6/6] Auditoria de segurança npm (high+critical)..."
if npm --prefix "$BACKEND_DIR" audit --omit=dev --audit-level=high; then
  echo "✅ Sem vulnerabilidades high/critical"
else
  echo "❌ Vulnerabilidades high/critical detectadas"
  failures=$((failures+1))
fi

if [ "$failures" -gt 0 ]; then
  echo ""
  echo "❌ Revisão de segurança falhou com $failures problema(s)."
  exit 1
fi

echo ""
echo "✅ Revisão de segurança concluída com sucesso."
