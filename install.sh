#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

REPO_URL="https://github.com/kalininlive/Userbot-TG-Installer.git"
APP_DIR="${APP_DIR:-/opt/tgapi}"
NODE_MAJOR="${NODE_MAJOR:-20}"

echo "==> Установка пакетов"
apt-get -yq update
apt-get -yq install ca-certificates curl git gnupg build-essential ufw

echo "==> Node.js и PM2"
curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -
apt-get -yq install nodejs
npm i -g pm2

echo "==> Код приложения"
if [ -d "$APP_DIR/.git" ]; then
  cd "$APP_DIR" && git pull --ff-only || true
else
  rm -rf "$APP_DIR"
  git clone --depth=1 "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"
npm ci || npm i
mkdir -p "$APP_DIR/sessions" "$APP_DIR/scripts"
chmod +x "$APP_DIR"/scripts/*.sh 2>/dev/null || true

echo "==> .env"
if [ ! -f "$APP_DIR/.env" ]; then
  API_TOKEN=$(openssl rand -hex 24)
  cat > "$APP_DIR/.env" <<ENV
PORT=3000
API_TOKEN=\${API_TOKEN}
SESSIONS_DIR=\${APP_DIR}/sessions
LOG_LEVEL=info
ACCESS_MODE=ip
ALLOW_IPS=
ALLOW_ORIGINS=
ENV
fi

# Спросим IP(ы) n8n (через запятую) и добавим в ALLOW_IPS
if grep -q '^ALLOW_IPS=$' "$APP_DIR/.env" || ! grep -q '^ALLOW_IPS=' "$APP_DIR/.env"; then
  read -rp "IP(ы) n8n, которым разрешён доступ (через запятую): " ALLOW
  ALLOW=\${ALLOW// /}
  sed -i "s|^ALLOW_IPS=.*|ALLOW_IPS=127.0.0.1,\${ALLOW}|" "$APP_DIR/.env"
fi

echo "==> PM2 старт"
pm2 start "$APP_DIR/src/server.js" --name tgapi || pm2 restart tgapi --update-env
pm2 save
pm2 startup -u root --hp /root >/tmp/pm2_startup.txt || true
cat /tmp/pm2_startup.txt || true

echo "==> UFW (SSH + 3000 только для первого IP из ALLOW_IPS)"
ufw allow OpenSSH || true
FIRST_IP="$(grep '^ALLOW_IPS=' "$APP_DIR/.env" | cut -d= -f2 | tr -d ' ' | tr ',' '\n' | sed -n '2p')"
if [[ -n "$FIRST_IP" ]]; then
  ufw allow from "$FIRST_IP" to any port 3000 proto tcp || true
fi
ufw deny 3000/tcp || true
yes | ufw enable || true
ufw status verbose || true

echo "==> Проверка здоровья"
for i in {1..10}; do
  if curl -fsS "http://127.0.0.1:3000/health" >/dev/null; then
    echo "API жив: http://127.0.0.1:3000/health"
    break
  fi
  sleep 1
done

echo
echo "API_TOKEN=$(grep ^API_TOKEN= "$APP_DIR/.env" | cut -d= -f2)"
echo "QR мастер: $APP_DIR/scripts/qr_wizard.sh"
echo

# ───────────────────────────────────────────────────────────
# Предложим сразу авторизовать первую сессию (QR в логах)
read -rp "Запустить мастер QR-авторизации СЕЙЧАС? [y/N] " DO_QR
if [[ "${DO_QR,,}" == "y" ]]; then
  echo "→ Запускаю $APP_DIR/scripts/qr_wizard.sh"
  "$APP_DIR/scripts/qr_wizard.sh" || {
    echo "⚠️ Не удалось пройти авторизацию сейчас. Можно повторить позже: $APP_DIR/scripts/qr_wizard.sh"
  }
else
  echo "Можно пройти авторизацию позже: $APP_DIR/scripts/qr_wizard.sh"
fi
# ───────────────────────────────────────────────────────────

echo "Готово."
