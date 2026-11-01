* `setup()` gains `workspace_prefs`: `FALSE` leaves the user's RStudio
  preferences alone. The default, `TRUE`, still turns off `.RData` restore and
  save.
* `setup()` without `root` now stops outside a study and asks for it, instead
  of writing the study into the working directory.
* `setup()`'s help now says that `renv` and `hvtiRutilities` can be installed
  into the session's library.
* The dependency checks no longer call `installed.packages()` to name the base
  packages.
