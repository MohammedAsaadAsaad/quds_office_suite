# Changelog

All notable changes to `quds_office_engine` are documented here.

## 0.5.0

**Report templates that look different, not only read different.**

- `pdf_templates.dart` ships **100+** classified report templates across
  commerce, finance, people, operations, narrative, data, education,
  property, logistics, and programs. Pick a named class
  (`InvoiceTemplate`, `PurchaseOrderTemplate`, …) and keep developing it.
- **`SheetSkin`** is the composition surface: invoice bar, receipt slip,
  letterhead, certificate frame, payslip split, checklist boxes, route
  endpoints, voucher, grades, identity panel, notice strip, journal,
  comparison columns, and more. Labels stay language. Direction stays
  layout. `TemplateTheme.copyWith` stays brand.
- `TemplateCatalog.all` / `inCategory` index every entry.
  `TemplateSuite.demo` writes a sample page. `joinTemplateFiles` joins
  English and Arabic into one PDF.
- `Table.fromTextArray` defaults to `AlignmentDirectional.topStart`, so
  Arabic table cells pin text to the start edge in RTL.
- `pdf_widgets` Flutter twins: `Transform`, clips, `FractionallySizedBox`,
  `IntrinsicHeight`, `CustomPaint`, `ListTile`, directional insets, and
  more. `TextOverflow.ellipsis` cuts a line.
- `OfficeColors.red` and other common names are `RRGGBB` strings for
  `OfficePalette` without touching Flutter `Colors`.

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
- Word widget DSL removed. Use `pdf_widgets` for PDF layout and
  `DocxDocumentBuilder` for DOCX.

## 0.2.0

- English package documentation, Word widget DSL (later removed), and
  PDF export polish.

## 0.1.0

- First public release: Office builders, models, formulas, BiDi, PDF export.
