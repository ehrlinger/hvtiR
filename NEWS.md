Package: hvtiR
Version: 1.3.5

# hvtiR 1.3.5

* When restoring a study's lockfile fails because a package does not compile,
  `setup()` now names the packages that failed and gives the `renv::record()`
  call that moves the pin while keeping its locked source: a GitHub record
  stays on GitHub. Under `upgrade = FALSE` it gives no such call, since that
  mode keeps a revision's locked versions. It used to lead with "A GitHub
  token is needed" whenever an authentication message appeared anywhere in
  the output, which sent users after a token when the real cause was a locked
  version (`vctrs` 0.7.2) that no longer builds under R 4.6.

* After a compile failure, `setup()`'s `renv::record()` hint now covers every
  package that failed, in one call, each keeping its locked source. A package
  whose source has no safe one-line spec is named apart. Previously the call
  named only the first, so each further package cost another run.

* `setup()` no longer says "A GitHub token is needed" when renv's restore
  fails only on packages locked from a repository. renv prints its
  authentication note even when a retried GitHub download then succeeds, so
  the hint now needs a GitHub-locked package in renv's failed list (or a list
  too long to read in full), and names that package.

* Catalog versions refreshed from `main`: `TemporalHazard` dev 1.2.16 to
  1.2.17; `hvtiPlotR` dev 2.8.18 to 2.8.21; `hvtiRbootstrap` dev 0.9.6 to
  0.9.7; `hvtiRlifetables` dev 0.1.5 to 0.1.6; `hvtiRpropensity` dev 0.2.1
  to 0.2.2; `hvtiRtables` dev 1.0.11 to 1.0.12; `hvtiRtemplates` dev 1.5.2
  to 1.5.4; `hvtiRutilities` dev 1.5.15 to 1.5.18. The catalog ships in the
  package and is published as `members.json`, so its recorded versions are
  content rather than bookkeeping.

* Family floors refreshed from `main`: `hvtiRtemplates` Imports
  `hvtiRutilities` (>= 1.5.15) to (>= 1.5.17); `hvtiRtemplates` Suggests
  `TemporalHazard` (>= 1.2.12) to (>= 1.2.17); `hvtiRtemplates` Suggests
  `hvtiPlotR` (>= 2.8.18) to (>= 2.8.20); `hvtiRtemplates` Suggests
  `hvtiRdatabuild` (>= 0.3.0) to (>= 0.3.3). `family-floors.csv` ships in
  the package and records the version floors members declare on one another.

# hvtiR 1.3.4

* Catalog versions refreshed from CRAN and `main`: `ggRandomForests` CRAN
  3.5.4 to 3.5.5; `hvtiPlotR` dev 2.8.16 to 2.8.18; `hvtiRdatabuild` dev
  0.3.2 to 0.3.3; `hvtiRtemplates` dev 1.5.0 to 1.5.1; `hvtiRutilities` dev
  1.5.11 to 1.5.13. The catalog ships in the package and is published as
  `members.json`, so its recorded versions are content rather than
  bookkeeping.

* Family floors refreshed from `main`: `hvtiRdatabuild` Imports
  `hvtiRutilities` (>= 1.5.2) to (>= 1.5.3); `hvtiRtemplates` Imports
  `hvtiRutilities` (>= 1.5.11) to (>= 1.5.13); `hvtiRtemplates` Suggests
  `hvtiPlotR` (>= 2.8.9) to (>= 2.8.18). `family-floors.csv` ships in the
  package and records the version floors members declare on one another.

* `setup()` run from a session inside a different study's renv project now
  says so and names that project. It used to say the session had loaded
  packages `setup()` would replace, which was not the reason. RStudio reopens
  the last project on restart, so this is the usual way to hit it.

* The warning `install()` and `update()` raise for debris in a study's
  library now prints the study's real paths, so each repair command can be
  pasted as it is, where it used to print placeholders such as
  `<library>/_cache`. It no longer says pak cannot replace `_cache`: that is
  pak's staging directory, left by a failed install, which pak works around
  and renv's library scan fails on. A leftover `_cache` alone now gets its
  one removal step; links into a cache the user cannot read still get the
  full repair, which now says the renv steps fail until `_cache` is gone and
  ends by restoring only the removed packages: the bare `renv::restore()` it
  used to end with reverted every package to the lockfile, undoing the
  install or update that raised the warning. The numbered steps are
  indented under the warning.

* `setup()` removes pak's leftover `_cache` from a study library by its exact
  path. It used to pass the path to `unlink()` as a pattern, so a study path
  containing `[`, `*` or `?` could delete a sibling study's `_cache` and leave
  its own.

* `setup()` no longer upgrades a standard analysis package, such as `arrow`,
  that is already in the study's library but missing from its `renv.lock`.
  It named every unlocked package to pak, which installs the newest release
  of a package it is named; on a server that could not build that release,
  setup stopped. A family member missing from `renv.lock` is still named, so
  it moves to `main` even when already installed.

* `setup()` reports a removed `_cache` as what it is, pak's staging folder
  left by a failed install, rather than counting it among the unreadable
  cache links it removed and reinstalled.

* `setup()` no longer stops when `arrow` cannot be installed. It installs
  `arrow` last, on its own, and on a failure warns, names pak's message and
  the saved log, and sets the study up without it. Some servers cannot build
  current `arrow` (C++20, and OpenSSL 3 for its prebuilt library), and no
  older release compiles on R 4.6. A failure installing any other package
  still stops setup.

* Catalog versions refreshed from `main`: `hvtiRtemplates` dev 1.5.1 to
  1.5.2; `hvtiRutilities` dev 1.5.13 to 1.5.15. The catalog ships in the
  package and is published as `members.json`, so its recorded versions are
  content rather than bookkeeping.

* Family floors refreshed from `main`: `hvtiRtemplates` Imports
  `hvtiRutilities` (>= 1.5.13) to (>= 1.5.15). `family-floors.csv` ships in
  the package and records the version floors members declare on one another.

# hvtiR 1.3.3

* Catalog versions refreshed from CRAN and `main`: `hvtiRtables` dev 1.0.10
  to 1.0.11; `hvtiRtemplates` dev 1.4.2 to 1.5.0; `hvtiRutilities` dev 1.5.9
  to 1.5.11. The catalog ships in the package and is published as
  `members.json`, so its recorded versions are content rather than
  bookkeeping.

* Family floors refreshed from `main`: `hvtiRtemplates` Imports
  `hvtiRutilities` (>= 1.5.7) to (>= 1.5.11); `hvtiRtemplates` Suggests
  `hvtiRtables` (>= 1.0.9) to (>= 1.0.11). `family-floors.csv` ships in the
  package and records the version floors members declare on one another.

