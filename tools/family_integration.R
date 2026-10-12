# Helpers for .github/workflows/family-integration.yml.
#
# The integration run must test one fixed family: the revisions
# hvtiR::install() put in the library. Every later step reads that record
# rather than GitHub `main`, which can move between steps. Three subcommands:
#
#   Rscript tools/family_integration.R record <dir>
#       Writes <dir>/family.tsv (package, repo, sha) for every member, and
#       <dir>/consumers.tsv for the members whose INSTALLED Depends, Imports
#       or LinkingTo names another member. Fails if a member has no
#       RemoteSha, since then it did not come from GitHub and cannot be pinned.
#
#   Rscript tools/family_integration.R pin <checkout> <dir>/family.tsv
#       Rewrites the checkout's Remotes: so every family entry names the
#       installed SHA (owner/repo@sha). Its dev dependencies then resolve to
#       the revisions already installed instead of whatever `main` is now.
#
#   Rscript tools/family_integration.R verify <dir>/family.tsv
#       Fails if any member's installed RemoteSha differs from the record.
#       The pin is the mechanism; this is the guarantee.

hard_fields <- c("Depends", "Imports", "LinkingTo")

dependency_names <- function(value) {
  if (is.null(value) || is.na(value) || !nzchar(value)) return(character())
  entries <- trimws(strsplit(value, ",")[[1]])
  sub("[[:space:]]*\\(.*$", "", entries[nzchar(entries)])
}

installed_sha <- function(package) {
  sha <- utils::packageDescription(package)$RemoteSha
  if (is.null(sha) || is.na(sha)) "" else sha
}

record <- function(dir) {
  members <- hvtiR::members()
  family <- data.frame(
    package = members$package,
    repo = members$repo,
    sha = vapply(members$package, installed_sha, character(1)),
    stringsAsFactors = FALSE
  )
  missing <- family$package[!nzchar(family$sha)]
  if (length(missing)) {
    stop("No RemoteSha, so not installed from GitHub: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  imports_member <- vapply(family$package, function(p) {
    desc <- utils::packageDescription(p, fields = hard_fields)
    deps <- unlist(lapply(desc, dependency_names))
    any(setdiff(deps, p) %in% family$package)
  }, logical(1))
  utils::write.table(family, file.path(dir, "family.tsv"), sep = "\t",
                     quote = FALSE, row.names = FALSE)
  utils::write.table(family[imports_member, ], file.path(dir, "consumers.tsv"),
                     sep = "\t", quote = FALSE, row.names = FALSE,
                     col.names = FALSE)
  message("Recorded ", nrow(family), " members; consumers: ",
          paste(family$package[imports_member], collapse = ", "))
}

# "TemporalHazard=ehrlinger/TemporalHazard" or "ehrlinger/hvtiRutilities"
# (optionally already "@ref") -> the same entry pinned to the recorded SHA
# when its repository is a member; other entries are left alone.
pin_entry <- function(entry, family) {
  name <- if (grepl("=", entry, fixed = TRUE)) sub("=.*$", "=", entry) else ""
  spec <- sub("^.*=", "", entry)
  repo <- sub("@.*$", "", spec)
  hit <- match(tolower(repo), tolower(family$repo))
  if (is.na(hit)) return(entry)
  paste0(name, repo, "@", family$sha[hit])
}

pin <- function(checkout, family_tsv) {
  family <- utils::read.delim(family_tsv, stringsAsFactors = FALSE)
  path <- file.path(checkout, "DESCRIPTION")
  desc <- read.dcf(path, keep.white = "Remotes")
  if (!"Remotes" %in% colnames(desc)) {
    message("No Remotes: in ", path, "; nothing to pin.")
    return(invisible())
  }
  entries <- trimws(strsplit(desc[1, "Remotes"], ",")[[1]])
  entries <- entries[nzchar(entries)]
  desc[1, "Remotes"] <- paste(vapply(entries, pin_entry, character(1),
                                     family = family), collapse = ", ")
  write.dcf(desc, path, keep.white = "Remotes")
  message("Pinned Remotes: ", desc[1, "Remotes"])
}

verify <- function(family_tsv) {
  family <- utils::read.delim(family_tsv, stringsAsFactors = FALSE)
  now <- vapply(family$package, installed_sha, character(1))
  moved <- family$package[now != family$sha]
  if (length(moved)) {
    stop("The family changed under the test: ",
         paste0(moved, " ", substr(family$sha[now != family$sha], 1, 7),
                " -> ", substr(now[now != family$sha], 1, 7),
                collapse = "; "), call. = FALSE)
  }
  message("Family unchanged: ", nrow(family), " members at their recorded SHAs.")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  switch(args[1],
    record = record(args[2]),
    pin = pin(args[2], args[3]),
    verify = verify(args[2]),
    stop("usage: family_integration.R record|pin|verify ...", call. = FALSE)
  )
}
