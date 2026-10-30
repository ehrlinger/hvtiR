* After a compile failure, `setup()`'s `renv::record()` hint now covers every
  package that failed, in one call, each keeping its locked source. A package
  whose source has no safe one-line spec is named apart. Previously the call
  named only the first, so each further package cost another run.
