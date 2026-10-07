# `"built"` as a second name for the `"study"` dataset

**Written** 2026-10-07.
**Status** Design, approved. Not implemented.
**Repos** `hvtiRutilities` (the name), then `hvtiRtemplates` (the templates).
Recorded in `hvtiR`; see [the overview](2026-10-07-team-review-overview.md).
**Order** Third of five.

---

## 1. The problem

`hvtiRutilities` calls the study's main dataset `"study"`. It is the default
`dataset =` argument throughout, and it means "the file named by `built:` in
`_study.yml`". Every job template repeats it in its "edit study choices" chunk:

```r
# EDIT: the registered dataset this job reads ("study" is the built dataset).
DATASET <- "study"
```

The team's SAS templates have always called this dataset `built`. In the training,
people asked to change the word, and a new team member read "study" as the study
number. The presenter deferred a rename. This design makes it a choice instead.

## 2. Options considered

- **A second accepted name (chosen).** `"built"` and `"study"` both mean the
  default dataset, everywhere.
- **A per-study setting in `_study.yml`.** Rejected: every study picks one word,
  and a template copied between studies can break on it.
- **An R `options()` setting.** Rejected: a batch render or a colleague does not
  see someone's `.Rprofile`, so the same job could read different data, or fail,
  depending on who runs it.

## 3. The change in `hvtiRutilities`

- `.study_dataset()` (`R/study_data.R`) treats `"built"` exactly as `"study"`.
  The returned `dataset` field stays `"study"`, so manifests, provenance and
  status output keep one canonical name.
- The other places that test `identical(dataset, "study")` do the same. There are
  about 39 occurrences of `"study"` across 10 files in `R/`; each is read and
  changed or left with a reason.
- `"built"` becomes **reserved**, like `"study"`. `register_data(role = "named",
  dataset = "built")` is refused.
- **Existing collision.** A study that already registered an additional dataset
  named `built` stops on `study_config()` with: "_study.yml registers an
  additional dataset named 'built', which is now a second name for the study
  dataset. Rename it under additional_datasets: and in manifest.yaml." It does not
  silently pick one.
- Help pages that say `dataset = "study"` say that `"built"` means the same.
- `NEWS.md` entry.

## 4. The change in `hvtiRtemplates`

- Every template's edit block becomes:

  ```r
  # EDIT: the registered dataset this job reads ("built" is the study dataset).
  DATASET <- "built"
  ```

  30 templates set `DATASET` today.
- The prose blocks that explain `DATASET <- "study"` (for example `dc-gfup.qmd`
  around line 218) are updated to `"built"`.
- `read_job_data(dataset = "study")` keeps its default; both names work.
- Requires the `hvtiRutilities` release from section 3; the minimum version in
  `DESCRIPTION` is raised to it.
- Existing scaffolded jobs that say `"study"` keep working unchanged.

## 5. Tests

- `read_built(cfg, dataset = "built")` and `dataset = "study"` return the same data.
- `register_data()` refuses a named dataset called `built`.
- `study_config()` stops, with the rename message, on a `_study.yml` that already
  has an additional dataset named `built`.
- A template rendered with `DATASET <- "built"` reads the study dataset.
