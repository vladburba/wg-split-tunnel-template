#!/bin/zsh
# Скачивает актуальные IPv4+IPv6 префиксы по 7 AS (Telegram x5, Google, Meta) из RIPEstat.
# Перезаписывает файлы в prefixes/.
set -e

mkdir -p prefixes

# Telegram x5, Google (включая YouTube), Meta (включая WhatsApp)
ASNS=(62014 62041 59930 44907 211157 15169 32934)

echo "=== Скачиваю префиксы AS из RIPEstat ==="
for ASN in "${ASNS[@]}"; do
  out="prefixes/as${ASN}.txt"
  curl -s --max-time 25 \
    "https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS${ASN}" \
    | jq -r '.data.prefixes[]?.prefix' > "$out"
  count=$(wc -l < "$out" | tr -d ' ')
  printf "  AS%-7s %4d префиксов\n" "$ASN" "$count"
  sleep 1  # rate-limit вежливость
done

echo ""
echo "Готово. Дальше: source .venv/bin/activate && python aggregate_prefixes.py"
