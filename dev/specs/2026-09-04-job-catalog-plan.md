# Job Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the 53-row job ledger into `hvtiR` as a validated catalog that
routes every job type to the package that owes it, and render it as a pkgdown
page so the biostats slide stops being hand-maintained.

**Architecture:** A JSON data file in `inst/extdata/`, an internal reader
mirroring the existing `read_catalog()`, an exported `jobs()` accessor, a test
suite that validates routings against real package exports, and a Quarto
vignette that renders the matrix. `hvtiRtemplates` then reads the catalog from a
CI checkout rather than owning it.

**Tech Stack:** R, `jsonlite`, `testthat` edition 3, Quarto vignettes, pkgdown,
GitHub Actions.

**Design:** `dev/specs/2026-09-04-job-catalog-design.md`. Read it first. This
plan implements option B of §6 and defers §9.

## Global Constraints

- Versions are straight three digits, `1.1.3`, never a `.9000` suffix or a
  fourth digit. Patch digit only; minor and major are the maintainer's call.
- `hvtiR` has `Roxygen: list(markdown = TRUE)`. Backticks and `**bold**` work
  in roxygen here. ⚠️ This is the OPPOSITE of `hvtiRtemplates`, which needs
  `\code{}` and `\strong{}`. Do not carry a habit between them.
- Vignettes are Quarto, `.qmd`, `VignetteBuilder: quarto`.
- No em dashes in package documentation, vignette prose, commit messages or PR
  bodies. Use commas, colons or a restructured sentence.
- Never push to `main`. Branch, open a PR, let the maintainer merge.
- `devtools::check()` must stay at 0 errors, 0 warnings, 0 notes.
- `NEWS.md` entries go under a `# hvtiR (unreleased)` heading, added if absent.
  The version rename to `1.1.3` is a separate commit, at most once a day.

---

## File structure

| file | responsibility |
|---|---|
| `inst/extdata/jobs.json` | the 53 rows and their routing. The data. |
| `R/jobs.R` | `read_jobs()` internal reader, `jobs()` exported accessor |
| `tests/testthat/test-jobs.R` | shape and enum rules, no package loading |
| `tests/testthat/test-jobs-routing.R` | rule 3, loads destination packages |
| `vignettes/job-catalog.qmd` | the rendered matrix, the slide's replacement |
| `_pkgdown.yml` | navbar entry for the new article |
| `DESCRIPTION` | `jsonlite` added to Imports |

⚠️ **The design did not account for a JSON parser.** `hvtiR` imports only `cli`
and `utils` today, deliberately, because it is what bootstraps the family.
Task 1 adds `jsonlite` to Imports. It is acceptable because `jsonlite` has no
transitive dependencies of its own, so the installer's own install stays one
package heavier and no deeper. If that trade is refused, the fallback is CSV
with semicolon-separated array cells, which the design rejected as worse, and
this plan would need rewriting from Task 1.

The two test files are split because they fail for different reasons and one of
them can legitimately be incomplete on a laptop. Keeping the rules that need no
network or install in their own file means a developer with a bare checkout
still gets a meaningful run.

---

### Task 1: The data file and its reader

**Files:**
- Create: `inst/extdata/jobs.json`
- Create: `R/jobs.R`
- Create: `tests/testthat/test-jobs.R`
- Modify: `DESCRIPTION`

**Interfaces:**
- Consumes: nothing.
- Produces: `read_jobs(path)` returning a list of 53 lists, one per row, arrays
  preserved as lists. Every later task calls it.

- [ ] **Step 1: Seed the data file from the hvtiRtemplates ledger**

Run, from the `hvtiR` repo root, with `hvtiRtemplates` checked out alongside:

```bash
python3 -c "
import json
src='../hvtiRtemplates/dev/specs/artifacts/2026-08-29-template-roadmap.json'
rows=json.load(open(src))['prefixes']
for r in rows:
    r['disposition']=None
    r['destination']=None
    r['replaced_by']=[]
json.dump({'jobs':rows}, open('inst/extdata/jobs.json','w'), indent=1)
print(len(rows),'rows')
"
```

Expected output: `53 rows`.

The three new fields are null and empty here on purpose. Task 2 populates them,
so that a reviewer can see the seeding and the routing as separate diffs.

- [ ] **Step 2: Write the failing test**

Create `tests/testthat/test-jobs.R`:

