# Design records

How `hvtiverse` was specified and built.

| File | What it is |
|---|---|
| [2026-08-19-design.md](2026-08-19-design.md) | The design spec: what the package does, and why each choice was made over its alternatives. |
| [2026-08-19-plan.md](2026-08-19-plan.md) | The implementation plan: ten test-driven tasks, each with the code and tests to write. |

These are historical records of the v1.0.0 build, kept because the reasoning behind
the design is harder to recover than the code. They are not user documentation --
start with the README or `vignette("hvtiR")` for that.

They live here rather than under `docs/`, which belongs to pkgdown: pkgdown refuses
to build into a directory it did not create, so anything of ours in `docs/` breaks
the site build.
