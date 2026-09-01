# hvtiR

The one-command installer and diagnostic for the HVTI R package family:
`install()`, `update()`, `status()`, `doctor()` and
`members()`. Five exports across five source files, with `cli` as its only import.

**It is the entry point everyone installs through**, so a defect here is the first thing a
new user meets and the last thing they can diagnose. It is also the only package in the
family whose job is other packages: most of its correctness lives in a registry and in how
specs are handed to `pak`, not in computation.

This file is the operational contract and applies in full. It is tool neutral, so Codex and
any other agent read the same rules. Claude Code affordances live in `CLAUDE.md`, which
imports this file.

## Definition of done

- `devtools::test()` passes.
- `devtools::check()` is **0 errors, 0 warnings, 0 notes**. Verified 2026-08-20 at 1.0.0
  (21s with `--no-manual` and vignettes skipped; the manual has its own gate).
- `devtools::document()` has been run and `man/` and `NAMESPACE` are committed with the
  source change.
- A change touching installation is tested through the mocked seam, not by installing.

## The automated gates

Five workflows — **tied with `hvtiPlotR` for the fewest in the family**, where the rest
run six to nine. There is **no lint job and no test-coverage job** here, so nothing
catches a style regression or a coverage drop automatically. Do not read a green PR as
broader assurance than it gives.

| workflow | fails on |
|---|---|
| `R-CMD-check.yaml` | `R CMD check` across platforms |
| `check-manual.yaml` | the PDF manual build |
| `pkgdown.yaml` | the site build |
| `house-style.yaml` | drift between the composed `.claude/house-style.md` and the upstream standard |
| `version-check.yml` | a PR whose `Version:` has not moved past the base branch, or a `DESCRIPTION`/`NEWS.md` version disagreement |

## Rules for this repo

- **Every spec goes to `pak::pak()` in ONE call. This is correctness, not optimisation.**
  `hvtiRlifetables` imports `TemporalHazard (>= 1.2.0)`; resolving it alone sends pak to CRAN,
  where that version does not exist, and the requirement fails. Passing every spec at once
  co-resolves `ehrlinger/TemporalHazard` and satisfies the import. `test-install.R` pins this
  with `expect_length(calls, 1L)` — a change that installs "only what is needed" one package
  at a time reintroduces the bug that shipped in 1.0.0 and was fixed before release.
- **Members resolve from GitHub `main`, never from CRAN.** That is the whole point: the CRAN
  queue must not be able to block the family. A spec that reaches CRAN is a defect.
- **The registry is stored, not derived.** Every member's package name currently matches its
  repository, but they diverged until the 2026-08 renames — `hvtiRpropensity` lived in
  `ehrlinger/hvtiPropensityScores`, `TemporalHazard` in `ehrlinger/temporal_hazard`. Never
  infer a repo from a package name.
- **`R/remote.R` is the single network seam**, isolated so tests can replace it with
  `testthat::local_mocked_bindings()` and never reach the network. Keep it that way: a second
  network call somewhere else makes the suite flaky and slow, and it will not be obvious why.
- **`test-registry-live.R` is the exception that does reach the network**, guarded by
  `skip_on_cran()` and `skip_if_offline()`. It fetches each repo's `DESCRIPTION` and asserts
  the `Package` field matches the registry entry — the gate that catches a renamed repository
  or a wrong mapping. If a member is renamed, this is the test that should fail first.
- **Adding a member is three things, not one**: the registry row in `R/members.R`, the
  dependency edges the installer expands, and a `Remotes:` line in *that member's own*
  `DESCRIPTION` if it depends on another family package from GitHub. The missing `Remotes:`
  line in `hvtiRlifetables` is exactly what made the one-call rule load-bearing.
- **Roxygen markdown is ENABLED** (`Roxygen: list(markdown = TRUE)`), so write markdown in
  roxygen blocks.
  ⚠️ `hvtiRutilities` and `hvtiRtemplates` have no such field and need Rd markup instead.
  Check `DESCRIPTION` before moving a block between repos.
- **There is no `.lintr` here**, so lintr's defaults apply — including the 80-character line
  length. The family uses 80, 120 and 135 in different repos; this one is at the default.
- **`NEWS.md` uses a DCF header** (`Package:` and `Version:` above the first heading), as
  ggRandomForests does. ⚠️ `hvtiRtemplates` uses plain markdown headings with no `Version:`
  line. Match the local file.

## Gotchas

- **A later `update.packages()` can silently downgrade `ggRandomForests`** to its CRAN
  version, because that member exists on CRAN as well as GitHub. `status()` is how
  a user notices; nothing prevents it.
- **`update()` refuses to overwrite a member whose namespace is already loaded**,
  and `force` bypasses that guard. A user reporting "update did nothing" has probably loaded
  the package in the same session.
- `pak` is not a hard dependency — `pak_install()` checks for it and aborts with an install
  hint. Do not promote it to `Imports` to make a test simpler.
- `VignetteBuilder` is **quarto**, not `knitr`.

## Git and versioning

- **Never push to `main`.** Branch, then open a PR and let the maintainer merge.
- **`main` is protected by a GitHub ruleset, and nothing in this repo records that.** A clone
  shows no trace of it, so it is stated here. The ruleset is named `protect main`, is
  identical across all twelve hvtiR repositories, and enforces four rules on the default
  branch: no deletion, no force-push, pull-request-only, and an **automatic Copilot code
  review** on every PR. A rejected push comes from the server, not a local hook.
  ⚠️ It currently requires **zero approvals**. `require_code_owner_review` is set but inert
  because no repository in the family has a `CODEOWNERS` file, so a PR can merge unreviewed.
  Adding `CODEOWNERS` makes that flag live.
- Versions are **straight three digits** (`1.0.0`). Never a `.9000` suffix or a fourth digit.
- **Patch-digit bumps only**, as fixes land. Minor and major are the maintainer's decision.
- Bump `DESCRIPTION`, refresh its `Date`, and add the matching `NEWS.md` entry in the same
  commit — including the DCF `Version:` line at the top of `NEWS.md`.

## Change discipline

1. **Think before coding.** Do not assume, ask. If the request is ambiguous or a name, path
   or signature is uncertain, surface the confusion rather than running with a guess.
2. **Simplicity first.** Write the minimum that solves the stated problem. No speculative
   abstractions.
3. **Surgical changes.** Touch only what the task requires. Do not refactor, reformat or
   re-style adjacent code. Raise nearby problems separately rather than folding them in.
4. **Goal-driven execution.** State what done looks like before starting, and use tests as
   the criterion. Installation changes are proved through the mocked seam.

## Prose

Documentation prose — README, roxygen `@description` and `@details`, release copy — follows
the house voice. This package's README is the family's front door; it is read by people who
have installed nothing yet, so it must not assume any of the other packages.
