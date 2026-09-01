"""Tests for the version-bump guard.

Twice in one day two branches independently bumped to the same version. Git
merges an identical `Version:` line silently, so only NEWS.md conflicts and a
careless resolution ships two releases claiming one number. This guard makes
that a build failure instead of a surprise.
"""
import unittest

from check_version import (
    compare,
    has_unreleased_heading,
    main_with,
    parse_version,
    read_version,
)


class ParseTests(unittest.TestCase):
    def test_a_three_part_version_parses_to_integers(self):
        self.assertEqual(parse_version("1.0.5"), (1, 0, 5))

    def test_a_missing_version_field_is_an_error_naming_the_file(self):
        with self.assertRaises(ValueError) as ctx:
            read_version("Package: hvtiR\n", "DESCRIPTION")
        self.assertIn("DESCRIPTION", str(ctx.exception))

    def test_a_non_numeric_version_is_rejected(self):
        with self.assertRaises(ValueError):
            parse_version("1.0.5-dev")

    def test_a_four_part_version_is_rejected(self):
        # House rule: always a straight three-digit semantic version, never a
        # .9000 development suffix or a fourth digit.
        with self.assertRaises(ValueError) as ctx:
            parse_version("1.0.5.9000")
        self.assertIn("three", str(ctx.exception))


class CompareTests(unittest.TestCase):
    def test_a_patch_bump_passes(self):
        self.assertEqual(compare("1.0.5", "1.0.6"), [])

    def test_a_minor_bump_passes(self):
        self.assertEqual(compare("1.0.5", "1.1.0"), [])

    def test_an_identical_version_fails(self):
        # The case that actually bit: git merges the identical line silently.
        problems = compare("1.0.5", "1.0.5")
        self.assertTrue(problems)
        self.assertIn("1.0.5", problems[0])

    def test_a_lower_version_fails(self):
        self.assertTrue(compare("1.0.5", "1.0.4"))

    def test_a_skipped_patch_digit_is_allowed(self):
        # Not our business to police gaps, only that it moved forward.
        self.assertEqual(compare("1.0.5", "1.0.9"), [])

    def test_an_unchanged_version_passes_with_an_unreleased_heading(self):
        # The cadence case: a pull request files its entry under the unreleased
        # heading and leaves Version: alone.
        self.assertEqual(compare("1.0.5", "1.0.5", unreleased=True), [])

    def test_a_lower_version_fails_even_with_an_unreleased_heading(self):
        # The unreleased heading excuses standing still, never going backwards.
        self.assertTrue(compare("1.0.5", "1.0.4", unreleased=True))


class UnreleasedHeadingTests(unittest.TestCase):
    def test_the_heading_is_found(self):
        self.assertTrue(
            has_unreleased_heading("# hvtiR (unreleased)\n\n* merged work\n")
        )

    def test_a_version_heading_is_not_mistaken_for_it(self):
        self.assertFalse(has_unreleased_heading("# hvtiR 1.0.6\n"))

    def test_another_package_s_unreleased_heading_does_not_count(self):
        self.assertFalse(has_unreleased_heading("# hvtiPlotR (unreleased)\n"))

    def test_a_level_two_heading_does_not_count(self):
        # The family settled on level-1 version headings. A "##" heading is the
        # old shape this repository used alone, and accepting it would let the
        # inconsistency quietly return.
        self.assertFalse(has_unreleased_heading("## hvtiR (unreleased)\n"))


