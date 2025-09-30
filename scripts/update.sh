#!/usr/bin/env bash
set -euo pipefail
cd /opt/tgapi
git pull --ff-only || true
npm ci || npm i
pm2 restart tgapi --update-env
pm2 save
echo "[update] done."
