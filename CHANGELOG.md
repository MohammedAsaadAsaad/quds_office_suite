# Changelog

This repository is a Dart workspace. Each published package keeps its own changelog:

- [`packages/quds_office_engine/CHANGELOG.md`](packages/quds_office_engine/CHANGELOG.md)
- [`packages/quds_office_editor/CHANGELOG.md`](packages/quds_office_editor/CHANGELOG.md)

## 1.1.0 / 1.1.0

Engine **1.1.0**, editor **1.1.0**, and Report Studio **1.1.0**.

- Pinching with two fingers (trackpad or touch screen) zooms the report
  canvas and the preview.
- Report Studio no longer shows a message when it opens or saves a report
  with problems. The error and warning count in the status bar opens a
  problems panel under the canvas instead. Each problem says what is wrong,
  what kind of problem it is, and where; clicking it goes there and marks
  the property to fix.
- Report templates are ready-made `.qrep` files instead of code. In Report
  Studio, **File › Save as template** turns the open report into a template,
  listed under **New from template › My templates**. Any `.qrep` in the
  studio's templates folder is offered too.
- The report inspector replaces an embedded image in place: click its
  thumbnail, and every element showing it updates.
- Reports with expression errors open in the designer with the errors listed
  instead of failing to load.
- `SUM(item.x)` in a template variable totals the detail rows instead of
  returning 0.
- Report Studio has light and dark themes and an English or Arabic
  interface. Both follow the system by default, and the language falls back
  to English. You can change them from the settings button in the title bar.
- Report Studio prints. Use Ctrl+P, the printer button, **File › Print…**,
  or **Print** on the toolbar to open the system print dialog at the
  report's page size. It uses the `printing` package.
- A redesigned report inspector:
  - Icon buttons with tooltips.
  - A variables explorer with dotted folders (`stats.sum` →
    `{{Variables.stats.sum}}`).
  - Image thumbnails.
  - Font cards.
  - A font picker that previews each installed font in its own script.
- The report designer can be localized (`ReportDesignerStrings`, English and
  Arabic, with full right-to-left layout).

## 1.0.0 / 1.0.0

First stable release of both packages (engine **1.0.0**, editor **1.0.0**).
The public API now follows semantic versioning.

