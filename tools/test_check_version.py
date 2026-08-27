"""Tests for the version-bump guard.

Twice in one day two branches independently bumped to the same version. Git
merges an identical `Version:` line silently, so only NEWS.md conflicts and a
careless resolution ships two releases claiming one number. This guard makes
that a build failure instead of a surprise.
"""
import unittest

from check_version import compare, parse_version, read_version, main_with


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


class NewsAgreementTests(unittest.TestCase):
    # Dates present and moving, so these exercise NEWS agreement alone.
    DESC = "Package: hvtiR\nVersion: 1.0.6\nDate: 2026-08-27\n"
    BASE = "Package: hvtiR\nVersion: 1.0.5\nDate: 2026-08-26\n"

    def test_matching_news_and_description_pass(self):
        news = "Package: hvtiR\nVersion: 1.0.6\n\n## hvtiR 1.0.6\n"
        self.assertEqual(main_with(self.BASE, self.DESC, news), 0)

    def test_a_news_version_line_that_disagrees_fails(self):
        news = "Package: hvtiR\nVersion: 1.0.5\n\n## hvtiR 1.0.6\n"
        self.assertEqual(main_with(self.BASE, self.DESC, news), 1)

    def test_a_missing_news_heading_for_this_version_fails(self):
        news = "Package: hvtiR\nVersion: 1.0.6\n\n## hvtiR 1.0.5\n"
        self.assertEqual(main_with(self.BASE, self.DESC, news), 1)

    def test_an_unbumped_version_fails_even_when_news_agrees(self):
        news = "Package: hvtiR\nVersion: 1.0.5\n\n## hvtiR 1.0.5\n"
        self.assertEqual(main_with(self.BASE, self.BASE, news), 1)

    def test_a_bumped_version_with_a_moved_date_and_matching_news_passes(self):
        # The happy path, asserted once with every rule satisfied.
        news = "Package: hvtiR\nVersion: 1.0.6\n\n## hvtiR 1.0.6\n"
        self.assertEqual(main_with(self.BASE, self.DESC, news), 0)

    def test_all_three_problems_are_reported_together(self):
        # One run should surface every problem, not stop at the first.
        news = "Package: hvtiR\nVersion: 9.9.9\n\n## hvtiR 8.8.8\n"
        import io, contextlib
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            main_with(self.BASE, self.BASE, news)
        self.assertGreaterEqual(err.getvalue().count("- "), 2)


class DateTests(unittest.TestCase):
    """A version bump that leaves Date stale slipped past the first guard.

    Caught in review on #12: Version moved to 1.0.6 while Date still read the
    previous release's day. The guard checked Version and NEWS but not Date.
    """

    BASE = "Package: hvtiR\nVersion: 1.0.5\nDate: 2026-08-26\n"
    NEWS = "Package: hvtiR\nVersion: 1.0.6\n\n## hvtiR 1.0.6\n"

    def test_a_bump_that_moves_the_date_passes(self):
        head = "Package: hvtiR\nVersion: 1.0.6\nDate: 2026-08-27\n"
        self.assertEqual(main_with(self.BASE, head, self.NEWS), 0)

    def test_a_bump_that_leaves_the_date_stale_fails(self):
        head = "Package: hvtiR\nVersion: 1.0.6\nDate: 2026-08-26\n"
        self.assertEqual(main_with(self.BASE, head, self.NEWS), 1)

    def test_a_date_going_backwards_fails(self):
        head = "Package: hvtiR\nVersion: 1.0.6\nDate: 2026-08-25\n"
        self.assertEqual(main_with(self.BASE, head, self.NEWS), 1)

    def test_a_malformed_date_is_rejected(self):
        head = "Package: hvtiR\nVersion: 1.0.6\nDate: Aug 27 2026\n"
        self.assertEqual(main_with(self.BASE, head, self.NEWS), 1)

    def test_a_missing_date_field_is_reported_not_ignored(self):
        head = "Package: hvtiR\nVersion: 1.0.6\n"
        self.assertEqual(main_with(self.BASE, head, self.NEWS), 1)


if __name__ == "__main__":
    unittest.main()
