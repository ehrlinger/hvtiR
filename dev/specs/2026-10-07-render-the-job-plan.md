# Interactive runs say "render the job": implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a job template is run chunk by chunk in the console, its final provenance chunk stops with a message that says to render the job, instead of advising `add_job()`.

**Architecture:** One early check at the top of `.embed_provenance()` in `hvtiRtemplates/R/provenance.R`. A console run reaches that function with `input = NULL` (the template passes `knitr::current_input(dir = TRUE)`, which is `NULL` outside a knit), so the check stops with a classed condition before any study or Quarto state is read. A render outside the study's Quarto project still reaches the existing hooks message unchanged. No template file changes.

**Tech Stack:** R, testthat edition 3, roxygen2 with **Rd markup** (not markdown), Quarto (for the existing render tests only).

**Spec:** `hvtiR/dev/specs/2026-10-07-render-the-job-design.md`.

## Global Constraints

- Repository: `ehrlinger/hvtiRtemplates`. Branch from `main`; never push to `main`.
- Roxygen is **Rd markup**: `\code{}`, `\strong{}`, `\link{}`. Backticks and `**` land literally.
- Line length 135 (`.lintr`). `lintr::lint_package()` must be clean.
- No new dependency. In particular **no `rstudioapi`**: `R/open-job.R` avoids it on purpose.
- The condition class is exactly `hvtiRtemplates_not_rendered`, built the way `.warn_deprecated()` builds `hvtiRtemplates_deprecated` (`R/templates.R:175`): `structure(class = c(<class>, "error", "condition"), list(message = ..., call = NULL))`.
- The message contains the literal phrase `render the job` and names `hvtiRtemplates::render_job()`.
- The existing hooks message, `This managed job must be rendered through its configured Quarto study project. Run add_job() to install the hooks.`, is unchanged.
- `NEWS.md`: a bullet under the existing `# hvtiRtemplates (unreleased)` heading. Do **not** touch `Version:`.
- Definition of done: `devtools::test()` passes; `devtools::check()` 0 errors, 0 warnings, 0 notes; `devtools::document()` run with `man/` and `NAMESPACE` committed.
- The planning container had no R. Run every command below on a machine with R, `devtools` and the Quarto CLI.

## File structure

| file | change | responsibility |
|---|---|---|
| `R/provenance.R` | modify | add `.not_rendered_abort()`; call it first in `.embed_provenance()` |
| `tests/testthat/test-provenance-publication.R` | modify | three tests: the console-run stop, that it reads no study state, and that the hooks message is unchanged |
| `R/render-job.R` | modify | one `@details` paragraph telling a reader what a console run does |
| `man/render_job.Rd` | regenerate | from the roxygen change |
| `NEWS.md` | modify | one bullet |

---

### Task 1: Stop a console run with "render the job"

**Files:**
- Modify: `R/provenance.R` (insert a helper above `.embed_provenance()`, currently line 876; add one line as the function's first statement)
- Test: `tests/testthat/test-provenance-publication.R` (append; this file already defines `make_hook_study()` at line 1)

**Interfaces:**
- Consumes: `.embed_provenance(input, data, artifacts = list(), extra = list(), cfg = hvtiRutilities::study_config())`, unchanged signature.
- Produces: `.not_rendered_abort()`, internal, no arguments, never returns; signals a condition of class `c("hvtiRtemplates_not_rendered", "error", "condition")`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-provenance-publication.R`:

```r
test_that("a console run stops at provenance and says to render the job", {
  # The template passes knitr::current_input(dir = TRUE), which is NULL when a
  # study author steps through chunks in the console rather than rendering.
  err <- expect_error(.embed_provenance(NULL, data = list()), class = "hvtiRtemplates_not_rendered")
  expect_match(conditionMessage(err), "render the job", fixed = TRUE)
  expect_match(conditionMessage(err), "hvtiRtemplates::render_job()", fixed = TRUE)
  expect_no_match(conditionMessage(err), "add_job", fixed = TRUE)
})

test_that("a console run stops before the study configuration is read", {
  # cfg is a promise. Forcing it from a working directory outside the study
  # would stop with study_config()'s own error and hide the advice to render.
  expect_error(
    .embed_provenance(NULL, data = list(), cfg = stop("cfg was read")),
    class = "hvtiRtemplates_not_rendered"
  )
})

test_that("a render outside the study project keeps the hooks message", {
  root <- make_hook_study(withr::local_tempdir())
  withr::local_envvar(QUARTO_PROJECT_DIR = NA)
  input <- file.path(root, "cohort-eda-dc-general.qmd")
  writeLines(c("---", "format: html", "---"), input)

  err <- expect_error(.embed_provenance(input, data = list(), cfg = hvtiRutilities::study_config(root)))
  expect_false(inherits(err, "hvtiRtemplates_not_rendered"))
  expect_match(conditionMessage(err), "must be rendered through its configured Quarto study project", fixed = TRUE)
})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "provenance-publication")'`

