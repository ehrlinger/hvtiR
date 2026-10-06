# Update out-of-date hvtiR members

Installs only the members whose status is `"missing"` or `"stale"`. When
everything is current, reports that and installs nothing. Members whose
version or commit could not be checked against GitHub are reported as
unchecked rather than silently treated as current.

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
Empty if nothing needed updating. If loaded members prevent
installation, the empty vector has a `blocked` attribute with their
names.

## Details

The target set is expanded over in-family dependencies (see
`member_deps()`) before installing, so a stale member's in-family
dependency is sent to pak alongside it even when that dependency is
already current. Without this, installing e.g. just `hvtiRlifetables`
sends pak to CRAN to resolve its `TemporalHazard` import, where the
required version may not exist.

`hvtiR` itself is checked by
[`status()`](https://ehrlinger.github.io/hvtiR/reference/status.md) and
reported here, but never installed. `update()` reuses that check;
calling it means the installer's namespace is already loaded, so it
cannot update itself. When the installer is behind, the report names
`pak::pak("ehrlinger/hvtiR")` as the remedy.

If a required member is already loaded, `update()` warns and installs
nothing. Restart R and run `update()` before those packages attach. The
returned empty character vector carries a `blocked` attribute listing
the loaded members, so callers can distinguish this from an up-to-date
result.

## Examples

``` r
if (FALSE) { # \dontrun{
update()
} # }
```
