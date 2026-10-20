* New `setup()` sets up a study's environment in one command: it cleans up template copies before renv,
  declares the family and the packages it needs, installs them into the study's library, and snapshots.
  renv runs in explicit mode, so the lockfile records what the study declares.
  A study with a `renv.lock` keeps its locked versions, and every package that lockfile recorded is declared on first conversion.
* `doctor()` reports a member whose dependencies are not on the library path, and a study lockfile made
  under a different R.
