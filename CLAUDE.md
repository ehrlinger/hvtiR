# Claude Code specifics

@AGENTS.md

[`AGENTS.md`](https://ehrlinger.github.io/hvtiR/AGENTS.md), imported
above, is the operational contract and applies in full. It is written to
be tool neutral so that Codex and other agents read the same rules. Only
the Claude Code affordances live here.

## Before you touch code

`AGENTS.md` says to orient before editing. In Claude Code the way to do
that is the codemap: it lives in the Obsidian vault under
`Claude/repomaps/` and is read via the `read-codemap` skill
(`/codemap hvtiR`). If the codemap looks stale, say so and offer to
refresh it (`/regenerate-codemap`) rather than working from a guess.

If the vault is not available, say so rather than staying quiet about
it, then orient from the repo itself — this package is small enough to
read: five exports across `R/members.R`, `R/install.R`, `R/remote.R`,
`R/status.R`.

## Testing installation without installing

`AGENTS.md` requires that installation changes be proved through the
mocked seam rather than by running an install. In practice that means
[`testthat::local_mocked_bindings()`](https://testthat.r-lib.org/reference/local_mocked_bindings.html)
over `fetch_description()` in `R/remote.R`, and capturing the specs
handed to `pak_install()`. Do not run
[`hvtiR::install()`](https://ehrlinger.github.io/hvtiR/reference/install.md)
against the live family to check a change — it rewrites the working
library, and the one-call invariant is already pinned by a test.

## Prose

`AGENTS.md` points at the house voice. In Claude Code, apply the
`ehrlinger-writing` skill: it carries the same voice, reader persona and
project context, kept in sync from the vault sources. For documentation
*structure* — README shape, roxygen contract, vignette roles — the
`r-package-style` skill is the companion.
