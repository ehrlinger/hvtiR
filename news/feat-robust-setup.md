* `setup()` no longer stops when a package will not install. A restore that
  fails is healed in up to 10 rounds: a package that will not build under
  this R moves to the newest version the study's repositories serve (only
  with `upgrade = TRUE`), and a missing dependency is installed first; one
  that will not install leaves its dependents out. After that, `setup()` keeps
  leaving out packages outside the family until the restore succeeds. With
  `upgrade = TRUE`, a package left out is retried at its current release by
  the install stage and locked if it installs; with `upgrade = FALSE` it is
  not retried, since that would move a pin. One still missing is named in a
  warning and recorded in `renv/hvtiR-setup.dcf`; the study is set up and the
  project opens. A package whose dependency is missing stays locked but
  cannot load until the dependency installs. A family member that cannot
  install still stops `setup()`.
* `setup()` copies `renv.lock` to `renv/renv.lock.before-setup-<time>` before
  healing changes it, and keeps the logs in `renv/logs/`.
* `doctor()` lists the packages the last `setup()` left out, and why. A
  record it cannot read gets one line, not an error.
