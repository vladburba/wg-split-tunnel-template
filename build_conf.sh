#!/bin/zsh
# Подставляет свежий AllowedIPs в клиентский .conf.
#
#   ./build_conf.sh                      — работает с ./profile2_split.conf
#                                          (создаст из шаблона, если его нет)
#   ./build_conf.sh /путь/к/файла.conf   — обновляет указанный существующий конфиг
#
# Меняется ТОЛЬКО строка AllowedIPs. Ключи, адрес, endpoint и всё остальное
# остаются как были — файл правится на месте, ничего не пересоздаётся.
set -e

TARGET="${1:-profile2_split.conf}"

if [ ! -f allowed_ips_oneline.txt ]; then
  echo "ОШИБКА: allowed_ips_oneline.txt не найден."
  echo "Сначала: source .venv/bin/activate && python aggregate_prefixes.py"
  exit 1
fi

if [ ! -d .venv ]; then
  echo "ОШИБКА: .venv/ не найден. Запустите ./setup.sh"
  exit 1
fi

# Свой конфиг создаём из шаблона; чужой путь — только обновляем, не создаём,
# чтобы опечатка в пути не породила мусорный файл вместо правки нужного.
if [ ! -f "$TARGET" ]; then
  if [ "$TARGET" = "profile2_split.conf" ]; then
    echo "Создаю profile2_split.conf из шаблона..."
    cp profile2_split.conf.template profile2_split.conf
  else
    echo "ОШИБКА: файл не найден — $TARGET"
    echo "Укажите путь к существующему .conf (создавать чужие файлы скрипт не будет)."
    exit 1
  fi
fi

TARGET="$TARGET" .venv/bin/python <<'PY'
from pathlib import Path
import os, re, sys

target = Path(os.environ['TARGET'])
conf = target.read_text()
allowed = Path('allowed_ips_oneline.txt').read_text().strip()

if not re.search(r'^AllowedIPs = ', conf, flags=re.MULTILINE):
    sys.exit(f'ОШИБКА: в {target} нет строки AllowedIPs — это точно клиентский конфиг?')

new = re.sub(r'^AllowedIPs = .*$', 'AllowedIPs = ' + allowed, conf, flags=re.MULTILINE)
if new == conf:
    print(f'{target.name}: AllowedIPs уже актуален, файл не тронут')
else:
    target.write_text(new)
    print(f'{target.name}: AllowedIPs обновлён — {allowed.count(",") + 1} префиксов')
PY

echo ""
echo "Дальше:"
echo "  • телефон  — ./generate_qr.sh, пересканировать QR"
echo "  • мак / ПК — переимпортировать файл в WireGuard"
echo "  • проверка — ./check_split.sh"
