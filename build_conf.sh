#!/bin/zsh
# Создаёт profile2_split.conf из шаблона и подставляет AllowedIPs.
# Если profile2_split.conf уже существует — обновляет только строку AllowedIPs,
# остальные поля (PrivateKey, Address, и т.д.) не трогает.
set -e

if [ ! -f allowed_ips_oneline.txt ]; then
  echo "ОШИБКА: allowed_ips_oneline.txt не найден."
  echo "Сначала запустите: source .venv/bin/activate && python aggregate_prefixes.py"
  exit 1
fi

if [ ! -f profile2_split.conf ]; then
  echo "Создаю profile2_split.conf из шаблона..."
  cp profile2_split.conf.template profile2_split.conf
fi

if [ ! -d .venv ]; then
  echo "ОШИБКА: .venv/ не найден. Запустите ./setup.sh"
  exit 1
fi

.venv/bin/python <<'PY'
from pathlib import Path
import re
conf = Path('profile2_split.conf').read_text()
allowed = Path('allowed_ips_oneline.txt').read_text().strip()
new = re.sub(r'^AllowedIPs = .*$', 'AllowedIPs = ' + allowed, conf, flags=re.MULTILINE)
Path('profile2_split.conf').write_text(new)
print(f'AllowedIPs обновлён: {len(allowed)} символов, {allowed.count(",") + 1} префиксов')
PY

echo ""
echo "Дальше:"
echo "  1. Откройте profile2_split.conf и подставьте свои ключи на места <PASTE_FROM_PROFILE_1>"
echo "  2. Запустите: ./generate_qr.sh"
