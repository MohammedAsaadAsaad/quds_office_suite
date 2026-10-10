# Changelog

All notable changes to `quds_office_editor` are documented here.

## 0.6.0

**Report designer (`QudsReportDesigner`).** Depends on `quds_office_engine` **0.6.0**.

- `ReportDesignerController`:
  - Select, move, resize, and nudge; snap to grid and guides.
  - Align, distribute, and same size; z-order; clipboard and duplicate.
  - Add and remove bands; undo and redo.
  - Typed property inspector rows; inline text editing.
  - Inferred mock data.
- RenderBox surfaces (no text fields, no scroll widgets):
  - `ReportDesignerCanvas`: bands, rulers, handles, marquee, tool creation, and cross-band drag.
  - `ReportInspector`.
  - `ReportToolbar` with vector icons.
  - `ReportPreviewSurface`: a paginated live preview painted from the engine's glyph outlines.
- Context menus; Design/Preview toggle (F5).
- Export to PDF, XLSX, or DOCX through `onExport`.
- Chart tool: creates a data-bound bar chart; the inspector edits type, data, aggregation, sort, top N, series, static points, and styling. The canvas draws the chart with the engine renderer and sample values.
- Templates button: loads one of `ReportTemplates.all` with its sample data, or a blank report (`ReportDesignerController.loadTemplate`).
- Autocomplete while editing text on the canvas or inspector values: a painted popup under the caret. ↑/↓ choose, Enter/Tab insert, Esc closes, Ctrl+Space opens it anywhere. Functions insert `NAME()` with the caret inside.
- Template variables: a Variables toolbar menu inserts `{{Variables.x}}` at the caret or as a new text box. With nothing selected, the inspector adds, renames, retypes, formats, and removes variables. Values are checked against the type, and renaming a variable rewrites its references.
- The on-canvas text editor paints on the element's fill and switches to black or white text when the element's color would be unreadable (WCAG 4.5:1).
- `ReportLayoutPainter.paintPrimitives` paints any primitive list, including chart paths.
- `ReportBundledFonts` loads the package's Liberation and Noto Naskh Arabic faces into a `ReportFontRegistry`.
- Inspector redesign (still one RenderBox):
  - Collapsible sections, a title badge with the element kind and band, and diagnostics with severity icons.
  - Controls picked from property metadata: switches for booleans, segmented icon or text choices, dropdowns, ±steppers (↑/↓ while editing, Shift for ×10), preset combos (font sizes, families, format samples), paired X/Y and Width/Height fields, and a B/I/U glyph row.
  - A painted color popover: no color, the template palette, Office theme tints and shades, and standard colors.
  - `ReportProperty` gains `hint`, `presets`, `step`, `min`, `pair`, and `glyph`. `ReportDesignerController.stepProperty` / `steppedValue` snap to the unit's step and clamp to the minimum.
