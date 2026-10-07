# Every template figure saved as PDF and PNG: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every figure a job template draws is saved into the job's `graphs/<subject>-<type>/` folder as a PNG for Word and a PDF for the publisher, by default, with a study choice to turn saving off and another to keep only some figures.

**Architecture:** One internal function, `.save_figure()`, in hvtiRtemplates, writes a figure's PNG (300 dpi) and its PDF (fonts embedded through cairo where available). It takes a ggplot or patchwork object, a list of them, or a function that draws base graphics. Each template gains two study choices (`SAVE_FIGURES`, `FIGURES`) and a three-line `save_figure()` wrapper beside its `set_path()`. The eight templates that save a PNG today switch their `ggsave()` or `png()` calls to the wrapper, and the eleven that only print their figures gain a call per figure. A figure's name is its file stem (`hp-survival`, `rfs-fit-diagnostics-brier`), so the files say which job and which figure they are.

**Tech Stack:** R (>= 4.4.0), ggplot2 (in `Suggests`, as today), grDevices, testthat edition 3, Quarto.

**Spec:** `hvtiR/dev/specs/2026-10-07-figures-pdf-png-design.md`.

## Global Constraints

- Repository: `ehrlinger/hvtiRtemplates` only. One branch and pull request. Never push to `main`.
- Lands after designs 3 and 4 have edited the templates (the overview's order), or is rebased onto them.
- A PNG the report embeds keeps its exact path and name, so `include_graphics()` links and the tests that check those files keep working.
- PNGs are written at 300 dpi; PDFs use `grDevices::cairo_pdf` when `capabilities("cairo")` is `TRUE`, and `grDevices::pdf` otherwise.
- `.save_figure()` calls `ggplot2::ggsave()` for ggplot objects, so the tests that mock `ggsave` still see every save.
- The new study-choice lines carry **no** `EDIT:` marker, for the reason design 6 gives: the edit guard renders any job with a marker as a draft.
- Sizes: a figure saved today keeps its current width and height. A figure saved for the first time uses the house manuscript size, 6 x 4 in, unless its chunk sets `fig-height`, which is kept. Team sizes are an open standard (design section 4).
- Roxygen is Rd markup. Line length 135. Templates keep the `.lintr` exclusions they have.
- `NEWS.md` bullet under `# hvtiRtemplates (unreleased)`. Do not touch `Version:`.
- Definition of done: `devtools::test()` passes; `devtools::check()` 0 errors, 0 warnings, 0 notes; `devtools::document()` run.
- The planning container had no R. Run every command on a machine with R, ggplot2, the template Suggests and Quarto.

## Amendments to the design, made while planning

Recorded in the design file.

1. **`ggplot2::ggsave()` directly, not `hvtiPlotR::save_manuscript()`.** `save_manuscript()` accepts only a ggplot, and `hp`'s three figures are base graphics. Several tests mock `ggplot2::ggsave` to count saves, and calling it directly keeps them meaningful. The result is the same pair of files; `save_manuscript()`'s defaults (6 x 4 in, 300 dpi, cairo) are this helper's defaults.
2. **The switches govern the publication copies, not the report's own image.** Eight templates embed the PNG they save (`include_graphics()`), so that PNG is always written; `SAVE_FIGURES` and `FIGURES` decide whether its PDF is written beside it. For a figure the report prints directly, they decide whether both files are written.
3. **`FIGURES` matches by the start of a figure's name**, so `"dp-eda-continuous"` keeps every continuous page, and `"rfs-explain"` keeps all of that job's figures.
4. **No `EDIT:` markers** on the new choices (as in design 6).
5. **The helper accepts a list of plots and a drawing function.** The planner could not run ggRandomForests to see whether `plot(gg_variable(...))` returns one plot or a list; a list is saved as `<name>-1`, `<name>-2` and so on.

## Figure inventory

Line numbers are as of hvtiRtemplates `cf77df6`, before designs 3 and 4; find each chunk by its label if they have moved. "Linked" means the report embeds the saved PNG.

| template | chunk | figure name(s) | kind | size (in) | today | linked |
|---|---|---|---|---|---|---|
| dc-gfup | `figures` (405) | `dc-gfup-<panel>` | ggplot, loop | 7 x 6 | `ggsave` 150 dpi (462 to 463) | yes |
| dc-stddiff | `fig-balance` (434) | `dc-stddiff-balance` | ggplot | 7 x max(3, 1.5 + 0.25 n) | `ggsave` (456 to 457) | yes |
| dc-tables | `correlation` (346) | `dc-tables-correlation-matrix`, in `descriptive/` | ggplot | 10 x 10 | `png()`, `print()`, `dev.off()` (362 to 364) | yes |
| dp-eda | `gfup-panels` (479) | `dp-eda-gfup-<panel>` | ggplot, loop | 7 x 6 | `ggsave` (543 to 544) | yes |
| dp-eda | `sections` (553), `draw_section()` | `dp-eda-<section>-page-<NN>` | patchwork, loop | 11 x 8.5 | `ggsave` (590 to 592) | yes |
| dp-postage | `pages` (336) | `dp-postage-<section>-page-<NN>` | patchwork, loop | 11 x 8.5 | `ggsave` (402 to 404) | yes |
| dp-gfup | `figures` (287), `show_figure()` | `dp-gfup-<panel>` | ggplot, loop | 7 x 6 | `png()` (307 to 309) | yes |
| dp-trends | `figures` (397) | `dp-trends-<trend>-<subgroup>` | ggplot, loops | 8 x 6 | `png()` (452 to 454) | yes |
| hp | `fig-survival` (487), `fig-hazard` (509), `fig-phases` (532) | `hp-survival`, `hp-hazard`, `hp-phases` | **base** | 1400 x 1000 px at 150, so 9.33 x 6.67 | `png()` ... `dev.off()` | yes |
| bc, bh, bl, br | `fig-frequencies` | `<prefix>-frequencies` | ggplot | 6 x 7 (`fig-height: 7`) | printed only | no |
| nb-boostmtree | `fig-error`, `fig-path`, `fig-calibration`, `fig-importance`, `effects` (children), `fig-traces` | `nb-boostmtree-error`, `-path`, `-calibration`, `-importance`, `-effects-continuous`, `-effects-categorical`, `-traces` | ggplot | 6 x 4 | printed only | no |
| rfc-, rfr-, rfs-explain | `fig-importance`, `fig-varpro`, `fig-dependence-marginal`, `fig-dependence-partial`, `fig-dependence-varpro` | `<template>-importance`, `-varpro`, `-dependence-marginal`, `-dependence-partial`, `-dependence-varpro` | ggplot (dependence plots possibly a list) | 6 x 4 | printed only | no |
| rfc-fit | `fig-diagnostics-error`, `fig-diagnostics-roc` | `rfc-fit-diagnostics-error`, `-roc` | ggplot | 6 x 4 | printed only | no |
| rfr-fit | `fig-diagnostics-error`, `fig-diagnostics-predicted` | `rfr-fit-diagnostics-error`, `-predicted` | ggplot | 6 x 4 | printed only | no |
| rfs-fit | `fig-diagnostics-error`, `fig-diagnostics-survival`, `fig-diagnostics-brier` | `rfs-fit-diagnostics-error`, `-survival`, `-brier` | ggplot | 6 x 4 | printed only | no |

Nineteen templates. `ac` draws no figure; its figures are an `hp` job's (design section 1).

## File structure

| file | change |
|---|---|
| `R/save-figure.R` | create: `.save_figure()`, `.pdf_device()` |
| `tests/testthat/test-save-figure.R` | create |
| the 19 templates above | choices, wrapper, save calls |
| `tests/testthat/test-template-figures.R` | create: every figure template has the choices and wrapper and no direct `ggsave`/`png` |
| `tests/testthat/test-migrate-dp-postage.R`, `test-dp-eda.R` | expectations |
| `inst/templates/README.md` | figure names per template |
| `NEWS.md` | |

---

### Task 1: The helper

**Files:**
- Create: `R/save-figure.R`
- Test: `tests/testthat/test-save-figure.R` (create)

**Interfaces:**
- Produces: `.save_figure(plot, png, width = 6, height = 4, save = TRUE, keep = NULL, linked = FALSE)` returns `png`, invisibly.
  - `plot` is a ggplot or patchwork object, a list of them, or a function that draws base graphics.
  - `png` is the PNG path; the PDF path is the same with `.pdf`.
  - The figure's name is `png`'s file stem. It is *selected* when `save` is `TRUE` and `keep` is `NULL` or has an element the name starts with.
  - The PNG is written when the figure is selected or `linked`; the PDF only when it is selected.
  - A list is saved element by element as `<name>-1`, `<name>-2`, with the same rule, and the function returns their PNG paths.

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-save-figure.R`:

```r
save_figure_ <- hvtiRtemplates:::.save_figure
gg <- function() {
  skip_if_not_installed("ggplot2")
  ggplot2::ggplot(data.frame(x = 1:3, y = 1:3), ggplot2::aes(x, y)) + ggplot2::geom_point()
}

test_that("a selected ggplot is written as a PNG and a PDF of the same name", {
  dir <- withr::local_tempdir()
  out <- save_figure_(gg(), file.path(dir, "job-one.png"))
  expect_identical(out, file.path(dir, "job-one.png"))
  expect_true(file.exists(file.path(dir, "job-one.png")))
  expect_true(file.exists(file.path(dir, "job-one.pdf")))
})

test_that("SAVE_FIGURES = FALSE writes nothing unless the report links the PNG", {
  dir <- withr::local_tempdir()
  save_figure_(gg(), file.path(dir, "a.png"), save = FALSE)
  expect_length(list.files(dir), 0L)
  save_figure_(gg(), file.path(dir, "b.png"), save = FALSE, linked = TRUE)
  expect_identical(list.files(dir), "b.png")
})

test_that("FIGURES keeps the figures whose names start with one of its entries", {
  dir <- withr::local_tempdir()
  keep <- c("dp-eda-continuous", "hp-survival")
  save_figure_(gg(), file.path(dir, "dp-eda-continuous-page-01.png"), keep = keep)
  save_figure_(gg(), file.path(dir, "dp-eda-count-page-01.png"), keep = keep)
  expect_setequal(list.files(dir), c("dp-eda-continuous-page-01.png", "dp-eda-continuous-page-01.pdf"))
})

test_that("a list of plots is saved one file pair per element", {
  dir <- withr::local_tempdir()
  out <- save_figure_(list(gg(), gg()), file.path(dir, "rf-dependence.png"))
  expect_identical(basename(out), c("rf-dependence-1.png", "rf-dependence-2.png"))
  expect_true(all(file.exists(file.path(dir, c("rf-dependence-1.pdf", "rf-dependence-2.pdf")))))
})

test_that("a drawing function is saved through the graphics devices", {
  dir <- withr::local_tempdir()
  draw <- function() plot(1:3, 1:3)
  save_figure_(draw, file.path(dir, "hp-survival.png"), width = 9, height = 6)
  expect_true(all(file.exists(file.path(dir, c("hp-survival.png", "hp-survival.pdf")))))
  expect_identical(grDevices::dev.cur(), c("null device" = 1L))
})

test_that("without cairo the default PDF device is used", {
  dir <- withr::local_tempdir()
  local_mocked_bindings(.cairo_available = function() FALSE)
  expect_identical(hvtiRtemplates:::.pdf_device(), grDevices::pdf)
  save_figure_(gg(), file.path(dir, "c.png"))
  expect_true(file.exists(file.path(dir, "c.pdf")))
})

test_that("anything else is refused by name", {
  expect_error(save_figure_(42, file.path(tempdir(), "x.png")), "ggplot, a list of ggplots, or a function")
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "save-figure")'`
Expected: FAIL, `.save_figure` not found.

- [ ] **Step 3: Write the implementation**

Create `R/save-figure.R`:

```r
# Saving a template figure for a manuscript: a PNG to place in the Word draft,
# and a PDF of the same name for the publisher. Word converts an inserted PDF
# into a large EMF, so the two files have different jobs. Design: hvtiR
# dev/specs/2026-10-07-figures-pdf-png-design.md.
#
# A figure's name is its file stem, such as hp-survival or
# rfs-fit-diagnostics-brier. SAVE_FIGURES turns the publication copies off, and
# FIGURES keeps only the figures whose names start with one of its entries. A
# PNG the report embeds (`linked`) is written whatever they say, because the
# report would otherwise show a broken image.

.cairo_available <- function() isTRUE(capabilities("cairo"))

# Fonts are embedded with cairo, so 12 pt type prints as designed.
.pdf_device <- function() if (.cairo_available()) grDevices::cairo_pdf else grDevices::pdf

.save_figure <- function(plot, png, width = 6, height = 4, save = TRUE, keep = NULL, linked = FALSE) {
  if (is.list(plot) && !inherits(plot, "ggplot")) {
    stems <- sprintf("%s-%d.png", sub("[.]png$", "", png), seq_along(plot))
    for (i in seq_along(plot)) .save_figure(plot[[i]], stems[[i]], width, height, save, keep, linked)
    return(invisible(stems))
  }
  if (!inherits(plot, "ggplot") && !is.function(plot)) {
    stop("A figure to save must be a ggplot, a list of ggplots, or a function that draws one.", call. = FALSE)
  }
  name <- sub("[.]png$", "", basename(png))
  selected <- isTRUE(save) && (is.null(keep) || any(startsWith(name, keep)))
  pdf <- sub("[.]png$", ".pdf", png)
  if (selected || linked) .write_figure(plot, png, width, height, "png")
  if (selected) .write_figure(plot, pdf, width, height, "pdf")
  invisible(png)
}

.write_figure <- function(plot, file, width, height, format) {
  if (inherits(plot, "ggplot")) {
    device <- if (identical(format, "pdf")) .pdf_device() else "png"
    ggplot2::ggsave(file, plot, device = device, width = width, height = height, units = "in", dpi = 300)
    return(invisible(file))
  }
  if (identical(format, "pdf")) {
    .pdf_device()(file, width = width, height = height)
  } else {
    grDevices::png(file, width = width, height = height, units = "in", res = 300)
  }
  on.exit(grDevices::dev.off(), add = TRUE)
  plot()
  invisible(file)
}
```

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "save-figure")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/save-figure.R tests/testthat/test-save-figure.R
git commit -m "Add a helper that saves a template figure as PNG and PDF"
```

---

### Task 2: The study choices and the wrapper, in every figure template

**Files:**
- Modify: the 19 templates in the inventory
- Test: `tests/testthat/test-template-figures.R` (create)

- [ ] **Step 1: Write the failing test**

Create `tests/testthat/test-template-figures.R`:

```r
figure_templates <- c("dc-gfup", "dc-stddiff", "dc-tables", "dp-eda", "dp-postage", "dp-gfup", "dp-trends", "hp",
                      "bc", "bh", "bl", "br", "nb-boostmtree", "rfc-explain", "rfr-explain", "rfs-explain",
                      "rfc-fit", "rfr-fit", "rfs-fit")

template_source <- function(name) {
  tl <- template_list()
  readLines(tl$file[sub(".", "-", tl$name, fixed = TRUE) == name | tl$name == name], warn = FALSE)
}

test_that("every figure template offers the two choices and the wrapper, with no EDIT marker on them", {
  for (name in figure_templates) {
    src <- template_source(name)
    expect_true(any(src == "SAVE_FIGURES <- TRUE"), info = name)
    expect_true(any(src == "FIGURES <- NULL"), info = name)
    expect_true(any(grepl("^save_figure <- function\\(plot, name", src)), info = name)
    choices <- grep("SAVE_FIGURES|FIGURES <- ", src)
    expect_false(any(grepl("EDIT:", src[choices], fixed = TRUE)), info = name)
  }
})

test_that("no template saves a figure except through save_figure()", {
  for (name in figure_templates) {
    src <- template_source(name)
    expect_false(any(grepl("ggplot2::ggsave(", src, fixed = TRUE)), info = name)
    expect_false(any(grepl("^\\s*png\\(", src)), info = name)
  }
})
```

`template_source()` matches either the `dp.trends` display name (design 4) or the `dp-trends` file stem, so the test works whichever has landed.

- [ ] **Step 2: Run it to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "template-figures")'`
Expected: FAIL for all 19.

- [ ] **Step 3: Insert the choices and the wrapper**

From the package root, run once. It adds the two choices as the last lines of each template's `edit-study-choices` chunk (in `dp-trends.qmd` that is after its `# MIGRATE-END` marker), and the wrapper directly after the closing brace of `set_path()`:

```r
templates <- c("10_descriptive/dc-gfup", "10_descriptive/dc-stddiff", "10_descriptive/dc-tables",
               "10_descriptive/dp-eda", "10_descriptive/dp-postage", "40_graphs/dp-gfup", "40_graphs/dp-trends",
               "40_graphs/hp", "30_analyses/bc", "30_analyses/bh", "30_analyses/bl", "30_analyses/br",
               "30_analyses/nb-boostmtree", "30_analyses/rfc-explain", "30_analyses/rfr-explain",
               "30_analyses/rfs-explain", "30_analyses/rfc-fit", "30_analyses/rfr-fit", "30_analyses/rfs-fit")
choices <- c(
  "",
  "# Each figure is saved to graphs/ as a PNG (for Word) and a PDF (for the publisher).",
  "# SAVE_FIGURES <- FALSE saves neither; FIGURES keeps only the figures whose names",
  "# start with one of its entries, e.g. FIGURES <- c(\"hp-survival\"). The names are the",
  "# file names, listed for each template in the templates README.",
  "SAVE_FIGURES <- TRUE",
  "FIGURES <- NULL"
)
wrapper <- c(
  "",
  "# Saves a figure as graphs/<subject>-<type>/<name>.png and .pdf under the choices above.",
  "save_figure <- function(plot, name, width = 6, height = 4, kind = \"graphs\", linked = FALSE) {",
  "  hvtiRtemplates:::.save_figure(plot, set_path(kind, paste0(name, \".png\")), width, height,",
  "                                SAVE_FIGURES, FIGURES, linked)",
  "}"
)
for (t in templates) {
  f <- file.path("inst/templates", paste0(t, ".qmd"))
  x <- readLines(f, warn = FALSE)
  label <- which(x == "#| label: edit-study-choices")
  stopifnot(length(label) == 1L)
  fence <- label + which(x[(label + 1L):length(x)] == "```")[[1L]]
  x <- append(x, choices, after = fence - 1L)
  start <- grep("^set_path <- function", x)
  stopifnot(length(start) == 1L)
  close <- start + which(x[(start + 1L):length(x)] == "}")[[1L]]
  x <- append(x, wrapper, after = close)
  writeLines(x, f)
}
```

`save_figure()` reads `SAVE_FIGURES` and `FIGURES` when it is called, not when it is defined, so its position before or after the choices chunk does not matter.

- [ ] **Step 4: Run the test**

Run: `Rscript -e 'devtools::test(filter = "template-figures")'`
Expected: the first test PASSES; the second still FAILS for the templates with direct saves (Task 3).

- [ ] **Step 5: Commit**

```bash
git add inst/templates tests/testthat/test-template-figures.R
git commit -m "Give every figure template the SAVE_FIGURES and FIGURES choices"
```

---

### Task 3: The eight templates that save today

**Files:**
- Modify: `dc-gfup`, `dc-stddiff`, `dc-tables`, `dp-eda`, `dp-postage`, `dp-gfup`, `dp-trends`, `hp`
- Modify: `tests/testthat/test-migrate-dp-postage.R`, `tests/testthat/test-dp-eda.R`

Each edit replaces a save call and keeps the PNG path, the size, and the link to it. Quote each `from` exactly as it stands in the file; line numbers are from the inventory.

- [ ] **Step 1: `dc-gfup.qmd` (`figures` chunk)**

Replace

```r
  file <- set_path("graphs", paste0("dc-gfup-", nm, ".png"))
  ggplot2::ggsave(file, p, width = 7, height = 6, units = "in", dpi = 150)
