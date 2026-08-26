"""Convert inst/extdata/catalog.csv into the published members.json.

members.json is the single artifact every downstream CV sink reads: the CV
Quarto source, the GitHub profile README, and the personal site. Counts are
derived here so that the family-count sentence is arithmetic rather than
prose maintained in three places.

Standard library only -- this runs on a CI runner with no pip install step,
and adds no R dependency to the package.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

COLUMNS = ("package", "repo", "family", "blurb", "cran", "status", "role", "homepage")
FAMILIES = ("member", "standalone", "book")
STATUSES = ("stable", "wip")


def read_catalog(handle) -> list[dict]:
    """Read catalog rows from an open file handle, preserving file order."""
    return list(csv.DictReader(handle))


def read_version(description: Path) -> str:
    """Pull Version: from a DESCRIPTION file."""
    match = re.search(r"^Version:\s*(\S+)", description.read_text(), re.M)
    if not match:
        raise ValueError(f"no Version: field in {description}")
    return match.group(1)


def _validate(rows: list[dict]) -> None:
    if not rows:
        raise ValueError("catalog is empty")

    missing = [c for c in COLUMNS if c not in rows[0]]
    if missing:
        raise ValueError(f"catalog is missing required column(s): {', '.join(missing)}")

    seen = set()
    for row in rows:
        name = row["package"]
        if not name:
            raise ValueError("catalog has a row with no package name")
        if name in seen:
            raise ValueError(f"duplicate catalog entry: {name}")
        seen.add(name)

        if row["family"] not in FAMILIES:
            raise ValueError(f"{name}: unknown family {row['family']!r}")
        if row["status"] not in STATUSES:
            raise ValueError(f"{name}: unknown status {row['status']!r}")
        if not row["blurb"].strip():
            raise ValueError(f"{name}: blurb is empty")
        if not row["repo"] and not row["homepage"]:
            raise ValueError(f"{name}: needs a repo or a homepage to link to")


def _url(row: dict) -> str:
    return row["homepage"] or f"https://github.com/{row['repo']}"


def build_manifest(rows: list[dict], version: str) -> dict:
    """Build the members.json payload from catalog rows.

    Raises ValueError on any schema violation, so a malformed catalog fails
    the publishing job rather than shipping a short package list downstream.
    """
    _validate(rows)

    packages = [
        {
            "package": row["package"],
            "repo": row["repo"] or None,
            "url": _url(row),
            "family": row["family"],
            "blurb": row["blurb"],
            "cran": row["cran"] or None,
            "status": row["status"],
            "role": row["role"] or None,
        }
        for row in rows
    ]

    members = [p for p in packages if p["family"] == "member"]
    on_cran = [p["package"] for p in members if p["cran"]]

    return {
        "generated_from": f"hvtiR {version}",
        "counts": {
            "members": len(members),
            "members_on_cran": len(on_cran),
            "members_github_only": len(members) - len(on_cran),
        },
        "cran_member_names": on_cran,
        "packages": packages,
    }


def main(argv=None) -> int:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=root / "inst" / "extdata" / "catalog.csv")
    parser.add_argument("--description", type=Path, default=root / "DESCRIPTION")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    with args.catalog.open(newline="") as fh:
        manifest = build_manifest(read_catalog(fh), read_version(args.description))

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2) + "\n")
    print(
        f"wrote {args.out}: {manifest['counts']['members']} members "
        f"({manifest['counts']['members_on_cran']} on CRAN), "
        f"{len(manifest['packages'])} entries total"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
