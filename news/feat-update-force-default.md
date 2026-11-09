* `update()` now defaults to `force = TRUE` on Linux and macOS
  (`force = .Platform$OS.type != "windows"`), so it installs over a member
  that is already loaded instead of warning and installing nothing. It then
  says to restart R, because the session keeps running the old copy. Windows
  keeps `force = FALSE`: overwriting a loaded package there leaves a broken
  library. `install()` keeps its guard everywhere.
