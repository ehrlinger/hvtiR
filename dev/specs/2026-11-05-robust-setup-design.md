# A setup() that lets people get to work

Status: approved, 2026-11-05. Decisions marked **(decided)** are John's.

## The problem

**(decided)** "We can't have users NOT able to get to work because of failures in
study_setup." Today `hvtiR::setup()` is all or nothing. One package that will not
install aborts the whole run, and the study cannot be used until someone fixes
it by hand.

Every failure recorded since October came from the install phase, not from the
study's identity:

| When | Study | Failure | What it took |
|---|---|---|---|
| 2026-10-26 | Chadi's new study | `arrow` 26 needed a C++20 compiler lri lacks | hvtiR#157: arrow allowed to fail |
| 2026-10-29 | Hsich multicenter (ST 1022) | An R 4.5.1 lock under R 4.6.1: `vctrs` 0.7.2 and eleven more pins would not compile | Seven manual rounds of `renv::record()` overnight |
| 2026-10-29 | Hsich multicenter | `forecast`: "dependency 'tseries' is not available", though tseries built in the same run | A manual `renv::install()` before `setup()` |
| 2026-10 | COMMENCE and others | Shared-cache links, GitHub tokens, a lockfile too long for `Rscript -e` | Fixed in hvtiR#138–#143 |

`abort_stage()` already recognizes compile failures and prints the
source-preserving `renv::record()` call that fixes them. The user then has to
run it and start over, once per failing package, because `renv::restore()`
stops at the first failure.

**(decided)** Arrow now installs from the team's own repository mirror, so it is
no longer a live failure. It is kept here as an example of a package with a
system requirement.

## Decision (decided): staged setup that heals, then degrades

The alternatives were self-heal only, still all or nothing (rejected because
whatever healing cannot fix still blocks work), and a shared prebuilt fallback
library (rejected because jobs would run against packages the study's lockfile
does not record).

"Able to get to work" **(decided)** means both: `setup()` first fixes what it can
safely fix, then leaves out what it cannot, records it, and finishes with a
usable study.

## 1. Stages, and what may degrade

| Stage | What | On failure |
|---|---|---|
| 1. Identity | `hvtiRutilities::study_setup()`: `_study.yml`, folders, `.Rproj`, cleanup, renv init | Mostly stops, with the repair step named. Two cleanup stops become warnings and one repair is added (section 4). Identity is written before renv starts, so a rerun resumes. |
| 2. Restore | `renv::restore()` of the existing lock (child 1) | Heal, then degrade (section 2) |
| 3. Install | pak installs the family and the declared packages the lock lacks | Heal, then degrade |
| 4. Finish | `LinkingTo` gaps, version floors, guard, snapshot (child 2) | **Stops.** A snapshot failure is never papered over. |
| 5. Verify | `unresolved_imports()` | A package whose dependency is missing is degraded. Otherwise it reports, as today. |

**Essential vs optional (decided).**

- **Essential: a failure stops `setup()`, after healing.** This is `hvtiR`, every
  family member (`members()$package`) and their hard dependencies (`Depends`,
  `Imports`, `LinkingTo`, resolved recursively). Without them `add_job()`,
  rendering and data reads do not work, so "set up" would be false.
- **Optional: a failure degrades.** This is everything else: the standard
  analysis set (`environment_extras()`), `optional_extras()`, and packages
  carried over from an existing `renv.lock`. Every case in the table above is
  optional.

A **degraded** package is taken out of `renv.lock`, stays declared in the study's
`DESCRIPTION`, and is recorded with its reason (section 3). Explicit-mode
snapshot leaves out a declared package that is not installed. This was
confirmed against renv 1.2.4 in hvtiR#157, so "declared, not locked" is a state
renv already supports. This design makes it visible.

`optional_extras()`'s special path (install alone, warn on failure) folds into
the general optional rule. It is removed only after its three tests from
hvtiR#157 are carried over to the general mechanism.

## 2. Heal, then degrade

When the restore or install child fails, each failed package is classified
from the child's output. The existing parsers are `compile_failures()` and
`restore_failures()`. Two patterns seen in the Hsich run are added:
`configuration failed for package 'x'` and `dependency 'x' is not available`.

