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

Firing needs no list of consumers; CLEARING does
-----------------------------------------------
The two directions are not symmetric, and an early version of this file got
that wrong in the dangerous direction.

  main != newest tag  =>  EVERY pin is stale, whatever tag it names, because
                          no tag can contain a change that postdates all of
                          them. Sound with no knowledge of consumers.

  main == newest tag  =>  says only that a tag containing the current catalog
                          EXISTS. It says nothing about which tag anybody
                          checks out. NOT sound.

So the alarm can be raised from local knowledge alone, and cannot be cleared
from it. The remedy this file prints has two steps -- name a version and tag
it, THEN advance `ref:` in the consumer -- and `main == newest tag` observes
only the first. Clearing on it closes the alarm halfway through the remedy and
then stays quiet forever, which is worse than never having raised it.

Clearing therefore requires reading the consumer refs and finding every one of
them equal to the newest tag. When a ref cannot be read the answer is PENDING,
never CURRENT: an unverifiable pin is not a verified one.

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

# Exit codes. 0, 2 and 3 are the only ones returned deliberately; anything else
# is the interpreter, and a caller keying on "not 0" would read a crash as
# drift.
#
# PENDING exists so that "not verified current" and "verified current" cannot
# collapse into one code. The caller closes its tracking issue on CURRENT and
# on nothing else, so every unverifiable state leaves the alarm standing.
CURRENT = 0
ERROR = 1
DRIFT = 2
PENDING = 3

DEFAULT_GRACE_DAYS = 7

# How a consumer pins this repository, in its own workflow YAML:
#
#     - uses: actions/checkout@v4
#       with:
#         repository: ehrlinger/hvtiR
#         ref: v1.1.5
#
# Parsed here rather than grepped in the workflow because a grep for `ref:`
# matches the wrong step as soon as a consumer checks out anything else, and it
# fails by returning a plausible wrong answer rather than by erroring.
CONSUMER_REPO = "ehrlinger/hvtiR"


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


def extract_pinned_ref(text: str, repository: str = CONSUMER_REPO) -> str | None:
    """The `ref:` belonging to the checkout step that names `repository`.

    Returns None when there is no such step or it carries no ref -- and None
    means PENDING upstream, never "fine". A checkout with no `ref:` takes the
    default branch, which is not a pin at all and must not read as a current
    one.

    Deliberately scoped: the ref must appear within the same `with:` block, so
    a later unrelated checkout cannot donate its ref to this one.
    """
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.strip() != f"repository: {repository}":
            continue
        indent = len(line) - len(line.lstrip())
        for follow in lines[i + 1:]:
            if not follow.strip():
                continue
            follow_indent = len(follow) - len(follow.lstrip())
            # Dedent ends the block; a sibling key at the same indent is still
            # inside it.
            if follow_indent < indent:
                break
            if follow_indent == indent and follow.strip().startswith("ref:"):
                return follow.strip()[len("ref:"):].strip().strip("'\"")
        return None
    return None


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


def consumer_report(tag: str, stale: list[tuple[str, str | None]]) -> str:
    lines = [
        f"The catalog on `main` is tagged as `{tag}`, but not every consumer "
        f"is reading it yet.",
        "",
    ]
    for label, ref in stale:
        seen = f"pins `{ref}`" if ref else "pins nothing (takes the default branch)"
        lines.append(f"* `{label}` {seen}, not `{tag}`.")
    lines += [
        "",
        "Tagging is only half the remedy. Until these refs move, the consumer "
        "still validates against an older catalog than this package ships, and "
        "its guards still pass while it does.",
    ]
    return "\n".join(lines)


def parse_consumer(spec: str) -> tuple[str, Path]:
    """`label=path` -- the workflow file a consumer pins this repository in."""
    label, _, path = spec.partition("=")
    if not label or not path:
        raise SystemExit(f"error: --consumer wants label=path, got {spec!r}")
    return label, Path(path)


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
    parser.add_argument("--consumer", action="append", default=[],
                        metavar="LABEL=PATH",
                        help="a consumer workflow file to read the pinned ref "
                             "from; repeatable")
    parser.add_argument("--tag-age-days", type=int, default=None,
                        help="days since the newest tag was created; consumers "
                             "are given the same grace to catch up")
    args = parser.parse_args()

    delta = compare(load_rows(args.current), load_rows(args.tagged))

    if any(delta.values()):
        total = sum(len(v) for v in delta.values())
        if args.ahead_days < args.grace_days:
            # Deliberately not silent. "Ahead, within grace" and "verified
            # current" are different states, and a run that prints the same
            # thing for both cannot be used to tell the check still works.
            print(f"jobs.json on main is ahead of {args.tag} by {total} "
                  f"row(s), for {args.ahead_days} day(s). Within the "
                  f"{args.grace_days}-day grace period, so this is the normal "
                  f"unreleased window.")
            return PENDING
        print(report(args.tag, args.ahead_days, delta))
        return DRIFT

    # The catalog is tagged. That is NOT the same as the consumers reading it,
    # and treating it as such closes the alarm halfway through the remedy.
    if not args.consumer:
        print(f"jobs.json on main matches {args.tag}. No consumer was given, "
              f"so whether anything actually reads that tag is unverified.")
        return PENDING

    stale: list[tuple[str, str | None]] = []
    unreadable: list[str] = []
    for spec in args.consumer:
        label, path = parse_consumer(spec)
        try:
            text = path.read_text()
        except OSError as err:
            unreadable.append(f"{label} ({err})")
            continue
        ref = extract_pinned_ref(text)
        if ref != args.tag:
            stale.append((label, ref))

    if unreadable:
        # An unverifiable pin is not a verified one. Returning CURRENT here
        # would close the alarm on the strength of a failed network call.
        print(f"jobs.json on main matches {args.tag}, but these consumers "
              f"could not be read, so the pins are unverified: "
              + "; ".join(unreadable))
        return PENDING

    if not stale:
        print(f"jobs.json on main matches {args.tag}, and every consumer pins "
              f"it: {', '.join(parse_consumer(c)[0] for c in args.consumer)}.")
        return CURRENT

    if args.tag_age_days is not None and args.tag_age_days < args.grace_days:
        print(f"jobs.json on main matches {args.tag}, but "
              f"{len(stale)} consumer ref(s) have not moved yet. The tag is "
              f"{args.tag_age_days} day(s) old, within the "
              f"{args.grace_days}-day grace period.")
        return PENDING

    print(consumer_report(args.tag, stale))
    return DRIFT


if __name__ == "__main__":
    sys.exit(main())