```r
test_that("the catalog has 53 rows and every row is keyed", {
  raw <- read_jobs()

  expect_type(raw, "list")
  expect_length(raw, 53L)
  expect_true(all(vapply(raw, function(r) is.character(r$prefix) ||
                           is.null(r$prefix), logical(1))))
})

test_that("prefix and qualifier together are unique", {
  raw <- read_jobs()
  key <- vapply(raw, function(r) {
    paste0(if (is.null(r$prefix)) "<NA>" else r$prefix, "\r",
           if (is.null(r$qualifier)) "<NA>" else r$qualifier)
  }, character(1))

  expect_identical(anyDuplicated(key), 0L)
})
```

⚠️ The key uses `"\r"` as a separator and spells a missing value `"<NA>"`
rather than pasting `NA` directly. Pasting `NA` collapses it to the string
`"NA"`, which then collides with a real qualifier named `NA`. That exact bug
was found and fixed in `hvtiRtemplates` and must not be reintroduced.

- [ ] **Step 3: Run test to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "jobs")'`
Expected: FAIL with `could not find function "read_jobs"`.

- [ ] **Step 4: Add jsonlite to Imports**

In `DESCRIPTION`, change the `Imports:` block to:

```
Imports:
    cli,
    jsonlite,
    utils
```

- [ ] **Step 5: Write the reader**

Create `R/jobs.R`:

```r
#' Read the job catalog
#'
#' The 53 job types found in the studies corpus, each routed to the package
#' that owes it. Rows are returned as a list rather than a data frame because
#' `upstream`, `downstream`, `workflows` and `replaced_by` are arrays.
#'
#' @param path Path to the catalog JSON. Defaults to the copy installed with
#'   the package.
#' @return A list of 53 lists, one per job type.
#' @noRd
read_jobs <- function(path = system.file("extdata", "jobs.json",
                                         package = "hvtiR")) {
  jsonlite::fromJSON(path, simplifyVector = FALSE)$jobs
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `Rscript -e 'devtools::test(filter = "jobs")'`
Expected: PASS, 2 tests.

- [ ] **Step 7: Commit**

```bash
git add DESCRIPTION R/jobs.R inst/extdata/jobs.json tests/testthat/test-jobs.R
git commit -m "feat: seed the job catalog and its reader

Fifty-three job types, carried over from the hvtiRtemplates ledger with the
three routing fields present and empty. jsonlite joins Imports because the
array fields cannot survive CSV without a delimiter convention.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Populate the routing fields

**Files:**
- Modify: `inst/extdata/jobs.json`
- Modify: `tests/testthat/test-jobs.R`

**Interfaces:**
- Consumes: `read_jobs()` from Task 1.
- Produces: every row carries `disposition` in
  `c("scaffold", "thin", "retire", "build")`, `destination` a package name or
  `null`, and `replaced_by` an array of `"package::function"` strings.

- [ ] **Step 1: Write the failing test**

Append to `tests/testthat/test-jobs.R`:

```r
test_that("every row carries a disposition from the enum", {
  raw <- read_jobs()
  d <- vapply(raw, function(r) {
    if (is.null(r$disposition)) NA_character_ else r$disposition
  }, character(1))

  expect_false(anyNA(d))
  expect_true(all(d %in% c("scaffold", "thin", "retire", "build")))
})

test_that("a retired row names what replaced it", {
  raw <- read_jobs()
  retired <- Filter(function(r) identical(r$disposition, "retire"), raw)

  expect_gt(length(retired), 0L)
  for (r in retired) {
    expect_false(is.null(r$destination), label = r$prefix)
    expect_gt(length(r$replaced_by), 0L)
  }
})

test_that("a scaffold or thin row is destined for hvtiRtemplates", {
  raw <- read_jobs()
  for (r in raw) {
    if (r$disposition %in% c("scaffold", "thin")) {
      expect_identical(r$destination, "hvtiRtemplates", label = r$prefix)
    }
  }
})

test_that("a build row names a destination, no replacement, and a blocker", {
  raw <- read_jobs()
  for (r in raw) {
    if (identical(r$disposition, "build")) {
      expect_false(is.null(r$destination), label = r$prefix)
      expect_length(r$replaced_by, 0L)
      expect_false(is.null(r$blocked_on), label = r$prefix)
    }
  }
})

test_that("every destination is a family member", {
  raw <- read_jobs()
  dest <- unique(unlist(lapply(raw, function(r) r$destination)))

  expect_true(all(dest %in% members()$package))
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "jobs")'`
Expected: FAIL on the disposition enum, all 53 values `NA`.

- [ ] **Step 3: Populate the audited rows**

Run from the repo root:

