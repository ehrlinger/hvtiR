# GitHub issue templates — design

**Date:** 2026-09-02
**Status:** approved 2026-09-02, implemented the same day in `hvtiR` and
across the eleven member repositories.
**Effect on prior records:** none.

## What this is for

`hvtiR` is the package everyone installs first, so it is the package whose
issue tracker strangers reach first. Two consequences shape the templates.

The reports that arrive are mostly **installation failures**, not wrong
answers. A wrong answer from `status()` is a bug in eleven lines of version
comparison; a failed `install()` is `pak` resolving eleven repositories against
a network, a library and whatever the user already has loaded. The second is
far more likely and far less self-describing, and it cannot be diagnosed at all
without `doctor()` and `sessionInfo()`. A template that merely invites those
gets them perhaps half the time; a required field gets them always.

Reports also arrive **at the wrong repository**. A user who hits a bug in
`hvtiRlifetables` knows they installed `hvtiR`, so this is where they come. The
chooser is the only place to redirect them before they have typed anything.

## The precedent being departed from

`hvtiPlotR` is the one family repository with issue templates, and both of its
files are GitHub's stock defaults, unedited. They ask an R plotting package's
users for their smartphone model, mobile OS and browser version. They are
precedent for having templates, not for their content, and nothing here is
copied from them.

## Format: YAML issue forms

Forms (`.yml`) rather than classic markdown (`.md`).

The whole value of these templates is the diagnostic block. A markdown template
is a prefilled body the reporter edits, and the section asking for
`sessionInfo()` is the one people delete when they do not have it to hand.
A form field marked `required: true` cannot be submitted empty. Forms also
apply labels on creation, which markdown templates do too, but forms give the
structured `render: text` textarea that keeps console output out of markdown's
hands.

The cost is that the reporter cannot restructure their report, which for a
diagnostic intake is the point rather than a loss.

## The files

`.github/ISSUE_TEMPLATE/`, four files.

### `01-installation.yml` — installation or update failure

Opens by telling the reporter to run `hvtiR::doctor()` before filing, since it
frequently answers the question without an issue.

| field | type | required |
|---|---|---|
| Which call failed | dropdown | yes |
| Full console output including the error | textarea, `render: text` | yes |
| `hvtiR::doctor()` output | textarea, `render: text` | yes |
| `sessionInfo()` | textarea, `render: text` | yes |
| Is `pak` installed? | dropdown: yes / no / not sure | yes |
| Possible proxy or firewall blocking github.com | checkbox | no |

Label: `installation`.

The dropdown enumerates `install()`, `update()`, their `force = TRUE` forms and
a first-time `pak::pak("ehrlinger/hvtiR")`, because the `force` cases are a
distinct failure mode: `update()` refuses to overwrite a member whose namespace
is loaded, and a user who has not read that reports "update did nothing".

The `pak` question is asked because `pak` is deliberately not a hard
dependency. `pak_install()` checks for it and aborts with an install hint, and
that abort reads to a new user like a defect in `hvtiR`.

The firewall checkbox is asked because members resolve from GitHub by design.
An environment that cannot reach github.com produces a failure that looks like
a resolution bug and is not one.

### `02-bug.yml` — bug in `status()`, `doctor()` or `members()`

Which function (dropdown, required), what was run and what came back, what was
expected, and `sessionInfo()`. Label: `bug`.

Separate from installation because the useful evidence differs. A wrong row in
the `status()` table needs the table; a `pak` transcript is noise. Merging the
two would mean either asking every reporter for everything, or asking for
nothing in particular.

One case this template is expected to catch: `update.packages()` can silently
replace `ggRandomForests` with its CRAN version, because that member exists on
CRAN as well as GitHub. Nothing prevents it and `status()` is how a user
notices, so the report arrives here looking like a `status()` defect.

### `03-member-change.yml` — add, rename or remove a family member

Action (dropdown, required), then **package name and GitHub repository as two
separate required inputs**, in-family dependencies the package imports, and a
checkbox confirming the member's own `DESCRIPTION` carries a `Remotes:` line
for any family package it imports.

The two-field split is the substance of this template. `R/members.R` stores the
mapping rather than deriving it, because the two diverged until the 2026-08
renames — `hvtiRpropensity` lived in `ehrlinger/hvtiPropensityScores`,
`TemporalHazard` in `ehrlinger/temporal_hazard`. A single "package name" field
invites the reporter to assume the repository matches, which is the assumption
the registry exists to refuse.

