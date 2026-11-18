- `update()`, `install()`, `status()` and `doctor()` no longer tell a user in a
  study that has no renv library yet to open its `.Rproj`. Opening it changes
  nothing, because there is no library to activate; they now say to run
  `setup()` there instead. The line "A new study starts with `setup()`, run
  outside any project" appears only when no study encloses the working
  directory, and no longer says "outside any project": read straight after
  the error, it was being taken as the fix.
