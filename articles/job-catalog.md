# The job catalog

Every job type found in the studies corpus, and the package that owes
it. SAS counts the studies holding a program of each job type, and R
counts the R jobs already written. Both are distinct counts, so rows do
not sum; `NA` means not yet measured and `0` means measured and none
found. This page is generated from the catalog shipped with the package,
so it cannot disagree with it.

| disposition | rows |
|:------------|-----:|
| build       |    8 |
| retire      |    6 |
| scaffold    |   29 |
| thin        |   15 |

## distributions

| job | name | SAS | R | disposition | status | destination | replaced by | blocked on |
|:---|:---|---:|---:|:---|:---|:---|:---|:---|
| `ac` | Actuarial | 745 | 20 | scaffold | shipped | hvtiRtemplates |  |  |
| `cd` | Cumulative distribution | 190 | 8 | scaffold | queued | hvtiRtemplates |  |  |
| `hz` | Hazard fit | 574 | 8 | scaffold | shipped | hvtiRtemplates |  |  |
| `nd` | Nonparametric distributions | 244 | 12 | scaffold | queued | hvtiRtemplates |  |  |
| `dp-variable` | Distribution of a variable | 237 | 2 | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_trends`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_trends.html), [`hvtiPlotR::hv_ordinal`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_ordinal.html) |  |

## documents

| job | name | SAS | R | disposition | status | destination | replaced by | blocked on |
|:---|:---|---:|---:|:---|:---|:---|:---|:---|
| `ar` | Analysis report | 394 | 1114 | scaffold | queued | hvtiRtemplates |  |  |

## analyses

| job | name | SAS | R | disposition | status | destination | replaced by | blocked on |
|:---|:---|---:|---:|:---|:---|:---|:---|:---|
| `bc` | Bootstrap Cox | 16 | 0 | scaffold | shipped | hvtiRtemplates |  |  |
| `bh` | Bootstrap hazard | 320 | 5 | scaffold | shipped | hvtiRtemplates |  |  |
| `bl` | Bootstrap logistic | 352 | 1 | scaffold | shipped | hvtiRtemplates |  |  |
| `bn` | Bootstrap nonparametric | 108 | 0 | scaffold | queued | hvtiRtemplates |  |  |
| `bq` | Bootstrap quantile | 2 | 0 | scaffold | queued | hvtiRtemplates |  | hvtiRbootstrap#16 |
| `br` | Bootstrap regression | 103 | 1 | scaffold | shipped | hvtiRtemplates |  |  |
| `cm` | Cox matching | 35 | 2 | scaffold | queued | hvtiRtemplates |  |  |
| `gm` | Generalized model | 73 | 0 | scaffold | queued | hvtiRtemplates |  |  |
| `hm` | Hazard model | 373 | 9 | scaffold | shipped | hvtiRtemplates |  |  |
| `lm` | Logistic model | 470 | 45 | thin | queued | hvtiRtemplates | [`hvtiRpropensity::ps_logistic`](https://ehrlinger.github.io/hvtiRpropensity/reference/ps_logistic.html), [`hvtiRpropensity::bs_count`](https://ehrlinger.github.io/hvtiRpropensity/reference/bs_count.html) |  |
| `ls` | Life table / STS | 32 | 0 | scaffold | queued | hvtiRtemplates |  |  |
| `mm` | Mixed model | 56 | 1 | scaffold | queued | hvtiRtemplates |  |  |
| `nb` | Notebook | 18 | 63 | build | NA | ggBoostedTrees |  | ggBoostedTrees#9 |
| `nm` | Nonparametric model | 121 | 1 | scaffold | queued | hvtiRtemplates |  |  |
| `pm` | Propensity model | 4 | 0 | retire | NA | hvtiRpropensity | [`hvtiRpropensity::bs_count`](https://ehrlinger.github.io/hvtiRpropensity/reference/bs_count.html) |  |
| `rf` | Random forest | 41 | 312 | retire | NA | ggRandomForests | [`ggRandomForests::gg_rfsrc`](https://ehrlinger.github.io/ggRandomForests/reference/gg_rfsrc.rfsrc.html), [`ggRandomForests::gg_error`](https://ehrlinger.github.io/ggRandomForests/reference/gg_error.html), [`ggRandomForests::gg_vimp`](https://ehrlinger.github.io/ggRandomForests/reference/gg_vimp.html), [`ggRandomForests::gg_variable`](https://ehrlinger.github.io/ggRandomForests/reference/gg_variable.html) |  |
| `rfc` | Random forest classifier | 11 | 52 | retire | NA | ggRandomForests | [`ggRandomForests::gg_roc`](https://ehrlinger.github.io/ggRandomForests/reference/gg_roc.rfsrc.html), [`ggRandomForests::gg_brier`](https://ehrlinger.github.io/ggRandomForests/reference/gg_brier.html), [`ggRandomForests::gg_error`](https://ehrlinger.github.io/ggRandomForests/reference/gg_error.html), [`ggRandomForests::calc_auc`](https://ehrlinger.github.io/ggRandomForests/reference/calc_auc.html) |  |
| `rfs` | Random forest survival | 9 | 39 | retire | NA | ggRandomForests | [`ggRandomForests::gg_rfsrc`](https://ehrlinger.github.io/ggRandomForests/reference/gg_rfsrc.rfsrc.html), [`ggRandomForests::gg_survival`](https://ehrlinger.github.io/ggRandomForests/reference/gg_survival.html), [`ggRandomForests::gg_error`](https://ehrlinger.github.io/ggRandomForests/reference/gg_error.html), [`ggRandomForests::gg_vimp`](https://ehrlinger.github.io/ggRandomForests/reference/gg_vimp.html) |  |
| `rfsrc` | Random forest (SRC) | 97 | 631 | retire | NA | ggRandomForests | [`ggRandomForests::gg_rfsrc`](https://ehrlinger.github.io/ggRandomForests/reference/gg_rfsrc.rfsrc.html), [`ggRandomForests::gg_survival`](https://ehrlinger.github.io/ggRandomForests/reference/gg_survival.html), [`ggRandomForests::gg_error`](https://ehrlinger.github.io/ggRandomForests/reference/gg_error.html), [`ggRandomForests::gg_vimp`](https://ehrlinger.github.io/ggRandomForests/reference/gg_vimp.html), [`ggRandomForests::gg_partial`](https://ehrlinger.github.io/ggRandomForests/reference/gg_partial.html) |  |
| `rm` | Regression model | 170 | 94 | scaffold | queued | hvtiRtemplates |  |  |
| `rfr` | Random forest regression | NA | NA | retire | intake | ggRandomForests | [`ggRandomForests::gg_rfsrc`](https://ehrlinger.github.io/ggRandomForests/reference/gg_rfsrc.rfsrc.html), [`ggRandomForests::gg_vimp`](https://ehrlinger.github.io/ggRandomForests/reference/gg_vimp.html), [`ggRandomForests::gg_shap`](https://ehrlinger.github.io/ggRandomForests/reference/gg_shap.html) | hvtiRutilities#taxonomy |
| `sid` | Random forest clustering (sidClustering) | NA | NA | build | intake | ggRandomForests |  | hvtiRutilities#taxonomy |
| `vt` | Virtual twins | NA | NA | build | intake | ggRandomForests |  | hvtiRutilities#taxonomy |

## datasets

| job | name | SAS | R | disposition | status | destination | replaced by | blocked on |
|:---|:---|---:|---:|:---|:---|:---|:---|:---|
| `bd` | Build | 1094 | 18 | scaffold | queued | hvtiRtemplates |  | hvtiRdatabuild |
| `dt` | Data check | 503 | 0 | scaffold | queued | hvtiRtemplates |  | hvtiRdatabuild |
| `vars` | Variables | 912 | 2 | scaffold | queued | hvtiRtemplates |  | hvtiRdatabuild |
| `si` | Single imputation | 1 | NA | scaffold | queued | hvtiRtemplates |  |  |
| `mi` | Multiple imputation | 18 | NA | scaffold | queued | hvtiRtemplates |  | hvtiRimputation |

## graphs

| job | name | SAS | R | disposition | status | destination | replaced by | blocked on |
|:---|:---|---:|---:|:---|:---|:---|:---|:---|
| `ce` | Competing events | 128 | 1 | build | NA | hvtiPlotR |  | hvtiPlotR#134 |
| `cp` | Cumulative probability plot | 4 | 1 | build | NA | hvtiPlotR |  | hvtiPlotR#135 |
| `fp` | Forest plot | 11 | 20 | build | NA | hvtiPlotR |  | hvtiPlotR#133 |
| `gp` | Generalized model plot | 50 | 2 | build | NA | hvtiPlotR |  | hvtiPlotR#136 |
| `hp` | Hazard plot | 541 | 24 | thin | revisit | hvtiRtemplates | [`hvtiPlotR::hv_hazard`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_hazard.html), [`hvtiPlotR::hazard_plot`](https://ehrlinger.github.io/hvtiPlotR/reference/hazard_plot.html), [`hvtiPlotR::hv_survival`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_survival.html), [`hvtiPlotR::hv_atrisk_compose`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_atrisk_compose.html) |  |
| `hs` | Hazard setup | 140 | 11 | scaffold | shipped | hvtiRtemplates |  |  |
| `lp` | Logistic plot | 310 | 606 | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_mirror_hist`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_mirror_hist.html) |  |
| `mp` | Mixed model plot | 41 | 5 | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_spaghetti`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_spaghetti.html) |  |
| `np` | Nonparametric plot | 241 | 201 | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_nonparametric`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_nonparametric.html), [`hvtiPlotR::hv_ordinal`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_ordinal.html) |  |
| `rp` | Regression plot | 68 | 8 | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_balance`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_balance.html) |  |
| `dp-trends` | Descriptive plot: trends | 80 | 105 | thin | shipped | hvtiRtemplates | [`hvtiPlotR::hv_trends`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_trends.html) |  |
| `dp-gfup` | Descriptive plot: follow-up | 48 | 50 | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_followup`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_followup.html) |  |
| `dp-spaghetti` | Descriptive plot: spaghetti | 40 | 68 | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_spaghetti`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_spaghetti.html) |  |
| `dp-procs` | Descriptive plot: procedures over time | 35 | 0 | thin | queued | hvtiRtemplates | [`hvtiPlotR::hv_longitudinal`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_longitudinal.html), [`hvtiPlotR::hv_stacked`](https://ehrlinger.github.io/hvtiPlotR/reference/hv_stacked.html) |  |
| `dp-boxplot` | Descriptive plot: boxplot | 9 | 2 | scaffold | queued | hvtiRtemplates |  |  |

## descriptive

| job | name | SAS | R | disposition | status | destination | replaced by | blocked on |
|:---|:---|---:|---:|:---|:---|:---|:---|:---|
| `lg` | Logit trends | 362 | 0 | scaffold | queued | hvtiRtemplates |  |  |
| `rg` | Regression trends | 45 | 0 | scaffold | queued | hvtiRtemplates |  |  |
| `dc-general` | Descriptive: general | 759 | 1 | thin | queued | hvtiRtemplates | [`hvtiRutilities::proc_contents`](https://ehrlinger.github.io/hvtiRutilities/reference/proc_contents.html), [`hvtiRutilities::proc_means`](https://ehrlinger.github.io/hvtiRutilities/reference/proc_means.html) |  |
| `dc-tables` | Descriptive: formatted tables | 551 | 1 | thin | queued | hvtiRtemplates | [`hvtiRtables::hv_tbl_summary`](https://ehrlinger.github.io/hvtiRtables/reference/hv_tbl_summary.html), [`hvtiRtables::hv_man_table`](https://ehrlinger.github.io/hvtiRtables/reference/hv_man_table.html), [`hvtiRtables::hv_man_table_save`](https://ehrlinger.github.io/hvtiRtables/reference/hv_man_table_save.html) |  |
| `dc-gfup` | Descriptive: follow-up | 389 | 0 | thin | queued | hvtiRtemplates | [`hvtiRutilities::proc_means`](https://ehrlinger.github.io/hvtiRutilities/reference/proc_means.html) |  |
| `dc-dead` | Descriptive: mortality | 171 | 0 | thin | queued | hvtiRtemplates | [`hvtiRutilities::proc_means`](https://ehrlinger.github.io/hvtiRutilities/reference/proc_means.html) |  |
| `dc-stddiff` | Descriptive: standardized differences | 120 | 0 | build | NA | hvtiRutilities |  | hvtiRutilities#103 |
| `dp-postage` | Descriptive plot: postage stamp | NA | NA | scaffold | queued | hvtiRtemplates |  |  |
| `dc-trends` | Descriptive: trends | 43 | 0 | scaffold | queued | hvtiRtemplates |  |  |
