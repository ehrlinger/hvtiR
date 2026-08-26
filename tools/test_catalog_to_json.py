"""Tests for the catalog -> members.json converter.

The converter runs in CI and produces the single artifact every downstream CV
sink reads. Its derived counts are what make the family-count sentence
arithmetic rather than something typed into three repositories by hand.
"""
import io
import json
import pathlib
import unittest

from catalog_to_json import build_manifest, read_catalog

FIXTURE = """\
package,repo,family,blurb,cran,status,role,homepage
alpha,ehrlinger/alpha,member,"First -- a member on CRAN.",alpha,stable,,
beta,ehrlinger/beta-repo,member,"Second, a GitHub-only member.",,wip,,
gamma,ehrlinger/gamma,standalone,"Not an R package.",,stable,Maintainer,
delta,ehrlinger/delta,book,"A book.",,stable,,https://example.org/delta/
"""

REAL_CATALOG = pathlib.Path(__file__).resolve().parents[1] / "inst" / "extdata" / "catalog.csv"


class BuildManifestTests(unittest.TestCase):
    def setUp(self):
        self.manifest = build_manifest(read_catalog(io.StringIO(FIXTURE)), version="9.9.9")

    def test_counts_are_derived_from_member_rows_only(self):
        self.assertEqual(
            self.manifest["counts"],
            {"members": 2, "members_on_cran": 1, "members_github_only": 1},
        )

    def test_standalone_and_book_rows_do_not_count_as_members(self):
        families = [p["family"] for p in self.manifest["packages"]]
        self.assertEqual(families.count("member"), 2)
        self.assertEqual(len(self.manifest["packages"]), 4)

    def test_cran_member_names_preserve_catalog_order(self):
        self.assertEqual(self.manifest["cran_member_names"], ["alpha"])

    def test_url_is_derived_from_repo(self):
        alpha = self._pkg("alpha")
        self.assertEqual(alpha["url"], "https://github.com/ehrlinger/alpha")

    def test_repo_name_may_differ_from_package_name(self):
        beta = self._pkg("beta")
        self.assertEqual(beta["url"], "https://github.com/ehrlinger/beta-repo")

    def test_homepage_overrides_the_derived_repo_url(self):
        delta = self._pkg("delta")
        self.assertEqual(delta["url"], "https://example.org/delta/")

    def test_absent_optional_fields_are_null_not_empty_string(self):
        beta = self._pkg("beta")
        self.assertIsNone(beta["cran"])
        self.assertIsNone(beta["role"])

    def test_generated_from_records_the_package_version(self):
        self.assertEqual(self.manifest["generated_from"], "hvtiR 9.9.9")

    def test_manifest_is_json_serialisable(self):
        self.assertIsInstance(json.dumps(self.manifest), str)

    def _pkg(self, name):
        return next(p for p in self.manifest["packages"] if p["package"] == name)


class RealCatalogTests(unittest.TestCase):
    def setUp(self):
        with REAL_CATALOG.open() as fh:
            self.manifest = build_manifest(read_catalog(fh), version="1.0.1")

    def test_the_family_count_sentence_is_arithmetic(self):
        # "eleven member packages, the nine below plus ggRandomForests and
        # TemporalHazard above" -- the sentence commit 6ab85bd had to fix by
        # hand in three repositories.
        self.assertEqual(
            self.manifest["counts"],
            {"members": 11, "members_on_cran": 2, "members_github_only": 9},
        )
        self.assertEqual(
            self.manifest["cran_member_names"],
            ["ggRandomForests", "TemporalHazard"],
        )

    def test_every_package_has_a_resolvable_url(self):
        for pkg in self.manifest["packages"]:
            self.assertTrue(pkg["url"].startswith("https://"), pkg["package"])


class ValidationTests(unittest.TestCase):
    def test_unknown_family_is_rejected(self):
        bad = FIXTURE.replace(",member,", ",associate,", 1)
        with self.assertRaises(ValueError) as ctx:
            build_manifest(read_catalog(io.StringIO(bad)), version="9.9.9")
        self.assertIn("associate", str(ctx.exception))

    def test_empty_blurb_is_rejected(self):
        bad = FIXTURE.replace('"First -- a member on CRAN."', '""', 1)
        with self.assertRaises(ValueError) as ctx:
            build_manifest(read_catalog(io.StringIO(bad)), version="9.9.9")
        self.assertIn("alpha", str(ctx.exception))

    def test_missing_column_is_rejected(self):
        bad = FIXTURE.replace(",role,", ",", 1)
        with self.assertRaises(ValueError) as ctx:
            build_manifest(read_catalog(io.StringIO(bad)), version="9.9.9")
        self.assertIn("role", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
