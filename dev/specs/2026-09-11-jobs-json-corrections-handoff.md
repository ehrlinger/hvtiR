# Handoff: the jobs.json corrections queued from the 2026-09-11 umbrella meeting

**Date:** 2026-09-11
**Repo:** `hvtiR`, one PR against `inst/extdata/jobs.json`.
**Status:** ✅ done 2026-09-11 on `fix/catalog-corrections-0911`, except the deck, which
the maintainer regenerates. Three premises below did not survive measurement, and the
sections are left as written so the correction can be read against them:

- **§2, `pm` is not misfiled `lm`.** `hvti_taxonomy()` defines `pm` as a count outcome
  with a balancing score. Across its 4 studies, 7 of 8 SAS programs are `PROC GENMOD
  dist=nb`, and 2 compute the score outright. No parse rule was wrong. The row is `thin`
  over `hvtiRpropensity::bs_count()`, which ports `tp.pm.count.balncing_score.sas`, and
  its 4 stands. The label "Propensity model" is what misled the room, and renaming it
  is `hvtiRutilities`' change.
- **§3, neither prose was right.** The design record is right that `sas_breadth_jobs`
  counts distinct studies. But 223 and 326 count studies *calling* the imputation
  macros, not studies holding an `si`/`mi` job, which by job name are 1 and 1. The
  maintainer put 223 and 326 in the field as a stated exception, now recorded in the
  catalog design, §5.
- **§4's four variants were five.** `std_dif_all_bef-aft` (13 studies) was folded in by
  the maintainer, so the union is 120, against a sum of 157.

All counts come from `census-ALL.csv` (the 2026-08-27 sweep), scanned 2026-09-11. The scan
first reproduced the 2026-09-02 `sas_breadth_jobs` for all 42 prefixes and the 2026-08-29
`r_jobs` and `r_studies_deflated` for all 42, with no mismatch.
**Origin:** the umbrella project status review, 2026-09-11, where the catalog page was on
screen and the room read it back. Plus two rules the maintainer stated afterwards.

⚠️ No study number, proposal number or patient detail appears here, and none may appear in
what this produces. Counts only.

---

## The two rules that govern the whole PR

⭐ **1. Where two spellings name the same job, the newer macro's spelling wins.** Stated
2026-09-11. This is not a new rule so much as the generalisation of a decision already in
the catalog: `dc-stddiff` ships the **2019** `stddiff.sas` and not the **2009**
`std_dif.sas`, recorded in that row's note as *"the wider corpus use of std_dif is a macro
outliving its replacement, not a preference."* Make it a stated rule rather than a
per-row judgement, because the next collision will otherwise be argued from scratch.

⚠️ **The rule decides the label. It must not decide the count.** Both spellings are the
same job, so both populations belong in the row. See §4.

⭐ **2. SAS breadth is the figure of record; R stays, and stays measured.** Stated
2026-09-11: most interested in SAS jobs, R important to keep. So `sas_breadth_jobs` is the
primary column and the R fields are not to be dropped or left to rot. The deck's catalog
page now reads `sas_breadth_jobs` for exactly this reason.

## 1. `pm` is routed to the wrong package

**What was said.** Maintainer, in the room: *"Propensity modeling is all going to be done
in the propensity package. Just like the imputation is."*

**What the row says now:** `disposition: scaffold`, `destination: hvtiRtemplates`, no
`replaced_by`, `blocked_on` empty.

🔴 **Do not just swap `destination`.** The imputation parallel he drew is specific and the
catalog already encodes it: `si` and `mi` keep `destination: hvtiRtemplates` and name
`hvtiRimputation` in `blocked_on`. The template stays a template; the method lives in the
package. Applied to `pm`, that is a `blocked_on` change, not a destination change.

But `hvtiRpropensity` is further along than `hvtiRimputation` was. At 0.1.3 it exports
`ps_logistic()`, `ps_match()`, `ps_weight()`, `ps_nominal()`, `ps_ordinal()`, plus the
`sa_*` sensitivity family. **If those already cover the job, `pm` is `thin` with
`replaced_by` naming them**, which is how every `dp` row is written, and it is a stronger
claim than `blocked_on`.

**Decide by reading the package, not by analogy.** Three candidate shapes:

| shape | when it is right |
|---|---|
| `thin`, `replaced_by: hvtiRpropensity::ps_*` | the exports cover the job today |
| `scaffold` + `blocked_on: hvtiRpropensity` | the job needs something not yet exported |
| `build`, `destination: hvtiRpropensity` | the package owes a function nobody has written |

## 2. `pm`'s count is borrowed from `lm`, and both rows are wrong

**What was said.** *"Your PM, that's all in the LM job. That's all in the logistics."*
Whoever created those jobs used the wrong prefix. A second voice in the room expected
**zero** `pm` jobs to exist; the catalog carries `sas_breadth_jobs: 4`.