- Fidelity fixes for Word, Excel, and PowerPoint files from other suites ([#2](https://github.com/MohammedAsaadAsaad/quds_office_suite/issues/2), [#3](https://github.com/MohammedAsaadAsaad/quds_office_suite/issues/3), [#4](https://github.com/MohammedAsaadAsaad/quds_office_suite/issues/4)), plus LibreOffice outline lists, style bold inheritance, and Excel header codes and cell alignment in PDF export. The engine README compares LibreOffice's own PDFs with the engine's for the same files.
- Calculated columns show up in report suggestions, variables, and fields.
- `.qrep` files are ZIP packages: `layout.xml` plus pre-saved images (`ReportPackage`, `QudsReportEngine.fromPackage`). Legacy plain-XML files still open.
- The designer and Report Studio embed, rename, insert, and remove report images (undoable) and save them inside the `.qrep`.
- The report inspector has Properties / Variables / Images tabs and a resizable width; Report Studio remembers the width in `settings.json`.
- Reports embed TrueType fonts in the `.qrep` (`fonts/<family>/regular.ttf|bold.ttf`), so they export with the designed faces anywhere. The inspector gains a Fonts tab; Report Studio lists installed fonts for one-click embedding and imports `.ttf` files.
- Reports declare their data in `<DataSchema>`: typed fields and tables, plus calculated columns that are evaluated at export. Sample data is saved in the `.qrep` as `data/sample.json`.
- The designer and Report Studio have a **data explorer** (F6), a Power BI-style grid. You can browse and edit tables and fields; add, rename, and delete rows and columns, including calculated `ƒx` columns; and import CSV or JSON. Renaming a column or field rewrites its bindings.
- Every report element has a unique name. `QudsReportEngine` can fill a report from code by name: `setText`, `setImage`, `setTableRows`, `setChartPoints`, `setVisible`, and `elementAs<T>`. It can also hold host data (`engine.data`) and export it with `export(format)`.
- Report templates are categorized (sales, finance, inventory, analytics, human resources), and each of the eight families ships an Arabic and an English version (16 templates). Templates carry pre-saved images (logo, stamp, signature, seal, product photos). Report Studio's **New from template** goes category, then family, then language. Adds `AMOUNTWORDS` / `words:` (English amounts in words) and `dateAr:` (Arabic month names).
- Report Studio **1.0.0 installers** ([release `studio-v1.0.0`](https://github.com/MohammedAsaadAsaad/quds_office_suite/releases/tag/studio-v1.0.0)):
  - A new app icon and a `.qrep` document icon (`tool/make_icons.py`) for Windows, Linux, macOS, and web.
  - Windows: an Inno Setup installer with an uninstaller, and a portable zip. Linux: a `.deb` and a tar.gz with `install.sh` / `uninstall.sh`.
  - On its first run the studio registers itself for `.qrep` files (the freedesktop MIME type plus a desktop entry on Linux, `HKCU` registry keys on Windows), so opening a `.qrep` file launches the studio. **File › Open .qrep files with Report Studio** registers it again.
  - The `report-studio-release` workflow builds all packages and attaches them to the GitHub release when a `studio-v*` tag is pushed.
  - The engine and editor READMEs link to the downloads, and the engine's pub.dev screenshots include the studio.

## 0.6.0 / 0.6.0

- Engine **0.6.0**: band report engine (`quds_reports.dart`): `.qrep`
  templates, expressions, typed variables, charts, six templates, and
  PDF / XLSX / DOCX export. Also PDF fidelity waves (GPOS marks, FreeText
  appearances, page graft, AcroForm write, JBIG2 MMR, CMS digest check).
- Editor **0.6.0**: `QudsReportDesigner` (canvas, inspector, toolbar, live
  preview, autocomplete) and the redesigned inspector.
- New app [`apps/quds_report_studio`](apps/quds_report_studio): a standalone
  desktop report editor.

## 0.5.3 / 0.5.1

- Engine **0.5.3**: `pdf_widgets` chrome (page numbers, barcodes, QR, SVG
  subset), bilingual catalog, skip BiDi format marks, keep Arabic tashkeel
  on its letter in PDF.
- Editor **0.5.1**: `PdfViewerOptions` and viewer/editor callbacks (fit,
  swipe, snap/fling, night invert).

## 0.5.0

- Engine: `pdf_templates` with 100+ skins (`SheetSkin`), Flutter twins,
  named `OfficeColors`, RTL table cell start alignment.
- Editor: Studio gallery lands on templates; each sample is English then
  Arabic; category chips for every domain.

## 0.4.0

- Engine: `PdfToolbox` page graft, quarter-turn `/Rotate`, shaped PDF watermark,
  two-slides-per-page export.
- Editor: page-owned PDF selection, select-all / select-page, display-list
  search with Arabic folding.
- Package READMEs rewritten to cover the public surface and the honest limits.

## 0.3.1

- Engine patch: `pdf_widgets` stays on a dedicated import (no Flutter name clashes).

## 0.3.0

- Phase 6 PDF file: `PdfFile`, display list, `QudsPdfViewer` / `QudsPdfEditor`.
- PDF widget composer (`pdf_widgets.dart`); Word widget DSL removed.
- Animated PDF zoom, host fonts, Studio PDF gallery.
- pub.dev **0.3.0** — Office + PDF diversity highlighted in package docs.

## 0.2.0

- English documentation for the engine, editor, and repository landing page.
- Word widget DSL, section landscape, find/print/stats, and editor chrome updates.

## 0.1.0

- First public GitHub release of the suite.
- Packages are published **separately** on pub.dev.
