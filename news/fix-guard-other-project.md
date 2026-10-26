* `setup()` run from a session inside a different study's renv project now
  says so and names that project. It used to say the session had loaded
  packages `setup()` would replace, which was not the reason. RStudio reopens
  the last project on restart, so this is the usual way to hit it.
