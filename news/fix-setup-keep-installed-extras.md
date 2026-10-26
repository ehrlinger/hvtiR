* `setup()` no longer upgrades a standard analysis package, such as `arrow`,
  that is already in the study's library but missing from its `renv.lock`.
  It named every unlocked package to pak, which installs the newest release
  of a package it is named; on a server that could not build that release,
  setup stopped. A family member missing from `renv.lock` is still named, so
  it moves to `main` even when already installed.
