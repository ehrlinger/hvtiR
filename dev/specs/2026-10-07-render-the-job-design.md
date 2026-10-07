# Interactive runs say "render the job"

**Written** 2026-10-07.
**Status** Design, approved. Not implemented.
**Repo** `hvtiRtemplates`. Recorded in `hvtiR` with four sibling designs from the
same review, the 2026-10-07 biostatistics team training; see
[the overview](2026-10-07-team-review-overview.md).
**Order** First of five. Small and self-contained.

---

## 1. The problem

A job template is written to be rendered, but people step through it chunk by
chunk in the console, and that is how most of them learn it. When they reach the
last chunk, the provenance chunk, the run stops with:

> This managed job must be rendered through its configured Quarto study project.
> Run add_job() to install the hooks.

The stop is right. The advice is wrong. The job already exists, so `add_job()`
refuses to run again, and the hooks are almost always installed. The real cause is
that nobody rendered the job. In the training this was described in advance ("when
you get down here to provenance, it will fail"), which is a warning, not an
explanation.

The message comes from `.embed_provenance()` in `hvtiRtemplates/R/provenance.R`
(about line 876). It tests `QUARTO_PROJECT_DIR` first, and that variable is unset
in two different situations that need different advice:

| situation | `knitr::current_input()` | `QUARTO_PROJECT_DIR` | right advice |
|---|---|---|---|
| chunks run in the console | `NULL` | unset | render the job |
| rendered outside the study's Quarto project | a path | unset or another project | install the hooks / render from the study |

## 2. The change

`.embed_provenance()` tells these apart before any other check.

- **Not rendering** (`knitr::current_input()` is `NULL`). Stop with a condition of
  class `hvtiRtemplates_not_rendered`, worded:

  > This job was run in the console, so its provenance cannot be recorded. Every
  > chunk above this one ran normally. To produce the report and its provenance,
  > render the job: click Render, or run hvtiRtemplates::render_job() on this
  > job's .qmd file.

  It names the package's own `render_job()` rather than `quarto::quarto_render()`,
  because `render_job()` is the documented way to render a job. It does not name
  the file. A console run has no render input to read the name from, and the
  package deliberately takes no dependency on `rstudioapi` (`R/open-job.R` says
  so), so the message never guesses a name. *Amended 2026-10-07, while writing
  the plan: the first draft read the name through `rstudioapi`.*

- **Rendering without the hooks.** Keep today's message. It is correct there.

It stays a `stop()`. The user asked for a loud failure, and it is the last chunk:
every result above it is already in the session.

## 3. Other render-only steps

The same cause, a console run, can trip earlier steps that assume a render. Audit
every template for calls that need a render, and give each the same classed
condition and wording when it fails for this reason. Known candidates:

- `.guard_partial(knitr::current_input())`, called near the top of every job;
- `.attach_handoff_lineage()`, which takes `.provenance_data`;
- the filename check that reads `knitr::current_input()` (about line 156 of
  `ac.qmd`), which the templates already guard for `NULL`.

A step that already handles `NULL` gracefully is left alone. The audit records
which steps were checked, so the next template author knows the rule.

*Audit result, 2026-10-07, while writing the plan:* none of them needs a change.
The edit-marker and set-declaration guards in every template skip when
`knitr::current_input()` is `NULL`; `.guard_partial()` returns early on a `NULL`
input, and `test-partial-render.R` already pins that; `.attach_handoff_lineage()`
only attaches an attribute and reads no render state. `.embed_provenance()` is the
only step a console run trips.

## 4. Tests

- `.embed_provenance()` with `knitr::current_input()` mocked to `NULL` signals
  `hvtiRtemplates_not_rendered`, and its message contains "render the job".
- With a current input but no `QUARTO_PROJECT_DIR`, the existing hooks message is
  unchanged.
- A console run stops before the study configuration is read, so it gives this
  message even when R's working directory is outside the study.
- Section 3 found no other step to change, so it adds no test; `.guard_partial(NULL)`
  is already pinned in `test-partial-render.R`.

## 5. Out of scope

Making provenance work interactively. A console run has no render identity and no
output file to attach a sidecar to, so the record would be a fiction.
