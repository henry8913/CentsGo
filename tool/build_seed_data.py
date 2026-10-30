#!/usr/bin/env python3
"""Build the bundled CentsGo seed dataset from official MIMIT open data.

Usage:
    python3 tool/build_seed_data.py <anagrafica_impianti_attivi.csv> <prezzo_alle_8.csv>

The two CSV files are published daily by the Italian Ministry of Enterprises and
Made in Italy (MIMIT) "Osservaprezzi carburanti" open data service:

    https://www.mimit.gov.it/images/exportCSV/anagrafica_impianti_attivi.csv
    https://www.mimit.gov.it/images/exportCSV/prezzo_alle_8.csv

Output: assets/data/stations.json (compact, offline, read-only snapshot).

The snapshot is a *point in time* copy: CentsGo reads it as its offline seed.
Regenerate it (and rebuild the app) to publish updated prices; the live refresh
from the same public endpoints is tracked in docs/ROADMAP.md.
"""

from __future__ import annotations

import collections
import csv
import datetime as dt
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "data", "stations.json")

# Canonical fuel families shown by the app. Everything else is folded in so a
# station that only sells a premium variant still has a usable price.
CANONICAL = ["Benzina", "Gasolio", "GPL", "Metano", "HVO"]


def canon(fuel: str) -> str | None:
    f = fuel.strip().lower()
    if not f:
        return None
    if "hvo" in f or "rehvo" in f or "bchvo" in f or f.startswith("f101") or f.startswith("f-101"):
        return "HVO"
    if "gnl" in f or "gnc" in f or "metano" in f:
        return "Metano"
    if "gpl" in f:
        return "GPL"
    if "gasolio" in f or "diesel" in f:
        return "Gasolio"
    if "benzina" in f or "verde" in f or "v-power" in f.split()[:1] or "ottani" in f:
        return "Benzina"
    return None


HIGHWAYS = {
    "A1": "Milano - Napoli",
    "A2": "Autostrada del Mediterraneo",
    "A3": "Napoli - Salerno",
    "A4": "Torino - Trieste",
    "A5": "Torino - Aosta - Monte Bianco",
    "A6": "Torino - Savona",
    "A7": "Milano - Serravalle - Genova",
    "A8": "Milano - Varese",
    "A9": "Lainate - Como - Chiasso",
    "A10": "Genova - Ventimiglia",
    "A11": "Firenze - Pisa Nord",
    "A12": "Genova - Roma",
    "A13": "Bologna - Padova",
    "A14": "Bologna - Taranto",
    "A15": "Parma - La Spezia",
    "A16": "Napoli - Canosa",
    "A18": "Messina - Catania",
    "A19": "Palermo - Catania",
    "A20": "Messina - Palermo",
    "A21": "Torino - Brescia",
    "A22": "Modena - Brennero",
    "A23": "Udine - Tarvisio",
    "A24": "Roma - L'Aquila - Teramo",
    "A25": "Torino - Pescara",
    "A26": "Genova - Gravellona Toce",
    "A27": "Venezia - Belluno",
    "A28": "Conegliano - Portogruaro",
    "A29": "Palermo - Mazara del Vallo",
    "A30": "Caserta - Salerno",
    "A31": "Vicenza - Piovene Rocchette",
    "A32": "Torino - Bardonecchia",
    "A33": "Asti - Cuneo",
    "A34": "Villesse - Gorizia",
    "A35": "Brebemi",
    "A36": "Autostrada Pedemontana Lombarda",
    "A50": "Tangenziale Ovest di Milano",
    "A51": "Tangenziale Est di Milano",
    "A52": "Tangenziale Nord di Milano",
    "A54": "Tangenziale di Pavia",
    "A55": "Tangenziale di Torino",
    "A56": "Tangenziale di Napoli",
    "A57": "Tangenziale di Venezia",
    "A58": "Tangenziale Est Esterna di Milano",
    "A60": "Tangenziale di Varese",
    "A90": "Grande Raccordo Anulare di Roma",
    "A91": "Roma - Fiumicino",
}


