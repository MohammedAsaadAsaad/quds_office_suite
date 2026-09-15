# Changelog

All notable changes to `quds_office_editor` are documented here.

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
