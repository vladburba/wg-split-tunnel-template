#!/bin/zsh
set -e
if ! command -v qrencode > /dev/null; then
  echo "Установи qrencode: brew install qrencode"
  exit 1
fi
qrencode -t png -o profile2_split.png -s 6 < profile2_split.conf
qrencode -t ansiutf8 < profile2_split.conf
echo "QR сохранён: profile2_split.png"
