# Version status of every hvtiR member

Compares each member installed locally against the version and, when pak
recorded its GitHub commit, the commit on the `main` branch of its
repository. The returned table remains version-focused; commit
provenance is an internal tie-breaker when versions match.

## Usage

``` r
status(remote = TRUE)
```

## Arguments

- remote:

  Consult GitHub for the latest versions? When `FALSE`, no network
  request is made, `latest` is `NA` throughout, and installed members
  report `"ok-local"`.

## Value

A data frame of class `hvtiR_status`, one row per member, with character
columns:

- package:

  The package name.

- repo:

  The GitHub repository it installs from.

- installed:

  Installed version, or `NA` if not installed.

- latest:

  Version on GitHub `main`, or `NA`.

- status:

  One of `"ok"`, `"stale"`, `"missing"`, `"ahead"`, `"unknown"` or
  `"ok-local"`. A member is also `"stale"` when its version matches
  `main` but its recorded GitHub commit does not.

## Details

The object is returned visibly and has a `print` method, so a bare call
displays the table while `st <- status()` captures the data frame for
scripting.

## Examples

``` r
# Offline: reports what is installed without contacting GitHub
status(remote = FALSE)
#> hvtiR - 11 members
#> 
#>   x hvtiRutilities   -          -          missing
#>   x hvtiRdatabuild   -          -          missing
#>   x hvtiRtables      -          -          missing
#>   x hvtiRtemplates   -          -          missing
#>   x hvtiPlotR        -          -          missing
#>   x hvtiRlifetables  -          -          missing
#>   x hvtiRbootstrap   -          -          missing
#>   x hvtiRpropensity  -          -          missing
#>   x hvtiBoostmtree   -          -          missing
#>   x TemporalHazard   -          -          missing
#>   x ggRandomForests  -          -          missing
#> 
#> ℹ 11 members need updating. Run `hvtiR::update()`.
```
