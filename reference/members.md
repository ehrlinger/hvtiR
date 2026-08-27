# Members of the hvtiR

The registry of R packages that make up the HVTI package family,
together with the GitHub repository each one installs from.

## Usage

``` r
members()
```

## Value

A data frame with one row per member and two character columns:

- package:

  The installed package name.

- repo:

  The GitHub repository, as `"owner/repo"`.

## Details

Every member's package name currently matches its repository name, but
the mapping is stored rather than derived. The two diverged until the
2026-08 renames – `hvtiRpropensity` lived in
`ehrlinger/hvtiPropensityScores` and `TemporalHazard` in
`ehrlinger/temporal_hazard` – and a derived repo would fail silently the
next time a name moves.

## Examples

``` r
members()
#>            package                      repo
#> 1   hvtiRutilities  ehrlinger/hvtiRutilities
#> 2   hvtiRdatabuild  ehrlinger/hvtiRdatabuild
#> 3      hvtiRtables     ehrlinger/hvtiRtables
#> 4   hvtiRtemplates  ehrlinger/hvtiRtemplates
#> 5        hvtiPlotR       ehrlinger/hvtiPlotR
#> 6  hvtiRlifetables ehrlinger/hvtiRlifetables
#> 7   hvtiRbootstrap  ehrlinger/hvtiRbootstrap
#> 8  hvtiRpropensity ehrlinger/hvtiRpropensity
#> 9   hvtiBoostmtree  ehrlinger/hvtiBoostmtree
#> 10  TemporalHazard  ehrlinger/TemporalHazard
#> 11 ggRandomForests ehrlinger/ggRandomForests
```
