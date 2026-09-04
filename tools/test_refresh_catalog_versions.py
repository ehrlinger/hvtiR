"""Tests for the catalog version refresher.

The refresher runs unattended on a schedule, so its failure modes are the
quiet ones: a value silently blanked, or a warning emitted every week until
nobody reads them. Both are exercised here. Nothing in this file touches the
network -- `fetch` is stubbed, so the tests pin behaviour rather than what
GitHub happened to answer.
"""
import unittest
from unittest import mock

import refresh_catalog_versions as refresher


def stub_fetch(responses):
    """Return a fetch() double answering from {url_fragment: (code, body)}."""
    def fake(url, attempts=3, timeout=25):
        for fragment, response in responses.items():
            if fragment in url:
                return response
        return (404, "")
    return fake


DESCRIPTION = "Package: thing\nVersion: 1.2.3\n"


class ExpectsDescription(unittest.TestCase):
    def test_registry_members_expect_one(self):
        self.assertTrue(refresher.expects_description({"family": "member"}))

    def test_non_packages_do_not(self):
        self.assertFalse(
            refresher.expects_description({"family": "standalone",
                                           "dev_version": ""})
        )

    def test_a_recorded_version_is_evidence_of_one(self):
        # Covers a future R package that is not a registry member: it has
        # already proved it has a DESCRIPTION by carrying a version.
        self.assertTrue(
            refresher.expects_description({"family": "standalone",
                                           "dev_version": "2.0.0"})
        )


class MemberGoesMissing(unittest.TestCase):
    """A 404 on a row that should have a DESCRIPTION is a failure, not a "".

    GitHub answers 404 the same way for a repository that legitimately has no
    DESCRIPTION, one renamed, one made private, one whose default branch moved,
    and one that lost the file. Blanking a known-good version on that signal
    would turn an outage into data loss and report nothing.
    """

    def setUp(self):
        self.row = {
            "package": "hvtiRutilities", "repo": "ehrlinger/hvtiRutilities",
            "family": "member", "cran": "", "cran_version": "",
            "dev_version": "1.1.9", "dev_ahead": "",
        }

    def test_recorded_version_is_preserved(self):
        with mock.patch.object(refresher, "fetch", stub_fetch({})):
            rows, failures = refresher.refresh([self.row])

        self.assertEqual(rows[0]["dev_version"], "1.1.9")
        self.assertTrue(failures)

    def test_the_failure_names_the_repo(self):
        with mock.patch.object(refresher, "fetch", stub_fetch({})):
            _, failures = refresher.refresh([self.row])

        self.assertIn("ehrlinger/hvtiRutilities", failures[0])

    def test_a_description_without_a_version_field_also_fails(self):
        responses = {"hvtiRutilities": (200, "Package: hvtiRutilities\n")}
        with mock.patch.object(refresher, "fetch", stub_fetch(responses)):
            rows, failures = refresher.refresh([self.row])

        self.assertEqual(rows[0]["dev_version"], "1.1.9")
        self.assertTrue(failures)


class NonPackagesStayQuiet(unittest.TestCase):
    """hazard is SAS/C and HVTI Recipes is a Quarto book.

    Their 404 is permanent and expected. Reporting it would put two warnings
    in every scheduled run forever, which is how a weekly signal stops being
    read at all.
    """

    def test_no_failure_is_reported(self):
        rows = [
            {"package": "hazard", "repo": "ehrlinger/hazard",
             "family": "standalone", "cran": "", "cran_version": "",
             "dev_version": "", "dev_ahead": ""},
            {"package": "HVTI Recipes", "repo": "ehrlinger/hvtiGraphics",
             "family": "book", "cran": "", "cran_version": "",
             "dev_version": "", "dev_ahead": ""},
        ]
        with mock.patch.object(refresher, "fetch", stub_fetch({})):
            rows, failures = refresher.refresh(rows)

        self.assertEqual(failures, [])
        self.assertEqual([r["dev_version"] for r in rows], ["", ""])


class HappyPath(unittest.TestCase):
    def test_a_moved_version_is_taken_up(self):
        row = {"package": "thing", "repo": "ehrlinger/thing", "family": "member",
               "cran": "", "cran_version": "", "dev_version": "1.0.0",
               "dev_ahead": ""}
        with mock.patch.object(
            refresher, "fetch", stub_fetch({"thing": (200, DESCRIPTION)})
        ):
            rows, failures = refresher.refresh([row])

        self.assertEqual(rows[0]["dev_version"], "1.2.3")
        self.assertEqual(failures, [])


class UnexplainedGaps(unittest.TestCase):
    """The finding the schedule exists to surface.

    A gap alone proves nothing: hvtiRbootstrap at 0.1.0 against 0.9.3 was rot,
    TemporalHazard at 1.1.0 against 1.2.9 is policy, and they read the same.
    """

    def row(self, **kwargs):
        base = {"package": "p", "cran_version": "1.0.0", "dev_version": "1.1.0",
                "dev_ahead": ""}
        base.update(kwargs)
        return base

    def test_an_unmarked_gap_is_reported(self):
        self.assertEqual(refresher.unexplained_gaps([self.row()]), ["p"])

    def test_a_marked_gap_is_not(self):
        self.assertEqual(
            refresher.unexplained_gaps([self.row(dev_ahead="expected")]), []
        )

    def test_no_gap_is_not_reported(self):
        self.assertEqual(
            refresher.unexplained_gaps([self.row(dev_version="1.0.0")]), []
        )

    def test_a_package_not_on_cran_cannot_have_a_gap(self):
        self.assertEqual(
            refresher.unexplained_gaps([self.row(cran_version="")]), []
        )


if __name__ == "__main__":
    unittest.main()
