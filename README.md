# Userbot TG API (одна команда установки)

## Установка
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kalininlive/Userbot-TG-Installer/main/install.sh)
В инсталлере укажи IP(ы) сервера n8n — он пропишет ALLOW_IPS и настроит UFW.

Синонимы параметров (middleware)
API принимает взаимозаменяемые поля:

Адресат: chat | channel | peer

@username или t.me/... → трактуется как канал

me, -100<ID>, числовой id → трактуется как peer

Текст: text | message (оба эквивалентны)

Примеры
Чтение:

pgsql
Копировать код
GET /messages?name=<acc>&chat=@n8n_community&limit=10
GET /messages?name=<acc>&chat=-1001481574785&limit=10
Отправка:

perl
Копировать код
POST /send
{
  "name": "<acc>",
  "chat": "me",         // можно peer или channel
  "text": "hello"
}
Полезные команды
Статус: curl -sS http://127.0.0.1:3000/health

Токен: grep ^API_TOKEN= /opt/tgapi/.env

Логи: pm2 logs tgapi

Рестарт:pm2 restart tgapi --update-env

Обновл.:/opt/tgapi/scripts/update.sh

Сессии: find /opt/tgapi/sessions -maxdepth 1 -name "*.session" -printf "%f\n" | sed 's/\.session$//'

Удалить:/opt/tgapi/scripts/uninstall.sh
