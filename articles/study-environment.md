# A study’s package environment

Six months after submission a reviewer asks about Table 2, and you need
the same numbers from the same code. Data and code are the easy part.
The packages have moved in the meantime, because the server’s library
changes whenever someone updates it, and nothing tells the projects that
use it.

So each study keeps its own library, in its own directory, with every
version written down in a lockfile. [Start
here](https://ehrlinger.github.io/hvtiR/articles/start-here.md) covers
[`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md), which
builds all of that once. This page is about living with it afterward:
adding a package, updating one, answering a revision, and fixing what
goes wrong.

## What setup leaves in the study

| File | What it is |
|----|----|
| `renv.lock` | The record: every package’s version, and each family member’s commit |
| `DESCRIPTION` | The packages the study declares. A shared file, written by [`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md), `study_need()` and `study_declare()` |
| `.Rprofile` | Starts renv when the project opens |
| `renv/settings.json` | The study’s renv settings, the shared cache setting among them |
| `renv/library/` | The installed packages |

renv runs in explicit mode in our studies. The lockfile records what
`DESCRIPTION` declares, not whatever a script happens to mention, so a
stale template copy can never put a package into it. The other side of
that bargain is that a package you install with plain
[`install.packages()`](https://rdrr.io/r/utils/install.packages.html) is
not recorded until it is declared.

The library is shared too.
[`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md) turns
off renv’s per-user cache for the study, so the library holds real
copies a teammate can read rather than links into your home directory.

## Adding a package

For a package from the configured repositories, run this in the open
project. It asks first, then installs the package, declares it and
records it:

``` r

hvtiRutilities::study_need("cmprsk")
```

A package that is already installed is only declared, not recorded, so
follow `study_need()` with
[`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html)
in that case.

A package from GitHub takes three steps:

``` r

renv::install("org/repo")
hvtiRutilities::study_declare("repo")
renv::snapshot()
```

Run these in the console and keep them out of your jobs. Re-running a
job should never install anything or change its environment.

## Updating packages

An update is a decision about one study, so make it on purpose and
record it. For one package:

``` r

renv::update("name")
renv::snapshot()
```

For the family, from a fresh session in the project, before anything
attaches a member:

``` r

hvtiR::update()
renv::snapshot()
```

If the snapshot aborts over a missing dependency, pak has probably
skipped a build-time (`LinkingTo`) package. Install the one it names
with
[`renv::install()`](https://rstudio.github.io/renv/reference/install.html)
and run the snapshot again. Do not rerun
[`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md) for
this: it restores the old lockfile first, so it can undo the update you
have not yet recorded.

To see whether the library and the lockfile agree, use
[`renv::status()`](https://rstudio.github.io/renv/reference/status.html).

## Bringing an active study on

The command is the one [Start
here](https://ehrlinger.github.io/hvtiR/articles/start-here.md) gives,
with `adopt = TRUE`. Two courtesies come first on a study other people
are working in. If it already has a `renv.lock`, ask its owner before
you run
[`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md). And
warn the team, because
[`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md)
changes the library their sessions load from; they should close those
sessions first.

A lockfile the study already has is kept.
[`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md)
restores the locked versions, declares every package the lockfile
recorded and installs only what is missing. The exception is a locked
version the family needs newer: by default
[`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md) moves
it, lists the move and records it. If the owner needs those pins held,
pass `upgrade = FALSE`, and the run stops rather than moves them. Do not
run [`renv::init()`](https://rstudio.github.io/renv/reference/init.html)
on such a study, which starts its library over.

## Answering a revision

Open the project, on the R version the lockfile records, then rebuild
the library the study was submitted with and check it:

``` r

renv::restore()
renv::status()
```

Then render the job as usual. If you need
[`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md) on a
study in revision, pass `upgrade = FALSE`, so that a package the install
would move stops the run.

⚠️
**[`hvtiR::status()`](https://ehrlinger.github.io/hvtiR/reference/status.md)
does not check the lockfile.** It compares what is installed with GitHub
`main`, so a study held on its submitted versions is expected to show
members as `stale`. That is the lockfile doing its job.
[`renv::status()`](https://rstudio.github.io/renv/reference/status.html)
is the check that matters here, and running
[`hvtiR::update()`](https://ehrlinger.github.io/hvtiR/reference/update.md)
to clear the report would move the very versions you are protecting.

## How the family is pinned

The family installs from GitHub `main`, so two people installing a week
apart can land on different commits under one version number. The
lockfile is what fixes that, because pak records the commit it installed
from and renv reads that field:

``` json
"hvtiPlotR": {
  "Package": "hvtiPlotR",
  "Version": "2.8.6",
  "RemoteUsername": "ehrlinger",
  "RemoteRepo": "hvtiPlotR",
  "RemoteSha": "a4f3c9d8..."
}
```

[`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
then brings each member back at that commit, with no install steps of
your own.

## Common problems

| Problem | Fix |
|----|----|
| [`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md) stops before installing and prints a command | You ran it inside a project whose renv is active. Close the project, then run the printed command from outside it |
| [`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md) says no study encloses the folder | Open the study’s folder itself as the RStudio project, not one of its subfolders, and run [`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md) there; or pass `root` |
| “Could not solve package dependencies” | Run [`hvtiR::doctor()`](https://ehrlinger.github.io/hvtiR/reference/doctor.md). It lists the repositories R uses, warns on a dated snapshot and names any version floor they cannot meet |
| [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html) fails on a package that is not on CRAN | Look for `RemoteRepo` in `renv.lock`. A package pinned on GitHub may need your own `GITHUB_PAT` |
| [`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md) warns that the study is set up without some packages | They would not install, and jobs that load them stop. [`hvtiR::doctor()`](https://ehrlinger.github.io/hvtiR/reference/doctor.md) lists them and why; the logs are in `renv/logs/` and the record is `renv/hvtiR-setup.dcf`. Rerun [`hvtiR::setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md) to try them again, or install one by hand in the study and run [`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html). A family member that will not install stops [`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md) instead. The lockfile as it was is in `renv/renv.lock.before-setup-<time>` |
| An install fails reading a package in someone’s home directory | The library holds links into a per-user cache. Rerun [`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md) for the study: it turns the cache off and replaces the links with real copies |
| A package is installed but not in `renv.lock` | It is not declared. Run `hvtiRutilities::study_declare("name")`, then [`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html) |
| `renv.lock` is behind the library | [`renv::status()`](https://rstudio.github.io/renv/reference/status.html) shows the drift, and [`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html) records it once you have checked that it is what you meant |
| A teammate’s session errors just after setup | They had the project open while the library changed. Restart the session |