```

with

```r
  file <- save_figure(p, paste0("dc-gfup-", nm), width = 7, height = 6, linked = TRUE)
```

- [ ] **Step 2: `dc-stddiff.qmd` (`fig-balance`)**

Replace

```r
file <- set_path("graphs", "dc-stddiff-balance.png")
ggplot2::ggsave(file, p, width = 7, height = max(3, 1.5 + 0.25 * nrow(balance)), units = "in", dpi = 150)
```

with

```r
file <- save_figure(p, "dc-stddiff-balance", width = 7, height = max(3, 1.5 + 0.25 * nrow(balance)), linked = TRUE)
```

- [ ] **Step 3: `dc-tables.qmd` (`correlation`)**

Replace

```r
    png(set_path("descriptive", fname), width = 10, height = 10, units = "in", res = 150)
    print(plot(cm) + theme_hv_manuscript())
    invisible(dev.off())
```

with

```r
    save_figure(plot(cm) + theme_hv_manuscript(), sub("[.]png$", "", fname), width = 10, height = 10,
                kind = "descriptive", linked = TRUE)
```

The child chunk's `include_graphics()` link to `<SUBJECT>-<TYPE>/fname` is unchanged.

- [ ] **Step 4: `dp-eda.qmd` (`gfup-panels` and `draw_section()`)**

Replace

```r
    file <- set_path("graphs", paste0("dp-eda-gfup-", nm, ".png"))
    ggplot2::ggsave(file, p, width = 7, height = 6, units = "in", dpi = 150)
