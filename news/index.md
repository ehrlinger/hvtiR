# Changelog

## hvtiverse 1.0.0

- First release.
- [`hvtiverse_install()`](https://ehrlinger.github.io/hvtiverse/reference/hvtiverse_install.md)
  installs all 11 members of the HVTI R package family from GitHub in a
  single `pak` call.
- [`hvtiverse_update()`](https://ehrlinger.github.io/hvtiverse/reference/hvtiverse_update.md)
  installs only the members that are missing or out of date, and refuses
  to overwrite a member whose namespace is already loaded.
- [`hvtiverse_status()`](https://ehrlinger.github.io/hvtiverse/reference/hvtiverse_status.md)
  reports installed against latest versions for every member.
- [`hvtiverse_doctor()`](https://ehrlinger.github.io/hvtiverse/reference/hvtiverse_doctor.md)
  adds R version and platform checks for diagnosing an installation that
  will not work.
- [`hvtiverse_members()`](https://ehrlinger.github.io/hvtiverse/reference/hvtiverse_members.md)
  exposes the registry.