Expected: the first two tests FAIL. The first fails because the condition is not of class `hvtiRtemplates_not_rendered`; the second fails with `cfg was read`, because today the function forces `cfg` on its first line. The third test PASSES already; it guards the behaviour that must not change.

- [ ] **Step 3: Write the implementation**

In `R/provenance.R`, insert directly above `.embed_provenance <- function(`:

```r
# A console run, a study author stepping through a job's chunks rather than
# rendering it, reaches the provenance chunk with no render input: the template
# passes knitr::current_input(dir = TRUE), which is NULL outside a knit. There
# is then no output to attach provenance to. Say so, and say what to do, before
# the hooks check below, whose advice (add_job()) is right only for a render
# outside the study's Quarto project. The check must also come before `cfg` is
# forced, or a console run from outside the study would see study_config()'s
# error instead.
#
# Checked 2026-10-07 for the same console-run failure, and needing no change:
# the edit-marker and set-declaration guards in every template (both skip on a
# NULL input), .guard_partial() (returns early on a NULL input; pinned in
# test-partial-render.R) and .attach_handoff_lineage() (attaches an attribute
# and reads no render state).
.not_rendered_abort <- function() {
  stop(structure(
    class = c("hvtiRtemplates_not_rendered", "error", "condition"),
    list(
      message = paste0(
        "This job was run in the console, so its provenance cannot be recorded. ",
        "Every chunk above this one ran normally. To produce the report and its provenance, ",
        "render the job: click Render, or run hvtiRtemplates::render_job() on this job's .qmd file."
      ),
      call = NULL
    )
  ))
}
```

Then make the first statement of `.embed_provenance()` the check, so the function begins:

```r
.embed_provenance <- function(input, data, artifacts = list(), extra = list(), cfg = hvtiRutilities::study_config()) {
  if (is.null(input)) .not_rendered_abort()
  root <- normalizePath(cfg$root, winslash = "/", mustWork = TRUE)
```

Leave every other line of the function as it is.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `Rscript -e 'devtools::test(filter = "provenance-publication")'`

Expected: all tests in the file PASS, the three new ones included.

- [ ] **Step 5: Run the template provenance contract tests**

The template tests mock `.embed_provenance()` and assert the shape of every template's final chunk. They must still pass, since no template changed.

Run: `Rscript -e 'devtools::test(filter = "template-provenance|partial-render")'`

Expected: PASS, with the same skip count as before the change (Quarto-dependent tests skip only where the Quarto CLI is absent).

- [ ] **Step 6: Commit**

```bash
git add R/provenance.R tests/testthat/test-provenance-publication.R
git commit -m "Tell a console run of a job to render it, not to run add_job()"
```

---

### Task 2: Document it and record it in NEWS

**Files:**
- Modify: `R/render-job.R` (the roxygen block above `render_job()`; add one paragraph to `@details`, after the paragraph that begins "Jobs scaffolded by")
- Regenerate: `man/render_job.Rd`
- Modify: `NEWS.md` (under `# hvtiRtemplates (unreleased)`, line 1)

