#!/usr/bin/env python3
"""Report groups of jobs.json rows that share a (destination, family) surface
but disagree on disposition.

WHY THIS EXISTS. dev/specs/2026-09-04-job-catalog-design.md section 9 asked
for a check that would have caught the `rfc` failure: `rfc` sat on the same
`ggRandomForests` reporting surface as `rf` and `rfsrc`, was marked with a
different disposition, and 52 R jobs got written against no template before
anyone noticed. Section 9 proposed grouping rows by (destination, family) and
flagging any group whose dispositions are not unanimous, and recommended
running it as a REPORT rather than a CI gate until it had been right or wrong
often enough to judge.

WHAT SECTION 9 GOT WRONG, measured here. Section 9 claimed the rule "would
have caught rfc" because the ggRandomForests/machine-learning group carried
"three dispositions among them". Run this script against the catalog as it
stood at commit 11cf860 (`git show 11cf860:inst/extdata/jobs.json`) and that
group holds TWO dispositions (retire, build), not three, and THREE statuses
(intake, out-of-scope, queued). The rule would have caught rfc on the STATUS
axis, not the disposition axis the design doc credited.

That correction matters for more than the historical record, because pull
request #43 has since closed the status axis with an explicit rule: status
and batch are null for a row destined elsewhere, except intake. A status
disagreement within a group is now DERIVABLE from that rule rather than a
free choice, so a status mismatch here carries no signal any more. The
disposition axis this script actually checks is the one still worth a human
look, and it is checked below on its own, deliberately not folded together
with status into one combined "disagreement" count the way the original
proposal implied.

WHAT THIS SCRIPT IS FOR. Run it by hand, not in CI, when the catalog grows or
when a routing decision is on the table. dev/specs/2026-09-05-coverage-
consistency-report.md records what running it today actually found: one
finding worth a follow-up (dp-variable, family plots but folder distributions)
and one false positive that a gate would have wrongly failed on (sid and vt
in ggRandomForests/machine-learning are genuinely un-built, which is what
`build` means; the other five rows in that group are correctly `retire`).
A gate that is wrong on half its live flags is worse than the report this
is; see the report for the reasoning and the recommendation not to promote
this to a gate.

USAGE.
    python3 dev/specs/artifacts/coverage-consistency.py [path/to/jobs.json]

With no argument it reads inst/extdata/jobs.json relative to the repository
root (derived from this file's own location, so the script runs correctly
from any clone). Pass a path explicitly to point it at an export of an older
revision, e.g.:
    git show 11cf860:inst/extdata/jobs.json > /tmp/jobs-11cf860.json
    python3 dev/specs/artifacts/coverage-consistency.py /tmp/jobs-11cf860.json
"""
import sys
import os
import json
import collections

# The repository root, derived from this script's own location rather than
# hardcoded, so the default path is correct no matter where the clone lives.
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir, os.pardir, os.pardir))
DEFAULT_CATALOG = os.path.join(REPO, "inst", "extdata", "jobs.json")


def load_jobs(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)["jobs"]


def group_by_surface(jobs):
    """Group rows by (destination, family). This is the "shares a surface"
    definition section 9 recommended prototyping: cruder than a `replaced_by`
    overlap check, but usable immediately because destination and family are
    populated on every row, where replaced_by is often empty.
    """
    groups = collections.defaultdict(list)
    for job in jobs:
        key = (job.get("destination"), job.get("family"))
        groups[key].append(job)
    return groups


def main():
    catalog_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CATALOG
    jobs = load_jobs(catalog_path)
    groups = group_by_surface(jobs)

    print(f"catalog: {catalog_path}")
    print(f"rows: {len(jobs)}")
    print(f"groups (destination, family): {len(groups)}")
    print()

    flagged = 0
    for key in sorted(groups, key=lambda k: (str(k[0]), str(k[1]))):
        rows = groups[key]
        prefixes = [r["prefix"] for r in rows]
        dispositions = collections.Counter(r.get("disposition") for r in rows)
        statuses = collections.Counter(r.get("status") for r in rows)

        # The flag is on DISPOSITION only. Status is deliberately not part of
        # the flag condition: PR #43 made status within a group derivable
        # (null unless destined here, except intake), so a status split is
        # now expected rather than anomalous. Printing it anyway is useful
        # context for a human reading the report, just not a trigger.
        is_flagged = len(dispositions) > 1
        if is_flagged:
            flagged += 1

        marker = "FLAG" if is_flagged else "    "
        print(f"[{marker}] destination={key[0]!r} family={key[1]!r} rows={len(rows)}")
        print(f"       prefixes: {prefixes}")
        print(f"       dispositions: {dict(dispositions)}")
        print(f"       statuses: {dict(statuses)}")
        print()

    print(f"{flagged} of {len(groups)} groups carry more than one disposition")


if __name__ == "__main__":
    main()