| Cause | `upgrade = TRUE` (default) | `upgrade = FALSE` (study in revision) |
|---|---|---|
| Compile or configure failure of a locked version | Move the pin to the **newest version in the study's configured repositories**, the binary mirror `binary_repos()` resolves and `setup()` records, using `record_specs()`. A GitHub record stays `user/repo`. | No move. Optional: degrade. Essential: stop, printing the `renv::record()` call (today's behavior). |
| "dependency 'x' is not available" | Install `x` first in the next round, then retry the package | Same. No pin moves. |
| Anything else (network, authentication, disk) | No guessing. Essential: stop with today's diagnosis (`abort_stage()`). Optional: degrade. | Same |

**(decided)** Pins move to the mirror, not to "latest CRAN". A healed pin is then
one the mirror serves as a binary, so a teammate's restore needs no compiler.

**The loop:**

- After each round's moves, the stage reruns.
- A package that fails again **after its pin has moved** is not healed again.
  It degrades, or stops the run if essential.
- A round whose failed set equals the previous round's ends healing.
- The cap is **10 rounds**. Whatever still fails then degrades, or stops the
  run if essential.
- Degrading takes the package's record out of `renv.lock`, then reruns. A
  package that then fails because a degraded one is absent is degraded too, and
  its `because` names the chain.
- **(decided)** Only the pins R forces move, one round at a time, never every
  outdated pin at once, as in the Hsich decision of 2026-10-29.

**Before round 1**, `renv.lock` is copied to
`renv/renv.lock.before-setup-<YYYYMMDD-HHMMSS>`. A shared study's lock is its
history, and healing rewrites it.

**Reporting:** `report_moves()` lists every move by round (package, old → new,
`RemoteSha` changes) and every degraded package with its reason.

## 3. The record, the degraded finish, and recovery

**The record:** `renv/hvtiR-setup.json`. It lives in the study so the team sees
it, not only the person who ran `setup()`, and every run rewrites it.

```json
{
  "run": {"at": "2026-11-05T16:10:00Z", "user": "<login>", "r": "4.6.1",
          "hvtiR": "<version>"},
  "lock_backup": "renv/renv.lock.before-setup-20261105-161000",
  "healed":  [{"package": "vctrs", "from": "0.7.2", "to": "0.7.3",
               "round": 1}],
  "missing": [{"package": "forecast",
               "reason": "dependency 'tseries' is not available",
               "because": "tseries",
               "log": "renv/logs/setup-20261105-161000.log"}],
  "cleanup": {"status": "done", "left": []}
}
```

`user` is the login name, which the file's owner on the share already shows.
Setup logs move from `tempdir()` (`save_setup_log()`) to `renv/logs/` so a
reason can be read after the session ends.

**A degraded finish:** `setup()` finishes and opens the project. The success
line becomes a warning naming the missing packages, saying jobs that load them
stop until they install, and saying to rerun `hvtiR::setup()`, with the record's
path. The returned status carries `attr(, "missing")` and `attr(, "healed")`.

**Recovery is an ordinary rerun.** A missing package is declared but not
locked, so the next `setup()` sees it as wanted (stage 3) and tries it again. If
it installs, the snapshot locks it and it leaves `missing`. The record is a
report, not a control file. Deleting it changes nothing about what `setup()`
does.

**`doctor()`** (R/status.R) reads the record and lists `missing`, with reasons
and the date of the last attempt. With no record it reports nothing new.

**Jobs:** no hvtiRtemplates change. `library(x)` already stops with "there is no
package called 'x'".

## 4. The identity stage: hvtiRutilities::study_setup()

