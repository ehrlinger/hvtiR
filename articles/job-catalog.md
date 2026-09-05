# The job catalog

Every job type found in the studies corpus, and the package that owes
it. Counts are SAS templates found and R jobs already written. This page
is generated from the catalog shipped with the package, so it cannot
disagree with it.

| disposition | rows |
|:------------|-----:|
| build       |    7 |
| retire      |    5 |
| scaffold    |   32 |
| thin        |    9 |

## distributions

| job | name | SAS | R | disposition | status | destination | replaced by | blocked on |
|:---|:---|---:|---:|:---|:---|:---|:---|:---|
| `ac` | Actuarial | 756 | 20 | scaffold | shipped | hvtiRtemplates |  |  |
| `cd` | Cumulative distribution | 202 | 8 | scaffold | queued | hvtiRtemplates |  |  |
| `hz` | Hazard fit | 581 | 8 | scaffold | shipped | hvtiRtemplates |  |  |
| `nd` | Nonparametric distributions | 244 | 12 | scaffold | queued | hvtiRtemplates |  |  |
| `dp-variable` | Distribution of a variable | NA | NA | scaffold | queued | hvtiRtemplates |  |  |

## documents

| job | name | SAS | R | disposition | status | destination | replaced by | blocked on |
|:---|:---|---:|---:|:---|:---|:---|:---|:---|
| `ar` | Analysis report | 706 | 1114 | scaffold | queued | hvtiRtemplates |  |  |

## analyses

