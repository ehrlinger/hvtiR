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
branch:

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

| Status     | Meaning                                 |
|------------|-----------------------------------------|
| `ok`       | installed version equals the latest     |
| `stale`    | installed version is behind             |
| `missing`  | not installed                           |
| `ahead`    | you have a local development build      |
| `unknown`  | GitHub could not be reached             |
| `ok-local` | installed; the remote was not consulted |

The object is a plain data frame underneath, so you can use it in a
script:

``` r

st <- hvtiR::status()
st$package[st$status == "stale"]
```

On a machine with no outbound network, skip the remote entirely:

``` r

status(remote = FALSE)
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

The reason is that a finished release is not the same as an available
one. In August 2026, `TemporalHazard` 1.2.0 and `ggRandomForests` 3.5.1
were both complete but waiting on the CRAN queue, and `hvtiRlifetables`
requires `TemporalHazard (>= 1.2.0)`. Installing from GitHub delivered
those releases to the group immediately.

One consequence is worth knowing: because `ggRandomForests` came from
GitHub, a later
[`update.packages()`](https://rdrr.io/r/utils/update.packages.html) can
quietly downgrade it to the CRAN version. If a version looks wrong, run
[`hvtiR::status()`](https://ehrlinger.github.io/hvtiR/reference/status.md).

The same downgrade can happen to `TemporalHazard`, which is also on CRAN
(1.1.0, versus 1.2.0 on GitHub) — and there it is not harmless.
[`hvtiR::status()`](https://ehrlinger.github.io/hvtiR/reference/status.md)
would show `TemporalHazard` as `stale`, and `hvtiRlifetables` requires
`TemporalHazard (>= 1.2.0)` in its `Imports:` field, a requirement R
enforces when the namespace loads. A downgraded `TemporalHazard` leaves
`hvtiRlifetables` unloadable, not just out of date, until
[`hvtiR::update()`](https://ehrlinger.github.io/hvtiR/reference/update.md)
puts `TemporalHazard` back.
