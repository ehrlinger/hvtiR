# Diagnose an hvtiR installation

Reports the running R version against the strictest requirement in the
package family, whether `pak` is installed, the platform, and then the
full member status table. When a remote check fails, reports the reason
retained by
[`status()`](https://ehrlinger.github.io/hvtiR/reference/status.md).
This is the report to run first when a member will not install.

## Usage

``` r
doctor(remote = TRUE)
```

## Arguments

- remote:

  Consult GitHub for the latest versions? Passed through to
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
#> ✔ R version 4.6.1 (>= 4.4.0 required)
#> ℹ Platform x86_64-pc-linux-gnu
#> ✔ pak is installed
#> ℹ renv is not installed
#> ℹ Member versions are not pinned - installs resolve from GitHub "main".
#> 
#> ── Members ──
#> 
#> hvtiR - 11 members
#> 
#>   x hvtiRutilities   -          -          missing
#>   x hvtiRdatabuild   -          -          missing
#>   x hvtiRtables      -          -          missing
#>   x hvtiRtemplates   -          -          missing
#>   - hvtiPlotR        2.7.12     -          ok-local
#>   x hvtiRlifetables  -          -          missing
#>   x hvtiRbootstrap   -          -          missing
#>   x hvtiRpropensity  -          -          missing
#>   - ggBoostedTrees   0.0.6      -          ok-local
#>   x TemporalHazard   -          -          missing
#>   - ggRandomForests  4.0.0      -          ok-local
#> 
#> ℹ 8 members need updating. Run `hvtiR::update()`.
```
