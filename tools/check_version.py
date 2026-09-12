"""Fail a pull request whose version moved somewhere it should not have.

Two branches bumping to the same version do not conflict in git: the identical
`Version:` line merges silently and only NEWS.md shows a conflict. Resolving
just what git shows you then ships two releases claiming one number, which
happened twice in a single day before this guard existed.

The guard used to require every pull request to bump, because a branch rebased
onto a main that already took its number looks exactly like one that never
bumped. Under the house-style cadence most pull requests deliberately leave the
version alone, so that rule would fail nearly all of them. What separates the
two cases is NEWS.md: work that is not being versioned lands under the standing
`# hvtiR (unreleased)` heading, and a branch that bumped has its entry under a
version heading instead. So an unchanged version is accepted only when the
unreleased heading is present, which keeps the collision a failure.

A pull request that ships nothing needs neither. The house style gives a
change whose every file R's built-in build exclusions or `.Rbuildignore` cover
(`.Rbuildignore` itself among them) no NEWS entry and no bump, so an unchanged
version passes for it with or without the heading. The workflow
hands over the base branch's `.Rbuildignore`, so a pull request cannot exempt
itself by adding a pattern. A missing or empty list of changed files, or of
patterns, never earns the exemption.

Also checks the two places the version is written agree, since NEWS.md carries
its own `Version:` line and a per-release heading.

Standard library only -- no pip install step on the runner.
"""
from __future__ import annotations

import argparse
import datetime
import re
import sys
from pathlib import Path


def read_version(text: str, label: str) -> str:
    match = re.search(r"^Version:\s*(\S+)", text, re.M)
    if not match:
        raise ValueError(f"no Version: field found in {label}")
    return match.group(1)


UNRELEASED_RE = re.compile(r"^#\s+hvtiR\s+\(unreleased\)\s*$", re.M)


def has_unreleased_heading(news: str) -> bool:
    """Whether NEWS.md carries the standing unreleased heading."""
    return bool(UNRELEASED_RE.search(news))


# `tools:::inRbuildignore()` tests these before a package's own `.Rbuildignore`,
# which is why `.Rbuildignore` itself never ships. Copied from
# `tools:::get_exclude_patterns()` in R 4.6.1.
R_BUILD_EXCLUDES = [
    r"^\.Rbuildignore$", r"(^|/)\.DS_Store$", r"^\.(RData|Rhistory)$",
    r"~$", r"\.bak$", r"\.sw.$", r"(^|/)\.#[^/]*$", r"(^|/)#[^/]*#$",
    r"^TITLE$", r"^data/00Index$", r"^inst/doc/00Index\.dcf$",
    r"^config\.(cache|log|status)$", r"(^|/)autom4te\.cache$",
    r"^src/.*\.d$", r"^src/Makedeps$", r"^src/so_locations$",
    r"^inst/doc/Rplots\.(ps|pdf)$", r"^(GPATH|GRTAGS|GTAGS)$",
]


def read_rbuildignore(text: str) -> list:
    """The patterns in an `.Rbuildignore`, one per non-blank line."""
    return [line for line in text.splitlines() if line.strip()]


def ships_nothing(paths: list, patterns: list) -> bool:
    """Whether `R CMD build` would leave out every changed file.

    Mirrors `tools:::inRbuildignore()`, which adds R's own patterns
    (`R_BUILD_EXCLUDES`) to the file's: each pattern is a case-insensitive Perl
    regex tested against paths relative to the package root, directories
    included, and an excluded directory takes everything under it. So a file
    is out when it, or any directory above it, matches. An empty list of paths
    or of patterns is not "ships nothing": a missing input must fail closed.
    """
    if not paths or not patterns:
        return False
    try:
        regexes = [re.compile(p, re.IGNORECASE)
                   for p in R_BUILD_EXCLUDES + list(patterns)]
    except re.error as exc:
        raise ValueError(f".Rbuildignore pattern does not compile: {exc}") from None

    def excluded(path: str) -> bool:
        parts = path.split("/")
        prefixes = ["/".join(parts[:i]) for i in range(1, len(parts) + 1)]
        return any(rx.search(pre) for pre in prefixes for rx in regexes)

    return all(excluded(p) for p in paths)


def parse_version(version: str) -> tuple:
    """Parse a straight three-digit semantic version.

    House rule: never a .9000 development suffix and never a fourth digit, so
    anything else is rejected rather than coerced.
    """
    parts = version.split(".")
    if len(parts) != 3:
        raise ValueError(
            f"version {version!r} must have exactly three parts (major.minor.patch)"
        )
    if not all(p.isdigit() for p in parts):
        raise ValueError(f"version {version!r} must be numeric in every part")
    return tuple(int(p) for p in parts)


