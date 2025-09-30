# Userbot TG API — установщик для n8n-автоматизаций

Скрипт разработан для запуска **Telegram Userbot API** на отдельном сервере и его подключения к сценариям **n8n** (HTTP-узлы, веб-хуки, интеграции).  
**Посмотреть больше автоматизаций:** https://t.me/+VxXC2TaMEv0zMzcy  
**Заказать разработку автоматизации:** https://t.me/WebSansay

---

## Что это даёт

- Лёгкий установщик (Ubuntu 22.04) — всё поднимется за одну команду.
- API с авторизацией по **Bearer API_TOKEN**.
- Быстрый QR-логин (ASCII-QR в логах) и хранение сессий на диске.
- Безопасность из коробки: порт 3000 открыт **только** для IP вашего n8n (и 127.0.0.1).
- Готовые маршруты: профайл, диалоги/каналы, чтение сообщений, отправка сообщений.
- Удобные **синонимы параметров** (`chat|channel|peer` и `text|message`) — меньше ошибок в запросах.

---

## Требования

- **OS:** Ubuntu 22.04 x64 (root или sudo).
- **Сеть:** исходящие к Telegram DC (обычно 80/443 TCP).
- **Порт:** входящий `3000/tcp` (доступ только с IP вашего n8n).
- **Доступ:** IP n8n (или нескольких n8n), чтобы whitelisting работал.

---

## Установка (2 способа)

**Способ 1 (рекомендуемый):**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kalininlive/Userbot-TG-Installer/main/install.sh)
````

**Способ 2 (если оболочка не поддерживает `<(...)`):**

```bash
curl -fsSL https://raw.githubusercontent.com/kalininlive/Userbot-TG-Installer/main/install.sh | bash
```

### Во время установки скрипт:

1. Спросит IP(ы) вашего **n8n** → запишет в `ALLOW_IPS` и настроит UFW (порт 3000 открыт только этим IP + 127.0.0.1).
2. Сгенерирует `API_TOKEN` и выведет его в конце.
3. Предложит **сразу запустить мастер QR-авторизации**: спросит `api_id`, `api_hash`, `name` и покажет **QR в логах** (нужно отсканировать в Telegram: Настройки → Устройства → Подключить устройство).

> Если вы отказались от QR на этапе установки — запустить его можно позже:
>
> ```
> /opt/tgapi/scripts/qr_wizard.sh
> ```

---

## Где лежит и как управлять

* Директория приложения: `/opt/tgapi`
* Файл настроек: `/opt/tgapi/.env`
* Сессии: `/opt/tgapi/sessions/*.session` (+ вспомогательные `.json`)
* Логи: `pm2 logs tgapi`
* Автозапуск: PM2 (процесс `tgapi`)

Полезные команды:

```bash
# Статус здоровья API (локально)
curl -sS http://127.0.0.1:3000/health

# Токен API
grep ^API_TOKEN= /opt/tgapi/.env

# Логи/перезапуск/сохранение PM2
pm2 logs tgapi
pm2 restart tgapi --update-env
pm2 save

# Обновление кода (git pull + зависимости + рестарт)
 /opt/tgapi/scripts/update.sh

# Удаление c бэкапом сессий в /opt/tgapi/sessions_backup_YYYYmmdd_HHMMSS
 /opt/tgapi/scripts/uninstall.sh

# Список сессий (по файлам)
find /opt/tgapi/sessions -maxdepth 1 -name "*.session" -printf "%f\n" | sed 's/\.session$//'
```

---

## Конфигурация (`.env`)

| Параметр        | Значение / пример            | Описание                                                             |
| --------------- | ---------------------------- | -------------------------------------------------------------------- |
| `PORT`          | `3000`                       | Порт API.                                                            |
| `API_TOKEN`     | `abcdef0123...`              | Секрет для Bearer-авторизации (задаётся установщиком).               |
| `SESSIONS_DIR`  | `/opt/tgapi/sessions`        | Папка для `.session` файлов.                                         |
| `LOG_LEVEL`     | `info`                       | Уровень логирования.                                                 |
| `ACCESS_MODE`   | `ip`                         | Режим ограничений для **открытых** роутов (`/health`, `/auth/qr/*`). |
| `ALLOW_IPS`     | `127.0.0.1,90.156.253.98`    | Разрешённые IP (CSV). Всегда включён `127.0.0.1`.                    |
| `ALLOW_ORIGINS` | *(пусто или список доменов)* | Разрешённые источники для CORS (если нужно с фронтенда).             |

