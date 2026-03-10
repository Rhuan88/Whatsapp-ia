#!/usr/bin/env bash
set -Eeuo pipefail

# Uso:
#   sudo bash bootstrap-oracle.sh [target_user] [repo_url] [install_dir]
# Exemplo:
#   sudo bash bootstrap-oracle.sh ubuntu https://github.com/Rhuan88/Whatsapp-ia.git /opt/Whatsapp-ia

TARGET_USER="${1:-${SUDO_USER:-ubuntu}}"
REPO_URL="${2:-https://github.com/Rhuan88/Whatsapp-ia.git}"
INSTALL_DIR="${3:-/opt/Whatsapp-ia}"

if [ "${EUID}" -ne 0 ]; then
  echo "❌ Execute como root (sudo)."
  echo "Exemplo: sudo bash bootstrap-oracle.sh ubuntu https://github.com/Rhuan88/Whatsapp-ia.git /opt/Whatsapp-ia"
  exit 1
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "❌ Usuário '$TARGET_USER' não existe na VM."
  exit 1
fi

echo "[1/8] Atualizando pacotes base..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl gnupg git ufw lsb-release build-essential

echo "[2/8] Instalando Node.js 20 (se necessário)..."
NEED_NODE_INSTALL=1
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -v | sed 's/v//' | cut -d. -f1)"
  if [ "${NODE_MAJOR}" -ge 18 ]; then
    NEED_NODE_INSTALL=0
    echo "Node.js já instalado: $(node -v)"
  fi
fi

if [ "$NEED_NODE_INSTALL" -eq 1 ]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
  echo "Node.js instalado: $(node -v)"
fi

echo "[3/8] Instalando Docker (se necessário)..."
if ! command -v docker >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-v2 || \
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-plugin
fi
systemctl enable docker
systemctl restart docker
usermod -aG docker "$TARGET_USER" || true

echo "[4/8] Instalando PM2 (se necessário)..."
if ! command -v pm2 >/dev/null 2>&1; then
  npm install -g pm2
fi

echo "[5/8] Clonando/atualizando repositório..."
mkdir -p "$(dirname "$INSTALL_DIR")"
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "Repositório já existe. Atualizando..."
  sudo -u "$TARGET_USER" bash -lc "cd '$INSTALL_DIR' && git pull --ff-only"
else
  sudo -u "$TARGET_USER" git clone "$REPO_URL" "$INSTALL_DIR"
fi

echo "[6/8] Garantindo .env no backend..."
BACKEND_DIR="$INSTALL_DIR/backend"
if [ ! -d "$BACKEND_DIR" ]; then
  echo "❌ Pasta backend não encontrada em: $BACKEND_DIR"
  exit 1
fi

if [ ! -f "$BACKEND_DIR/.env" ]; then
  cp "$BACKEND_DIR/.env.example" "$BACKEND_DIR/.env"
  chown "$TARGET_USER":"$TARGET_USER" "$BACKEND_DIR/.env"
  echo "⚠️ Criado $BACKEND_DIR/.env (edite antes do deploy)."
fi

echo "[7/8] Abrindo portas HTTP/HTTPS (UFW, se ativo)..."
if command -v ufw >/dev/null 2>&1; then
  ufw allow OpenSSH >/dev/null 2>&1 || true
  ufw allow 80/tcp >/dev/null 2>&1 || true
  ufw allow 443/tcp >/dev/null 2>&1 || true
fi

echo "[8/8] Concluído!"
echo "✅ Bootstrap finalizado."
echo ""
echo "Próximos passos (como $TARGET_USER):"
echo "  cd '$BACKEND_DIR'"
echo "  nano .env"
echo "  bash deploy.sh"
echo ""
echo "Opcional (HTTPS com domínio):"
echo "  sudo bash setup-nginx-ssl.sh bot.seudominio.com seu-email@dominio.com"
echo ""
echo "⚠️ Se acabou de adicionar usuário ao grupo docker, faça logout/login na sessão SSH."
