#' Members of the hvtiR
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
#' members()
members <- function() {
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

#' Dependencies between hvtiR members
#'
#' Members that import another member. Used to close an update's target set:
#' installing a member without its in-family dependency can send `pak` to CRAN
#' for that dependency, where the required version may not exist.
#'
#' @return A named list. Each name is a member package; each value is a
#'   character vector of member packages it depends on.
#' @noRd
member_deps <- function() {
  list(
    hvtiRdatasets = "hvtiRutilities",
    hvtiRlifetables = "TemporalHazard"
  )
}
