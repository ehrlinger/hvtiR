* The warning `install()` and `update()` raise for debris in a study's
  library now prints the study's real paths, so each repair command can be
  pasted as it is, where it used to print placeholders such as
  `<library>/_cache`. It no longer says pak cannot replace `_cache`: that is
  pak's staging directory, left by a failed install, which pak works around
  and renv's library scan fails on. A leftover `_cache` alone now gets its
  one removal step; links into a cache the user cannot read still get the
  full repair, which now says the renv steps fail until `_cache` is gone and
  ends by restoring only the removed packages: the bare `renv::restore()` it
  used to end with reverted every package to the lockfile, undoing the
  install or update that raised the warning. The numbered steps are
  indented under the warning.