```

with

```r
    file <- save_figure(p, paste0("dp-eda-gfup-", nm), width = 7, height = 6, linked = TRUE)
```

and replace

```r
    file <- set_path("graphs", sprintf("dp-eda-%s-page-%02d.png", section, i))
    ggplot2::ggsave(file, pages[[i]] & scale_fill_hv() & theme_hv_manuscript(base_size = 8),
                    width = 11, height = 8.5, units = "in", dpi = 150)
```

with

```r
    file <- save_figure(pages[[i]] & scale_fill_hv() & theme_hv_manuscript(base_size = 8),
                        sprintf("dp-eda-%s-page-%02d", section, i), width = 11, height = 8.5, linked = TRUE)
```

Match the indentation of each line as found; the text inside is exact.

- [ ] **Step 5: `dp-postage.qmd` (`pages`)**

Replace

```r
    file <- set_path("graphs", sprintf("dp-postage-%s-page-%02d.png", section, i))
    ggplot2::ggsave(file, pages[[i]] & scale_fill_hv() & theme_hv_manuscript(base_size = 8),
                    width = 11, height = 8.5, units = "in", dpi = 150)
```

with

```r
    file <- save_figure(pages[[i]] & scale_fill_hv() & theme_hv_manuscript(base_size = 8),
                        sprintf("dp-postage-%s-page-%02d", section, i), width = 11, height = 8.5, linked = TRUE)
