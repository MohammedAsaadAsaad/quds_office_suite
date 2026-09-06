# Changelog

All notable changes to `quds_office_editor` are documented here.

## 0.1.0

First public release.

### Surfaces
- `QudsWordEditor` — paginated Word canvas with IME, BiDi caret, tables, comments, headers/footers, equations, and visuals.
- `QudsSheetEditor` — virtualized spreadsheet grid with formula bar, freeze panes, fill handle, and charts.
- `QudsSlideEditor` — slide stage with transform handles, snap guides, animations, and a real slideshow (including reverse play).

### Host integration
- Controllers load and save OOXML bytes (`fromBytes` / `saveBytes`), including password-protected packages.
- `OfficeTheme` + `OfficeSurfaceConfig` for light/dark, viewing / selecting / editing modes, and bilingual chrome strings.
- Undo/redo, clipboard, context menus, and keyboard intents without `TextField` / `ListView` / `InteractiveViewer`.
- Isolate open for large documents so the UI isolate stays live.

### Studio example
- Full bilingual Word / Excel / PowerPoint workspace under `example/`.
