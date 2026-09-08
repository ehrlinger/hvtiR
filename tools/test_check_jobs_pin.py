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


CHECKOUT = """jobs:
  check:
    steps:
      - uses: actions/checkout@v4
      - uses: actions/checkout@v4
        with:
          repository: ehrlinger/hvtiR
          ref: {ref}
          path: .hvtiR
      - name: after
        run: echo done
"""


class GraceTests(unittest.TestCase):
    def run_main(self, cur, tag, ahead, grace=7, consumers=(),
                 tag_age=None):
        with TemporaryDirectory() as tmp:
            c = Path(tmp) / "c.json"; c.write_text(json.dumps(cur))
            t = Path(tmp) / "t.json"; t.write_text(json.dumps(tag))
            argv = ["check_jobs_pin.py", "--current", str(c), "--tagged",
                    str(t), "--tag", "v1.1.5", "--ahead-days", str(ahead),
                    "--grace-days", str(grace)]
            for spec in consumers:
                argv += ["--consumer", spec]
            if tag_age is not None:
                argv += ["--tag-age-days", str(tag_age)]
            import contextlib, io, sys
            buf = io.StringIO()
            old = sys.argv; sys.argv = argv
            try:
                with contextlib.redirect_stdout(buf):
                    code = cjp.main()
            finally:
                sys.argv = old
            return code, buf.getvalue()

    def consumer(self, tmp, label, ref):
        path = Path(tmp) / f"{label}.yaml"
        path.write_text(CHECKOUT.format(ref=ref))
        return f"{label}={path}"

    SAME = staticmethod(lambda: rows(("ac", None, "x")))
    AHEAD = staticmethod(lambda: rows(("ac", None, "x"), ("mi", None, "n")))

    def test_matching_the_tag_alone_is_PENDING_not_CURRENT(self):
        # The bug this file exists to prevent: `main == newest tag` says a tag
        # containing the catalog EXISTS, not that anything checks it out.
        # Returning CURRENT here closed the alarm halfway through the remedy.
        code, out = self.run_main(self.SAME(), self.SAME(), ahead=99)
        self.assertEqual(code, cjp.PENDING)
        self.assertIn("unverified", out)

    def test_CURRENT_only_when_every_consumer_pins_the_newest_tag(self):
        with TemporaryDirectory() as tmp:
            spec = self.consumer(tmp, "R-CMD-check", "v1.1.5")
            code, out = self.run_main(self.SAME(), self.SAME(), ahead=99,
                                      consumers=[spec])
            self.assertEqual(code, cjp.CURRENT)
            self.assertIn("every consumer pins it", out)

    def test_a_consumer_left_on_an_older_tag_is_DRIFT(self):
        with TemporaryDirectory() as tmp:
            spec = self.consumer(tmp, "R-CMD-check", "v1.1.4")
            code, out = self.run_main(self.SAME(), self.SAME(), ahead=99,
                                      consumers=[spec], tag_age=30)
            self.assertEqual(code, cjp.DRIFT)
            self.assertIn("`v1.1.4`", out)
            self.assertIn("only half the remedy", out)

    def test_one_stale_consumer_among_several_still_reports(self):
        with TemporaryDirectory() as tmp:
            ok = self.consumer(tmp, "spec-counts", "v1.1.5")
            bad = self.consumer(tmp, "R-CMD-check", "v1.1.4")
            code, out = self.run_main(self.SAME(), self.SAME(), ahead=99,
                                      consumers=[ok, bad], tag_age=30)
            self.assertEqual(code, cjp.DRIFT)
            self.assertIn("R-CMD-check", out)
            self.assertNotIn("`spec-counts` pins", out)

    def test_a_consumer_that_cannot_be_read_is_PENDING_not_CURRENT(self):
        # An unverifiable pin is not a verified one; closing the alarm on a
        # failed fetch is the same defect in a different coat.
        code, out = self.run_main(self.SAME(), self.SAME(), ahead=99,
                                  consumers=["R-CMD-check=/nonexistent.yaml"])
        self.assertEqual(code, cjp.PENDING)
        self.assertIn("could not be read", out)

    def test_a_freshly_cut_tag_gives_consumers_grace(self):
        with TemporaryDirectory() as tmp:
            spec = self.consumer(tmp, "R-CMD-check", "v1.1.4")
            code, out = self.run_main(self.SAME(), self.SAME(), ahead=99,
                                      consumers=[spec], tag_age=1)
            self.assertEqual(code, cjp.PENDING)
            self.assertIn("grace period", out)

    def test_catalog_drift_inside_grace_is_PENDING(self):
        code, out = self.run_main(self.AHEAD(), self.SAME(), ahead=2)
        self.assertEqual(code, cjp.PENDING)
        self.assertIn("grace period", out)

    def test_catalog_drift_past_grace_reports_and_returns_DRIFT(self):
        code, out = self.run_main(self.AHEAD(), self.SAME(), ahead=30)
        self.assertEqual(code, cjp.DRIFT)
        self.assertIn("moved past `v1.1.5`", out)
        self.assertIn("`mi`", out)
        self.assertIn("R-CMD-check.yaml", out)
        self.assertIn("spec-counts.yaml", out)

    def test_the_grace_boundary_is_not_off_by_one(self):
        self.assertEqual(self.run_main(self.AHEAD(), self.SAME(),
                                       ahead=6)[0], cjp.PENDING)
        self.assertEqual(self.run_main(self.AHEAD(), self.SAME(),
                                       ahead=7)[0], cjp.DRIFT)


class ExtractPinnedRefTests(unittest.TestCase):
    def test_reads_the_ref_of_the_step_naming_this_repository(self):
        self.assertEqual(cjp.extract_pinned_ref(CHECKOUT.format(ref="v1.1.5")),
                         "v1.1.5")

    def test_quoted_refs_are_unquoted(self):
        self.assertEqual(
            cjp.extract_pinned_ref(CHECKOUT.format(ref="'v1.1.5'")), "v1.1.5")

    def test_a_checkout_with_no_ref_is_None_not_a_pin(self):
        # No ref means the default branch, which is not a pin at all. It must
        # not compare equal to the newest tag by accident.
        text = "".join(line for line in
                       CHECKOUT.format(ref="v1").splitlines(True)
                       if "ref:" not in line)
        self.assertIsNone(cjp.extract_pinned_ref(text))

    def test_an_unrelated_checkouts_ref_is_not_borrowed(self):
        text = """jobs:
  check:
    steps:
      - uses: actions/checkout@v4
        with:
          repository: someone/else
          ref: v9.9.9
"""
        self.assertIsNone(cjp.extract_pinned_ref(text))

    def test_a_later_steps_ref_does_not_leak_into_an_earlier_block(self):
        text = """jobs:
  check:
    steps:
      - uses: actions/checkout@v4
        with:
          repository: ehrlinger/hvtiR
          path: .hvtiR
      - uses: actions/checkout@v4
        with:
          repository: someone/else
          ref: v9.9.9
"""
        self.assertIsNone(cjp.extract_pinned_ref(text))


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
