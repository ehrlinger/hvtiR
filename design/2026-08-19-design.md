# hvtiverse — design

**Date:** 2026-08-19
**Status:** approved, ready for implementation planning

## Problem

The HVTI R package family is 11 packages across 11 public GitHub repositories.
Getting a working environment today means running `pak::pak()` or
`remotes::install_github()` eleven times, in an order the user has to know,
against repository names that do not always match the package names. There is
no single command that answers "am I current?" and no single command that makes
you current.

`hvtiverse` is a small installer-and-diagnostic package that provides both.

## Scope

In scope: install, update, status, doctor.

Out of scope, deliberately:

- **No attach layer.** There is no `library(hvtiverse)` that attaches members,
  prints a version banner, or reports masked functions. Conflict reporting
  means tracking every exported symbol across 11 packages and rechecking on
  every release; the cost is real and the benefit here is not.
- **No tiers.** All 11 members are one flat set.
- **No pinned manifest or lockfile.** "Latest" means GitHub `main`.
- **No library-path or toolchain diagnostics.**
- **Not members:** `hvtiEDAreports` (Python, archived 2026-08-27), `hvtiGraphics`
  / HVTI Recipes (Quarto book), `house-style` (a CI standard, not a package).

## Package shape

New public repository `ehrlinger/hvtiverse`; package `hvtiverse`; version `1.0.0`.

```
DESCRIPTION
  Depends: R (>= 4.1.0)
  Imports: cli, utils
  Suggests: pak, testthat (>= 3.0.0), withr, knitr, quarto
R/members.R    registry
R/remote.R     DESCRIPTION fetch and parse
R/status.R     status and doctor
R/install.R    install/update and the loaded-namespace guard
```

`Depends: R (>= 4.1.0)` is load-bearing and deliberately looser than the family's
strictest member (R >= 4.4.0, required by `ggRandomForests` and
`hvtiRlifetables`). If `hvtiverse` itself demanded 4.4.0, a user on R 4.2 could
not install the tool whose job is to tell them their R is too old. The
diagnostic has to run on the broken machine.

`cli` and `utils` are the only hard dependencies. `pak` is in `Suggests` and is
touched only when something is actually installed.

## Registry

`R/members.R` holds a hardcoded two-column data frame, exported via
`hvtiverse_members()`.

| package | repo |
|---|---|
| hvtiRutilities | ehrlinger/hvtiRutilities |
| hvtiRdatasets | ehrlinger/hvtiRdatasets |
| hvtiRtables | ehrlinger/hvtiRtables |
| hvtiRtemplates | ehrlinger/hvtiRtemplates |
| hvtiPlotR | ehrlinger/hvtiPlotR |
| hvtiRlifetables | ehrlinger/hvtiRlifetables |
| hvtiRbootstrap | ehrlinger/hvtiRbootstrap |
| hvtiRpropensity | ehrlinger/hvtiPropensityScores |
| hvtiBoostmtree | ehrlinger/hvtiBoostmtree |
| TemporalHazard | ehrlinger/temporal_hazard |
| ggRandomForests | ehrlinger/ggRandomForests |

Two rows have a package name that differs from the repository name
(`hvtiRpropensity`, `TemporalHazard`), so the mapping cannot be derived and must
be stored. All 11 repositories default to branch `main`.

Two columns only: no `on_cran` flag, no tier, no pinned ref.

## Install source: GitHub, not CRAN

All 11 members install from GitHub `main`, including `ggRandomForests`, which is
also on CRAN. Two reasons:

1. **Consistency.** "Latest" must mean the same thing in `hvtiverse_status()` as
   it does in `hvtiverse_update()`. Comparing against GitHub and installing from
   CRAN would report packages as current that the installer would then change.
2. **It unblocks work.** As of 2026-08-19, `TemporalHazard` 1.2.0 and
   `ggRandomForests` 3.5.1 are finished but held behind CRAN's reopening, and
   `hvtiRlifetables` requires `TemporalHazard (>= 1.2.0)`. Installing from
   GitHub delivers those releases to the team now rather than on CRAN's
   schedule.

**Documented caveat:** because `ggRandomForests` is installed from GitHub, a
later `update.packages()` can silently downgrade it to the CRAN version.

## Public API

```r
hvtiverse_members()                # the registry
hvtiverse_status(remote = TRUE)    # per-member version table
hvtiverse_doctor()                 # R/platform checks, then status()
hvtiverse_install(force = FALSE)   # all 11 members; fresh machine
hvtiverse_update(force = FALSE)    # only missing and stale members
```

`hvtiverse_status()` returns its data frame **visibly**, carrying the class
`c("hvtiverse_status", "data.frame")`, with a `print.hvtiverse_status` method
supplying the readable table. Columns: `package`, `repo`, `installed`,
`latest`, `status`.

The return must be visible, not invisible: R auto-prints only visible top-level
results, so an invisible return would mean the print method never fires and
`hvtiverse_status()` at the console displays nothing. A visible classed return
gives both behaviours — a bare call prints the table, and
`st <- hvtiverse_status()` captures the data frame silently.

Status values:

| value | meaning |
|---|---|
| `ok` | installed version equals latest |
| `stale` | installed version is behind latest |
| `missing` | not installed |
| `ahead` | installed version is newer than `main` (local dev build) |
| `unknown` | remote fetch failed (offline, proxy, repo renamed) |
| `ok-local` | installed, remote not consulted (`remote = FALSE` only) |