- Standalone desktop app [`apps/quds_report_studio`](https://github.com/MohammedAsaadAsaad/quds_office_suite/tree/main/apps/quds_report_studio) replaces the old example entry point. It has frameless window chrome (move, resize, maximize), New/Open/Save/Save as, recent files, and an unsaved-changes guard.

**Fixes.**

- Chart visuals reserve a strip for the bottom legend, so it no longer overlaps the category labels.
- `PdfViewerController` zoom animation starts on its first frame. Calling `fitPage` / `setScale` from a tap no longer trips the scheduler assertion.
- `RenderWordCanvas.windowForPagePoint` maps a page point back to widget coordinates (the inverse of hit-testing), so hosts and tests can target page content past the rulers.
- Analyzer clean-up across the package and example (initializing formals, unnecessary casts, `onReorderItem`).
- The example studio theme uses Liberation Sans with Noto Naskh Arabic / Tajawal as fallbacks, so Latin chrome text no longer depends on host fonts.

## 0.5.1

**PDF viewer options and events.**

- `PdfViewerOptions` on `QudsPdfViewer` / `QudsPdfEditor`: fit policy, zoom
  clamps, swipe enable/axis, page fling/snap, night invert, background,
  scrollbar, password, `preventLinkNavigation`.
- Callbacks: `onViewCreated`, `onLoadComplete`, `onPageChanged`, `onRender`,
  `onError`, `onPageError`, `onLinkHandle`, `onDraw`.
- Horizontal page stack, night-mode raster invert (viewer), and snap/fling on
  the canvas.
- Depends on `quds_office_engine` **0.5.3** (Arabic tashkeel on the correct
  letter, BiDi format marks skipped, new `pdf_widgets`).

## 0.5.0

**Studio gallery ships the report template library.**

- Templates are the landing gallery rail. Category chips filter commerce,
  finance, people, operations, narrative, data, education, property,
  logistics, and programs.
- Every template sample is **two pages** in one PDF: English, then Arabic.
- Depends on `quds_office_engine` **0.5.0** (`pdf_templates`, `SheetSkin`,
  RTL table cell start alignment, Flutter twins).
- Gallery also covers Flutter-twins widgets and the existing showcase /
  Office → PDF samples.

## 0.4.0

PDF viewing matches the page that owns the text.

- Selection stays on its page. Opening another file or scrolling to another
  page does not repaint the old highlight at the same coordinates.
- `Ctrl+A` / `selectAll()` selects every text run in the file.
  `Ctrl+Shift+A` / `selectPage` selects every run on that page.
- Find walks display-list runs, including matches that span runs. Hits are
  page-tagged, the current hit scrolls into view, and next/previous wrap.
  Arabic queries fold presentation forms, alef variants, and diacritics.
- `/Rotate` is painted and hit-tested as a clockwise quarter-turn of the view.
- Depends on `quds_office_engine` 0.4.0 (`PdfToolbox` graft, shaped watermark).

## 0.3.0

**Four surfaces: Word · Excel · PowerPoint · PDF.** The editor now embeds a
full PDF viewer/editor beside the Office canvases — same RenderBox discipline,
same theme/chrome hooks.

### PDF surfaces
- `QudsPdfViewer` / `QudsPdfEditor` on `RenderPdfCanvas` (display list paint,
  find, copy, link follow, animated zoom with tile stretch).
- Viewer is display-only; editor adds markup, form fill, page ops, layer
  toggle, and incremental save.
- Host fonts: call `OfficeHostFonts.ensureRegistered()` so Standard-14 /
  common Office aliases paint without OS font folders; embedded PDF faces win.

### Office surfaces (continued)
- `QudsWordEditor`, `QudsSheetEditor`, `QudsSlideEditor` — IME, BiDi caret,
  formulas, Morph slideshow, isolate open.

### Studio example
- PDF gallery (Office→PDF, PdfDocument writer, `pdf_widgets` samples) and
  bilingual workspace.

## 0.2.0

Interactive Word ruler, notes pane, section-wide landscape, horizontal page
gutters, and English package documentation. Chrome strings stay localizable;
the canvas supports many languages and writing directions.

## 0.1.0

First public release.

### Surfaces
- `QudsWordEditor` — paginated Word canvas with IME, BiDi caret, tables, comments, headers/footers, equations, and visuals.
- `QudsSheetEditor` — virtualized spreadsheet grid with formula bar, freeze panes, fill handle, and charts.
- `QudsSlideEditor` — slide stage with transform handles, snap guides, animations, and a real slideshow (including reverse play).

### Host integration
- Controllers load and save OOXML bytes (`fromBytes` / `saveBytes`), including password-protected packages.
- `OfficeTheme` + `OfficeSurfaceConfig` for light/dark, viewing / selecting / editing modes, and localizable chrome strings.
- Page orientation applies to the whole continuous section; the Word canvas pans horizontally with side gutters.
- Undo/redo, clipboard, context menus, and keyboard intents without `TextField` / `ListView` / `InteractiveViewer`.
- Isolate open for large documents so the UI isolate stays live.

### Studio example
- Full bilingual Word / Excel / PowerPoint workspace under `example/`.
