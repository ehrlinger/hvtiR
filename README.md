# hvtiR

<!-- badges: start -->
[![R-CMD-check](https://github.com/ehrlinger/hvtiR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ehrlinger/hvtiR/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/ehrlinger/hvtiR/graph/badge.svg)](https://app.codecov.io/gh/ehrlinger/hvtiR)
[![active](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/badges/latest/active.svg)
[![pkgdown](https://github.com/ehrlinger/hvtiR/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/ehrlinger/hvtiR/actions/workflows/pkgdown.yaml)

[![R package version](https://img.shields.io/github/r-package/v/ehrlinger/hvtiR)](https://github.com/ehrlinger/hvtiR)

[![lint](https://github.com/ehrlinger/hvtiR/actions/workflows/lint.yaml/badge.svg)](https://github.com/ehrlinger/hvtiR/actions/workflows/lint.yaml)
<!-- badges: end -->

One command to install the HVTI R package family, and one command to say
whether you are current.

**Documentation:** <https://ehrlinger.github.io/hvtiR/>

**New to the family, or to a study?**
[Start here](https://ehrlinger.github.io/hvtiR/articles/start-here.html). It sets
the study up and sends you on to the
[`hvtiRtemplates` tutorials](https://ehrlinger.github.io/hvtiRtemplates/), in that
order.

## Installation

```r
# install.packages("pak")
pak::pak("ehrlinger/hvtiR")
```

Then, in a study's project or another renv project, install every member.
hvtiR installs only into a project's library, never your personal one, so
outside a project this stops and says which `.Rproj` to open:

```r
hvtiR::install()
```

### Set up a study

Open the study's folder as an RStudio project (File > New Project > Existing
Directory), then in that project's console:

```r
install.packages("pak")
pak::pak("ehrlinger/hvtiR")
hvtiR::setup(
  study = "EDIT: the Study Tracker title",
  study_tracker_id = 0L,  # EDIT: the Study Tracker ID
  identity_source = "manual"  # you typed the identity; the default records it as verified
)
```

For an exploration of a registered study that Study Tracker has not registered
yet, pass `derived_from = <its ID>` in place of `study_tracker_id`.
With no `_study.yml` there, `setup()` asks whether to adopt the folder; the
default answer is No. Run this once per study, before anything else. Once the
study's renv is active, rerun it from an R session started outside the
project, passing `root =`: from inside it stops before installing anything and
names the command to run, because it replaces packages that session has loaded.
It also stops the study using renv's
per-user cache, so the shared library holds real copies a teammate can read,
and reinstalls any package that was only a link into someone's home. It cleans
up template copies first and only then locks the packages, so the lockfile records what the study declares and not what the templates
happened to mention. Adopting an existing (legacy) study, by answering Yes or by passing
`adopt = TRUE` with `root =`, is what cleans up its template copies. **That deletes every `tp.*` file by name, even
an edited one, with no backup**, so rescue your own first or add `cleanup = FALSE`. A study that already has a `renv.lock`
keeps its locked versions unless the declared family needs newer ones, in which case
`setup()` moves them, lists each move and records them (`upgrade = TRUE`, the default; pass
`upgrade = FALSE` for a study in revision, whose versions must not move), and every package that lockfile recorded is declared
on first conversion, so none drop out. No personal GitHub token is needed: the packages are installed with
pak, which carries a shared token, and renv keeps the environment (lockfile,
restore, snapshot). It is safe to rerun.

Every study gets the family and a standard set of analysis packages, with no
separate install step: `tidyverse`, `haven`, `gtsummary`, `flextable`,
`survival`, `survminer`, `randomForestSRC`, `varPro` and `pacman`, plus
`arrow` for registered data, `quarto` for rendering jobs and `ggiraph` for
interactive figures. `setup()` declares them in the study's `DESCRIPTION`, so the lockfile records them. Add anything else with
`hvtiRutilities::study_need()`.

## Keeping current

```r
hvtiR::status()   # what is installed, what is available
hvtiR::update()   # install only what is missing or stale
```

When pak recorded an installed package's GitHub commit, `status()` also catches
new commits on `main` that keep the same package version. The five-column table
stays version-focused; commit provenance is used internally to decide whether
an equal-version install is current.

`hvtiR::status()` also checks `hvtiR` itself against GitHub. The installer
stays outside the member table, but the report names the available version and
`pak::pak("ehrlinger/hvtiR")` when it is behind. `hvtiR::update()` reuses the
same check; it cannot update its own loaded namespace.

On Linux and macOS, `hvtiR::update()` installs over a member you have already
attached in the session, then tells you to restart R: the session keeps the old
copy until you do. On Windows a loaded package cannot be replaced, so there it
refuses; restart R and run it again before attaching anything.

## Reproducible installs

`install()` resolves every member from GitHub `main`, so it gives you the
newest code rather than a fixed one. Two people running it a week apart can end
up on different commits under the same version number. When an analysis has to
be reproducible, pin the versions with [renv](https://rstudio.github.io/renv/):

```r
renv::init()      # once per project
hvtiR::install()  # installs into the project library
renv::snapshot()  # records every package, and each member's commit
```

`renv.lock` then names the exact commit behind each member, and

```r
renv::restore()
```

rebuilds that library on another machine. This works because pak records the
commit it installed from, which is the field renv reads.

A member installed from a local working copy rather than from GitHub carries no
such commit, so renv has none to record for it. `hvtiR::doctor()` reports
whether an renv project is active.

## When something will not install

```r
hvtiR::doctor()
```

reports your R version against the family's requirement (4.4.0 or newer),
your platform, whether `pak` is available, the package repositories R is
configured to use, whether an renv project is active, and the full member
table. It warns when a repository is a dated snapshot and names each
dependency version floor a member declares that the repositories cannot meet.
When a GitHub check fails, it also reports the repository-specific reason.

## Members

| Package | Repository |
|---|---|
| hvtiRutilities | ehrlinger/hvtiRutilities |
| hvtiRdatabuild | ehrlinger/hvtiRdatabuild |
| hvtiRtables | ehrlinger/hvtiRtables |
| hvtiRtemplates | ehrlinger/hvtiRtemplates |
| hvtiPlotR | ehrlinger/hvtiPlotR |
| hvtiRlifetables | ehrlinger/hvtiRlifetables |
| hvtiRbootstrap | ehrlinger/hvtiRbootstrap |
| hvtiRpropensity | ehrlinger/hvtiRpropensity |
| hvtiRimputation | ehrlinger/hvtiRimputation |
| ggBoostedTrees | ehrlinger/ggBoostedTrees |
| TemporalHazard | ehrlinger/TemporalHazard |
| ggRandomForests | ehrlinger/ggRandomForests |

Members install from GitHub `main` because that is where family releases land
first. CRAN is a downstream republication for members that are published
there.

A later `update.packages()` can replace a GitHub installation with an older
CRAN release. This matters especially for `TemporalHazard`:
`hvtiRlifetables` declares `Imports: TemporalHazard (>= 1.2.0)`, and R enforces
that requirement at namespace load. If a CRAN downgrade no longer satisfies
it, `hvtiRlifetables` will not load. `hvtiR::status()` will show
`TemporalHazard` as `stale`, and `hvtiR::update()` repairs it.

`hvtiEDAreports` (Python, archived 2026-08-27) and the HVTI Recipes book are not
R packages and are not members.

## Further reading

- [Reference](https://ehrlinger.github.io/hvtiR/reference/) - every function, with examples.
- [Start here](https://ehrlinger.github.io/hvtiR/articles/start-here.html) - set up a study,
  then on to the `hvtiRtemplates` tutorials.
- [Install, update and check the family](https://ehrlinger.github.io/hvtiR/articles/hvtiR.html) -
  including what to do when a member will not install.
- [Changelog](https://ehrlinger.github.io/hvtiR/news/) - what changed in each release.
- [Design records](dev/specs/) - the spec and implementation plan, kept because the reasoning
  behind the design is harder to recover than the code.