```

`page_files` still collects only PNG paths, which `save_figure()` returns.

- [ ] **Step 6: `dp-gfup.qmd` (`show_figure()`)**

Replace

```r
  png(set_path("graphs", fname), width = 7, height = 6, units = "in", res = 150)
  print(p)
  invisible(dev.off())
```

with

```r
  save_figure(p, sub("[.]png$", "", fname), width = 7, height = 6, linked = TRUE)
```

- [ ] **Step 7: `dp-trends.qmd` (`figures`)**

Replace

```r
    png(set_path("graphs", fname), width = 8, height = 6, units = "in", res = 150)
    print(p)
    invisible(dev.off())
```

with

```r
    save_figure(p, sub("[.]png$", "", fname), width = 8, height = 6, linked = TRUE)
```

- [ ] **Step 8: `hp.qmd` (three base-graphics chunks)**

Each chunk today opens a device, draws, closes it, and embeds the file:

```r
png(set_path("graphs", "hp-survival.png"),
    width = 1400, height = 1000, res = 150)
<drawing lines>
dev.off()
knitr::include_graphics(set_path("graphs", "hp-survival.png"))
```

Rewrite each as a drawing function, saved and then embedded:

```r
draw <- function() {
  <drawing lines, unchanged>
}
knitr::include_graphics(save_figure(draw, "hp-survival", width = 1400 / 150, height = 1000 / 150, linked = TRUE))
```

Do this for `fig-survival` (`hp-survival`), `fig-hazard` (`hp-hazard`) and `fig-phases` (`hp-phases`). The drawing lines are everything between the `png(...)` call and `dev.off()`, moved inside `draw` with two more spaces of indent. `fig-phases`' `for` loop of `lines()` moves with them. Any object the drawing lines read is found by the function through its enclosing environment, the chunk's.

- [ ] **Step 9: Update the two tests that count files**

In `tests/testthat/test-migrate-dp-postage.R`, in the test around lines 196 to 211 that mocks `ggplot2::ggsave` and asserts `expect_identical(names(saved), "dp-postage-percent-page-01.png")`, change the expectation to:

```r
  expect_identical(names(saved), c("dp-postage-percent-page-01.png", "dp-postage-percent-page-01.pdf"))
