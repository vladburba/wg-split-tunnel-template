# WireGuard Split-Tunnel Template (Telegram + YouTube + WhatsApp)

Готовый список IP для split-tunnel WireGuard. Через VPN идут только **Telegram, YouTube,
WhatsApp** — остальное мимо туннеля.

> Чтобы это применить, у вас уже должен быть **рабочий WireGuard-сервер** и **рабочий конфиг
> клиента** (full-tunnel). Этот шаблон **ничего на сервере не меняет** — он только подсказывает,
> что писать в `AllowedIPs` на стороне клиента.

---

## ⚡ Самый простой путь — без установки чего-либо

**Достаточно скопировать одну строку из этого репо в ваш конфиг.**

1. Откройте файл [`allowed_ips_oneline.txt`](allowed_ips_oneline.txt) — внутри одна длинная
   строка ~1600 символов через запятую. Это уже агрегированный список префиксов
   `1.1.1.1/32` + AS Telegram + AS Google/YouTube + AS Meta/WhatsApp.
2. **Скопируйте** всё содержимое файла.
3. Сделайте **копию** вашего рабочего `.conf` (например, `wg-split.conf`). Оригинал
   full-tunnel **не трогайте** — он ещё пригодится (см. «Что не работает» ниже).
4. В копии в секции `[Peer]` замените строку `AllowedIPs = 0.0.0.0/0,::/0` (или похожую)
   на:

   ```ini
   AllowedIPs = <скопированное содержимое allowed_ips_oneline.txt>
   ```

5. В секции `[Interface]` убедитесь, что есть строка `DNS = 1.1.1.1`. Если нет — **добавьте**.
6. Импортируйте `wg-split.conf` в WireGuard app как **новый** профиль:
   - **iPhone / Android**: `+` → «Создать из файла» (или передайте файл на телефон).
   - **macOS / Windows / Linux**: «Add Tunnel» → «Import from file».

Всё. Telegram, YouTube, WhatsApp идут через VPN, остальное — напрямую.

> **Зачем `DNS = 1.1.1.1`?** Без него провайдер перехватывает DNS-запросы и подменяет ответы —
> сайты ломаются по доменам, даже когда все правильные IP в списке. `1.1.1.1/32` уже включён
> в наш `AllowedIPs`, чтобы DNS-трафик шёл через туннель.

---

## Что НЕ работает — важное ограничение

Видеосайты-агрегаторы (типа livetv.ru, kinogo) подгружают плеер и контент с десятков
постоянно меняющихся CDN. IP-список под такие сайты не подобрать — главная страница
загрузится, а кнопка «play» не сработает.

**Решение:** для таких сайтов на телефоне переключайтесь на full-tunnel профиль (тот, который
у вас уже работал). Посмотрел — вернулся на split-tunnel для повседневности. В WireGuard
app — один тап.

---

## Чем отличается от других решений

| Если у вас… | Берите |
|---|---|
| Нет своего VPN-сервера, хотите полный антизапрет из коробки | [AntiZapret-VPN](https://github.com/GubernievS/AntiZapret-VPN) (650 ⭐) — ставит сервер + список РКН |
| Свой список IP, нужно его агрегировать в `AllowedIPs` | [WireGuard-AllowedIPs-Calculator](https://github.com/MagomedovTimur/WireGuard-AllowedIPs-Calculator) и аналоги — general-purpose калькуляторы |
| **Свой WG-сервер уже работает**, нужен **второй split-tunnel профиль** именно под TG/YT/WA — без перенастройки сервера | **Этот шаблон** |

---

## Если нужна автоматизация (скрипты + QR)

Вместо ручного копирования можно прогнать готовый pipeline: установка зависимостей →
актуализация префиксов → сборка `.conf` → генерация QR.

### Prerequisites

- macOS или Linux с zsh/bash.
- `python3` (3.9+), `curl`, `jq`, `dig` — обычно уже есть.
- `qrencode` — `setup.sh` сам поставит через Homebrew (Mac) или попросит вручную (Linux).
- Существующий **рабочий** WireGuard клиентский конфиг — оттуда возьмёте `PrivateKey`,
  `Address`, `PublicKey` сервера, `Endpoint`.

### Quick start

```zsh
git clone https://github.com/<USERNAME>/wg-split-tunnel-template.git
cd wg-split-tunnel-template

# 1. Зависимости (qrencode + Python venv + netaddr)
./setup.sh

# 2. (Опционально) обновить снапшот префиксов из RIPEstat
source .venv/bin/activate
./fetch_prefixes.sh
python aggregate_prefixes.py

# 3. Создать profile2_split.conf и подставить AllowedIPs
./build_conf.sh

# 4. Заполнить ключи в profile2_split.conf:
#    PrivateKey, Address  — ваши, из существующего клиентского профиля
#    PublicKey, Endpoint  — параметры вашего сервера
#    PresharedKey         — если есть; если нет — удалите строку
#    DNS = 1.1.1.1        — оставьте как есть
$EDITOR profile2_split.conf

# 5. Сгенерировать QR
./generate_qr.sh

# 6. На телефоне: WireGuard → "+" → "Создать с QR-кодом" → наведите на QR.
```

### Регенерация (если AS обновили префиксы)

Когда-нибудь Telegram/Google/Meta добавят новые подсети, и сообщения перестанут идти —
обновить:

```zsh
source .venv/bin/activate
./fetch_prefixes.sh           # обновляет prefixes/*.txt
python aggregate_prefixes.py  # пересчитывает allowed_ips_*.txt
./build_conf.sh               # обновляет AllowedIPs в .conf (ключи сохраняются)
./generate_qr.sh              # новый QR
# На телефоне: удалить старый split-профиль, отсканировать новый QR.
```

---

## Архитектурное замечание

`AllowedIPs` — это **локальная routing table клиента**. Сервер не знает, что у клиента в
этом списке. Поэтому **тот же peer + те же ключи + другой `AllowedIPs`** = валидный
split-tunnel профиль. Сервер перенастраивать не нужно.

---

## Безопасность

- `*.conf` и `*.png` **исключены `.gitignore`** — они содержат ваш приватный ключ.
  **Не коммитьте их.**
- Если форкнули репо — перед каждым `git push` проверяйте `git status` и `git diff --cached`.
- Этот шаблон **никуда ничего не передаёт** — всё работает локально.
- После того как QR отсканирован на телефон — `profile2_split.png` можно удалить.

---

## Структура

| Файл | Что |
|---|---|
| `allowed_ips_oneline.txt` | **Готовая строка для `AllowedIPs`** (для самого простого пути) |
| `setup.sh` | Установка зависимостей |
| `fetch_prefixes.sh` | Скачивает префиксы AS из RIPEstat |
| `aggregate_prefixes.py` | `cidr_merge` v4+v6, гарантирует `1.1.1.1/32` |
| `build_conf.sh` | Создаёт `profile2_split.conf` из шаблона |
| `generate_qr.sh` | Делает PNG + ANSI QR из `.conf` |
| `prefixes/asNNNNN.txt` | Снапшот префиксов AS |
| `profile2_split.conf.template` | Шаблон с плейсхолдерами `<PASTE_FROM_PROFILE_1>` |

---

## Лицензия

[MIT](LICENSE).
