# Userbot TG API — установка одной командой

## Установка (2 способа)

**Способ 1 (рекомендуемый):**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kalininlive/Userbot-TG-Installer/main/install.sh)
```

**Способ 2 (если оболочка не поддерживает `<(...)`):**
```bash
curl -fsSL https://raw.githubusercontent.com/kalininlive/Userbot-TG-Installer/main/install.sh | bash
```

В инсталлере укажи IP(ы) сервера n8n — он пропишет `ALLOW_IPS`, настроит UFW и предложит
сразу запустить мастер QR-авторизации (ввод `api_id`, `api_hash`, `name` и показ QR в логах).
Если откажешься — авторизацию всегда можно пройти позже: `/opt/tgapi/scripts/qr_wizard.sh`.

---

## Синонимы параметров (middleware)

API понимает взаимозаменяемые поля:

- **Адресат:** `chat` | `channel` | `peer`  
  `@username` или `t.me/...` → трактуется как **канал**;  
  `me`, `-100<ID>`, числовой id → трактуется как **peer**.
- **Текст:** `text` | `message` (оба эквивалентны)

### Примеры

**Чтение:**
```http
GET /messages?name=<acc>&chat=@n8n_community&limit=10
GET /messages?name=<acc>&chat=-1001481574785&limit=10
```

**Отправка:**
```http
POST /send
{
  "name": "<acc>",
  "chat": "me",          // можно peer или channel
  "text": "hello"
}
```

---

## Полезные команды

- Статус: `curl -sS http://127.0.0.1:3000/health`
- Токен:  `grep ^API_TOKEN= /opt/tgapi/.env`
- Логи:   `pm2 logs tgapi`
- Рестарт: `pm2 restart tgapi --update-env`
- Обновление: `/opt/tgapi/scripts/update.sh`
- Сессии: `find /opt/tgapi/sessions -maxdepth 1 -name "*.session" -printf "%f\n" | sed 's/\.session$//'`
- Удаление: `/opt/tgapi/scripts/uninstall.sh`
