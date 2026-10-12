* New `inst/extdata/family-floors.csv` records every version floor one family
  member declares on another, read from each member's `DESCRIPTION` on `main`
  by the weekly catalog-versions job. A floor `main` does not meet in
  `Depends`, `Imports` or `LinkingTo` would break `install()`, which resolves
  members from `main` in one call, so that job now fails on one; a `Suggests`
  floor is reported only.
