# quds_office_editor

<p>
  <a href="https://pub.dev/packages/quds_office_editor"><img alt="pub package" src="https://img.shields.io/pub/v/quds_office_editor.svg"/></a>
  <a href="https://pub.dev/packages/quds_office_editor/score"><img alt="pub points" src="https://img.shields.io/pub/points/quds_office_editor"/></a>
  <a href="https://github.com/MohammedAsaadAsaad/quds_office_suite/blob/main/LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-0B1F3A"/></a>
  <img alt="Flutter RenderBox" src="https://img.shields.io/badge/Flutter-RenderBox-02569B?logo=flutter&logoColor=white"/>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.44%2B-02569B?logo=flutter&logoColor=white"/>
</p>

**Embeddable Word, Excel, PowerPoint, and PDF surfaces for Flutter.** Each
document is a custom `RenderBox`. Not `TextField`. Not `ListView`. Not
`InteractiveViewer`.

This is the interaction half of
[Quds Office Suite](https://github.com/MohammedAsaadAsaad/quds_office_suite).
Documents, formulas, pagination, `PdfFile`, `PdfToolbox`, and `pdf_widgets`
live in [`quds_office_engine`](https://pub.dev/packages/quds_office_engine)
and are re-exported from this package.

You draw the ribbon, the file menu, and the window chrome. This package paints
the document.

![Word editor](example/screenshots/word.png)
![Excel editor](example/screenshots/excel.png)
![PowerPoint editor](example/screenshots/powerpoint.png)
![PDF viewer](example/screenshots/pdf.png)

---

## Why a custom RenderBox

A real Office canvas is one engine. Caret, BiDi, IME, pagination, tables,
selection, and zoom must agree on the same coordinates.

Flutter’s text widgets are excellent for forms. They are the wrong primitive
for a paginated Word page, a virtualized sheet, a slide stage with motion, or
a PDF page whose text runs live in unrotated crop space.

| Surface | Controller | What it paints |
| --- | --- | --- |
| `QudsWordEditor` | `WordEditorController` | Paginated pages, caret, tables, comments, headers and footers, OMML, pictures |
| `QudsSheetEditor` | `SheetEditorController` | Virtualized grid, formula bar, freeze panes, fill handle, charts |
| `QudsSlideEditor` | `SlideEditorController` | Slide stage, transform handles, snap guides, animations, slideshow |
| `QudsPdfViewer` | `PdfViewerController` | Read-only PDF pages, zoom, find, copy, links, rotation |
| `QudsPdfEditor` | `PdfEditorController` | The same canvas plus markup, form fill, page ops, incremental save |

```text
┌─ your Scaffold / desktop frame ──────────────────────────┐
│  toolbarBuilder  (optional — your ribbon)                │
│  ┌─────────────────────────────────────────────────────┐ │
│  │  QudsWordEditor / QudsSheetEditor / QudsSlideEditor │ │
│  │  QudsPdfViewer / QudsPdfEditor                      │ │
│  │  RenderBox  ·  IME  ·  selection  ·  undo           │ │
│  └─────────────────────────────────────────────────────┘ │
│  statusBarBuilder (optional)                             │
└──────────────────────────────────────────────────────────┘
```

Host chrome stays outside the widget. The page, grid, stage, and PDF stack
are custom paint.

---

## Languages and writing directions

The editor is built for **many languages and many writing directions**, not a
single locale.

- **IME composition** — Latin, Arabic, Hebrew, CJK, and other system IMEs
  compose on the custom caret. There is no `EditableText` on the page.
- **Logical caret, visual runs** — the caret walks grapheme clusters. Paint
  follows the engine’s UAX #9 BiDi and Arabic shaping.
- **Paragraph and section direction** — LTR, RTL, and mixed documents.
  Windows and Linux Ctrl+Shift side shortcuts flip paragraph direction
  (`officeParagraphDirectionFromSides`).
- **Sheet direction** — worksheets display right-to-left or left-to-right.
- **PDF text** — selection grows from the visual edge of an RTL run. Search
  folds Arabic presentation forms, alef variants, and diacritics so a typed
  query can meet a shaped content stream. A rotated watermark is painted as
  one shaped string on the host face, not as upright letters.
- **Chrome locale** — `OfficeStrings` is a typed string table. Ship
  `OfficeStrings.english`, `OfficeStrings.arabic`, or your own translations.
  The canvas does not hardcode UI copy.
- **Surface direction** — `OfficeSurfaceConfig.textDirection` sets the default
  for chrome and new content. Users can still mix directions inside a file.

```dart
const OfficeSurfaceConfig(
  textDirection: TextDirection.rtl,
  strings: OfficeStrings.arabic,
);
```

The same document bytes open with the same layout in any host language.
Locale changes chrome labels, not pagination.

---

## Install

```yaml
dependencies:
  quds_office_editor: ^0.4.0
```

```bash
flutter pub add quds_office_editor
```

Requires Flutter **3.44+** and Dart **3.12+**. The engine comes along as
`quds_office_engine: ^0.4.0`.

### Host fonts

The package ships Liberation Sans, Serif, and Mono (Standard 14 / Arial /
Times / Courier substitutes) and Noto Naskh Arabic. Register them once before
paint:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfficeHostFonts.ensureRegistered();
  runApp(const MyApp());
}
```

Aliases such as Helvetica, Arial, Calibri, Times New Roman, and Courier New
resolve to those faces. When a PDF embeds its own `/FontFile2`, that face
wins for glyph shape and advances. Raw CFF is wrapped as OTTO for the host
loader. The engine does not rasterize CFF outlines itself. JBIG2 and JPEG2000
images stay unsupported placeholders.

---

## Word

```dart
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

class WordHost extends StatefulWidget {
  const WordHost({super.key, this.bytes});

  final Uint8List? bytes;

  @override
  State<WordHost> createState() => _WordHostState();
}

class _WordHostState extends State<WordHost> {
  late final WordEditorController controller = widget.bytes == null
      ? WordEditorController(
          config: const OfficeSurfaceConfig(
            textDirection: TextDirection.ltr,
            strings: OfficeStrings.english,
            theme: OfficeTheme.light,
          ),
        )
      : WordEditorController.fromBytes(widget.bytes!);

  @override
  void initState() {
    super.initState();
    if (widget.bytes == null) {
      controller.insertHeading(text: 'New document');
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QudsWordEditor(
      controller: controller,
      toolbarBuilder: (context, c) {
        return const SizedBox.shrink(); // your Home ribbon
      },
    );
  }
}
```

```dart
final Uint8List docx = controller.saveBytes();
```

The Word canvas supports:

- Logical caret and IME, without `EditableText`
- Bold, italic, underline, color, highlight, superscript, subscript
- Alignment, lists, indent, line spacing, LTR and RTL sections
- Page size and orientation per **section** (portrait and landscape in one
  document; continuous column slices share one paper size)
- Horizontal pan and side gutters when a landscape page is wider than the view
- Interactive rulers (margins, indents, tabs)
- Tables (resize, select cells, merge), pictures, charts
- Comments, footnotes and endnotes pane, hyperlinks, headers and footers
- Page breaks, section breaks, TOC
- OMML equations
- Find and replace, print, text statistics
- Undo, redo, copy, cut, paste

Orientation is a section property. Toggling landscape updates the caret
section and its continuous siblings, not a single laid-out page.

---

## Excel

```dart
final controller = SheetEditorController.fromBytes(xlsxBytes);

QudsSheetEditor(
  controller: controller,
  frozenRows: 1,
  frozenCols: 1,
);
```

The grid is virtualized (`VirtualViewport`) so large sheets stay light.

- A1 selection, fill handle, row and column insert and delete
- In-cell editor and formula bar (`showFormulaBar`)
- Formula engine from the engine package (`SUM`, `IF`, `VLOOKUP`, …)
- Freeze panes, RTL or LTR sheets, number formats
- Embedded charts from the selection
- Recalculation on edit; isolate open for large workbooks

```dart
controller.recalculateWorkbook();
final Uint8List xlsx = controller.saveBytes();
```

---

## PowerPoint

```dart
final controller = SlideEditorController.fromBytes(pptxBytes);

QudsSlideEditor(controller: controller);
```

Edit mode:

- Move, resize, and rotate with transform handles
- Snap guides when edges align
- Shape text with the same inline editor used in cells
- Tables, pictures, charts, z-order
- Entrance, emphasis, exit, and motion paths
- Slide transitions (fade, push, wipe, Morph, and others)

Slideshow:

```dart
controller.startShow(from: 0);   // F5 in the studio example
controller.showNext();           // click / →
controller.showPrevious();       // reverse the last motion
controller.endShow();            // Esc
```

`showPrevious()` reverses **that** animation or **that** transition. A fly-in
flies back out. A push slides back. A mid-fade retreats from the current
frame. It is not a jump to the previous slide’s final state.

---

## PDF viewer and editor

`QudsPdfViewer` is display-only (`viewing` / `selecting`): zoom, find, copy,
outline jump, follow URI and internal destinations. It has no `saveBytes`.

`QudsPdfEditor` extends the same canvas: highlights, notes, AcroForm values,
page insert, delete, and rotate, XFDF, and incremental save.

```dart
final viewer = PdfViewerController.fromBytes(pdfBytes);
QudsPdfViewer(controller: viewer);

final editor = PdfEditorController.fromBytes(pdfBytes);
editor.highlightSelection();
editor.rotateCurrentPage(90); // clockwise /Rotate, not a box swap
final Uint8List saved = editor.saveBytes();
```

The page is `RenderPdfCanvas`. Host chrome (File, View, Annotate, Form) stays
outside the widget. Body-text reflow is out of scope.

### What the canvas actually does

| Behavior | Detail |
| --- | --- |
| **Page stack** | Pages are stacked with a gap. `goToPage` scrolls. Thumbnails and the outline jump to a destination |
| **Zoom** | Animated zoom about a focal point. Cached tiles stretch while the gesture is in flight, then raster at the settled scale |
| **Rotation** | `/Rotate` is a clockwise quarter-turn of the view. Hit-testing maps view coordinates back into unrotated crop space before selection and links |
| **Selection** | Drag, double-click word, triple-click run. RTL highlights grow from the right edge. The highlight belongs to the page that owns the runs — it does not stick to the next page or to the next file |
| **Select all** | `Ctrl+A` / `selectAll()` selects every text run in the file |
| **Select page** | `Ctrl+Shift+A` / `selectPage` selects every run on that page, not an x-band between the first and last carets |
| **Copy** | `Ctrl+C` copies the logical text of the selection |
| **Find** | Search walks the display-list runs, including a match that spans several runs. Hits are page-tagged. The current hit scrolls into view. Next and previous wrap |
| **Arabic find** | Queries fold presentation forms, alef variants, and diacritics against the same fold of the page text |
| **Links** | Internal destinations and `http` / `https` / `mailto`. Desktop hover shows a destination preview; the marker is a thin line above the target, not a bar through the heading |
| **Link follow** | `onOpenUri` overrides the platform opener |
| **New file** | `loadBytesAsync` clears selection and find marks, and the canvas drops any in-flight drag highlight |

Opening a PDF and changing pages does not carry the previous selection onto
the new page’s coordinates.

### Page tools

Assembly (merge, split, extract, stamp, numbers, crop) is
[`PdfToolbox`](https://pub.dev/packages/quds_office_engine) on the engine.
The editor consumes the resulting bytes with `loadBytesAsync`. Stamp and
Bates overlays in the toolbox are Helvetica. A shaped, rotated watermark
belongs on `pdf_widgets` `Watermark`, not on the Latin stamp operator.

Rotate in the editor calls the same `/Rotate` model: 90° clockwise or
counter-clockwise, accumulated and normalized, without rewriting MediaBox.

---

## Theming, modes, and chrome

```dart
const OfficeSurfaceConfig(
  mode: OfficeInteractionMode.editing, // or selecting, viewing
  theme: OfficeTheme.dark,
  textDirection: TextDirection.ltr,
  strings: OfficeStrings.english,
  showRulers: true,
  showFormulaBar: true,
  showGridlines: true,
  showSlideHandles: true,
  showFindChrome: false,
  showNotesPane: false,
  showNavigationPane: false,
  enableUndo: true,
);
```

| Mode | Caret / IME | Selection | Mutations |
| --- | --- | --- | --- |
| `editing` | Yes | Yes | Yes |
| `selecting` | No | Yes | No |
| `viewing` | No | No | No |

`OfficeTheme.light`, `OfficeTheme.dark`, and `OfficeTheme.highContrast` ship
as starting palettes. Host chrome is **your** Material or Cupertino. Only the
page, grid, stage, and PDF stack are custom paint.

`OfficeStrings` is a complete typed table (file, home, insert, layout, review,
view, find, notes, PDF page commands, …). `OfficeStrings.english` and
`OfficeStrings.arabic` are included. Provide another language by constructing
`OfficeStrings(...)`.

Density (`OfficeDensity`) and form factor (`OfficeFormFactor`) let a host
tighten chrome on phone versus desktop without changing the document model.

---

## Load, save, progress

```dart
await controller.loadBytesAsync(
  bytes,
  password: password,
  onProgress: (p) => setState(() => label = p.stage),
);

final Uint8List out = controller.saveBytes(password: optionalPassword);
```

Heavy opens run through `OfficeIsolateOpen` so a large deck does not freeze
the first frame. Password-protected OOXML packages open when a password is
supplied. PDF open uses the same isolate path (`OfficeIsolateOpen.pdf`).

Export any Office controller’s model to PDF:

```dart
final Uint8List pdf = OfficePdfExport.fromBytes(controller.saveBytes());
```

PDF save is incremental (`PdfIncrementalSave`) so annotations and form values
append to the original file instead of rewriting every stream.

---

## What this package refuses to be

The document surface is **not** a stack of Flutter text widgets.

| Forbidden on the canvas | Why |
| --- | --- |
| `TextField` / `TextFormField` / `EditableText` | Caret, BiDi, and pagination must be one engine |
| `SelectableRegion` | Selection is owned by the controller |
| `ListView` / `SingleChildScrollView` / `InteractiveViewer` | Virtualization and zoom are custom |

Use those widgets in **your** toolbar, find field, and dialogs. Do not drop
them onto the page. The studio example’s find bar is host chrome; the PDF
highlight itself is painted by `RenderPdfCanvas`.

Also out of scope, on purpose:

- Editing PDF body text as if it were Word
- OCR, and recovering Office layout from a PDF
- CMS signature verification and certified PDF/A
- Rasterizing CFF, JBIG2, or JPEG2000 inside the engine

---

## Studio example

A full workspace (File, Home, Insert, Layout, Review, View, a sample library,
and an OS window frame) lives under `example/`:

```bash
cd packages/quds_office_editor/example
flutter run -d linux   # or macos, windows, chrome
```

The studio includes a bilingual chrome, a PDF gallery (Office export,
`pdf_widgets` samples, face samples), and a PDF tools lab that calls
`PdfToolbox` — merge, split, extract with several range groups, organize,
rotate by quarter-turns, and appearance overlays. Reopen a gallery sample
after changing it; a file already open in the viewer is the bytes you loaded,
not a live link to the gallery builder.

See [example/README.md](example/README.md) for a guided tour.

---

## Architecture

```text
your chrome (ribbons, dialogs, file pickers)
        │
        ▼
QudsWordEditor / QudsSheetEditor / QudsSlideEditor / QudsPdfViewer
        │
        ▼
OfficeController  ·  PdfViewerController
        │
        ▼
quds_office_engine   models, layout, PdfFile, export
```

| File | Role |
| --- | --- |
| `office_editors.dart` | Office widgets, shortcuts, IME |
| `pdf_editors.dart` | `QudsPdfViewer` / `QudsPdfEditor` |
| `office_controller.dart` | Commands, selection, undo, load and save |
| `pdf_controller.dart` | PDF page, selection, find, markup, save |
| `office_theme.dart` | Tokens, modes, localizable strings |
| `office_clipboard.dart` | Copy, cut, paste |
| `render_word_canvas.dart` | Paginated Word `RenderBox` |
| `render_sheet_grid.dart` | Virtualized sheet `RenderBox` |
| `render_slide_stage.dart` | Slide and slideshow `RenderBox` |
| `render_pdf_canvas.dart` | PDF page stack `RenderBox` |
| `pdf_text_selection.dart` | Caret, RTL slices, page-owned highlights |
| `pdf_find.dart` | Display-list search with Arabic folding |
| `office_ruler.dart` | Interactive Word ruler |
| `word_notes_pane.dart` | Footnotes and endnotes host pane |

---

## Design rules

- **Engine owns the model** — the editor never forks a second document format.
- **RenderBox only on the canvas** — no scrolling or text widgets as the page.
- **Host owns chrome** — ribbons, dialogs, and file pickers stay in your app.
- **Type-safe commands** — undoable mutations go through the controller.
- **PDF selection is page-owned** — a highlight is not a screen rectangle that
  follows the viewport.

---

## License

MIT. See [LICENSE](LICENSE).
