# Quds Office Suite — PDF program (Phase 6)

Canonical plan for adding **PDF as a first-class format**: open, display,
annotate, fill, and save — without changing Word, Excel, PowerPoint, or the
existing PDF **writer**.

This document is the Phase 6 contract. Implementation lives under
`packages/quds_office_engine/lib/src/pdf/file/` and
`packages/quds_office_editor/lib/src/editor_pdf/`. Do not skip remaining
honesty items in [STANDARDS.md](STANDARDS.md). Do not leave `TODO` stubs,
`dynamic`, or placeholder return values.

Companion docs: [MISSION.md](MISSION.md), [ROADMAP.md](ROADMAP.md),
[STANDARDS.md](STANDARDS.md).

---

## 1. Goal

Ship three host-facing products on top of one pure-Dart model:

| Product | Widget / API | Mutations | Typical host |
| --- | --- | --- | --- |
| **Engine** | `PdfFile`, isolate open/save, extract, find, print | Model only | CLI, server, isolates |
| **Viewer** | `QudsPdfViewer` | None | Read-only embed, preview pane |
| **Editor** | `QudsPdfEditor` | Annotations, form values, page ops (defined below) | Full PDF workspace |

The viewer is **not** a crippled editor. It is the same canvas in
`OfficeInteractionMode.viewing` / `selecting`, published as its own widget so
a host can depend on display-only APIs.

Existing `OfficePdfExport` / `PdfDocument` (the **compiler**) stay the write
path from OOXML and `PdfReportBuilder`. `pdf_widgets.dart` is a constraint-layout
composer on that writer (`Widget.layout` → `PdfCanvas`). It does not edit
`PdfFile` content streams. PDF-as-a-file is a **parallel** stack.

---

## 2. Non-negotiables

| Rule | Meaning |
| --- | --- |
| Engine stays pure Dart | No `dart:ui`, no Flutter, no platform channels in `quds_office_engine` |
| Editor stays RenderBox | No `TextField`, `TextFormField`, `EditableText`, `SelectableRegion`, `ListView`, `SingleChildScrollView`, `InteractiveViewer` on the page |
| Isolation | New types live under `lib/src/pdf/file/` (read/edit model). Do not reuse or rename the writer’s `PdfDocument` / `PdfPage` / `PdfCanvas` |
| No OOXML coupling | A PDF file is not a `WmlDocument`. Conversion Word↔PDF remains export-only unless a later, explicit translator is added |
| Type safety | No `dynamic`, no untyped maps. COS values are a closed typed union |
| Incremental honesty | If a feature is not implemented, the API returns a typed unsupported result — never silent drop of user edits |
| General-purpose only | No customer-specific or document-specific branches |
| Languages and directions | Unicode extract, visual selection from the display list, logical copy via ToUnicode / ActualText. LTR, RTL, and mixed runs as the file stored them |

---

## 3. Standards map

The suite **targets** these specifications. “Target” means we implement a
documented subset and test against it — not that every optional clause ships
in the first wave.

### 3.1 Core file format

| Spec | Role in this program |
| --- | --- |
| **ISO 32000-1:2008** (PDF 1.7) | Primary read/write dialect. Matches the existing writer. |
| **ISO 32000-2:2020** (PDF 2.0) | **Read** compatible (ignore unknown keys; honor 2.0 encryption revisions when present). **Write** stays 1.7 unless a later wave opts in. |
| Adobe implementation notes (xref repair, hybrid files) | Repair heuristics only, documented in STANDARDS |

Required syntax (engine open must succeed when present):

- Header `%PDF-1.x` / `%PDF-2.0`
- Body of indirect objects (`n g obj` … `endobj`)
- Cross-reference **table** (`xref`) and **stream** (`/Type /XRef`, PDF ≥ 1.5)
- Trailer / trailer-in-xref-stream; `startxref` (last occurrence wins)
- **Incremental updates** (ISO 32000-1 §7.5.6): parse the newest section, keep the original byte prefix for later incremental save
- **Object streams** (`/Type /ObjStm`)
- Generation numbers; free-list entries
- Linearized hint dictionaries: **open as a normal file** (ignore hint tables; do not require linearization on save)