class NewsAgreementTests(unittest.TestCase):
    # Dates present and moving, so these exercise NEWS agreement alone.
    DESC = "Package: hvtiR\nVersion: 1.0.6\nDate: 2026-08-27\n"
    BASE = "Package: hvtiR\nVersion: 1.0.5\nDate: 2026-08-26\n"

    def test_matching_news_and_description_pass(self):
        news = "Package: hvtiR\nVersion: 1.0.6\n\n# hvtiR 1.0.6\n"
        self.assertEqual(main_with(self.BASE, self.DESC, news), 0)

    def test_a_news_version_line_that_disagrees_fails(self):
        news = "Package: hvtiR\nVersion: 1.0.5\n\n# hvtiR 1.0.6\n"
        self.assertEqual(main_with(self.BASE, self.DESC, news), 1)

    def test_a_missing_news_heading_for_this_version_fails(self):
        news = "Package: hvtiR\nVersion: 1.0.6\n\n# hvtiR 1.0.5\n"
        self.assertEqual(main_with(self.BASE, self.DESC, news), 1)

    def test_an_unbumped_version_fails_even_when_news_agrees(self):
        news = "Package: hvtiR\nVersion: 1.0.5\n\n# hvtiR 1.0.5\n"
        self.assertEqual(main_with(self.BASE, self.BASE, news), 1)

    def test_an_unbumped_version_passes_when_news_has_an_unreleased_heading(self):
        # End to end: no bump, entry filed under the unreleased heading. This is
        # what most pull requests now look like.
        news = (
            "Package: hvtiR\nVersion: 1.0.5\n\n"
            "# hvtiR (unreleased)\n\n* Merged work awaiting a version.\n\n"
            "# hvtiR 1.0.5\n"
        )
        self.assertEqual(main_with(self.BASE, self.BASE, news), 0)

    def test_a_bumped_version_with_a_moved_date_and_matching_news_passes(self):
        # The happy path, asserted once with every rule satisfied.
        news = "Package: hvtiR\nVersion: 1.0.6\n\n# hvtiR 1.0.6\n"
        self.assertEqual(main_with(self.BASE, self.DESC, news), 0)

    def test_all_three_problems_are_reported_together(self):
        # One run should surface every problem, not stop at the first.
        news = "Package: hvtiR\nVersion: 9.9.9\n\n# hvtiR 8.8.8\n"
        import io, contextlib
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            main_with(self.BASE, self.BASE, news)
        self.assertGreaterEqual(err.getvalue().count("- "), 2)


class DateTests(unittest.TestCase):
    """Date must not go backwards or into the future.

    It deliberately does NOT have to advance. This package cut 1.0.3, 1.0.4,
    1.0.5 and 1.0.6 all on 2026-08-26; requiring a new day would have blocked
    every one of them. Same-day releases are normal here, so the rule catches
    a Date left behind from an earlier day, not one shared with the release
    before it.
    """

    BASE = "Package: hvtiR\nVersion: 1.0.5\nDate: 2026-08-26\n"
    NEWS = "Package: hvtiR\nVersion: 1.0.6\n\n# hvtiR 1.0.6\n"

    def test_a_later_date_passes(self):
        head = "Package: hvtiR\nVersion: 1.0.6\nDate: 2026-08-27\n"
        self.assertEqual(main_with(self.BASE, head, self.NEWS), 0)

    def test_the_same_day_passes_because_same_day_releases_are_normal(self):
        head = "Package: hvtiR\nVersion: 1.0.6\nDate: 2026-08-26\n"
        self.assertEqual(main_with(self.BASE, head, self.NEWS), 0)

    def test_a_date_going_backwards_fails(self):
        head = "Package: hvtiR\nVersion: 1.0.6\nDate: 2026-08-25\n"
        self.assertEqual(main_with(self.BASE, head, self.NEWS), 1)

    def test_a_future_date_fails(self):
        import datetime
        ahead = (datetime.date.today() + datetime.timedelta(days=2)).isoformat()
        head = f"Package: hvtiR\nVersion: 1.0.6\nDate: {ahead}\n"
        self.assertEqual(main_with(self.BASE, head, self.NEWS), 1)

    def test_a_malformed_date_is_rejected(self):
        head = "Package: hvtiR\nVersion: 1.0.6\nDate: Aug 27 2026\n"
        self.assertEqual(main_with(self.BASE, head, self.NEWS), 1)

    def test_a_missing_date_field_is_reported_not_ignored(self):
        head = "Package: hvtiR\nVersion: 1.0.6\n"
        self.assertEqual(main_with(self.BASE, head, self.NEWS), 1)


if __name__ == "__main__":
    unittest.main()
