# Diagnose an hvtiR installation

Reports the running R version against the strictest requirement in the
package family, whether `pak` is installed, the platform, the configured
package repositories (warning when one is a dated snapshot), and then
the full member status table. When a remote check fails, reports the
reason retained by
[`status()`](https://ehrlinger.github.io/hvtiR/reference/status.md).
With `remote`, it also reads each member's `DESCRIPTION` from GitHub and
names every dependency floor the repositories cannot meet, such as
`varPro (>= 3.3.0)` against a snapshot that predates it. It also names
any installed member whose dependency is missing from the library path,
and warns when the study's `renv.lock` was made under a different R
version than the running one. This is the report to run first when a
member will not install.

## Usage

``` r
doctor(remote = TRUE)
```

## Arguments

- remote:

  Consult GitHub for the latest versions, and the configured
  repositories for the dependencies members need? Passed through to
  [`status()`](https://ehrlinger.github.io/hvtiR/reference/status.md).

## Value

The [`status()`](https://ehrlinger.github.io/hvtiR/reference/status.md)
data frame, invisibly. Called for the report it prints.

## Examples

``` r
# Offline: environment checks plus what is installed
doctor(remote = FALSE)
#> 
#> ── hvtiR doctor ────────────────────────────────────────────────────────────────
#> 
#> ── Environment ──
#> 
#> ℹ hvtiR 1.3.4
#> ✔ R version 4.6.2 (>= 4.4.0 required)
#> ℹ Platform x86_64-pc-linux-gnu
#> ✔ pak is installed
#> ℹ Repository RSPM: <https://packagemanager.posit.co/cran/__linux__/noble/latest>
#> ℹ Repository CRAN: <https://cran.rstudio.com>
#> ℹ renv is not installed
#> ℹ Member versions are not pinned - installs resolve from GitHub "main".
#> 
#> ── Members ──
#> 
#> hvtiR 1.3.4 - 12 members
#> 
#>   x hvtiRutilities   -          -          missing
#>   x hvtiRdatabuild   -          -          missing
#>   x hvtiRtables      -          -          missing
#>   x hvtiRtemplates   -          -          missing
#>   x hvtiPlotR        -          -          missing
#>   x hvtiRlifetables  -          -          missing
#>   x hvtiRbootstrap   -          -          missing
#>   x hvtiRpropensity  -          -          missing
#>   x hvtiRimputation  -          -          missing
#>   x ggBoostedTrees   -          -          missing
#>   x TemporalHazard   -          -          missing
#>   x ggRandomForests  -          -          missing
#> 
#> ℹ 12 members need updating. Run `hvtiR::update()`.
```
