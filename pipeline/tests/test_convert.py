import json, sys, unittest
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))
import convert, make_channels_xml  # noqa: E402

CFG = {"channels": [
    {"id": "vtm", "name": "VTM", "sourceId": "VTM.be", "siteId": "vtmhd", "app": "vtmgo",
     "scheme": "vtmgo://", "logoFile": "vtm-be.png"}]}
NOW = datetime(2026, 10, 15, 12, 0, tzinfo=timezone.utc)


def run(programmes, cfg=CFG):
    xml = "<tv>" + programmes + "</tv>"
    return convert.convert(ET.fromstring(xml), cfg, NOW)


def prog(start, stop, title="A", desc="", ch="VTM.be"):
    d = f"<desc>{desc}</desc>" if desc else ""
    return f'<programme start="{start}" stop="{stop}" channel="{ch}"><title>{title}</title>{d}</programme>'


class ConvertTests(unittest.TestCase):
    def test_timezone_to_utc(self):
        doc, _, _ = run(prog("20261015140000 +0200", "20261015150000 +0200"))
        p = doc["channels"][0]["programs"][0]
        self.assertEqual((p["start"], p["end"]), ("2026-10-15T12:00:00Z", "2026-10-15T13:00:00Z"))

    def test_missing_description_omitted(self):
        doc, _, _ = run(prog("20261015120000 +0000", "20261015130000 +0000"))
        self.assertNotIn("description", doc["channels"][0]["programs"][0])

    def test_description_whitespace_collapsed(self):
        doc, _, _ = run(prog("20261015120000 +0000", "20261015130000 +0000", desc="a\n  b"))
        self.assertEqual(doc["channels"][0]["programs"][0]["description"], "a b")

    def test_duplicates_removed(self):
        p = prog("20261015120000 +0000", "20261015130000 +0000")
        doc, _, _ = run(p + p)
        self.assertEqual(len(doc["channels"][0]["programs"]), 1)

    def test_overlap_resolved_and_sorted(self):
        doc, warn, _ = run(prog("20261015123000 +0000", "20261015133000 +0000", "B")
                           + prog("20261015120000 +0000", "20261015130000 +0000", "A"))
        ps = doc["channels"][0]["programs"]
        self.assertEqual([p["title"] for p in ps], ["A", "B"])
        self.assertEqual(ps[0]["end"], ps[1]["start"])
        self.assertTrue(any("overlap" in w for w in warn))

    def test_gap_warns_but_kept(self):
        doc, warn, _ = run(prog("20261015120000 +0000", "20261015130000 +0000")
                           + prog("20261015140000 +0000", "20261015150000 +0000", "B"))
        self.assertEqual(len(doc["channels"][0]["programs"]), 2)
        self.assertTrue(any("gat" in w for w in warn))

    def test_suffix_in_channel_id(self):
        doc, _, empty = run(prog("20261015120000 +0000", "20261015130000 +0000", ch="VTM.be@SD"))
        self.assertEqual(empty, [])
        self.assertEqual(len(doc["channels"][0]["programs"]), 1)

    def test_window_filters(self):
        doc, _, _ = run(prog("20260101000000 +0000", "20260101010000 +0000", "oud")
                        + prog("20261015120000 +0000", "20261015130000 +0000", "nu"))
        self.assertEqual([p["title"] for p in doc["channels"][0]["programs"]], ["nu"])

    def test_empty_channel_reported(self):
        _, _, empty = run("")
        self.assertEqual(empty, ["VTM"])

    def test_channels_xml(self):
        xml = make_channels_xml.build(CFG)
        el = ET.fromstring(xml).find("channel")
        self.assertEqual((el.get("site_id"), el.get("xmltv_id")), ("vtmhd", "VTM.be"))

    def test_output_matches_schema_if_available(self):
        try:
            import jsonschema
        except ImportError:
            self.skipTest("jsonschema ontbreekt")
        doc, _, _ = run(prog("20261015120000 +0000", "20261015130000 +0000"))
        jsonschema.validate(doc, json.load(open(ROOT / "docs" / "schema.json")))


if __name__ == "__main__":
    unittest.main()
