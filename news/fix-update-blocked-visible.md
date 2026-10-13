* `update()` now says at once that it installed nothing when a member it needs
  is already loaded, naming the loaded members. Until now the only signal was
  a warning, which prints after the call returns and vanishes under
  `suppressWarnings()` or `options(warn = -1)`, so `update()` could stop after
  "hvtiR is current" without a word about the members it skipped.
