#!/usr/bin/env bash
# Скачивает IPv4+IPv6 префиксы по AS-номерам из RIPEstat.
# Источник правды — services.conf: только AS включённых сервисов.
set -e

if [ ! -f services.conf ]; then
  echo "ОШИБКА: services.conf не найден"
  exit 1
fi

# Парсим services.conf:
#   - игнорируем строки, начинающиеся с # (или пустые)
#   - срезаем inline-комментарии
#   - первое слово = имя сервиса, остальные = AS-номера
ASNS=$(awk '
  { sub(/#.*$/, "") }                # срезаем inline-комментарии
  /^[[:space:]]*$/ { next }          # пропускаем пустые
  { for (i = 2; i <= NF; i++) print $i }
' services.conf | sort -u)

if [ -z "$ASNS" ]; then
  echo "В services.conf нет включённых сервисов. Раскомментируйте хотя бы один."
  exit 1
fi

mkdir -p prefixes

echo "=== Скачиваю префиксы AS из services.conf через RIPEstat ==="
for ASN in $ASNS; do
  out="prefixes/as${ASN}.txt"
  curl -s --max-time 25 \
    "https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS${ASN}" \
    | jq -r '.data.prefixes[]?.prefix' > "$out"
  count=$(wc -l < "$out" | tr -d ' ')
  printf "  AS%-7s %4d префиксов\n" "$ASN" "$count"
  sleep 1   # вежливость к API
done

echo ""
echo "Готово. Дальше: source .venv/bin/activate && python aggregate_prefixes.py"
