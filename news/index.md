# Changelog

## hvtiR 1.0.1

- **The package is renamed from `hvtiverse` to `hvtiR`**, matching the
  `hvtiR*` prefix the rest of the family uses. Install from
  `ehrlinger/hvtiR`.

- **Every exported function is renamed**, dropping the package-name
  prefix that no other family package carries. The package is meant to
  be called with `::` rather than attached:

  | was | now |
  |----|----|
  | [`hvtiverse::hvtiverse_install()`](https://ehrlinger.github.io/hvtiverse/reference/hvtiverse_install.html) | [`hvtiR::install()`](https://ehrlinger.github.io/hvtiR/reference/install.md) |
  | [`hvtiverse::hvtiverse_update()`](https://ehrlinger.github.io/hvtiverse/reference/hvtiverse_update.html) | [`hvtiR::update()`](https://ehrlinger.github.io/hvtiR/reference/update.md) |
  | [`hvtiverse::hvtiverse_status()`](https://ehrlinger.github.io/hvtiverse/reference/hvtiverse_status.html) | [`hvtiR::status()`](https://ehrlinger.github.io/hvtiR/reference/status.md) |
  | [`hvtiverse::hvtiverse_doctor()`](https://ehrlinger.github.io/hvtiverse/reference/hvtiverse_doctor.html) | [`hvtiR::doctor()`](https://ehrlinger.github.io/hvtiR/reference/doctor.md) |
  | [`hvtiverse::hvtiverse_members()`](https://ehrlinger.github.io/hvtiverse/reference/hvtiverse_members.html) | [`hvtiR::members()`](https://ehrlinger.github.io/hvtiR/reference/members.md) |

- The class returned by
  [`status()`](https://ehrlinger.github.io/hvtiR/reference/status.md) is
  renamed `hvtiR_status`. Unlike the functions it stays
  package-qualified, because S3 classes are matched by string and a bare
  `status` class would collide.

- No deprecated aliases are provided. `hvtiverse` 1.0.0 was never
  depended on outside this family, so there is nothing to migrate.
