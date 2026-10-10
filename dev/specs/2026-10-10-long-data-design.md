# Long data: what a patient is, and who must know

**Written** 2026-10-10.
**Status** Design, approved. Not implemented. This is the umbrella; each workstream
gets its own design and plan.
**Repos** `hvtiRutilities` (registration, `set_shape()`), `hvtiRtemplates` (the job
data step and every template's accept list), `hvtiRbootstrap` (patient resampling),
`TemporalHazard` (multiple events). Recorded in `hvtiR`.
**Depends on** design 6,
[ancillary, subset and combined datasets](2026-10-07-ancillary-datasets-design.md):
registered `kind` and `key`, the long `JOIN`, `REDUCE`, and the
`one_row_per_patient` refusal this design generalizes.
**Order** After hvtiRtemplates 1.3.0 (tagged 2026-10-09), as decided then.

---

## 1. The problem

The group uses long data heavily, and the family treats it as an exception.

- **Design 6 can join long data, then mostly refuses it.** A long `JOIN` gives one
  row per record. Seventeen patient-level templates refuse it unless `REDUCE` brings
  it back to one row per patient, and the switch that does it,
  `one_row_per_patient`, is yes or no. Nothing says what a template *can* take.
- **Nothing records what one patient is.** `read_job_data()` knows the key, such as
  `(ccfid, d)`, but not that `ccfid` is the patient and `d` a visit time, so every
  consumer downstream has to be told again or guess.
- **Guessing has a known failure.** A bootstrap that resamples rows of long data
  treats each echo as a patient: the replicates hold the wrong number of patients,
  and the intervals are too narrow. `hvtiRbootstrap::boot_predict_ci()` already
  resamples by patient when given `id =`; `boot_select()`, `boot_bag()` and the
  `boot_validate()` path cannot.
- **The analyses are untemplated.** The taxonomy names the repeated-measures
  prefixes, and the roadmap has every one queued with almost no R exemplar:

  | prefix | what | breadth | R exemplars |
  |---|---|---|---|
  | `mm` | mixed model, continuous repeated measures | 59 | 1 |
  | `gm` | generalized model, ordinal or count | 77 | 0 |
  | `mp` | mixed-model plot | 82 | 4 |
  | `gp` | generalized-model plot | 50 | 2 |
  | `ce` | competing events | 131 | 1 |

The maintainer confirmed on 2026-10-09 that all of the following are in use and in
scope:

- **Repeated measures:** temporal decomposition, linear and logistic mixed models,
  GEE and robust standard errors, and descriptive trends.
- **Multiple events per patient:** repeated events of one type, competing events,
  multistate or sequential transitions, and time-varying covariates.
- **Patient resampling** for bootstrap variable selection, bootstrap confidence
  bands, and optimism-corrected validation.

These sit in four packages. Answered separately, each would decide for itself what
the patient column is called and how it is passed, which is how one of them ends up
resampling rows. This design settles only what they share.

## 2. Decisions

1. **One umbrella, three sub-specs.** The umbrella fixes the vocabulary, the shape
   metadata, the template accept lists and the `id` contract. Each workstream then
   gets its own design and plan. Chosen over one spec covering everything (one plan
   across four packages) and three independent specs (three answers to "which column
   is the patient").
2. **Read-time metadata plus a plain `id =` argument everywhere.** Chosen over a
   shared long-data class, which would make every package depend on the class's
   home and make users wrap plain data frames, and over template conventions alone,
   which nothing would check.

## 3. Vocabulary

Every dataset a job reads carries two facts:

- **`id`**, the column that names a patient. Registration already resolves it, with
  design 6's fallback to the MRN.
- **`shape`**, one of four values:

| shape | one row per | rows identified by | example |
|---|---|---|---|
| `patient` | patient | `id` | the built cohort |
| `record` | patient and time | `(id, time)` | serial echoes |
| `interval` | patient and time segment | `(id, start, stop)` | repeated-event segments, multistate transitions |
| `counting` | patient and covariate segment | `(id, start, stop)` | time-varying covariates |

`interval` and `counting` have the same key form and differ in meaning: an
`interval` row ends in an event or a transition, and a `counting` row ends where a
covariate changes. They are kept apart because the models that read them differ.

"Cluster" is not used for the patient anywhere in this design or its sub-specs.
`hvtiRbootstrap::boot_clusters()` already uses the word for groups of correlated
variables, and two meanings in one package is how the wrong one gets passed.

## 4. Where shape comes from

1. **At registration.** `register_data()` infers the shape from the key: `patient`
   when the key is `id` alone, and `record` when it is `id` plus one more column.
   `interval` and `counting` cannot be inferred, because their keys look alike, so
   registering one takes an explicit `shape =`, with `start =` and `stop =` naming
   the time columns. A `shape =` that contradicts the key stops, naming both.
2. **When a job derives long data.** A new hvtiRutilities helper,
   `set_shape(d, shape, id, start = NULL, stop = NULL)`, stamps the shape on a data
   frame the job built itself, such as the output of
   `TemporalHazard::hzr_repeated_events()`. It checks the claim rather than trusting
   it:
   - `patient`: `id` is unique;
   - `record`: `(id, time)` is unique;
   - `interval` and `counting`: `start < stop` on every row, and no two segments of
     one patient overlap;
   - every shape: `id` has no missing value.

   A failed check stops with counts only, never identifiers, as design 6's key checks
   do.
3. **A long join reports `record`,** and a join with `REDUCE` reports `patient`, so
   the shape follows what the read actually returns.

`read_job_data()` records `id` and `shape` in the read's record and in provenance,
beside the key and the row and patient counts.

## 5. Templates declare what they accept

`read_job_data(accept = )` names the shapes a job can analyse. A shape outside the
list stops the read with a message that names the data's shape, the shapes the
template accepts, and the fix: `REDUCE`, or the template that takes that shape.

`one_row_per_patient = TRUE` stays as an alias for `accept = "patient"`, so a 1.3.0
job keeps working unchanged.

Each template states its list once, as a study choice **without** an `EDIT:` marker:
the list belongs to the template, not to the study, and a marker would leave every
finished job rendering as a draft.

| template family | accepts |
|---|---|
| patient-level models (`hz`, `lm-*`, `rf*`, `nb-*`, the bootstrap selection templates, and the rest of design 6's refusing list), and `dc-gfup` | `patient` |
| `mm`, `gm`, `mp`, `gp` (to come) | `record` |
| `dp-trends`, `dc-general`, `dc-tables`, `dp-eda` | `patient`, `record` |
| repeated-event and multistate hazard (to come) | `interval` |
| time-varying Cox or hazard (to come) | `counting` |
| `ce` (to come) | `patient`: competing events are one row per patient with an event type |

- **Descriptive templates count both units.** On `record` data their tables say "N
  records on M patients", as the join record does today. A count of records is never
  shown as a count of patients.
- **Provenance records the accept list** beside the shape that was read, so a later
  reader sees the choice was deliberate.

## 6. The `id` contract

Every function that fits, resamples or summarizes long data takes the patient column
as a plain `id =` argument holding a column name. Templates pass it from what the read
recorded, never from a separate study choice that could disagree with it.

1. **With `id`, the unit is the patient.**
   - Resampling draws patients, as `boot_predict_ci()` does now. It draws positions,
     renumbers each drawn patient so a patient drawn twice is two units, and refuses
     a missing `id`.
   - Robust standard errors cluster on the patient.
   - Counts report patients and rows.
2. **Without `id`, more than one row per patient stops the function.** Data with one
   row per patient needs no `id`. A consumer that cannot tell, because it was handed
   a plain data frame with no recorded shape, checks `id` uniqueness if it was given
   one and otherwise treats the data as `patient`, the behaviour today.
3. **Results record `id`, the number of patients and the number of rows.**

| sub-spec | package | applies the contract to |
|---|---|---|
| 1. Repeated measures | hvtiRtemplates and the fitters it calls | `mm`, `gm`, `mp`, `gp`; mixed-model random effects and GEE clustering take the patient from `id`. Temporal decomposition is a design of its own inside this sub-spec |
| 2. Patient resampling | hvtiRbootstrap | `boot_select()`, `boot_bag()` and the `boot_validate()` path, through the same draw `boot_predict_ci()` uses |
| 3. Multiple events | TemporalHazard and hvtiRtemplates | repeated events from `hzr_repeated_events()` as `interval`; multistate as `interval` per transition; time-varying covariates as `counting`; `ce` stays `patient` |

The umbrella decides the vocabulary, `set_shape()`, `accept` and this contract.
Model choices, such as random-effect structure or variance estimator, belong to each
sub-spec.

## 7. Order

1. **Foundation.** hvtiRutilities: `shape`, `start` and `stop` at registration, and
   `set_shape()`. hvtiRtemplates: `read_job_data(accept = )` and an accept list in
   every template. hvtiRutilities releases first and hvtiRtemplates raises its floor,
   as hvtiRutilities#189 and hvtiRtemplates#278 did. Patch versions, unless the
   maintainer chooses otherwise.
2. **Patient resampling.** The smallest: the draw already exists in
   `boot_predict_ci()`.
3. **Multiple events.** Repeated events first, since `hzr_repeated_events()` has SAS
   parity already; then time-varying covariates; then multistate.
4. **Repeated measures.** The largest: four new templates, plus temporal
   decomposition as a design of its own.

## 8. Compatibility

- A dataset registered today, with or without `kind` and `key`, reads unchanged, and
  its shape is inferred. An ambiguous key reads as `record`.
- `one_row_per_patient = TRUE` keeps working as an alias for `accept = "patient"`.
- No 1.3.0 job changes its result. The only refusals are ones 1.3.0 already gives,
  now with a message naming the shapes.

## 9. Not in this design

- Model choices inside each sub-spec.
- Joining more than one ancillary dataset, or two ancillary datasets to each other.
- Aggregate `REDUCE` rules, such as a patient's mean or number of records.
- Anything on the SAS side, which is being retired.

## 10. Tests

All fixtures synthetic, no PHI.

- **Inference.** Every key form infers the shape in section 4, and an explicit
  `shape =` that contradicts the key stops.
- **`set_shape()`.** It accepts a true claim of each shape and rejects each false
  one: a duplicated `id` for `patient`, a duplicated `(id, time)` for `record`,
  `start >= stop` and overlapping segments for `interval` and `counting`, and a
  missing `id` for all. Messages carry counts, never identifiers.
- **Accept lists.** Each family's list is enforced. A template with no list fails a
  test. `one_row_per_patient = TRUE` behaves exactly as `accept = "patient"`.
- **The `id` contract.** Each consumer stops on long data given no `id`. Patient
  resampling keeps a patient's rows together, checked by counting patients and rows
  in each draw.
- **Provenance.** It records `id`, the shape and the accept list.
- **Mutation.** Each new test fails with its code reverted, per the family rule.
