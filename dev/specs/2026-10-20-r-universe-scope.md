# Serving the HVTI family from R-universe: scope

Date: 2026-10-20. Status: scoping, nothing built. Companion to `2026-10-20-study-environment-setup-design.md`.

## The problem, and what would fix it

`hvtiR::setup()` and `install()` resolve each member as `owner/repo`. renv and pak turn that into GitHub API calls, which allow 60 anonymous requests an hour per IP. Every user on the analysis server shares one IP, so installs and restores fail unless the user has a personal token. The interim fix, installing with pak's bundled token, works but leans on a token nobody owns.

The lasting fix is a CRAN-style repository for the family: a `PACKAGES` index plus tarballs, fetched over plain HTTPS from a host with no per-IP quota. [R-universe](https://docs.r-universe.dev/) builds exactly that from Git repositories, free, for a GitHub account. This document scopes whether it fits, and where it does not.

## Short answer

R-universe is a good fit for **install and update**, and a poor fit for **reproducible restore on its own**. Three facts from the documentation drive that:

1. A universe holds **one version of each package**. It does not archive old ones ([set-up guide](https://docs.r-universe.dev/publish/set-up.html), [reproducibility](https://docs.r-universe.dev/install/reproducibility.html)).
2. Linux binaries are built for **Ubuntu only**, so the RHEL 8 server installs from source. That is fine here (below).
3. The tracked branch is the default branch (or one named ref), so "released" means "merged to main", not "tagged".

A lockfile pinned to an older family version restores through renv's git fallback, and that fallback uses the `git` command line, not the GitHub API (verified in renv source, section 4). That is what makes the design workable.

## 1. Setup steps and who does them

All of these are the repository owner's (John's) to do. None needs a server administrator.

1. **Create a public repository named `ehrlinger.r-universe.dev`** on the `ehrlinger` account. The name must be lowercase `<user>.r-universe.dev` ([set-up guide](https://docs.r-universe.dev/publish/set-up.html)).
2. **Install the R-universe GitHub app** on the `ehrlinger` account. It asks only for read and write access to commit statuses, used to post build checkmarks. The guide recommends "All repositories" so later additions need no further step ([set-up guide](https://docs.r-universe.dev/publish/set-up.html)).
3. **Commit `packages.json`** to that repository: a JSON array, one object per package. Required: `package` (must match the DESCRIPTION name) and `url` (a public Git URL, since the build servers run `git clone`). Optional: `subdir`, `branch`, `metadata`.
4. **Wait for the first build.** Packages appear once they finish on all platforms, usually inside an hour.

A first-cut `packages.json` for the family, from `members()`:

```json
[
  {"package": "hvtiRutilities",  "url": "https://github.com/ehrlinger/hvtiRutilities"},
  {"package": "hvtiRdatabuild",  "url": "https://github.com/ehrlinger/hvtiRdatabuild"},
  {"package": "hvtiRtables",     "url": "https://github.com/ehrlinger/hvtiRtables"},
  {"package": "hvtiRtemplates",  "url": "https://github.com/ehrlinger/hvtiRtemplates"},
  {"package": "hvtiPlotR",       "url": "https://github.com/ehrlinger/hvtiPlotR"},
  {"package": "hvtiRlifetables", "url": "https://github.com/ehrlinger/hvtiRlifetables"},
  {"package": "hvtiRbootstrap",  "url": "https://github.com/ehrlinger/hvtiRbootstrap"},
  {"package": "hvtiRpropensity", "url": "https://github.com/ehrlinger/hvtiRpropensity"},
  {"package": "hvtiRimputation", "url": "https://github.com/ehrlinger/hvtiRimputation"},
  {"package": "ggBoostedTrees",  "url": "https://github.com/ehrlinger/ggBoostedTrees"},
  {"package": "TemporalHazard",  "url": "https://github.com/ehrlinger/temporal_hazard"},
  {"package": "ggRandomForests", "url": "https://github.com/ehrlinger/ggRandomForests"},
  {"package": "hvtiR",           "url": "https://github.com/ehrlinger/hvtiR"}
]
```

Notes:

- `TemporalHazard`'s `url` points at `temporal_hazard`; the `package` field carries the installed name. That is the same package/repo split `members()` already stores.
- `hvtiR` itself belongs in the universe. It is absent from `members()` on purpose (an installer that resolves itself is circular), but the bootstrap command `pak::pak("ehrlinger/hvtiR")` is also an API call, so it needs a repository form too.
- **Subdirectory packages**: `subdir` is "the path to the R package root when the package is not at the repository root" ([set-up guide](https://docs.r-universe.dev/publish/set-up.html)). Example: `{"package": "stringdist", "url": ".../stringdist", "subdir": "pkg"}`.
- **Pointing at a branch or tag**: `branch` "can take the name of any Git reference (either a branch or a tag)", and `"*release"` tracks the latest GitHub release. The guide advises omitting `branch` to follow the default branch, so a rename does not break the entry ([set-up guide](https://docs.r-universe.dev/publish/set-up.html)). The guide does not say whether `subdir` and a tag work together; that is a pilot item.

## 2. A forked `boostmtree` that takes precedence over CRAN

`ggBoostedTrees` pins `boostmtree=ehrlinger/boostmtree_src/boostmtree@v2.0.7-ccf` in `Remotes:`: a fork (`ehrlinger/boostmtree_src`, default branch `master`, public), package in the `boostmtree/` subdirectory, at a tag. The universe entry would be:

```json
{"package": "boostmtree", "url": "https://github.com/ehrlinger/boostmtree_src",
 "subdir": "boostmtree", "branch": "v2.0.7-ccf"}
```

Whether that can be served and win over CRAN is the least certain part of this scope.

- **Allowed, but discouraged.** The [publishing rules](https://docs.r-universe.dev/publish/terms.html) say hosting "a fork or completely different package with the same name" is "strongly discouraged", because users may install the CRAN copy by accident and R can overwrite one with the other. R-universe "treats the CRAN version as the official package" and puts a warning on the duplicate's page. I found no statement that the build refuses it. Pilot it.
- **Precedence is R's, not R-universe's.** `install.packages()` and renv, with the default `duplicates` filter, report "the latest version where more than one version is available, and ... the first-named repository ... with the latest version" ([`?available.packages`](https://stat.ethz.ch/R-manual/R-devel/library/utils/html/available.packages.html), checked against the installed R help). So the **highest version number wins; the repository order only breaks a tie.** Repository order alone does not make the fork win.
- **Consequence for version numbers.** The fork must carry a version strictly greater than CRAN's `boostmtree`, now and after every CRAN release. The tag name `v2.0.7-ccf` suggests the fork is ahead today; check the fork's `DESCRIPTION` `Version:` against CRAN before relying on it. If CRAN ships a higher number, installs and `update()` silently switch to CRAN's. The fix is to bump the fork's version past CRAN's, as a manual step each time. A `-ccf` tag does not help: only the DESCRIPTION version is compared.
- **A tidier alternative to consider.** R's `?available.packages` also documents a `"CRAN"` filter that prefers CRAN over other repositories. We want the opposite, so there is no built-in "universe wins" setting. If the version-race risk is unacceptable, rename the fork (for example `boostmtreeCCF`) and change `ggBoostedTrees` to import that name. That removes the collision and the R-universe warning. It is a code change in `ggBoostedTrees` and a decision for John, not for this document.
- **Remotes field.** With the fork in the universe, the `Remotes:` line in `ggBoostedTrees` (and hvtiR's `subdir_remotes()` pre-install step in `setup.R`) becomes unnecessary for repository installs, because `Imports: boostmtree (>= 2.0.1)` is satisfied from the repository. Do not remove the Remotes line until the universe is the proven path; `Remotes:` is the only thing that works when the universe is not on `repos`.
- Does the fork have compiled code? The locally installed `boostmtree` (2.0.3) reports `NeedsCompilation: no`; check the fork. Compiled code would matter for section 3.

## 3. Binaries, platforms and R versions

From the [binaries page](https://docs.r-universe.dev/install/binaries.html):

- **Linux**: binaries are built and checked for **one distribution, `ubuntu:latest`** (Ubuntu 26.04, "resolute", at the time of the page), x86_64 and arm64. Served at `https://<owner>.r-universe.dev/bin/linux/<distro>-<arch>/<R version>/`. The page is silent about RHEL, Rocky and Alma, and says only that `install.packages()` uses a binary when one exists and installs from source otherwise.
- **macOS**: x86_64 and arm64 builds only for packages with compiled code; others share one binary. **Windows**: the page does not mention it. I did not verify macOS or Windows coverage beyond this.
- **R versions**: R-devel and R-release. The page does not mention older versions. With the server on R 4.5 or 4.6, binary availability depends on which is "release" on the day. Expect source installs on the server regardless.

**So RHEL 8.10 builds from source.** For this family that costs little: every installed member reports `NeedsCompilation: no` locally (checked 2026-10-20 on the Mac: all twelve members, plus `boostmtree`). A source install of a pure-R package is an unpack and a byte-compile, seconds each. The cost shows up only if a member gains compiled code. The internal PPM serves RHEL binaries for CRAN packages; the universe adds none, and it does not need to.

The Ubuntu-only binary path also changes when "latest" moves. It matters only if someone points a Linux machine at the `/bin/linux/` path by hand; `contrib.url`-style source resolution through the repository root does not use it.

## 4. Version retention and `renv::restore()`

This is the section that decides the design.

**What R-universe keeps.** One version per package. "R-universe does not keep old package versions"; instead it records the upstream Git URL and commit in the built DESCRIPTION ([reproducibility](https://docs.r-universe.dev/install/reproducibility.html), [rOpenSci note](https://ropensci.org/blog/2022/01/06/runiverse-renv/)). The fields written are `Repository` (the universe), `RemoteUrl` (the Git repository), `RemoteRef` (branch, `HEAD` in the example) and `RemoteSha` (the commit). The docs' own answer for pinned versions is a snapshot you download and host yourself: `https://<universe>.r-universe.dev/api/snapshot`, a static CRAN-like layout of binaries, sources and indexes. No retention period is documented for any of it.

**What renv does with an older lockfile.** The rOpenSci note says renv checks the repository first and, if that version is gone, clones `RemoteUrl` at `RemoteSha`. I read the installed renv (1.2.4) source to settle how:

- `renv_retrieve_repos()` tries binary and source methods against the repositories, then, for source installs, **appends `renv_retrieve_git` when the record has both `RemoteUrl` and `RemoteSha`**, and otherwise falls back to the CRAN archive.
- `renv_retrieve_git_impl()` runs `git init`, `git remote add origin <RemoteUrl>`, `git fetch --depth=1 origin <RemoteSha>`, `git reset --hard FETCH_HEAD` as a shell command.

**Therefore the fallback does not use the GitHub API.** It is a plain `git fetch` over HTTPS to `github.com`, which has no 60-per-hour anonymous limit of the REST API kind. It needs `git` on the server's PATH and outbound HTTPS to `github.com`. Public repositories need no credentials. GitHub allows fetching an arbitrary reachable SHA, which this relies on. The renv [NEWS](https://github.com/rstudio/renv/blob/main/NEWS.md) lists r-universe restore fixes in 0.17.1, 1.0.0, 1.0.8 and 1.1.0, and 1.3.0 makes dependency resolution use the lockfile's recorded commit; the server's renv version should be at least 1.1.0. Study lockfiles written before the move to the universe record `Source: GitHub` and keep restoring through the GitHub path as they do today; those are the studies still exposed to the API limit until re-snapshotted.

**What this means for studies.**

| Case | Outcome |
|---|---|
| Lockfile names the current universe version | Restores from the universe, a tarball download. |
| Lockfile names an older version | Version not in the universe; renv falls back to `git fetch` of `RemoteSha`. Works if the commit is reachable on GitHub. No API call. |
| Commit force-pushed away or repo deleted | Restore fails. Same as any GitHub-sourced package today. |
| `subdir` package (boostmtree fork) at fallback | **Unverified.** The clone is the repository root. Whether renv installs from the `RemoteSubdir` path in that case needs a test before any lockfile depends on it. |
| Version number unchanged but source changed | The lockfile records `Version`, not the SHA; check that renv compares `RemoteSha` and does not treat a same-version rebuild as identical. Test. |

**Recommendation on retention.** Treat the universe as a delivery channel, not an archive. The archive is the tagged history in the Git repositories (`vX.Y.Z` tags already exist). If a study needs an exact frozen set, take an [API snapshot](https://docs.r-universe.dev/install/reproducibility.html) at the family release and keep it on `/studies`. That is a small zip, produced in seconds, and removes dependence on the fallback.

## 5. Which branch is built

By default R-universe builds the **default branch** of each repository ([set-up guide](https://docs.r-universe.dev/publish/set-up.html)), and builds are triggered by commits, with a rebuild at least every 30 days. A forum report says tags are ignored unless `"branch": "*release"` is set, which is the documented value for "latest GitHub release"; I did not confirm that thread's current accuracy.

How that fits the family's rule that releases land on `main` and are tagged `vX.Y.Z`:

- **Default branch (no `branch` field)** tracks every merge to `main`. This matches what `install()` does today (it installs from `main`; `remote_version()` already reads `main`'s DESCRIPTION). It also means a patch merge is live within the build lag, ahead of the tag. This is the least friction and the closest to the current behavior, and the version a study records is whatever `main` carried.
- **`"branch": "*release"`** serves only tagged GitHub releases. It matches "released means tagged" but needs every package to publish a GitHub *release*, not just a tag, and it hides unreleased `main`. For tier-4 coordination (hvtiRtemplates imports hvtiRutilities and expects the floor to be available) it would also make the release order visible in the universe.
- Recommendation: **start on the default branch**. Revisit `*release` only if untagged `main` reaching studies becomes a problem. The family's patch-bump discipline already means `main` always carries a straight three-digit version, so the numbers sort correctly.

## 6. What changes in hvtiR

Code changes, all in `ehrlinger/hvtiR`, none yet written:

- **A repository constant** (for example `HVTIR_REPO <- "https://ehrlinger.r-universe.dev"`), set as an extra entry in `repos` for the child process that `setup()` runs and for `install()`/`update()`, ahead of or behind PPM per the order below.
- **`install_specs()` / `build_specs()`** (which map names to `owner/repo`) become package names for repository installs, and keep the `owner/repo` form as the fallback when the repository is unreachable. The `member_deps()` closure in `install_members()` was written because pak sent an in-family dependency to CRAN; with the universe on `repos`, the solver finds it there, so the closure's reason weakens but should stay as a belt.
- **`registry`**: `members()` keeps its `repo` column (the Git remote still matters for the fallback and for `remote_version()`); no new column is needed unless a member's universe name could ever differ from its package name, which `packages.json` already encodes.
- **`remote_version()`** reads `raw.githubusercontent.com`, not the REST API, so it is not subject to the 60-per-hour limit and can stay. Optionally compare against the universe's index.
- **The installer**: since ehrlinger/hvtiR#141, `setup()` installs the family with pak into the study library, passing the study's lockfile repositories, and renv owns the environment. Adding the universe to those repositories is enough for pak to install members by name from it; renv's pak back end stays off for the `LinkingTo` fill.
- **Lockfile `Source`**: packages restored from the universe snapshot as `Source: Repository`, with `Repository: ehrlinger` (the universe's name) and the `Remote*` fields. That Source value requires the universe URL to be in `repos` at restore time, or renv reports the repository unknown. So **the repository must be recorded in `renv.lock`'s `R: Repositories` block**, which `renv::snapshot()` does from `getOption("repos")`. `setup()` should set `repos` before it snapshots so every lockfile names the universe.
- **Repository order with the internal PPM** (`lri-ppm00.lerner.ccf.org`): put the universe and PPM both in `repos`. For a package that exists only in the universe (11 of 12 members), order is irrelevant. For `boostmtree`, version number decides first and order only ties (section 2). Do not use a PPM date snapshot URL for the universe; it has none. `latest_repos()` in `install.R` rewrites dated PPM snapshots to `latest` when a floor is unmet, and does not touch the universe URL, which is correct.
- **Converting an existing study is a separate, explicit step.** Re-snapshotting is not enough: renv records what is installed, and a package installed from GitHub keeps `Source: GitHub` and its `RemoteSha` in the lockfile whatever `repos` says (confirmed with renv 1.2.4 in review of this scope; see the [snapshot reference](https://rstudio.github.io/renv/reference/snapshot.html)). Its restores keep using the GitHub API. Conversion must keep each pinned version and commit, so it is done per package and only where the universe serves the identical build:
  1. For each lockfile record with `Source: GitHub` whose package is in the universe, read the universe's index (`available.packages(repos = HVTIR_REPO)`, which carries `Version` and, for R-universe, `RemoteSha`).
  2. **Same `Version` and same `RemoteSha`**: reinstall that package from the universe by name into the study library (pak or `renv::install("pkg", repos = ...)`, dependencies off), so its installed `DESCRIPTION` now says `Repository: ehrlinger`. The code is byte-for-byte the locked commit.
  3. **Different `Version` or `RemoteSha`** (the universe keeps only the current build): leave the record as `Source: GitHub`. Converting it would change the study's code; that is `hvtiR::update()`'s decision, made by the study owner, after which the new version arrives from the universe anyway.
  4. Snapshot once, with the universe in `repos`, so the lockfile's `R: Repositories` block names it; report which packages converted and which stayed on GitHub.
  This belongs in `setup()` (run on an adopted study) or a small `hvtiR::convert_sources()`; it is part of the hvtiR change in step 7 below, not a manual re-snapshot.
- **Failure messages**: `explain_install_failure()` suggests a `repos` line; extend it to name the universe when a member is missing from every configured repository.
- **Tests** can stub the repository the way `pak_install` is already a seam; no network in tests.

## 7. Build failures, latency, monitoring, exposure

- **Latency.** First build: within about an hour ([set-up guide](https://docs.r-universe.dev/publish/set-up.html)). Later commits: the docs give no figure; the system rebuilds on a commit and at least every 30 days. Measure it in the pilot rather than quote a number. A family release day will include a wait between merge and availability; the existing release order (utilities first, templates last) therefore also needs "wait for the universe" between tiers, or `setup()` will see a floor unmet.
- **Failure behavior.** Whether the previous good version stays served after a failed build is **not documented in anything I could fetch**; the troubleshooting page URL I tried returned 404. A package page can show "The latest version of this package failed to build", and the per-package API (`/api/packages/<name>`) lists builds by platform with status and a link to the Actions run ([example record](https://mrc-ide.r-universe.dev/api/packages/buildr)). Test it by pushing a deliberately broken commit to a scratch package in a scratch universe.
- **Monitoring.** Poll `https://ehrlinger.r-universe.dev/api/packages` from the existing weekly sweep, compare each package's served `Version` with `main`'s DESCRIPTION, and report any gap. This reuses `remote_version()`. The GitHub app also posts a commit status on each package commit, which shows in the PR/commit UI.
- **One universe per account.** The docs say each GitHub user has a single universe ([set-up guide](https://docs.r-universe.dev/publish/set-up.html)), so personal packages outside the family would sit in the same index. If that is unwanted, the guide's suggestion is a second GitHub organization.
- **Exposure.** All twelve repositories are already public, and R-universe builds only public Git URLs. What is new: a build log, a rendered manual and a `/api` JSON per package, all public. The things to check before listing a package: no PHI or study identifiers in tests, vignettes or example data (the house rule already requires none), and no token or internal hostname in DESCRIPTION. `hvtiRtemplates` ships a gallery and vignettes; read their rendered output once. R-universe will also run `R CMD check` on each package and publish the result, including warnings.
- **Dependence on an outside service.** If R-universe is down or changes terms, studies can still install from GitHub. Keep the `owner/repo` path working as a documented fallback.

## 8. Alternatives, briefly

| Option | Needs | For | Against |
|---|---|---|---|
| **R-universe** (this document) | John only | Free, no server work, plain HTTPS, `RemoteSha` supports restore, snapshots available | One version kept; Ubuntu-only binaries; same-name fork with CRAN is discouraged; outside service; build lag |
| **Internal Posit Package Manager, Git-source builds** | PPM administrator | Same host as CRAN, RHEL binaries, versions retained, one repo entry, no outside dependency | Needs admin to configure; Git builds need PPM to reach GitHub (and a token for its own API use, if private); depends on an admin's time and PPM licence features, which I did not verify |
| **drat on GitHub Pages** | John only | Simple, static, versions can accumulate as tarballs | We build and push tarballs ourselves each release (CI job to write); no binaries; no automatic build from `main`; each release is a commit to a pages branch |
| **CRAN-like repo on `/studies`** | Server access; a build script | No outside dependency, versions retained by us, works offline | Not reachable off the server (Mac and laptop installs); someone must run `tools::write_PACKAGES()` on each release; the share is a mount that changes name across remounts, and corpus scans must not walk it |

I did not verify PPM's Git-source feature against its documentation for this server's edition; confirm with whoever administers `lri-ppm00` before choosing it.

## Recommendation

Stand up an `ehrlinger.r-universe.dev` universe for the thirteen packages (twelve members plus `hvtiR`), serving the default branch, and add it to `repos` in `hvtiR::setup()`, `install()` and `update()` with the `owner/repo` path kept as the fallback. Treat it as a delivery channel only: keep the Git tags as the archive and take a universe snapshot at each family release for studies that need an exact freeze, and ask the PPM administrator whether Git-source builds are available as the longer-term home.

Do not put the `boostmtree` fork in until a pilot shows it builds, wins on version, and survives a CRAN release. Until then `ggBoostedTrees` keeps its `Remotes:` line, or the fork is renamed.

## Step list and owners

| # | Step | Owner |
|---|---|---|
| 1 | Pilot: create a scratch universe with two members and the `boostmtree` fork (`subdir` + tag). Check: builds; fork is served; behavior when CRAN's `boostmtree` has the same or higher version; previous version after a deliberately broken push; latency of a push appearing | John |
| 2 | On a server session: install a member from the universe with `repos` set; confirm source install works on RHEL 8.10 with no compiler; confirm `git fetch` of a SHA from `github.com` works from the server (outbound HTTPS, `git` on PATH) | John, with a server user |
| 3 | Test an older-lockfile restore: lock a study at universe version N, publish N+1, restore the old lockfile; include the `subdir` and same-version-new-SHA cases (section 4 table) | John |
| 4 | Decide the `boostmtree` question: serve the fork (needs a version ahead of CRAN, kept ahead) or rename it | John |
| 5 | Read each repository's rendered docs, vignettes and `R CMD check` output for anything that should not be public | John |
| 6 | Create the `ehrlinger.r-universe.dev` repository, install the GitHub app, commit `packages.json` | John |
| 7 | hvtiR change: repository constant, `repos` set before snapshot, specs by name with fallback, tests with the seam stubbed; PR against `ehrlinger/hvtiR` | Claude, John merges |
| 8 | Add a universe-versus-`main` check to the weekly sweep; add "wait for the universe" between tiers to the release-ordering note | John (Claude drafts) |
| 9 | Ask the PPM administrator whether Git-source builds are on offer for this server, and record the answer | John |
| 10 | Convert existing studies as each is next touched (do not mass-migrate): run the source conversion in section 6, which moves only records whose version and commit the universe serves identically, then snapshots; a plain re-snapshot does not convert GitHub sources | Study owners, using the hvtiR step from 7 |

## Open items I could not settle from documentation

- Whether the previous good version stays served after a failed build.
- Whether R-universe accepts a fork with a CRAN name without complaint beyond the warning.
- Whether `subdir` combines with a tag in `branch`, and whether renv's git fallback honors a subdirectory.
- Build latency after a push.
- Current macOS and Windows binary coverage, and the R versions built beyond "release" and "devel".
