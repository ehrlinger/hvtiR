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
        # An empty directory, not the repository's own news/: fragment_path()
        # skips names that exist, and the real news/ can hold today's.
        with TemporaryDirectory() as tmp:
            news = Path(tmp) / "news"
            self.assertEqual(nce.fragment_path(news, self.DAY),
                             news / "chore-catalog-version-refresh-2026-10-12.md")

    def test_a_later_week_never_reuses_an_uncollected_fragment(self):
        # Last week's refresh merged and has not been collected yet. This
        # week's must be a new file, or its bullet would be lost or would be an
        # edit rather than an added fragment.
        later = nce.fragment_path(Path("news"), self.DAY + datetime.timedelta(7))
        self.assertNotEqual(later, nce.fragment_path(Path("news"), self.DAY))

    def test_a_same_day_refresh_never_reuses_a_merged_fragment(self):
        # 2026-10-12: a refresh merged in the morning and was not collected;
        # the afternoon refresh rewrote the same dated file, which dropped the
        # morning's bullet and was an edit, not an added fragment, so
        # check_version failed it. The checkout is main, so a name already
        # there belongs to a merged refresh; take the next free one.
        with TemporaryDirectory() as tmp:
            news = Path(tmp)
            (news / "chore-catalog-version-refresh-2026-10-12.md").write_text("x")
            self.assertEqual(nce.fragment_path(news, self.DAY).name,
                             "chore-catalog-version-refresh-2026-10-12-2.md")
            (news / "chore-catalog-version-refresh-2026-10-12-2.md").write_text("y")
            self.assertEqual(nce.fragment_path(news, self.DAY).name,
                             "chore-catalog-version-refresh-2026-10-12-3.md")


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

    def test_rerunning_from_the_same_base_converges(self):
        # Each workflow run starts from a fresh checkout of main, which does
        # not hold an unmerged refresh's fragment, so a rerun picks the same
        # name and the pull request branch is rewritten, not added to.
        names = []
        for _ in range(2):
            with TemporaryDirectory() as tmp:
                b = catalog(tmp, "b", ("hvtiR", "", "1.0.0"))
                a = catalog(tmp, "a", ("hvtiR", "", "1.0.1"))
                self.run_main(tmp, b, a)
                names.append([f.name for f in (Path(tmp) / "news").iterdir()])
        self.assertEqual(names[0], names[1])
        self.assertEqual(len(names[0]), 1)

    def test_a_merged_fragment_from_today_is_left_intact(self):
        with TemporaryDirectory() as tmp:
            news = Path(tmp) / "news"
            news.mkdir()
            morning = news / "chore-catalog-version-refresh-2026-10-12.md"
            morning.write_text("* the morning's bullet\n")
            b = catalog(tmp, "b", ("hvtiR", "", "1.0.0"))
            a = catalog(tmp, "a", ("hvtiR", "", "1.0.1"))
            self.run_main(tmp, b, a)
            self.assertEqual(morning.read_text(), "* the morning's bullet\n")
            self.assertTrue((news / "chore-catalog-version-refresh-2026-10-12-2.md")
                            .exists())

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

    # The source named is the one that moved. Most members are never published
    # to CRAN, so "from CRAN and `main`" beside a dev-only move told readers an
    # internal package had come from CRAN.
    def test_dev_moves_alone_name_main(self):
        flat = " ".join(nce.bullet(["`hvtiRtables` dev 1.0.9 to 1.0.10"]).split())
        self.assertIn("refreshed from `main`:", flat)
        self.assertNotIn("CRAN", flat.replace("`hvtiRtables`", ""))

    def test_cran_moves_alone_name_cran(self):
        flat = " ".join(nce.bullet(["`ggRandomForests` CRAN 3.5.3 to 3.5.4"]).split())
        self.assertIn("refreshed from CRAN:", flat)
        self.assertNotIn("`main`:", flat)

    def test_both_kinds_of_move_name_both(self):
        flat = " ".join(nce.bullet(["`a` dev 1 to 2", "`b` CRAN 3 to 4"]).split())
        self.assertIn("refreshed from CRAN and `main`:", flat)

    def test_the_bullet_wraps_like_every_other_entry(self):
        line = nce.bullet([f"`pkg{i}` dev 1.0.0 to 1.0.1" for i in range(6)])
        self.assertTrue(len(line.splitlines()) > 1)
        self.assertTrue(all(len(l) <= 76 for l in line.splitlines()), line)
        # continuation lines are indented, so the bullet stays one list item
        self.assertTrue(all(l.startswith("  ")
                            for l in line.splitlines()[1:]), line)

    def test_a_hyphenated_name_is_never_split_across_lines(self):
        # The 2026-10-15 refresh wrapped after "`family-", which Markdown
        # renders as "family- floors.csv" (#131). These are that day's moves.
        moved = ["`hvtiPlotR` Suggests `hvtiRpropensity` added",
                 "`hvtiRpropensity` Suggests `hvtiPlotR` added",
                 "`hvtiRtemplates` Suggests `hvtiPlotR` (>= 2.8.0) to (>= 2.8.9)",
                 "`hvtiRtemplates` Suggests `hvtiRpropensity` (>= 0.1.10) to (>= 0.2.0)",
                 "`hvtiRtemplates` Suggests `hvtiRtables` (>= 1.0.1) to (>= 1.0.5)"]
        for text in (nce.floor_bullet(moved), nce.bullet(moved)):
            self.assertNotIn("-\n", text, text)
        self.assertIn("`family-floors.csv`", nce.floor_bullet(moved))