# hvtiR 1.3.2

* `setup()` declares a standard set of analysis packages in every study,
  alongside the family: `tidyverse`, `haven`, `gtsummary`, `flextable`,
  `survival`, `survminer`, `randomForestSRC`, `varPro` and `pacman`. They are
  the packages the team Quick Start used to install by hand. renv runs in
  explicit mode, so declaring them is what puts them in the lockfile; a study
  no longer needs a separate install step for them.

* `setup()` declares the `quarto` R package in every study. `hvtiRtemplates`
  renders jobs through it, and `render_job()` and `submit_job()` stop without
  it, but no member imports it, so a study that installed it by hand still
  left it out of `renv.lock` and a fresh `renv::restore()` could not render a
  job. It also declares `ggiraph`, which gives the `dc-eda` template its hover
  figures; without it the template quietly falls back to static ones. Rerun
  `setup()` in an existing study to record both.

* Catalog versions refreshed from CRAN and `main`: `ggBoostedTrees` dev
  0.9.3 to 0.10.0; `hvtiPlotR` dev 2.8.14 to 2.8.16; `hvtiRtables` dev 1.0.8
  to 1.0.10; `hvtiRtemplates` dev 1.4.1 to 1.4.2; `hvtiRutilities` dev 1.5.8
  to 1.5.9. The catalog ships in the package and is published as
  `members.json`, so its recorded versions are content rather than
  bookkeeping.

* Family floors refreshed from `main`: `hvtiRtemplates` Suggests
  `hvtiRtables` (>= 1.0.8) to (>= 1.0.9). `family-floors.csv` ships in the
  package and records the version floors members declare on one another.

# hvtiR 1.3.1

* Catalog versions refreshed from CRAN and `main`: `hvtiRutilities` dev
  1.5.7 to 1.5.8. The catalog ships in the package and is published as
  `members.json`, so its recorded versions are content rather than
  bookkeeping.

* Family floors refreshed from `main`: `hvtiRtemplates` Suggests
  `hvtiRtables` (>= 1.0.7) to (>= 1.0.8). `family-floors.csv` ships in the
  package and records the version floors members declare on one another.

* `setup()` now checks that it is not running inside the study before it does anything that can install. With a renv project active, or the session library under the study root, it stops and names the command to run from a session started outside the project, `hvtiR::setup(root = "<study>", ...)`. Before, resolving the root could install `hvtiRutilities` into the study's own library first.
* `setup()` finds the study root without installing anything: it uses `RENV_PROJECT` when set, and asks `hvtiRutilities` only when it is already installed.
* `setup()` stops the study using renv's per-user cache (`renv::settings$use.cache(FALSE)`, stored in `renv/settings.json` so it applies to the whole team) and runs `renv::isolate()` before restoring. It removes, and so reinstalls, any library link whose target the user cannot read, and pak's leftover `_cache` staging directory, and reports what it removed. This fixes "Unable to move package" failures in a library shared by several users.
* `install()` and `update()` warn, with the fix, when run from an active study project whose library holds links the user cannot read or a leftover `_cache` directory.
* `setup()` reports a failed install without crashing. The child's output is cleaned (carriage returns, colour codes, invalid bytes, braces) before it reaches the message, and the full raw output is saved to `hvtiR-setup-<time>.log` in the session's temporary directory, which the message names.
* `setup()` no longer needs a personal GitHub token. It installs the family with pak into the study's library (pak carries a shared token, so a server's shared IP does not exhaust GitHub's anonymous API limit) and keeps renv for the environment: restore, then the pak install, then the lockfile snapshot, in explicit mode. The `LinkingTo` packages pak skips are installed from the configured repositories, which the snapshot's validation needs. With no token it now warns instead of stopping, since only restoring a package the lockfile pins on GitHub can need one. A token held only in the git credential store is still passed on as `GITHUB_PAT` for the run.
* `setup()` no longer installs subdirectory remotes ahead of the rest to work around a renv 1.2.4 unpack bug: pak handles them, so the workaround and its `Remotes` parsing are removed.
* `setup()` finds the study root without loading `hvtiRutilities`: loading it left its namespace in use and blocked the upgrade that follows. It uses `RENV_PROJECT`, else the nearest `_study.yml` at or above the working directory, else the working directory.
* A link in the study's library whose target is readable but whose `DESCRIPTION` is not is now treated as unreadable and removed (the link only). A real package directory whose `DESCRIPTION` the user cannot read is never deleted: `setup()` stops before changing anything, names the packages, and says their owner or an administrator must fix the permissions (`chmod -R g+rX <library>/<pkg>`) or remove them.
* The `install()` and `update()` warning now gives the manual repair in the order that works: remove `_cache`, remove each broken link, then `renv::settings$use.cache(FALSE)`, `renv::isolate()` and `renv::restore()`.
* The check that no locked package moved now runs after the `LinkingTo` fill, immediately before the snapshot, because the fill installs through renv and can move a locked package.
* That check now compares `RemoteSha` as well as `Version`, so a GitHub package locked at one commit and rebuilt from another is caught even when its version is unchanged.
* When the check trips, `setup()` first removes the packages this run added to the study's library, then restores the moved locked packages, so the library matches the lockfile again. If that restore fails (restoring a GitHub-locked package needs a personal token), the message names the packages that could not be restored and the token steps. The lockfile is unchanged either way.
* The pak install now uses the repositories the study's `renv.lock` records, falling back to the session's, instead of the session's alone.

* `setup()` runs its child R processes from a script file instead of an `-e` argument. R truncated a long `-e` argument, so a study with about 155 locked packages ran half a script and stopped with "The install did not report the study's library path".

* `setup()` installs from the binary form of a Posit Package Manager source URL. When the study's `renv.lock` records `.../cran/latest` and the session has `.../cran/__linux__/<distro>/latest` (same host, path and snapshot), pak, the restore and the `LinkingTo` fill use the binary URL and `renv.lock` is rewritten to record it, so installs no longer compile from source (arrow failed on RHEL 8's default compiler). No other repository is changed.

