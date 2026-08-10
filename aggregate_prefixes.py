"""
Агрегация IPv4+IPv6 префиксов для WireGuard split-tunnel профиля.

Читает:
  services.conf         — конструктор: какие сервисы (и их AS) включены
  prefixes/asNNNNN.txt  — префиксы по AS (заполняются fetch_prefixes.sh)

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


def parse_services_conf() -> dict[str, list[str]]:
    """services.conf -> {service_name: [as_numbers]}. Пропускает комментарии и пустые строки."""
    config = ROOT / "services.conf"
    if not config.exists():
        return {}
    services: dict[str, list[str]] = {}
    for raw_line in config.read_text().splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        name, asns = parts[0], parts[1:]
        services[name] = asns
    return services


def load_prefixes(services: dict[str, list[str]]) -> set[str]:
    """Грузит префиксы только для AS из включённых сервисов."""
    raw: set[str] = set()
    missing: list[tuple[str, str]] = []
    for name, asns in services.items():
        for asn in asns:
            f = ROOT / "prefixes" / f"as{asn}.txt"
            if not f.exists():
                missing.append((name, asn))
                continue
            for line in f.read_text().splitlines():
                line = line.strip()
                if line:
                    raw.add(line)
    if missing:
        print("⚠️  Не найдены файлы префиксов для AS:")
        for name, asn in missing:
            print(f"     {name}: prefixes/as{asn}.txt")
        print("    Запустите ./fetch_prefixes.sh для скачивания.")
        print()
    return raw


def load_manual_prefixes() -> set[str]:
    """Грузит prefixes/manual.txt — префиксы для сервисов, живущих не в своей AS.

    Нужен, когда сервис размещён на общем CDN (Fastly, Cloudflare, CloudFront):
    добавить всю AS такого CDN нельзя, но выделенный блок провайдера — можно.
    Файл не перезаписывается fetch_prefixes.sh.
    """
    f = ROOT / "prefixes" / "manual.txt"
    if not f.exists():
        return set()
    manual = {
        line
        for raw_line in f.read_text().splitlines()
        if (line := raw_line.split("#", 1)[0].strip())
    }
    if manual:
        print(f"Ручных префиксов из manual.txt: {len(manual)}")
    return manual


def main() -> None:
    services = parse_services_conf()
    if not services:
        print("ОШИБКА: services.conf не найден или пустой.")
        print("Создайте файл и пропишите включённые сервисы — см. README.")
        return

    print(f"Включённые сервисы ({len(services)}): {', '.join(services.keys())}")
    raw = load_prefixes(services)
    raw |= load_manual_prefixes()
    if not raw:
        print("Префиксы не загружены. Сначала ./fetch_prefixes.sh")
        return
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
        v4_others = [n for n in v4_merged if n != DNS_PREFIX]
        v4_final = [DNS_PREFIX] + v4_others
        print(f"Добавлен {DNS_PREFIX} первой строкой (DNS через туннель)")

    final = v4_final + list(v6_merged)
    total = len(final)

    final_path = ROOT / "allowed_ips_final.txt"
    oneline_path = ROOT / "allowed_ips_oneline.txt"
    oneline_str = ",".join(str(n) for n in final)
    final_path.write_text("\n".join(str(n) for n in final) + "\n")
    oneline_path.write_text(oneline_str)

    sync_readme(oneline_str)

    print()
    print("Готово:")
    print(f"  {final_path.name} — {total} строк")
    print(f"  {oneline_path.name} — {total} префиксов одной строкой")
    print(f"  Сжатие: {len(raw)} -> {total} ({(1 - total/len(raw))*100:.1f}%)")


def sync_readme(oneline: str) -> None:
    """Обновляет блок AllowedIPs внутри README.md между маркерами BEGIN/END_ALLOWED_IPS."""
    import re
    readme = ROOT / "README.md"
    if not readme.exists():
        return
    text = readme.read_text()
    start = "<!-- BEGIN_ALLOWED_IPS -->"
    end = "<!-- END_ALLOWED_IPS -->"
    if start not in text or end not in text:
        return  # маркеры отсутствуют — пропускаем
    block = f"{start}\n```text\n{oneline}\n```\n{end}"
    new_text = re.sub(
        re.escape(start) + r".*?" + re.escape(end),
        block,
        text,
        count=1,
        flags=re.DOTALL,
    )
    if new_text != text:
        readme.write_text(new_text)
        print(f"  README.md — синхронизирован блок AllowedIPs ({len(oneline)} символов)")


if __name__ == "__main__":
    main()