```

In `tests/testthat/test-dp-eda.R`, around lines 71 to 78, `pages()` lists files with `paste0("^", stem, "-(continuous|percent|count)-")`, which now also matches the PDFs, and a PDF records its creation time, so two renders' PDFs differ byte for byte. Restrict it to the PNGs:

```r
  pages <- function(stem) list.files(graphs, paste0("^", stem, "-(continuous|percent|count)-.*[.]png$"),
                                     full.names = TRUE)
```

- [ ] **Step 10: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "template-figures|dc-gfup|dc-stddiff|dc-tables|dp-eda|migrate|migration|vignette-migration|hazard")'`
Expected: PASS. The PNG checks in `test-dc-gfup-figure.R`, `test-dc-stddiff.R`, `test-partial-render.R`, `test-migration-numbered-output.R`, `test-migrate-dp-trends.R` and `test-vignette-migration.R` still find the same PNG names in the same places.

- [ ] **Step 11: Commit**

```bash
git add inst/templates tests/testthat
git commit -m "Save the eight templates' existing figures as PNG and PDF through save_figure()"
```

---

### Task 4: The eleven templates that only print their figures

**Files:**
- Modify: `bc`, `bh`, `bl`, `br`, `nb-boostmtree`, `rfc-explain`, `rfr-explain`, `rfs-explain`, `rfc-fit`, `rfr-fit`, `rfs-fit`
- Test: `tests/testthat/test-template-figures.R` (append)

