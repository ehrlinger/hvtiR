* `setup()` removes pak's leftover `_cache` from a study library by its exact
  path. It used to pass the path to `unlink()` as a pattern, so a study path
  containing `[`, `*` or `?` could delete a sibling study's `_cache` and leave
  its own.
