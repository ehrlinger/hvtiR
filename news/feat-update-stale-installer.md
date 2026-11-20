* `update()` stops before updating any member when hvtiR itself is behind
  GitHub, and names `pak::pak("ehrlinger/hvtiR")`. An old installer resolves
  members against its own release's registry and dependency edges. Pass
  `stale_installer = TRUE` to update with it anyway (#98). It also stops when
  hvtiR was updated on disk but the session, not yet restarted, still runs
  the older copy.
* `status()` prints the "hvtiR is behind" line before the member table, where
  it is read first, and its closing line says to update hvtiR before running
  `update()` (#98).
