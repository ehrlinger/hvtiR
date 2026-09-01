Package: hvtiR
Version: 1.1.1

# hvtiR (unreleased)

* `tools/check_version.py` accepts a pull request that leaves `Version:` alone,
  provided its entry is filed under this heading. It required every pull
  request to bump, which the house-style cadence no longer asks for. A version
  that goes backwards still fails, and an unchanged version with no unreleased
  heading still fails, which is the rebase collision the guard was built for.

* `NEWS.md` version headings move from `##` to `#`, matching every other
  package in the family. This repository was the only one at level two, which
  meant the version guard here and the equivalent test in `hvtiRbootstrap`
  keyed on different heading levels. Both R's news reader and pkgdown parse
  the file to the same 16 and 15 entries as before, so nothing downstream
  changes.

# hvtiR 1.1.1

* Adds `lint.yaml` and `test-coverage.yaml`, the two workflows every other
  member of the family already ran. This repository was the only one without
  them, so nothing here caught a style regression or a coverage drop.

* Clears the 26 lints that adding `lint.yaml` would have failed on. No `.lintr`
  is added: `hvtiRutilities` runs the same job with no configuration file, so
  lintr's defaults -- including the 80-character line -- are demonstrably
  achievable here, and this repository stays at the strictest setting in the
  family. Three lints are genuine false positives and carry a `# nolint` with
  the reason instead: `unknown` in `build_specs()` is used inside a cli glue
  string that lintr cannot parse, and `SELF_REPO` and `MIN_R_VERSION` are
  package constants deliberately spelled in upper case so they do not read as
  locals at their use sites.

* `lint.yaml` also brings a `docs-current` job, which runs `roxygenise()` and
  fails on any diff in `man/`, `NAMESPACE` or `DESCRIPTION`. That gate enforces
  a rule the contributing notes already stated but nothing checked.

# hvtiR 1.1.0

* The vignette described `doctor()` as adding "two environment checks" when it
  reports four -- R version, platform, `pak`, and now `renv`. It had already
  omitted the `pak` check before this release. It now also covers reproducible
  installs and the installer self-report, which the README gained at the same
  time; the two had drifted apart.

* `update()` now reports `hvtiR`'s own version against GitHub. The installer is
  not a member of its own registry, so nothing previously mentioned it and a
  user could stay current on all eleven members while silently running a stale
  installer. It is reported and never installed: `update()` cannot update
  `hvtiR` in place, because calling it means the namespace is already loaded
  and the loaded-namespace guard refuses. When the installer is behind, the
  report names `pak::pak("ehrlinger/hvtiR")` as the remedy.

* `doctor()` reports whether an `renv` project is active. When one is not, it
  says so and adds that member versions are not pinned, because `install()`
  resolves from GitHub `main` and two runs a week apart can land on different
  commits under the same version number. Informational, not a failure: `renv`
  is optional and its absence blocks nothing.

* The README gains a "Reproducible installs" section: `renv::init()`,
  `hvtiR::install()`, `renv::snapshot()`, and `renv::restore()` on the other
  machine. It works because pak records the commit it installed from, which is
  the field `renv` reads -- and it notes the limit, that a member installed
  from a local working copy carries no commit for `renv` to record.

* `dev/specs/` gains a rejected design record for a `snapshot()`/`restore()`
  pair that would have pinned members by commit inside this package. It was
  specified, approved and then rejected once it was clear `renv` reads the same
  `RemoteSha` field and so has the same ceiling while covering strictly more.
  The record is kept for the evidence it gathered, including why installing by
  release or tag was rejected: six of the eleven members have no release at
  all, and `hvtiRlifetables` imports `TemporalHazard (>= 1.2.0)` whose latest
  release is v1.1.0.

# hvtiR 1.0.13

* Recomposed `.claude/house-style.md` against `house-style-v1` at `64c9e23`
  (archived `standard-2026-08-28-3`). Wording only: the Development records
  section now separates the `.Rbuildignore` exclusion from git tracking, and
  says that "one directory" contrasts against the `specs/` + `specs/plans/` pair
  rather than implying a per-repository subdirectory. The rule is unchanged.

