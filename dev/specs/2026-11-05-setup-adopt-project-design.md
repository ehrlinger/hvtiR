# Adopting a study from its own RStudio project

Status: approved, 2026-11-05. Decisions marked **(decided)** are John's.

## The problem

The way a study author will usually start (**decided**: this is the default path,
not an edge case) is to open an RStudio project in an existing legacy study
folder and set the study up from there. Today that fails:

```r
hvtiR::setup(study = "…", study_tracker_id = 1234L)
#> No study encloses /studies/…, so setup() has no target.
#> ℹ Pass `root`, the directory to set the study up in.
```

With `root = NULL`, `setup()` looks for a `_study.yml` at or above the working
directory. A legacy study has none, so `setup()` stops. The session guard is not
what blocks this: in a folder with no renv, `renv_state()` is not `"active"` and
the session library lies in the user's home, so `guard_session()` returns. The
working call, `setup(root = ".", adopt = TRUE, …)`, is correct but nobody
remembers it.

The default is cautious for a reason. Adopting sets `cleanup = TRUE`, which
deletes `tp.*` files, `binder.summaries.doc` and exact template copies. A silent
"use the working directory" could run that on the wrong folder, such as a project
opened at `30_analyses/`.

## Decision: project-aware `setup()` (decided)

The alternatives were a separate `hvtiR::adopt()` verb and an RStudio addin.
They were turned down in favor of one entry point. `setup()` stays the one
command a study needs, and it learns to recognize the project it is run from.

### Target resolution when `root = NULL`

In order:

1. **A `_study.yml` at or above the working directory.** That study is the
   target, as today. An enclosing study always wins over a project inside it.
2. **The working directory is a project root.** This holds when it contains a
   `*.Rproj` file, or when it equals `rstudioapi::getActiveProject()`, if RStudio
   is available. That folder is the *candidate* for adoption (below).
3. **Neither.** `abort_no_study()`, as today, with the wording revised (see
   Documentation).

A helper `project_candidate()` (`@noRd`) returns the candidate path or `NULL`.
It looks only at the working directory itself and never walks up. A project one
level up is not the session's project.

### Refusals, checked before any prompt

- **The candidate's name is a study subfolder.** This is any of `00_datasets`,
  `10_descriptive`, `20_distributions`, `30_analyses`, `40_graphs`,
  `50_documents`, `90_estimates`, or their bare legacy names (`datasets`,
  `descriptive`, …). Such a project was opened one level too deep. The error
  names the parent folder as the likely study.
- **The candidate holds a `DESCRIPTION` without `Type: Project`.** That is a
  package, not a study. `study_setup()` already refuses this, but only after
  the prompt. Checking here means the user is never asked to adopt a package.

The folder list is copied into hvtiR, because `hvtiRutilities:::.study_folders()`
is internal. A test asserts that the copy equals the internal list, so that a
new
folder in hvtiRutilities makes the test fail instead of letting the copy drift.

### Confirming the adoption

- **Interactive, `adopt` not passed.** One yes/no prompt, defaulting to **No**:

  > `/studies/…/example` has no `_study.yml`. Adopt it as study "Title"
  > (Study Tracker 1234)? Adopting deletes the `tp.*` files, `binder.summaries.doc`
  > and exact template copies it holds; pass `cleanup = FALSE` to keep them.

  Yes continues exactly as `setup(root = <candidate>, adopt = TRUE, …)`. No (or
  `NA`, cancel) stops with no change. The prompt says "keep them" only when
  `cleanup` is not already `FALSE` in `...`. When it is `FALSE`, the cleanup
  sentence is left out.
- **`adopt = TRUE` passed.** No prompt, because the caller has already asked. A
  `cli` info line names the target folder before anything is written.
- **Non-interactive.** `setup()` never adopts on its own. It stops with the
  exact call to run, built as `guard_session()` builds its command
  (`deparse1(as.call(...))`, with `...` quoted back):
  `hvtiR::setup(root = "<candidate>", study = …, study_tracker_id = …, adopt = TRUE)`.

The prompt goes through a seam, `ask_adopt_project()`, wrapping
`utils::askYesNo()`, and `interactive()` goes through one too. Tests replace both
with `testthat::local_mocked_bindings()`. This mirrors
`.study_ask_adopt()` / `.study_interactive()` in hvtiRutilities.

### Order inside `setup()`

Target resolution, the refusals and the prompt all run **before**
`guard_session()` and before anything that installs or writes (the renv
install, `set_workspace_prefs()`, `utilities_fn()` loading hvtiRutilities). The
guard then receives the resolved `root`, so its check and the command it quotes
both name the candidate. A user who answers No has had nothing changed,
including RStudio preferences.

The closing `rstudioapi::openProject(root)` reopens the project the user is
already in. That is the restart into the now-active renv, and nothing changes
there.

## Out of scope

- **A legacy folder whose old `renv::init()` left a `.Rprofile` that activates
  renv.** Opening that project makes renv active, so `guard_session()` blocks.
  Its current message (close the project, run from outside) stays. A follow-up
  could detect "renv active, no `_study.yml`" and say what to do.
- **A count of the files cleanup would delete, in the prompt.** That needs an
  exported preview from hvtiRutilities, plus a release in that package first.
  Revisit if users ask for it.
- **No change to hvtiRutilities.** `study_setup()` keeps its own adopt prompt
  for a matching `_study.yml`. hvtiR passes it an explicit `root` and
  `adopt = TRUE`, so that prompt never fires on this path.

## Documentation

Because this is the default path, it leads the documentation:

- `setup()`'s roxygen `@description` and `@param root` describe the in-project
  path first. Passing `root` from a session outside any project is the
  alternative, and is still needed when renv is already active.
- `abort_no_study()`: when no candidate exists either, the message says to open
  the study's folder as an RStudio project (File > New Project > Existing
  Directory) and rerun, or to pass `root`.
- The getting-started material that shows `setup(root = …)` (README, the
  start-here and study-environment articles) leads with "open the study folder
  as a project, then `hvtiR::setup(study, study_tracker_id)`". Those files are
  being edited on open branches (`docs/start-here`, `docs/study-environment`,
  `docs/quick-start-172-173`). The implementation plan sequences the doc edits
  against those branches instead of conflicting with them.

## Tests

In `tests/testthat/test-setup.R`, using temporary folders and the seams above.
Each test stops before the install, either by mocking `utilities_fn()` or
by asserting the resolved arguments it receives.

1. A folder with a `.Rproj` and no `_study.yml`, interactive, prompt Yes:
   `study_setup` is called with `root = <folder>` and `adopt = TRUE`.
2. The same, prompt No: an error with no change, and `set_workspace_prefs()` is
   not called.
3. The same, `adopt = TRUE` passed: no prompt, and the info line names the
   folder.
4. The same, non-interactive: an error whose message contains the full
   `setup(root = …, adopt = TRUE)` call.
5. A candidate named `30_analyses` (and a bare `analyses`) is refused before the
   prompt, and the error names the parent.
6. A candidate holding a package `DESCRIPTION` is refused before the prompt.
7. An enclosing `_study.yml` above a nested `.Rproj` still resolves to the
   enclosing study, with no prompt.
8. No `.Rproj`, no study: `abort_no_study()`, as today.
9. The copied folder list equals `hvtiRutilities:::.study_folders()`, both names
   and values.

Prove tests 1–4 by mutation: revert `project_candidate()` to return `NULL` and
confirm they fail.

## Release

hvtiR patch bump (the maintainer chooses when). The change needs a `news/`
fragment. hvtiRutilities has no floor change.
