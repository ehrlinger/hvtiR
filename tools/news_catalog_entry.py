"""Write a NEWS fragment for a catalog refresh, so the refresh can pass its own gate.

Why this exists
---------------
`catalog-versions.yml` opens a pull request that changes
`inst/extdata/catalog.csv` and nothing else. `check_version.py` fails exactly
that shape: the version is unchanged from the base branch AND the pull request
adds no `news/` fragment. Both guards are right, and the machine pull request
could not satisfy either on its own, so every such refresh needed a
hand-written NEWS commit before it could merge.

The entry is warranted on merits, not written to appease a check.
`catalog.csv` ships in the package and is published as `members.json`, which
the CV, the profile README and the personal site all render from. A change to
its recorded versions is content.

What it does
------------
Compares two catalogs, and when a recorded version moved, writes one bullet
naming every package that moved, and in which column, to
`news/chore-catalog-version-refresh-<date>.md`. The bump collects it into
NEWS.md with the other fragments.

The date keeps each week's fragment a file of its own. A plain
`news/<branch>.md` would collide with last week's when that refresh has merged
and not yet been collected: overwriting it would lose last week's bullet, and
editing it would not count as adding a fragment. A rerun on the same day
rewrites the same file, so reruns converge rather than accumulate.

Standard library only -- no pip install step on the runner.
"""
from __future__ import annotations

import argparse
import csv
import datetime
import sys
import textwrap
from pathlib import Path

FRAGMENT_STEM = "chore-catalog-version-refresh"
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


def fragment_path(news_dir: Path, day: datetime.date) -> Path:
    """This run's fragment: one file per day, so weeks never collide."""
    return news_dir / f"{FRAGMENT_STEM}-{day.isoformat()}.md"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--before", required=True, type=Path)
    parser.add_argument("--after", required=True, type=Path)
    parser.add_argument("--news-dir", type=Path, default=Path("news"))
    parser.add_argument("--date", type=datetime.date.fromisoformat,
                        default=datetime.datetime.now(datetime.timezone.utc).date(),
                        help="the fragment's date, YYYY-MM-DD; default today (UTC)")
    args = parser.parse_args()

    moved = describe(read_catalog(args.before), read_catalog(args.after))
    if not moved:
        print("No recorded version moved; no fragment written.")
        return 0

    path = fragment_path(args.news_dir, args.date)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(bullet(moved) + "\n")
    print(f"Wrote {path}: {'; '.join(moved)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
