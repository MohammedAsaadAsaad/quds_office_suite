# Changelog

All notable changes to `quds_office_engine` are documented here.

## 0.4.0

PDF is a file you can assemble, not only a file you can open or export.

- `PdfToolbox` grafts a new PDF 1.7 so fonts and images survive merge, extract,
  split, reorder, remove, reverse, insert, and mix. Range groups are
  1-based (`1-3`, `8-10`, `15`). One source may contribute several groups.
- `/Rotate` is a clockwise quarter-turn added to the existing value. It does
  not rewrite MediaBox. `PdfPageView` maps view space to unrotated crop space.
- Appearance overlays: Helvetica stamp, page numbers, Bates, and CropBox crop.
  Stamp is Latin only. A shaped watermark belongs on `pdf_widgets`.
- `pdf_widgets` watermark is one rotated string (ActualText + visual-order
  glyphs) so Arabic stays joined.
- Office slide export can stack two slides on one page (`slidesPerPage: 2`).
  The default remains one slide per page.
- `ArabicShaper.nominal` maps presentation forms back to isolated letters.
- Package documentation covers the full public surface, including honest
  limits (no OCR, no CMS verify, no certified PDF/A, no content-stream reflow).

## 0.3.1

- Keep `pdf_widgets` on its own library import
  (`package:quds_office_engine/pdf_widgets.dart`) so Flutter hosts do not see
  colliding `Text` / `TextStyle` / `Widget` names from the main barrel.

## 0.3.0

**Office + PDF in one pure-Dart engine.** This release makes PDF a first-class
citizen alongside DOCX / XLSX / PPTX — open, compose, and export without Flutter.

### PDF as a file (`PdfFile`)
- Open ISO 32000 packages: xref table/stream, object streams, incremental
  updates, filters (including CCITT G3/G4), encryption/password paths.
- Display list for page paint (`b`/`b*`, graphics state, Type 3, axial/radial
  shadings, OCG, SMask→RGBA, CMYK/ICCBased images).
- Text extract (WinAnsi / MacRoman / PDFDoc, Standard-14, `/ActualText`,
  `/StructTreeRoot` reading order).
- Typed honesty for signatures (`ByteRange` status), PDF/A detection (not
  certification), and unsupported codecs (JBIG2/JPX, in-engine CFF raster).

### PDF widgets (`pdf_widgets.dart`)
- Flutter-like constraint layout in pure Dart: `Document`, `Page` /
  `MultiPage`, `Table` / `TableBorder` / column widths, flex, text, media.
- Real bold faces via `Document.fontBold` (Type0 `/F3`), not faux stroke.
- Table cells expand to full width×row height (package:pdf-style fills).
- Synchronous `Document.save()` → native `PdfDocument` writer bytes.

### Office (unchanged strengths)
- Round-trip DOCX / XLSX / PPTX, formulas, BiDi/RTL, isolate open/save.
- `OfficePdfExport` still compiles Word / Excel / PowerPoint to PDF 1.7.

### Breaking
- Word widget DSL (`word_widgets.dart`) removed — use `DocxDocumentBuilder` /
  `WmlDocument` for OOXML; use `pdf_widgets.dart` for PDF composition.

## 0.2.0

Word widget DSL, independent landscape sections, find/print/stats helpers,
font sets, notes/fields/styles, and richer PDF embedding. English-only
package documentation; multilingual and multi-direction text remain first-class.

## 0.1.0

First public release.

### Word
- Open, edit, and write `.docx` (WordprocessingML) with sections, headers, footers, tables, comments, hyperlinks, bookmarks, and TOC.
- OMML math gallery, linear input, and layout.
- Print-faithful pagination used by PDF export.

### Excel
- Open and write `.xlsx` (SpreadsheetML) with styles, shared strings, freeze panes, RTL sheets, and charts.
- Formula engine with Excel-style functions (`SUM`, `IF`, `VLOOKUP`, `INDEX`/`MATCH`, dates, text, stats, …).
- Dependency graph and isolate-friendly recalculation.

### PowerPoint
- Open and write `.pptx` (PresentationML) with DrawingML shapes, tables, notes, hidden slides.
- Click-driven animations and slide transitions, including Morph.
- Slideshow clock that can play a transition or animation **forward or in reverse**.

### Platform
- Pure Dart: no Flutter, no `dart:ui`.
- Own OPC/ZIP, CFBF/OLE, Deflate, and XML stack.
- Password-aware open, repair of damaged packages, isolate open/save for large files.
- Native PDF 1.7 export for Word, Excel, and PowerPoint (fonts, images, links, notes pages).
- Fluent builders: `DocxDocumentBuilder`, `XlsxWorkbookBuilder`, `PptxDeckBuilder`, `PdfReportBuilder`.
- Widget-style Word DSL (`word_widgets.dart`) with independent portrait / landscape sections.
- `OfficeTextExtractor` for DOCX / XLSX / PPTX / ODF.
- Find / replace, print ranges, text statistics, and document properties.
- UAX #9 BiDi, Arabic shaping, grapheme-aware line breaking, and mixed writing directions.
