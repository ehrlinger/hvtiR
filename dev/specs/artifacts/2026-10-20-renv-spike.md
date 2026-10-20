# renv explicit-mode spike (2026-10-20)

renv `1.2.4`, pak back end (`RENV_CONFIG_PAK_ENABLED=TRUE`), R 4.6.1, macOS arm64.
Script: the brief's `spike.R`, plus additions (below). Scratch project in the session scratchpad, not a repo.

## Results

1. `1. jsonlite locked: TRUE | cli locked (must be FALSE): FALSE` -- PASS.
   `.renvignore` was ABSENT (`.renvignore present: FALSE`), and the stale `30_analyses/tp.hz.R`
   containing `library(cli)` was still not recorded. Explicit mode does not need `.renvignore`.
2. `renv::install('ehrlinger/hvtiRutilities', prompt = FALSE)` through pak finished without error
   (`Installed hvtiRutilities 1.5.5 (github::ehrlinger/hvtiRutilities@a4425af)`) -- PASS.
   After adding `hvtiRutilities` to the DESCRIPTION Depends and snapshotting, the lockfile records:
   `Source: GitHub`, `RemoteUsername: ehrlinger`, `RemoteRepo: hvtiRutilities`,
   `RemotePkgRef: ehrlinger/hvtiRutilities`, `RemoteRef: HEAD`, `RemoteSha: a4425af4...`, `Version: 1.5.5`.
3. `3. jsonlite still 2.0.0 : TRUE` -- PASS. `restore` reported `1 pkg: kept 1`. (Caveat: the snapshot
   before it had failed, see below, so the lock restored was the check-1 lock.)
4. `4. lockfile R: 4.6.1 | running R: 4.6.1` -- the lockfile records the running R version
   (full `major.minor.patch`).

## Finding that needs a decision (not one of the four checks)

After `renv::install()` of hvtiRutilities via pak, a plain `renv::snapshot(prompt = FALSE)` ABORTS:

```
The following required packages are not installed:
- cpp11     [required by haven, readr, readxl, and 3 others]
- progress  [required by readxl, vroom]
Error: aborting snapshot due to pre-flight validation failure
```

Cause: pak installs binaries without their `LinkingTo` packages (`vroom`: `LinkingTo: cpp11, progress, tzdb`),
and renv's pre-flight treats them as required. `renv::snapshot(prompt = FALSE, force = TRUE)` succeeds and
writes the lockfile (with the GitHub fields above); `cpp11` is then listed in the lock as a dependency
name although it is not installed. Whether `setup()` should snapshot with `force = TRUE`, or install the
`LinkingTo` packages first (`renv::install(c("cpp11","progress"))`), is open. Not tested: the same flow
with pak disabled.

## Script changes

- Added `cat` of `.renvignore` presence after check 1.
- After check 2, rewrote DESCRIPTION with `Depends: jsonlite, hvtiRutilities` and ran `renv::snapshot()`
  to read the hvtiRutilities fields (as instructed); the lock read for the fields used `force = TRUE`
  in a separate follow-up run on a persistent project dir (tempdir is deleted on exit).
- Check 4 line also prints the running R version. Checks themselves unchanged.
