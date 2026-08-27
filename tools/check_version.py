"""Fail a pull request whose version has not moved past the base branch.

Two branches bumping to the same version do not conflict in git: the identical
`Version:` line merges silently and only NEWS.md shows a conflict. Resolving
just what git shows you then ships two releases claiming one number, which
happened twice in a single day before this guard existed.

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


def compare(base: str, head: str) -> list:
    """Problems with the head version relative to base. Empty means fine."""
    if parse_version(head) > parse_version(base):
        return []
    if base == head:
        return [
            f"DESCRIPTION Version is still {head}, unchanged from the base branch. "
            "Two branches claiming one version merge silently -- bump the patch digit."
        ]
    return [f"DESCRIPTION Version {head} is lower than the base branch's {base}."]


def main_with(base_desc: str, head_desc: str, head_news: str) -> int:
    """Run every check and report all problems, not just the first."""
    problems = []
    try:
        base = read_version(base_desc, "the base branch's DESCRIPTION")
        head = read_version(head_desc, "DESCRIPTION")
        problems += compare(base, head)
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

    if not re.search(rf"^##\s+hvtiR\s+{re.escape(head)}\s*$", head_news, re.M):
        problems.append(f"NEWS.md has no '## hvtiR {head}' heading for this release.")

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
    args = parser.parse_args(argv)

    code = main_with(
        args.base_description.read_text(),
        args.description.read_text(),
        args.news.read_text(),
    )
    if code == 0:
        print(f"version ok: {read_version(args.description.read_text(), 'DESCRIPTION')}")
    return code


if __name__ == "__main__":
    sys.exit(main())