* `setup()` no longer reports false moves from its lock guard. It compares versions as versions (`1.2-5` is `1.2.5`) and looks packages up across every library on the path, so recommended packages in R's system library (`mgcv`, `nlme`, `survival`, ...) are found.
* New `upgrade` argument to `setup()`. The default, `TRUE`, lets the install move locked versions the declared family needs, lists each move and records it in `renv.lock`. `upgrade = FALSE` keeps a study in revision on its locked versions: the guard rolls back as before, and its message now says how to move them.
* `setup()` now resolves unmet version requirements before it snapshots. It reads `Depends`, `Imports` and `LinkingTo` of every package in the study library and finds packages that are absent or below a floor (`>=`, `>`, `==`), as renv's snapshot validation would. With `upgrade = TRUE` (the default) it installs them through renv from the binary repositories and checks again; the lock guard then reports any locked package those installs moved, and a moved package it raised is listed under "Other unmet requirements resolved". What stays unmet, or anything at all with `upgrade = FALSE`, stops `setup()` before the snapshot with each requirement listed and `renv.lock` unchanged.

# hvtiR 1.3.0

* Catalog versions refreshed from CRAN and `main`: `hvtiRtables` dev 1.0.5
  to 1.0.7. The catalog ships in the package and is published as
  `members.json`, so its recorded versions are content rather than
  bookkeeping.

* Family floors refreshed from `main`: `hvtiRtemplates` Suggests
  `hvtiRtables` (>= 1.0.5) to (>= 1.0.7). `family-floors.csv` ships in the
  package and records the version floors members declare on one another.

* New `setup()` sets up a study's environment in one command: it cleans up template copies before renv,
  declares the family and the packages it needs, installs them into the study's library, and snapshots.
  renv runs in explicit mode, so the lockfile records what the study declares.
  A study with a `renv.lock` keeps its locked versions, and every package that lockfile recorded is declared on first conversion.
* `doctor()` reports a member whose dependencies are not on the library path, and a study lockfile made
  under a different R.
* `setup()` installs the subdirectory remotes that members pin (read from their DESCRIPTIONs, such as `boostmtree`)
  in a first `renv::install()` call, which works around a renv 1.2.4 failure ("target file ... already exists") on a cold cache.
* `setup()` warns before it writes anything when no GitHub credentials are found, and says how to create them,
  and a failed install that reports missing authentication credentials says so too.
* `setup()` never upgrades a locked package: if declaring a new package would move a locked dependency, it restores the locked versions, leaves `renv.lock` unchanged and stops, naming the change; `update()` is the way to move versions.

* Catalog versions refreshed from CRAN and `main`: `ggBoostedTrees` dev
  0.9.2 to 0.9.3; `hvtiPlotR` dev 2.8.11 to 2.8.14; `hvtiRdatabuild` dev
  0.3.1 to 0.3.2; `hvtiRtables` dev 1.0.7 to 1.0.8; `hvtiRutilities` dev
  1.5.5 to 1.5.7. The catalog ships in the package and is published as
  `members.json`, so its recorded versions are content rather than
  bookkeeping.

* Family floors refreshed from `main`: `hvtiRdatabuild` Imports
  `hvtiRutilities` (>= 1.5.1) to (>= 1.5.2); `hvtiRtemplates` Imports
  `hvtiRutilities` (>= 1.5.1) to (>= 1.5.7). `family-floors.csv` ships in
  the package and records the version floors members declare on one another.

# hvtiR 1.2.9

* Catalog versions refreshed from CRAN and `main`: `hvtiPlotR` dev 2.8.10 to
  2.8.11; `hvtiRbootstrap` dev 0.9.5 to 0.9.6; `hvtiRtemplates` dev 1.4.0 to
  1.4.1; `hvtiRutilities` dev 1.5.4 to 1.5.5. The catalog ships in the
  package and is published as `members.json`, so its recorded versions are
  content rather than bookkeeping.

# hvtiR 1.2.8

* `update()` now says at once that it installed nothing when a member it needs
  is already loaded, naming the loaded members. Until now the only signal was
  a warning, which prints after the call returns and vanishes under
  `suppressWarnings()` or `options(warn = -1)`, so `update()` could stop after
  "hvtiR is current" without a word about the members it skipped.

* Catalog versions refreshed from CRAN and `main`: `TemporalHazard` dev
  1.2.15 to 1.2.16; `hvtiPlotR` dev 2.8.6 to 2.8.10; `hvtiRdatabuild` dev
  0.3.0 to 0.3.1; `hvtiRpropensity` dev 0.1.11 to 0.2.1; `hvtiRtables` dev
  1.0.3 to 1.0.5; `hvtiRtemplates` dev 1.3.1 to 1.4.0; `hvtiRutilities` dev
  1.5.2 to 1.5.4. The catalog ships in the package and is published as
  `members.json`, so its recorded versions are content rather than
  bookkeeping.

* Family floors refreshed from `main`: `hvtiPlotR` Suggests
  `hvtiRpropensity` added; `hvtiRpropensity` Suggests `hvtiPlotR` added;
  `hvtiRtemplates` Suggests `hvtiPlotR` (>= 2.8.0) to (>= 2.8.9);
  `hvtiRtemplates` Suggests `hvtiRpropensity` (>= 0.1.10) to (>= 0.2.0);
  `hvtiRtemplates` Suggests `hvtiRtables` (>= 1.0.1) to (>= 1.0.5).
  `family-floors.csv` ships in the package and records the version floors
  members declare on one another.

# hvtiR 1.2.7

* Catalog versions refreshed from CRAN and `main`: `TemporalHazard` dev
  1.2.12 to 1.2.14. The catalog ships in the package and is published as
  `members.json`, so its recorded versions are content rather than
  bookkeeping.

* New `inst/extdata/family-floors.csv` records every version floor one family
  member declares on another, read from each member's `DESCRIPTION` on `main`
  by the weekly catalog-versions job. A floor `main` does not meet in
  `Depends`, `Imports` or `LinkingTo` would break `install()`, which resolves
  members from `main` in one call, so that job now fails on one; a `Suggests`
  floor is reported only.

* Catalog versions refreshed from CRAN and `main`: `TemporalHazard` dev
  1.2.14 to 1.2.15; `ggBoostedTrees` dev 0.9.1 to 0.9.2; `hvtiPlotR` dev
  2.8.5 to 2.8.6; `hvtiRbootstrap` dev 0.9.4 to 0.9.5; `hvtiRdatabuild` dev
  0.2.4 to 0.3.0; `hvtiRimputation` dev 0.1.2 to 0.1.3; `hvtiRlifetables`
  dev 0.1.4 to 0.1.5; `hvtiRtemplates` dev 1.3.0 to 1.3.1; `hvtiRutilities`
  dev 1.5.1 to 1.5.2. The catalog ships in the package and is published as
  `members.json`, so its recorded versions are content rather than
  bookkeeping.

* Family floors refreshed from `main`: `hvtiRtemplates` Suggests
  `hvtiRdatabuild` (>= 0.2.3) to (>= 0.3.0). `family-floors.csv` ships in
  the package and records the version floors members declare on one another.

# hvtiR 1.2.6

