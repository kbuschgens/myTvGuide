#!/usr/bin/env python3
"""XMLTV -> docs/schema.json-formaat.

Gebruik: convert.py <guide.xml> <channels.json> <uit.json> [--now ISO] [--past-hours 24] [--days 7]
Exit-code 1 als een zender geen programma's heeft (vorige publicatie blijft dan staan).
"""
import argparse, json, sys
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone


def parse_xmltv_time(s):
    s = s.strip()
    fmt = "%Y%m%d%H%M%S %z" if " " in s else "%Y%m%d%H%M%S"
    d = datetime.strptime(s, fmt)
    if d.tzinfo is None:
        d = d.replace(tzinfo=timezone.utc)
    return d.astimezone(timezone.utc)


def iso(d):
    return d.strftime("%Y-%m-%dT%H:%M:%SZ")


def normalize_id(raw):
    """VTM.be@SD -> VTM.be"""
    return (raw or "").split("@")[0]


def extract_programs(root):
    """Geeft {sourceId: [(start, end, title, desc)]}."""
    by_channel = {}
    for p in root.iter("programme"):
        cid = normalize_id(p.get("channel"))
        title = (p.findtext("title") or "").strip()
        if not cid or not title or not p.get("start") or not p.get("stop"):
            continue
        start, end = parse_xmltv_time(p.get("start")), parse_xmltv_time(p.get("stop"))
        desc = " ".join((p.findtext("desc") or "").split())
        by_channel.setdefault(cid, []).append((start, end, title, desc))
    return by_channel


def clean(programs, window_start, window_end, warnings, name):
    """Sorteren, dubbelen/ongeldige verwijderen, overlap oplossen, window toepassen."""
    programs = sorted(set(programs), key=lambda p: (p[0], p[1]))
    out = []
    for start, end, title, desc in programs:
        if end <= start:
            warnings.append(f"{name}: ongeldige duur '{title}' {iso(start)}")
            continue
        if out and start < out[-1]["_end"]:
            warnings.append(f"{name}: overlap '{out[-1]['title']}' / '{title}' opgelost")
            out[-1]["_end"] = start
            out[-1]["end"] = iso(start)
            if out[-1]["_end"] <= out[-1]["_start"]:
                out.pop()
        elif out and start > out[-1]["_end"]:
            warnings.append(f"{name}: gat {iso(out[-1]['_end'])} - {iso(start)}")
        out.append({"_start": start, "_end": end, "start": iso(start), "end": iso(end),
                    "title": title, **({"description": desc} if desc else {})})
    out = [p for p in out if p["_end"] > window_start and p["_start"] < window_end]
    for p in out:
        del p["_start"], p["_end"]
    return out


def convert(root, cfg, now, past_hours=24, days=7):
    by_channel = extract_programs(root)
    w0, w1 = now - timedelta(hours=past_hours), now + timedelta(days=days)
    warnings, channels, empty = [], [], []
    for c in cfg["channels"]:
        programs = clean(by_channel.get(c["sourceId"], []), w0, w1, warnings, c["name"])
        if not programs:
            empty.append(c["name"])
        channels.append({"id": c["id"], "name": c["name"], "logo": f"logos/{c['logoFile']}",
                         "app": c["app"], "scheme": c["scheme"], "programs": programs})
    return {"version": 1, "generatedAt": iso(now), "channels": channels}, warnings, empty


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("xmltv"); ap.add_argument("channels"); ap.add_argument("out")
    ap.add_argument("--now"); ap.add_argument("--past-hours", type=int, default=24)
    ap.add_argument("--days", type=int, default=7)
    a = ap.parse_args()
    now = (datetime.fromisoformat(a.now.replace("Z", "+00:00")) if a.now
           else datetime.now(timezone.utc)).replace(second=0, microsecond=0)
    doc, warnings, empty = convert(ET.parse(a.xmltv).getroot(), json.load(open(a.channels)),
                                   now, a.past_hours, a.days)
    for w in warnings:
        print("waarschuwing:", w, file=sys.stderr)
    if empty:
        print("FOUT: geen programma's voor: " + ", ".join(empty), file=sys.stderr)
        sys.exit(1)
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))
    print(f"geschreven: {a.out} ({sum(len(c['programs']) for c in doc['channels'])} programma's)")


if __name__ == "__main__":
    main()
