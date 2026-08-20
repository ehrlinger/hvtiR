# Diagnose an hvtiverse installation

Reports the running R version against the strictest requirement in the
package family, the platform, and then the full member status table.
This is the report to run first when a member will not install.

## Usage

``` r
hvtiverse_doctor(remote = TRUE)
```

## Arguments

- remote:

  Consult GitHub for the latest versions? Passed through to
  [`hvtiverse_status()`](https://ehrlinger.github.io/hvtiverse/reference/hvtiverse_status.md).

## Value

The
[`hvtiverse_status()`](https://ehrlinger.github.io/hvtiverse/reference/hvtiverse_status.md)
data frame, invisibly. Called for the report it prints.

## Examples

``` r
# Offline: environment checks plus what is installed
hvtiverse_doctor(remote = FALSE)
#> 
#> ── hvtiverse doctor ────────────────────────────────────────────────────────────
#> 
#> ── Environment ──
#> 
#> ✔ R version 4.6.1 (>= 4.4.0 required)
#> ℹ Platform x86_64-pc-linux-gnu
#> 
#> ── Members ──
#> 
#> hvtiverse - 11 members
#> 
#>   x hvtiRutilities   -          -          missing
#>   x hvtiRdatasets    -          -          missing
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
#> ℹ 11 members need updating. Run `hvtiverse::hvtiverse_update()`.
```
