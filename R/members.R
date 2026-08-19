#' Members of the hvtiverse
#'
#' The registry of R packages that make up the HVTI package family, together
#' with the GitHub repository each one installs from.
#'
#' Two members carry a package name that differs from their repository name:
#' `hvtiRpropensity` lives in `ehrlinger/hvtiPropensityScores`, and
#' `TemporalHazard` lives in `ehrlinger/temporal_hazard`. The mapping is
#' therefore stored rather than derived.
#'
#' @return A data frame with one row per member and two character columns:
#'   \describe{
#'     \item{package}{The installed package name.}
#'     \item{repo}{The GitHub repository, as `"owner/repo"`.}
#'   }
#' @export
#' @examples
#' hvtiverse_members()
hvtiverse_members <- function() {
  data.frame(
    package = c(
      "hvtiRutilities",
      "hvtiRdatasets",
      "hvtiRtables",
      "hvtiRtemplates",
      "hvtiPlotR",
      "hvtiRlifetables",
      "hvtiRbootstrap",
      "hvtiRpropensity",
      "hvtiBoostmtree",
      "TemporalHazard",
      "ggRandomForests"
    ),
    repo = c(
      "ehrlinger/hvtiRutilities",
      "ehrlinger/hvtiRdatasets",
      "ehrlinger/hvtiRtables",
      "ehrlinger/hvtiRtemplates",
      "ehrlinger/hvtiPlotR",
      "ehrlinger/hvtiRlifetables",
      "ehrlinger/hvtiRbootstrap",
      "ehrlinger/hvtiPropensityScores",
      "ehrlinger/hvtiBoostmtree",
      "ehrlinger/temporal_hazard",
      "ehrlinger/ggRandomForests"
    ),
    stringsAsFactors = FALSE
  )
}