> **Безопасность по умолчанию**:
>
> * Открытые роуты (`/health`, `/auth/qr/*`) доступны только с IP из `ALLOW_IPS`.
> * Все остальные роуты требуют `Authorization: Bearer <API_TOKEN>`.

---

## QR-мастер (терминал)

Запустить:

```bash
/opt/tgapi/scripts/qr_wizard.sh
```

Он спросит:

* `api_id` и `api_hash` (из [https://my.telegram.org/apps](https://my.telegram.org/apps)),
* `name` — имя вашей сессии (например, `main`, `client1`, `n8n_main`).

Покажет ASCII-QR в `pm2 logs`, а затем в цикле проверит статус:

```
/auth/qr/status?name=<name>  →  {"status":"authorized"}  →  ✅ Аккаунт <name> авторизован
```

---

## API (обзор)

### Открытые (ограничены по IP: `ALLOW_IPS`)

* `GET /health` — проверка живости (всегда должна отдавать `{ ok: true }`).
* `POST /auth/qr/start` — старт QR-авторизации.
  Тело: `{ "name": "acc", "apiId": 12345, "apiHash": "abc..." }`
* `GET /auth/qr/status?name=acc` — статус: `preparing | qr_ready | authorized | error`.
* `GET /auth/qr/png?name=acc` — PNG-картинка QR (когда статус `qr_ready`).
* `GET /auth/qr/wizard` — простая HTML-страница (браузерный мастер QR).

### Защищённые (требуют `Authorization: Bearer <API_TOKEN>`)

* `GET /me?name=acc` — профиль текущего пользователя.
* `GET /dialogs?name=acc&limit=50` — список диалогов.
* `GET /channels?name=acc&limit=50` — список каналов.
* `GET /messages?name=acc&[chat|channel|peer]=<target>&limit=50` — читать сообщения.
* `POST /send` — отправить сообщение.
  Тело: `{ "name":"acc", "[chat|channel|peer]":"me|@username|-100id", "[text|message]":"..." }`

### Синонимы параметров (middleware)

* Адресат: можно передавать **любой** из `chat`, `channel`, `peer`:

  * `@username` или `t.me/...` → трактуется как **канал** (внутри будет `channel`),
  * `me`, `-100<ID>`, числовой id → трактуется как **peer`.
* Текст: можно передавать `text` **или** `message`.

> Практически везде используйте просто `chat=` и `text=` — сервер сам разрулит.

---

## Примеры запросов (`curl`)

Подготовим окружение:

```bash
NAME="main"                                        # имя вашей сессии
TOKEN="$(grep ^API_TOKEN= /opt/tgapi/.env | cut -d= -f2)"
API="http://127.0.0.1:3000"
```

**Профиль:**

```bash
curl -sS -H "Authorization: Bearer $TOKEN" "$API/me?name=$NAME"
```

**Каналы и диалоги:**

```bash
curl -sS -H "Authorization: Bearer $TOKEN" "$API/channels?name=$NAME&limit=20"
curl -sS -H "Authorization: Bearer $TOKEN" "$API/dialogs?name=$NAME&limit=20"
```

**Чтение сообщений (username):**

```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "$API/messages?name=$NAME&chat=@n8n_community&limit=10"
```

**Чтение сообщений (числовой ID канала):**

```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "$API/messages?name=$NAME&chat=-1001481574785&limit=5"
```

**Отправка в “Избранное”:**

```bash
curl -sS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"'"$NAME"'","chat":"me","text":"hello from API"}' \
  "$API/send"
```

**Отправка в канал по username:**

```bash
curl -sS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"'"$NAME"'","chat":"@n8n_community","text":"ping"}' \
  "$API/send"