```bash
python3 -c "
import json
p='inst/extdata/jobs.json'
d=json.load(open(p)); rows=d['jobs']

PLOT='hvtiPlotR'; GGRF='ggRandomForests'; GGBT='ggBoostedTrees'; TPL='hvtiRtemplates'
thin={
 ('dp','trends'):['hvtiPlotR::hv_trends'],
 ('dp','spaghetti'):['hvtiPlotR::hv_spaghetti'],
 ('dp','gfup'):['hvtiPlotR::hv_followup'],
 ('dp','procs'):['hvtiPlotR::hv_longitudinal','hvtiPlotR::hv_stacked'],
 ('np',None):['hvtiPlotR::hv_nonparametric','hvtiPlotR::hv_ordinal'],
 ('hp',None):['hvtiPlotR::hv_hazard','hvtiPlotR::hazard_plot','hvtiPlotR::hv_survival','hvtiPlotR::hv_atrisk_compose'],
 ('rp',None):['hvtiPlotR::hv_balance'],
 ('mp',None):['hvtiPlotR::hv_spaghetti'],
 ('lp',None):['hvtiPlotR::hv_mirror_hist'],
}
build={('cp',None):PLOT,('ce',None):PLOT,('gp',None):PLOT,('fp',None):PLOT,
       ('sid',None):GGRF,('vt',None):GGRF,('nb',None):GGBT}
retire={
 ('rfsrc',None):['ggRandomForests::gg_rfsrc','ggRandomForests::gg_survival','ggRandomForests::gg_error','ggRandomForests::gg_vimp','ggRandomForests::gg_partial'],
 ('rf',None):['ggRandomForests::gg_rfsrc','ggRandomForests::gg_error','ggRandomForests::gg_vimp','ggRandomForests::gg_variable'],
 ('rfs',None):['ggRandomForests::gg_rfsrc','ggRandomForests::gg_survival','ggRandomForests::gg_error','ggRandomForests::gg_vimp'],
 ('rfc',None):['ggRandomForests::gg_roc','ggRandomForests::gg_brier','ggRandomForests::gg_error','ggRandomForests::calc_auc'],
 ('rfr',None):['ggRandomForests::gg_rfsrc','ggRandomForests::gg_vimp','ggRandomForests::gg_shap'],
}
for r in rows:
    k=(r['prefix'], r['qualifier'])
    if k in retire:
        r['disposition']='retire'; r['destination']=GGRF; r['replaced_by']=retire[k]
    elif k in build:
        r['disposition']='build'; r['destination']=build[k]; r['replaced_by']=[]
        if not r.get('blocked_on'):
            r['blocked_on']='needs an issue: no function exists yet'
    elif k in thin:
        r['disposition']='thin'; r['destination']=TPL; r['replaced_by']=thin[k]
    else:
        r['disposition']='scaffold'; r['destination']=TPL; r['replaced_by']=[]
json.dump(d, open(p,'w'), indent=1)
from collections import Counter
print(Counter(r['disposition'] for r in rows))
"
```

Expected output: `Counter({'scaffold': 32, 'thin': 9, 'build': 7, 'retire': 5})`,
summing to 53. These counts were verified against the ledger on 2026-09-04.

⚠️ **`rp` names only `hvtiPlotR::hv_balance`, not `calc_smd`.** `calc_smd` is
documented in `hvtiPlotR/man/` but is absent from its `NAMESPACE`, so it is not
an export and Task 3 would reject it. That is rule 3 working: the standardized
mean difference half of `rp` is not reachable by a study author today. If that
is wrong, the fix is to export `calc_smd` in `hvtiPlotR` and add it back here,
not to relax the rule.

⚠️ **`blocked_on` is filled with a placeholder string here and that is a known
debt, not a finished state.** Seven `build` rows need real issues opened in
`hvtiPlotR`, `ggRandomForests` and `ggBoostedTrees`. Task 6 replaces the
placeholders with issue references. Do not ship a release with the placeholder
text in the file.

- [ ] **Step 4: Run tests to verify they pass**

Run: `Rscript -e 'devtools::test(filter = "jobs")'`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add inst/extdata/jobs.json tests/testthat/test-jobs.R
git commit -m "feat: route every job type to the package that owes it

Nine thin, seven build, five retire, thirty-two scaffold. The retire rows are
the ggRandomForests family: rfs, rfc and rfr join rf and rfsrc, which were
already out-of-scope on the same reporting surface while the other three sat
queued with R jobs already written against them.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Validate replacements against real exports

**Files:**
- Create: `tests/testthat/test-jobs-routing.R`
- Modify: `.github/workflows/R-CMD-check.yaml`

**Interfaces:**
- Consumes: `read_jobs()` from Task 1, populated rows from Task 2.
- Produces: nothing new in R. A CI guarantee that every `replaced_by` entry
  names a live export.

