#' Read the job catalog
#'
#' The 53 job types found in the studies corpus, each routed to the package
#' that owes it. Rows are returned as a list rather than a data frame because
#' `upstream`, `downstream`, `workflows` and `replaced_by` are arrays.
#'
#' @param path Path to the catalog JSON. Defaults to the copy installed with
#'   the package.
#' @return A list of 53 lists, one per job type.
#' @noRd
read_jobs <- function(path = system.file("extdata", "jobs.json",
                                         package = "hvtiR")) {
  jsonlite::fromJSON(path, simplifyVector = FALSE)$jobs
}

#' The job catalog
#'
#' Every job type found in the studies corpus, with the package that owes it.
#' A job type is keyed on `prefix` and `qualifier` together, because one prefix
#' can carry several job types.
#'
#' `disposition` says what kind of work a row is:
#'
#' * `scaffold`, genuinely repeated work; a template is the deliverable
#' * `thin`, a template whose body is mostly calls into `replaced_by`
#' * `retire`, the work is a function that exists; no template is owed
#' * `build`, the work is a function that does not exist yet
#'
#' `destination` names who owes the remaining work. `replaced_by` names what
#' already exists, as `package::function`, and is frequently in a different
#' package from `destination`: a thin template lives in `hvtiRtemplates` and
#' leans on `hvtiPlotR`.
#'
#' The taxonomy that says what a prefix *means* is
#' `hvtiRutilities::hvti_taxonomy()`. This catalog says who owes it. They are
#' apart because validating a routing has to load the destination package, and
#' `hvtiRutilities` is imported by packages this catalog routes to.
#'
#' @return A data frame with one row per job type. `replaced_by` is a list
#'   column of character vectors, empty where nothing replaces the row.
#' @export
#' @examples
#' j <- jobs()
#' table(j$disposition)
jobs <- function() {
  raw <- read_jobs()

  chr <- function(field) {
    vapply(raw, function(r) {
      v <- r[[field]]
      if (is.null(v)) NA_character_ else as.character(v)
    }, character(1))
  }
  int <- function(field) {
    vapply(raw, function(r) {
      v <- r[[field]]
      if (is.null(v)) NA_integer_ else as.integer(v)
    }, integer(1))
  }

  out <- data.frame(
    prefix      = chr("prefix"),
    qualifier   = chr("qualifier"),
    name        = chr("name"),
    folder      = chr("folder"),
    family      = chr("family"),
    status      = chr("status"),
    disposition = chr("disposition"),
    destination = chr("destination"),
    sas_breadth = int("sas_breadth"),
    r_jobs      = int("r_jobs"),
    blocked_on  = chr("blocked_on"),
    stringsAsFactors = FALSE
  )
  out$replaced_by <- lapply(raw, function(r) {
    v <- unlist(r$replaced_by)
    if (is.null(v)) character(0) else as.character(v)
  })
  out
}
