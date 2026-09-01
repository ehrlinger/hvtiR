# snapshot / restore — design

**Date:** 2026-09-01
**Status:** rejected 2026-09-01, in favour of `renv`. Not implemented.
**Effect on prior records:** none. The "No pinned manifest or lockfile"
exclusion in [2026-08-19-hvtiverse-design.md](2026-08-19-hvtiverse-design.md)
stands.

## Decision: rejected in favour of renv

This design was taken to approval and then rejected before any implementation.
Everything below the next heading is the design as it stood at approval, kept
because the evidence gathered for it answers questions that will be asked
again. It does not describe anything the package does.

`renv` records a GitHub package's commit in `renv.lock` and reinstalls from it,
so it already provides what this design was for. Three findings, gathered while
specifying it, make the case decisive:

1. **`renv` reads the same `RemoteSha` field this design would.** So it has the
   identical ceiling: a member installed from a local working copy is
   unpinnable either way. The measurement below, which looked like an edge case
   in this design, is really proof that the design adds no capability.
2. **`renv` handles the co-resolution problem better.** The one-call `pak` rule
   exists because `hvtiR` does not hold the full dependency graph and must let
   pak co-resolve `hvtiRlifetables`'s `TemporalHazard (>= 1.2.0)` import.
   `renv` has the whole graph in the lockfile and installs `TemporalHazard`
   from GitHub at its recorded commit, so the constraint never arises.
3. **`renv` covers strictly more** -- the CRAN dependency tree, the R version
   and library isolation -- for none of the two new exports, manifest format,
   preflight classifier and nine test cases this design costs.

The one thing `renv` does not provide is discoverability: someone running
`hvtiR::install()` gets no prompt that reproducibility needs `renv`. That was
addressed instead in 1.0.14 by a `README` section and one line in `doctor()`
reporting whether an `renv` project is active -- roughly a twentieth of the
cost, for the only benefit that was actually missing.

The alternatives analysis below stands on its own and is unaffected by this
rejection: release and tag pinning remain rejected for their own reasons, which
are about the family's release practice rather than about `renv`.

## Problem

`install()` resolves every member from GitHub `main`. That is the right default
and is not changing: it is what keeps the CRAN queue from being able to block
the family. But it means an install is not reproducible. Two people running
`hvtiR::install()` a week apart get different commits under the same
`DESCRIPTION` version whenever the patch digit did not move, and neither can
name what they got.

`status(remote = TRUE)` already resolves a commit SHA per member, so the
information needed to close this gap is present. What is missing is a way to
write it down and a way to install from it.

## Scope

In scope: two new exports, `snapshot()` and `restore()`, and one new file
`R/snapshot.R`.

Out of scope, deliberately:

- **The CRAN dependency tree.** The manifest pins the eleven family members and
  nothing else. `cli`, `survival`, `ggplot2` and the rest keep floating.
- **Any change to `install()`, `update()`, `status()` or `doctor()`.** Their
  contracts are unchanged and `R/install.R`, `R/status.R` and `R/remote.R` gain
  no new behaviour. `R/remote.R` gains a caller for an argument it already has.
- **A vignette.** A README section covers it.
- **Release or tag pinning.** See "Alternatives rejected".

### Why this reverses the 2026-08-19 exclusion

The v1.0.0 design ruled out a lockfile with one line: `"Latest" means GitHub
main`. That is still true of `install()` and `update()`, which is what the
exclusion was protecting. What it did not anticipate is that "latest" and
"reproducible" are different requirements that can coexist rather than compete.
`snapshot()`/`restore()` is a third verb pair alongside them, not a change to
what "latest" means.

## Relationship to renv

`renv` already pins GitHub packages by commit (`Source: GitHub` with
`RemoteSha`) *and* the CRAN tree, so it is a strict superset of what this
provides. This design does not compete with it. The division is:

| layer | owner |
|---|---|
| the eleven GitHub family members | `hvtiR::snapshot()` / `restore()` |
| the CRAN dependency tree, R version, library paths | `renv`, if the user wants it |

