# Team review, 2026-10-07: six changes across the family

**Written** 2026-10-07.
**Status** Six designs, approved. Designs 1, 2 and 6 have implementation plans. None implemented.
**Repo** `hvtiR` holds the records because the changes span `hvtiRutilities` and
`hvtiRtemplates`, and design 6 also `hvtiRdatabuild`. Each is implemented in the
repository it names.

---

## Where this came from

The biostatistics team's R training on 2026-10-07 reviewed the family as the team
uses it: building and registering a study dataset, scaffolding and running job
templates, and saving their output. The same day a statistician replaced
`built.sas7bdat` in place and could not get the templates to run again. That
session, and the team's feedback from the training, produced these six designs.
The training transcript is not kept here.

## The six designs, in implementation order

| # | design | repo | what it fixes |
|---|---|---|---|
| 1 | [Interactive runs say "render the job"](2026-10-07-render-the-job-design.md) ([plan](2026-10-07-render-the-job-plan.md)) | hvtiRtemplates | a console run stops at the provenance chunk with advice to run `add_job()`, which is wrong |
| 2 | [Dated parquet and `update_manifest()`](2026-10-07-dated-parquet-manifest-design.md) ([plan](2026-10-07-dated-parquet-manifest-plan.md)) | hvtiRutilities, then hvtiRdatabuild and hvtiRtemplates | a rebuilt `built.sas7bdat` stops every template, and the fix is hard to find and can fail silently |
| 3 | [`"built"` as a name for the study dataset](2026-10-07-built-dataset-name-design.md) | hvtiRutilities, hvtiRtemplates | the team calls it `built`; the code calls it `"study"` |
| 4 | [Job names: template first, periods](2026-10-07-job-naming-template-first-design.md) | hvtiRtemplates, hvtiRutilities | jobs sort by subject and the template is at the end of the name |
| 5 | [Figures as PDF and PNG](2026-10-07-figures-pdf-png-design.md) | hvtiRtemplates | most templates save no figure files, and those that do write PNG only |
| 6 | [Ancillary, subset and combined datasets](2026-10-07-ancillary-datasets-design.md) ([plan](2026-10-07-ancillary-datasets-plan.md)) | hvtiRutilities, hvtiRtemplates, hvtiRdatabuild | echoes and labs cannot be joined to the cohort without a hand-written merge, and nothing says when joined or subset data is out of date |

1 is small and removes the most common confusion. 2 is the one blocking work now.
3, 4 and 5 all edit the same job templates, so they go one after another. 6 needs 2
(it uses the dated versions) and is otherwise independent.

## Decisions made

- The current study dataset is always named `built.sas7bdat`. Registering it
  converts it to `built_YYYYMMDD.parquet`, which is what R jobs read. Every
  registered version is kept.
- `update_manifest()` with no arguments registers whatever changed.
- A rebuilt but unregistered `built.sas7bdat` does not stop a job. The job runs on
  the registered parquet, and its report says a newer file is waiting.
- `"built"` and `"study"` both name the study dataset. Templates say `"built"`.
- Jobs are named `<prefix>[.<qualifier>].<subject>.<type>.qmd`.
- Every figure is saved as PDF and PNG by default, with a switch and a selection.
- A console run fails loudly at provenance, saying "render the job".
- Datasets have a kind (built, subset, ancillary, combined) and a key, recorded at
  registration; a job may override the key. A job may join one ancillary dataset to
  its cohort, long or reduced to one row per patient. Out-of-date data runs with a
  note giving the fix, except a stale analysis set in a final render, which stops.

## Raised in the training, not designed here

These came up and are left for later or for the team to decide:

- **A Git strategy.** Until there is one, the provenance sidecar beside each report
  records which data version it used.
- **Team figure standards:** sizes, axis-label defaults, confidence bars or bands,
  numbers-at-risk labels, combined panels.
- **Template structure:** the setup code is hard to follow, and there may be too
  many chunks.
- **The build template** saving a dataset with an option to register it.
- **renv and R versions** across the team, and legacy files that stop renv.
- **Server group permissions** since the LRI server update (not a package matter).
