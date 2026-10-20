# Study environment setup: fix the environment, do not just name the fix

**Status:** Design, approved 2026-10-20. Not yet planned.
**Spans:** `hvtiR` (new `setup()`, extended `doctor()`), `hvtiRutilities`
(`study_setup()` defaults, explicit renv, on-demand installs), `hvtiRtemplates`
(`add_job()` declares a template's packages).

## Why

The 2026-10-19 biostatistics R training spent most of two hours getting
environments right rather than using them. Every failure had the same shape: a
package told the user what to install, the user installed it in whatever
library was active, and the next step failed for a different missing piece. The
packages should make the environment right themselves.

What went wrong, and why:

| Symptom in the session | Cause |
|---|---|
| Installs "didn't take" because steps ran "out of order" | `pak` and `hvtiR` went into the user library before `renv::init()`; once renv isolated the project they were invisible. |
| `there is no package called 'digest'`, then `'labelled'` | Both are **Imports** of `hvtiRutilities`. A missing Import means `hvtiRutilities` was loaded from a library its dependencies are not in: a library-path fault, not a missing package. Installing them one error at a time hid it. |
| `register_data()` stops: needs `arrow` | `arrow` is a Suggests. `registered_versions.R` names `install.packages("arrow")` and stops. |
| `hvtiPlotR` "is not available" | Members live on GitHub; `install.packages()` and renv's default resolver do not know that. |
| `update()` needed `force = TRUE`, and repeated "restart R" | Stale members already attached in a reused session. |
| renv prompted with long lists of packages to record | renv's implicit snapshot scans the study's code, including stale template copies (`tp.*`, `old_RF_templates*`) that `.renvignore` does not list. Running `renv::init()` by hand, before `study_setup()`, meant the scan ran before cleanup and before `.renvignore` existed at all. |
| Two sessions on one project under R 4.4.1 and 4.6.1 | Nothing compares the running R with the R the study's lockfile records. |

The machinery for the right order already exists: `study_setup()` cleans up
template copies and then runs `renv::init(bare = TRUE)` in a child process. But
both steps are opt-in (`cleanup = FALSE, renv = FALSE`), so the documented
sequence ran renv first.

## Decisions

1. **One command sets a study up, in a fixed order:** `hvtiR::setup()`. Order:
   preflight, study identity and folders, **cleanup, then renv**, install,
   snapshot. Clean must come before anything that scans the study.
2. **renv runs in explicit mode.** The study's dependencies are declared in a
   study `DESCRIPTION` and the lockfile is built from it
   (`renv::settings$snapshot.type("explicit")`). renv no longer scans code to
   decide what to lock, so stale templates cannot leak in whether or not they
   were cleaned and whatever `.renvignore` says. An ignore list goes stale;
   a declaration does not.
3. **Both a bootstrap and an on-demand safety net.** `setup()` installs the
   full set up front. A function that still finds an optional package missing
   offers to install it into the project library, declares it, and snapshots,
   rather than printing an `install.packages()` line.
4. **An existing lockfile is restored, never upgraded.** Studies in revision
   must not move package versions. `setup()` on a study with a valid
   `renv.lock` restores the locked versions and adds only what the declaration
   names and the lockfile lacks. Moving versions is a separate, explicit
   `hvtiR::update()` by the study owner.
5. **`study_setup()` defaults change:** `cleanup = adopt`, `renv = TRUE`. Both
   stay arguments; see below.

### `cleanup = adopt`, overridable

An adopted study is almost always a legacy study carrying template copies, so
adopting implies cleaning. The default is lazy, `cleanup = adopt`, so it reads
`adopt` after the interactive "adopt it?" prompt may have set it to `TRUE`; the
prompt path cleans too, with no extra code. A caller can still pass
`adopt = TRUE, cleanup = FALSE`.

Consequence, stated in NEWS: adopting a study where `template_dir`
(`/programs/development/template`) does not exist now stops with an error
unless `template_dir` is passed or `cleanup = FALSE`.

### `renv = TRUE` by default, but still an argument

A complete environment is retained untouched, and a partial one stops with an
error naming what is missing, so `TRUE` is safe on every real study. The
argument stays for test suites: `hvtiRutilities` replaces the child-process
seam, but downstream suites that build temporary studies (`hvtiRtemplates`
among them) would otherwise run a real `renv::init()` and snapshot per study,
needing the network and the child timeout.

## Components

### `hvtiR`

**`setup(study, study_tracker_id, root = NULL, ...)`** (new, exported). Runs
from a session that has `hvtiR` loaded, in the study project. Steps:

1. **Preflight.** Reuses `doctor()`'s checks and acts on them:
   - R below `MIN_R_VERSION` stops.
   - An existing `renv.lock` whose recorded R version differs from the running
     one warns, naming both. This is the 4.4.1/4.6.1 split.
   - RStudio's "restore .RData into workspace" and "save workspace on exit"
     are turned off (`rstudioapi::writeRStudioPreference()`, when RStudio is
     running), with a line saying so. The `.Rproj` that `study_setup()` writes
     already sets both off per project.
   - Members missing from the current library are installed there first:
     `setup()` needs `hvtiRutilities` to run `study_setup()`.
2. **Study.** Calls `hvtiRutilities::study_setup(..., cleanup = adopt,
   renv = TRUE)`, which leaves a bare, explicit-mode renv project. Arguments
   not named by `setup()` pass through.
3. **Declare.** Writes, or adds to, the study `DESCRIPTION`: every hvtiR member
   plus `environment_extras()`, the Suggests that members' study-facing
   functions need (`arrow` for registered data first; the list lives in the
   registry beside `members()`, so one place owns it).
4. **Install.** In a child R process in the study, so the project library is
   the target: with a valid lockfile, `renv::restore(prompt = FALSE)`, then
   install only the declared packages the lockfile lacks; without one, install
   everything declared. GitHub members install as `owner/repo` with renv's pak
   back end enabled (`RENV_CONFIG_PAK_ENABLED=TRUE`), so the solver is the one
   `install()` already uses. A failed solve goes through
   `explain_install_failure()`.
5. **Snapshot** in the child, then **verify:** every declared package resolves
   in the project library, and every member's Imports resolve beside it. The
   verification is what catches the `digest` case.
6. **Hand over.** In RStudio, `rstudioapi::openProject(root)` restarts into the
   project library; elsewhere, the closing message says to restart R. The
   current session is never switched in place: its namespaces came from the
   user library.

Bootstrap, the only step left outside the packages, in any session, before or
inside the project:

```r
install.packages("pak")
pak::pak("ehrlinger/hvtiR")
hvtiR::setup(
  study = "EDIT: the Study Tracker title",
  study_tracker_id = 0L  # EDIT: the Study Tracker ID
)
```

**`doctor()`** gains two checks: members whose Imports do not resolve on the
current `.libPaths()` (named, with "run `hvtiR::setup()`"), and a running R
that differs from the lockfile's R.

### `hvtiRutilities`

- **`study_setup()`**: `cleanup = adopt`, `renv = TRUE` defaults.
  `.study_init_renv()` writes the explicit-mode setting before its snapshot.
  `.study_renvignore()` gains `tp.*` and `old_RF_templates*/`, for studies set
  up before explicit mode.
- **On-demand installs.** One internal helper, `.need_package(pkg, caller)`,
  replaces the "Install it with `install.packages()`" stops (today
  `read_clinical_data.R` and `registered_versions.R`):
  - installed: return;
  - interactive and in an renv project: ask once; on yes, `renv::install()`,
    add to the study `DESCRIPTION`, `renv::snapshot(prompt = FALSE)`, continue;
  - otherwise: stop, naming `hvtiR::setup()` as the fix, not
    `install.packages()`.

  It never upgrades an installed package (decision 4).

### `hvtiRtemplates`

- **`add_job()`** reads the packages the template's `setup` chunk attaches and
  version-checks, and passes any missing ones to the same declare, install and
  snapshot path, so scaffolding a random-forest job brings its packages with
  it. Templates already state their packages and floors in one chunk; this
  reads them rather than adding a second list.

## Error handling

Fail loud, every step. A step that cannot complete stops with what it found and
the one command that fixes it. `setup()` is safe to rerun: each step checks
before it acts (retained renv, existing declaration lines, packages already at
the locked version), so a run interrupted at any step resumes.

## Testing

- `hvtiR`: `setup()` against stubbed seams (child process, installer,
  `rstudioapi`), covering the fresh study, a study with a lockfile (restore,
  no upgrade), and a lockfile on a different R. `doctor()`'s Imports check
  with a fake library.
- `hvtiRutilities`: `cleanup = adopt` both ways, **including the interactive
  adopt prompt path**, which a refactor that forces `cleanup` early would break
  silently; `renv = TRUE` default through the seam; explicit mode recorded;
  `.need_package()` in its three branches.
- `hvtiRtemplates`: `add_job()` declares a template's packages, against a
  temporary catalog.
- One end-to-end run, `skip_on_cran()`: a temporary legacy-shaped study with a
  `tp.*` file, real renv, asserting the template copy is gone and absent from
  `renv.lock`. Mutation check: run renv before cleanup and confirm the test
  goes red.

## Release

Patch bumps only. Order: `hvtiRutilities`, then `hvtiRtemplates`, then `hvtiR`.
`setup()` checks the installed `hvtiRutilities` version at run time rather than
through `Imports`; `hvtiR` keeps its two-package Imports so it installs on a
bare machine.

## Out of scope

- **Which data to register.** The session's debate (register `built`, a
  derived "vars" analysis dataset, or both; which derivations move into the
  build) is a team decision, not an environment fix.
- **The Quick Start document** lives on SharePoint. Once `setup()` ships, its
  setup section shrinks to the three bootstrap lines above, and its
  `register_data()` example should drop arguments it no longer needs.
- **`setwd()` and `../` paths in scripts**, and choosing a Workbench resource
  profile: real, but not package environment.
