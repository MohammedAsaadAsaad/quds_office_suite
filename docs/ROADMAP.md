# Quds Office Suite — Roadmap (post Wave 4)

Waves 1–4 are implemented in-tree. Later work should keep [STANDARDS.md](STANDARDS.md)
and [MISSION.md](MISSION.md) honest as coverage changes.

## Wave 1 — PDF correctness (done)

- Print ranges, Excel geometry, outline bookmarks, notes links, list/TOC paint
- See [STANDARDS.md](STANDARDS.md)

## Wave 2 — Word depth (done)

- Fields: `HYPERLINK`, `FILENAME`, `FILESIZE`, `AUTHOR`, `TITLE`, `MERGEFIELD`
- Deeper `numbering.xml` (multi-level counters, restart, `%1`…`%9` labels)
- Richer `styles.xml` (`basedOn`, fonts, document.styles round-trip, table grid-like styles)
- Justified caret/selection regression coverage in the editor

## Wave 3 — Excel & PowerPoint print (done)

- Excel PDF: print titles / repeating rows, true cell borders vs gridlines, header/footer tokens
- Formula stubs: `HYPERLINK`, `ADDRESS`, `CELL`, `INFO`, `FIXED`/`DOLLAR`, limited `ASC`/`BAHTTEXT`
- Pivot/PowerQuery naming kept honest (simple SUM pivot; CSV helper only)
- PPT: stroke outlines, hyperlink URI annots, chart `rtl` write from `ChartDisplay` / sheet RTL

## Wave 4 — Platform (done)

- Multi-face glyf embed via `OfficeFontSet` / `OfficeFontResolver` (CFF/`FontFile3` deferred)
- Optional `PdfSaveOptions` (`pdfA`, `tagged`) — no PDF file-encryption API (OOXML crypto remains)
- Optional PPT media package IO: `package:quds_office_engine/quds_office_engine_optional.dart`
- Mission Phase 1–5 restored in [MISSION.md](MISSION.md)

## Wave 5+ — PDF file program

Phase 6 landed: `PdfFile`, `QudsPdfViewer`, `QudsPdfEditor`, incremental
save, AcroForm fill, XFDF, page surgery, CCITT, Standard-14 / WinAnsi,
CFF→OTTO host wrap, ActualText, ViewerPreferences, layer toggle, Type 2/3
`sh`, struct reading order, signature ByteRange status. Remaining limits
(in-engine CFF raster, JBIG2/JPX, CMS verify, certified PDF/A) are in
[STANDARDS.md](STANDARDS.md). Contract: [PDF.md](PDF.md).

Widget composer follow-ups that landed after 0.3.1:

- `MultiPage` splits [Table] across pages and repeats `repeat` header rows;
  vertical columns flow as separate children so a nested table can span.
- `BoxDecoration.gradient` (`LinearGradient`) paints as color strips.
- `Chart` draws value labels, a y-axis guide, and a legend (bar / line / pie).

Still out of the widget composer (do not pretend): PDF axial shading objects,
package:pdf chart dataset API, barcode/svg, and MultiPage span inside a
single `Expanded` row.

- P6.1 COS + Standard encryption
- P6.2 Display list + `QudsPdfViewer`
- P6.3 Markup + incremental save + `QudsPdfEditor`
- P6.4 AcroForm + deeper fonts
- P6.5 Page surgery, OCG, XFDF
- P6.6 PDF/A–UA honesty, redact, signature verify
- P6.7 Studio + README + performance

Do not skip sub-phases. Do not route OOXML export through `PdfFile`.

## Architecture reminder

- `quds_office_engine` — pure Dart, no `dart:ui`
- `quds_office_editor` — Flutter `RenderBox` / `LeafRenderObjectWidget` only
- No `TODO` stubs; no `dynamic`; general-purpose fixtures only in tests