- [ ] **Step 1: Write the failing test**

Create `tests/testthat/test-jobs-routing.R`:

```r
# Rule 3 of the job catalog design: every replaced_by entry must name a real
# export of a real family package.
#
# This test needs the destination packages installed. A plain skip would be
# invisible: R CMD check reports a skip as success, so the family could drift
# for months under a green check. That failure has already happened once in
# hvtiRlifetables, where a regression guard read SKIP 5 | PASS 474 and had
# never run on Windows. So the uninstalled packages are NAMED in the output,
# and on CI a missing package is a failure rather than a skip.

.jobs_refs <- function() {
  raw <- read_jobs()
  unique(unlist(lapply(raw, function(r) unlist(r$replaced_by))))
}

# Reporting the unvalidated packages is its own function so that the loud-skip
# behaviour can be tested directly, with a package name that is certainly not
# installed, rather than by uninstalling something from the developer's real
# library and hoping the reinstall runs.
.jobs_report_absent <- function(absent,
                                ci = identical(Sys.getenv("CI"), "true")) {
  if (!length(absent)) {
    return(invisible(character(0)))
  }
  msg <- paste("UNVALIDATED routings, package not installed:",
               paste(absent, collapse = ", "))
  if (ci) stop(msg, call. = FALSE) else message(msg)
  invisible(absent)
}

test_that("an absent destination is named, and is fatal on CI", {
  expect_identical(.jobs_report_absent(character(0)), character(0))
  expect_message(.jobs_report_absent("notAPackageThatExists", ci = FALSE),
                 "UNVALIDATED routings, package not installed: notAPackageThatExists")
  expect_error(.jobs_report_absent("notAPackageThatExists", ci = TRUE),
               "UNVALIDATED routings")
})

test_that("every replaced_by entry is package::function", {
  refs <- .jobs_refs()

  expect_gt(length(refs), 0L)
  expect_true(all(grepl("^[A-Za-z][A-Za-z0-9.]*::[A-Za-z._][A-Za-z0-9._]*$",
                        refs)),
              info = paste(refs[!grepl("::", refs)], collapse = ", "))
})

test_that("every replaced_by package is a family member", {
  pkgs <- unique(sub("::.*$", "", .jobs_refs()))

  expect_true(all(pkgs %in% members()$package),
              info = paste(setdiff(pkgs, members()$package), collapse = ", "))
})

test_that("every replaced_by function is exported by its package", {
  refs <- .jobs_refs()
  pkgs <- unique(sub("::.*$", "", refs))

  have <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
  .jobs_report_absent(pkgs[!have])

  for (p in pkgs[have]) {
    exported <- getNamespaceExports(p)
    want <- sub("^.*::", "", refs[sub("::.*$", "", refs) == p])
    expect_true(all(want %in% exported),
                info = paste0(p, ": ", paste(setdiff(want, exported),
                                             collapse = ", ")))
  }
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "jobs-routing")'`
Expected: FAIL or a `UNVALIDATED routings` message, depending on what is
installed locally. Install the three destinations and re-run:

```bash
Rscript -e 'pak::pak(c("ehrlinger/hvtiPlotR", "ehrlinger/ggRandomForests", "ehrlinger/ggBoostedTrees"))'
Rscript -e 'devtools::test(filter = "jobs-routing")'
```

Expected after install: PASS, 3 tests, no `UNVALIDATED` message.

⚠️ If a routing fails here, the fix is to correct `jobs.json`, not to relax the
test. A `replaced_by` naming a function that is not exported is exactly the
defect this rule exists to catch.

- [ ] **Step 3: Make CI install the destinations**

In `.github/workflows/R-CMD-check.yaml`, in the step that installs
dependencies, add the three destination packages so that no routing goes
unvalidated in CI. Find the `r-lib/actions/setup-r-dependencies` step and add:

```yaml
        with:
          extra-packages: >
            any::rcmdcheck,
            ehrlinger/hvtiPlotR,
            ehrlinger/ggRandomForests,
            ehrlinger/ggBoostedTrees
```

- [ ] **Step 4: Verify the skip is loud**

The behaviour is proved by the `.jobs_report_absent()` test written in Step 1,
which uses a package name that cannot be installed. Nothing is removed from the
developer's library.

Run: `Rscript -e 'devtools::test(filter = "jobs-routing")'`
Expected: PASS, 4 tests. The run must print no `UNVALIDATED` message, because
every real destination is installed after Step 2.

Then confirm the fatal path end to end:

