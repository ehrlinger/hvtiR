"""Tests for the catalog version refresher.

The refresher runs unattended on a schedule, so its failure modes are the
quiet ones: a value silently blanked, or a warning emitted every week until
nobody reads them. Both are exercised here. Nothing in this file touches the
network -- `fetch` is stubbed, so the tests pin behaviour rather than what
GitHub happened to answer.
"""
import io
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


class CranAnswersSomethingOtherThanAPackage(unittest.TestCase):
    """A 200 from crandb is not a promise that the body is a package record.

    An error envelope, a proxy or captive portal, and an API change all answer
    with well-formed JSON that is not an object. `.get` on that raised rather
    than returning None, and an uncaught exception exits 1 -- which the
    schedule read as success, ending the run green with nothing refreshed.
    Every unexpected shape must take the unreadable-oracle path instead.
    """

    def shape(self, body):
        with mock.patch.object(refresher, "fetch",
                               return_value=(200, body)):
            return refresher.cran_version("thing")

    def test_a_json_array_is_unreadable_not_a_crash(self):
        self.assertIsNone(self.shape('["not", "a", "record"]'))

    def test_a_bare_json_string_is_unreadable(self):
        self.assertIsNone(self.shape('"gone"'))

    def test_a_bare_json_number_is_unreadable(self):
        self.assertIsNone(self.shape("123"))

    def test_a_non_string_version_is_unreadable(self):
        # Reading 5 as a version would write "5" into the catalog and look
        # like a real answer.
        self.assertIsNone(self.shape('{"Version": 5}'))

    def test_an_object_envelope_is_unreadable_not_absent_from_cran(self):
        # The dangerous one: {} and an error envelope are OBJECTS, so the
        # isinstance check passes and .get returned "" -- the value this
        # module reserves for an authoritative 404. refresh() then blanked a
        # recorded version and reported no failure at all.
        self.assertIsNone(self.shape('{"error": "upstream unavailable"}'))

    def test_an_empty_object_is_unreadable(self):
        self.assertIsNone(self.shape("{}"))

    def test_an_empty_version_string_is_unreadable(self):
        self.assertIsNone(self.shape('{"Version": ""}'))

    def test_a_real_record_still_reads(self):
        self.assertEqual(self.shape('{"Version": "1.2.3"}'), "1.2.3")

    def test_an_envelope_keeps_the_recorded_version(self):
        # The whole point: a blanked cran_version is indistinguishable from
        # "not on CRAN", and it was being written with nothing reported.
        rows = [{"package": "ggRandomForests", "cran": "ggRandomForests",
                 "repo": "", "family": "member", "cran_version": "3.5.2",
                 "dev_version": "4.0.0", "dev_ahead": "expected"}]
        with mock.patch.object(refresher, "fetch",
                               return_value=(200, '{"error": "nope"}')):
            refreshed, failures = refresher.refresh(rows)
        self.assertEqual(refreshed[0]["cran_version"], "3.5.2")
        self.assertEqual(len(failures), 1)
        self.assertIn("could not read CRAN", failures[0])

    def test_malformed_json_is_still_unreadable(self):
        self.assertIsNone(self.shape("not json at all"))

    def test_an_unreadable_cran_keeps_the_recorded_value(self):
        rows = [{"package": "thing", "cran": "thing", "repo": "",
                 "family": "member", "cran_version": "1.0.0",
                 "dev_version": "1.0.0", "dev_ahead": ""}]
        with mock.patch.object(refresher, "fetch",
                               return_value=(200, '["nope"]')):
            refreshed, failures = refresher.refresh(rows)
        self.assertEqual(refreshed[0]["cran_version"], "1.0.0")
        self.assertEqual(len(failures), 1)
        self.assertIn("could not read CRAN", failures[0])


