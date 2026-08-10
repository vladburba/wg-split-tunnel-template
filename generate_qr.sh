#!/bin/zsh
# Делает QR-код из клиентского .conf — для импорта на телефон сканированием.
#
#   ./generate_qr.sh                          — из ./profile2_split.conf
#   ./generate_qr.sh путь/к/файлу.conf        — из указанного конфига
#   ./generate_qr.sh файл.conf out.png        — с явным именем картинки
#   ./generate_qr.sh файл.conf --ansi         — плюс вывести QR прямо в терминал
#
# ВНИМАНИЕ: QR содержит ПОЛНЫЙ конфиг, включая приватный ключ. Кто сфотографировал
# картинку — получил доступ в вашу сеть. Поэтому:
#   • PNG создаётся с правами 600;
#   • вывод в терминал по умолчанию ВЫКЛЮЧЕН (флаг --ansi) — иначе ключ окажется
#     в истории терминала, в скроллбэке и в логах записи сессии;
#   • после сканирования картинку удалите.
set -e

if ! command -v qrencode > /dev/null; then
  echo "Нужен qrencode: brew install qrencode  (или apt install qrencode)"
  exit 1
fi

CONF="profile2_split.conf"
OUT=""
ANSI=0

for arg in "$@"; do
  case "$arg" in
    --ansi) ANSI=1 ;;
    *.png)  OUT="$arg" ;;
    *)      CONF="$arg" ;;
  esac
done

if [ ! -f "$CONF" ]; then
  echo "ОШИБКА: конфиг не найден — $CONF"
  exit 1
fi

if ! grep -q '^PrivateKey' "$CONF"; then
  echo "ОШИБКА: в $CONF нет PrivateKey — это точно клиентский конфиг?"
  exit 1
fi

[ -z "$OUT" ] && OUT="${CONF:t:r}.png"

umask 077
qrencode -t png -o "$OUT" -s 6 < "$CONF"
chmod 600 "$OUT"

echo "QR сохранён: $OUT (права 600)"
echo "Открыть и отсканировать с телефона, затем удалить картинку."

if [ "$ANSI" -eq 1 ]; then
  echo ""
  echo "!!! Ниже приватный ключ в виде QR — он останется в истории терминала !!!"
  echo ""
  qrencode -t ansiutf8 < "$CONF"
fi
