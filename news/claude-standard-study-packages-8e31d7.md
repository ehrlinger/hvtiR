* `setup()` declares a standard set of analysis packages in every study,
  alongside the family: `tidyverse`, `haven`, `gtsummary`, `flextable`,
  `survival`, `survminer`, `randomForestSRC`, `varPro` and `pacman`. They are
  the packages the team Quick Start used to install by hand. renv runs in
  explicit mode, so declaring them is what puts them in the lockfile; a study
  no longer needs a separate install step for them.
