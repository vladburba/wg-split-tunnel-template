# WireGuard Split-Tunnel Template (Telegram + YouTube + WhatsApp)

Шаблон для генерации **второго** WireGuard-профиля с маршрутизацией только нужного трафика
через VPN: **Telegram, YouTube/Google, WhatsApp/Meta**. Остальной трафик идёт мимо туннеля
(быстрее, и ваш реальный IP остаётся для остальных сервисов — банкингов, госуслуг и т.д.).

Инструмент собирает актуальные IPv4+IPv6 префиксы AS этих сервисов, агрегирует их через
`netaddr.cidr_merge`, формирует готовый `.conf`-файл и QR-код для импорта в WireGuard на
iPhone / Android / любом клиенте.

> **Не настраивает сервер.** Этот шаблон только готовит клиентский конфиг — у вас уже должен
> быть рабочий WireGuard-сервер и хотя бы один существующий рабочий клиент (full tunnel).

## Кому это нужно

Вы в РФ (или другой стране с блокировками), у вас уже **работает** WireGuard:
- Сервер где-то за границей.
- На телефоне (iPhone/Android) есть профиль 1 (full tunnel) — весь трафик через VPN.

Минусы full tunnel: банкинги ругаются на нездешний IP, скорость ниже, медиа-сервисы могут
показывать другую страну. Хочется второго профиля, через который идёт **только**:
- Telegram (чтобы работал)
- YouTube (чтобы работал)
- WhatsApp (чтобы работал)

…а всё остальное — напрямую через мобильный/домашний интернет.

## Что вы получите

- `profile2_split.conf` — конфиг с **вашими** ключами (берёте из существующего профиля 1) и
  готовым `AllowedIPs` ≈ 108 префиксов: 1.1.1.1 (DNS) + 7 AS Telegram/Google/Meta.
- `profile2_split.png` — QR для импорта на телефон.

## Prerequisites

- macOS или Linux с zsh/bash.
- `python3` (3.9+), `curl`, `jq`, `dig` — обычно уже есть.
- `qrencode` — `setup.sh` сам поставит через Homebrew (Mac) или попросит вручную (Linux).
- Существующий **рабочий** WireGuard full-tunnel профиль — оттуда возьмёте ваш `PrivateKey`,
  `Address`, `PublicKey` сервера, `Endpoint`.

## Quick start

```zsh
git clone https://github.com/<USERNAME>/wg-split-tunnel-template.git
cd wg-split-tunnel-template

# 1. Установка зависимостей (qrencode + Python venv + netaddr)
./setup.sh

# 2. (Опционально) Обновить префиксы — снапшот в репо может устареть.
#    Если Telegram внезапно перестанет работать через профиль 2 — начните отсюда.
source .venv/bin/activate
./fetch_prefixes.sh
python aggregate_prefixes.py

# 3. Создать конфиг и подставить AllowedIPs
./build_conf.sh

# 4. Заполнить ключи в profile2_split.conf:
#    - PrivateKey, Address    — ваши, из существующего клиентского профиля
#    - PublicKey, Endpoint    — параметры вашего сервера, тоже из профиля 1
#    - PresharedKey           — если есть в профиле 1; если нет — удалите строку
#    - DNS                    — оставьте 1.1.1.1
$EDITOR profile2_split.conf

# 5. Сгенерировать QR
./generate_qr.sh

# 6. На телефоне: WireGuard app → "+" → "Создать с QR-кодом" → наведите на QR.
#    Старый full-tunnel профиль 1 не удаляйте — он пригодится (см. ниже).
```

## Архитектурное замечание

`AllowedIPs` — это **локальная routing table клиента**. Сервер не знает, что у клиента в
этом списке. Поэтому **тот же peer + те же ключи + другой `AllowedIPs`** = валидный
split-tunnel профиль. Сервер нечего перенастраивать.

`1.1.1.1/32` обязательно в `AllowedIPs` — иначе DNS-запросы к Cloudflare идут мимо туннеля,
провайдер их перехватывает и подменяет, и Telegram/YouTube ломаются по доменам, даже когда
все правильные IP уже в списке. Скрипт агрегации это гарантирует автоматически.

## Что НЕ работает — известное ограничение

Видеосайты-агрегаторы (типа livetv.ru, kinogo) подгружают плеер и контент с десятков
постоянно меняющихся CDN. IP-список под такие сайты не подобрать — всегда что-то из
третьесторонних ресурсов будет блокироваться. Главная страница загрузится, кнопка «play» —
не сработает.

**Решение:** для таких сайтов на телефоне переключайтесь на full-tunnel профиль 1. Посмотрел —
вернул split-tunnel профиль 2 для повседневной жизни. В WireGuard app один тап.

## Регенерация (если AS обновили префиксы)

Когда-нибудь Telegram/Google/Meta добавят новые подсети, и сообщения перестанут идти.
Обновить:

```zsh
source .venv/bin/activate
./fetch_prefixes.sh           # перезагружает prefixes/*.txt
python aggregate_prefixes.py  # перегенерирует allowed_ips_*.txt
./build_conf.sh               # обновляет AllowedIPs в profile2_split.conf (ключи остаются)
./generate_qr.sh              # новый QR
# На телефоне: удалить старый split-профиль, отсканировать новый QR.
```

## Безопасность

- `profile2_split.conf` и `profile2_split.png` **исключены `.gitignore`** — они содержат
  ваш приватный ключ. **Не коммитьте их.**
- Если форкнули репо — перед каждым `git push` проверяйте `git status` и `git diff --cached`.
- Этот шаблон **не использует и никуда не передаёт** ваши ключи — всё локально на вашей
  машине.
- После того как QR отсканирован на телефон — `profile2_split.png` можно удалить.
- `profile2_split.conf` оставьте — он понадобится для регенерации, ключи в нём защищены
  правами доступа на вашей файловой системе.

## Структура

| Файл | Что |
|---|---|
| `setup.sh` | Установка зависимостей (qrencode, Python venv, netaddr) |
| `fetch_prefixes.sh` | Скачивает префиксы AS из RIPEstat в `prefixes/` |
| `aggregate_prefixes.py` | `cidr_merge` v4+v6, гарантирует `1.1.1.1/32` |
| `build_conf.sh` | Создаёт `profile2_split.conf` из шаблона, подставляет `AllowedIPs` |
| `generate_qr.sh` | Делает PNG + ANSI QR из готового `.conf` |
| `prefixes/asNNNNN.txt` | Текущий снапшот префиксов AS |
| `allowed_ips_*.txt` | Результат агрегации |
| `profile2_split.conf.template` | Шаблон с плейсхолдерами `<PASTE_FROM_PROFILE_1>` |

## Лицензия

[MIT](LICENSE).
