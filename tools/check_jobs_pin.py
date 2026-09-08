"""Report when hvtiR's job catalog on `main` has outrun its newest tag.

The problem
-----------
`inst/extdata/jobs.json` is read by sibling repositories, not imported. They
cannot depend on it: `hvtiR` installs the family, so a `DESCRIPTION` entry
would invert the dependency. `hvtiRtemplates` therefore checks the catalog
out by TAG in `R-CMD-check.yaml` and `spec-counts.yaml`, deliberately, so that
editing the catalog here cannot fail every pull request there.

That pin is correct and it has a shelf life. When the catalog on `main` moves
past the newest tag, the pin still resolves and every guard on both sides
still passes -- while the consumer validates against a catalog older than the
one this package ships. Between v1.1.3 and v1.1.5 that gap was fourteen
changed rows, and nothing reported it; it closed because somebody happened to
advance the pin by hand.

Two copies of one definition, each locally valid, guards green on both sides,
and nothing reporting the divergence, is the SAS failure mode this migration
exists to escape. The difference in our favour is that a tag IS a version, so
the fork is diagnosable -- but only if something looks.

Why this needs no list of consumers
-----------------------------------
It compares `main` against this repository's own newest tag, which is entirely
local knowledge. If the catalog on `main` has moved past that tag then EVERY
pin is stale, whatever tag it names, because no tag can contain a change that
postdates all of them. Enumerating consumers would add a second registry to
keep correct, and this repository already has one of those.

Why a grace period
------------------
The house cadence is to land work under a standing `# hvtiR (unreleased)`
heading and name the version separately. So `main` ahead of the newest tag is
the NORMAL state for a day or two, not a defect. Reporting it immediately
would flag the convention working as designed, and an alarm that fires on
correct behaviour is trained away -- the same reasoning `catalog-versions.yml`
records for not failing a build on routine drift.

What it deliberately does not do
--------------------------------
It does not fail. The remedy is to cut a release and advance the pin, which is
a maintainer's decision, so there is nothing for a red check to make anyone do
faster. The caller reports; it does not block.

Standard library only -- no pip install step on the runner.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Exit codes. 0 and 2 are the only ones returned deliberately; anything else is
# the interpreter, and a caller keying on "not 0" would read a crash as drift.
OK = 0
ERROR = 1
DRIFT = 2

DEFAULT_GRACE_DAYS = 7


def load_rows(path: Path) -> dict[tuple[str, str | None], dict]:
    """Rows keyed by (prefix, qualifier).

    Keyed on the pair, not on `prefix` alone: the catalog carries several rows
    per prefix distinguished only by their qualifier, and collapsing them
    silently drops every row but the last -- which reads as "no drift".
    """
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as err:
        raise SystemExit(f"error: could not read {path}: {err}")
    rows = data.get("jobs", data) if isinstance(data, dict) else data
    if not isinstance(rows, list):
        raise SystemExit(f"error: {path} does not hold a list of job rows")
    keyed: dict[tuple[str, str | None], dict] = {}
    for row in rows:
        if not isinstance(row, dict) or "prefix" not in row:
            raise SystemExit(f"error: {path} has a row with no prefix")
        keyed[(row["prefix"], row.get("qualifier"))] = row
    if not keyed:
        raise SystemExit(f"error: {path} holds no rows")
    return keyed


def name(key: tuple[str, str | None]) -> str:
    prefix, qualifier = key
    return f"{prefix}-{qualifier}" if qualifier else prefix


def compare(current: dict, tagged: dict) -> dict[str, list[str]]:
    """What `main` has that the tag does not, and vice versa."""
    added = sorted(name(k) for k in current.keys() - tagged.keys())
    removed = sorted(name(k) for k in tagged.keys() - current.keys())
    changed = sorted(
        name(k) for k in current.keys() & tagged.keys()
        if current[k] != tagged[k]
    )
    return {"added": added, "removed": removed, "changed": changed}


def report(tag: str, days: int, delta: dict[str, list[str]]) -> str:
    lines = [
        f"The job catalog on `main` has moved past `{tag}`, the newest tag, "
        f"and has been ahead for {days} day(s).",
        "",
        "Every consumer pinning a tag is therefore reading a catalog older "
        "than this package ships. The pins still resolve and their guards "
        "still pass, which is why nothing else reports this.",
        "",
    ]
    for label, key in (("Rows only on `main`", "added"),
                       ("Rows only in the tag", "removed"),
                       ("Rows that differ", "changed")):
        if delta[key]:
            lines.append(f"**{label}** ({len(delta[key])}): "
                         + ", ".join(f"`{n}`" for n in delta[key]))
    lines += [
        "",
        "Remedy: name a version and tag it, then advance `ref:` in "
        "`hvtiRtemplates`'s `R-CMD-check.yaml` and `spec-counts.yaml`. "
        "Both must move; they are pinned independently.",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--current", required=True, type=Path,
                        help="jobs.json as it stands on main")
    parser.add_argument("--tagged", required=True, type=Path,
                        help="jobs.json as of the newest tag")
    parser.add_argument("--tag", required=True, help="the newest tag's name")
    parser.add_argument("--ahead-days", required=True, type=int,
                        help="days since the catalog on main last changed")
    parser.add_argument("--grace-days", type=int, default=DEFAULT_GRACE_DAYS,
                        help=f"stay quiet for this long (default "
                             f"{DEFAULT_GRACE_DAYS})")
    args = parser.parse_args()

    delta = compare(load_rows(args.current), load_rows(args.tagged))
    if not any(delta.values()):
        print(f"jobs.json on main matches {args.tag}; every pin is current.")
        return OK

    total = sum(len(v) for v in delta.values())
    if args.ahead_days < args.grace_days:
        # Deliberately not silent. "Ahead, within grace" and "not ahead" are
        # different states, and a run that prints the same thing for both
        # cannot be used to tell whether the check is still working.
        print(f"jobs.json on main is ahead of {args.tag} by {total} row(s), "
              f"for {args.ahead_days} day(s). Within the {args.grace_days}-day "
              f"grace period, so this is the normal unreleased window.")
        return OK

    print(report(args.tag, args.ahead_days, delta))
    return DRIFT


if __name__ == "__main__":
    sys.exit(main())
