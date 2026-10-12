"""Refresh the catalog's version columns from their live oracles.

The family table in the CV tracking note went stale six rows in seven days,
and both cells marked as DESCRIPTION-backed were wrong. This script exists so
that the recorded versions are refreshed by a machine on a schedule instead of
by a person who has to remember to look.

Two facts, two oracles, and they are not interchangeable:

* `cran_version` -- what the public can install, from crandb.r-pkg.org.
* `dev_version`  -- what `main` carries, from raw.githubusercontent.com.

Never read a local working tree: on the day this was written, six of eleven
clones sat on feature branches whose DESCRIPTION ran ahead of what was
released, so a local sweep would have recorded unreleased numbers. Never read
a repomap either -- it is a 15-minute cache of a DESCRIPTION, and it is what
the version-marking convention that failed had relied on.

`dev_ahead` is NOT refreshed here. It records intent, and no oracle returns
intent: a deliberate pre-CRAN development line and a stale row look identical.
It is preserved from the existing file and maintained by hand.

It also writes the family floor table, `inst/extdata/family-floors.csv`: one
row per version floor a member declares on another member, read from the same
DESCRIPTION files. No other tool reads those floors (`dependency_floors()` in
R/status.R drops every `Remotes:` package), and `install()` resolves members
from `main` in one pak call, so a floor raised past a sibling's `main` breaks
every install. An unsatisfiable `Depends`/`Imports`/`LinkingTo` floor exits 3;
see dev/specs/2026-10-12-family-version-coherence-design.md.

Standard library only -- this runs on a CI runner with no pip install step.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
import sys
import time
from pathlib import Path

VERSION_COLUMNS = ("cran_version", "dev_version", "dev_ahead")
AHEAD_VALUES = ("", "expected", "unexpected")

# Base seconds between retried attempts, scaled by the attempt just failed,
# matching remote_retry_wait in R/remote.R. Retrying with no wait at all is
# not a retry: the case these attempts exist for is a throttled shared-IP
# runner, and three requests fired inside a millisecond meet the same closed
# window three times.
RETRY_WAIT = 1

# Fields whose floors the table records, and the ones that break an install.
# A Suggests floor degrades a template; it does not stop pak from solving.
FLOOR_FIELDS = ("Depends", "Imports", "LinkingTo", "Suggests")
HARD_FIELDS = ("Depends", "Imports", "LinkingTo")
FLOOR_COLUMNS = ("package", "field", "dependency", "op", "floor",
                 "dependency_dev", "satisfied")

CRAN_URL = "https://crandb.r-pkg.org/{pkg}"
DEV_URL = "https://raw.githubusercontent.com/{repo}/main/DESCRIPTION"


def fetch(url: str, attempts: int = 3, timeout: int = 25) -> tuple[int, str]:
    """GET a URL, retrying transient failures. Returns (http_status, body).

    A busy shared-IP runner is throttled rather than unreachable, and a
    renamed repository fails the same way a timeout does -- only persistence
    separates the two. Mirrors the retry rationale in test-registry-live.R.

    The status code is returned rather than swallowed because 404 and "the
    network stalled" mean opposite things here and must not be retried alike.
    A status of 0 means curl never got a response at all.

    When the attempts run out, the LAST status seen is returned rather than 0.
    A 429 and a connection that never opened are both unreadable, but they are
    unreadable for opposite reasons, and the caller's failure message names
    only permanent causes. Reporting "throttled" as "renamed, private, default
    branch moved, or the file is gone" points the reader at the wrong repair.
    """
    code = 0
    for attempt in range(1, attempts + 1):
        done = subprocess.run(
            ["curl", "-s", "--max-time", str(timeout),
             "-w", "\n%{http_code}", url],
            capture_output=True,
            text=True,
        )
        if done.returncode == 0:
            body, _, status = done.stdout.rpartition("\n")
            code = int(status) if status.strip().isdigit() else 0
            # A 404 is a settled answer, not a stall: retrying cannot change it.
            if code == 200 or code == 404:
                return code, body
        else:
            code = 0
        if attempt < attempts:
            time.sleep(RETRY_WAIT * attempt)
    return code, ""


def dev_version(repo: str, expected: bool) -> tuple[str | None, int]:
    """See `dev_description()`; this drops the body."""
    version, code, _ = dev_description(repo, expected)
    return version, code


def dev_description(repo: str, expected: bool) -> tuple[str | None, int, str]:
    """Version: from the repo's DESCRIPTION on main, with the status seen.

    The value is None when unreadable. The status rides along so the caller
    can say WHY: a 404 and a 429 are both unreadable and want opposite
    repairs, and a message naming only the permanent causes sends the reader
    to check a rename that never happened.

    `expected` says whether this row is supposed to have a DESCRIPTION at all,
    and it decides how a 404 is read. GitHub answers 404 identically for a
    repository that legitimately has no DESCRIPTION, one that was renamed, one
    that went private, one whose default branch is no longer `main`, and one
    that lost the file by accident. The status code cannot separate those; only
    knowing what the row should contain can.

    So: for a row with no DESCRIPTION expected (`hazard` is SAS/C,
    `HVTI Recipes` is a Quarto book), 404 is a settled answer and "" is
    correct. For a row that should have one, 404 is a failure -- the caller
    keeps the recorded version and reports it, rather than blanking a
    known-good value and staying silent about it.

    The body rides along too, so the floor table reads the same file rather
    than fetching every DESCRIPTION a second time.
    """
    code, body = fetch(DEV_URL.format(repo=repo))
    if code == 404:
        return (None if expected else ""), code, ""
    if code != 200:
        return None, code, ""
    for line in body.splitlines():
        if line.startswith("Version:"):
            return line.split(":", 1)[1].strip(), code, body
    # Reached main and read a DESCRIPTION with no Version: field. That is a
    # malformed file, not an absent package, so report it rather than blank.
    return (None if expected else ""), code, ""


def why_unreadable(code: int) -> str:
    """What a status code means for someone who has to go and fix it."""
    if code == 404:
        return "renamed, private, default branch moved, or the file is gone"
    if code == 0:
        return "no response at all: offline, DNS, or the request timed out"
    if code == 429:
        return f"throttled (HTTP {code}); the retries did not outlast it"
    return f"HTTP {code}"


def expects_description(row: dict) -> bool:
    """Whether this catalog row should have a DESCRIPTION on main.

    Derived from the catalog rather than an allowlist of package names, so a
    new member is covered the day it is added. `family == "member"` means an R
    package in the registry; a row that already carries a dev_version is
    holding evidence that it had one, which covers any future R package that
    is not a registry member.
    """
    return row.get("family") == "member" or bool(row.get("dev_version"))


def cran_version(pkg: str) -> str | None:
    """Version from crandb. None means unreadable; "" means not on CRAN.

    A 200 does not guarantee a package record. An error envelope, a proxy or
    captive portal, or an API change can all answer with well-formed JSON that
    is not a package: not an object at all, or an object carrying no Version.
    `.get` on a non-object raises rather than returning None --
    an uncaught exception exits 1, and the schedule used to read 1 as success.
    So the shape is checked, not assumed, and anything unexpected takes the
    same path as an unreadable oracle: report it and keep the recorded value.
    """
    code, body = fetch(CRAN_URL.format(pkg=pkg))
    if code == 404:
        return ""
    if code != 200:
        return None
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return None
    if not isinstance(payload, dict):
        return None
    version = payload.get("Version")
    # "" is reserved for an authoritative 404: the package is not on CRAN.
    # A 200 object with no Version -- {} or an error envelope such as
    # {"error": "upstream unavailable"} -- is not that answer, and letting it
    # fall through to "" blanked a recorded version and reported no failure.
    # Absent, empty and non-string all mean the same thing here: unreadable.
    if not isinstance(version, str) or not version:
        return None
    return version


def refresh(rows: list[dict],
            descriptions: dict[str, str] | None = None
            ) -> tuple[list[dict], list[str]]:
    """Return refreshed rows and a list of human-readable failures.

    When `descriptions` is given, each DESCRIPTION read from `main` is stored
    in it under the row's package name, for the floor table.

    A row whose oracle could not be read keeps its existing recorded value and
    is reported. Overwriting a known-good version with an empty string because
    the network stalled would turn an outage into data loss -- the exact
    "result-shaped nothing" failure this family has been bitten by before.
    """
    failures: list[str] = []

    for row in rows:
        if row.get("cran"):
            live = cran_version(row["cran"])
            if live is None:
                failures.append(f"{row['package']}: could not read CRAN")
            else:
                row["cran_version"] = live
        else:
            row["cran_version"] = ""

        if row.get("repo"):
            live, code, body = dev_description(row["repo"],
                                               expects_description(row))
            if body and descriptions is not None:
                descriptions[row["package"]] = body
            if live is None:
                failures.append(
                    f"{row['package']}: could not read DESCRIPTION on main "
                    f"({row['repo']}) -- {why_unreadable(code)}"
                )
            else:
                row["dev_version"] = live
        else:
            row["dev_version"] = ""

        row.setdefault("dev_ahead", "")

    return rows, failures


def dcf_fields(text: str) -> dict[str, str]:
    """A DESCRIPTION's fields, continuation lines joined with a space."""
    fields: dict[str, str] = {}
    key = None
    for line in text.splitlines():
        if line[:1] in (" ", "\t") and key:
            fields[key] += " " + line.strip()
        elif ":" in line:
            key, _, value = line.partition(":")
            key = key.strip()
            fields[key] = value.strip()
    return fields