Each figure chunk keeps printing its figure into the report. It now also saves it. Two patterns cover every chunk.

- [ ] **Step 1: Write the failing test**

Append to `tests/testthat/test-template-figures.R`:

```r
test_that("every printed figure is also saved, under its documented name", {
  expected <- list(
    bc = "bc-frequencies", bh = "bh-frequencies", bl = "bl-frequencies", br = "br-frequencies",
    `nb-boostmtree` = c("nb-boostmtree-error", "nb-boostmtree-path", "nb-boostmtree-calibration",
                        "nb-boostmtree-importance", "nb-boostmtree-effects-", "nb-boostmtree-traces"),
    `rfc-fit` = c("rfc-fit-diagnostics-error", "rfc-fit-diagnostics-roc"),
    `rfr-fit` = c("rfr-fit-diagnostics-error", "rfr-fit-diagnostics-predicted"),
    `rfs-fit` = c("rfs-fit-diagnostics-error", "rfs-fit-diagnostics-survival", "rfs-fit-diagnostics-brier")
  )
  for (t in c("rfc-explain", "rfr-explain", "rfs-explain")) {
    expected[[t]] <- paste0(t, c("-importance", "-varpro", "-dependence-marginal", "-dependence-partial",
                                 "-dependence-varpro"))
  }
  for (name in names(expected)) {
    src <- template_source(name)
    saves <- src[grepl("save_figure(", src, fixed = TRUE)]
    for (fig in expected[[name]]) {
      expect_true(any(grepl(paste0("\"", fig), saves, fixed = TRUE)), info = paste(name, fig))
    }
  }
})
```