### 3.2 Filters (ISO 32000-1 §7.4)

| Filter | Wave | Notes |
| --- | --- | --- |
| `/FlateDecode` (+ `/DecodeParms` predictor) | P6.1 | Already have Flate in the writer |
| `/ASCIIHexDecode`, `/ASCII85Decode` | P6.1 | |
| `/RunLengthDecode` | P6.1 | |
| `/DCTDecode` | P6.2 | JPEG image XObject |
| `/CCITTFaxDecode` | P6.2 | Group 3 1-D and Group 4 (landed). Mixed G3 2-D (`K>0`) is 1-D best-effort |
| `/LZWDecode` | P6.3 | |
| `/JBIG2Decode` | P6.5 | Typed `PdfFilterUnsupported` (stays; no decoder) |
| `/JPXDecode` | P6.5 | Same |
| `/Crypt` | P6.1 | After the security handler decrypts the stream |

Unsupported filters must yield `PdfFilterUnsupported` on that stream, not a
crash. The page still paints everything else.

### 3.3 Encryption (ISO 32000-1 §7.6, ISO 32000-2)

| Item | Wave | Notes |
| --- | --- | --- |
| Standard security handler, Rev 2–4 (RC4 / AES-128) | P6.1 | Password open, same host pattern as OOXML |
| AES-256 (Rev 5/6, Acrobat X+ / PDF 2.0) | P6.3 | |
| Empty user password / owner-only | P6.1 | |
| Permissions flags (print, copy, modify, annotate) | P6.1 | Viewer/editor **honor** them; host may offer an override flag for owned files |
| Public-key (PKCS#7) encryption | Later | Typed unsupported |
| Write encryption of a new or incremental file | P6.6 | Optional; not required for annotation save if the source was unencrypted |
| Certificate / custom handlers | Out | |

Never execute PDF JavaScript. Never follow `/Launch` automatically.

### 3.4 Graphics and text (ISO 32000-1 §8–9)

Content-stream interpreter produces a **display list** (device-independent
ops), not a Flutter Scene.

**Must interpret (P6.2):**

- Graphics state: `q`/`Q`, `cm`, `w`, `J`, `j`, `M`, `d`, `ri`, `i`, `gs`
- Path construction + painting: `m`, `l`, `c`, `v`, `y`, `h`, `re`, `S`, `s`, `f`, `f*`, `F`, `B`, `B*`, `b`, `b*`, `n`
- Clipping: `W`, `W*`
- Color: `g`/`G`, `rg`/`RG`, `k`/`K`, `cs`/`CS`, `sc`/`SC`/`scn`/`SCN`
- Color spaces: `/DeviceGray`, `/DeviceRGB`, `/DeviceCMYK` (ICC-less CMY→RGB), `/ICCBased` (use `/N` as Gray/RGB/CMYK; **no** ICC apply)
- XObjects: `/Image` (JPEG, Flate+Predictor RGB/Gray, `/SMask`), `/Form` (nested content)
- Text: `BT`/`ET`, `Tm`, `Td`, `TD`, `T*`, `Tc`, `Tw`, `Tz`, `TL`, `Tr`, `Ts`, `Tf`, `Tj`, `TJ`, `'`, `"`
- External graphics state from `/ExtGState` (line params, `ca`/`CA`, `BM` subset: Normal, Multiply, Screen)
- Inline images (`BI`…`EI`) for small images

**Should interpret (P6.4–P6.5):**

- Soft masks (`/SMask`) on Flate RGB/Gray (landed in-engine) and JPEG+DCT SMask via `softMaskJpeg` host compose (landed). Transparency groups: honor nested Form only
- Shadings (`sh`) Type 2 axial + Type 3 radial strips (landed). Type 1/2/3 patterns stay unsupported
- Type 3 fonts (bitmap `CharProcs`, landed)
- Optional content (`/OCProperties`, `BDC`/`EMC` with `/OC`) — `PdfFile.setLayerVisible` / editor toggle (landed)

**Typed unsupported (paint placeholder or skip, never invent geometry):**

- 3D / RichMedia / Sound / Movie
- Reference XObjects (`/Ref`)
- PostScript XObjects

### 3.5 Fonts (ISO 32000-1 §9)

| Kind | Wave | Role |
| --- | --- | --- |
| Type 0 / CIDFont Type 2 + `/FontFile2` (glyf) | P6.2 | Primary; reuse `SfntParser` / `OfficeFontSet` |
| Simple TrueType + WinAnsi / MacRoman / PDFDocEncoding | P6.2 | |
| `/ToUnicode` CMap | P6.2 | Extract, find, copy, search |
| `/ActualText` (marked content) | P6.3 | Landed: overrides extract/copy; glyphs still paint |
| CIDFont Type 0 + `/FontFile3` (CFF/OTF) | P6.4 | Raw CFF wrapped as OTTO for the host (`PdfCffHost`). Engine does not rasterize CFF |
| Type 1 / MMType1 + `/FontFile` | P6.4 | PFB stays host-unsupported (no wrap) |
| Type 3 | P6.5 | |
| Standard 14 (Times, Helvetica, Courier, Symbol, ZapfDingbats) | P6.2 | Metric tables shipped as data in-engine (no Flutter) |

Missing glyph → `.notdef` / tofu in the display list, never a thrown error
during paint.

### 3.6 Document structure and navigation

| Feature | Spec | Wave | Viewer | Editor |
| --- | --- | --- | --- | --- |
| Page tree + inherited `/Resources`, `/MediaBox`, `/Rotate` | §7.7.3 | P6.2 | Yes | Yes |
| Boxes: Media, Crop, Bleed, Trim, Art | §14.11.2 | P6.2 | Crop for paint; others queryable | Same |
| Page labels (`/PageLabels`) | §12.4.2 | P6.3 | Status / outline | Yes |
| Outlines (`/Outlines`) | §12.3.3 | P6.2 | Jump | Edit titles/targets in P6.5 |
| Named destinations | §12.3.2.3 | P6.2 | Resolve GoTo | Yes |
| Viewer preferences | §12.2 | P6.3 | `PdfFile.viewerPrefs` (direction, fit, hide chrome) | Honor |
| Document info + XMP | §14.3 | P6.1 | Read | Edit Info/XMP in P6.5 |
| Tagged PDF / StructTreeRoot | §14.7, PDF/UA | P6.6 | Expose tree; paint uses it only for copy/read order | Do not strip on incremental save |
| Article threads, collections | — | Out / later | | |

### 3.7 Annotations (ISO 32000-1 §12.5)

Markup and navigation annotations are the **editor’s primary mutation
surface**. Content-stream rewriting is **not** a P6 goal.

| Subtype | Wave | Viewer | Editor |
| --- | --- | --- | --- |
| `/Link` (URI, GoTo, GoToR) | P6.2 | Hit + callback | Same + create/edit |
| `/Text` (sticky note) | P6.3 | Show icon + popup text | Create/edit/delete |
| `/FreeText` | P6.3 | Paint `/AP` or generate | Create/edit |
| `/Highlight`, `/Underline`, `/Squiggly`, `/StrikeOut` | P6.3 | Paint quad points | Create from text selection |
| `/Ink`, `/Square`, `/Circle`, `/Line`, `/Polygon`, `/PolyLine` | P6.3 | Paint | Create/edit |
| `/Stamp`, `/Caret`, `/Stamp` (custom appearance) | P6.4 | Paint `/AP` | Create |
| `/Caret`, `/FileAttachment`, `/Sound` | P6.5 / later | Icon | Optional |
| `/Widget` | P6.4 | See forms | See forms |
| `/Popup` | P6.3 | Owned by parent | Same |
| `/Watermark` (annotation or OCG) | P6.5 | Paint | Optional |
| `/PrinterMark`, `/TrapNet`, `/3D` | Out | | |

Every created annotation **must** have an appearance stream (`/AP /N`) we
generate, so Adobe/LibreOffice show the same ink. Incremental save must
preserve unknown annotation keys.

### 3.8 Interactive forms (ISO 32000-1 §12.7)

| Item | Wave | Notes |
| --- | --- | --- |
| AcroForm catalog, `/Fields` tree, `/NeedAppearances` | P6.4 | |
| `/Tx` (text, multiline, password, comb) | P6.4 | Custom IME on the PDF canvas — not `TextField` |
| `/Btn` (checkbox, radio, push) | P6.4 | |
| `/Ch` (combo, list) | P6.4 | Host chrome may draw the dropdown **outside** the page; the value is written to the field |
| `/Sig` | P6.6 | **Display** existing appearance; **verify** if we add a crypto helper; **create** signatures is a later opt-in |
| Calculate / validate / format JS | Never | Do not run JS. Optional host callback for “field changed” |
| XFA (`/XFA`) | Out | Deprecated; `PdfAcroForm.hasXfa` only — extract nothing |
| FDF / XFDF import-export | P6.5 | |

Filling a form is an editor feature. The viewer may show field appearances
and, in `selecting` mode, copy field values — it does not commit new values.

### 3.9 Conformance families (honest scope)

| Family | Spec | Stance |
| --- | --- | --- |
| **PDF/A-1b, A-2b, A-3b** | ISO 19005 | Writer already emits *oriented* extras. Reader: detect profile from XMP/OutputIntent; **do not claim certification**. Incremental save of a PDF/A file must not strip OutputIntent/XMP; adding annotations may make the file fail a validator — document that. |
| **PDF/A-2u / A-3u** | Unicode mapped text | Follows ToUnicode work in P6.2 |
| **PDF/UA-1** | ISO 14289 | P6.6: read structure, expose reading order; no full authoring suite |
| **PDF/X** | ISO 15930 | Out of core (print prepress). Boxes and OutputIntent remain readable |
| **PDF/E, PDF/VT** | — | Out |
| **PAdES / ISO 32000 signatures** | ETSI | P6.6 verify; create later |

---

## 4. What already exists (do not break)

| Existing | Keep doing |
| --- | --- |
| `PdfDocument` + `PdfPage` + `PdfCanvas` | OOXML → PDF 1.7 compile |
| `OfficePdfExport` | Word / sheet / slide / notes pages |
| `PdfReportBuilder` | Direct PDF reports |
| `PdfSaveOptions` (`pdfA`, `tagged`) | Writer-only flags |
| `OfficeFontSet`, glyf subset, `/SMask` on export | Shared **font/image primitives** may be *called* from the reader; types stay in `src/fonts` and `src/pdf` writer files |
| Flate codec | Shared |

**Forbidden:** renaming writer types, routing Office export through `PdfFile`,
or putting parse state on `PdfDocument`.

### 4.1 Naming

| Name | Package | Meaning |
| --- | --- | --- |
| `PdfDocument` | engine (existing) | Compiler / in-memory write job |
| `PdfFile` | engine (new) | Opened PDF (COS + page tree + annots + forms) |
| `PdfOpenPayload` | engine (new) | Isolate result: file + display lists |
| `PdfDisplayList` | engine (new) | Per-page paint ops + text + links |
| `PdfViewerController` | editor (new) | Load, zoom, selection, find, follow link |
| `PdfEditorController` | editor (new) | Extends viewer + mutations + save |
| `QudsPdfViewer` | editor (new) | Embeddable view/select surface |
| `QudsPdfEditor` | editor (new) | Embeddable edit surface |
| `RenderPdfCanvas` | editor (new) | Shared `RenderBox` |

Optional library (keeps the default engine export lean until P6.2 is solid):

```dart
import 'package:quds_office_engine/pdf_file.dart';
```

Promote selected types onto `quds_office_engine.dart` only when the public
surface is stable (end of P6.2).

---

## 5. Architecture

```text
Uint8List
    │
    ▼
PdfCosReader ── incremental xref ── PdfFile (COS graph)
    │
    ├── PdfSecurity.open(password?)
    ├── PdfPageTree
    ├── PdfOutline
    ├── PdfAnnotStore
    └── PdfAcroForm
    │
    ▼
PdfInterpreter ── PdfDisplayList[]   (pure Dart)
    │
    ├── OfficeTextExtractor / OfficeFind / OfficeTextStats
    ├── OfficePrint (range → replay list or pass-through bytes)
    └── isolate: OfficeIsolateOpen.pdf / OfficeIsolateSave.pdf
    │
    ▼
RenderPdfCanvas (Flutter, editor package only)
    ├── QudsPdfViewer   (viewing | selecting)
    └── QudsPdfEditor   (editing)  ── incremental save ── Uint8List
```

Host chrome (ribbons, outline pane, find pane, properties) stays in the host
or studio example — same rule as Word.

### 5.1 Engine package layout (new)

```text
packages/quds_office_engine/lib/
├── pdf_file.dart                         public open/save/display API
└── src/pdf/file/
    ├── cos/
    │   ├── pdf_cos.dart                  PdfCosNull, Bool, Int, Real, Name,
    │   │                                 String, HexString, Array, Dict, Ref
    │   ├── pdf_cos_reader.dart           tokenizer + parser
    │   ├── pdf_xref.dart                 table + stream + incremental
    │   ├── pdf_objstm.dart
    │   └── pdf_repair.dart               startxref scan, damaged xref
    ├── crypto/
    │   └── pdf_security.dart             standard handler
    ├── decode/
    │   └── pdf_filters.dart
    ├── model/
    │   ├── pdf_file.dart
    │   ├── pdf_page_tree.dart
    │   ├── pdf_resources.dart
    │   ├── pdf_annot.dart
    │   ├── pdf_form.dart
    │   └── pdf_outline.dart
    ├── interp/
    │   ├── pdf_interpreter.dart
    │   ├── pdf_display_list.dart
    │   └── pdf_font_load.dart
    ├── text/
    │   ├── pdf_tounicode.dart
    │   └── pdf_extract.dart
    └── io/
        ├── pdf_incremental_save.dart
        └── pdf_isolate.dart              hooks for OfficeIsolateOpen.pdf
```

Writer files (`src/pdf/pdf_document.dart`, `office_pdf_export.dart`, …)
**do not move**.

### 5.2 Editor package layout (new)

```text
packages/quds_office_editor/lib/src/
├── editor_pdf/
│   ├── render_pdf_canvas.dart            shared RenderBox
│   ├── paint_pdf_display_list.dart       Dart list → Canvas
│   └── pdf_annot_handles.dart
└── embed/
    ├── pdf_controller.dart               viewer + editor controllers
    └── (office_editors.dart exports QudsPdfViewer / QudsPdfEditor)
```

---

## 6. Engine functions (complete set)

All of these are in-scope for Phase 6. Waves assign **when**, not **whether**,
unless marked Later / Out.

### 6.1 Open and repair

- `PdfFile.open(Uint8List, {String? password})`
- `OfficeIsolateOpen.pdf` + progress stages: `xref`, `decrypt`, `pages`, `display`
- Detect linearized / incremental / hybrid xref
- Repair: scan last `startxref`, rebuild xref from `obj` markers when the
  table is truncated (same honesty as OOXML repair)
- Typed errors: `PdfOpenError.badHeader`, `.badXref`, `.encrypted`,
  `.wrongPassword`, `.unsupportedFilter`, `.unsupportedHandler`

### 6.2 Query

- Page count, per-page boxes, rotation, labels
- Outlines as a typed tree (`PdfOutlineNode`)
- Embedded files (`/EmbeddedFiles` name tree) — list + extract bytes (P6.5)
- Document Info + XMP (read P6.1; write P6.5)
- Permissions and encryption metadata (never log the password)

### 6.3 Display list

- `PdfFile.displayList(int pageIndex)` / `displayLists()`
- Ops: fill/stroke path, clip, text run (font id, matrix, glyphs, fill),
  image blit, form xobject instance, link/annot hotspot, optional-content mark
- Coordinates: PDF user space, origin bottom-left in the model; the editor
  flips Y once at paint time
- Rotation applied in the list builder so the viewer sees upright pages

### 6.4 Text

- Extract page / document text (`OfficeTextExtractor` gains `kind: pdf`)
- Reading order: structure tree if tagged, else display-list Y/X cluster
- Find / replace **in extractable text**: find is P6.2; **replace** of page
  content is **Out** (would rewrite streams). Replace of *annotation* /
  *form* values is in-scope
- `OfficeTextStats` for PDF (pages, words, characters)
- Copy: Unicode via ToUnicode / ActualText; selection ranges are
  `(page, runIndex, start, end)` — not `dynamic` maps

### 6.5 Navigation and actions

Resolve, do not execute unsafe actions:

| Action | Engine | Viewer |
| --- | --- | --- |
| `/GoTo` in-doc | Resolve page + dest | Jump + scroll |
| `/URI` | Return URI | `onFollowLink` |
| `/GoToR` | Return file + dest | Host opens |
| `/Named` | Resolve | Jump |
| `/Launch`, `/ImportData`, `/JavaScript`, `/SubmitForm` | Typed ignore / host | Never auto |

### 6.6 Print

- `OfficePrint` for PDF: page range, copies
- Default: replay display lists through the **existing writer** (new
  `OfficePdfExport.pdfFile`) so print looks like the viewer
- Optional pass-through of original bytes when the range is the full
  document and no annotation overlay is pending (P6.3+)

### 6.7 Save

| Mode | When | Behavior |
| --- | --- | --- |
| Incremental | Default after annotate/fill | Append new objects + xref; preserve original bytes and existing signatures as much as ISO allows |
| Full rewrite | Host opt-in / linearized request | New 1.7 file from COS graph; **drops** byte-identical signatures |
| No-op | Viewer | `saveBytes` is not on the viewer controller |

If permissions forbid modify/annotate, save fails with a typed error unless
the host passed `PdfSavePolicy.ownerOverride` after a successful owner
password.

### 6.8 Mutualisation with Office

- `OfficeFind.inPdf` / extract / stats / print follow existing Office helpers
- Do **not** invent a second BiDi stack: PDF paint uses the file’s glyph
  positions; extract uses Unicode. Shaping is only needed when the **editor**
  generates a FreeText / form appearance in a complex script (reuse
  `uax9_bidi` + Arabic shaping)

---

## 7. Viewer functions (complete set)

`QudsPdfViewer` + `PdfViewerController`.

Modes: `viewing` (pan/zoom/follow-link as host decides), `selecting` (text
selection + copy). No IME. No `saveBytes`.

| Function | Detail |
| --- | --- |
| Open | `fromBytes` / `loadBytesAsync` + password + isolate + progress |
| Pages | Stacked pages, side gutters, horizontal pan (same idea as Word landscape) |
| Zoom | Wheel + API; min/max like `VirtualViewport` |
| Fit | Width, page, actual size |
| Rotate view | View-only rotate without rewriting `/Rotate` |
| Navigation | Page number, outline jump, named dest, link hit-test |
| Selection | Glyph/run hit-test; multi-page drag; copy Unicode |
| Find | Highlight hits; next/prev; `OfficeFindOptions` (case, whole word) |
| Annot display | Paint `/AP` or engine fallback for markup we understand |
| Form display | Paint widget appearances; read-only |
| Layers | Toggle OCG when present (P6.5) |
| Night / theme | Recolor chrome only; page contents stay faithful unless host asks for a paper color |
| Print | Delegate to engine print |
| Errors | Undecoded image / font → placeholder box, not a gray ErrorWidget |
| Direction | Canvas chrome follows `OfficeSurfaceConfig.textDirection`; page content follows the file |

Host slots: `toolbarBuilder`, `statusBarBuilder`, optional outline/find
builders — same pattern as `QudsWordEditor`.

---

## 8. Editor functions (complete set)

`QudsPdfEditor` + `PdfEditorController` **extends** the viewer controller
(one canvas, one selection model).

### 8.1 In scope (Phase 6)

- All viewer functions
- Create / move / resize / delete markup annotations listed in §3.7
- Edit sticky-note contents and FreeText (custom IME)
- Highlight from a text selection (quad points from the display list)
- Ink with pressure-less polyline; optional stylus if Flutter delivers it
- Stamp from a small built-in set + host-provided image bytes
- Fill / reset AcroForm fields; regenerate `/AP`
- Insert / delete / rotate **pages** by rewriting the page tree (P6.5);
  incremental when possible
- Merge: append pages from another `PdfFile` (P6.5)
- Extract pages to a new `PdfFile` (P6.5)
- Undo / redo of editor mutations (command pipeline, like Word)
- Clipboard: copy text; paste text into FreeText / text fields only
- `saveBytes()` incremental by default
- Header-less “redact” later: **visual** redaction annotation in P6.5;
  true content-stream redaction (remove glyphs + images) is P6.6 and must
  be explicit (`PdfRedactMode.removeContent`)

### 8.2 Out of Phase 6 (do not pretend)

- Rewriting arbitrary body text as if it were Word (reflow, edit a paragraph
  in a magazine PDF)
- Creating a PDF from scratch inside the editor (hosts already have
  `PdfReportBuilder` / OOXML export)
- XFA
- Running SubmitForm / JS
- Full prepress (PDF/X color-managed print)
- 3D, video, sound playback
- OCR (no bitmap-to-text engine in-tree)

---

## 9. Public API sketch (normative names)

Names are binding. Signatures may grow with optional named args; do not
rename after P6.2 ships.

```dart
// engine: pdf_file.dart
final PdfFile file = PdfFile.open(bytes, password: password);
final PdfDisplayList list = file.displayList(0);
final PdfOpenPayload payload = await OfficeIsolateOpen.pdf(bytes);

final Uint8List saved = PdfIncrementalSave.write(
  originalBytes: bytes,
  file: file,
);

// editor
final viewer = PdfViewerController.fromBytes(bytes);
final editor = PdfEditorController.fromBytes(bytes);

QudsPdfViewer(controller: viewer);
QudsPdfEditor(controller: editor);
```

`PdfEditorController.saveBytes()` is the only PDF save on controllers.
`PdfViewerController` has `loadBytesAsync`, `find`, `copySelection`,
`goToPage`, `setScale` — no mutate/save.

---

## 10. Sub-phases (do not skip)

Each sub-phase ends with tests and an honest STANDARDS update.

### P6.1 — COS + security (engine only)

- Tokenizer, objects, xref table/stream, incremental, ObjStm
- Filters: Flate (+ predictor), ASCIIHex/85, RunLength, Crypt
- Standard handler Rev 2–4
- Info dictionary read
- Tests: official small fixtures + generated writer output **round-trip
  open** (our own `PdfDocument.save` bytes must open as `PdfFile`)

**Exit:** `PdfFile.open` on unencrypted writer output; encrypted sample with
password; typed error without.

### P6.2 — Display list + viewer

- Page tree, boxes, rotate, resources
- Interpreter subset in §3.4 “must”
- Fonts: glyf CID/TTF + Standard 14 + ToUnicode
- Images: JPEG, Flate RGB/Gray + SMask
- Links + outlines
- `QudsPdfViewer` + isolate open
- Extract / find / copy / stats
- Paint via `paint_pdf_display_list.dart`

**Exit:** studio can open a typical text+image PDF; select and copy; follow
URI; zoom/pan; our exported Word PDF is viewable.

### P6.3 — Markup editor + incremental save

- Annotation model + `/AP` generation
- `QudsPdfEditor`, undo/redo
- Highlight / notes / ink / shapes / FreeText
- Incremental save; reopen in engine + LibreOffice/Adobe smoke (manual)
- Permissions honored

**Exit:** annotate, save, reopen, appearances visible in a third-party viewer.

### P6.4 — AcroForm + CFF start

- Field tree, fill, appearances
- AES-256 open (if not finished in P6.1)
- CFF/`FontFile3` **or** a documented tofu policy if still incomplete —
  STANDARDS must say which

**Exit:** fill a standard IRS-style / government AcroForm sample; save;
values persist.

### P6.5 — Document surgery and richer graphics

- Insert/delete/rotate/extract/merge pages
- OCG layers, stamp, embedded files, XFDF
- LZW, more shadings; JBIG2/JPX placeholders become decoders or stay typed
- Outline edit, Info/XMP write

**Exit:** merge two files; toggle a layer; export XFDF.

### P6.6 — Conformance, redact, signatures

- Tagged-tree read + reading order
- PDF/A detection; incremental-save warnings
- Optional write encryption
- Signature **verify**; visual Sig field
- True redaction (content removal) behind an explicit API

**Exit:** STANDARDS updated; no silent PDF/A claim.

### P6.7 — Polish

- Studio PDF workspace (File / View / Annotate / Form)
- `OfficeStrings` entries (English + existing locale table)
- Pana/doc comments, README sections for engine + editor
- Performance: tile or list-cull offscreen pages; pool display-list ops

---

## 11. Tests and fixtures

- Golden display lists for a checked-in **general-purpose** fixture set
  (ISO 32000 examples, our writer output, one encrypted file, one form,
  one RTL/ToUnicode file). No customer documents.
- Round-trip: `OfficePdfExport.word` → `PdfFile.open` → extract contains
  known strings
- Incremental: annotate → save → open → annotation count and `/AP` present
- Permission matrix
- Repair: truncated xref
- Editor widget tests: open, select, copy, highlight, undo (mirrors
  `embed_test.dart` style)
- Never require network

---

## 12. Security

- Passwords only in memory; not logged; not written to COS extras
- No JS VM
- No automatic `/Launch` or remote GoToR
- Decode bombs: cap page count, stream size, nesting of Form XObjects,
  and image dimensions (typed `PdfOpenError.limit`)
- Viewer default: do not load embedded files until the host asks

---

## 13. Languages and writing directions

PDF stores **placed glyphs**. The viewer must:

- Paint them in the file’s visual order (no re-shaping of existing text)
- Map to Unicode with ToUnicode / ActualText for copy, find, and search
- Support mixed LTR/RTL documents (Arabic, Hebrew, Latin, CJK on one page)
- When **generating** appearances (FreeText, text fields), use the engine
  BiDi + Arabic shaping path and embed a covering glyf face
- Chrome / IME / outline pane follow `OfficeSurfaceConfig.textDirection`
  and `OfficeStrings` — same multilingual rule as Word

---

## 14. Studio and documentation (end of P6.7)

- New studio surface or File-type tab: Open PDF, outline, find, annotate
- Engine README: “Open PDF” section (English, no locale-specific sample
  prose)
- Editor README: `QudsPdfViewer` vs `QudsPdfEditor`
- STANDARDS.md: move “PDF import” from out-of-scope to the coverage table
  as each sub-phase lands

---

## 15. Acceptance (Phase 6 done)

Phase 6 is complete only when **all** of the following are true:

1. Engine opens ISO 32000-1 files (xref table + stream, incremental, ObjStm)
   with Standard encryption Rev 2–4 and documented Rev 5/6.
2. Viewer paints text, paths, JPEG/Flate images, links, outlines; select/copy/find work.
3. Editor markup + AcroForm fill + incremental save reopen correctly in-engine
   and in at least one third-party viewer (manual note in STANDARDS).
4. Page merge/extract/rotate exist and are tested.
5. Word / Excel / PowerPoint editors and `OfficePdfExport` have **no**
   required API breaks from this work.
6. Engine still has zero Flutter / `dart:ui` imports.
7. STANDARDS.md matches reality (including remaining CFF/JBIG2/signature
   limits).

---

## 16. Order reminder

```text
P6.1 COS + crypto
  → P6.2 display list + QudsPdfViewer
    → P6.3 annotations + QudsPdfEditor + incremental save
      → P6.4 AcroForm + deeper fonts
        → P6.5 page surgery + layers + XFDF
          → P6.6 PDF/A-UA honesty + redact + verify
            → P6.7 studio + README + perf
```

Do not start P6.3 before a host can embed `QudsPdfViewer` on real files.
Do not start content-stream editing — it is not in this program.
