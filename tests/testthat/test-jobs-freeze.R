test_that("the job catalog is frozen while it moves to hvtiRtemplates", {
  # hvtiRtemplates:dev/specs/2026-09-18-template-catalog-design.md moves this
  # catalog to hvtiRtemplates as templates.json. Between that move (its step 1)
  # and this package dropping jobs.json (its step 2) two copies exist, which is
  # the drift the 2026-09-04 design existed to prevent. This test turns the
  # freeze from a convention into a check: any edit to jobs.json fails here.
  # Step 2 deletes this test together with the file.
  #
  # The checksum is taken over NORMALIZED text, not raw bytes. The repository
  # has no .gitattributes and CI runs on windows-latest, where checkout may
  # write CRLF line endings; a raw checksum would then fail on Windows alone,
  # with nobody having touched the file. readLines() accepts either ending,
  # so re-joining its lines with "\n" gives the same digest on every platform.
  # Measured 2026-09-18: a genuine CRLF copy (1,440 CR bytes) differs from the
  # LF file by raw md5 and matches it after normalization.
  path <- system.file("extdata", "jobs.json", package = "hvtiR")
  expect_true(nzchar(path), label = "jobs.json is installed with the package")

  normalized <- tempfile()
  on.exit(unlink(normalized), add = TRUE)
  writeLines(readLines(path, warn = FALSE), normalized, sep = "\n")

  expect_identical(
    unname(tools::md5sum(normalized)),
    "1bf6b7fb4ef3cda2028b9667dc29f2c2",
    label = paste(
      "jobs.json changed while frozen; catalog edits belong in",
      "hvtiRtemplates' templates.json (template-catalog design, step 1)"
    )
  )
})
