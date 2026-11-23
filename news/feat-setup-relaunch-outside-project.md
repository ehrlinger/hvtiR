* `setup()` run from inside a project no longer stops and asks for a session
  outside it: it starts that session itself. It runs `setup()` again in a
  fresh R from an empty folder, with the startup variables renv saved when it
  activated, prints that session's output, then sets the RStudio preferences
  and opens the project. Whether to adopt a study that already has a
  `_study.yml` is asked first, in the session you typed in, since the fresh R
  is not interactive. It still stops, naming the command, when the fresh R
  cannot load hvtiR (installed only in a study's library).
