# Quds Office Suite — Mission (Phases 1–5)

Canonical architecture and phase order for agents and contributors.
Wave work in [ROADMAP.md](ROADMAP.md) maps onto these phases; do not skip
phases, and do not leave `TODO` stubs or untyped/`dynamic` APIs.

## Packages

| Package | Role |
| --- | --- |
| `packages/quds_office_engine` | Pure Dart OOXML + PDF. **Never** import `dart:ui` or Flutter. |
| `packages/quds_office_editor` | Flutter editing surfaces via `RenderBox` / `LeafRenderObjectWidget` only. |

Editor prohibition: no `TextField`, `TextFormField`, `EditableText`,
`SelectableRegion`, `SingleChildScrollView`, `ListView`, or `InteractiveViewer`.

Prefer `Uint8List` views, index slicing, and object pooling over heap-heavy
DOM-style trees.

## Phase 1 — OPC & binary foundations

- ZIP/OPC package model, content types, relationships
- CFBF / OLE embedded parts where needed
- Agile encryption for OOXML packages (open/save with password)
- Repair helpers and isolate open/save

## Phase 2 — Word (WML)

- Document model: sections, paragraphs, runs, tables, lists, headers/footers
- Styles and numbering; fields subset; TOC/bookmarks/hyperlinks
- BiDi / Arabic shaping hooks; layout engine → laid-out pages
- Round-trip serialize/deserialize

## Phase 3 — Excel (SML) & PowerPoint (PML)

- Workbook sheets, shared strings, styles, formulas, charts/pictures subset
- Presentation slides, shapes, notes, masters/layouts subset, motion/Morph subset
- Shared DrawingML / visual helpers

## Phase 4 — PDF export & print fidelity

- Native PDF 1.7 writer (canvas, images, links, outlines)
- Word layout replay; Excel print geometry; PPT slide/notes pages
- Glyf TTF subset embed; multi-face fallback via `OfficeFontSet`
- Optional `PdfSaveOptions` (PDF/A-oriented extras, tagged outlines)

## Phase 5 — Editor surfaces & polish

- Custom RenderBox editors for Word/sheet/slide
- Caret, selection, IME, and print/export hosting
- Optional modules (e.g. PPT media package IO) stay off the default engine export
- Keep [STANDARDS.md](STANDARDS.md) honest about limits

## Phase 6 — PDF file (open, view, annotate)

Specified in [PDF.md](PDF.md). Parallel to OOXML: a `PdfFile` model, isolate
open/save, `QudsPdfViewer`, and `QudsPdfEditor`. Does **not** replace Phase 4
export (`OfficePdfExport` / writer `PdfDocument`). Do not start until Phases
1–5 are treated as stable, and do not skip PDF sub-phases P6.1–P6.7.

## Waves vs phases

Post-audit delivery waves (1–4 in the roadmap) refine Phase 4 fidelity and
platform options; they do not replace Phases 1–3. Complete each wave’s tests
before starting the next. PDF work is Phase 6 / [PDF.md](PDF.md), not a
substitute for Waves 1–4.
