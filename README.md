# hvtiverse

<!-- badges: start -->
![](https://img.shields.io/github/r-package/v/ehrlinger/hvtiverse)
![](https://img.shields.io/github/actions/workflow/status/ehrlinger/hvtiverse/R-CMD-check.yaml)
<!-- badges: end -->

One command to install the HVTI R package family, and one command to say
whether you are current.

## Installation

```r
# install.packages("pak")
pak::pak("ehrlinger/hvtiverse")
```

Then install every member:

```r
hvtiverse::hvtiverse_install()
```

## Keeping current

```r
library(hvtiverse)

hvtiverse_status()   # what is installed, what is available
hvtiverse_update()   # install only what is missing or stale
```

`hvtiverse_update()` will refuse to overwrite a member you have already
attached in the session, because a loaded package cannot be safely replaced.
Restart R and run it again before attaching anything.

## When something will not install

```r
hvtiverse_doctor()
```

reports your R version against the family's requirement (4.4.0 or newer),
your platform, and the full member table.

## Members

| Package | Repository |
|---|---|
| hvtiRutilities | ehrlinger/hvtiRutilities |
| hvtiRdatasets | ehrlinger/hvtiRdatasets |
| hvtiRtables | ehrlinger/hvtiRtables |
| hvtiRtemplates | ehrlinger/hvtiRtemplates |
| hvtiPlotR | ehrlinger/hvtiPlotR |
| hvtiRlifetables | ehrlinger/hvtiRlifetables |
| hvtiRbootstrap | ehrlinger/hvtiRbootstrap |
| hvtiRpropensity | ehrlinger/hvtiPropensityScores |
| hvtiBoostmtree | ehrlinger/hvtiBoostmtree |
| TemporalHazard | ehrlinger/temporal_hazard |
| ggRandomForests | ehrlinger/ggRandomForests |

Members install from GitHub rather than CRAN, so releases waiting in the CRAN
queue are still available to the group. One consequence: a later
`update.packages()` can downgrade `ggRandomForests` to its CRAN version. Run
`hvtiverse_status()` if a version looks wrong.

`hvtiEDAreports` (Python) and the HVTI Recipes book are not R packages and are
not members.
