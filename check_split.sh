#!/usr/bin/env bash
# Проверка split-туннеля: сверяет ОЖИДАНИЕ (из allowed_ips_oneline.txt)
# с ФАКТОМ (таблица маршрутов системы).
#
# Ничего не меняет — только читает. Работает на macOS и Linux.
#
# Запуск:
#   ./check_split.sh                          # список берётся из ./allowed_ips_oneline.txt
#   ./check_split.sh /путь/к/allowed_ips.txt  # или из указанного файла
#   ./check_split.sh -- github.com openai.com # свои хосты для проверки
#
# Ключевая идея: скрипт не знает заранее, что «должно» идти в туннель.
# Он смотрит, попадает ли адрес хоста в ваш список, и сверяет с тем,
# куда система реально шлёт пакеты. Расхождение = ошибка в конфиге.

set -uo pipefail

LIST="allowed_ips_oneline.txt"
HOSTS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --) shift; HOSTS=("$@"); break ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) LIST="$1"; shift ;;
  esac
done

if [ ! -f "$LIST" ]; then
  echo "Не найден файл со списком: $LIST"
  echo "Укажите путь первым аргументом или запустите из корня репозитория."
  exit 1
fi

if [ ${#HOSTS[@]} -eq 0 ]; then
  HOSTS=(
    api.anthropic.com claude.ai
    github.com raw.githubusercontent.com
    www.youtube.com web.telegram.org www.instagram.com
    api.openai.com wikipedia.org yandex.ru
  )
fi

command -v python3 >/dev/null || { echo "Нужен python3 (проверка попадания IP в CIDR)."; exit 1; }

# --- как узнать интерфейс для адреса: BSD/macOS и Linux по-разному ---
route_iface() {
  if route -n get "$1" >/dev/null 2>&1; then
    route -n get "$1" 2>/dev/null | awk '/interface:/{print $2; exit}'
  else
    ip route get "$1" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'
  fi
}

is_tunnel() { case "$1" in utun*|wg*|tun*) return 0 ;; *) return 1 ;; esac; }

# printf выравнивает по БАЙТАМ, а кириллица многобайтная — колонки разъезжаются.
# ${#s} в UTF-8-локали считает символы, поэтому добиваем пробелами вручную.
pad() {
  local s="$1" w="$2" out="$1"
  local n=$(( w - ${#s} ))
  while [ "$n" -gt 0 ]; do out="$out "; n=$((n-1)); done
  printf '%s' "$out"
}

resolve() {
  if command -v dig >/dev/null 2>&1; then
    dig +short "$1" A 2>/dev/null | grep -E '^[0-9]+\.' | head -1
  else
    getent hosts "$1" 2>/dev/null | awk '{print $1; exit}'
  fi
}

printf '\n=== СПИСОК ===\n'
printf '  файл: %s\n' "$LIST"
printf '  префиксов: %s\n' "$(tr ',' '\n' < "$LIST" | grep -c .)"

printf '\n=== ОЖИДАНИЕ ПРОТИВ ФАКТА ===\n'
printf '  %s%s%s%s%s\n' "$(pad 'хост' 28)" "$(pad 'адрес' 17)" "$(pad 'по списку' 11)" "$(pad 'фактически' 12)" "вердикт"
printf '  %s\n' "--------------------------------------------------------------------------------"

FAILED=0
for h in "${HOSTS[@]}"; do
  ip=$(resolve "$h")
  if [ -z "$ip" ]; then
    printf '  %-28s %s\n' "$h" "не резолвится — пропуск"
    continue
  fi

  # попадает ли адрес в список префиксов
  if python3 -c "
import ipaddress,sys
nets=[ipaddress.ip_network(x.strip()) for x in open('$LIST').read().split(',') if x.strip()]
sys.exit(0 if any(ipaddress.ip_address('$ip') in n for n in nets) else 1)
" 2>/dev/null; then in_list="туннель"; else in_list="напрямую"; fi

  ifc=$(route_iface "$ip")
  if [ -z "$ifc" ]; then actual="нет марш."
  elif is_tunnel "$ifc"; then actual="туннель"
  else actual="напрямую"; fi

  if [ "$in_list" = "$actual" ]; then verdict="ok"
  else verdict="РАСХОЖДЕНИЕ"; FAILED=$((FAILED+1)); fi

  printf '  %s%s%s%s%s (%s)\n' "$(pad "$h" 28)" "$(pad "$ip" 17)" "$(pad "$in_list" 11)" "$(pad "$actual" 12)" "$verdict" "${ifc:-—}"
done

printf '\n=== СВЯЗЬ ===\n'
for h in "${HOSTS[@]:0:3}"; do
  printf '  %-28s ' "$h"
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 12 "https://$h" 2>/dev/null)
  if [ -n "$code" ] && [ "$code" != "000" ]; then echo "отвечает (HTTP $code)"; else echo "НЕ ОТВЕЧАЕТ"; fi
done

printf '\n=== ВНЕШНИЙ АДРЕС ===\n'
ip_out=$(curl -s --max-time 12 https://api.ipify.org 2>/dev/null)
printf '  обычный сайт видит: %s\n' "${ip_out:-не определился}"
printf '  (в split-режиме здесь должен быть ваш домашний адрес,\n'
printf '   а НЕ адрес VPN-сервера — иначе туннель полный, а не выборочный)\n'

printf '\n=== ИТОГ ===\n'
if [ "$FAILED" -eq 0 ]; then
  printf '  Расхождений нет: маршруты совпадают со списком.\n\n'
else
  printf '  РАСХОЖДЕНИЙ: %s. Маршруты не соответствуют списку.\n' "$FAILED"
  printf '  Обычные причины: активен другой профиль; конфиг не переимпортирован\n'
  printf '  после пересборки списка; у сервиса сменились адреса — нужен fetch_prefixes.sh.\n\n'
fi
exit 0
