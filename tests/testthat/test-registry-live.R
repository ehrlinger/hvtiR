test_that("every registry repo resolves and its Package matches", {
  skip_on_cran()
  skip_if_offline()

  m <- hvtiverse_members()

  for (i in seq_len(nrow(m))) {
    dcf <- fetch_description(m$repo[i])

    expect_false(
      is.null(dcf),
      label = paste("could not fetch DESCRIPTION for", m$repo[i])
    )
    expect_identical(
      as.character(dcf[1L, "Package"]),
      m$package[i],
      label = paste("Package field for", m$repo[i])
    )
  }
})

# Extract the `x.y.z` version out of an `R (>= x.y.z)` requirement in a
# Depends: field. NA in, NA out.
extract_r_requirement <- function(depends) {
  if (is.na(depends)) {
    return(NA_character_)
  }

  flat <- gsub("[[:space:]]+", " ", depends)
  hit <- regmatches(flat, regexpr("R \\(>= *([0-9.]+)\\)", flat))

  if (length(hit) == 0L) {
    return(NA_character_)
  }

  sub("R \\(>= *([0-9.]+)\\)", "\\1", hit)
}

# Split a Depends:/Imports: field into bare package names, dropping version
# constraints and whitespace/newlines from the folded DCF value.
parse_field_packages <- function(field) {
  if (is.na(field)) {
    return(character(0))
  }

  flat <- gsub("[[:space:]]+", " ", field)
  entries <- trimws(gsub("\\([^)]*\\)", "", strsplit(flat, ",")[[1]]))
  entries[nzchar(entries)]
}

test_that("MIN_R_VERSION matches the strictest R requirement across the family", {
  skip_on_cran()
  skip_if_offline()

  m <- hvtiverse_members()
  reqs <- character(0)

  for (i in seq_len(nrow(m))) {
    dcf <- fetch_description(m$repo[i])

    expect_false(
      is.null(dcf),
      label = paste("could not fetch DESCRIPTION for", m$repo[i])
    )

    depends <- if (!is.null(dcf) && "Depends" %in% colnames(dcf)) {
      dcf[1L, "Depends"]
    } else {
      NA_character_
    }

    req <- extract_r_requirement(depends)
    if (!is.na(req)) {
      reqs <- c(reqs, req)
    }
  }

  if (length(reqs) == 0L) {
    fail("No hvtiverse member declares an R (>= x.y.z) requirement.")
  }

  strictest <- max(package_version(reqs))
  expect_true(
    strictest == package_version(MIN_R_VERSION),
    label = sprintf(
      "MIN_R_VERSION (%s) vs strictest live requirement (%s)",
      MIN_R_VERSION, as.character(strictest)
    )
  )
})

test_that("member_deps matches the live Depends/Imports fields of each member", {
  skip_on_cran()
  skip_if_offline()

  m <- hvtiverse_members()
  deps <- member_deps()

  for (i in seq_len(nrow(m))) {
    pkg <- m$package[i]
    dcf <- fetch_description(m$repo[i])

    expect_false(
      is.null(dcf),
      label = paste("could not fetch DESCRIPTION for", m$repo[i])
    )

    if (is.null(dcf)) {
      next
    }

    depends <- if ("Depends" %in% colnames(dcf)) dcf[1L, "Depends"] else NA_character_
    imports <- if ("Imports" %in% colnames(dcf)) dcf[1L, "Imports"] else NA_character_

    referenced <- c(parse_field_packages(depends), parse_field_packages(imports))
    live_member_deps <- intersect(referenced, m$package)

    recorded <- deps[[pkg]]
    if (is.null(recorded)) {
      recorded <- character(0)
    }

    expect_setequal(live_member_deps, recorded)
  }
})
