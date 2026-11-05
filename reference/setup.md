# Set up a study's environment

The one command a study needs before analysis. In order: checks R,
installs renv if it is missing, and turns off RStudio's `.RData` restore
and save (a preference for the user, not the study; see
`workspace_prefs`); runs `hvtiRutilities::study_setup()` with renv on,
which cleans up template copies before renv when adopting; declares
`hvtiR`, every member, the packages they need and the team's standard
analysis packages in the study's `DESCRIPTION`; installs them into the
study's library with pak and renv; snapshots; checks that every
package's dependencies resolve there; and restarts into the project.

## Usage

``` r
setup(
  study,
  study_tracker_id,
  root = NULL,
  adopt = FALSE,
  upgrade = TRUE,
  workspace_prefs = TRUE,
  ...
)
```

## Arguments

- study:

  The Study Tracker title.

- study_tracker_id:

  The Study Tracker ID, an integer.

- root:

  The study root, where `setup()` writes. By default the study enclosing
  the working directory; with none, the RStudio project folder the
  session is in, once its adoption is confirmed. Outside both, `setup()`
  stops and asks for it, so a new study always names its directory.

- adopt:

  Set up an existing study, adding only what is missing. Adopting cleans
  up template copies unless `cleanup = FALSE` is passed.

- upgrade:

  Whether the install may move versions the lockfile pins. The default,
  `TRUE`, moves them when the declared family needs newer ones: the
  guard lists each move (package, old and new version, `RemoteSha`
  changes) and the snapshot records the new versions. Pass `FALSE` for a
  study in revision, whose versions must not move: a locked package the
  install would move then stops the run and `renv.lock` is left
  unchanged.

- workspace_prefs:

  Whether to rewrite the user's RStudio preferences so that `.RData` is
  neither restored nor saved. The default, `TRUE`, applies to every
  project that user opens. `FALSE` leaves them as they are.

- ...:

  Passed to `hvtiRutilities::study_setup()`, such as `cleanup`,
  `template_dir` or `owner`. `renv` is not accepted: `setup()` always
  uses renv, so use `hvtiRutilities::study_setup()` directly for a study
  without it.

## Value

The study status from `hvtiRutilities::study_setup()`, invisibly, with
attributes `healed` and `missing`: data frames of the pins moved and the
packages left out.

## Details

The usual start is a legacy study opened as its own RStudio project
(File \> New Project \> Existing Directory): run
`setup(study, study_tracker_id)` in that project's console. With no
`_study.yml` there, `setup()` asks whether to adopt the project folder
(the default answer is No), and adopting cleans up template copies
unless `cleanup = FALSE` is passed. It refuses a project opened at one
of a study's folders, such as `30_analyses`, or at a package. A
non-interactive session never adopts unasked: it stops and prints the
`setup(root = ..., adopt = TRUE)` call to run. The step-by-step flow,
with where to type each command, is in
[`vignette("start-here")`](https://ehrlinger.github.io/hvtiR/articles/start-here.md).

renv runs in explicit mode: the lockfile records what the study's
`DESCRIPTION` declares, not whatever the code happens to mention. A
study that already has a `renv.lock` keeps its locked versions, and on
first conversion every package that lockfile recorded is declared, so
none drop out. They are restored, and only packages the lockfile lacks
are installed; one the library already holds is kept as it is, unless it
is a member. By default (`upgrade = TRUE`) it moves locked versions the
declared family needs and says which; `upgrade = FALSE` keeps a study in
revision on its locked versions.

The standard analysis packages are `tidyverse`, `haven`, `gtsummary`,
`flextable`, `survival`, `survminer`, `randomForestSRC`, `varPro` and
`pacman`, all from the configured repositories. A study needs no
separate step to have them; anything beyond them is added with
`hvtiRutilities::study_need()`.

Once the study's renv is active in a session, `setup()` replaces
packages that session has loaded, so rerun it from a session started
outside the project, passing `root`. From inside an active project it
stops before installing anything, and names the command to run.

In the install, the study stops using renv's per-user cache
(`renv::settings$use.cache(FALSE)`, kept in `renv/settings.json`, so it
applies to everyone), links already in the library are copied in
([`renv::isolate()`](https://rstudio.github.io/renv/reference/isolate.html)),
and any link whose target the user cannot read is removed, as is pak's
leftover `_cache` directory, and the package reinstalled. A shared
library cannot depend on one user's home.

No personal GitHub token is needed. The family is installed with pak,
which carries a shared token, into the study's library, and renv keeps
the environment: it restores the lockfile first, then snapshots, and
installs from the configured repositories the build-time (`LinkingTo`)
dependencies pak skips. Restoring a package the lockfile pins on GitHub
goes through renv, which has no shared token; a `GITHUB_PAT` (or a token
in the git credential store) covers that, and `setup()` warns when there
is none.

Two packages can land in this session's library rather than the study's:
`renv`, and `hvtiRutilities` with the packages it needs, are installed
with pak into the first library in
[`base::.libPaths()`](https://rdrr.io/r/base/libPaths.html) when they
are missing, and `hvtiRutilities` also when it is older than 1.5.6.
`setup()` runs them from this session, so they must be there before the
study's library exists.

When an install fails, `setup()` heals what it safely can and leaves out
what it cannot. Before it changes `renv.lock` it copies the file to
`renv/renv.lock.before-setup-<time>`. A restore that fails is healed in
up to 10 rounds: a package that will not build under this R moves to the
newest version the study's repositories serve (only with
`upgrade = TRUE`), and a missing dependency is installed first; a
dependency that will not install leaves its dependents out. After that,
`setup()` keeps leaving out packages outside the family until the
restore succeeds. A package left out stays declared but is dropped from
`renv.lock`. With `upgrade = TRUE` the install stage then retries it at
its current release, and it is locked if it installs; with
`upgrade = FALSE` it is not retried, because that would move a pin. A
package still missing at the end is named in a warning and recorded in
`renv/hvtiR-setup.dcf`; `setup()` finishes and opens the project, and
[`doctor()`](https://ehrlinger.github.io/hvtiR/reference/doctor.md)
lists what was left out. A package whose dependency is missing stays
locked but cannot load until the dependency installs. A family member
that cannot install still stops `setup()`. Each failure's log is kept in
`renv/logs/`.

Safe to rerun: each step checks before it acts.

## Examples

``` r
if (FALSE) { # \dontrun{
setup(
  study = "Study Tracker title", study_tracker_id = 1234L,
  root = "/studies/example"
)
} # }
```