* `update()` now warns and installs nothing when a required member is already
  loaded; this replaces the previous error. The returned empty character
  vector carries a `blocked` attribute listing the loaded members. Restart R
  and run `update()` before those packages attach. `force = TRUE` still
  bypasses the guard, with the existing Windows safety risk.

* `DESCRIPTION` now declares the Quarto command line tool in
  `SystemRequirements`. The vignettes have always needed it to build; the
  field makes that visible to installers and to `R CMD check`.

* The pkgdown site's articles put the table of contents on the left and use
  the full width of the window, the same layout as the HVTI Quarto books and
  the hvtiRtemplates jobs, through `pkgdown/extra.css`. The installed
  vignettes keep the Quarto engine's own minimal format.

* Catalog versions refreshed from CRAN and `main`: `ggRandomForests` CRAN
  3.5.3 to 3.5.4; `hvtiPlotR` dev 2.8.4 to 2.8.5; `hvtiRimputation` dev
  0.1.1 to 0.1.2; `hvtiRpropensity` dev 0.1.10 to 0.1.11; `hvtiRtemplates`
  dev 1.2.4 to 1.3.0; `hvtiRutilities` dev 1.4.4 to 1.5.1. The catalog ships
  in the package and is published as `members.json`, so its recorded
  versions are content rather than bookkeeping.

# hvtiR 1.2.5

* Catalog versions refreshed from CRAN and `main`: `ggBoostedTrees` dev
  0.9.0 to 0.9.1; `hvtiPlotR` dev 2.8.3 to 2.8.4; `hvtiRtemplates` dev 1.2.2
  to 1.2.4; `hvtiRutilities` dev 1.4.3 to 1.4.4. The catalog ships in the
  package and is published as `members.json`, so its recorded versions are
  content rather than bookkeeping.

# hvtiR 1.2.4

