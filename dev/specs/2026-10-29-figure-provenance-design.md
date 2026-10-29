# Figure provenance: a commit per render, printed in the footnote

Status: draft, 2026-10-29. Decisions marked **(decided)** are John's; those
marked **(open)** wait on him.

## The problem

At the 2026-10-29 CHSS AVSD data meeting, Ashley could not find the jobs Rajes
used for a published manuscript figure. The job name is printed at the bottom
of each plot, so the job can be named and the figure redrawn, but nothing shows
that the job is unchanged since the figure was made. Rajes fitted several
models; the published figure may not come from the published one.

The SAS workflow has the same gap: the footnote names the job, and the `.sas`
file, its `.lst`, `.log` and `.pdf` drift apart with no record of which version
of the job wrote which output. This design closes it for R jobs, in git.

## What exists

- **hvtiRtemplates render provenance.** A managed render's pre-render hook
  records the source `.qmd` and its sha256; `.embed_provenance()` calls
  `hvtiRutilities::capture_provenance()`, which records the job, package
  versions (with `RemoteSha` for git installs), the `renv.lock` hash, input
  data and artifact hashes, and the time, embedded in the report HTML.
- **It does not record the figures.** `.save_figure()` writes a PNG, PDF and
  TIFF and nothing links them to the render.
- **hvtiRutilities checkpoints.** `study_checkpoint()` commits an allow-listed
  snapshot of the study's code to a private repository, `.checkpoint/repo/`,
  under a lock, and tags it. The study folder itself is not a git repository,
  so this is the only commit a study has.
- **hvtiPlotR footnote.** `make_footnote()` draws text on the current device.
  Nothing calls it for the analyst; `save_manuscript()` never draws one.

## Where the study's git is going

The study folder is not a git repository **yet** (John, 2026-10-29). The
checkpoint's `.checkpoint/repo/` already pushes to Azure DevOps
(`CORR_STUDIES`), and that setup is meant to become the study's own
repository, but the pipeline from study folder to ADO still needs design and
completion. Render commits are one consumer of that pipeline, so:

- **Build against one seam.** `study_render_commit()` asks hvtiRutilities for
  "the study's repository"; today that is `.checkpoint/repo/`, later the study
  folder. Callers (the hook, the footnote) never name the path.
- **Ship on the checkpoint repository now.** **(decided 2026-10-29)** Figures
  become traceable immediately; when the study folder becomes the repository,
  the seam moves and the `renders` branch migrates with it.

Decisions 2 to 4 below (the `renders` branch, the failure policy and the
footnote on publication figures) are taken as recommended, since John chose
to build without objecting to them. Revisit before the hvtiRtemplates step
if any is wrong.

## Design

### 1. A commit per render (hvtiRutilities) **(decided: commit per render)**

A new export, `study_render_commit(source, cfg = study_config())`, run by the
pre-render hook before the job executes:

- Takes the checkpoint lock, commits the same allow-listed snapshot a
  checkpoint commits, and returns the commit ID.
- **The job must be in the commit it returns.** The allow-list drops
  symlinks, anything under the data and estimate folders and files over
  50 MB, so a commit can succeed without the job in it. The job's path must
  be in the committed tree with a blob hash matching the file on disk;
  otherwise no ID is returned and the failure policy (section 2) applies, so
  no figure prints an ID from which `git show <commit>:<job>` cannot recover
  the job.
- **Commits go to a branch of their own, `renders`, not `main`.** Closure state
  reads `main`'s first-parent history and delivery replays `main`; render
  commits there would interleave with milestones and renumber nothing useful.
  **(open)**
- **An unchanged tree reuses the last commit** rather than adding an empty one,
  so re-rendering an unchanged job adds no history.
- **No tag, no push.** A render is not a milestone. `study_checkpoint_push()`
  pushes `renders` along with `main`. **(open)**
- **A render commit is never rewritten.** Its ID is printed in figures, so
  synchronisation must keep it reachable under the same ID. Checkpoint
  delivery's replay (`.cp_replay()`) rewrites commits and must never touch
  render commits. Two copies of a study that render independently diverge, so
  each copy pushes its renders to a ref of its own,
  `refs/renders/<workspace_id>`, which never needs a force push or a rewrite.
  The same constraint argues against putting render commits on `main`, which
  delivery replays. **(open: per-workspace refs versus merging histories)**
- Runs on the server's local filesystem, as checkpoints do, never over SMB.

### 2. Failure policy **(open)**

When the commit cannot be made (no git, lock held past its wait, unverified
identity), the choice is:

- **(a) stop the render.** No figure without a commit; strictest, and a stale
  lock blocks work.
- **(b) render, and print `uncommitted` in the footnote** with a warning in the
  report. Work continues; the figure says plainly it cannot be traced.

Recommendation: (b). A figure that says "uncommitted" is honest and visible;
a blocked render is worked around by rendering outside the managed project,
which loses provenance silently.

### 3. The footnote (hvtiPlotR)

`save_manuscript()` gains `footnote = NULL`. Given a string, it draws it with
`make_footnote()` on the device before closing it, in every format it writes,
including `draft_file`. The line reads:

```
<job path> · <commit, 7 chars> · R 4.5.1 · hvtiPlotR 2.8.19 · hvtiRtemplates 1.5.3 · 2026-10-29 14:40
```

- Only R, hvtiPlotR and hvtiRtemplates versions, so it stays one line at 6 in
  wide. The full package list is in the render provenance.
- hvtiPlotR builds the string from parts it is given; it does not know about
  studies or git, so it gains no dependency on hvtiRutilities.
- **The footnote is on publication figures too.** That reverses the current
  `make_footnote()` guidance ("omit for publication"). Journals crop it in
  typesetting; the study-folder copy keeps it. **(open)**

### 4. Figures in the render provenance (hvtiRtemplates)

- The pre-render hook calls `study_render_commit()` and stores the commit in
  the render state beside `render_id`.
- `.save_figure()` passes the footnote to `save_manuscript()` (or draws it for
  a base-graphics function) and records each file written, path and sha256,
  in a `figures` field of the payload.
- **`figures` is its own field, not `artifacts`.** Artifacts are inputs that
  `.combine_handoff_lineage()` reads back; listing outputs there would make a
  figure an input of the next job.

### 5. Tracing a figure

Given a figure in the study folder: read the commit from its footnote, then
`git -C .checkpoint/repo show <commit>:<job path>` gives the job as it ran.
Given only the file: its sha256 finds the render in the report provenance,
which names the commit. A later checkpoint verification (separate work) can
flag figures whose commit is not the job's latest.

## Release order

hvtiRutilities (the commit) → hvtiPlotR (the footnote argument) →
hvtiRtemplates (the hook and `.save_figure()`), floors raised only in
hvtiRtemplates' own bump, as `AGENTS.md` describes.

## Out of scope

- SAS outputs. A checkpoint can hash existing `.lst`, `.log` and `.pdf` files;
  that is the checkpoint-verification follow-up.
- Embedding metadata in figure files.
