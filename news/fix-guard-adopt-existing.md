* When `setup()` is run from inside a study whose own library is loaded, it
  stops and prints the call to run from outside the project. For a study
  directory that already exists, that call now says `adopt = TRUE`, and the
  message says what adopting deletes and that `cleanup = FALSE` keeps it. It
  had echoed the `adopt` it was given, so for a study that already had a
  `_study.yml` the printed call said `adopt = FALSE` and stopped when run as
  printed.
