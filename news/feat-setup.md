* New `setup()` sets up a study's environment in one command: it cleans up template copies before renv,
  declares the family and the packages it needs, installs them into the study's library, and snapshots.
  renv runs in explicit mode, so the lockfile records what the study declares.
  A study with a `renv.lock` keeps its locked versions, and every package that lockfile recorded is declared on first conversion.
* `doctor()` reports a member whose dependencies are not on the library path, and a study lockfile made
  under a different R.
* `setup()` installs the subdirectory remotes that members pin (read from their DESCRIPTIONs, such as `boostmtree`)
  in a first `renv::install()` call, which works around a renv 1.2.4 failure ("target file ... already exists") on a cold cache.
* `setup()` warns before it writes anything when no GitHub credentials are found, and says how to create them,
  and a failed install that reports missing authentication credentials says so too.
* `setup()` never upgrades a locked package: if declaring a new package would move a locked dependency, it restores the locked versions, leaves `renv.lock` unchanged and stops, naming the change; `update()` is the way to move versions.
