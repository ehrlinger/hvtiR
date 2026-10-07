# Design records

How `hvtiR` was specified and built.

| File | What it is |
|---|---|
| [2026-08-19-hvtiverse-design.md](2026-08-19-hvtiverse-design.md) | The design spec: what the package does, and why each choice was made over its alternatives. |
| [2026-08-19-hvtiverse-plan.md](2026-08-19-hvtiverse-plan.md) | The implementation plan: ten test-driven tasks, each with the code and tests to write. |
| [2026-09-01-snapshot-restore-design.md](2026-09-01-snapshot-restore-design.md) | **Rejected.** The design spec for `snapshot()` and `restore()`: pinning the family by commit SHA, why not by release, and why `renv` made the whole thing unnecessary. |
| [2026-09-02-issue-templates-design.md](2026-09-02-issue-templates-design.md) | The design spec for the GitHub issue templates: why YAML forms over markdown, why installation and bug reports are separate intakes, and why the member-change form asks for package name and repository as two fields. |
| [2026-10-07-team-review-overview.md](2026-10-07-team-review-overview.md) | Six designs from the 2026-10-07 team training, implemented in `hvtiRutilities`, `hvtiRtemplates` and `hvtiRdatabuild`: interactive runs that say "render the job", registering to a dated parquet with `update_manifest()`, `"built"` as a dataset name, template-first job names, figures saved as PDF and PNG, and ancillary, subset and combined datasets. Start here; it links the six. |

The 2026-08-19 pair records the v1.0.0 build. Later records cover changes made
on top of it, and a design that reverses an earlier decision says so in its
header. They are kept because the reasoning behind the design is harder to
recover than the code. They are not user documentation -- start with the README
or `vignette("hvtiR")` for that.

They live under `dev/specs/` because that is where the portfolio house style puts
development records, and `-design` / `-plan` carries the distinction rather than a
subdirectory. They are emphatically not under `docs/`, which belongs to pkgdown:
pkgdown refuses to build into a directory it did not create, so anything of ours
in `docs/` breaks the site build.
