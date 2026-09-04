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