The `Remotes:` checkbox is there because adding a member is three things and
not one: the registry row, the dependency edges the installer expands, and that
line in the member's own `DESCRIPTION`. Its absence in `hvtiRlifetables` is
what makes the one-call `pak` rule load-bearing.

Label: `registry`.

### `config.yml`

`blank_issues_enabled: true`, plus one contact link per member repository.

Blank issues stay enabled deliberately. There is no feature-request template
here — enhancement requests for a five-export installer are rare, and the
template belongs in the member repositories where the volume is — so the blank
issue is the path for those and for anything unanticipated. Disabling it would
force every unclassifiable report through a template that does not fit.

The eleven contact links duplicate the registry in `R/members.R` and will drift
when a repository is renamed. That is accepted rather than solved: generating
`config.yml` from `members()` would add a script and a step to keep the two in
step, and `test-registry-live.R` already fails first when a member is renamed,
which is when the links would be fixed.

## Labels

The templates apply `installation`, `bug` and `registry`. GitHub silently drops
a label a template names that the repository does not have, so all three must
exist before the templates are merged. This is a `gh label create` step and not
something the YAML can assert.

## Verification

The template chooser reads only the default branch. It cannot be rendered from
a pull request branch, so a green pull request does not demonstrate that the
templates work.

What can be checked before merge: that each file parses as YAML, and that it
conforms to GitHub's issue-form schema — every element has a `type`, every
non-markdown element an `id`, every dropdown a non-empty `options`, and every
`config.yml` contact link all three of `name`, `url` and `about`.

What must be checked after merge: load the repository's New Issue page and
confirm all three templates and the eleven links appear.

`.github` is in `.Rbuildignore`, so none of this reaches `R CMD check`,
`lintr::lint_package()` or the manual build.

## Family rollout, and where this design was wrong about it

Done 2026-09-02, one pull request per member repository.

**The claim that `02-bug.yml` is repository-agnostic was false.** It names
`hvtiR::status()`, `hvtiR::doctor()` and `hvtiR::members()` in a required
dropdown, and its closing field describes the `ggRandomForests` CRAN
downgrade. None of that travels. The members got a rewritten bug form rather
than a copy, and the rollout is the thing that exposed the error — writing
the substitution made it obvious the file had nothing generic in it.

Each member repository carries three files:

| file | intake |
|---|---|
| `01-bug.yml` | The package returning a wrong answer or erroring. |
| `02-feature.yml` | Enhancements, asking for the problem before the solution. |
| `config.yml` | Blank issues enabled, plus links routing installs to `hvtiR`. |

`01-installation.yml` and `03-member-change.yml` remain specific to `hvtiR` and
did not travel, as designed.

Two things the members' bug form has that this design did not anticipate:

- **It asks how the package was installed** — `hvtiR`, GitHub directly, CRAN,
  or not sure. Family versions land on GitHub first, so a CRAN install can be
  behind the version a bug was fixed in, and a plain `update.packages()` can
  move a package back to its CRAN version. That answer is often the diagnosis
  rather than context for it.
- **It routes installation failures to `hvtiR` before the reporter types
  anything**, which is the mirror of the contact links described above.

Two decisions taken during the rollout rather than here:

- **`hvtiPlotR`'s existing templates were deleted.** It was the only member
  carrying any, both GitHub stock defaults asking an R package's users for
  their smartphone model and browser version. Left in place they would have
  sat in the chooser beside the new forms.
- **No member got a `NEWS.md` entry or a version bump.** No member repository
  has a version-check workflow, and `.github` content is contributor
  infrastructure rather than package behaviour. `hvtiR` took a NEWS entry
  because the templates matter to its front-door role; the members did not.

## Rejected alternatives

**Classic markdown templates.** Matches the single existing family precedent
and is simpler to author, but enforces nothing. The diagnostics are the reason
these templates exist.

**No routing in the chooser.** Misrouted issues would be moved with GitHub's
"Transfer issue" button, which is cheap for the maintainer but leaves the
reporter having filed in the wrong place. Redirecting before they type costs
them less.

**`config.yml` generated from `members()`.** Cannot drift, but adds a script,
a generation step and a way for the checked-in file to be stale against its own
generator. Rejected on the reasoning above.
