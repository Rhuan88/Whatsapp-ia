#!/usr/bin/env bash
set -Eeuo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "❌ Execute como root (sudo)."
  echo "Exemplo: sudo bash setup-nginx-ssl.sh meu-dominio.com email@dominio.com"
  exit 1
fi

DOMAIN="${1:-}"
EMAIL="${2:-}"

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
  echo "Uso: sudo bash setup-nginx-ssl.sh <dominio> <email>"
  echo "Exemplo: sudo bash setup-nginx-ssl.sh bot.exemplo.com admin@exemplo.com"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/nginx-whatsapp-ia.conf.template"
SITE_AVAILABLE="/etc/nginx/sites-available/whatsapp-ia"
SITE_ENABLED="/etc/nginx/sites-enabled/whatsapp-ia"

echo "[1/7] Instalando pacotes (nginx + certbot)..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx certbot python3-certbot-nginx

echo "[2/7] Gerando configuração do Nginx para $DOMAIN..."
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "❌ Template não encontrado: $TEMPLATE_FILE"
  exit 1
fi

sed "s/__DOMAIN__/$DOMAIN/g" "$TEMPLATE_FILE" > "$SITE_AVAILABLE"

if [ -L "$SITE_ENABLED" ] || [ -f "$SITE_ENABLED" ]; then
  rm -f "$SITE_ENABLED"
fi
ln -s "$SITE_AVAILABLE" "$SITE_ENABLED"

if [ -L /etc/nginx/sites-enabled/default ] || [ -f /etc/nginx/sites-enabled/default ]; then
  rm -f /etc/nginx/sites-enabled/default
fi

echo "[3/7] Testando Nginx..."
nginx -t
systemctl enable nginx
systemctl restart nginx

echo "[4/7] Liberando firewall (se UFW estiver ativo)..."
if command -v ufw >/dev/null 2>&1; then
  ufw allow 'Nginx Full' >/dev/null 2>&1 || true
  ufw allow OpenSSH >/dev/null 2>&1 || true
fi

echo "[5/7] Emitindo certificado Let's Encrypt..."
certbot --nginx -d "$DOMAIN" -m "$EMAIL" --agree-tos --no-eff-email --redirect -n

echo "[6/7] Testando renovação automática..."
certbot renew --dry-run || true

echo "[7/7] Concluído!"
echo "✅ HTTPS ativo em: https://$DOMAIN"
echo "✅ Healthcheck: https://$DOMAIN/health"
