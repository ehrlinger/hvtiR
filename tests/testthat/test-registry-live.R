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
