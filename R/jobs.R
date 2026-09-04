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

  # Every field below is a scalar in the catalog, but the file is hand
  # edited and four of its fields ARE arrays, so a scalar written as an
  # array is a plausible slip. vapply's own message for it names neither
  # the field nor the row -- "values must be length 1, but FUN(X[[i]])
  # result is length 2" -- and the first sign of it is the vignette
  # failing to build. So check here and say which row and which field.
  row_label <- function(r, i) {
    prefix <- r[["prefix"]]
    paste0("row ", i,
           if (is.character(prefix) && length(prefix) == 1L) {
             paste0(" (prefix '", prefix, "')")
           } else {
             ""
           })
  }
  scalar <- function(r, i, field) {
    v <- r[[field]]
    if (!is.null(v) && length(v) != 1L) {
      stop("jobs(): ", row_label(r, i),
           " gives ", length(v), " values for '", field,
           "', which the catalog records one of.",
           call. = FALSE)
    }
    v
  }
  chr <- function(field) {
    vapply(seq_along(raw), function(i) {
      v <- scalar(raw[[i]], i, field)
      if (is.null(v)) NA_character_ else as.character(v)
    }, character(1))
  }
  # as.integer() turns a non-numeric string into NA with a warning, which
  # reads downstream as a field the catalog simply omits. Same slip, same
  # file, so name the row and the field rather than losing the value.
  int <- function(field) {
    vapply(seq_along(raw), function(i) {
      v <- scalar(raw[[i]], i, field)
      if (is.null(v)) {
        return(NA_integer_)
      }
      n <- suppressWarnings(as.integer(v))
      if (is.na(n) && !is.na(v)) {
        stop("jobs(): ", row_label(raw[[i]], i),
             " gives '", v, "' for '", field,
             "', which the catalog records a whole number in.",
             call. = FALSE)
      }
      n
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
