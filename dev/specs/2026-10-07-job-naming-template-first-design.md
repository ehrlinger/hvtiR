# Job names: template first, periods between fields

**Written** 2026-10-07.
**Status** Design, approved. Not implemented.
**Repos** `hvtiRtemplates` (`add_job()`, the templates, the catalog display) and
`hvtiRutilities` (`job_census()`). Recorded in `hvtiR`; see
[the overview](2026-10-07-team-review-overview.md).
**Order** Fourth of five.

---

## 1. The problem

`add_job()` names a job `<subject>-<type>-<prefix>[-<qualifier>].qmd`:

```
death-hz-ac.qmd
cohort-eda-dp-trends.qmd
death-boot-bl.qmd   death-boot-bl-runner.R
```

Sorted by name, a study's jobs group by subject, and the template, the part people
look for first, is at the end. The team's SAS jobs put the template first with
periods (`hm.dead...`). In the training they asked for the prefixes back at the
front, with periods, sorting by template, then subject, then type.

## 2. The new form

```
<prefix>[.<qualifier>].<subject>.<type>.qmd
<prefix>[.<qualifier>].<subject>.<type>.runner.R
```

```
ac.death.hz.qmd
dp.trends.cohort.eda.qmd
bl.death.boot.qmd   bl.death.boot.runner.R
```

It parses without ambiguity. `subject`, `type` and `qualifier` already match
`^[A-Za-z0-9_]+$`, so none contains a period. Three fields before `.qmd` is a
template with no qualifier; four is one with a qualifier. Which prefixes carry a
qualifier is known from the catalog.

## 3. What changes

**`add_job()`** (`hvtiRtemplates/R/add-job.R`, `.job_path()`) writes the new form.
Its documentation, examples and the runner name follow.

**The filename check in every template.** Each job splits its own filename and
stops if the fields disagree with its `SUBJECT` and `TYPE` lines, so a renamed job
cannot write into another set's folder. The check is in 34 templates (for example
`ac.qmd` around line 156, splitting on `-`). It is moved into one internal
function, which accepts **both** the new period form and the old dash form, and
each template calls it. This is the only way existing jobs keep rendering.

**The catalog display.** `template_list()` and `template_catalog()` show qualified
templates as `dp.trends`, and `add_job("dp.trends", ...)` is accepted. The dash
spelling `"dp-trends"` is still accepted as input.

**`job_census()`** (`hvtiRutilities/R/job_names.R`). A new `scaffolded_dotted`
pattern runs before `legacy`, which otherwise claims any dotted name as
`<prefix>.<anything>`. It claims a name only when all of these hold:

- the extension is `.qmd`, or the name ends `.runner.R`;
- the first field is a known prefix (`hvti_taxonomy()` or `hvti_prefix_folds()`);
- there are three fields, or four when that prefix carries a qualifier.

The residual risk is a legacy `.qmd` that happens to fit that shape exactly; it is
read as scaffolded. The pattern-order test in `test-job-names.R` is extended.

## 4. What does not change

- **Results folders** stay `estimates/<subject>-<type>/` and
  `graphs/<subject>-<type>/`, so a chain of jobs that has already run still finds
  its files.
- **Existing jobs** are not renamed. A rename helper is not designed; add it later
  if the team wants old studies converted.
- **Periods versus hyphens elsewhere** (template file names inside the package,
  folder names) are untouched.

## 5. Tests

- `add_job("ac", subject = "death", type = "hz")` writes `ac.death.hz.qmd`.
- A qualified template writes four fields; its runner ends `.runner.R`.
- The shared filename check accepts `ac.death.hz.qmd` and `death-hz-ac.qmd`, and
  stops on a name whose fields disagree with `SUBJECT` or `TYPE`.
- `job_census()` reads the new form as scaffolded, and still reads SAS legacy
  names (`hm.dead.sas`) as legacy.
- `template_list()` shows `dp.trends`.