* `install()` and `update()` explain a failed solve on an unmet dependency
  floor rather than passing on pak's raw "Could not solve package
  dependencies". They name each floor that the members being installed
  declare and the repositories cannot meet and, when a repository is a dated
  Posit Package Manager snapshot, print the one-line `options(repos = ...)`
  that points it at `latest` for the session. Any other failure is rethrown
  unchanged (#103).

* The getting-started vignette shows output as of 2026-09-29: the `status()`
  examples carry the installer version in the header, the member versions in
  the catalog on that date and all twelve members (`hvtiRimputation` was missing from the offline example),
  and the `doctor()` section covers the repository listing, the dated-snapshot
  warning and the dependency floors added in 1.2.3. The README's member table
  gains `hvtiRimputation` and its `doctor()` summary the same additions.

* Catalog versions refreshed from CRAN and `main`: `ggBoostedTrees` dev
  0.0.7 to 0.9.0; `hvtiPlotR` dev 2.8.2 to 2.8.3; `hvtiRpropensity` dev
  0.1.8 to 0.1.10. The catalog ships in the package and is published as
  `members.json`, so its recorded versions are content rather than
  bookkeeping.

# hvtiR 1.2.3

* `doctor()` lists the configured package repositories and warns when one is
  a dated Posit Package Manager snapshot, as RStudio Server sites often set.
  A dependency released after the snapshot is invisible to pak, so
  `install()` fails with "Could not solve package dependencies" when a member
  needs it: `ggRandomForests` requires `varPro (>= 3.3.0)`, released to CRAN
  on 2026-09-22.

* `doctor()` also names the dependency floors the configured repositories
  cannot meet. It reads each member's `DESCRIPTION` from GitHub, compares every
  outside `Depends`, `Imports` and `LinkingTo` floor against the repositories'
  package indexes. Against the Posit Package Manager snapshot of 2026-09-01
  it reports that `ggRandomForests` needs `varPro` >= 3.3.0 while the
  repositories offer 3.2.0. The check needs the
  network, so `doctor(remote = FALSE)` skips it.

* Catalog versions refreshed from CRAN and `main`: `TemporalHazard` dev
  1.2.11 to 1.2.12; `hvtiPlotR` dev 2.7.17 to 2.7.18. The catalog ships in
  the package and is published as `members.json`, so its recorded versions
  are content rather than bookkeeping.
* Catalog versions refreshed from CRAN and `main`: `hvtiPlotR` dev 2.7.18 to
  2.8.2; `hvtiRdatabuild` dev 0.2.3 to 0.2.4; `hvtiRtables` dev 1.0.2 to
  1.0.3; `hvtiRutilities` dev 1.4.1 to 1.4.3. The catalog ships in the
  package and is published as `members.json`, so its recorded versions are
  content rather than bookkeeping.

# hvtiR 1.2.2

* Catalog versions refreshed from CRAN and `main`: `hvtiPlotR` dev 2.7.15 to
  2.7.17; `hvtiRimputation` dev 0.1.0 to 0.1.1; `hvtiRpropensity` dev 0.1.7 to
  0.1.8; `hvtiRtemplates` dev 1.2.1 to 1.2.2; `hvtiRutilities` dev 1.3.1 to
  1.4.1.

# hvtiR 1.2.1

* `status()` now checks hvtiR itself against GitHub as well as the family
  members. When the installer is behind, the report names both the available
  version and `pak::pak("ehrlinger/hvtiR")` as the update command. `update()`
  reuses that check rather than making a second request.

* Catalog versions refreshed from CRAN and `main`: `hvtiRdatabuild` dev 0.2.2
  to 0.2.3; `hvtiRpropensity` dev 0.1.5 to 0.1.7; `hvtiRtemplates` dev 1.2.0 to
  1.2.1; `hvtiRutilities` dev 1.3.0 to 1.3.1. The catalog ships in the package
  and is published as `members.json`, so its recorded versions are content
  rather than bookkeeping.

# hvtiR 1.2.0

* ⚠️ **Breaking: the job catalog leaves hvtiR, and `jobs()` is removed.** The
  catalog moves to `hvtiRtemplates` as `inst/extdata/templates.json`, read by
  `hvtiRtemplates::template_catalog()`
  (`hvtiRtemplates:dev/specs/2026-09-18-template-catalog-design.md`). Every job
  type is a template there; other packages only supply the functions a
  template calls, so hvtiR keeps no part of it. Removed: `jobs()` and its help
  page, `inst/extdata/jobs.json`, the `job-catalog` vignette, the catalog tests
  (including the temporary freeze guard added while the catalog moved), the
  `jobs-pin-drift` workflow and `tools/check_jobs_pin.py`. `jsonlite` leaves
  Imports, and `ggRandomForests`, `hvtiPlotR`, `hvtiRpropensity`, `hvtiRtables`,
  `hvtiRutilities` and `TemporalHazard` leave Suggests and Remotes: they were
  installed only to validate the catalog's `replaced_by` exports. The registry
  still names them all as members; `install()` reads the registry, not this
  package's `DESCRIPTION`.

* **The published-artifact catalog records `hvtiRutilities` 1.3.0** in its
  `dev_version` column, refreshed from `main` by
  `tools/refresh_catalog_versions.py`.

# hvtiR 1.1.15

* **The published-artifact catalog records `hvtiRutilities` 1.2.1** in its
  `dev_version` column, refreshed from `main` by
  `tools/refresh_catalog_versions.py`. That catalog is presentation metadata,
  read by the internal `read_catalog()` for renderers such as the family
  table; `status()` does not read it, and takes its versions live from each
  repository's `main`. 1.2.1 carries `cache_fit()` and the `rfr`, `sid` and
  `vt` taxonomy rows that the `rfs`/`rfc`/`rfr` and `sid`/`vt` catalog rows
  above depend on.

* **`rfs`, `rfc` and `rfr` move from `retire` to `scaffold`, destined for
  `hvtiRtemplates`.** Their templates are owed there: they fit with
  randomForestSRC and plot with ggRandomForests, so they use ggRandomForests
  rather than living in it. `status` becomes `queued`, since a row destined for
  hvtiRtemplates carries a scheduling status, and `batch` stays null because
  no ML batch has been assigned. `replaced_by` keeps the `gg_*` functions the
  templates will call. `retire` now holds exactly `rf` and `rfsrc`, the legacy
  umbrella rows `hvti_taxonomy()` demoted.

* **`rfr`, `sid` and `vt` leave intake.** hvtiRutilities PR #127 added all
  three prefixes to `hvti_taxonomy()`; it is on that package's `main` but in
  no release yet, so it is NOT in 1.2.0. All three rows are destined for
  `ggRandomForests`, off this catalog's `hvtiRtemplates` destination, so they
  take `status: null` like the other off-destination rows rather than a
  scheduling status. `rfr` is a retire row and needs no blocker. `sid` and
  `vt` are build rows, which must cite a real issue once out of intake; they
  now cite `hvtiRforests#1`, the issue for ML sub-project 3, opened with the
  new `hvtiRforests` repository because nothing citable existed before.

* The intake placeholder guard in `test-jobs.R` no longer goes quiet when
  intake is empty. It asserted inside a `for` over the intake rows, so with
  none left it made no expectation, and testthat reports an empty test as a
  SKIP rather than a pass. It now asserts over the whole set. Separately, the
  temporary pin on the three rows' `hvtiRutilities#taxonomy` blocker is
  retired: `sid` and `vt` are now pinned to `hvtiRforests#1`, and `rfr` to
  having no blocker at all.

# hvtiR 1.1.14

* **The catalog records the current `main` version of five members**, refreshed
  from the live oracles by `tools/refresh_catalog_versions.py`:
  `hvtiRutilities` 1.1.12 to 1.2.0, `hvtiRtemplates` 1.1.0 to 1.2.0,
  `hvtiPlotR` 2.7.14 to 2.7.15, `hvtiRpropensity` 0.1.4 to 0.1.5 and
  `hvtiRtables` 1.0.1 to 1.0.2. Until now `status()` could not tell anyone that
  the `hvtiRutilities` and `hvtiRtemplates` 1.2.0 releases existed, which is
  what a study needs before it can install them.

# hvtiR 1.1.13

* **`dc-stddiff` moves from `hvtiRutilities` to `hvtiRpropensity`.** That
  package already computes standardized differences inside `ps_match()`,
  `ps_logistic()` and `ps_weight()`, and the port takes `stddiffci` and
  `mw_var` with it. The row stays `build`, now blocked on
  `hvtiRpropensity#34`, which supersedes `hvtiRutilities#103`, and its spec is
  hvtiRtemplates' `dev/specs/2026-09-16-standardized-difference-design.md`.

* **The catalog marks `dc-general` shipped**, over
  `hvtiRutilities::proc_contents()` and `proc_means()`, with base R for the
  contingency tables, cumulative distributions and correlations.

* Catalog versions refreshed from CRAN and `main`: `hvtiRdatabuild` dev
  0.2.1 to 0.2.2. The catalog ships in the package and is published as
  `members.json`, so its recorded versions are content rather than
  bookkeeping.

# hvtiR 1.1.12

* Catalog versions refreshed from CRAN and `main`: `hvtiPlotR` dev 2.7.13 to
  2.7.14; `hvtiRbootstrap` dev 0.9.3 to 0.9.4; `hvtiRdatabuild` dev 0.2.0 to
  0.2.1; `hvtiRlifetables` dev 0.1.3 to 0.1.4; `hvtiRpropensity` dev 0.1.3
  to 0.1.4; `hvtiRtables` dev 1.0.0 to 1.0.1; `hvtiRutilities` dev 1.1.11 to
  1.1.12. The versioned catalog ships in the package.

# hvtiR 1.1.11

* **The catalog marks `dc-tables`, `dc-gfup` and `dp-postage` shipped.**
  `dc-tables` now names the correlation table and matrix engines, and
  `dp-postage` is thin over `hvtiPlotR::hv_eda()`.

* Catalog versions refreshed from CRAN and `main`: `ggRandomForests` CRAN
  3.5.2 to 3.5.3; `TemporalHazard` dev 1.2.9 to 1.2.11; `ggBoostedTrees` dev
  0.0.6 to 0.0.7. The catalog ships in the package and is published as
  `members.json`, so its recorded versions are content rather than
  bookkeeping.

# hvtiR 1.1.10

* **`pm`'s row leaves the catalog**, with its entry in `hvti_taxonomy()`.
  It had stayed as a `retire` row after folding into `lm` only because
  `hvtiRtemplates` requires the catalog and the taxonomy to name the same
  prefixes. `lm` still counts the studies using either prefix, 470. The
  catalog has 57 rows and 5 retired.

* **The hazard rows name the TemporalHazard functions their templates
  call**, in `replaced_by`: `ac` `hzr_kaplan()`; `hz` `hazard()` and
  `hzr_phase()`; `hm` `hazard()`, `hzr_stepwise()`, `hzr_deciles()` and
  `hzr_gof()`; `hs` `hazard()` and `hzr_stepwise()`; `bh` `hzr_bootstrap()`
  and `hzr_stepwise()`; and `hp` adds `hazard()` to its `hvtiPlotR`
  functions. Each is read from the shipped template in `hvtiRtemplates` and
  validated against TemporalHazard's exports, so `TemporalHazard` joins
  `Suggests`, `Remotes` and the CI installs. `bc` is a Cox job and calls none
  of them. No disposition changes.

* **Five rows take the relabelled taxonomy names**, after the same review
  that folded `pm` into `lm`: `bn` "Bootstrap non-linear", `nd` "Non-linear
  distributions", `nm` "Non-linear model", `np` "Non-linear plot" and `nb`
  "Boosting". `hvti_taxonomy()` in `hvtiRutilities` takes the same labels.

# hvtiR 1.1.9

* **`pm` folds into `lm`, and `lm` is `thin` over `hvtiRpropensity`.** A
  review of the catalog page on 2026-09-11 put 8 or 9 in 10 `lm` jobs as
  propensity models, and the corpus agrees as far as a text match can: 1,014
  of the 1,872 `lm` SAS programs name a propensity or balancing score, in 331
  of 467 studies. `lm` now leans on `ps_logistic()` and `bs_count()`, and
  counts the studies using either prefix, 470 against 469. `pm`, whose
  programs are negative-binomial balancing-score fits, is `retire` over
  `bs_count()`, and keeps a row only while `hvti_taxonomy()` lists it.
  `hvtiRpropensity` joins `Suggests`,
  `Remotes` and the CI installs, because the routing test validates every
  package a `replaced_by` names and fails on CI when one is absent.

* **The catalog's counts are corrected, and their units are written down.**
  `dc-stddiff` counts the union of the six spellings that fold into it, 120
  studies, where 59 was the 2019 spelling alone and a sum would give 157. `si`
  and `mi` count jobs like every other row: `mi` its own and `bd`'s
  multiple-imputation jobs, 18 studies, and `si` 1, because mean imputation
  runs inside bootstrap jobs. The 223 and 326 studies calling the imputation
  macros stay in the notes. Twelve of
  the thirteen qualified `dc` and `dp` rows gain `r_jobs` and `r_exemplars`,
  by the 2026-08-29 definition, which the scan reproduces for all 42
  prefixes; `dp-postage` stays null, because its job is named by dataset.
  Section 5 of `dev/specs/2026-09-04-job-catalog-design.md` defines each
  unit and records two rules: `sas_breadth_jobs` is the figure of record, and
  where two spellings name one job the newer macro's names the row while the
  row counts both.

* **`jobs()` returns `sas_breadth_jobs` and `r_exemplars`**, and the job
  catalog vignette's SAS column reads `sas_breadth_jobs`. It read
  `sas_breadth`, which is null on every qualified row, so all thirteen `dc`
  and `dp` rows showed no SAS count.

* **`dc-trends` and `dp-boxplot` now count studies in the field's own unit.**
  #61 filled `sas_breadth_jobs` with a token count over the whole job name, 58
  and 34, where every other qualified row holds distinct studies whose second
  name field is the qualifier. By that unit, from the 2026-09-02 re-parse, they
  are 43 (`descriptive/dc`) and 9 (`graphs/dp`), both still past the
  two-studies gate. The `options` evidence strings stay token counts, and say
  so.

* **Two job types join the catalog, and a top-level `options` list starts
  beside `jobs`.** `dc-trends` (43 studies) and `dp-boxplot` (9) are
  `queued` with no batch yet. Both come from the 2026-09-10 triage in
  `hvtiRtemplates`, counted as distinct studies over the 2026-08-27 census.
  `options` records four constructs that span prefixes rather than being job
  types of their own: a landmark early / late split, repeated events, a US
  life-table comparison, and a matched or weighted analysis. Every reader of
  the catalog takes only `jobs`, so the new list changes nothing that exists.
  The `hs` and `dc-stddiff` notes now name the legacy variants that fold into
  them, and the tests that pinned 56 rows now pin 58.

# hvtiR 1.1.8

* **`dp-trends` is `shipped`**, the first of the EDA templates from the
  2026-09-10 batch. `hvtiRtemplates` gains `40_graphs/dp-trends.qmd`, a thin
  template over `hvtiPlotR::hv_trends()`. Its design is
  `dev/specs/2026-09-10-dp-trends-template-design.md` in `hvtiRtemplates`, the
  value the row's `spec` now holds. A `spec` with no repository prefix is a path
  in `hvtiRtemplates`, as 16 of the catalog's 18 are; `si` and `mi` name
  `hvtiRdatabuild/` explicitly because their designs live there. The row is
  flipped straight to `shipped` rather than through `in-flight`:
  `hvtiRtemplates` only sees the catalog through its pinned tag, and the pin
  moves in the same pull request that adds the template, so the catalog never
  claims a template that is not on disk and one tag suffices.

# hvtiR 1.1.7

* **`dp-postage` is no longer blocked.** Its `blocked_on` named
  `hvtiRtemplates#97`, the defect that made `hvtiRtemplates` reject any template
  whose folder disagrees with `hvti_taxonomy()`. `hvtiRtemplates#98` fixed it
  and closed `hvtiRtemplates#97` on 2026-09-10, so `blocked_on` is now `null`
  and the row's note records when and why. Nothing checks `blocked_on` for a
  `queued` row, which is why this is a manual step rather than something a test
  would have caught.

* **The job catalog gains `dp-postage` and pulls three `dc` rows into batch 3**,
  taking it from 55 rows to 56. Scheduled for the biostats fellows training
  session; the design is
  `hvtiRtemplates/dev/specs/2026-09-09-eda-templates-design.md`.

  `dc-general`, `dc-tables` and `dc-gfup` move from batch 4 to batch 3. Nothing
  else moves: `dc-dead`, `lg` and `rg` stay in 4, and the `dp` rows were
  already in 3.

  ⚠️ **`dp-postage` is the first row whose `folder` disagrees with
  `hvti_taxonomy()` by design.** The taxonomy files `dp` under `graphs`; this
  row is `descriptive`, which is the third folder the prefix occupies in the
  corpus. `hvtiRtemplates` asserted template folders against the taxonomy
  alone until `hvtiRtemplates#98`, so a row like this one, and the already
  scheduled `dp-variable` with `folder: distributions`, could not have shipped
  a template. `blocked_on` names that issue.

  Its counts are `null` rather than zero. `descriptive/dp` has never been
  censused: the 2026-09-02 decomposition enacted rows for `graphs/dp` and
  `distributions/dp` only, and five further `descriptive/dp` legacy templates
  remain unrepresented. An em dash in the rendered roadmap means unmeasured,
  not absent.

  `disposition` is `scaffold`, not `thin` like its `dp` siblings, because
  `hvtiPlotR` 2.7.13 has no faceting constructor and the grid is the
  template's own `facet_wrap()`.

* **`dc-tables` records that pairwise correlation is in scope for it.** The
  exemplar is `/descriptive/dc.tables.ods_preoplabs_a1c.sas`, one `proc corr
  nosimple spearman pearson fisher(biasadj=no) plots=matrix` emitting a
  scatter-plot matrix and a Fisher-CI coefficient table. `dc-general` carries a
  plain `proc corr nosimple rank` section with no plot and no intervals, so the
  two are not the same job and the note says which is which.

* `hvtiRutilities` is recorded at 1.1.11 in `inst/extdata/catalog.csv`, up from
  1.1.10, refreshed from `origin/main` by `catalog-versions.yml`. The catalog
  ships in the package and is published as `members.json`, so its recorded
  versions are content rather than bookkeeping and belong under a heading like
  anything else.
* `catalog-versions.yml` now files its own NEWS entry, via
  `tools/news_catalog_entry.py`. The refresh pull request changed
  `inst/extdata/catalog.csv` and nothing else, which is exactly the shape
  `check_version.py` rejects -- version unchanged from the base and no
  standing `# hvtiR (unreleased)` heading to file under. Both guards are
  right; the machine pull request could satisfy neither, so every refresh
  needed a hand-written NEWS commit before it could merge.
* The collision is structural rather than occasional: the unreleased heading
  is removed by every naming commit, so a refresh landing between a bump and
  the next unreleased change fails every time. 1.1.6 was named minutes before
  the refresh that exposed it.
* The tool never opens a second unreleased heading and never repeats a bullet
  it has already written, because the refresh branch is regenerated weekly and
  reruns have to converge rather than accumulate.
# hvtiR 1.1.6

* Added `hvtiRimputation` to the registry, taking the family to twelve
  members. It ports `PROC STANDARD` with `REPLACE` and the `imputsub` macro:
  fill by a stated method, and return a row-level record of exactly which
  values were changed. It imports only `stats` and `utils`, so it needs no
  `member_deps()` edge and no `Remotes:` line of its own -- the third of the
  three things adding a member usually takes does not apply here. It is
  recorded as `wip`: `impute_multiple()` is unbuilt and pooling is
  deferred.
* Registered only after `ehrlinger/hvtiRimputation`'s `main` actually carried
  the package. The repo existed on GitHub for some hours with `main` at an
  empty initial commit and the package on an unmerged branch, and a registry
  row written then would have broken `install()` for everyone: every spec goes
  to `pak::pak()` in one call, so a single spec resolving to a `main` with no
  package fails the whole family install rather than its own row.
* **The job catalog gains `si` and `mi`**, the imputation job types, taking it
  from 53 rows to 55. Both are `datasets`/`datasets`, `disposition: scaffold`,
  destined for `hvtiRtemplates`. `si` is ported and shipped as
  `hvtiRimputation::impute_mean()`; `mi` is blocked on `impute_multiple()`,
  which is designed and not built.

  ⚠️ **`sas_breadth` is deliberately `null` on both.** The imputation numbers
  that exist are STUDY counts -- 223 call single, 326 call multiple, 18 both --
  and this field holds file/job counts everywhere else in the catalog (`bd` is
  1,134 files). Writing study counts into it would repeat the units error the
  corpus census already caught once, where macro *copies* were reported as
  *runs*. The counts are in `note`, with their unit named.

  This row was not optional: `hvtiRtemplates`' `test-roadmap.R` asserts that
  every taxonomy prefix has a catalog row, so adding `si`/`mi` upstream in
  `hvtiRutilities` turned that suite red until the catalog accounted for them.
  That gate is working exactly as its comment says it should.
* **`53` is no longer hard-coded in two places and one docstring.** The counts
  moved to 55, and `jobs()`'s test now also asserts
  `nrow(jobs()) == length(read_jobs())` -- the relationship, which cannot go
  stale the way a literal does.
* New `jobs-pin-drift` workflow, with `tools/check_jobs_pin.py` behind it.
  `inst/extdata/jobs.json` is read by sibling repositories rather than
  imported, so `hvtiRtemplates` checks it out by tag -- deliberately, so that
  editing the catalog here cannot fail every pull request there. That pin has
  a shelf life: once `main` moves past the newest tag, the pin still resolves
  and both sides stay green while the consumer validates against an older
  catalog. Between `v1.1.3` and `v1.1.5` that gap was eighteen rows and
  nothing reported it; it closed because somebody advanced the pin by hand.
  Two copies of one definition, each locally valid and neither reporting the
  divergence, is the failure mode this migration exists to escape.
* Raising the alarm needs no list of consumers; clearing it does, and the two
  are not symmetric. `main` ahead of the newest tag means every pin is stale
  whatever tag it names, which is local knowledge. `main` matching the newest
  tag means only that a tag holding the current catalog *exists* -- it says
  nothing about which tag anybody checks out. So clearing reads the consumer
  workflows and requires every `ref:` to name that tag; a ref that cannot be
  read is pending, never current.
* It reports into one reused issue rather than opening a pull request, because
  the remedy -- name a version, tag it, advance `ref:` in the consumer -- is a
  maintainer's decision rather than a data edit, and it closes that issue only
  once every consumer is confirmed to read the new tag. It does not fail a
  build, and it stays quiet for a seven-day grace period on both halves, since
  `main` ahead of the newest tag is the normal unreleased window under the
  house cadence and a freshly cut tag needs time to propagate.

# hvtiR 1.1.5

* Routed the five `dc` (descriptive) jobs in `inst/extdata/jobs.json`
  according to an audit, rather than the standing shorthand that all of them
  were `hvtiRtables`' work. That shorthand held for exactly one of the five.
  `dc-tables` is the manuscript table job: hvtiRtemplates' decomposition
  design pins it to a table-building macro allocated to `hvtiRtables`, and
  `hv_tbl_summary`, `hv_man_table` and `hv_man_table_save` cover it, so it
  stays `thin`. `dc-general`, `dc-gfup` and `dc-dead` are base-procedure
  jobs, "look at the data" rather than "produce the manuscript table". One
  job of each of the latter two shapes was read in the corpus; both run base
  procedures only, with no table-building macro. `hvtiRutilities` ports two
  of those procedures, so all three stay `thin` with `replaced_by` naming
  `hvtiRutilities::proc_contents` and/or `hvtiRutilities::proc_means`; the
  remainder is tracked as `hvtiRutilities#102` and does not block the `thin`
  marking. `dc-stddiff` becomes a `build` row targeting `hvtiRutilities`
  rather than `hvtiRtables`: the decomposition design decided on 2026-09-03
  to ship the successor standardized-differences macro rather than its
  predecessor, which makes the dependency `hvtiRutilities`, and the function
  does not exist yet. Its `status` and `batch` are now `null`, per the
  schema rule that those hvtiRtemplates scheduling fields are null whenever
  `destination` moves off `hvtiRtemplates`; the work is tracked as
  `hvtiRutilities#103`.

# hvtiR 1.1.4

* Corrected `inst/extdata/jobs.json` disposition for the `(dp, variable)` job
  row from `scaffold` to `thin`, with `replaced_by` naming
  `hvtiPlotR::hv_trends` and `hvtiPlotR::hv_ordinal`. A coverage consistency
  check had flagged this row as the one `scaffold` disposition in a group of
  otherwise `thin` rows. Reading real jobs across several studies confirmed
  the shape is a descriptive time-trend plot of one variable with no
  covariates, already served by those two `hvtiPlotR` exports, so no new
  template is needed.

* The scheduled catalog refresh no longer reports success when its script
  crashed. The workflow tested the exit code against `-gt 2`, but 0 and 2 are
  the only codes the script returns deliberately, and an uncaught Python
  exception exits 1. That passed the test, so the run ended green having
  written nothing, opened no pull request and raised no annotation: a record
  that looks checked and is not, which is the failure the schedule exists to
  prevent. The guard is now an allowlist.

* `cran_version()` treats any crandb answer that is not a package record as an
  unreadable oracle rather than crashing on it. A 200 carrying a JSON array,
  string or number, or a non-string `Version`, raised an uncaught
  `AttributeError`, which was the exit-1 crash above. Such a row now keeps its
  recorded value and is reported, like any other unreadable oracle. That
  includes a 200 carrying an object with no `Version`: `{}` and an error
  envelope are objects, so they passed the shape check and mapped to `""`,
  which this module reserves for an authoritative CRAN 404. A recorded
  version was blanked and no failure was reported.

* The catalog refresher waits between retried fetches. It retried three times
  with no delay at all, which is not a retry: the case the attempts exist for
  is a throttled shared-IP runner, and three requests fired inside a
  millisecond meet the same closed window three times. The wait now widens
  with the attempt, matching `remote_retry_wait` in `R/remote.R`.

* An unreadable oracle now says why. `fetch()` collapsed every exhausted retry
  to status 0, so a throttle was reported with the wording reserved for
  permanent causes, "renamed, private, default branch moved, or the file is
  gone", and pointed the reader at a rename that never happened. The last
  status seen survives the attempts and `why_unreadable()` turns it into the
  repair it actually implies.

* `--check` no longer reports "no drift" for a run that verified nothing. A
  failed fetch keeps the recorded value, so `before == after` holds just as
  firmly when nothing was read as when everything was read and unchanged, and
  the exit code was 0 either way. It is now 2 when an oracle could not be
  read, matching the convention the writing path already used.

* `status` and `batch` are now null on every row whose `destination` is not
  `hvtiRtemplates`, except an `intake` row, which keeps `status: "intake"`
  and only loses `batch`. Both fields are `hvtiRtemplates` scheduling values,
  and a row `hvtiRtemplates` will never ship a template for has nothing to
  schedule; leaving a value there let `rfc` read `queued` on the exact
  `ggRandomForests` surface that had already justified marking `rf` and
  `rfsrc` `out-of-scope`. `out-of-scope` had no remaining users after the
  change and is removed as a status value.

# hvtiR 1.1.3

* `status()` and `doctor()` report hvtiR's own version. hvtiR is not a member,
  so `status()` walks `members()` and never showed the version of the package
  the user is running, and `doctor()`'s Environment section reported the R
  version, the platform and `pak` but not hvtiR. Both issue templates ask for
  that output, so a report arrived without the one version a maintainer needs
  first.

* `jobs()` names the row and the field when a scalar field in the catalog
  arrives as an array. `vapply()`'s own message for that named neither, and
  the first sign of it was the vignette failing to build. The catalog is hand
  edited and four of its fields are arrays, so a scalar written as one is a
  plausible slip.

* `jobs()` also names the row and the field when a count field holds something
  that is not a whole number. `as.integer()` made that `NA` with a warning,
  which reads downstream as a field the catalog simply omits rather than one
  written wrong. A whole number written as a string still reads.

* `ggBoostedTrees` is no longer declared in `Suggests`. No `replaced_by` entry
  names it, so nothing loaded it, but `R CMD check` installs all of `Suggests`
  and it pulls a compiled `boostmtree` fork; seven CI jobs were building it on
  every run. `ggRandomForests` and `hvtiPlotR`, which the catalog does name,
  stay.

* The catalog gains `cran_version`, `dev_version` and `dev_ahead`, refreshed
  weekly from crandb and each repo's `DESCRIPTION` on `main` by
  `tools/refresh_catalog_versions.py`. `members.json` is unchanged, so no
  downstream CV sink is affected.

* New `jobs()`, the job catalog: every job type found in the studies corpus,
  routed to the package that owes it. Rendered as the "The job catalog"
  article.

* `AGENTS.md` records the branch rulesets as they actually stand. It claimed the
  repositories differed only in `required_status_checks`, and that the pull-request
  rules were uniform; checked against the API, neither held. The two repositories
  that disagreed were brought into line rather than the claim being softened:
  `hvtiRbootstrap` now requires one approving review like the rest, and
  `hvtiGraphics` no longer carries `require_code_owner_review` with no `CODEOWNERS`
  file behind it, and now requires an approving review like the rest. All thirteen
  repositories under `house-style/repos.yml` carry an identical `protect main` apart
  from `required_status_checks`, which `TemporalHazard`, `ggRandomForests` and
  `hvtiRbootstrap` enforce; the reason each of the three does is written down.

# hvtiR 1.1.2

* `ggBoostedTrees` replaces `hvtiBoostmtree` in the registry. The boostmtree
  work moved out of an HVTI-named fork of the modelling package and into a
  plotting package that sits beside `ggRandomForests`: it draws `boostmtree`
  and `BoostMLR` fits rather than re-releasing them. The member count is
  unchanged at eleven. `hvtiBoostmtree` is retired, so an installed copy is not
  removed by an update and should be dropped by hand.

* GitHub issue templates, as YAML forms rather than markdown. Three of them --
  an installation or update failure, a bug in `status()`, `doctor()` or
  `members()`, and a change to the family registry -- each requiring the
  diagnostics its own case needs, so an install report cannot arrive without
  `doctor()` and `sessionInfo()` output. The chooser also links every member's
  tracker: this repository is the one everyone installs, so it is where reports
  about the other eleven packages land. `.github` is in `.Rbuildignore`, so
  none of it reaches `R CMD check`.

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
