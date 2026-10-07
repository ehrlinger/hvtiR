# Every template figure saved as PDF and PNG

**Written** 2026-10-07.
**Status** Design, approved. Not implemented.
**Repo** `hvtiRtemplates`. Uses `hvtiPlotR::save_manuscript()` as it is.
Recorded in `hvtiR`; see [the overview](2026-10-07-team-review-overview.md).
**Order** Fifth of five.

---

## 1. The problem

A template renders to HTML, which is fine for reading. A manuscript needs the
figures as files: **PNG** to place in the Word draft, and **PDF** for the
publisher's high-resolution submission.

Today the templates do this unevenly:

- eight templates write figures, as **PNG only**, mostly at 150 dpi, through
  `ggplot2::ggsave()` or base `png()`: `dc-gfup`, `dc-tables`, `dc-stddiff`,
  `dp-eda`, `dp-postage`, `hp`, `dp-trends`, `dp-gfup`;
- the rest show figures **only in the HTML**. `ac`, the example used in the
  training, saves its estimates as `.rds` and no figure files at all.

The training agreed the rule: make the team standard the default, and leave a way
out for exceptions.

## 2. What exists

`hvtiPlotR::save_manuscript()` (since 2.7.3) already writes both files in one call, at
the house manuscript size (6 x 4 in) and 300 dpi:

```r
save_manuscript(p, "fig.pdf", draft_file = "fig.png")
```

Its documentation explains the split: Word converts an inserted PDF into a large
EMF, so the PNG goes into Word and the PDF goes to the journal. For font embedding
it documents `device = grDevices::cairo_pdf`.

Every template that reads the study dataset already has `set_path("graphs",
file)`, which writes into `graphs/<subject>-<type>/`.

## 3. The change

**One internal helper** in `hvtiRtemplates`, used by every template:

```r
save_figure(p, name, width = 6, height = 4)
```

- It does nothing when `SAVE_FIGURES` is `FALSE`, or when `FIGURES` is set and
  does not include `name`.
- Otherwise it calls `hvtiPlotR::save_manuscript()`, writing
  `graphs/<subject>-<type>/<name>.pdf` and `<name>.png` at 300 dpi.
- It uses `grDevices::cairo_pdf` when `capabilities("cairo")` is `TRUE`, and the
  default PDF device otherwise.
- It returns the two paths invisibly, so the provenance record can list them as
  artifacts.

**The "edit study choices" chunk** in every template that draws a figure gains:

```r
# EDIT: save each figure as PDF (publisher) and PNG (Word).
SAVE_FIGURES <- TRUE
# EDIT: NULL saves every figure; a vector keeps only those, e.g. c("survival").
FIGURES <- NULL
```

**Each figure gets a stable name.** The help text for `FIGURES` lists each
template's figure names, so a job with ten figures can keep two.

**The eight existing `ggsave()` and `png()` calls** move to `save_figure()`.
Templates that only display figures start saving them.

`hvtiPlotR` stays in `Suggests`. `draft_file` arrived in 2.7.3, so the current
`>= 2.8.0` minimum already covers it.

## 3a. Amendments made while planning (2026-10-07)

Recorded in [the plan](2026-10-07-figures-pdf-png-plan.md) too, which lists every
figure, its name and its size.

1. **`ggplot2::ggsave()` directly, not `hvtiPlotR::save_manuscript()`.** `hp`'s three
   figures are base graphics, which `save_manuscript()` refuses, and several tests
   mock `ggplot2::ggsave` to count saves. Same files, same defaults (300 dpi, cairo
   PDF); `hvtiPlotR` stays as it is.
2. **The switches govern the publication copies.** Eight templates embed the PNG
   they save, so that PNG is always written; `SAVE_FIGURES` and `FIGURES` decide its
   PDF. For a figure the report prints directly, they decide both files.
3. **`FIGURES` matches the start of a name**, so `"dp-eda-continuous"` keeps every
   continuous page.
4. **No `EDIT:` markers** on the new choices, so a finished job does not render as a
   draft (as in design 6).
5. **A list of plots and a drawing function are accepted**, for base graphics and
   for plot methods that may return several plots.
6. **Sizes:** a figure saved today keeps its size; a newly saved one is 6 x 4 in, or
   its chunk's `fig-height`. Section 5's "a rendered `ac` job" becomes `hp`, since
   `ac` draws no figure.

## 4. Open team standards (not decided here)

The training asked for team defaults with exceptions. These are for the team to
decide, and the helper's arguments are where the answers will go:

- figure size per template (the 6 x 4 in house default, or others);
- axis-label defaults, and how a study overrides one (the x axis was the example);
- confidence intervals as bars or bands;
- labels on the numbers-at-risk rows;
- whether panels (A/B) are combined in R rather than by hand.

## 5. Tests

- `save_figure()` writes a PDF and a PNG into the set's `graphs/` folder.
- `SAVE_FIGURES <- FALSE` writes nothing; `FIGURES` restricts to the names given.
- Without cairo (mocked), the default PDF device is used and the call succeeds.
- A rendered `ac` job produces its figure pair.
