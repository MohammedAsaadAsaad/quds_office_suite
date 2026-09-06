# Contributing

Thank you for helping Quds Office Suite.

## Workspace

This repo is a Dart workspace:

```text
packages/quds_office_engine   # pure Dart — never import dart:ui or Flutter
packages/quds_office_editor   # Flutter RenderBox editors
```

```bash
dart pub get
cd packages/quds_office_engine && dart test
cd packages/quds_office_editor && flutter test
```

## Rules

- Complete work. No `TODO` stubs or placeholder returns.
- 100% type safety: no `dynamic`, no untyped maps.
- Engine package: no Flutter, no `dart:ui`.
- Editor canvases: `RenderBox` / `LeafRenderObjectWidget` only. Do not use
  `TextField`, `TextFormField`, `EditableText`, `SelectableRegion`,
  `ListView`, `SingleChildScrollView`, or `InteractiveViewer` on the
  document surface. Host chrome (the studio example) may use Material.
- Prefer `Uint8List` views, index slicing, and pooling over heap-heavy trees.

## Pull requests

1. Keep engine and editor changes separable when you can.
2. Add or update tests next to the behavior you change.
3. Update the package `CHANGELOG.md` if the public API or user-visible
   behavior changes.
4. Do not bump versions unless we are cutting a release.

## Publishing

Maintainers: see [docs/PUBLISHING.md](docs/PUBLISHING.md).
Each package is published **separately** on pub.dev.
