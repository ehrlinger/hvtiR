* `setup()`'s question whether to adopt a study folder now defaults to Yes, so
  pressing Enter alone adopts it. Adopting is what `setup()` was called to do,
  and having to type `yes` added a step without making the check any closer: the
  question still names the folder, the title, the ID and the files cleanup
  deletes. `?setup`, the README and both adopt prompts in
  `vignette("start-here")` say so. `no` and `cancel` still change
  nothing.
