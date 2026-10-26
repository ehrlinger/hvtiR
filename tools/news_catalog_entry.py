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

The job also commits `inst/extdata/family-floors.csv`. A floor raised with
every version unchanged would otherwise be the same gate failure, so a change
to a declared floor (added, removed, or a new operator or version) writes a
bullet of its own. A moved `dependency_dev` or verdict is not floor news: it
follows a version move, which the catalog bullet already names.

The date keeps each week's fragment a file of its own. A plain
`news/<branch>.md` would collide with last week's when that refresh has merged
and not yet been collected: overwriting it would lose last week's bullet, and
editing it would not count as adding a fragment. The same holds within a day:
a name the checkout already holds belongs to a merged refresh, so the next
free `-2`, `-3`, ... is used. A rerun before merge starts from the same `main`,
lands on the same name and rewrites its pull request branch, so reruns
converge rather than accumulate.

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
FLOOR_MARKER = "Family floors refreshed"


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


def read_floors(path: Path | None) -> dict[tuple, tuple]:
    """{(package, field, dependency): (op, floor)}; empty when no table."""
    if path is None or not path.exists():
        return {}
    with path.open(newline="") as handle:
        return {(r["package"], r["field"], r["dependency"]):
                (r.get("op", "") or (">=" if r.get("floor") else ""),
                 r.get("floor", ""))
                for r in csv.DictReader(handle)}


def describe_floors(before: dict[tuple, tuple],
                    after: dict[tuple, tuple]) -> list[str]:
    """One phrase per declaration added, removed or changed, sorted."""
    def floor(op_floor: tuple) -> str:
        op, version = op_floor
        return f" ({op} {version})" if version else ""

    moved = []
    for key in sorted(set(before) | set(after)):
        package, field, dependency = key
        name = f"`{package}` {field} `{dependency}`"
        if key not in before:
            moved.append(f"{name}{floor(after[key])} added")
        elif key not in after:
            moved.append(f"{name}{floor(before[key])} removed")
        elif before[key] != after[key]:
            was = floor(before[key]).strip() or "(no floor)"
            now = floor(after[key]).strip() or "(no floor)"
            moved.append(f"{name} {was} to {now}")
    return moved


def floor_bullet(moved: list[str]) -> str:
    """The floor table's own bullet, wrapped like the catalog one."""
    text = (f"* {FLOOR_MARKER} from `main`: {'; '.join(moved)}. "
            f"`family-floors.csv` ships in the package and records the version "
            f"floors members declare on one another.")
    return textwrap.fill(text, width=76, subsequent_indent="  ",
                         break_on_hyphens=False)


def bullet(moved: list[str]) -> str:
    """One wrapped bullet. Wrapped because every other entry in NEWS.md is,
    and a single long line makes the file's diffs unreadable for the humans
    who write the entries either side of it. Neither bullet breaks at a
    hyphen: inside a code span such as `family-floors.csv`, that break
    renders as two words."""
    body = "; ".join(moved)
    # Name only the oracle that moved. Most members never go to CRAN, so a
    # fixed "from CRAN and `main`" put CRAN beside packages it has never held.
    sources = [name for name, kind in (("CRAN", "` CRAN "), ("`main`", "` dev "))
               if any(kind in phrase for phrase in moved)]
    text = (f"* {MARKER} from {' and '.join(sources)}: {body}. "
            f"The catalog ships in "
            f"the package and is published as `members.json`, so its recorded "
            f"versions are content rather than bookkeeping.")
    return textwrap.fill(text, width=76, subsequent_indent="  ",
                         break_on_hyphens=False)


def fragment_path(news_dir: Path, day: datetime.date) -> Path:
    """This run's fragment: dated, and never a name `news_dir` already holds.

    The job runs on a fresh checkout of `main`, so a fragment already there
    belongs to a refresh that has merged and not yet been collected. Writing
    over it drops that refresh's bullet and turns an added fragment into an
    edit, which check_version rejects; both happened on 2026-10-12, when two
    refreshes merged the same day. So the next free `-2`, `-3`, ... is taken.
    An unmerged refresh's fragment lives only on its pull request branch, so a
    rerun still lands on the same name and rewrites that branch.
    """
    stem = f"{FRAGMENT_STEM}-{day.isoformat()}"
    path, n = news_dir / f"{stem}.md", 1
    while path.exists():
        n += 1
        path = news_dir / f"{stem}-{n}.md"
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--before", required=True, type=Path)
    parser.add_argument("--after", required=True, type=Path)
    parser.add_argument("--floors-before", type=Path,
                        help="family-floors.csv before the refresh")
    parser.add_argument("--floors-after", type=Path,
                        help="family-floors.csv after the refresh")
    parser.add_argument("--news-dir", type=Path, default=Path("news"))
    parser.add_argument("--date", type=datetime.date.fromisoformat,
                        default=datetime.datetime.now(datetime.timezone.utc).date(),
                        help="the fragment's date, YYYY-MM-DD; default today (UTC)")
    args = parser.parse_args()

    moved = describe(read_catalog(args.before), read_catalog(args.after))
    floors = describe_floors(read_floors(args.floors_before),
                             read_floors(args.floors_after))
    if not moved and not floors:
        print("No recorded version or floor moved; no fragment written.")
        return 0

    bullets = ([bullet(moved)] if moved else []) + \
              ([floor_bullet(floors)] if floors else [])
    path = fragment_path(args.news_dir, args.date)
    path.parent.mkdir(parents=True, exist_ok=True)
    # A blank line between bullets, as between every other entry in NEWS.md.
    path.write_text("\n\n".join(bullets) + "\n")
    print(f"Wrote {path}: {'; '.join(moved + floors)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
