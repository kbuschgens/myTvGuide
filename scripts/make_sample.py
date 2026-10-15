#!/usr/bin/env python3
"""Genereert docs/sample.json met fictieve programmering rond het huidige tijdstip."""
import json, sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

root = Path(__file__).resolve().parent.parent
cfg = json.loads((root / "pipeline" / "channels.json").read_text())
now = datetime.now(timezone.utc).replace(second=0, microsecond=0)
start0 = now.replace(minute=0) - timedelta(hours=6)
iso = lambda d: d.strftime("%Y-%m-%dT%H:%M:%SZ")

titles = ["Voorbeeldjournaal", "Fictieve Quiz", "Demo Drama", "Testkeuken", "Proefreportage",
          "Dummy Sport", "Sample Show", "Placeholder Film", "Mock Magazine", "Specimen Talkshow"]
lengths = [25, 30, 45, 50, 60, 90, 120]

channels = []
for ci, ch in enumerate(cfg["channels"]):
    t, i, programs = start0, ci, []
    while t < start0 + timedelta(hours=36):
        dur = lengths[(i * 3 + ci) % len(lengths)]
        end = t + timedelta(minutes=dur)
        title = titles[(i + ci) % len(titles)]
        programs.append({"start": iso(t), "end": iso(end), "title": title,
                         "description": f"Fictieve beschrijving van {title} op {ch['name']}."})
        t, i = end, i + 1
    channels.append({"id": ch["id"], "name": ch["name"], "logo": f"logos/{ch['logoFile']}",
                     "app": ch["app"], "scheme": ch["scheme"], "programs": programs})

out = root / "docs" / "sample.json"
out.write_text(json.dumps({"version": 1, "generatedAt": iso(now), "channels": channels}, indent=1, ensure_ascii=False))
print(f"geschreven: {out}")