🔴 **Do not hand-edit either number.** `pm` at 4 and `lm` at 469 both come out of the
2026-09-02 per-folder re-parse. Editing the JSON fixes the display and leaves the rule that
produced it intact, so the next scan silently restores the wrong figures. The maintainer
said the same thing in the room: *"all I'm doing is reading these files with the rules I
have and you have to fix my rules."*

**So this one is a scan change first, a catalog change second.** Until the rule changes,
the honest state is that `pm`'s 4 and `lm`'s 469 are both suspect and neither is
independently correct.

⚠️ **Expect the fix to be smaller than it sounds.** If all `pm` jobs are misfiled `lm`,
`lm` gains at most 4 distinct studies against a base of 469, and `pm` goes to zero or near
it. **A row that measures zero is a finding, not an empty row**: it says the taxonomy
carries a prefix the corpus never used, which is a different statement from "not yet
counted" and should not be rendered as a dash.

## 3. `si` and `mi`: a unit conflict to resolve before the numbers can land

The counts exist. 223 studies call single mean imputation, 326 call multiple, 18 call both,
measured 2026-09-05. They are in each row's `note` as prose and **not** in any count field,
so the catalog page renders both rows as dashes.

🔴 **Two statements in the repo contradict each other, and this PR has to settle which
holds.**

- `si`'s note: *"223 studies ... (STUDY count, not files; `sas_breadth` is left null
  because it holds file/job counts elsewhere in this catalog)."*
- `hvtiRtemplates` `dev/specs/2026-09-02-per-folder-naming-parse-design.md` §4:
  *"`sas_breadth` is a distinct-study count and the buckets must not be summed."*

If the design record is right, the note's parenthetical is wrong, 223 and 326 belong in
`sas_breadth_jobs`, and two of the six remaining dashes fill with no new measurement. If
the note is right, the field means something else for some rows and the column is not
comparable down its own length, which is worse than a dash.

**Settle it from the re-parse artifact, not from either prose.** Check what
`sas_breadth_jobs` counts for a row whose value is known, and write the answer into the
catalog's own documentation so the next person does not re-litigate it.

## 4. `dc-stddiff` is undercounted by its own triage

`sas_breadth_jobs: 59`, which is the `stddiff` spelling alone. The row's note, from the
2026-09-10 triage, says four legacy variants **fold into this row**: `std_dif`,
`stddif_mtch_mtwt`, `stdcoef_diff.continuous` and `stddiffci.sumtbl`.

🔴 **A row that absorbs four variants must count them.** `std_dif` alone is 72 studies
against this row's 59. **Do not add 72 and 59.** These are distinct-study counts and a
study using both spellings is one study; the re-parse design is explicit that the buckets
must not be summed. The union has to come from the scan.

Rule 1 settles the **label**: the row stays `stddiff`, the 2019 spelling. Rule 1 says
nothing about the population, and reading it as though it did is how the row ends up
counting the newer macro's users and silently dropping the older macro's.

## 5. The R side, which is not to be left behind

All 18 uncounted rows are null in `r_jobs` **and** `r_exemplars`, including all 13
qualifier rows that now carry a SAS figure. The 2026-09-02 re-parse counted SAS jobs per
qualifier and never did the R side, so the catalog page shows a filled SAS column beside an
empty R one for every `dc` and `dp` row.

Per rule 2 this is a follow-up rather than a blocker, but it is a follow-up with a date on
it: the R column is the one that shows the port moving, and it currently cannot show
movement in the thirteen rows where the port is actually happening.

## Definition of done

- [ ] Rules 1 and 2 written into the catalog's own documentation, not just this note
- [ ] `pm` routing decided by reading `hvtiRpropensity`, and the row rewritten to match
- [ ] `pm` / `lm` misfiling fixed **in the parse rule**, then re-scanned, then the catalog
      updated from the scan
- [ ] A measured zero rendered as zero, never as a dash
- [ ] The `sas_breadth_jobs` unit question settled and documented
- [ ] `si` and `mi` carry their counts in a field, once the unit is settled
- [ ] `dc-stddiff` re-counted over the union of its four folded variants
- [ ] `r_jobs` and `r_exemplars` filled for the 13 qualifier rows
- [ ] The deck's catalog page regenerated; it reads this file directly

## Not in this PR

The room asked for a human pass over every row of the catalog page, looking for names a
person would not recognise. `pm` was found that way, and `dc` and `dp` before it. That
review is a person reading a printout, not a code change, and it will produce more rows
like these.

One name is already queued for it: **`ls`, "Life table / STS"**, which nobody in the room
could explain. The name was read from the files rather than written by hand.
