"""Tests for news_catalog_entry.py."""
import importlib.util
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

_spec = importlib.util.spec_from_file_location(
    "news_catalog_entry", Path(__file__).with_name("news_catalog_entry.py"))
nce = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(nce)

HEAD = "package,repo,cran_version,dev_version\n"
NEWS_NAMED = """Package: hvtiR
Version: 1.1.6

# hvtiR 1.1.6

* Something already released.

# hvtiR 1.1.5

* Older.
"""
NEWS_UNRELEASED = """Package: hvtiR
Version: 1.1.6

# hvtiR (unreleased)

* Someone else's pending work.

# hvtiR 1.1.6

* Something already released.
"""


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


class InsertTests(unittest.TestCase):
    LINE = "* Catalog versions refreshed from CRAN and `main`: x."

    def test_creates_the_heading_above_the_newest_version(self):
        out = nce.insert(NEWS_NAMED, self.LINE)
        self.assertEqual(out.count(nce.UNRELEASED), 1)
        self.assertLess(out.index(nce.UNRELEASED), out.index("# hvtiR 1.1.6"))
        self.assertIn(self.LINE, out)

    def test_appends_into_an_existing_section_without_a_second_heading(self):
        out = nce.insert(NEWS_UNRELEASED, self.LINE)
        self.assertEqual(out.count(nce.UNRELEASED), 1)
        self.assertIn("Someone else's pending work.", out)
        self.assertLess(out.index("Someone else's pending work."),
                        out.index(self.LINE))
        self.assertLess(out.index(self.LINE), out.index("# hvtiR 1.1.6"))

    def test_rerunning_does_not_duplicate_the_bullet(self):
        # The refresh branch is regenerated weekly; reruns must converge.
        once = nce.insert(NEWS_NAMED, self.LINE)
        twice = nce.insert(once, self.LINE)
        self.assertEqual(once, twice)
        self.assertEqual(twice.count(self.LINE), 1)

    def test_the_dcf_header_is_left_above_the_new_heading(self):
        out = nce.insert(NEWS_NAMED, self.LINE)
        self.assertTrue(out.startswith("Package: hvtiR\nVersion: 1.1.6\n"))

    def test_news_with_no_version_heading_is_rejected(self):
        with self.assertRaises(SystemExit):
            nce.insert("Package: hvtiR\nVersion: 1.1.6\n", self.LINE)


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
