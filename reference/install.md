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
before installing anything and names the `.Rproj` to open. A new study
starts with
[`setup()`](https://ehrlinger.github.io/hvtiR/reference/setup.md)
instead, run outside any project.

Members are installed from GitHub rather than CRAN because GitHub is
where family releases land first. CRAN is a downstream republication for
members that are published there.

## Examples

``` r
if (FALSE) { # \dontrun{
install()
} # }
```
