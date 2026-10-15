#!/usr/bin/env python3
"""Genereert een channels.xml voor iptv-org/epg (site telenet.tv) uit channels.json.

Gebruik: make_channels_xml.py <channels.json> <uit.xml>
De xmltv_id wordt gezet op sourceId (bv. VTM.be), omdat de upstream lijst voor
VRT 1 en VRT Canvas geen xmltv_id heeft.
"""
import json, sys
from xml.sax.saxutils import escape, quoteattr


def build(cfg):
    rows = ['<?xml version="1.0" encoding="UTF-8"?>', "<channels>"]
    for c in cfg["channels"]:
        rows.append(
            f'  <channel site="telenet.tv" site_id={quoteattr(c["siteId"])} lang="nl" '
            f'xmltv_id={quoteattr(c["sourceId"])}>{escape(c["name"])}</channel>'
        )
    rows.append("</channels>")
    return "\n".join(rows) + "\n"


if __name__ == "__main__":
    cfg = json.load(open(sys.argv[1]))
    open(sys.argv[2], "w", encoding="utf-8").write(build(cfg))
