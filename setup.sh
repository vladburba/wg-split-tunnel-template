#!/bin/zsh
# Установка зависимостей для генерации split-tunnel WireGuard профиля.
# Безопасно запускать повторно — пропускает уже установленное.
set -e

echo "=== 1. Проверка системных утилит ==="
for tool in curl jq dig python3; do
  if ! command -v "$tool" > /dev/null; then
    echo "ОШИБКА: $tool не найден. Установите его и запустите setup.sh заново."
    exit 1
  fi
done
echo "OK: curl, jq, dig, python3 на месте"

echo ""
echo "=== 2. Проверка qrencode (для генерации QR) ==="
if ! command -v qrencode > /dev/null; then
  if command -v brew > /dev/null; then
    echo "Устанавливаю qrencode через Homebrew..."
    brew install qrencode
  else
    echo "ВНИМАНИЕ: qrencode не найден и Homebrew недоступен."
    echo "На Linux: sudo apt install qrencode  (или yum/pacman)"
    echo "На macOS: установите Homebrew, затем повторите setup.sh"
    exit 1
  fi
else
  echo "OK: qrencode уже установлен"
fi

echo ""
echo "=== 3. Python venv ==="
if [ ! -d .venv ]; then
  python3 -m venv .venv
  echo "Создан .venv/"
else
  echo "OK: .venv/ уже существует"
fi

echo ""
echo "=== 4. Установка Python-зависимостей ==="
.venv/bin/pip install -q -r requirements.txt
echo "OK: netaddr установлен"

echo ""
echo "=== Готово ==="
echo "Дальше: см. README.md → Quick start (шаг 2 и далее)"