```

---

## Быстрый старт в n8n (идея)

1. **HTTP Request** (POST) → `http://IP_вашего_tgapi:3000/auth/qr/start`
   Тело JSON: `{"name":"acc","apiId":12345,"apiHash":"abc..."}`
   *Этот шаг стартует авторизацию и генерит QR.*

2. **HTTP Request** (GET, каждые 2–3 сек, до authorized) →
   `http://IP_вашего_tgapi:3000/auth/qr/status?name=acc`
   *Проверяем статус и берём ссылку `tg://login?...`.*

3. **Markdown/HTML** → выводим картинку:
   `<img src="http://IP_вашего_tgapi:3000/auth/qr/png?name=acc">`

> Важно: IP/домен n8n должен входить в `ALLOW_IPS`.

---

## Трюки с сессиями (файлы)

**Переименовать сессию** (пример с `old` → `new`):

```bash
pm2 stop tgapi
mv /opt/tgapi/sessions/old.session /opt/tgapi/sessions/new.session
[ -f /opt/tgapi/sessions/old.json ] && mv /opt/tgapi/sessions/old.json /opt/tgapi/sessions/new.json
pm2 start tgapi
```

**Удалить все сессии:**

```bash
pm2 stop tgapi
rm -f /opt/tgapi/sessions/*.session /opt/tgapi/sessions/*.json
pm2 start tgapi
```

---

## Обновления

* Ручное обновление:

  ```bash
  /opt/tgapi/scripts/update.sh
  ```
* Или перезапуск с подтяжкой env:

  ```bash
  pm2 restart tgapi --update-env
  ```

---

## Приватный репозиторий (если решите закрыть доступ)

“Одна команда” из README работает **только для публичного репозитория**.
Для приватного есть два подхода:

**A. HTTPS + Personal Access Token (быстро):**

```bash
APP_DIR=/opt/tgapi
rm -rf "$APP_DIR"
read -rsp "GitHub token (repo read): " GH_TOKEN; echo
git clone --depth=1 "https://${GH_TOKEN}@github.com/kalininlive/Userbot-TG-Installer.git" "$APP_DIR"
unset GH_TOKEN
bash "$APP_DIR/install.sh"
```

**B. SSH deploy-key (удобно для частых установок):**

```bash
ssh-keygen -t ed25519 -C "deploy key for tgapi" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub  # добавьте как Deploy key (Read) в настройках репозитория
ssh -o StrictHostKeyChecking=accept-new -T git@github.com || true
git clone --depth=1 git@github.com:kalininlive/Userbot-TG-Installer.git /opt/tgapi
bash /opt/tgapi/install.sh
```

---

## Частые ошибки и решения

* **401 Unauthorized**
  Не передан заголовок или неверный токен.
  → Добавьте `-H "Authorization: Bearer $(grep ^API_TOKEN= /opt/tgapi/.env | cut -d= -f2)"`.

* **403 Forbidden / Не видно `/auth/qr/*`**
  Ваш IP не в `ALLOW_IPS`, или UFW не пропускает.
  → Проверьте `.env` (`ALLOW_IPS=`) и `ufw status`. Добавьте IP n8n и `pm2 restart tgapi --update-env`.

* **`CHANNEL_INVALID`** при чтении/отправке
  Не верный идентификатор или вы не участник канала.
  → Используйте `@username` **или** `-100<ID>`. Убедитесь, что аккаунт авторизован и состоит в канале.

* **`Not connected / TIMEOUT`**
  Временные сетевые проблемы, блокировки или Telegram переключил DC.
  → `pm2 restart tgapi`, проверьте исходящие порты/файерволл/провайдера.

* **QR не появляется / статус не меняется**
  Смотрите `pm2 logs tgapi`. Проверьте время сервера (`timedatectl`). Повторите `qr_wizard.sh`.

---

## Лицензия и контакты

* Свободно используйте и модифицируйте под свои задачи.
* Идеи, PR и вопросы приветствуются.

**Больше автоматизаций:** [https://t.me/+VxXC2TaMEv0zMzcy](https://t.me/+VxXC2TaMEv0zMzcy)
**Заказать разработку:** [https://t.me/WebSansay](https://t.me/WebSansay)

```
::contentReference[oaicite:0]{index=0}
```
