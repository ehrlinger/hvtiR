# Getting Started with hvtiR

## The problem

The HVTI R package family is eleven packages spread across eleven GitHub
repositories. Setting up a machine used to mean eleven
[`pak::pak()`](https://pak.r-lib.org/reference/pak.html) calls, in an
order you had to know, against repository names that do not always match
the package names — `TemporalHazard` lives in
`ehrlinger/temporal_hazard`, and `hvtiRpropensity` lives in
`ehrlinger/hvtiPropensityScores`.

`hvtiR` reduces that to one call, and adds a way to ask whether you are
current.

## The members

The registry is the package’s only piece of data. It maps each package
to the repository it installs from:

``` r

hvtiR::members()
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

## What you have

[`hvtiR::status()`](https://ehrlinger.github.io/hvtiR/reference/status.md)
compares what is installed against what is on each repository’s `main`
branch. When pak recorded the installed GitHub commit, the comparison
catches new commits even when the package version did not change:

``` r

hvtiR::status()
```

    hvtiR - 11 members

      v hvtiRutilities   1.0.10     1.0.10     ok
      v hvtiRdatasets    0.1.1      0.1.1      ok
      ! hvtiRtables      0.9.0      1.0.0      stale
      x hvtiPlotR        -          2.7.6      missing
      ...

    i 2 members need updating. Run hvtiR::update().

The status column takes one of six values:

| Status     | Meaning                                           |
|------------|---------------------------------------------------|
| `ok`       | installed version and recorded commit are current |
| `stale`    | installed version or recorded commit is behind    |
| `missing`  | not installed                                     |
| `ahead`    | you have a local development build                |
| `unknown`  | GitHub could not be reached                       |
| `ok-local` | installed; the remote was not consulted           |

Packages installed without GitHub commit provenance fall back to the
version comparison. The table stays version-focused; commit SHAs are
used internally only to resolve a tie between equal versions.

The object is a plain data frame underneath, so you can use it in a
script:

``` r

st <- hvtiR::status()
st$package[st$status == "stale"]
```

On a machine with no outbound network, skip the remote entirely:

``` r

hvtiR::status(remote = FALSE)
```

    hvtiR - 11 members

      - hvtiRutilities   1.0.10     -          ok-local
      - hvtiRdatasets    0.1.1      -          ok-local
      - hvtiRtables      1.0.0      -          ok-local
      - hvtiRtemplates   1.0.0      -          ok-local
      - hvtiPlotR        2.7.6      -          ok-local
      - hvtiRlifetables  1.3.0      -          ok-local
      - hvtiRbootstrap   0.2.0      -          ok-local
      - hvtiRpropensity  1.1.0      -          ok-local
      - hvtiBoostmtree   2.0.1      -          ok-local
      - TemporalHazard   1.2.0      -          ok-local
      - ggRandomForests  3.5.1      -          ok-local

    i Remote was not consulted; versions shown are installed versions only.

## Installing and updating

On a new machine, install everything:

``` r

hvtiR::install()
```

Thereafter, install only what has fallen behind:

``` r

hvtiR::update()
```

### Why it may refuse

[`hvtiR::update()`](https://ehrlinger.github.io/hvtiR/reference/update.md)
stops if a member you are about to update is already attached in the
session:

    Error: Cannot install hvtiPlotR: already loaded in this session.
    i Restart R and run this before anything attaches it.
    i Pass `force = TRUE` to install anyway (unsafe on Windows).

This is not fussiness. A package whose namespace is loaded cannot be
safely overwritten — on Windows the write fails outright and leaves a
half-installed library. Restart R and run the update before you attach
anything.

## When something will not install

``` r

hvtiR::doctor()
```

The doctor adds two environment checks ahead of the status table: your R
version against the family’s strictest requirement, and your platform.

`ggRandomForests` and `hvtiRlifetables` both need R 4.4.0 or newer,
which is the single most common reason a member will not install. Note
that `hvtiR` itself requires only R 4.1.0 — deliberately, so that the
diagnostic still runs on a machine whose R is too old for the members it
is reporting on.

## Why GitHub and not CRAN

Every member installs from GitHub `main`, including `ggRandomForests`,
which is also published on CRAN.

Development flows from the family repositories to CRAN, not the other
way around. GitHub `main` is therefore the leading release source, while
CRAN is a downstream republication for members that are published there.

One consequence is worth knowing: because `ggRandomForests` came from
GitHub, a later
[`update.packages()`](https://rdrr.io/r/utils/update.packages.html) can
quietly downgrade it to the CRAN version. If a version looks wrong, run
[`hvtiR::status()`](https://ehrlinger.github.io/hvtiR/reference/status.md).

The same replacement can happen to `TemporalHazard`, and there it may
not be harmless. `hvtiRlifetables` requires `TemporalHazard (>= 1.2.0)`
in its `Imports:` field, a requirement R enforces when the namespace
loads. If a CRAN downgrade no longer satisfies that requirement,
`hvtiRlifetables` will not load until
[`hvtiR::update()`](https://ehrlinger.github.io/hvtiR/reference/update.md)
puts the GitHub release back.