A user who wants full reproducibility should use `renv` and does not need this.
A user who wants the family pinned coherently without adopting `renv` gets it
here. The two compose: inside an renv project, `restore()` installs into the
project library like `install()` already does, and the user snapshots
afterwards. No renv-specific code paths, consistent with the v1.0.0 design's
renv section.

## Manifest

**File:** `hvti-lock.dcf`, defaulting to the working directory. It is a project
artifact belonging to the analysis repository that consumes the family, not to
this package and not to the R library.

**Format: DCF.** In order of weight: `read.dcf()` and `write.dcf()` are base R,
so `Imports` stays `cli, utils`; `fetch_description()` already returns DCF
matrices, so the codebase already speaks it; `NEWS.md` already uses a DCF
header; and it diffs line by line in git. `catalog.R` sets a CSV precedent, but
CSV handles optional and empty fields badly and the unpinned annotation needs
exactly that.

```
Manifest: hvtiR
Schema: 1
Created: 2026-09-01
Generator: hvtiR 1.0.14
R: 4.5.1

Package: hvtiRutilities
Repo: ehrlinger/hvtiRutilities
Version: 1.1.8
Sha: edd53c1a4f...

Package: hvtiPlotR
Repo: ehrlinger/hvtiPlotR
Version: 2.7.13
Sha:
Unpinned: no commit recorded in installed DESCRIPTION
```

The leading record is the header, identified by its `Manifest:` field and
skipped when reading rows. `Schema:` exists so that a future format change can
abort cleanly rather than misparse. `R:` and `Generator:` are advisory: recorded
for diagnostics, never enforced on restore.

## Public API

| function | signature | returns |
|---|---|---|
| `snapshot()` | `snapshot(path = "hvti-lock.dcf")` | the manifest data frame, invisibly |
| `restore()` | `restore(path = "hvti-lock.dcf", force = FALSE)` | the specs passed to pak, invisibly |

Both are new exports, taking the package from five to seven. Each verb does one
job, matching the shape of `install`, `update`, `status` and `doctor`. The
alternative of folding restore into `install(lockfile =)` was rejected: it would
give `install()` a second mode contradicting its documented contract of
unconditionally matching `main`.

## Reuse

`R/snapshot.R` adds no parallel machinery. It reuses four existing internals:

| reused | from | for |
|---|---|---|
| `installed_version()` | `R/status.R` | already returns the version carrying `RemoteSha` as a `remote_sha` attribute |
| `fetch_description(repo, ref =)` | `R/remote.R` | preflight, through the `ref` argument nothing currently passes |
| `check_loaded()` | `R/install.R` | the loaded-namespace guard |
| `pak_install()` | `R/install.R` | the single install seam, preserving the one-call invariant |

`R/remote.R` remains the single network seam. Preflight adds a caller, not a
second seam.

## Behaviour

### snapshot

1. `members()`, then `installed_version()` for each.
2. Drop rows where the member is not installed.
3. `build_manifest()` builds the data frame. Pure: it takes values and returns
   the frame, following `classify_status()`'s precedent.
4. Warn, naming any member that is installed but carries no `RemoteSha`.
5. `write_manifest()` writes DCF.

A member that is not installed is omitted rather than treated as an error. A
partial family install is a legitimate thing to snapshot, and `restore()`
reproduces the same partial set.

### Unpinnable members are the common case on a developer machine

A local `R CMD INSTALL` or `devtools::install()` writes no `Remote*` fields, so
a member built from a working copy cannot be pinned. Measured on the
maintainer's machine, 2026-09-01:

| member | version | `RemoteSha` |
|---|---|---|
| hvtiRutilities | 1.1.8 | `edd53c1` |
| TemporalHazard | 1.2.7 | `3f4a506` |
| hvtiPlotR | 2.7.13 | none |
| ggRandomForests | 4.0.0 | none |
| hvtiRtables | 1.0.0 | none |
| hvtiRlifetables | 0.1.3 | none |

Four of six, and `hvtiPlotR` at 2.7.13 against a `main` of 2.7.12 is an unpushed
dev build whose commit may exist nowhere but that disk.