**Interfaces:**
- Consumes: the condition class and message from Task 1.
- Produces: nothing code depends on.

- [ ] **Step 1: Add the paragraph to `render_job()`'s documentation**

In `R/render-job.R`, after the `@details` paragraph that begins `#' Jobs scaffolded by \code{\link{add_job}} capture their data provenance while`, and before the paragraph that begins `#' One job renders at a time`, insert:

```r
#' Running a job's chunks one at a time in the console is a good way to work
#' through it, and every chunk runs as it would in a render except the last.
#' That chunk records provenance, which needs a render, so a console run stops
#' there with an error of class \code{hvtiRtemplates_not_rendered} that says to
#' render the job. Everything computed above it is still in the session.
#'
```

- [ ] **Step 2: Regenerate the documentation**

Run: `Rscript -e 'devtools::document()'`

Expected: `man/render_job.Rd` changes; `NAMESPACE` does not.

- [ ] **Step 3: Check the rendered help reads correctly**

Run: `Rscript -e 'tools::Rd2txt("man/render_job.Rd")' | grep -A5 "console"`

Expected: the paragraph prints, with `hvtiRtemplates_not_rendered` in code quotes and no literal backslash markup.

- [ ] **Step 4: Add the NEWS bullet**

In `NEWS.md`, directly under the `# hvtiRtemplates (unreleased)` heading and its blank line, insert as the first bullet:

```markdown
* Running a job's chunks in the console no longer ends with advice to run
  `add_job()`. The final provenance chunk, the one step that needs a render, now
  stops with an error of class `hvtiRtemplates_not_rendered` saying that every
  chunk above it ran and that the job should be rendered, with
  `hvtiRtemplates::render_job()` or the Render button. A render outside the
  study's Quarto project keeps the existing message about installing the hooks.

```

- [ ] **Step 5: Commit**

```bash
git add R/render-job.R man/render_job.Rd NEWS.md
git commit -m "Document what a console run of a job does"
```

---

### Task 3: Run the gates

**Files:** none changed unless a gate fails.

- [ ] **Step 1: Lint**

Run: `Rscript -e 'lintr::lint_package()'`

Expected: no lints. If a new line exceeds 135 characters, wrap it and re-run.

- [ ] **Step 2: Full test suite**

Run: `Rscript -e 'devtools::test()'`

Expected: `FAIL 0`. Read the `SKIP` count and compare it with `main`; it must not rise.

- [ ] **Step 3: R CMD check**

Run: `Rscript -e 'devtools::check(document = FALSE, manual = FALSE)'`

Expected: 0 errors, 0 warnings, 0 notes.

- [ ] **Step 4: Check the docs are current**

Run: `Rscript -e 'roxygen2::roxygenise()' && git status --porcelain man NAMESPACE DESCRIPTION`

Expected: no output. The `docs-current` CI job runs the same check.

- [ ] **Step 5: See it work in a real console run**

In RStudio, open any scaffolded job in a test study and use **Run All**. Expected: every chunk runs, and the last stops with the "render the job" message. Then click **Render**: the report and its `.provenance.json` are written as before.

- [ ] **Step 6: Push and open the pull request**

```bash
git push -u origin <branch>
```

Open a pull request against `main` that links the spec, `hvtiR/dev/specs/2026-10-07-render-the-job-design.md`.

---

## Self-review

- **Spec coverage.** Section 2's two cases: Task 1 (the console-run stop, and the unchanged hooks message). Section 2's wording: Task 1, Step 3. Section 3's audit: done while planning, recorded in the code comment (Task 1, Step 3) and in the spec. Section 4's tests: Task 1, Step 1. Section 5 (out of scope): nothing to build.
- **Placeholders.** `<branch>` in Task 3, Step 6 is the implementer's branch name, chosen at execution.
- **Names.** `.not_rendered_abort()` and `hvtiRtemplates_not_rendered` are spelled the same in every task.
