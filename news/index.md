# Changelog

## hvtiR 1.0.4

- Added `inst/extdata/catalog.csv`, presentation metadata for every
  published artifact: the family members from
  [`members()`](https://ehrlinger.github.io/hvtiR/reference/members.md),
  plus the SAS/C `hazard` code and the HVTI Recipes book, which are not
  R packages. `status`, `cran` and `role` are stored as fields rather
  than folded into the blurb, so each consumer can render them in its
  own house style.

- Added `tests/testthat/test-catalog.R`, which ties the catalog’s member
  rows to
  [`members()`](https://ehrlinger.github.io/hvtiR/reference/members.md)
  exactly. A package added to the registry without a catalog entry now
  fails `R CMD check` rather than silently shortening the package lists
  published downstream.

- Added `tools/catalog_to_json.py`, which the pkgdown workflow runs to
  publish `members.json` alongside the site. Member counts are derived
  there, so the family-count sentence used by downstream documents is
  arithmetic rather than prose maintained by hand.

## hvtiR 1.0.3

- [`status()`](https://ehrlinger.github.io/hvtiR/reference/status.md)
  now detects an older GitHub installation when its version matches
  `main` but pak’s recorded `RemoteSha` does not. The member reports as
  `"stale"`, so
  [`update()`](https://ehrlinger.github.io/hvtiR/reference/update.md)
  reinstalls it. Installs without GitHub commit provenance continue to
  use version comparison alone.
- Commit checks use GitHub’s public Atom feeds rather than its
  rate-limited API. A failed commit check reports `"unknown"` and its
  reason is retained for
  [`doctor()`](https://ehrlinger.github.io/hvtiR/reference/doctor.md).

## hvtiR 1.0.2

- Remote version checks now use a five-second connection timeout and
  retain per-repository failure reasons for
  [`doctor()`](https://ehrlinger.github.io/hvtiR/reference/doctor.md) to
  report.
- [`doctor()`](https://ehrlinger.github.io/hvtiR/reference/doctor.md)
  now reports whether `pak` is available before showing member status.
- Documentation now explains GitHub as the family’s leading release
  source without hard-coded CRAN or GitHub versions, and the offline
  vignette example uses the qualified
  [`hvtiR::status()`](https://ehrlinger.github.io/hvtiR/reference/status.md)
  call.
- The pkgdown site is validated on pull requests with read-only
  permissions, and deployments remove pages retired by the `hvtiverse`
  to `hvtiR` rename.
- Source-package tarballs and linked-worktree Git metadata are excluded
  from package builds.

## hvtiR 1.0.1

- **The package is renamed from `hvtiverse` to `hvtiR`**, matching the
  `hvtiR*` prefix the rest of the family uses. Install from
  `ehrlinger/hvtiR`.

- **Every exported function is renamed**, dropping the package-name
  prefix that no other family package carries. The package is meant to
  be called with `::` rather than attached:

  | was | now |
  |----|----|
  | [`hvtiverse::hvtiverse_install()`](https://rdrr.io/pkg/hvtiverse/man/hvtiverse_install.html) | [`hvtiR::install()`](https://ehrlinger.github.io/hvtiR/reference/install.md) |
  | [`hvtiverse::hvtiverse_update()`](https://rdrr.io/pkg/hvtiverse/man/hvtiverse_update.html) | [`hvtiR::update()`](https://ehrlinger.github.io/hvtiR/reference/update.md) |
  | [`hvtiverse::hvtiverse_status()`](https://rdrr.io/pkg/hvtiverse/man/hvtiverse_status.html) | [`hvtiR::status()`](https://ehrlinger.github.io/hvtiR/reference/status.md) |
  | [`hvtiverse::hvtiverse_doctor()`](https://rdrr.io/pkg/hvtiverse/man/hvtiverse_doctor.html) | [`hvtiR::doctor()`](https://ehrlinger.github.io/hvtiR/reference/doctor.md) |
  | [`hvtiverse::hvtiverse_members()`](https://rdrr.io/pkg/hvtiverse/man/hvtiverse_members.html) | [`hvtiR::members()`](https://ehrlinger.github.io/hvtiR/reference/members.md) |

- The class returned by
  [`status()`](https://ehrlinger.github.io/hvtiR/reference/status.md) is
  renamed `hvtiR_status`. Unlike the functions it stays
  package-qualified, because S3 classes are matched by string and a bare
  `status` class would collide.

- No deprecated aliases are provided. `hvtiverse` 1.0.0 was never
  depended on outside this family, so there is nothing to migrate.