This is why an unpinnable member warns rather than aborting: aborting would mean
`snapshot()` never succeeds on a maintainer machine at all. It also bounds the
feature's audience honestly. `snapshot()` is for a machine whose library came
from `hvtiR::install()`, where pak wrote `RemoteSha` on every row -- which is
the analyst running the analysis, and the reason reproducibility was wanted.

### restore

1. `read_manifest()`, validating `Schema:`.
2. Preflight every pinned row: `fetch_description(repo, ref = sha)`.
3. Any dead pin aborts. Nothing is installed.
4. `check_loaded()` guard, bypassable with `force`.
5. Build specs: pinned rows become `owner/repo@sha`, unpinned rows become
   `owner/repo` and resolve from `main`.
6. One `pak_install(specs)` call.
7. Report what was pinned and what was resolved from `main`.

The one-call invariant is preserved and is why partial restore is not offered:
if one spec will not resolve, pak fails the whole call regardless, so the only
real choice is whether to check first and give a better error.

`restore()` takes each repository from the manifest's own `Repo:` field, not
from `members()`. The manifest is self-describing, so it still restores after a
member is dropped from the registry, and a repository renamed since the
snapshot surfaces through preflight as unreachable rather than as a silent
mismatch. A manifest whose rows are all unpinned is not an error: it restores
the recorded set from `main`, which is `install()` narrowed to those members.

A snapshot is internally consistent by construction. It was read off a library
that worked, so a constraint like `hvtiRlifetables` importing
`TemporalHazard (>= 1.2.0)` is satisfied by whatever versions were recorded.

Preflight fetches the `DESCRIPTION` at the pinned SHA, which also yields the
`Version` at that commit. Checking it against the recorded `Version:` is a free
integrity check on a hand-edited or corrupted manifest, at warning level.

### Offline is indistinguishable from a dead pin

`fetch_description()` returns `NULL` on any failure -- 404, DNS, timeout, proxy,
rate limit. A failed preflight therefore cannot by itself tell "this commit no
longer exists" from "this machine is offline". Reporting a rewritten history to
someone on a plane is a wrong diagnosis, not merely a vague one.

The failing repository's `main` is re-probed to classify:

| `repo@sha` | `repo@main` | conclusion |
|---|---|---|
| fails | succeeds | the pin is dead; history was rewritten |
| fails | fails | the repository is unreachable: offline, renamed or deleted |

Two distinct abort messages. The second probe runs only on the failure path, so
the happy path costs nothing.

### Preflight retries

Preflight passes `attempts = 3`. `fetch_description()`'s own documentation says
the default of one exists to keep `status()` and `doctor()` inside the latency
`remote_timeout` promises, and that callers who would rather wait than read a
throttled host as a missing repository should ask for more. `restore()` is
exactly that caller: deliberate, infrequent, and a false dead-pin verdict is
expensive. Burst-fetching eleven SHAs from `raw.githubusercontent.com` is also
the same throttling pattern that made `test-registry-live.R` flaky and prompted
the backoff work in 1.0.4.

## Error handling

`snapshot()`:

| condition | behaviour |
|---|---|
| no members installed | abort |
| installed, no `RemoteSha` | warn; write the row with empty `Sha:` and an `Unpinned:` reason |
| not installed | omit silently |
| path not writable | abort, wrapping the base error with the attempted path |
| file exists | overwrite, reporting the path written |

Overwriting is deliberate: a snapshot command overwriting its target is the
normal expectation, and prompting would break non-interactive use.

`restore()` aborts before touching anything on a missing file, a `Schema:`
newer than supported, malformed DCF, or a manifest with zero rows. The
loaded-namespace guard reuses `check_loaded()` and its existing message;
`force` bypasses it. A missing `pak` is already handled inside
`pak_install()`.

## Testing

All logic pure, all I/O at the edges, no test reaching the network and no test
installing anything.

