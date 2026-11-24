* `setup()` again leaves out a package that fails to install rather than
  stopping, when renv prints a traceback after its error. The failed-package
  reader took the last line mentioning "failed to install", which was then the
  traceback's quoted format string, so it found no package and healing aborted
  on its first round. A study whose `renv.lock` pinned an `arrow` version the
  repository no longer served stopped there, with all 103 packages rolled
  back. It now reads the last such line that names a package.
