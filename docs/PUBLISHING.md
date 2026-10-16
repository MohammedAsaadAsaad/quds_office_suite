# Publishing Quds Office Suite

The GitHub repository is the **monorepo**. pub.dev gets **three packages**,
published one at a time.

| Order | Directory | Command | Depends on |
| --- | --- | --- | --- |
| 1 | `packages/quds_office_engine` | `dart pub publish` | — |
| 2 | `packages/quds_reports` | `dart pub publish` | `quds_office_engine` on pub.dev |
| 3 | `packages/quds_office_editor` | `flutter pub publish` | `quds_office_engine` and `quds_reports` on pub.dev |

The workspace root (`quds_office_suite`), the studio example, and
`apps/quds_report_studio` are
**not** published (`publish_to: none`).

---

## 1. Prerequisites

```bash
dart pub logins   # or: flutter pub login
```

Confirm the account that will own the packages on [pub.dev](https://pub.dev).

`quds_reports` carries the same version as `quds_office_engine` (currently
`1.4.0`). The editor is `1.5.0` and depends on both. CHANGELOG entries must
exist for the version you publish.

---

## 2. Dry-run (always)

From the repository root, after `dart pub get`:

```bash
cd packages/quds_office_engine
dart pub publish --dry-run
```

```bash
cd packages/quds_reports
dart pub publish --dry-run
```

```bash
cd packages/quds_office_editor
flutter pub publish --dry-run
```

Fix every warning you can: missing LICENSE, short description, undocumented
public API, leftover `publish_to: none`, path dependencies.

The editor depends on `quds_office_engine: ^1.4.0` and `quds_reports: ^1.4.0`.
Inside the workspace, Dart resolves the local packages. On pub.dev, those
versions must already exist **before** you publish the editor. Publish
`quds_reports` only after the matching engine version is on pub.dev.

---

## 3. Publish engine

```bash
cd packages/quds_office_engine
dart test
dart pub publish
```

Wait until [pub.dev/packages/quds_office_engine](https://pub.dev/packages/quds_office_engine)
shows the new version (often a few minutes).

---

## 4. Publish quds_reports

```bash
cd packages/quds_reports
dart test
dart pub publish
```

Wait until [pub.dev/packages/quds_reports](https://pub.dev/packages/quds_reports)
shows the new version.

---

## 5. Publish editor

```bash
cd packages/quds_office_editor
flutter test
flutter pub publish
```

---

## 6. Tag the monorepo

```bash
git tag v1.4.0
git push origin v1.4.0
```

If later versions diverge, tag per package (`engine-v0.2.0`, `editor-v0.2.0`).

---

## 7. After publish

- Verify README, changelog, and example tabs on each pub.dev page.
- The pub.dev score updates after the analyzer / pana run (can take a while).
- Do not republish the same version. Bump, changelog, then publish again.

---

## Versioning

Follow [semver](https://semver.org):

- **0.x** — breaking changes allowed with a minor bump.
- **Patch** — fixes that do not change the public API.
- **Minor** (1.x+) — compatible additions.
- **Major** — breaking API.

When the engine breaks its API, bump `quds_reports` to the same version and
the editor constraints in the same PR, then publish engine, `quds_reports`,
and the editor in that order.
