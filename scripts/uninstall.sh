#!/usr/bin/env bash
set -euo pipefail
read -rp "Удалить tgapi? [y/N] " ans
[[ "${ans,,}" == "y" ]] || exit 0
ts=$(date +%Y%m%d_%H%M%S)
pm2 stop tgapi || true
pm2 delete tgapi || true
pm2 save || true
cp -a /opt/tgapi/sessions "/opt/tgapi/sessions_backup_${ts}" || true
rm -rf /opt/tgapi
echo "Готово."
