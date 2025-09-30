#!/usr/bin/env bash
set -euo pipefail
API_BASE="${API_BASE:-http://127.0.0.1:3000}"
read -rp "api_id: " API_ID
read -rsp "api_hash (не отображается): " API_HASH; echo
read -rp "name (имя сессии): " NAME
echo "→ Стартую QR для ${NAME}…"
curl -sS -X POST "${API_BASE}/auth/qr/start" -H 'Content-Type: application/json' \
  -d "{\"name\":\"${NAME}\",\"apiId\":${API_ID},\"apiHash\":\"${API_HASH}\"}" || { echo "Ошибка запроса"; exit 1; }
echo "→ Открою логи PM2; отсканируй QR (Telegram → Настройки → Устройства → Подключить)."
pm2 logs tgapi --lines 80
echo "→ Проверяю статус…"
for i in {1..20}; do
  S=$(curl -sS "${API_BASE}/auth/qr/status?name=$(printf %s "$NAME" | sed 's/ /%20/g')" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')
  echo "  попытка $i: $S"
  [ "$S" = "authorized" ] && echo "✅ Аккаунт ${NAME} авторизован" && exit 0
  sleep 2
done
echo "⚠️ Не дождался authorized."
exit 1