# The operator is kept, not normalised: R reads (> 1.5.1) as strictly newer,
# so 1.5.1 meets (>= 1.5.1) and does not meet (> 1.5.1). dependency_floors()
# in R/status.R keeps the same distinction.
DEPENDENCY = re.compile(
    r"^([A-Za-z][A-Za-z0-9.]*)\s*(?:\(\s*(>=?)\s*([0-9][0-9.-]*)\s*\))?$")


def version_key(version: str) -> tuple[int, ...]:
    """Numeric sort key, compared the way R's package_version() compares.

    1.10.0 is newer than 1.9.0, and trailing zero components do not count:
    R reads 1.5.0 and 1.5 as equal, so 1.5.0 does not meet (> 1.5). Python
    tuples would call (1, 5, 0) newer than (1, 5).
    """
    key = [int(part) for part in re.split(r"[.-]", version) if part.isdigit()]
    while key and key[-1] == 0:
        key.pop()
    return tuple(key)


def verdict(op: str, floor: str, on_main: str) -> str:
    """"TRUE"/"FALSE" for a floor against main's version; "" when there is
    no floor, or no recorded version to judge it against."""
    if not floor or not on_main:
        return ""
    have, need = version_key(on_main), version_key(floor)
    return "TRUE" if (have > need if op == ">" else have >= need) else "FALSE"