Run: `CI=true Rscript -e 'devtools::test(filter = "jobs-routing")'`
Expected: PASS, 4 tests, still no `UNVALIDATED` message. If this run fails with
`UNVALIDATED routings`, a destination is genuinely missing from your library:
install it, do not weaken the test.

- [ ] **Step 5: Commit**

```bash
git add tests/testthat/test-jobs-routing.R .github/workflows/R-CMD-check.yaml
git commit -m "test: refuse a routing that names no real export

Rule 3 of the catalog design. The destinations are installed in CI so the
skip count there is zero, and an uninstalled package is named in the output
rather than silently skipped, which is how hvtiRlifetables shipped a guard
that had never run on Windows.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: The exported accessor

**Files:**
- Modify: `R/jobs.R`
- Modify: `NAMESPACE` (via `devtools::document()`)
- Modify: `tests/testthat/test-jobs.R`
- Modify: `_pkgdown.yml`

**Interfaces:**
- Consumes: `read_jobs()`.
- Produces: `jobs()`, exported, returning a 53-row data frame with columns
  `prefix`, `qualifier`, `name`, `folder`, `family`, `status`, `disposition`,
  `destination`, `sas_breadth`, `r_jobs`, `blocked_on` and a `replaced_by`
  list column.

- [ ] **Step 1: Write the failing test**

Append to `tests/testthat/test-jobs.R`:

```r
test_that("jobs() returns one row per job type with a list column", {
  j <- jobs()

  expect_s3_class(j, "data.frame")
  expect_identical(nrow(j), 53L)
  expect_true(all(c("prefix", "folder", "disposition", "destination",
                    "replaced_by") %in% names(j)))
  expect_type(j$replaced_by, "list")
  expect_type(j$sas_breadth, "integer")
})

