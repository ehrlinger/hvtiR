# Set up a study's environment

The one command a study needs before analysis. In order: checks R,
installs renv if it is missing, and turns off RStudio's `.RData` restore
and save; runs
[`hvtiRutilities::study_setup()`](https://ehrlinger.github.io/hvtiRutilities/reference/study_setup.html)
with renv on, which cleans up template copies before renv when adopting;
declares `hvtiR`, every member and the packages they need in the study's
`DESCRIPTION`; installs them into the study's library in a fresh R
process; snapshots; checks that every package's dependencies resolve
there; and restarts into the project.

## Usage

``` r
setup(study, study_tracker_id, root = NULL, adopt = FALSE, ...)
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
are installed. Moving a study's versions is
[`update()`](https://ehrlinger.github.io/hvtiR/reference/update.md)'s
job, and the study owner's decision.

`setup()` replaces packages in the study's library, so run it from a
session started outside the study project, passing `root`.

Safe to rerun: each step checks before it acts.

## Examples

``` r
if (FALSE) { # \dontrun{
setup(study = "Study Tracker title", study_tracker_id = 1234L)
} # }
```