| job | name | SAS | R | disposition | status | destination | replaced by | blocked on |
|:---|:---|---:|---:|:---|:---|:---|:---|:---|
| `bc` | Bootstrap Cox | 16 | 0 | scaffold | shipped | hvtiRtemplates |  |  |
| `bh` | Bootstrap hazard | 322 | 5 | scaffold | shipped | hvtiRtemplates |  |  |
| `bl` | Bootstrap logistic | 352 | 1 | scaffold | shipped | hvtiRtemplates |  |  |
| `bn` | Bootstrap nonparametric | 214 | 0 | scaffold | queued | hvtiRtemplates |  |  |
| `bq` | Bootstrap quantile | 2 | 0 | scaffold | queued | hvtiRtemplates |  | hvtiRbootstrap#16 |
| `br` | Bootstrap regression | 103 | 1 | scaffold | shipped | hvtiRtemplates |  |  |
| `cm` | Cox matching | 35 | 2 | scaffold | queued | hvtiRtemplates |  |  |
| `gm` | Generalized model | 77 | 0 | scaffold | queued | hvtiRtemplates |  |  |
| `hm` | Hazard model | 383 | 9 | scaffold | shipped | hvtiRtemplates |  |  |
| `lm` | Logistic model | 621 | 45 | scaffold | queued | hvtiRtemplates |  |  |
| `ls` | Life table / STS | 34 | 0 | scaffold | queued | hvtiRtemplates |  |  |
| `mm` | Mixed model | 59 | 1 | scaffold | queued | hvtiRtemplates |  |  |
| `nb` | Notebook | 21 | 63 | build | NA | ggBoostedTrees |  | ggBoostedTrees#9 |
| `nm` | Nonparametric model | 122 | 1 | scaffold | queued | hvtiRtemplates |  |  |
| `pm` | Propensity model | 5 | 0 | scaffold | queued | hvtiRtemplates |  |  |
| `rf` | Random forest | 47 | 312 | retire | NA | ggRandomForests | [`ggRandomForests::gg_rfsrc`](https://ehrlinger.github.io/ggRandomForests/reference/gg_rfsrc.rfsrc.html), [`ggRandomForests::gg_error`](https://ehrlinger.github.io/ggRandomForests/reference/gg_error.html), [`ggRandomForests::gg_vimp`](https://ehrlinger.github.io/ggRandomForests/reference/gg_vimp.html), [`ggRandomForests::gg_variable`](https://ehrlinger.github.io/ggRandomForests/reference/gg_variable.html) |  |
| `rfc` | Random forest classifier | 19 | 52 | retire | NA | ggRandomForests | [`ggRandomForests::gg_roc`](https://ehrlinger.github.io/ggRandomForests/reference/gg_roc.rfsrc.html), [`ggRandomForests::gg_brier`](https://ehrlinger.github.io/ggRandomForests/reference/gg_brier.html), [`ggRandomForests::gg_error`](https://ehrlinger.github.io/ggRandomForests/reference/gg_error.html), [`ggRandomForests::calc_auc`](https://ehrlinger.github.io/ggRandomForests/reference/calc_auc.html) |  |
| `rfs` | Random forest survival | 25 | 39 | retire | NA | ggRandomForests | [`ggRandomForests::gg_rfsrc`](https://ehrlinger.github.io/ggRandomForests/reference/gg_rfsrc.rfsrc.html), [`ggRandomForests::gg_survival`](https://ehrlinger.github.io/ggRandomForests/reference/gg_survival.html), [`ggRandomForests::gg_error`](https://ehrlinger.github.io/ggRandomForests/reference/gg_error.html), [`ggRandomForests::gg_vimp`](https://ehrlinger.github.io/ggRandomForests/reference/gg_vimp.html) |  |
| `rfsrc` | Random forest (SRC) | 131 | 631 | retire | NA | ggRandomForests | [`ggRandomForests::gg_rfsrc`](https://ehrlinger.github.io/ggRandomForests/reference/gg_rfsrc.rfsrc.html), [`ggRandomForests::gg_survival`](https://ehrlinger.github.io/ggRandomForests/reference/gg_survival.html), [`ggRandomForests::gg_error`](https://ehrlinger.github.io/ggRandomForests/reference/gg_error.html), [`ggRandomForests::gg_vimp`](https://ehrlinger.github.io/ggRandomForests/reference/gg_vimp.html), [`ggRandomForests::gg_partial`](https://ehrlinger.github.io/ggRandomForests/reference/gg_partial.html) |  |
| `rm` | Regression model | 174 | 94 | scaffold | queued | hvtiRtemplates |  |  |
| `rfr` | Random forest regression | NA | NA | retire | intake | ggRandomForests | [`ggRandomForests::gg_rfsrc`](https://ehrlinger.github.io/ggRandomForests/reference/gg_rfsrc.rfsrc.html), [`ggRandomForests::gg_vimp`](https://ehrlinger.github.io/ggRandomForests/reference/gg_vimp.html), [`ggRandomForests::gg_shap`](https://ehrlinger.github.io/ggRandomForests/reference/gg_shap.html) | hvtiRutilities#taxonomy |
| `sid` | Random forest clustering (sidClustering) | NA | NA | build | intake | ggRandomForests |  | hvtiRutilities#taxonomy |
| `vt` | Virtual twins | NA | NA | build | intake | ggRandomForests |  | hvtiRutilities#taxonomy |

## datasets

| job | name | SAS | R | disposition | status | destination | replaced by | blocked on |
|:---|:---|---:|---:|:---|:---|:---|:---|:---|
| `bd` | Build | 1134 | 18 | scaffold | queued | hvtiRtemplates |  | hvtiRdatabuild |
| `dt` | Data check | 512 | 0 | scaffold | queued | hvtiRtemplates |  | hvtiRdatabuild |
| `vars` | Variables | 959 | 2 | scaffold | queued | hvtiRtemplates |  | hvtiRdatabuild |

## graphs

| job | name | SAS | R | disposition | status | destination | replaced by | blocked on |
|:---|:---|---:|---:|:---|:---|:---|:---|:---|
| `ce` | Competing events | 131 | 1 | build | NA | hvtiPlotR |  | hvtiPlotR#134 |
| `cp` | Cumulative probability plot | 5 | 1 | build | NA | hvtiPlotR |  | hvtiPlotR#135 |
| `fp` | Forest plot | 19 | 20 | build | NA | hvtiPlotR |  | hvtiPlotR#133 |
| `gp` | Generalized model plot | 50 | 2 | build | NA | hvtiPlotR |  | hvtiPlotR#136 |
| `hp` | Hazard plot | 557 | 24 | thin | revisit | hvtiRtemplates | [`hvtiPlotR::hv_hazard`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_hazard.html), [`hvtiPlotR::hazard_plot`](https://ehrlinger.github.io/hvtiPlotR/reference/hazard_plot.html), [`hvtiPlotR::hv_survival`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_survival.html), [`hvtiPlotR::hv_atrisk_compose`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_atrisk_compose.html) |  |
| `hs` | Hazard setup | 144 | 11 | scaffold | shipped | hvtiRtemplates |  |  |
| `lp` | Logistic plot | 636 | 606 | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_mirror_hist`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_mirror_hist.html) |  |
| `mp` | Mixed model plot | 82 | 5 | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_spaghetti`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_spaghetti.html) |  |
| `np` | Nonparametric plot | 248 | 201 | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_nonparametric`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_nonparametric.html), [`hvtiPlotR::hv_ordinal`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_ordinal.html) |  |
| `rp` | Regression plot | 76 | 8 | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_balance`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_balance.html) |  |
| `dp-trends` | Descriptive plot: trends | NA | NA | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_trends`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_trends.html) |  |
| `dp-gfup` | Descriptive plot: follow-up | NA | NA | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_followup`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_followup.html) |  |
| `dp-spaghetti` | Descriptive plot: spaghetti | NA | NA | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_spaghetti`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_spaghetti.html) |  |
| `dp-procs` | Descriptive plot: procedures over time | NA | NA | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_longitudinal`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_longitudinal.html), [`hvtiPlotR::hv_stacked`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_stacked.html) |  |

## descriptive

| job | name | SAS | R | disposition | status | destination | replaced by | blocked on |
|:---|:---|---:|---:|:---|:---|:---|:---|:---|
| `lg` | Logit trends | 367 | 0 | scaffold | queued | hvtiRtemplates |  |  |
| `rg` | Regression trends | 45 | 0 | scaffold | queued | hvtiRtemplates |  |  |
| `dc-general` | Descriptive: general | NA | NA | scaffold | queued | hvtiRtemplates |  |  |
| `dc-tables` | Descriptive: formatted tables | NA | NA | scaffold | queued | hvtiRtemplates |  |  |
| `dc-gfup` | Descriptive: follow-up | NA | NA | scaffold | queued | hvtiRtemplates |  |  |
| `dc-dead` | Descriptive: mortality | NA | NA | scaffold | queued | hvtiRtemplates |  |  |
| `dc-stddiff` | Descriptive: standardized differences | NA | NA | scaffold | queued | hvtiRtemplates |  |  |