def family_floors(rows: list[dict], descriptions: dict[str, str]) -> list[dict]:
    """Table rows for every dependency one member declares on another.

    Members are the catalog rows with `family == "member"`, so the table covers
    a new member the day it is added. `satisfied` is empty for a dependency
    declared without a floor: there is nothing to meet.
    """
    dev = {r["package"]: r.get("dev_version", "") for r in rows
           if r.get("family") == "member"}
    table = []
    for package, text in descriptions.items():
        if package not in dev:
            continue
        fields = dcf_fields(text)
        for field in FLOOR_FIELDS:
            for entry in fields.get(field, "").split(","):
                match = DEPENDENCY.match(entry.strip())
                if not match or match.group(1) not in dev:
                    continue
                name = match.group(1)
                op, floor = match.group(2) or "", match.group(3) or ""
                on_main = dev[name]
                table.append({"package": package, "field": field,
                              "dependency": name, "op": op, "floor": floor,
                              "dependency_dev": on_main,
                              "satisfied": verdict(op, floor, on_main)})
    return sorted(table, key=lambda r: (r["package"], FLOOR_FIELDS.index(r["field"]),
                                        r["dependency"]))


def unsatisfied_floors(table: list[dict]) -> tuple[list[dict], list[dict]]:
    """(hard, soft): unmet floors that break an install, and ones that do not."""
    unmet = [r for r in table if r["satisfied"] == "FALSE"]
    return ([r for r in unmet if r["field"] in HARD_FIELDS],
            [r for r in unmet if r["field"] not in HARD_FIELDS])


