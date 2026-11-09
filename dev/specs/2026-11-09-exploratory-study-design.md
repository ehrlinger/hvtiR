# Exploratory studies derived from a registered study

Status: approved, 2026-11-09. Decisions marked **(decided)** are John's.

## The problem

Every study the family sets up needs a Study Tracker record. `hvtiR::setup()`
and `hvtiRutilities::study_setup()` both require `study_tracker_id`, one
positive integer, and refuse to run without it. Exploration does not fit that
shape. An analyst wants to try an idea off a registered study (a new outcome,
a different cohort cut) before anyone decides it is a study of its own. Today
the choices are:

- reuse the parent's ID, which files the exploration's checkpoints under the
  parent in `CORR_STUDIES` as though they were the parent's work, or
- invent an integer, which looks like a real Tracker ID and is not one.

Nothing checks `study_tracker_id` against the live Tracker. So neither choice
fails at once. Each one quietly puts a wrong record into `_study.yml`.

## What reads the Tracker ID today

Measured on `main` on 2026-11-09. Every reader coerces the value to an integer:

| Repo | Site | Use |
|---|---|---|
| hvtiRutilities | `R/study_setup.R` | validates one positive integer and writes it |
| hvtiRutilities | `R/study_update_identity.R` | refuses a record whose ID differs from the file's |
| hvtiRutilities | `R/checkpoint_study.R` | `as.integer(st_id %||% study_tracker_id)`, and stops if it is invalid |
| hvtiRutilities | `R/study_status.R` | tells the user to add the ID when it is missing |
| hvtiR | `R/setup.R` | passes it through, and quotes it in the guard and adopt prompt |
| qhsprograms | `execs/cmd/study_setup/ado.py`, `bridge.R` | integer, and names the ADO repo `st-<id>-…` |

## Decisions

1. **The exploration carries a provisional ID, kept in its own field.**
   **(decided)** `study_tracker_id` stays absent until the Tracker issues a
   real one. Putting a string in `study_tracker_id` would break all six integer
   readers above, across three repositories and two languages.
2. **It starts from an empty layout.** **(decided)** Nothing is copied or
   linked from the parent: no data, no `renv.lock`, no code. Only the link
   back to the parent is recorded.
3. **The entry point is `setup(derived_from = )`.** **(decided)** No new
   export.
4. **The ID format is `x<parent>-<workspace8>`.** **(decided)** It needs no
   central counter.
5. **Checkpoints are local-only until promotion.** **(decided)**

## `_study.yml`

An exploration:

```yaml
study: "Lactate trajectories (exploration)"
derived_from: 1234
provisional_id: x1234-3f9a2c1b
workspace_id: 3f9a2c1b-7d4e-4a10-9b2f-0c8e5d6a7b31
```

- `derived_from` is the parent's Study Tracker ID, one positive integer,
  validated as `study_tracker_id` is. It stays after promotion as permanent
  lineage.
- `workspace_id` is a new UUID, written only when one is absent.
  ⚠️ `study_setup()` writes no `workspace_id` today; only `checkpoint_study.R`
  reads one. An exploration therefore creates its own, and `provisional_id`
  takes its first eight hex digits.
- `provisional_id` is `x`, the parent ID, `-`, and those eight digits. It is
  written once and never recomputed, so a later edit to `workspace_id` cannot
  change it.

A registered study is unchanged. It has `study_tracker_id` and no
`derived_from` or `provisional_id`.

A promoted study has `study_tracker_id` and `derived_from`, with no
`provisional_id`.

There are three states. `study_config()` rejects a file that has
`provisional_id` or `derived_from` but does not match one of them, and names
the fields it found. A file that has none of the three fields keeps today's
behaviour. Legacy `_study.yml` files without an ID exist, and `study_status()`
already advises on them; rejecting them would break those studies.

| state | `study_tracker_id` | `provisional_id` | `derived_from` |
|---|---|---|---|
| registered | yes | no | no |
| provisional | no | yes | yes |
| promoted | yes | no | yes |

## Changes

### hvtiRutilities (ships first)

- **`study_setup()`** takes exactly one of `study_tracker_id` or `derived_from`.
  It stops if given both or neither. With `derived_from`, it writes the
  provisional block and the usual empty numbered layout.

  If you rerun it, or adopt a folder that already has a `provisional_id`, it
  keeps that ID and does not mint a new one. Rerunning with `study_tracker_id`
  on a provisional study stops and points to `study_promote()`. It never
  promotes as a side effect.
