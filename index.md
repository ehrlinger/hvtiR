# hvtiR

![R package
version](https://img.shields.io/github/r-package/v/ehrlinger/hvtiR)![R-CMD-check
status](https://img.shields.io/github/actions/workflow/status/ehrlinger/hvtiR/R-CMD-check.yaml)![pkgdown
site
status](https://img.shields.io/github/actions/workflow/status/ehrlinger/hvtiR/pkgdown.yaml?label=pkgdown)

One command to install the HVTI R package family, and one command to say
whether you are current.

**Documentation:** <https://ehrlinger.github.io/hvtiR/>

## Installation

``` r

# install.packages("pak")
pak::pak("ehrlinger/hvtiR")
```

Then install every member:

``` r

hvtiR::install()
```

## Keeping current

``` r

hvtiR::status()   # what is installed, what is available
hvtiR::update()   # install only what is missing or stale
```

[`hvtiR::update()`](https://ehrlinger.github.io/hvtiR/reference/update.md)
will refuse to overwrite a member you have already attached in the
session, because a loaded package cannot be safely replaced. Restart R
and run it again before attaching anything.

## When something will not install

``` r

hvtiR::doctor()
```

reports your R version against the family’s requirement (4.4.0 or
newer), your platform, whether `pak` is available, and the full member
table. When a GitHub check fails, it also reports the
repository-specific reason.

## Members

| Package         | Repository                     |
|-----------------|--------------------------------|
| hvtiRutilities  | ehrlinger/hvtiRutilities       |
| hvtiRdatasets   | ehrlinger/hvtiRdatasets        |
| hvtiRtables     | ehrlinger/hvtiRtables          |
| hvtiRtemplates  | ehrlinger/hvtiRtemplates       |
| hvtiPlotR       | ehrlinger/hvtiPlotR            |
| hvtiRlifetables | ehrlinger/hvtiRlifetables      |
| hvtiRbootstrap  | ehrlinger/hvtiRbootstrap       |
| hvtiRpropensity | ehrlinger/hvtiPropensityScores |
| hvtiBoostmtree  | ehrlinger/hvtiBoostmtree       |
| TemporalHazard  | ehrlinger/temporal_hazard      |
| ggRandomForests | ehrlinger/ggRandomForests      |

Members install from GitHub `main` because that is where family releases
land first. CRAN is a downstream republication for members that are
published there.

A later
[`update.packages()`](https://rdrr.io/r/utils/update.packages.html) can
replace a GitHub installation with an older CRAN release. This matters
especially for `TemporalHazard`: `hvtiRlifetables` declares
`Imports: TemporalHazard (>= 1.2.0)`, and R enforces that requirement at
namespace load. If a CRAN downgrade no longer satisfies it,
`hvtiRlifetables` will not load.
[`hvtiR::status()`](https://ehrlinger.github.io/hvtiR/reference/status.md)
will show `TemporalHazard` as `stale`, and
[`hvtiR::update()`](https://ehrlinger.github.io/hvtiR/reference/update.md)
repairs it.

`hvtiEDAreports` (Python) and the HVTI Recipes book are not R packages
and are not members.

## Further reading

- [Reference](https://ehrlinger.github.io/hvtiR/reference/) - every
  function, with examples.
- [Getting
  started](https://ehrlinger.github.io/hvtiR/articles/hvtiR.html) - the
  vignette, including what to do when a member will not install.
- [Changelog](https://ehrlinger.github.io/hvtiR/news/) - what changed in
  each release.
- [Design records](https://ehrlinger.github.io/hvtiR/design/) - the spec
  and implementation plan, kept because the reasoning behind the design
  is harder to recover than the code.
