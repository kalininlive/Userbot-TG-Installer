#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

REPO_URL="https://github.com/kalininlive/Userbot-TG-Installer.git"
APP_DIR="${APP_DIR:-/opt/tgapi}"
NODE_MAJOR="${NODE_MAJOR:-20}"

echo "==> Установка пакетов"
apt-get -yq update
apt-get -yq install ca-certificates curl git gnupg build-essential ufw dnsutils

echo "==> Node.js и PM2"
curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
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
API_TOKEN=${API_TOKEN}
SESSIONS_DIR=${APP_DIR}/sessions
LOG_LEVEL=info
ACCESS_MODE=ip
ALLOW_IPS=
ALLOW_ORIGINS=
ENV
fi

# Спросим IP(ы) n8n (через запятую) и добавим в ALLOW_IPS
if grep -q '^ALLOW_IPS=$' "$APP_DIR/.env" || ! grep -q '^ALLOW_IPS=' "$APP_DIR/.env"; then
  read -rp "IP(ы) n8n, которым разрешён доступ (через запятую): " ALLOW
  ALLOW=${ALLOW// /}
  sed -i "s|^ALLOW_IPS=.*|ALLOW_IPS=127.0.0.1,${ALLOW}|" "$APP_DIR/.env"
fi

echo "==> PM2 старт"
pm2 start "$APP_DIR/src/server.js" --name tgapi || pm2 restart tgapi --update-env
pm2 save
pm2 startup -u root --hp /root >/tmp/pm2_startup.txt || true
cat /tmp/pm2_startup.txt || true

# === UFW: строгий доступ к 3000 только с IP из ALLOW_IPS (ALLOW выше DENY) ===
echo "==> UFW (SSH открыт; 3000 только для ALLOW_IPS в правильном порядке)"

# 0) Оставляем SSH
ufw allow OpenSSH || true

# 1) Собираем уникальные IPv4 из ALLOW_IPS (без пробелов)
ALLOW_LINE="$(grep '^ALLOW_IPS=' "$APP_DIR/.env" | cut -d= -f2- | tr -d ' ')"
ALLOW_LIST="$(printf '%s\n' "$ALLOW_LINE" | tr ',' ' ' | xargs -n1 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u)"

# 2) Удаляем все старые правила про 3000/tcp, чтобы порядок не испортился
if ufw status numbered | grep -q '3000/tcp'; then
  while :; do
    NUM=$(ufw status numbered | awk '/3000\/tcp/{print $1}' | tr -d '[]' | sort -nr | head -n1)
    [ -n "$NUM" ] || break
    ufw delete "$NUM" || true
  done
fi

# 3) Добавляем ALLOW для каждого IP n8n ПЕРЕД DENY
if [ -n "$ALLOW_LIST" ]; then
  for IP in $ALLOW_LIST; do
    ufw insert 1 allow from "$IP" to any port 3000 proto tcp || true
  done
else
  echo "⚠️  ALLOW_IPS пуст — порт 3000 будет закрыт для внешних! (работает только локально)"
fi

# 4) Добавляем общий DENY для 3000/tcp СРАЗУ ПОСЛЕ allow-правил
DENY_POS=$(( $(echo "$ALLOW_LIST" | wc -w) + 1 ))
ufw insert "$DENY_POS" deny 3000/tcp || ufw deny 3000/tcp

# 5) Включаем UFW (если не включён) и печатаем правила
yes | ufw enable || true
ufw status verbose || true

echo "==> Проверка здоровья"
for i in {1..12}; do
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
