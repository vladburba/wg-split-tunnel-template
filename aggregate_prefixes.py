"""
Агрегация IPv4+IPv6 префиксов для WireGuard split-tunnel профиля.

Читает:
  prefixes/*.txt        — префиксы по AS (один на строку)
  domains_resolved.txt  — опционально: IP-ы доменов в формате CIDR (/32, /128).
                          Создавай этот файл, если нужно добавить специфические IP.

Пишет:
  allowed_ips_final.txt    — по одному префиксу на строку
                             (1.1.1.1/32 первой строкой, далее IPv4 отсортированно, далее IPv6)
  allowed_ips_oneline.txt  — одной строкой через запятую (готово для AllowedIPs)

Запуск (внутри активированного venv):
  python aggregate_prefixes.py
"""
from pathlib import Path
from netaddr import IPNetwork, cidr_merge

ROOT = Path(__file__).resolve().parent
DNS_PREFIX = IPNetwork("1.1.1.1/32")


def load_prefixes() -> set[str]:
    raw: set[str] = set()
    for p in (ROOT / "prefixes").glob("*.txt"):
        for line in p.read_text().splitlines():
            line = line.strip()
            if line:
                raw.add(line)
    domains = ROOT / "domains_resolved.txt"
    if domains.exists():
        for line in domains.read_text().splitlines():
            line = line.strip()
            if line:
                raw.add(line)
    return raw


def main() -> None:
    raw = load_prefixes()
    print(f"Уникальных префиксов на входе: {len(raw)}")

    v4_in: list[IPNetwork] = []
    v6_in: list[IPNetwork] = []
    for cidr in raw:
        net = IPNetwork(cidr)
        (v4_in if net.version == 4 else v6_in).append(net)
    print(f"  IPv4: {len(v4_in)}, IPv6: {len(v6_in)}")

    v4_merged = cidr_merge(v4_in)
    v6_merged = cidr_merge(v6_in)
    print(
        f"После cidr_merge: "
        f"IPv4 {len(v4_in)} -> {len(v4_merged)}, "
        f"IPv6 {len(v6_in)} -> {len(v6_merged)}"
    )

    # 1.1.1.1/32 — DNS через туннель. Без него провайдер перехватит DNS-запросы.
    dns_covered = any(DNS_PREFIX in net for net in v4_merged)
    if dns_covered:
        print(f"{DNS_PREFIX} уже покрыт существующим префиксом")
        v4_final = list(v4_merged)
    else:
        # Удаляем dns из списка (на случай дублей) и кладём первой строкой.
        v4_others = [n for n in v4_merged if n != DNS_PREFIX]
        v4_final = [DNS_PREFIX] + v4_others
        print(f"Добавлен {DNS_PREFIX} первой строкой (DNS через туннель)")

    final = v4_final + list(v6_merged)
    total = len(final)

    final_path = ROOT / "allowed_ips_final.txt"
    oneline_path = ROOT / "allowed_ips_oneline.txt"
    final_path.write_text("\n".join(str(n) for n in final) + "\n")
    oneline_path.write_text(",".join(str(n) for n in final))

    print()
    print("Готово:")
    print(f"  {final_path.name} — {total} строк")
    print(f"  {oneline_path.name} — {total} префиксов одной строкой")
    print(f"  Сжатие: {len(raw)} -> {total} ({(1 - total/len(raw))*100:.1f}%)")


if __name__ == "__main__":
    main()