class RetryActuallyWaits(unittest.TestCase):
    """Three requests fired inside a millisecond are not three attempts.

    The case these retries exist for is a throttled shared-IP runner, and a
    throttle window does not move while you are not waiting. R/remote.R has
    always widened its wait; this is the same rule on the Python side.
    """

    def curl(self, *results):
        """subprocess.run double yielding one CompletedProcess per call."""
        made = [mock.Mock(returncode=rc, stdout=out) for rc, out in results]
        return mock.Mock(side_effect=made)

    def test_it_waits_between_attempts_and_widens(self):
        run = self.curl((0, "\n429"), (0, "\n429"), (0, "\n429"))
        with mock.patch.object(refresher.subprocess, "run", run), \
                mock.patch.object(refresher.time, "sleep") as slept:
            refresher.fetch("https://example.invalid/x")
        self.assertEqual(run.call_count, 3)
        self.assertEqual([c.args[0] for c in slept.call_args_list],
                         [refresher.RETRY_WAIT, refresher.RETRY_WAIT * 2])

    def test_it_does_not_wait_after_the_last_attempt(self):
        # A trailing sleep delays the failure without improving it.
        run = self.curl((0, "\n500"))
        with mock.patch.object(refresher.subprocess, "run", run), \
                mock.patch.object(refresher.time, "sleep") as slept:
            refresher.fetch("https://example.invalid/x", attempts=1)
        slept.assert_not_called()

    def test_a_settled_answer_is_not_retried(self):
        run = self.curl((0, "body\n200"))
        with mock.patch.object(refresher.subprocess, "run", run), \
                mock.patch.object(refresher.time, "sleep") as slept:
            code, body = refresher.fetch("https://example.invalid/x")
        self.assertEqual((code, body), (200, "body"))
        self.assertEqual(run.call_count, 1)
        slept.assert_not_called()

    def test_the_last_status_survives_the_attempts(self):
        # Collapsing 429 to 0 made a throttle read as a missing repository.
        run = self.curl((0, "\n429"), (0, "\n429"), (0, "\n429"))
        with mock.patch.object(refresher.subprocess, "run", run), \
                mock.patch.object(refresher.time, "sleep"):
            code, _ = refresher.fetch("https://example.invalid/x")
        self.assertEqual(code, 429)

    def test_curl_never_answering_is_still_zero(self):
        run = self.curl((7, ""), (7, ""), (7, ""))
        with mock.patch.object(refresher.subprocess, "run", run), \
                mock.patch.object(refresher.time, "sleep"):
            code, _ = refresher.fetch("https://example.invalid/x")
        self.assertEqual(code, 0)


class UnreadableSaysWhy(unittest.TestCase):
    def test_a_throttle_does_not_read_as_a_rename(self):
        said = refresher.why_unreadable(429)
        self.assertIn("throttled", said)
        self.assertNotIn("renamed", said)

    def test_a_404_still_names_the_permanent_causes(self):
        self.assertIn("renamed", refresher.why_unreadable(404))

    def test_no_response_is_distinct_from_a_status(self):
        self.assertIn("no response", refresher.why_unreadable(0))

    def test_the_failure_line_carries_the_reason(self):
        row = {"package": "thing", "cran": "", "repo": "e/thing",
               "family": "member", "cran_version": "", "dev_version": "1.0.0",
               "dev_ahead": ""}
        with mock.patch.object(refresher, "fetch", return_value=(429, "")):
            _, failures = refresher.refresh([row])
        self.assertEqual(len(failures), 1)
        self.assertIn("throttled", failures[0])


class CheckModeIsHonest(unittest.TestCase):
    """`--check` must not answer "no drift" for a run that verified nothing.

    A failed fetch keeps the recorded value, so before == after holds just as
    firmly when nothing was read as when everything was read and unchanged.
    """

    def run_check(self, fetch_result):
        import tempfile
        rows = ("package,repo,family,blurb,cran,status,role,homepage,"
                "cran_version,dev_version,dev_ahead\n"
                "thing,e/thing,member,b,,wip,,,,1.0.0,\n")
        with tempfile.NamedTemporaryFile("w", suffix=".csv",
                                         delete=False, newline="") as handle:
            handle.write(rows)
            path = handle.name
        with mock.patch.object(refresher, "fetch", return_value=fetch_result):
            with mock.patch("sys.stderr", new=io.StringIO()), \
                    mock.patch("sys.stdout", new=io.StringIO()):
                return refresher.main([path, "--check"])

    def test_an_unreadable_oracle_outranks_no_drift(self):
        self.assertEqual(self.run_check((0, "")), 2)

    def test_no_drift_is_still_zero(self):
        self.assertEqual(
            self.run_check((200, "Package: thing\nVersion: 1.0.0\n")), 0)

    def test_drift_is_still_one(self):
        self.assertEqual(
            self.run_check((200, "Package: thing\nVersion: 2.0.0\n")), 1)


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
