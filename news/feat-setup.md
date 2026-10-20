* New `setup()` sets up a study's environment in one command: it cleans up template copies before renv,
  declares the family and the packages it needs, installs them into the study's library, and snapshots.
  A study with a `renv.lock` keeps its locked versions.
* `doctor()` reports a member whose dependencies are not on the library path, and a study lockfile made
  under a different R.