# hvtiR 1.0.12

* Development records moved from `design/` to `dev/specs/`, adopting the
  portfolio convention settled in `ehrlinger/house-style`. Both gain an
  `hvtiverse` slug, since the house style names a file
  `<date>-<slug>-<kind>.md` and `2026-08-19-design.md` carried a date and a
  kind with nothing in between. `^design$` became `^dev$` in `.Rbuildignore`,
  and the README link, a `.gitignore` comment and the directory's own README
  table were repointed.

# hvtiR 1.0.11

* This repo now carries the composed house style and the CI check that
  enforces it, having been added to the `house-style` registry. The check
  fails when `.claude/house-style.md` drifts from the vault sources it was
  composed from.
* `hvtiEDAreports` is recorded as archived (2026-08-27) in the README and the
  two design documents that list it as a non-member.

# hvtiR 1.0.10

* The `HVTI Recipes` row in `inst/extdata/catalog.csv` now points at
  `ehrlinger/hvtiGraphics`, and its homepage at
  <https://ehrlinger.github.io/hvtiGraphics/>. The book's repository was renamed
  from `hvti_graphics`; GitHub redirects the repository, but GitHub Pages does
  not, so the homepage was a dead link rather than a redirected one. The book is
  not an R package, so it sits outside `members()` and was missed when the
  registry was repointed in 1.0.8.

# hvtiR 1.0.9

* `.remember/`, the scratch directory written by the `remember` skill, is now
  excluded from the build and from git. It was listed in neither ignore file, so
  `R CMD build` copied it into the tarball and `R CMD check` reported a "hidden
  files and directories" NOTE against the working tree. Nothing an installed
  package exposes changes.

# hvtiR 1.0.8

* The registry now names three repositories by the names GitHub actually
  serves. `hvtiRdatasets` became `hvtiRdatabuild`, and its repository moved with
  it; `ehrlinger/hvtiPropensityScores` became `ehrlinger/hvtiRpropensity`; and
  `ehrlinger/temporal_hazard` became `ehrlinger/TemporalHazard`.
* Only the first of those broke anything. `test-registry-live.R` fetches each
  member's `DESCRIPTION` and compares its `Package` field, so the renamed
  package failed while the two renamed repositories kept passing on GitHub's
  redirect -- staleness that works until the redirect stops working.
* Every member's package name now matches its repository name. The mapping is
  still stored rather than derived, because these three names moved in one week
  and a derived repo would fail silently the next time one does.

# hvtiR 1.0.7

* A pull request whose `Version:` has not moved past `main` now fails CI.
  Two branches bumping to the same version do not conflict in git -- the
  identical line merges silently and only `NEWS.md` shows a conflict -- so
  the collision was invisible until someone read the release notes. The
  guard also checks that `NEWS.md`'s `Version:` line and its per-release
  heading agree with `DESCRIPTION`, and that `Date` neither goes backwards
  nor sits in the future. `Date` is not required to advance: same-day
  releases are normal here, so demanding a new day would block them.

# hvtiR 1.0.6

* `member_deps()` records that `hvtiRtemplates` imports `hvtiRutilities`.
  The dependency was added upstream on 2026-08-27; without the entry an
  update that names only `hvtiRtemplates` leaves `pak` to resolve
  `hvtiRutilities` from CRAN, where it does not exist.

# hvtiR 1.0.5

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

# hvtiR 1.0.4

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

# hvtiR 1.0.3

* `status()` now detects an older GitHub installation when its version matches
  `main` but pak's recorded `RemoteSha` does not. The member reports as
  `"stale"`, so `update()` reinstalls it. Installs without GitHub commit
  provenance continue to use version comparison alone.
* Commit checks use GitHub's public Atom feeds rather than its rate-limited
  API. A failed commit check reports `"unknown"` and its reason is retained
  for `doctor()`.

# hvtiR 1.0.2

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

# hvtiR 1.0.1

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


# hvtiverse 1.0.0

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
