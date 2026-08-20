# Members of the hvtiverse

The registry of R packages that make up the HVTI package family,
together with the GitHub repository each one installs from.

## Usage

``` r
hvtiverse_members()
```

## Value

A data frame with one row per member and two character columns:

- package:

  The installed package name.

- repo:

  The GitHub repository, as `"owner/repo"`.

## Details

Two members carry a package name that differs from their repository
name: `hvtiRpropensity` lives in `ehrlinger/hvtiPropensityScores`, and
`TemporalHazard` lives in `ehrlinger/temporal_hazard`. The mapping is
therefore stored rather than derived.

## Examples

``` r
hvtiverse_members()
#>            package                           repo
#> 1   hvtiRutilities       ehrlinger/hvtiRutilities
#> 2    hvtiRdatasets        ehrlinger/hvtiRdatasets
#> 3      hvtiRtables          ehrlinger/hvtiRtables
#> 4   hvtiRtemplates       ehrlinger/hvtiRtemplates
#> 5        hvtiPlotR            ehrlinger/hvtiPlotR
#> 6  hvtiRlifetables      ehrlinger/hvtiRlifetables
#> 7   hvtiRbootstrap       ehrlinger/hvtiRbootstrap
#> 8  hvtiRpropensity ehrlinger/hvtiPropensityScores
#> 9   hvtiBoostmtree       ehrlinger/hvtiBoostmtree
#> 10  TemporalHazard      ehrlinger/temporal_hazard
#> 11 ggRandomForests      ehrlinger/ggRandomForests
```
