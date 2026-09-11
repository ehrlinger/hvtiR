# The job catalog

Every job type found in the studies corpus, with the package that owes
it. A job type is keyed on `prefix` and `qualifier` together, because
one prefix can carry several job types.

## Usage

``` r
jobs()
```

## Value

A data frame with one row per job type. `replaced_by` is a list column
of character vectors, empty where nothing replaces the row.

## Details

`disposition` says what kind of work a row is:

- `scaffold`, genuinely repeated work; a template is the deliverable

- `thin`, a template whose body is mostly calls into `replaced_by`

- `retire`, the work is a function that exists; no template is owed

- `build`, the work is a function that does not exist yet

`destination` names who owes the remaining work. `replaced_by` names
what already exists, as `package::function`, and is frequently in a
different package from `destination`: a thin template lives in
`hvtiRtemplates` and leans on `hvtiPlotR`.

The count columns are distinct counts over the studies corpus, so they
never sum across rows. `sas_breadth_jobs`, the studies holding a program
of the job type, is the figure of record. `sas_breadth` counts files of
any extension and predates the qualifier parse, so it is `NA` on a
qualified row. `r_jobs` counts R jobs. `r_exemplars` counts the studies
holding one, leaving out any job name found in more than 100 studies,
because one script copied that widely would otherwise count as precedent
in every study it reached. `NA` means not measured and `0` means
measured and none found. `dev/specs/2026-09-04-job-catalog-design.md`
defines each unit.

The catalog file also carries a top-level `options` list beside `jobs`.
An option is a construct shared across prefixes, such as a landmark
early / late split or a matched analysis. It is not a job type, so
`jobs()` does not return it; each entry names the prefixes it applies to
and the census evidence for it.

The taxonomy that says what a prefix *means* is
[`hvtiRutilities::hvti_taxonomy()`](https://ehrlinger.github.io/hvtiRutilities/reference/hvti_taxonomy.html).
This catalog says who owes it. They are apart because validating a
routing has to load the destination package, and `hvtiRutilities` is
imported by packages this catalog routes to.

`status` and `batch` are `hvtiRtemplates` scheduling fields: they answer
when `hvtiRtemplates` will ship a template for a row, not whether the
row is done. Both are null in the catalog for a row whose `destination`
is neither `hvtiRtemplates` nor null, because that repository has
nothing of its own to schedule there. `jobs()` surfaces `status` as `NA`
in the `status` column; it does not surface `batch` at all, so a caller
after that field reads the catalog row directly. The one exception to
the nulling is `status == "intake"`, which survives regardless of
`destination`: it is not a schedule value at all, but a taxonomy fact
meaning the prefix has been proposed but is not yet in
[`hvtiRutilities::hvti_taxonomy()`](https://ehrlinger.github.io/hvtiRutilities/reference/hvti_taxonomy.html).

## Examples

``` r
j <- jobs()
table(j$disposition)
#> 
#>    build   retire scaffold     thin 
#>        8        6       29       15 
```
