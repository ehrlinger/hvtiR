# Install every hvtiR member

Installs all members from GitHub `main`, whether or not they are already
present. This is the fresh-machine command; use
[`update()`](https://ehrlinger.github.io/hvtiR/reference/update.md) to
install only what is missing or out of date.

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

Members are installed from GitHub rather than CRAN so that releases held
behind the CRAN queue remain available.

## Examples

``` r
if (FALSE) { # \dontrun{
install()
} # }
```
