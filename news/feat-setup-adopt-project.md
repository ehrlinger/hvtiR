* `setup()` run inside a legacy study's own RStudio project, with no
  `_study.yml` above it, now offers to adopt the project folder (the default
  answer is No) instead of stopping. It refuses a project opened at a study
  folder such as `30_analyses`, or at a package, and a non-interactive
  session stops and prints the `setup(root = ..., adopt = TRUE)` call. This
  is now the usual way to start a study.