- **`checkpoint_study.R`** accepts a provisional study. It returns
  `st_id = NULL`, `provisional_id`, and `provisional = TRUE`. With neither ID it
  still stops.
- **`study_checkpoint()` and `study_close()`** on a provisional study commit and
  tag in `.checkpoint/repo/`, as they do today with no `checkpoint: remote:`.
  The outbox already holds entries back for an unverified identity, and uses
  the same mechanism here: `delivery$git` stays `pending` with
  `delivery$reason: provisional`, and nothing is pushed. The entry's `st_id`
  holds the provisional ID. Its only consumer is the commit-message header.
- **`study_checkpoint_push()`** refuses a provisional study. It names
  `study_promote()` as the way forward.
- **`study_status()`** reports "exploratory, derived from ST 1234, provisional
  ID x1234-3f9a2c1b" in place of its missing-ID advice.
- **New `study_promote(study_tracker_id, start = ".")`.** It refuses a study
  that is not provisional and refuses an invalid ID. It writes
  `study_tracker_id`, removes `provisional_id`, and keeps `derived_from` and
  `workspace_id`. It returns the outbox entries that are now pushable, so the
  next `study_checkpoint_push()` sends them.

  It does not rename existing tags. Checkpoint tags carry their kind and
  sequence, not the ID.

  It warns, but does not stop, when the new ID equals `derived_from`. That
  usually means the exploration is being folded back into the parent, which may
  be intended.
- `study_update_identity()` is unchanged. Its rule that the ID must match is
  what stops a folder from being silently pointed at another study, and
  promotion has its own verb so that rule can stay.

### hvtiR (after hvtiRutilities)

- **`setup()`** gains `derived_from = NULL`, placed last before `...` and not
  after `study_tracker_id`. Putting it there would move `root` to a different
  position and break `setup("t", 7L, "/path")`. `study_setup()` likewise gets
  it after `r_upgrade`.

  `setup()` requires exactly one of the two IDs before doing any work, and
  passes the one it gets to `study_setup()`. `study_tracker_id` now defaults to
  `NULL`, and existing positional calls still work.
- `setup_command()`, `guard_session()` and the adopt prompt quote whichever ID
  was given. The adopt prompt reads "(exploration of ST 1234)" for a provisional
  study.
- The `Imports` floor on hvtiRutilities moves to the release that adds
  `derived_from`, in this package's own bump, because it relies on that
  release.
- `vignette("start-here")` gets a short section on starting an exploration and
  promoting it.

### qhsprograms (separate, its own ADO PR)

- `study-setup` gains `--derived-from N`, mutually exclusive with the Tracker ID
  argument. `bridge.R` passes it through.
- `ado.py` creates no `CORR_STUDIES` repository for a provisional study. The
  repository is created on the first push after promotion, as it is today for a
  registered study.

## Errors

| Situation | Behaviour |
|---|---|
| `setup()` or `study_setup()` given both IDs, or neither | stop, naming both arguments |
| `derived_from` not one positive whole number | stop, as for `study_tracker_id` |
| `study_setup(study_tracker_id = N)` on a provisional study | stop, pointing to `study_promote(N)` |
| `study_promote()` on a registered or promoted study | stop: already has Study Tracker ID … |
| `study_checkpoint_push()` on a provisional study | stop, pointing to `study_promote()` |
| `provisional_id` or `derived_from` present outside the three states | `study_config()` stops, naming the fields found |
| no ID field at all (legacy) | unchanged: `study_status()` advises, as today |

## Tests

- **hvtiRutilities.** Fixture `_study.yml` files for each of the three states,
  and one for each invalid combination:
  - `study_setup()` mints the ID once and keeps it on rerun and adopt.
  - Checkpoint and close on a provisional study, even with a remote set, leave
    the entry `pending` with reason `provisional`.
  - `study_promote()` moves provisional → promoted and refuses the other two
    states.
  - `study_status()` reports the exploratory state.
- **hvtiR.** Through the mocked seam only, with no live install:
  - `derived_from` reaches `study_setup()`.
  - Both IDs, or neither, stop before any install.
  - The one-`pak::pak()`-call test still passes.
  - The quoted command names `derived_from`.

## Out of scope

- Checking the parent ID against the live Tracker. No reader does that today,
  and the StudyTracker Workspace API is not built.
- Inheriting anything from the parent. If that is wanted later, it would be an
  opt-in argument.
- Telling the Tracker about the lineage. `derived_from` is recorded so that the
  Workspace API can read it when it exists.
