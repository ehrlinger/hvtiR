* When restoring a study's lockfile fails because a package does not compile,
  `setup()` now names the packages that failed and suggests recording a newer
  version with `renv::record()`. It used to lead with "A GitHub token is
  needed" whenever an authentication message appeared anywhere in the output,
  which sent users after a token when the real cause was a locked version
  (`vctrs` 0.7.2) that no longer builds under R 4.6.