def read_date(text: str, label: str) -> str:
    match = re.search(r"^Date:\s*(\S+)", text, re.M)
    if not match:
        raise ValueError(f"no Date: field found in {label}")
    return match.group(1)


def parse_date(value: str) -> datetime.date:
    try:
        return datetime.date.fromisoformat(value)
    except ValueError:
        raise ValueError(f"Date {value!r} is not an ISO date (YYYY-MM-DD)") from None


def compare_dates(base: str, head: str, today: datetime.date = None) -> list:
    """Date must not go backwards, and must not be in the future.

    It deliberately need not advance. This package cut 1.0.3 through 1.0.6 all
    on 2026-08-26, so requiring a new day would block same-day releases, which
    are normal here. The rule therefore catches a Date left behind from an
    earlier day rather than one shared with the release before it.
    """
    head_date, base_date = parse_date(head), parse_date(base)
    problems = []
    if head_date < base_date:
        problems.append(
            f"DESCRIPTION Date {head} is earlier than the base branch's {base}."
        )
    if head_date > (today or datetime.date.today()):
        problems.append(f"DESCRIPTION Date {head} is in the future.")
    return problems


def compare(base: str, head: str, unreleased: bool = False,
            nothing_ships: bool = False) -> list:
    """Problems with the head version relative to base. Empty means fine.

    `unreleased` says whether NEWS.md carries the unreleased heading, which is
    what makes an unchanged version legitimate rather than a silent collision.
    `nothing_ships` says R's built-in build exclusions or `.Rbuildignore`
    cover every file the pull request touches, which makes it legitimate too.
    """
    if parse_version(head) > parse_version(base):
        return []
    if base == head:
        if unreleased or nothing_ships:
            return []
        return [
            f"DESCRIPTION Version is still {head}, unchanged from the base branch, "
            "and NEWS.md has no '# hvtiR (unreleased)' heading. File the entry "
            "under that heading, or bump the patch digit. Without one of the two, "
            "a branch rebased onto a main that already took this number is "
            "indistinguishable from one that never bumped. A change that ships "
            "nothing, every file excluded by R's build defaults or "
            ".Rbuildignore, needs neither."
        ]
    return [f"DESCRIPTION Version {head} is lower than the base branch's {base}."]


def main_with(base_desc: str, head_desc: str, head_news: str,
              changed_files: list = None, rbuildignore: list = None) -> int:
    """Run every check and report all problems, not just the first."""
    problems = []
    try:
        base = read_version(base_desc, "the base branch's DESCRIPTION")
        head = read_version(head_desc, "DESCRIPTION")
        problems += compare(base, head, has_unreleased_heading(head_news),
                            ships_nothing(changed_files or [], rbuildignore or []))
    except ValueError as exc:
        problems.append(str(exc))
        return _report(problems)

    try:
        problems += compare_dates(
            read_date(base_desc, "the base branch's DESCRIPTION"),
            read_date(head_desc, "DESCRIPTION"),
        )
    except ValueError as exc:
        problems.append(str(exc))

    try:
        news = read_version(head_news, "NEWS.md")
        if news != head:
            problems.append(
                f"NEWS.md Version: is {news} but DESCRIPTION says {head}; they must match."
            )
    except ValueError as exc:
        problems.append(str(exc))

    if not re.search(rf"^#\s+hvtiR\s+{re.escape(head)}\s*$", head_news, re.M):
        problems.append(f"NEWS.md has no '# hvtiR {head}' heading for this release.")

    return _report(problems)


def _report(problems: list) -> int:
    if not problems:
        return 0
    print("version check failed:", file=sys.stderr)
    for p in problems:
        print(f"  - {p}", file=sys.stderr)
    return 1


def main(argv=None) -> int:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-description", type=Path, required=True,
                        help="DESCRIPTION as it exists on the base branch")
    parser.add_argument("--description", type=Path, default=root / "DESCRIPTION")
    parser.add_argument("--news", type=Path, default=root / "NEWS.md")
    parser.add_argument("--changed-files", type=Path,
                        help="the pull request's changed paths, one per line")
    parser.add_argument("--rbuildignore", type=Path, default=root / ".Rbuildignore",
                        help=".Rbuildignore to judge them by; CI passes the base's")
    args = parser.parse_args(argv)

    changed = []
    if args.changed_files:
        changed = [ln.strip() for ln in args.changed_files.read_text().splitlines()
                   if ln.strip()]
    code = main_with(
        args.base_description.read_text(),
        args.description.read_text(),
        args.news.read_text(),
        changed,
        read_rbuildignore(args.rbuildignore.read_text()),
    )
    if code == 0:
        print(f"version ok: {read_version(args.description.read_text(), 'DESCRIPTION')}")
    return code


if __name__ == "__main__":
    sys.exit(main())
