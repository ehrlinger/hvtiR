"""Tests for check_jobs_pin.py."""
import importlib.util
import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

_spec = importlib.util.spec_from_file_location(
    "check_jobs_pin", Path(__file__).with_name("check_jobs_pin.py"))
cjp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cjp)


def rows(*specs):
    return {"jobs": [dict(prefix=p, qualifier=q, note=n) for p, q, n in specs]}


class CompareTests(unittest.TestCase):
    def keyed(self, doc, tmp, stem):
        path = Path(tmp) / f"{stem}.json"
        path.write_text(json.dumps(doc))
        return cjp.load_rows(path)

    def test_identical_catalogs_report_nothing(self):
        with TemporaryDirectory() as tmp:
            a = self.keyed(rows(("ac", None, "x")), tmp, "a")
            b = self.keyed(rows(("ac", None, "x")), tmp, "b")
            self.assertEqual(cjp.compare(a, b),
                             {"added": [], "removed": [], "changed": []})

    def test_added_removed_and_changed_are_separated(self):
        with TemporaryDirectory() as tmp:
            cur = self.keyed(rows(("ac", None, "x"), ("mi", None, "new")),
                             tmp, "cur")
            tag = self.keyed(rows(("ac", None, "OLD"), ("gone", None, "y")),
                             tmp, "tag")
            self.assertEqual(cjp.compare(cur, tag),
                             {"added": ["mi"], "removed": ["gone"],
                              "changed": ["ac"]})

    def test_rows_are_keyed_by_prefix_AND_qualifier(self):
        # The catalog carries several rows per prefix separated only by their
        # qualifier. Keying on prefix alone keeps the last and silently drops
        # the rest, which reads as "no drift" -- the one wrong answer here.
        with TemporaryDirectory() as tmp:
            cur = self.keyed(rows(("dp", "variable", "x"), ("dp", "box", "y")),
                             tmp, "cur")
            self.assertEqual(len(cur), 2)
            tag = self.keyed(rows(("dp", "variable", "x"), ("dp", "box", "Z")),
                             tmp, "tag")
            self.assertEqual(cjp.compare(cur, tag)["changed"], ["dp-box"])


class GraceTests(unittest.TestCase):
    def run_main(self, cur, tag, ahead, grace=7):
        with TemporaryDirectory() as tmp:
            c = Path(tmp) / "c.json"; c.write_text(json.dumps(cur))
            t = Path(tmp) / "t.json"; t.write_text(json.dumps(tag))
            import contextlib, io, sys
            buf = io.StringIO()
            argv = ["check_jobs_pin.py", "--current", str(c), "--tagged",
                    str(t), "--tag", "v1.1.5", "--ahead-days", str(ahead),
                    "--grace-days", str(grace)]
            old = sys.argv; sys.argv = argv
            try:
                with contextlib.redirect_stdout(buf):
                    code = cjp.main()
            finally:
                sys.argv = old
            return code, buf.getvalue()

    def test_no_drift_is_ok(self):
        code, out = self.run_main(rows(("ac", None, "x")),
                                  rows(("ac", None, "x")), ahead=99)
        self.assertEqual(code, cjp.OK)
        self.assertIn("every pin is current", out)

    def test_drift_inside_grace_is_ok_but_still_says_so(self):
        # "Ahead, within grace" and "not ahead" must not print the same thing,
        # or the run cannot be used to tell the check is still working.
        code, out = self.run_main(rows(("ac", None, "x"), ("mi", None, "n")),
                                  rows(("ac", None, "x")), ahead=2)
        self.assertEqual(code, cjp.OK)
        self.assertIn("grace period", out)
        self.assertNotIn("every pin is current", out)

    def test_drift_past_grace_reports_and_returns_DRIFT(self):
        code, out = self.run_main(rows(("ac", None, "x"), ("mi", None, "n")),
                                  rows(("ac", None, "x")), ahead=30)
        self.assertEqual(code, cjp.DRIFT)
        self.assertIn("moved past `v1.1.5`", out)
        self.assertIn("`mi`", out)
        self.assertIn("30 day(s)", out)
        # the remedy names both pinned workflows, because they move separately
        self.assertIn("R-CMD-check.yaml", out)
        self.assertIn("spec-counts.yaml", out)

    def test_the_grace_boundary_is_not_off_by_one(self):
        payload = (rows(("ac", None, "x"), ("mi", None, "n")),
                   rows(("ac", None, "x")))
        self.assertEqual(self.run_main(*payload, ahead=6)[0], cjp.OK)
        self.assertEqual(self.run_main(*payload, ahead=7)[0], cjp.DRIFT)


class MalformedInputTests(unittest.TestCase):
    def read(self, text):
        with TemporaryDirectory() as tmp:
            p = Path(tmp) / "j.json"; p.write_text(text)
            return cjp.load_rows(p)

    def test_a_row_without_a_prefix_is_rejected(self):
        with self.assertRaises(SystemExit):
            self.read(json.dumps({"jobs": [{"name": "no prefix"}]}))

    def test_an_empty_catalog_is_rejected(self):
        # Silence must never be success: an empty file compares equal to
        # anything's absent rows and would report a clean run.
        with self.assertRaises(SystemExit):
            self.read(json.dumps({"jobs": []}))

    def test_unparseable_json_is_rejected(self):
        with self.assertRaises(SystemExit):
            self.read("{not json")

    def test_a_missing_file_is_rejected(self):
        with self.assertRaises(SystemExit):
            cjp.load_rows(Path("/nonexistent/jobs.json"))


if __name__ == "__main__":
    unittest.main()