def unexplained_gaps(rows: list[dict]) -> list[str]:
    """Packages whose main is ahead of CRAN without that being recorded.

    This is the finding the schedule exists to surface. A gap alone proves
    nothing: hvtiRbootstrap at 0.1.0 against 0.9.3 was rot, TemporalHazard at
    1.1.0 against 1.2.9 is policy, and they read identically. Only dev_ahead
    tells them apart, so an unmarked gap means somebody has to look.
    """
    return [
        row["package"]
        for row in rows
        if row.get("cran_version")
        and row.get("dev_version")
        and row["cran_version"] != row["dev_version"]
        and row.get("dev_ahead") != "expected"
    ]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path, nargs="?",
                        default=Path("inst/extdata/catalog.csv"))
    parser.add_argument("--check", action="store_true",
                        help="report drift without writing the file; exits 0 "
                             "for no drift, 1 for drift, 2 if an oracle "
                             "could not be read and nothing was verified")
    parser.add_argument("--floors", type=Path,
                        default=Path("inst/extdata/family-floors.csv"),
                        help="the family floor table to rewrite")
    args = parser.parse_args(argv)

    with args.catalog.open(newline="") as handle:
        reader = csv.DictReader(handle)
        fields = list(reader.fieldnames or [])
        rows = list(reader)

    for column in VERSION_COLUMNS:
        if column not in fields:
            fields.append(column)

    before = [(r["package"], r.get("cran_version", ""), r.get("dev_version", ""))
              for r in rows]
    descriptions: dict[str, str] = {}
    rows, failures = refresh(rows, descriptions)
    after = [(r["package"], r["cran_version"], r["dev_version"]) for r in rows]

    for was, now in zip(before, after):
        if was != now:
            print(f"drift: {now[0]} cran {was[1] or '-'} -> {now[1] or '-'}, "
                  f"main {was[2] or '-'} -> {now[2] or '-'}")

    for gap in unexplained_gaps(rows):
        print(f"unexplained gap: {gap} is ahead of CRAN and dev_ahead is not "
              f"'expected' -- set it, or cut the release")

    for failure in failures:
        print(f"WARNING {failure}; kept the recorded value", file=sys.stderr)

    # A member whose DESCRIPTION could not be read keeps its recorded
    # declarations, for the same reason a version is kept: an outage is not a
    # change. Only the declaration is kept. The dependency's version and the
    # verdict are recomputed from this run, or an upstream that has since
    # caught up would go on failing the job against its old version.
    table = family_floors(rows, descriptions)
    prior: list[dict] = []
    if args.floors.exists():
        with args.floors.open(newline="") as handle:
            prior = [{c: r.get(c, "") for c in FLOOR_COLUMNS}
                     for r in csv.DictReader(handle)]
        dev = {r["package"]: r.get("dev_version", "") for r in rows}
        read = set(descriptions)
        for r in prior:
            if r["package"] in read:
                continue
            # A table written before the op column existed meant >=.
            op = r["op"] or (">=" if r["floor"] else "")
            on_main = dev.get(r["dependency"], r["dependency_dev"])
            table.append(dict(r, op=op, dependency_dev=on_main,
                              satisfied=verdict(op, r["floor"], on_main)))
        table.sort(key=lambda r: (r["package"], FLOOR_FIELDS.index(r["field"]),
                                  r["dependency"]))
    hard, soft = unsatisfied_floors(table)
    for r in hard:
        print(f"unsatisfiable floor: {r['package']} {r['field']} "
              f"{r['dependency']} ({r['op']} {r['floor']}) but main carries "
              f"{r['dependency_dev']}; install() fails until this is fixed")
    for r in soft:
        print(f"unsatisfied suggests floor: {r['package']} {r['field']} "
              f"{r['dependency']} ({r['op']} {r['floor']}) but main carries "
              f"{r['dependency_dev']}")

    if args.check:
        # An unreadable oracle outranks "no drift". A failed fetch keeps the
        # recorded value, so `before == after` holds just as firmly when every
        # row was verified and unchanged as when NOTHING was verified at all.
        # Returning 0 for the second case is the "result-shaped nothing" this
        # module's own docstring warns against, and it would let a check job
        # go green having confirmed no version anywhere.
        # The floor table is drift too: a raised floor with every version
        # unchanged rewrites it on a normal run, so --check must not call it 0.
        if hard:
            return 3
        if failures:
            return 2
        return 1 if before != after or table != prior else 0

    with args.catalog.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        writer.writerows(rows)

    with args.floors.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FLOOR_COLUMNS,
                                quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        writer.writerows(table)

    # An unsatisfiable hard floor outranks everything: it breaks install() for
    # every user, which no unread oracle does. 3, so the workflow can open the
    # pull request carrying the report and fail the job afterwards.
    if hard:
        return 3
    # A failed fetch is not a failed run: the file is still correct, just not
    # fully re-verified. Exit non-zero only so the schedule surfaces it.
    return 2 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