def read_csv(path: str):
    with io.open(path, "r", encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()
    # First line is "Estrazione del YYYY-MM-DD", second is the header.
    extraction = None
    m = re.search(r"(\d{4}-\d{2}-\d{2})", lines[0]) if lines else None
    if m:
        extraction = m.group(1)
    header_idx = 1 if lines and "|" in lines[1] else 0
    header = lines[header_idx].split("|")
    rows = []
    for line in lines[header_idx + 1:]:
        if not line.strip():
            continue
        parts = line.split("|")
        if len(parts) < len(header):
            continue
        rows.append(dict(zip(header, parts)))
    return extraction, rows


def parse_dt(value: str) -> int:
    try:
        d = dt.datetime.strptime(value.strip(), "%d/%m/%Y %H:%M:%S")
        return int(d.timestamp())
    except Exception:
        return 0


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    anag_path, price_path = sys.argv[1], sys.argv[2]
    extraction, anag = read_csv(anag_path)
    _, prices = read_csv(price_path)

    by_station: dict[str, dict] = collections.defaultdict(lambda: {"self": {}, "full": {}})
    updated: dict[str, int] = {}
    for row in prices:
        sid = row["idImpianto"].strip()
        family = canon(row["descCarburante"])
        if not family:
            continue
        try:
            value = float(row["prezzo"].replace(",", "."))
        except ValueError:
            continue
        if value <= 0 or value > 20:
            continue
        bucket = "self" if row["isSelf"].strip() == "1" else "full"
        current = by_station[sid][bucket].get(family)
        if current is None or value < current:
            by_station[sid][bucket][family] = round(value, 3)
        ts = parse_dt(row.get("dtComu", ""))
        if ts > updated.get(sid, 0):
            updated[sid] = ts

    brands: list[str] = []
    brand_index: dict[str, int] = {}
    stations = []
    skipped = 0
    for row in anag:
        sid = row["idImpianto"].strip()
        try:
            lat = float(row["Latitudine"])
            lon = float(row["Longitudine"])
        except ValueError:
            skipped += 1
            continue
        if lat == 0 or lon == 0:
            skipped += 1
            continue
        price = by_station.get(sid)
        if not price or not (price["self"] or price["full"]):
            skipped += 1
            continue
        # Keep the commercial flag (Bandiera) as the filterable brand. Unbranded
        # stations stay a single "Pompe Bianche" bucket instead of exploding into
        # one pseudo-brand per company name.
        brand = row["Bandiera"].strip() or "Pompe Bianche"
        if brand not in brand_index:
            brand_index[brand] = len(brands)
            brands.append(brand)
        address = " ".join((row["Indirizzo"] or "").split())
        highway = None
        if row["Tipo Impianto"].strip() == "Autostradale":
            m = re.search(r"\b(A\d{1,2})\b", address + " " + row["Nome Impianto"])
            highway = m.group(1) if m else "A0"
        merged: dict[str, list] = {}
        for family in CANONICAL:
            self_price = price["self"].get(family)
            full_price = price["full"].get(family)
            if self_price is None and full_price is None:
                continue
            merged[family] = [self_price, full_price]
        stations.append([
            sid,
            brand_index[brand],
            " ".join((row["Nome Impianto"] or "").split()).title(),
            address,
            " ".join((row["Comune"] or "").split()).title(),
            row["Provincia"].strip(),
            round(lat, 5),
            round(lon, 5),
            highway,
            updated.get(sid, 0),
            merged,
        ])

    stations.sort(key=lambda s: (s[5], s[4], s[1]))
    payload = {
        "meta": {
            "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
            "price_extraction": extraction,
            "source": "MIMIT - Osservaprezzi carburanti (open data)",
            "source_url": "https://www.mimit.gov.it/it/open-data",
            "license": "Italian open data (IODL 2.0) - attribution required",
            "station_count": len(stations),
            "skipped": skipped,
            "note": "Offline snapshot. Prices are self/servito in EUR per litre (per kg for Metano).",
        },
        "fuels": CANONICAL,
        "brands": brands,
        "highways": {code: HIGHWAYS.get(code, code) for code in sorted({s[8] for s in stations if s[8]}, key=lambda c: (len(c), c))},
        "stations": stations,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with io.open(OUT, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, separators=(",", ":"))
    size = os.path.getsize(OUT)
    print(f"wrote {OUT} ({size/1e6:.2f} MB): {len(stations)} stations, {len(brands)} brands, skipped {skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
