#!/usr/bin/env bash
# Sets up an Ubuntu cloud VM and starts the app on port 80.
# Usage (from the project folder):
#   sudo bash deploy/setup-server.sh                      -> http://<SERVER_IP>
#   sudo DOMAIN=app.example.com bash deploy/setup-server.sh -> https://app.example.com (and http://<SERVER_IP>)
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$(id -u)" -ne 0 ]; then echo "Run with sudo: sudo bash deploy/setup-server.sh"; exit 1; fi

echo "==> Installing Docker and Docker Compose"
apt-get update -y
apt-get install -y docker.io docker-compose-v2 git
systemctl enable --now docker
if [ -n "${SUDO_USER:-}" ]; then usermod -aG docker "$SUDO_USER"; fi

echo "==> Creating .env (port 80, random secrets) if missing"
if [ ! -f .env ]; then
  cat > .env <<ENV
APP_PORT=80
SECRET_KEY=$(openssl rand -hex 32)
DB_PASSWORD=$(openssl rand -hex 16)
ENV
  chmod 600 .env
fi
if [ -n "${DOMAIN:-}" ]; then
  # Caddy takes ports 80/443; the app itself listens on 8080 (not opened in the cloud firewall).
  sed -i '/^APP_PORT=/d; /^DOMAIN=/d' .env
  printf 'APP_PORT=8080\nDOMAIN=%s\n' "$DOMAIN" >> .env
fi

echo "==> Opening port 80 in the server firewall"
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
fi
# Oracle Cloud Ubuntu images block ports with iptables REJECT rules by default.
if iptables -S INPUT 2>/dev/null | grep -q -- "-j REJECT"; then
  for port in 80 443; do
    iptables -C INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null || iptables -I INPUT 5 -p tcp --dport $port -m state --state NEW -j ACCEPT
  done
  if command -v netfilter-persistent >/dev/null; then netfilter-persistent save; fi
fi

echo "==> Starting the application"
if grep -q '^DOMAIN=' .env; then
  docker compose -f docker-compose.yml -f docker-compose.https.yml up -d --build
else
  docker compose up -d --build
fi

IP=$(curl -s --max-time 5 https://api.ipify.org || hostname -I | awk '{print $1}')
echo
echo "Done. Open: http://${IP}"
if grep -q '^DOMAIN=' .env; then echo "      and: https://$(grep '^DOMAIN=' .env | cut -d= -f2)"; fi
echo "If it does not open, allow inbound TCP ports 80 and 443 in the cloud provider's network rules."