| unit | kind | tests |
|---|---|---|
| `build_manifest()` | pure | synthetic inputs: fully pinned, partially unpinned, empty |
| DCF round trip | filesystem | build, write to `tempfile()`, read, `expect_identical`; base `tempfile()` with `on.exit(unlink())` so `Suggests` is unchanged |
| `snapshot()` | mocked | `local_mocked_bindings(installed_version =)`: pinned library, partially unpinned library expecting a warning and an empty `Sha:`, empty library expecting an abort |
| `restore()` specs | mocked | `local_mocked_bindings(fetch_description =, pak_install =)`; pinned rows produce `owner/repo@sha`, unpinned rows produce `owner/repo` |
| one-call invariant | mocked | `expect_length(calls, 1L)`, mirroring `test-install.R` |
| dead pin | mocked | fetch fails on the sha ref and succeeds on `main`; expect that abort and `expect_length(calls, 0L)` |
| unreachable repo | mocked | fetch fails on both refs; expect the other abort |
| loaded-namespace guard | mocked | guard fires; `force = TRUE` bypasses |
| schema | fixture | an unknown `Schema:` aborts |

The dead-pin classification is fully testable through the mock because it
depends only on which `ref` was requested, which is a direct payoff of routing
everything through one seam.

Fixtures in `tests/testthat/fixtures/`, following `DESCRIPTION-simple` and
`DESCRIPTION-continuation`: `hvti-lock-simple.dcf`, `hvti-lock-unpinned.dcf`,
`hvti-lock-badschema.dcf`.

`test-registry-live.R` is untouched and no new network test is added.

## Alternatives rejected

### Installing by release or tag

Surveyed 2026-09-01:

| member | latest release | `main` version |
|---|---|---|
| hvtiRutilities | v1.1.7 | 1.1.8 |
| hvtiRdatabuild | none (0 tags) | 0.2.0 |
| hvtiRtables | none (0 tags) | 1.0.0 |
| hvtiRtemplates | none (0 tags) | 1.0.17 |
| hvtiPlotR | v2.7.7 | 2.7.12 |
| hvtiRlifetables | none (0 tags) | 0.1.3 |
| hvtiRbootstrap | none (1 tag) | 0.1.1 |
| hvtiRpropensity | none (0 tags) | 0.1.3 |
| hvtiBoostmtree | v2.0.1 | 2.0.1 |
| TemporalHazard | v1.1.0 | 1.2.7 |
| ggRandomForests | v3.5.2 | 4.0.0 |

Three reasons, in order:

1. Six of eleven members have no release, so `@*release` fails outright for
   them. `install()` would break for the majority of the family.
2. `hvtiRlifetables` imports `TemporalHazard (>= 1.2.0)`, whose latest release
   is v1.1.0. The one-call rule fixes where pak looks; it cannot fix a pinned
   version being too old. Release pinning reintroduces the 1.0.0 resolution bug
   through a different door.
3. Releases are stale enough to mislead: ggRandomForests a full major behind,
   TemporalHazard five patches behind.

Underneath all three: releases are not a maintained artifact in this family. Tag
counts run 0, 0, 0, 0, 0, 1, 3, 7, 8, 20, 30. The release surface would have to
be created and then maintained across twelve repositories before anything could
depend on it, which reimposes the release-cadence gate that resolving from
`main` exists to avoid.

Pinning by SHA needs no release discipline at all, and pins exactly what ran
rather than something older.

### Replacing renv

Pinning the full dependency tree would rebuild `renv` inside an 824-line
installer and inherit its hard problems: library paths, platform and binary
differences, R version. Rejected on scope.

### A manifest that overrides the registry

Having `members()` read the manifest when present would make every verb
pin-aware for free. Rejected: a file on disk would silently change what four
existing functions do, including the two the test suite is built around. Too
much blast radius for the gain.

## Conventions

- `DESCRIPTION` 1.0.13 to 1.0.14, `Date` refreshed. Patch digit only;
  consolidating into a minor is the maintainer's decision.
- `NEWS.md` entry, including the DCF `Version:` line at the top.
- `devtools::document()` run; two new `man/` pages committed with the source.
- A README section. The README is the family front door and this section
  assumes no other package.
- Installation behaviour proved through the mocked seam, never by installing.
