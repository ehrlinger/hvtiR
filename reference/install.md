# Install every hvtiR member

Installs all members from GitHub `main`, whether or not they are already
present. This is the command for a project with nothing installed yet;
use [`update()`](https://ehrlinger.github.io/hvtiR/reference/update.md)
to install only what is missing or out of date.

## Usage

``` r
install(force = FALSE)
```

## Arguments

- force:

  Bypass the loaded-namespace guard. A package whose namespace is loaded
  cannot be safely overwritten; on Windows the write fails and leaves a
  broken library. Unsafe: restart R instead.

## Value

The character vector of `"owner/repo"` specs passed to pak, invisibly.

## Details

It installs only into a project's library: a study's, or another renv
project's. In a session whose library is your personal one it stops
before installing anything and says what to do: open the study's
`.Rproj`, or, in a study or project folder with no renv library yet, run
[`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md) there.

Any renv project counts, so to try the family without a study, install
into a new scratch project.
[`dir.create()`](https://rdrr.io/r/base/files2.html) refuses a folder
that already exists, so the project never lands in one that holds other
files. `restart = FALSE` and
[`renv::load()`](https://rstudio.github.io/renv/reference/load.html)
activate it in this session, whatever the front end:

    dir <- file.path(
      path.expand("~"),
      paste0("hvtiR-scratch-", format(Sys.time(), "%Y%m%d-%H%M%S"))
    )
    stopifnot(dir.create(dir))
    renv::init(dir, bare = TRUE, restart = FALSE)
    renv::load(dir)
    renv::install(c("pak", "ehrlinger/hvtiR"))
    hvtiR::install()

Members are installed from GitHub rather than CRAN because GitHub is
where family releases land first. CRAN is a downstream republication for
members that are published there.

## Examples

``` r
if (FALSE) { # \dontrun{
install()
} # }
```
