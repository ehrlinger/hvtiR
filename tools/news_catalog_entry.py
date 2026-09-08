"""File a NEWS entry for a catalog refresh, so the refresh can pass its own gate.

Why this exists
---------------
`catalog-versions.yml` opens a pull request that changes
`inst/extdata/catalog.csv` and nothing else. `check_version.py` fails exactly
that shape: the version is unchanged from the base branch AND there is no
standing `# hvtiR (unreleased)` heading to file the entry under. Both guards
are right, and the machine pull request could satisfy neither on its own, so
every such refresh needed a hand-written NEWS commit before it could merge.

It is not an occasional collision. The unreleased heading is REMOVED by every
naming commit, so a refresh landing between a bump and the next unreleased
change hits this every time -- and that is most of them, since cutting a
release is what tends to prompt someone to look at the catalog. 1.1.6 was
named minutes before the refresh that exposed it.

The entry is warranted on merits, not written to appease a check.
`catalog.csv` ships in the package and is published as `members.json`, which
the CV, the profile README and the personal site all render from. A change to
its recorded versions is content.

What it does
------------
Compares two catalogs, and when a recorded version moved:

  * ensures a `# hvtiR (unreleased)` heading exists, creating it directly
    above the newest version heading when it does not;
  * appends one bullet naming every package that moved and in which column.

It NEVER creates a second unreleased heading, and never duplicates a bullet it
has already written -- the refresh branch is regenerated weekly and reruns must
converge rather than accumulate.

Standard library only -- no pip install step on the runner.
"""
from __future__ import annotations

import argparse
import csv
import sys
import textwrap
from pathlib import Path

UNRELEASED = "# hvtiR (unreleased)"
VERSION_COLUMNS = ("cran_version", "dev_version")
MARKER = "Catalog versions refreshed"


def read_catalog(path: Path) -> dict[str, dict]:
    try:
        with path.open(newline="") as handle:
            rows = {r["package"]: r for r in csv.DictReader(handle)
                    if r.get("package")}
    except (OSError, csv.Error) as err:
        raise SystemExit(f"error: could not read {path}: {err}")
    if not rows:
        raise SystemExit(f"error: {path} holds no rows")
    return rows


def describe(before: dict[str, dict], after: dict[str, dict]) -> list[str]:
    """One phrase per moved value, in catalog order."""
    moved: list[str] = []
    for package, row in after.items():
        old = before.get(package)
        if old is None:
            # A new row is a new member, not a version move. Its arrival is
            # narrated by whoever added it; saying "'' -> 0.1.0" here would
            # read as drift.
            continue
        for column in VERSION_COLUMNS:
            was, now = (old.get(column) or "").strip(), (row.get(column) or "").strip()
            if was != now:
                where = "CRAN" if column == "cran_version" else "dev"
                moved.append(f"`{package}` {where} "
                             f"{was or 'unrecorded'} to {now or 'unrecorded'}")
    return moved


def bullet(moved: list[str]) -> str:
    """One wrapped bullet. Wrapped because every other entry in NEWS.md is,
    and a single long line makes the file's diffs unreadable for the humans
    who write the entries either side of it."""
    body = "; ".join(moved)
    text = (f"* {MARKER} from CRAN and `main`: {body}. The catalog ships in "
            f"the package and is published as `members.json`, so its recorded "
            f"versions are content rather than bookkeeping.")
    return textwrap.fill(text, width=76, subsequent_indent="  ")


def insert(news: str, line: str) -> str:
    """Put `line` in the unreleased section, creating the heading if needed."""
    if line in news:
        return news  # already filed; reruns must converge

    if UNRELEASED in news:
        start = news.index(UNRELEASED) + len(UNRELEASED)
        nxt = news.find("\n# ", start)
        end = len(news) if nxt == -1 else nxt
        section = news[start:end].rstrip("\n")
        return news[:start] + section + "\n" + line + "\n\n" + news[end:].lstrip("\n")

    # No unreleased section: open one directly above the newest version
    # heading, which is where the next naming commit expects to find it.
    first = news.find("\n# hvtiR ")
    if first == -1:
        raise SystemExit("error: NEWS.md has no '# hvtiR <version>' heading to "
                         "anchor the unreleased section above")
    at = first + 1
    return news[:at] + f"{UNRELEASED}\n\n{line}\n\n" + news[at:]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--before", required=True, type=Path)
    parser.add_argument("--after", required=True, type=Path)
    parser.add_argument("--news", required=True, type=Path)
    args = parser.parse_args()

    moved = describe(read_catalog(args.before), read_catalog(args.after))
    if not moved:
        print("No recorded version moved; NEWS.md left alone.")
        return 0

    try:
        news = args.news.read_text()
    except OSError as err:
        raise SystemExit(f"error: could not read {args.news}: {err}")

    updated = insert(news, bullet(moved))
    if updated == news:
        print(f"Entry already filed for: {'; '.join(moved)}")
        return 0

    args.news.write_text(updated)
    print(f"Filed under '{UNRELEASED}': {'; '.join(moved)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