| Stop today | Becomes | Why that is safe |
|---|---|---|
| Template corpus at `template_dir` not found, with cleanup on | **Warning.** Cleanup is skipped and recorded in `attr(, "cleanup")` as skipped, with the reason | Explicit-mode renv no longer scans study code, so template copies cannot reach the lockfile. Cleanup is tidiness, not correctness. |
| Cleanup cannot delete some files | **Warning** listing them. Setup continues, and they are recorded in `attr(, "cleanup")$left` | Same |
| Partial renv: `renv.lock` sound but `renv/activate.R` or the `.Rprofile` source line missing | **Repair:** `renv::activate()` in the child, which writes the scaffolding and leaves the lock byte-identical; then the existing path continues | The lock is untouched; only scaffolding is rebuilt |
| Any other partial renv (lock missing or invalid beside `renv/`) | **Still stops**, naming each piece and a move-aside command | Which piece is the truth is ambiguous, and guessing could destroy a lock |
| `guard_snapshot()`: the lock records another R major.minor | **Still stops** (the message gives `r_upgrade = TRUE` and the R path) | Moving a study to a new R is a decision |
| Malformed `_study.yml`, Tracker ID mismatch, root is a file | **Still stops** (they already name the cause) | Identity errors: carrying on would set up the wrong study |

hvtiR copies `attr(, "cleanup")` into the record's `cleanup` field.

## Testing

**hvtiR**, in `tests/testthat/test-setup.R`, using `local_setup()`. Its
`run_in_study()` mock scripts the child output round by round.

1. A compile failure for a locked pin in round 1, success in round 2: one
   record call against the study's repositories (a GitHub record keeps
   `user/repo`), two restores, and the package listed in `healed`.
2. A package that fails again after moving degrades without further rounds.
3. Two rounds failing on the same set end healing.
4. A package that fails every round degrades after round 10.
5. `upgrade = FALSE` makes no record call. Optional packages degrade, and an
   essential one stops with today's message.
6. A failing family member stops after healing. A failing standard extra
   degrades.
7. "dependency 'x' is not available" installs `x` first in the next round.
8. Degrading removes the record from a real temporary `renv.lock`, and a
   dependent is degraded with `because`.
9. The lock backup exists before round 1 and equals the original.
10. A degraded run writes `renv/hvtiR-setup.json`, warns rather than aborts,
    and calls `open_project()`. A rerun where the package now installs drops it
    from `missing`.
11. `doctor()` lists `missing` from the record, and says nothing new without
    one.
12. The three hvtiR#157 arrow tests, rewritten against the general optional
    rule.

Each group is proved by mutation: disable healing, then degrading, and confirm
the group's tests fail.

**hvtiRutilities**, in its `study_setup()` tests, using the existing seams
(`.study_unlink()`, `.study_rscript()`):

- Undeletable files warn, are listed in `attr(, "cleanup")$left`, and setup
  finishes.
- A missing `template_dir` warns, cleanup is skipped and recorded, and setup
  finishes.
- A sound lock without `activate.R` calls `renv::activate()` in the child, and
  the lock is byte-identical afterwards.
- Each stop that stays still stops.

**Acceptance, on lri (run by John).** Make a scratch study under
`/studies/general/_development/` with a copy of the Hsich R 4.5.1 lockfile from
before 2026-10-29. Under R 4.6.1, `hvtiR::setup(..., adopt = TRUE)` must finish
without help, list the forced pins in `healed`, and list anything still failing
in `missing`. The plan supplies the commands. `HVTIR_E2E` cannot produce a
compile failure, so this run is the acceptance test.

## Rollout

Release order is by `Imports`: hvtiR imports nothing from the family, but calls
hvtiRutilities through `utilities_fn()` with a floor (`UTILITIES_FLOOR`).

1. **hvtiRutilities PR** (section 4), released with a patch bump.
2. **hvtiR PR** (sections 1–3, `doctor()`). `UTILITIES_FLOOR` moves to that
   release in hvtiR's own bump.

⚠️ **Draft hvtiR#177** (guard_session's printed `adopt = TRUE`) also edits
`R/setup.R`. The hvtiR PR branches after John decides #177.

## Out of scope

- A `doctor()` hint inside templates when `library(x)` fails.
- A shared fallback library (approach C).
- Moving a study to a new R without `r_upgrade = TRUE`.
- Healing essential packages beyond the same mirror-pin move. A family member
  that will not build is a release defect, fixed in the family, not by
  `setup()`.
