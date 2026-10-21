# Set up a study's environment

The one command a study needs before analysis. In order: checks R,
installs renv if it is missing, and turns off RStudio's `.RData` restore
and save; runs
[`hvtiRutilities::study_setup()`](https://ehrlinger.github.io/hvtiRutilities/reference/study_setup.html)
with renv on, which cleans up template copies before renv when adopting;
declares `hvtiR`, every member, the packages they need and the team's
standard analysis packages in the study's `DESCRIPTION`; installs them
into the study's library with pak and renv; snapshots; checks that every
package's dependencies resolve there; and restarts into the project.

## Usage

``` r
setup(study, study_tracker_id, root = NULL, adopt = FALSE, upgrade = TRUE, ...)
```

## Arguments

- study:

  The Study Tracker title.

- study_tracker_id:

  The Study Tracker ID, an integer.

- root:

  The study root. By default the study enclosing the working directory,
  or the working directory.

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

- ...:

  Passed to
  [`hvtiRutilities::study_setup()`](https://ehrlinger.github.io/hvtiRutilities/reference/study_setup.html),
  such as `cleanup`, `template_dir` or `owner`. `renv` is not accepted:
  `setup()` always uses renv, so use
  [`hvtiRutilities::study_setup()`](https://ehrlinger.github.io/hvtiRutilities/reference/study_setup.html)
  directly for a study without it.

## Value

The study status from
[`hvtiRutilities::study_setup()`](https://ehrlinger.github.io/hvtiRutilities/reference/study_setup.html),
invisibly.

## Details

renv runs in explicit mode: the lockfile records what the study's
`DESCRIPTION` declares, not whatever the code happens to mention. A
study that already has a `renv.lock` keeps its locked versions, and on
first conversion every package that lockfile recorded is declared, so
none drop out. They are restored, and only packages the lockfile lacks
are installed. By default (`upgrade = TRUE`) it moves locked versions
the declared family needs and says which; `upgrade = FALSE` keeps a
study in revision on its locked versions.

The standard analysis packages are `tidyverse`, `haven`, `gtsummary`,
`flextable`, `survival`, `survminer`, `randomForestSRC`, `varPro` and
`pacman`, all from the configured repositories. A study needs no
separate step to have them; anything beyond them is added with
`hvtiRutilities::study_need()`.

`setup()` replaces packages in the study's library, so run it from a
session started outside the study project, passing `root`. From inside
the project it stops before installing anything, and names the command
to run.

In the install, the study stops using renv's per-user cache
(`renv::settings$use.cache(FALSE)`, kept in `renv/settings.json`, so it
applies to everyone), links already in the library are copied in
(`renv::isolate()`), and any link whose target the user cannot read is
removed, as is pak's leftover `_cache` directory, and the package
reinstalled. A shared library cannot depend on one user's home.

No personal GitHub token is needed. The family is installed with pak,
which carries a shared token, into the study's library, and renv keeps
the environment: it restores the lockfile first, then snapshots, and
installs from the configured repositories the build-time (`LinkingTo`)
dependencies pak skips. Restoring a package the lockfile pins on GitHub
goes through renv, which has no shared token; a `GITHUB_PAT` (or a token
in the git credential store) covers that, and `setup()` warns when there
is none.

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
