# Coverage consistency: prototype report

`dev/specs/2026-09-04-job-catalog-design.md` section 9 deferred a check for
rows that share a reporting surface but disagree on disposition, and
recommended prototyping the destination-plus-family definition as a report
rather than a gate. This is that prototype, run against `inst/extdata/jobs.json`
with `dev/specs/artifacts/coverage-consistency.py`.

## Finding 1: section 9 misstates the `rfc` evidence

Section 9 says the destination-plus-family rule "would have caught `rfc`: `rf`,
`rfsrc`, `rfs`, `rfc` and `rfr` are all `machine-learning` routed to
`ggRandomForests`, and three dispositions among them is the anomaly."

Measured against the catalog as it stood at commit `11cf860` (the commit that
first routed every job to the package that owes it):

```
[FLAG] destination='ggRandomForests' family='machine-learning' rows=7
       prefixes: ['rf', 'rfc', 'rfs', 'rfsrc', 'rfr', 'sid', 'vt']
       dispositions: {'retire': 5, 'build': 2}
       statuses: {'out-of-scope': 2, 'queued': 2, 'intake': 3}
```

That is TWO dispositions (`retire`, `build`), not three, and THREE statuses
(`out-of-scope`, `queued`, `intake`). The rule would have caught `rfc` on the
STATUS axis, not the disposition axis section 9 credited.

This changes the recommendation. Pull request #43 has since closed the status
axis with an explicit rule: `status` and `batch` are null for a row destined
elsewhere, except `intake`. A status disagreement within a group is therefore
now DERIVABLE rather than a free choice, so a status mismatch inside a
destination-plus-family group carries no signal any more; it is expected. The
one thing the heuristic is on record as having actually caught has been
superseded by a real rule, and what is left to prototype is the disposition
axis alone, on its own evidence, not on the borrowed credit of the `rfc`
catch.

## Finding 2: the disposition axis, run today, is one real finding and one false positive

Running the script against the current catalog:

```
catalog: inst/extdata/jobs.json
rows: 53
groups (destination, family): 12

[    ] destination='ggBoostedTrees' family='machine-learning' rows=1
       prefixes: ['nb']
       dispositions: {'build': 1}
       statuses: {None: 1}

[FLAG] destination='ggRandomForests' family='machine-learning' rows=7
       prefixes: ['rf', 'rfc', 'rfs', 'rfsrc', 'rfr', 'sid', 'vt']
       dispositions: {'retire': 5, 'build': 2}
       statuses: {None: 4, 'intake': 3}

[    ] destination='hvtiPlotR' family='plots' rows=4
       prefixes: ['ce', 'cp', 'fp', 'gp']
       dispositions: {'build': 4}
       statuses: {None: 4}

[    ] destination='hvtiRtemplates' family='bootstrap' rows=5
       prefixes: ['bc', 'bh', 'bl', 'bq', 'br']
       dispositions: {'scaffold': 5}
       statuses: {'shipped': 4, 'queued': 1}

[    ] destination='hvtiRtemplates' family='bootstrap-ci' rows=1
       prefixes: ['bn']
       dispositions: {'scaffold': 1}
       statuses: {'queued': 1}

[    ] destination='hvtiRtemplates' family='datasets' rows=3
       prefixes: ['bd', 'dt', 'vars']
       dispositions: {'scaffold': 3}
       statuses: {'queued': 3}

[    ] destination='hvtiRtemplates' family='descriptive' rows=7
       prefixes: ['lg', 'rg', 'dc', 'dc', 'dc', 'dc', 'dc']
       dispositions: {'scaffold': 7}
       statuses: {'queued': 7}

[    ] destination='hvtiRtemplates' family='distributions' rows=4
       prefixes: ['ac', 'cd', 'hz', 'nd']
       dispositions: {'scaffold': 4}
       statuses: {'shipped': 2, 'queued': 2}

[    ] destination='hvtiRtemplates' family='documents' rows=1
       prefixes: ['ar']
       dispositions: {'scaffold': 1}
       statuses: {'queued': 1}

[    ] destination='hvtiRtemplates' family='hazard-chain' rows=2
       prefixes: ['hm', 'hs']
       dispositions: {'scaffold': 2}
       statuses: {'shipped': 2}

[    ] destination='hvtiRtemplates' family='models' rows=8
       prefixes: ['cm', 'gm', 'lm', 'ls', 'mm', 'nm', 'pm', 'rm']
       dispositions: {'scaffold': 8}
       statuses: {'queued': 8}

[FLAG] destination='hvtiRtemplates' family='plots' rows=10
       prefixes: ['hp', 'lp', 'mp', 'np', 'rp', 'dp', 'dp', 'dp', 'dp', 'dp']
       dispositions: {'thin': 9, 'scaffold': 1}
       statuses: {'revisit': 1, 'queued': 9}

2 of 12 groups carry more than one disposition
```