if __name__ == "__main__":
    unittest.main()


FLOOR_HEADER = "package,field,dependency,op,floor,dependency_dev,satisfied\n"


def floors(tmp, stem, *lines):
    path = Path(tmp) / f"{stem}-floors.csv"
    path.write_text(FLOOR_HEADER + "".join(line + "\n" for line in lines))
    return path


class FloorTableTests(unittest.TestCase):
    """A floor-only refresh must still produce a fragment, or check_version
    rejects the machine pull request that commits family-floors.csv."""

    def run_main(self, tmp, cat, fb, fa):
        import sys
        argv = sys.argv
        sys.argv = ["x", "--before", str(cat), "--after", str(cat),
                    "--floors-before", str(fb), "--floors-after", str(fa),
                    "--news-dir", str(Path(tmp) / "news"), "--date", "2026-10-12"]
        try:
            return nce.main()
        finally:
            sys.argv = argv

    def fragment(self, tmp):
        return " ".join((Path(tmp) / "news/chore-catalog-version-refresh-2026-10-12.md")
                        .read_text().split())

    def test_a_raised_floor_alone_writes_a_fragment(self):
        with TemporaryDirectory() as tmp:
            cat = catalog(tmp, "c", ("hvtiR", "", "1.0.0"))
            fb = floors(tmp, "b", "beta,Imports,alpha,>=,1.0.0,1.5.1,TRUE")
            fa = floors(tmp, "a", "beta,Imports,alpha,>=,1.5.0,1.5.1,TRUE")
            self.assertEqual(self.run_main(tmp, cat, fb, fa), 0)
            self.assertIn("`beta` Imports `alpha` (>= 1.0.0) to (>= 1.5.0)",
                          self.fragment(tmp))

    def test_an_added_and_a_removed_floor_are_both_named(self):
        with TemporaryDirectory() as tmp:
            cat = catalog(tmp, "c", ("hvtiR", "", "1.0.0"))
            fb = floors(tmp, "b", "beta,Imports,alpha,>=,1.0.0,1.5.1,TRUE")
            fa = floors(tmp, "a", "beta,Suggests,gamma,,,2.0.0,")
            self.run_main(tmp, cat, fb, fa)
            text = self.fragment(tmp)
            self.assertIn("`beta` Suggests `gamma` added", text)
            self.assertIn("`beta` Imports `alpha` (>= 1.0.0) removed", text)

    def test_a_moved_dependency_version_alone_is_not_a_floor_change(self):
        # dependency_dev and satisfied follow the versions, which the catalog
        # bullet already narrates; only the declaration is floor news.
        with TemporaryDirectory() as tmp:
            cat = catalog(tmp, "c", ("hvtiR", "", "1.0.0"))
            fb = floors(tmp, "b", "beta,Imports,alpha,>=,1.0.0,1.5.1,TRUE")
            fa = floors(tmp, "a", "beta,Imports,alpha,>=,1.0.0,1.5.2,TRUE")
            self.run_main(tmp, cat, fb, fa)
            self.assertFalse((Path(tmp) / "news").exists())


class FragmentLayoutTests(unittest.TestCase):
    """Two bullets in one fragment are separated by a blank line, as every
    other entry in NEWS.md is."""

    def test_the_catalog_and_floor_bullets_are_a_blank_line_apart(self):
        with TemporaryDirectory() as tmp:
            cb = catalog(tmp, "cb", ("hvtiR", "", "1.0.0"))
            ca = catalog(tmp, "ca", ("hvtiR", "", "1.0.1"))
            fb = floors(tmp, "b", "beta,Imports,alpha,>=,1.0.0,1.5.1,TRUE")
            fa = floors(tmp, "a", "beta,Imports,alpha,>=,1.5.0,1.5.1,TRUE")
            import sys
            argv = sys.argv
            sys.argv = ["x", "--before", str(cb), "--after", str(ca),
                        "--floors-before", str(fb), "--floors-after", str(fa),
                        "--news-dir", str(Path(tmp) / "news"),
                        "--date", "2026-10-12"]
            try:
                nce.main()
            finally:
                sys.argv = argv
            text = (Path(tmp) / "news/chore-catalog-version-refresh-2026-10-12.md").read_text()
        self.assertIn("\n\n* Family floors refreshed", text)
        self.assertTrue(text.endswith("\n") and not text.endswith("\n\n"))
