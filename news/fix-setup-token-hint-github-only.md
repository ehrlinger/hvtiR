* `setup()` no longer says "A GitHub token is needed" when renv's restore
  fails only on packages locked from a repository. renv prints its
  authentication note even when a retried GitHub download then succeeds, so
  the hint now needs a GitHub-locked package in renv's failed list (or a list
  too long to read in full), and names that package.