- [ ] **Step 2: Run it to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "template-figures")'`
Expected: FAIL for the eleven templates.

- [ ] **Step 3: Pattern A, a chunk that ends in an expression**

A chunk whose last line is a plot expression (`plot(err)`, `plot(gg_vimp(vi))`, or the `ggplot(...) + ... + theme_minimal()` of the `fig-frequencies` chunks) changes from

```r
<expression>
```

to

```r
.fig <- <expression>
save_figure(.fig, "<name>")
.fig
```

For the four `fig-frequencies` chunks, which set `fig-height: 7`, use `save_figure(.fig, "<prefix>-frequencies", height = 7)`. A multi-line `ggplot(...) + ...` expression is assigned whole: put `.fig <- ` before its first line.

Apply it to:
- `bc`, `bh`, `bl`, `br`: `fig-frequencies`, named `bc-frequencies`, `bh-frequencies`, `bl-frequencies`, `br-frequencies`.
- `rfc-explain`, `rfr-explain`, `rfs-explain`: the five chunks, named `<template>-importance`, `-varpro`, `-dependence-marginal`, `-dependence-partial`, `-dependence-varpro`.
- `rfc-fit`: `fig-diagnostics-error`, `fig-diagnostics-roc`.
- `rfr-fit`: `fig-diagnostics-error`, `fig-diagnostics-predicted`.
- `rfs-fit`: `fig-diagnostics-error`, `fig-diagnostics-survival`, `fig-diagnostics-brier`.

The fit templates' names follow the pattern `<template>-diagnostics-<what>`.

If an expression returns a list of plots (possible for the dependence plots), `save_figure()` saves each element as `<name>-1`, `<name>-2`, and the chunk still prints `.fig` as before.

- [ ] **Step 4: Pattern B, a chunk that ends in a named object**

`nb-boostmtree`'s chunks end in an object already named (`p_error`, `p_path`, `p_calibration`, `p_vimp`, `p_traces`). Before that last line add one line:

```r
save_figure(p_error, "nb-boostmtree-error")
```

with `p_path` and `nb-boostmtree-path`, `p_calibration` and `nb-boostmtree-calibration`, `p_vimp` and `nb-boostmtree-importance`, `p_traces` and `nb-boostmtree-traces`.

In the `effects` chunk, inside the loop that builds each child from `.p <- p_effects[[.i]]`, add after that assignment:

```r
  save_figure(.p, paste0("nb-boostmtree-effects-", .kinds[[.i]]))
```

- [ ] **Step 5: Run the tests**

Run: `Rscript -e 'devtools::test()'`
Expected: `FAIL 0`. The template render tests (rf, nb, bootstrap) now write figure pairs into their temporary studies; nothing asserts their absence.

- [ ] **Step 6: Commit**

```bash
git add inst/templates tests/testthat/test-template-figures.R
git commit -m "Save the figures that eleven templates only printed"
```

---

### Task 5: Documentation, NEWS and gates

- [ ] **Step 1: List the figure names**

In `inst/templates/README.md`, add a section "Saved figures":