Two groups flag today. They are not the same kind of finding.

**`hvtiRtemplates` / `plots`: nine `thin`, one `scaffold`.** The `scaffold` row
is `dp-variable`. It is worth attention, but as an open question rather than a
defect with a known fix: `dp-variable` is the only `dp` row whose `folder` is
`distributions`, while every sibling `dp` row (`dp-trends`, `dp-gfup`,
`dp-spaghetti`, `dp-procs`) is `folder: graphs`, yet all five carry
`family: plots`. Its `scaffold` disposition also looks like a seeded default
rather than an audited decision, because the original coverage audit covered
the `graphs` folder only. It may be that `scaffold` is correct and `folder` or
`family` is the field that is wrong, or the reverse; this report does not
resolve it, it surfaces it.

**`ggRandomForests` / `machine-learning`: five `retire`, two `build`.** This
is legitimate, not a defect. `sid` and `vt` genuinely have no function written
yet, which is what `build` means, and the other five rows are correctly
`retire`. A gate built on this rule would have failed the catalog on a
correct state.

One flag out of two is real. On a 12-group catalog, that is not a track record
that justifies blocking a merge on it.

## The `replaced_by` alternative, and why it stays unattractive

Section 9's other candidate, grouping by `replaced_by` overlap, is cheaper and
more precise in principle, but it can only see rows whose `replaced_by` is
populated. At the time of the `rfc` failure that motivated this whole line of
work, `replaced_by` was empty, so that definition could not have caught the
motivating case at all. It is not evaluated further here for that reason.

## Recommendation

Do not make this a gate. Keep `dev/specs/artifacts/coverage-consistency.py` as
a script to run by hand, when the catalog grows or when a routing decision is
on the table, not as a CI check.

One of the two flags this run produced is a false positive that a gate would
have failed on. A check that is wrong half the time on a catalog this small
is worse than no check, which is exactly what section 9 anticipated. It also
means the recommendation is provisional rather than closed: what would change
it is either the catalog growing enough rows that the false-positive rate
falls to something a gate could tolerate, or someone finding a definition of
"shares a surface" sharper than destination plus family, one that would not
have flagged `sid`/`vt` alongside a genuine problem in the first place.

## Update 2026-09-05: the open question is closed, and it was the check's first true positive

The `dp-variable` open question above is resolved. Reading real jobs in the
corpus (four jobs across four studies in two top level trees, all the same
shape: a descriptive graph of one variable against follow-up time alone, no
covariates, quantile or decile time groupings, plus a trend test; one of the
four the ordinal variant) confirms `folder: distributions` and
`family: plots` were both already correct. The field that was wrong was
`disposition`: it should have been `thin`, not `scaffold`, because the shape
is served by two existing `hvtiPlotR` exports rather than needing a new
template built from nothing. `inst/extdata/jobs.json` now reads `disposition:
"thin"` on that row with `replaced_by` naming both functions.

That makes `dp-variable` the disposition check's **first true positive**: a
real mis-disposition, not a seeded default, caught by exactly the
destination-plus-family grouping this report evaluated above. The
recommendation against a gate is unchanged, because the report's other flag,
`ggRandomForests`/`machine-learning`, remains a genuine false positive (two
rows correctly `build` rather than `retire`) that a gate would have failed
the catalog on. One true positive and one false positive out of two flags is
still not a track record that justifies blocking a merge on this rule; it is
simply no longer zero true positives.

One more observation worth carrying forward rather than treating as a defect:
`graphs`/`dp-trends` and `distributions`/`dp-variable` now both name
`hvtiPlotR::hv_trends` in `replaced_by`. This is intentional. The
decomposition design deliberately created both rows, and studies keep the two
job types in separate folders, so the overlap reflects one function serving
two distinct catalog entries, not a duplicate row. It is worth watching,
because two rows naming the same function is exactly the shape a
`replaced_by`-overlap grouping (the alternative this report declined to
evaluate above) would key on, and a future attempt at that alternative should
expect to see it and not treat it as a finding on its own.
