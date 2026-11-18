- `update()`, `install()`, `status()` and `doctor()` no longer tell a user in a
  study, or in a project folder with no `_study.yml` yet (one made with
  RStudio's New Project wizard), that has no renv library to open its
  `.Rproj`. Opening it changes nothing, because there is no library to
  activate; they now say to run `setup()` there instead. The line "A new study
  starts with `setup()`" appears only when neither a study nor a project
  folder is found, and no longer says "run outside any project": read
  straight after the error, it was being taken as the fix.
