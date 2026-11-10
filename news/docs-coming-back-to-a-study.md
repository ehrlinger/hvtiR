* The "Start here" vignette has a new section, "Coming back to a study", for
  an analyst returning to a study that already has `_study.yml` and
  `renv.lock`: open the `.Rproj` and never rerun `setup()`, then `status()`,
  `update()`, `renv::snapshot()` after an update you made (or
  `renv::restore()` when the lockfile is ahead of the library),
  `update_manifest()` and `upgrade_job()`, in that order.
