* `setup()` no longer stops when a package will not install. A restore that
  fails is healed in up to 10 rounds: a package whose locked version R forced
  to fail moves to the newest version the study's repositories serve (only
  with `upgrade = TRUE`), and a missing dependency is installed first. After
  that, `setup()` keeps leaving out optional packages until the restore
  succeeds. A package left out is retried at its current release by the
  install stage, and is locked if it installs. One still missing is named in a
  warning and recorded in `renv/hvtiR-setup.dcf`; the study is set up and the
  project opens. A family member that cannot install still stops `setup()`.
* `setup()` copies `renv.lock` to `renv/renv.lock.before-setup-<time>` before
  healing changes it, and keeps the logs in `renv/logs/`.
* `doctor()` lists the packages the last `setup()` left out, and why.
