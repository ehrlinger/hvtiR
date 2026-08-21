# Update out-of-date hvtiR members

Installs only the members whose status is `"missing"` or `"stale"`. When
everything is current, reports that and installs nothing. Members whose
version could not be checked against GitHub are reported as unchecked
rather than silently treated as current.

## Usage

``` r
update(force = FALSE)
```

## Arguments

- force:

  Bypass the loaded-namespace guard. See
  [`install()`](https://ehrlinger.github.io/hvtiR/reference/install.md).

## Value

The character vector of `"owner/repo"` specs passed to pak, invisibly.
Empty if nothing needed updating.

## Details

The target set is expanded over in-family dependencies (see
`member_deps()`) before installing, so a stale member's in-family
dependency is sent to pak alongside it even when that dependency is
already current. Without this, installing e.g. just `hvtiRlifetables`
sends pak to CRAN to resolve its `TemporalHazard` import, where the
required version may not exist.

## Examples

``` r
if (FALSE) { # \dontrun{
update()
} # }
```