`hvtiverse_doctor()` is the "why is this broken" entry point: it reports the
running R version against the family's strictest `Depends:` (currently 4.4.0)
plus OS and architecture, then prints the status table. `hvtiverse_status()` is
the narrower "what is stale" entry point.

`hvtiverse_install()` and `hvtiverse_update()` differ only in which members they
target; both delegate to one internal `install_members()`. `hvtiverse_install()`
targets all 11 members unconditionally, reinstalling ones that are already
current — it is the fresh-machine command. `hvtiverse_update()` targets only
members whose status is `missing` or `stale`; if none are, it reports that and
does nothing.

`force` has one meaning in both functions: **bypass the loaded-namespace guard**.
It does not mean "reinstall regardless of version" — that is what
`hvtiverse_install()` already does by virtue of targeting everything.

`remote = FALSE` in `hvtiverse_status()` skips the network entirely: `latest` is
`NA` for every member and `status` is `missing` or `ok-local` based only on what
is installed. It exists so `hvtiverse_doctor()` stays useful on a machine with
no outbound network, and so tests never reach the network by accident.

## Behaviour

### Remote version fetch

`read.dcf(url("https://raw.githubusercontent.com/<repo>/main/DESCRIPTION"))`,
reading the `Version` field, wrapped in `tryCatch`.

`read.dcf` is used rather than a `grep` on `^Version:` because it handles DCF
continuation lines correctly. Eleven serial HTTPS requests, roughly 1-2 seconds.
`raw.githubusercontent.com` is CDN-served: no authentication, and no meaningful
rate limit. (The GitHub REST API was rejected for this: 60 unauthenticated
requests per hour means rate-limiting after five `hvtiverse_status()` calls.)

### Offline behaviour

A fetch failure must never raise an error. Each failure yields `latest = NA` and
`status = "unknown"`, and the run emits **one** summary warning rather than
eleven. `hvtiverse_doctor()` with no network still reports R version, platform,
and installed versions.

### Loaded-namespace guard

Before installing, compute `intersect(targets, loadedNamespaces())`. If that is
non-empty and `force = FALSE`, abort with a `cli` message naming the loaded
members and instructing the user to restart R and retry.

This exists because a package whose DLL is already loaded cannot be safely
overwritten — on Windows the write fails outright, and a partial install leaves
a broken library. `tidyverse_update()` sidesteps this by refusing to install at
all; `hvtiverse` installs, but guards.

`hvtiverse` is not a member of itself, so it can never appear in that set and
there is no self-update hazard.

`force = TRUE` bypasses the guard and is documented as unsafe on Windows.

### Installation

`pak::pak(specs, ask = FALSE)` over the `owner/repo` strings.

`pak` rather than `remotes` because two members carry `Remotes:` fields —
`hvtiRdatasets` -> `ehrlinger/hvtiRutilities` and `hvtiPlotR` ->
`davidsjoberg/ggsankey`. `Remotes:` is not transitive under
`install.packages()`, which would silently fail to resolve them.

**All 11 specs go to `pak` in a single call**, not eleven calls in a loop. This
is a correctness requirement, not an optimisation. `hvtiRlifetables` declares
`Imports: TemporalHazard (>= 1.2.0)` but carries **no** `Remotes:` line, so
resolving it alone sends `pak` to CRAN, where TemporalHazard is still 1.1.0 and
the requirement fails — that package is currently uninstallable in isolation.
Passing every spec at once means `ehrlinger/temporal_hazard` is co-resolved at
1.2.0 and satisfies the import.

That co-resolution is a side effect of batching, not something either package
declares, so it is fragile. The proper fix is a `Remotes: ehrlinger/temporal_hazard`
line in `hvtiRlifetables/DESCRIPTION`; it is tracked separately and is not a
prerequisite for this implementation.

If `pak` is not installed, fail with a message giving the exact command to
install it.

### renv interaction

`study_init()` pins package versions with `renv`. `hvtiverse_update()` installs
into the active library, which inside an renv project is the project library.
This is documented behaviour, not a feature: users in an renv project should
expect to `renv::snapshot()` afterwards. No renv-specific code paths.

## Testing

The organising principle is that all logic is pure and all I/O sits at the
edges, so the test suite needs no network.

| unit | kind | tests |
|---|---|---|
| `classify_status(installed, latest)` | pure | table-driven: equal, less, greater, `NA` latest, `NA` installed |
| `check_loaded(targets, loaded)` | pure | takes `loaded` as an argument rather than calling `loadedNamespaces()` internally, so the guard is testable without loading anything |
| `build_specs(members, which)` | pure | asserts the exact repo strings handed to `pak` |
| `remote_version(repo)` | I/O | mocked with `local_mocked_bindings()` against fixture DESCRIPTION files, including one with continuation lines and one failure case returning `NA` |
| registry integrity | network, CI only | `skip_if_offline()`; every registry `repo` resolves and its `Package:` field matches the registry `package` — this is what catches a repo rename or a third name mismatch |

## Conventions

- Version `1.0.0`; three-digit semantic versions only, no dev suffix.
- `NEWS.md` `Version:` kept in step with `DESCRIPTION`.
- pkgdown site, GitHub Actions `R CMD check`.
- README leads with the one-line bootstrap: `pak::pak("ehrlinger/hvtiverse")`.
- The R package stack figure gains an `hvtiverse` node — tracked separately,
  not part of this implementation.
