# Publishing Quds Office Suite

The GitHub repository is the **monorepo**. pub.dev gets **two packages**,
published one at a time.

| Order | Directory | Command | Depends on |
| --- | --- | --- | --- |
| 1 | `packages/quds_office_engine` | `dart pub publish` | — |
| 2 | `packages/quds_office_editor` | `flutter pub publish` | `quds_office_engine` on pub.dev |

The workspace root (`quds_office_suite`) and the studio example are
**not** published (`publish_to: none`).

---

## 1. Prerequisites

```bash
dart pub logins   # or: flutter pub login
```

Confirm the account that will own the packages on [pub.dev](https://pub.dev).

Version in both `pubspec.yaml` files must match the release you want
(`0.1.0` for the first cut). CHANGELOG entries must exist for that version.

---

## 2. Dry-run (always)

From the repository root, after `dart pub get`:

```bash
cd packages/quds_office_engine
dart pub publish --dry-run
```

```bash
cd packages/quds_office_editor
flutter pub publish --dry-run
```

Fix every warning you can: missing LICENSE, short description, undocumented
public API, leftover `publish_to: none`, path dependencies.

The editor depends on `quds_office_engine: ^0.4.0`. Inside the workspace,
Dart resolves the local package. On pub.dev, the version must already exist
**before** you publish the editor.

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

## 4. Publish editor

```bash
cd packages/quds_office_editor
flutter test
flutter pub publish
```

---

## 5. Tag the monorepo

```bash
git tag v0.1.0
git push origin v0.1.0
```

If later versions diverge, tag per package (`engine-v0.2.0`, `editor-v0.2.0`).

---

## 6. After publish

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

When the engine breaks its API, bump the editor constraint in the same PR
(`quds_office_engine: ^0.4.0`) and publish engine first.