```markdown
## Saved figures

Every figure a job draws is saved to `graphs/<subject>-<type>/` as a PNG, to
place in a Word draft, and a PDF of the same name, for the publisher's
high-resolution submission. In a job's study choices, `SAVE_FIGURES <- FALSE`
saves neither, and `FIGURES` keeps only the figures whose names start with one
of its entries, such as `FIGURES <- c("hp-survival", "hp-hazard")`. A PNG the
report itself shows is written either way.

| template | figure names |
|---|---|
| dc-gfup | `dc-gfup-<panel>` |
| dc-stddiff | `dc-stddiff-balance` |
| dc-tables | `dc-tables-correlation-matrix` (in `descriptive/`) |
| dp-eda | `dp-eda-gfup-<panel>`, `dp-eda-<section>-page-<NN>` |
| dp-postage | `dp-postage-<section>-page-<NN>` |
| dp-gfup | `dp-gfup-<panel>` |
| dp-trends | `dp-trends-<trend>-<subgroup>` |
| hp | `hp-survival`, `hp-hazard`, `hp-phases` |
| bc, bh, bl, br | `<prefix>-frequencies` |
| nb-boostmtree | `nb-boostmtree-error`, `-path`, `-calibration`, `-importance`, `-effects-<kind>`, `-traces` |
| rfc-, rfr-, rfs-explain | `<template>-importance`, `-varpro`, `-dependence-marginal`, `-dependence-partial`, `-dependence-varpro` |
| rfc-fit | `rfc-fit-diagnostics-error`, `-roc` |
| rfr-fit | `rfr-fit-diagnostics-error`, `-predicted` |
| rfs-fit | `rfs-fit-diagnostics-error`, `-survival`, `-brier` |

Sizes are the template's own, or 6 x 4 in where a figure was not saved before.
Figure sizes, axis labels and confidence-interval style are team standards
still to be settled.
```

- [ ] **Step 2: NEWS.** Under `# hvtiRtemplates (unreleased)`:

```markdown
* **Every template figure is saved as a PNG and a PDF.** Figures go to the
  job's `graphs/<subject>-<type>/` folder as a 300 dpi PNG, for a Word draft,
  and a PDF of the same name with fonts embedded, for the publisher. Eight
  templates saved a PNG before, at 150 dpi; eleven (bc, bh, bl, br,
  nb-boostmtree and the six random-forest templates) only printed their
  figures. Each job's study choices gain `SAVE_FIGURES` and `FIGURES` to turn
  saving off or keep only some figures by name; `inst/templates/README.md`
  lists the names. A PNG the report shows keeps its name and is always written.
```

- [ ] **Step 3: Gates.** `Rscript -e 'devtools::document()'`, `lintr::lint_package()`, `devtools::test()`, `devtools::check(document = FALSE, manual = FALSE)`. Expected: no lints; `FAIL 0` with the `SKIP` count unchanged from `main`; 0 errors, 0 warnings, 0 notes.
- [ ] **Step 4: End to end.** In a scratch study:
  1. Render an `hp` job. `graphs/<subject>-<type>/` holds three PNG and PDF pairs, and the report shows the three figures.
  2. Set `FIGURES <- "hp-survival"` and render again. The other two PDFs are not rewritten, and their PNGs are, because the report shows them.
  3. Render an `rfs-fit` job. It writes three pairs.
  4. Open one PDF to confirm the text is selectable, which shows the fonts are embedded.
- [ ] **Step 5:** Commit (`git add inst/templates/README.md NEWS.md man && git commit -m "Document saved figures"`), push, open the pull request linking the design and this plan.

---

## Self-review

- **Spec coverage.**
  - Section 3, the helper: Task 1.
    - Its "uses `save_manuscript()`" is amended to `ggsave()`, with the same files and defaults.
    - The cairo switch and returning paths are in Task 1.
    - Provenance artifacts are not wired: the PNG paths are returned for a later change to list.
  - Section 3, the choices: Task 2.
  - Section 3, stable names: the inventory and Task 5.
  - Section 3, moving the eight existing saves: Task 3.
  - Section 3, saving printed figures: Task 4.
  - Section 3, the `hvtiPlotR` minimum: no longer needed, since the helper uses ggplot2, already in `Suggests`.
  - Section 4, open standards: Task 5's README note.
  - Section 5, tests:
    - the helper writing both files: Task 1;
    - `SAVE_FIGURES` and `FIGURES`: Task 1;
    - no cairo: Task 1;
    - a rendered `ac` producing its figure pair: corrected to `hp` (Task 5, Step 4), because `ac` draws no figure.
- **Placeholders.** `<expression>`, `<name>` and `<drawing lines>` in Tasks 3 and 4 are filled per chunk from the inventory, which gives every name; the pattern is the code. No `TBD`.
- **Names.** `.save_figure()`, `.write_figure()`, `.pdf_device()`, `.cairo_available()`, the template wrapper `save_figure()`, and the choices `SAVE_FIGURES` and `FIGURES` are spelled the same throughout.
