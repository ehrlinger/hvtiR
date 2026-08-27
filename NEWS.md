Package: hvtiR
Version: 1.0.7

## hvtiR 1.0.7

* A pull request whose `Version:` has not moved past `main` now fails CI.
  Two branches bumping to the same version do not conflict in git -- the
  identical line merges silently and only `NEWS.md` shows a conflict -- so
  the collision was invisible until someone read the release notes. The
  guard also checks that `NEWS.md`'s `Version:` line and its per-release
  heading agree with `DESCRIPTION`, and that `Date` neither goes backwards
  nor sits in the future. `Date` is not required to advance: same-day
  releases are normal here, so demanding a new day would block them.

## hvtiR 1.0.6

* `member_deps()` records that `hvtiRtemplates` imports `hvtiRutilities`.
  The dependency was added upstream on 2026-08-27; without the entry an
  update that names only `hvtiRtemplates` leaves `pak` to resolve
  `hvtiRutilities` from CRAN, where it does not exist.

## hvtiR 1.0.5

* The live registry test no longer reports a throttled CI runner as a defect.
  `fetch_description()` gained an `attempts` argument that retries a failed
  request with a widening wait, and the live test asks for three attempts.
  A renamed repository fails exactly as before, only later: retrying separates
  a transient stall from a persistent one by how long it lasts, which is the
  only signal available when both surface as the same failed connection.
* `fetch_description()` rejects a non-positive or malformed `attempts` count
  instead of failing later with an unbound-object error.
* `status()` and `doctor()` are unchanged. They keep the single-attempt
  default, so a member that cannot be reached still resolves inside the
  five-second budget rather than three times over.

## hvtiR 1.0.4

* Added `inst/extdata/catalog.csv`, presentation metadata for every published
  artifact: the family members from `members()`, plus the SAS/C `hazard` code
  and the HVTI Recipes book, which are not R packages. `status`, `cran` and
  `role` are stored as fields rather than folded into the blurb, so each
  consumer can render them in its own house style.

* Added `tests/testthat/test-catalog.R`, which ties the catalog's member rows
  to `members()` exactly. A package added to the registry without a catalog
  entry now fails `R CMD check` rather than silently shortening the package
  lists published downstream.

* Added `tools/catalog_to_json.py`, which the pkgdown workflow runs to publish
  `members.json` alongside the site. Member counts are derived there, so the
  family-count sentence used by downstream documents is arithmetic rather than
  prose maintained by hand.

## hvtiR 1.0.3

* `status()` now detects an older GitHub installation when its version matches
  `main` but pak's recorded `RemoteSha` does not. The member reports as
  `"stale"`, so `update()` reinstalls it. Installs without GitHub commit
  provenance continue to use version comparison alone.
* Commit checks use GitHub's public Atom feeds rather than its rate-limited
  API. A failed commit check reports `"unknown"` and its reason is retained
  for `doctor()`.

## hvtiR 1.0.2

* Remote version checks now use a five-second connection timeout and retain
  per-repository failure reasons for `doctor()` to report.
* `doctor()` now reports whether `pak` is available before showing member
  status.
* Documentation now explains GitHub as the family's leading release source
  without hard-coded CRAN or GitHub versions, and the offline vignette example
  uses the qualified `hvtiR::status()` call.
* The pkgdown site is validated on pull requests with read-only permissions,
  and deployments remove pages retired by the `hvtiverse` to `hvtiR` rename.
* Source-package tarballs and linked-worktree Git metadata are excluded from
  package builds.

## hvtiR 1.0.1

* **The package is renamed from `hvtiverse` to `hvtiR`**, matching the `hvtiR*`
  prefix the rest of the family uses. Install from `ehrlinger/hvtiR`.
* **Every exported function is renamed**, dropping the package-name prefix that
  no other family package carries. The package is meant to be called with `::`
  rather than attached:

  | was | now |
  |---|---|
  | `hvtiverse::hvtiverse_install()` | `hvtiR::install()` |
  | `hvtiverse::hvtiverse_update()`  | `hvtiR::update()`  |
  | `hvtiverse::hvtiverse_status()`  | `hvtiR::status()`  |
  | `hvtiverse::hvtiverse_doctor()`  | `hvtiR::doctor()`  |
  | `hvtiverse::hvtiverse_members()` | `hvtiR::members()` |

* The class returned by `status()` is renamed `hvtiR_status`. Unlike the
  functions it stays package-qualified, because S3 classes are matched by
  string and a bare `status` class would collide.
* No deprecated aliases are provided. `hvtiverse` 1.0.0 was never depended on
  outside this family, so there is nothing to migrate.


## hvtiverse 1.0.0

* First release.
* `hvtiverse_install()` installs all 11 members of the HVTI R package family
  from GitHub in a single `pak` call.
* `hvtiverse_update()` installs only the members that are missing or out of
  date, and refuses to overwrite a member whose namespace is already loaded.
* `hvtiverse_status()` reports installed against latest versions for every
  member.
* `hvtiverse_doctor()` adds R version and platform checks for diagnosing an
  installation that will not work.
* `hvtiverse_members()` exposes the registry.
