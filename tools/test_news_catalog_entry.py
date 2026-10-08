"""Tests for news_catalog_entry.py."""
import datetime
import importlib.util
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

_spec = importlib.util.spec_from_file_location(
    "news_catalog_entry", Path(__file__).with_name("news_catalog_entry.py"))
nce = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(nce)

HEAD = "package,repo,cran_version,dev_version\n"
def catalog(tmp, stem, *rows):
    p = Path(tmp) / f"{stem}.csv"
    p.write_text(HEAD + "".join(f"{a},ehrlinger/{a},{b},{c}\n" for a, b, c in rows))
    return p


class DescribeTests(unittest.TestCase):
    def read(self, tmp, stem, *rows):
        return nce.read_catalog(catalog(tmp, stem, *rows))

    def test_no_movement_describes_nothing(self):
        with TemporaryDirectory() as t:
            a = self.read(t, "a", ("hvtiRutilities", "", "1.1.10"))
            self.assertEqual(nce.describe(a, a), [])

    def test_a_dev_version_move_is_named_with_both_values(self):
        with TemporaryDirectory() as t:
            a = self.read(t, "a", ("hvtiRutilities", "", "1.1.10"))
            b = self.read(t, "b", ("hvtiRutilities", "", "1.1.11"))
            self.assertEqual(nce.describe(a, b),
                             ["`hvtiRutilities` dev 1.1.10 to 1.1.11"])

    def test_a_cran_move_is_distinguished_from_a_dev_move(self):
        with TemporaryDirectory() as t:
            a = self.read(t, "a", ("ggRandomForests", "3.5.2", "4.0.0"))
            b = self.read(t, "b", ("ggRandomForests", "3.5.3", "4.0.0"))
            self.assertEqual(nce.describe(a, b),
                             ["`ggRandomForests` CRAN 3.5.2 to 3.5.3"])

    def test_a_brand_new_row_is_not_reported_as_a_move(self):
        # A new row is a new member. Rendering it as "'' -> 0.1.0" would read
        # as drift in a release note, and its arrival is narrated by whoever
        # added it.
        with TemporaryDirectory() as t:
            a = self.read(t, "a", ("hvtiRutilities", "", "1.1.10"))
            b = self.read(t, "b", ("hvtiRutilities", "", "1.1.10"),
                          ("hvtiRimputation", "", "0.1.0"))
            self.assertEqual(nce.describe(a, b), [])

    def test_an_empty_catalog_is_rejected(self):
        with TemporaryDirectory() as t:
            p = Path(t) / "e.csv"; p.write_text(HEAD)
            with self.assertRaises(SystemExit):
                nce.read_catalog(p)


class FragmentPathTests(unittest.TestCase):
    DAY = datetime.date(2026, 10, 12)

    def test_the_fragment_is_dated_under_news(self):
        self.assertEqual(nce.fragment_path(Path("news"), self.DAY),
                         Path("news/chore-catalog-version-refresh-2026-10-12.md"))

    def test_a_later_week_never_reuses_an_uncollected_fragment(self):
        # Last week's refresh merged and has not been collected yet. This
        # week's must be a new file, or its bullet would be lost or would be an
        # edit rather than an added fragment.
        later = nce.fragment_path(Path("news"), self.DAY + datetime.timedelta(7))
        self.assertNotEqual(later, nce.fragment_path(Path("news"), self.DAY))


class MainTests(unittest.TestCase):
    def run_main(self, tmp, before, after, day="2026-10-12"):
        import sys
        argv = sys.argv
        sys.argv = ["x", "--before", str(before), "--after", str(after),
                    "--news-dir", str(Path(tmp) / "news"), "--date", day]
        try:
            return nce.main()
        finally:
            sys.argv = argv

    def test_a_move_writes_one_bullet_to_the_fragment(self):
        with TemporaryDirectory() as tmp:
            b = catalog(tmp, "b", ("hvtiR", "", "1.0.0"))
            a = catalog(tmp, "a", ("hvtiR", "", "1.0.1"))
            self.assertEqual(self.run_main(tmp, b, a), 0)
            text = (Path(tmp) / "news/chore-catalog-version-refresh-2026-10-12.md").read_text()
            self.assertTrue(text.startswith("* Catalog versions refreshed"))
            self.assertIn("`hvtiR` dev 1.0.0 to 1.0.1", " ".join(text.split()))

    def test_rerunning_the_same_day_converges(self):
        with TemporaryDirectory() as tmp:
            b = catalog(tmp, "b", ("hvtiR", "", "1.0.0"))
            a = catalog(tmp, "a", ("hvtiR", "", "1.0.1"))
            self.run_main(tmp, b, a)
            self.run_main(tmp, b, a)
            files = list((Path(tmp) / "news").iterdir())
            self.assertEqual(len(files), 1)
            self.assertEqual(files[0].read_text().count("* Catalog"), 1)

    def test_no_move_writes_nothing(self):
        with TemporaryDirectory() as tmp:
            b = catalog(tmp, "b", ("hvtiR", "", "1.0.0"))
            self.assertEqual(self.run_main(tmp, b, b), 0)
            self.assertFalse((Path(tmp) / "news").exists())


class BulletTests(unittest.TestCase):
    def test_several_moves_are_joined_into_one_bullet(self):
        line = nce.bullet(["`a` dev 1 to 2", "`b` CRAN 3 to 4"])
        flat = " ".join(line.split())
        self.assertIn("`a` dev 1 to 2; `b` CRAN 3 to 4", flat)
        self.assertTrue(line.startswith("* "))

    def test_the_bullet_wraps_like_every_other_entry(self):
        line = nce.bullet([f"`pkg{i}` dev 1.0.0 to 1.0.1" for i in range(6)])
        self.assertTrue(len(line.splitlines()) > 1)
        self.assertTrue(all(len(l) <= 76 for l in line.splitlines()), line)
        # continuation lines are indented, so the bullet stays one list item
        self.assertTrue(all(l.startswith("  ")
                            for l in line.splitlines()[1:]), line)


if __name__ == "__main__":
    unittest.main()
