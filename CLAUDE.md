# wg-split-tunnel-template

## Что это

Генератор списка `AllowedIPs` для split-tunnel WireGuard: через туннель идут
только выбранные сервисы (по умолчанию Telegram, YouTube, WhatsApp), остальной
трафик — мимо. Сервер шаблон не трогает: результат применяется на стороне
клиента.

**Репозиторий публичный** (`origin` → GitHub). Личных данных, ключей, адресов
серверов и рабочих конфигов здесь быть не должно — только шаблоны и скрипты.

## Как работает конвейер

1. `services.conf` — конструктор: строка = `<имя_сервиса> <AS1> [AS2] …`.
   Закомментировал строку — сервис выключен, дописал — добавлен.
2. `fetch_prefixes.sh` — тянет префиксы по AS-номерам в `prefixes/asNNNNN.txt`.
3. `aggregate_prefixes.py` — агрегирует и схлопывает в
   `allowed_ips_final.txt` / `allowed_ips_oneline.txt`.
4. `build_conf.sh` — собирает `profile2_split.conf` из
   `profile2_split.conf.template`; если конфиг уже есть — **обновляет только
   строку `AllowedIPs`**, остальные поля (`PrivateKey`, `Address`, …) не трогает.
5. `generate_qr.sh` — QR-код для мобильного клиента.

`setup.sh` ставит зависимости (проверяет `curl`, `jq`, `dig`, `python3`,
поднимает `.venv`), повторный запуск безопасен.

## Структура

- `services.conf` — единственный файл, который правит пользователь
- `prefixes/` — выгрузки префиксов по AS
- `allowed_ips_final.txt`, `allowed_ips_oneline.txt` — результат агрегации
- `profile2_split.conf.template` — шаблон клиентского конфига
- README содержит **готовую строку `AllowedIPs`** между маркерами
  `<!-- BEGIN_ALLOWED_IPS -->` / `<!-- END_ALLOWED_IPS -->` — при обновлении
  списка обновлять и её, иначе README расходится с генератором

## Особенности

- AS-номера сервисов ищутся на bgp.tools / radar.cloudflare.com.
- Скрипты на `zsh`, рассчитаны на macOS.
- Готовый клиентский конфиг (`profile2_split.conf`) — личный файл с ключами,
  в git не коммитится.