test_that("jobs() agrees with read_jobs() on the retire rows", {
  j <- jobs()

  expect_identical(sum(j$disposition == "retire"), 5L)
  expect_true(all(lengths(j$replaced_by[j$disposition == "retire"]) > 0L))
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "jobs")'`
Expected: FAIL with `could not find function "jobs"`.

- [ ] **Step 3: Write the accessor**

Append to `R/jobs.R`:

```r
#' The job catalog
#'
#' Every job type found in the studies corpus, with the package that owes it.
#' A job type is keyed on `prefix` and `qualifier` together, because one prefix
#' can carry several job types.
#'
#' `disposition` says what kind of work a row is:
#'
#' * `scaffold`, genuinely repeated work; a template is the deliverable
#' * `thin`, a template whose body is mostly calls into `replaced_by`
#' * `retire`, the work is a function that exists; no template is owed
#' * `build`, the work is a function that does not exist yet
#'
#' `destination` names who owes the remaining work. `replaced_by` names what
#' already exists, as `package::function`, and is frequently in a different
#' package from `destination`: a thin template lives in `hvtiRtemplates` and
#' leans on `hvtiPlotR`.
#'
#' The taxonomy that says what a prefix *means* is
#' `hvtiRutilities::hvti_taxonomy()`. This catalog says who owes it. They are
#' apart because validating a routing has to load the destination package, and
#' `hvtiRutilities` is imported by packages this catalog routes to.
#'
#' @return A data frame with one row per job type. `replaced_by` is a list
#'   column of character vectors, empty where nothing replaces the row.
#' @export
#' @examples
#' j <- jobs()
#' table(j$disposition)
jobs <- function() {
  raw <- read_jobs()

  chr <- function(field) {
    vapply(raw, function(r) {
      v <- r[[field]]
      if (is.null(v)) NA_character_ else as.character(v)
    }, character(1))
  }
  int <- function(field) {
    vapply(raw, function(r) {
      v <- r[[field]]
      if (is.null(v)) NA_integer_ else as.integer(v)
    }, integer(1))
  }

  out <- data.frame(
    prefix      = chr("prefix"),
    qualifier   = chr("qualifier"),
    name        = chr("name"),
    folder      = chr("folder"),
    family      = chr("family"),
    status      = chr("status"),
    disposition = chr("disposition"),
    destination = chr("destination"),
    sas_breadth = int("sas_breadth"),
    r_jobs      = int("r_jobs"),
    blocked_on  = chr("blocked_on"),
    stringsAsFactors = FALSE
  )
  out$replaced_by <- lapply(raw, function(r) {
    v <- unlist(r$replaced_by)
    if (is.null(v)) character(0) else as.character(v)
  })
  out
}
```

- [ ] **Step 4: Document and run tests**

```bash
Rscript -e 'devtools::document()'
Rscript -e 'devtools::test(filter = "jobs")'
```

Expected: `NAMESPACE` gains `export(jobs)`, `man/jobs.Rd` is created, tests
PASS, 9 tests.

- [ ] **Step 5: Add to the pkgdown reference**

In `_pkgdown.yml`, add `jobs` to the reference section alongside `members`. If
there is no explicit `reference:` section, skip this step: pkgdown indexes every
export automatically and adding one would start a list that can drift.

- [ ] **Step 6: Commit**

```bash
git add R/jobs.R NAMESPACE man/jobs.Rd tests/testthat/test-jobs.R _pkgdown.yml
git commit -m "feat: export jobs(), the routed job catalog

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Render the catalog as a pkgdown article

**Files:**
- Create: `vignettes/job-catalog.qmd`
- Modify: `_pkgdown.yml`
- Modify: `DESCRIPTION` (`knitr` and `quarto` are already in Suggests)

**Interfaces:**
- Consumes: `jobs()` from Task 4.
- Produces: a rendered page at
  `https://ehrlinger.github.io/hvtiR/articles/job-catalog.html`.

This is the slide's replacement. The deck page in
`Manager Productivity Meeting/Biostats meeting 2026-09-02.pptx` was built by
hand and has already drifted: the folder numbering printed on it
(`00_datasets`, `01_descriptives`, `02_distributions`, `10_analysis`,
`20_documents`, `30_graphs`, `40_estimates`) exists nowhere in code, while
`hvti_taxonomy()` and `inst/templates/` use `00/10/20/30/40/50/90` in a
different order. The article renders from `jobs()`, so it cannot drift.

⚠️ **This does not reproduce the slide's visual design.** It produces the same
information as a set of grouped tables. Reproducing the deck layout is a
separate exercise and is not what stops the drift; generating the numbers is.

- [ ] **Step 1: Write the article**

Create `vignettes/job-catalog.qmd`:

```markdown
---
title: "The job catalog"
vignette: >
  %\VignetteIndexEntry{The job catalog}
  %\VignetteEngine{quarto::html}
  %\VignetteEncoding{UTF-8}
---

```{r}
#| include: false
library(hvtiR)
knitr::opts_chunk$set(echo = FALSE)
```

Every job type found in the studies corpus, and the package that owes it.
Counts are SAS templates found and R jobs already written. This page is
generated from the catalog shipped with the package, so it cannot disagree
with it.

```{r}
j <- jobs()
knitr::kable(as.data.frame(table(
  disposition = j$disposition
)), col.names = c("disposition", "rows"))
```

```{r}
#| results: asis
show <- function(rows) {
  label <- ifelse(is.na(rows$qualifier), rows$prefix,
                  paste0(rows$prefix, "-", rows$qualifier))
  owed <- vapply(rows$replaced_by, function(v) {
    if (!length(v)) "" else paste0("`", paste(v, collapse = "`, `"), "`")
  }, character(1))
  out <- data.frame(
    job = paste0("`", label, "`"),
    name = rows$name,
    SAS = rows$sas_breadth,
    R = rows$r_jobs,
    disposition = rows$disposition,
    destination = rows$destination,
    `replaced by` = owed,
    check.names = FALSE
  )
  print(knitr::kable(out, row.names = FALSE))
  cat("\n\n")
}

for (f in unique(j$folder)) {
  cat("## ", f, "\n\n", sep = "")
  show(j[j$folder == f, , drop = FALSE])
}
```
```

- [ ] **Step 2: Render it**

Run: `Rscript -e 'devtools::build_vignettes()'`
Expected: `doc/job-catalog.html` exists and contains a `## graphs` heading with
fourteen rows.

Verify: `grep -c '<tr>' doc/job-catalog.html`
Expected: at least 53.

- [ ] **Step 3: Add it to the navbar**

In `_pkgdown.yml`, under `navbar:`, add the article to the articles menu so it
is reachable without knowing the URL.

- [ ] **Step 4: Build the site**

Run: `Rscript -e 'pkgdown::build_site()'`
Expected: `docs/articles/job-catalog.html` exists, no errors.

- [ ] **Step 5: Commit**

```bash
git add vignettes/job-catalog.qmd _pkgdown.yml
git commit -m "docs: render the job catalog as an article

The deck page it replaces was hand built and had already drifted: the folder
numbering printed on it exists in no code. This one is generated from jobs().

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Replace the blocked_on placeholders

**Files:**
- Modify: `inst/extdata/jobs.json`
- Modify: `tests/testthat/test-jobs.R`

**Interfaces:**
- Consumes: the seven `build` rows from Task 2.
- Produces: `blocked_on` values that are real issue references.

- [ ] **Step 1: Open the issues**

Seven functions do not exist. Open one issue per row, in the destination repo:

```bash
gh issue create -R ehrlinger/hvtiPlotR -t "Forest plot function for the fp job type" \
  -b "The fp job type has 19 SAS templates and 20 R jobs already written by hand, the only graphs row where R exceeds SAS. hvtiPlotR has no forest plot function; every 'forest' match in the package is the colour literal forestgreen. Catalog row: fp, disposition build."
gh issue create -R ehrlinger/hvtiPlotR -t "Competing events figures for the ce job type" \
  -b "131 SAS templates, 1 R job. hvtiPlotR ships the parametric dataset of competing-risk estimates but no function that consumes it. Catalog row: ce, disposition build."
gh issue create -R ehrlinger/hvtiPlotR -t "Cumulative probability plot for the cp job type" \
  -b "km_build_cumhaz_plot is cumulative hazard, not cumulative probability. Catalog row: cp, disposition build."
gh issue create -R ehrlinger/hvtiPlotR -t "Generalized model plot for the gp job type" \
  -b "50 SAS templates, 2 R jobs, no function. Catalog row: gp, disposition build."
gh issue create -R ehrlinger/ggRandomForests -t "sidClustering support for the sid job type" \
  -b "sidClustering appears zero times in ggRandomForests. Catalog row: sid, disposition build."
gh issue create -R ehrlinger/ggRandomForests -t "Virtual twins support for the vt job type" \
  -b "Virtual twins appears only inside gg_partial_varpro's documentation, describing Unlimited Virtual Twins as machinery varpro uses internally. There is no entry point. Catalog row: vt, disposition build."
gh issue create -R ehrlinger/ggBoostedTrees -t "BoostMLR support for the nb job type" \
  -b "gg_boost_* covers boostmtree. BoostMLR is in Suggests but appears in no R/, tests/ or vignettes/ file. Catalog row: nb, disposition build."
```

Record the seven issue numbers returned.

- [ ] **Step 2: Write the failing test**

Append to `tests/testthat/test-jobs.R`:

```r
test_that("a build row is blocked on a real issue reference", {
  raw <- read_jobs()
  for (r in raw) {
    if (identical(r$disposition, "build")) {
      expect_match(r$blocked_on, "^ehrlinger/[A-Za-z]+#[0-9]+$",
                   label = r$prefix)
    }
  }
})
```

- [ ] **Step 3: Run test to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "jobs")'`
Expected: FAIL, seven rows carry the placeholder string.

- [ ] **Step 4: Write the issue references**

Edit `inst/extdata/jobs.json` and replace each of the seven `blocked_on`
placeholder strings with the matching reference, for example
`"ehrlinger/hvtiPlotR#41"`. Use the numbers `gh` returned in Step 1.

- [ ] **Step 5: Run tests to verify they pass**

Run: `Rscript -e 'devtools::test(filter = "jobs")'`
Expected: PASS, 10 tests.

- [ ] **Step 6: Commit**

```bash
git add inst/extdata/jobs.json tests/testthat/test-jobs.R
git commit -m "feat: block every build row on a real issue

Seven functions the catalog says are owed but do not exist, now each with an
issue in the repo that owes it, and a test that refuses a placeholder.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Ship it, then point hvtiRtemplates at it

**Files:**
- Modify: `NEWS.md`, `DESCRIPTION` (this repo)
- Modify: `dev/specs/artifacts/check-roadmap-counts.py` (hvtiRtemplates)
- Modify: `.github/workflows/spec-counts.yaml` (hvtiRtemplates)

**Interfaces:**
- Consumes: a merged, released `hvtiR` carrying `inst/extdata/jobs.json`.
- Produces: `hvtiRtemplates` reading the catalog from a CI checkout, filtered
  to its own rows.

⚠️ **This task spans two repositories and is two pull requests.** Merge the
`hvtiR` one first. `hvtiRtemplates` cannot depend on `hvtiR`, which installs
it, so the coupling is a checkout and a path argument, never a `DESCRIPTION`
entry.

- [ ] **Step 1: Add the NEWS entry in hvtiR**

Add to `NEWS.md`, under a `# hvtiR (unreleased)` heading, creating the heading
if it is absent:

```markdown
# hvtiR (unreleased)

* New `jobs()`, the job catalog: every job type found in the studies corpus,
  routed to the package that owes it. Rendered as the "The job catalog"
  article.
```

- [ ] **Step 2: Open the hvtiR pull request**

```bash
git push -u origin design/job-catalog
gh pr create -B main -t "feat: the job catalog" -b "Implements dev/specs/2026-09-04-job-catalog-design.md.

Fifty-three job types, each routed to the package that owes it, with a test
suite that refuses a routing not backed by a real export and names any
destination it could not validate. Rendered as a pkgdown article, replacing a
hand-built deck page that had already drifted.

Ran /code-review locally; it stood in for the Copilot bot, whose quota is
exhausted until October.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

⚠️ Run `/code-review` locally before opening this, and say so in the body as
above. The `copilot_code_review` rule is still in the ruleset and does not
block a merge, so an unreviewed diff otherwise reaches `main` unread.

- [ ] **Step 3: After merge, bump the version and tag it**

A separate commit, on its own branch: rename the `# hvtiR (unreleased)` heading
to `# hvtiR 1.1.3`, and set `Version: 1.1.3` and `Date:` in `DESCRIPTION`.

⚠️ **Tag it after that merges.** Step 5 pins the `hvtiRtemplates` workflow to
`v1.1.3`, and an unpinned or non-existent ref makes that checkout fail:

```bash
git checkout main && git pull
git tag -a v1.1.3 -m "hvtiR 1.1.3: the job catalog"
git push origin v1.1.3
```

Verify the tag resolves before editing the other repo's workflow:

```bash
gh api repos/ehrlinger/hvtiR/git/ref/tags/v1.1.3 --jq .object.sha
```

Expected: a commit SHA, not a 404.

- [ ] **Step 4: Teach the hvtiRtemplates checker the new source**

In `hvtiRtemplates`, modify
`dev/specs/artifacts/check-roadmap-counts.py` so the ledger path comes from an
argument or the `HVTI_JOBS` environment variable, defaulting to the current
sibling file, and so the rows are filtered before the two-way count:

```python
rows = [r for r in rows if r.get("destination") in (None, "hvtiRtemplates")]
```

A row routed elsewhere is no longer a template hvtiRtemplates failed to ship,
which is the whole point of the field.

- [ ] **Step 5: Check out hvtiR in the hvtiRtemplates workflow**

In `.github/workflows/spec-counts.yaml`, before the check step:

```yaml
      - uses: actions/checkout@v4
        with:
          repository: ehrlinger/hvtiR
          ref: v1.1.3
          path: .hvtiR
      - run: echo "HVTI_JOBS=$GITHUB_WORKSPACE/.hvtiR/inst/extdata/jobs.json" >> "$GITHUB_ENV"
```

⚠️ Pin `ref` to a tag, not to `main`. An unpinned checkout makes every
`hvtiRtemplates` PR fail the moment somebody edits the catalog in another repo,
with no change in this one.

- [ ] **Step 6: Run the checker locally**

```bash
cd ../hvtiRtemplates
HVTI_JOBS=../hvtiR/inst/extdata/jobs.json python3 dev/specs/artifacts/check-roadmap-counts.py
```

Expected: exit 0. If it fails on a count, the likely cause is a row now routed
away from `hvtiRtemplates` while `inst/templates/` still holds its file. That
is a real finding: reconcile it, do not loosen the filter.

- [ ] **Step 7: Commit and open the second pull request**

```bash
git checkout -b chore/job-catalog-source
git add dev/specs/artifacts/check-roadmap-counts.py .github/workflows/spec-counts.yaml
git commit -m "chore: read the job catalog from hvtiR

The ledger moved. The checker takes a path and filters to rows destined for
this package, so a retired row stops reading as a template we failed to ship.
A checkout rather than a dependency, because hvtiR installs this package.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push -u origin chore/job-catalog-source
gh pr create -B main -t "chore: read the job catalog from hvtiR" -b "Follows ehrlinger/hvtiR#<n>. The 53-row ledger now lives in hvtiR, which is the only package that can name every member without inverting the family.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

---

## Deferred, not in this plan

- **Coverage consistency**, design §9. The check that would have caught `rfc`
  needs a "shares a surface" relation nobody has defined. Prototype the
  destination-plus-family definition as a report before making it a gate.
- **Auditing the remaining rows.** `datasets`, `descriptives`,
  `distributions`, `analysis` and `documents` are seeded `scaffold` because
  that is their status quo, not because anyone measured them. `dc`'s five split
  rows are the likeliest to move, to `hvtiRtables`, whose `hv_tbl_summary` is
  the Table 1 job.
- **The thirteen uncounted rows.** `dc` and `dp` split on 2026-09-03 and their
  SAS and R counts have not been recomputed. The catalog carries the gap.
- **`hp`'s fate.** It is `status: revisit` and `disposition: thin`. Deciding
  whether the shipped template survives is separate work.
- **Reproducing the deck's visual design.** Task 5 generates the numbers,
  which is what stops the drift.
