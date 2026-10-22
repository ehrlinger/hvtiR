* `setup()` declares the `quarto` R package in every study. `hvtiRtemplates`
  renders jobs through it, and `render_job()` and `submit_job()` stop without
  it, but no member imports it, so a study that installed it by hand still
  left it out of `renv.lock` and a fresh `renv::restore()` could not render a
  job. Rerun `setup()` in an existing study to record it.
