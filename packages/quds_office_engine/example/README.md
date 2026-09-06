# Quds Office Engine examples

Pure Dart (no Flutter). Start here, then open the gallery if you want every
format at once.

## Quickstart

One Word file and its PDF:

```bash
cd packages/quds_office_engine
dart run example/engine_quickstart.dart
```

## Rich export gallery

Writes **several files per app** — Word, Excel, and PowerPoint — then exports
each package to **PDF 1.7** with `OfficePdfExport`.

From this folder, or from the engine package root:

```bash
cd packages/quds_office_engine
dart run example/rich_export_gallery.dart
```

Optional output directory:

```bash
dart run example/rich_export_gallery.dart /tmp/quds-gallery
```

Arabic glyphs need a system UI font (DejaVu / Liberation / Noto). The script
embeds a subset when it finds one.

## What is written

| Folder | Office files | Extra PDF |
| --- | --- | --- |
| `out/word/` | engine briefing, builder report, letter | one PDF each |
| `out/excel/` | formula workbook, styled builder book, catalog | one PDF each |
| `out/powerpoint/` | engine shapes deck, builder layouts, RTL deck | slides PDF + notes-pages PDF for the engine deck |

Open the `.docx` / `.xlsx` / `.pptx` in Microsoft Office or LibreOffice, and
the `.pdf` in any reader.
