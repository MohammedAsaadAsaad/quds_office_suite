# Changelog

All notable changes to `quds_office_engine` are documented here.

## Unreleased

**`.qrep` packages.**

- A `.qrep` file is now a ZIP holding `layout.xml` (the `<QudsReport>` template) and pre-saved images under `images/<name>.png|jpg`.
  - A stored `mimetype` entry (`application/vnd.quds.qrep+zip`) comes first.
- `ReportPackage`:
  - `encode()` and `ReportPackage.decode(bytes)`; `decode` also opens legacy plain-XML `.qrep` files.
  - `keyFor(fileName)` derives unique image keys; `isValidKey` checks a name.
  - PNG / JPEG only (`ReportImageFormat.sniff`); each entry is capped at 64 MB.
  - Errors raise `ReportPackageException`.
- `QudsReportEngine.fromPackage(bytes, {images})` uses the embedded images; host `images:` win on name clashes. `engine.toPackage()` writes a package.

**Embedded fonts in `.qrep` packages.**

- Packages carry TrueType families under `fonts/<family>/regular.ttf|bold.ttf`, so a report exports with the faces it was designed with.
- `ReportPackage.fonts` (`Map<String, ReportFontFiles>`), `fontRegistry({base})`, `mergeFonts(base, embedded)` and `isValidFontFamily`.
  - Host families come first and win on name clashes; the host registry is not modified.
  - Every font is checked when it is written or read.
- `QudsReportEngine.fromPackage` registers the embedded fonts; `embeddedFonts` keeps them so `toPackage()` writes them back.
- `ReportFontFile.inspect(bytes)` / `inspectWith(read)` return `ReportFontFileInfo` (family, weight, italic) from the `name`, `OS/2` and `head` tables without parsing glyphs.
  - They throw `ReportFontException` for `.ttc` collections, CFF (`.otf`) outlines, missing tables, and fonts whose `fsType` forbids embedding.

**Report data schema and sample data.**

- `<DataSchema>` in the layout declares fields and tables with typed columns (`text`, `number`, `boolean`, `date`). This is `ReportTemplate.dataSchema` (`ReportDataSchema`, `ReportDataTable`, `ReportDataColumn`, `ReportDataField`).
  - Calculated columns (`expression="qty * price"`) are evaluated for every row at export; bare names refer to the row's columns.
  - Exports coerce values to the declared types. `engine.prepare(data)` returns the record the layout sees.
  - The parser warns about unknown types, duplicates, missing names, and broken formulas.
- Packages can carry design-time sample data as `data/sample.json` (`ReportPackage.sampleData`, `engine.sampleData`). Exports only use it when the host passes it.
- `ReportData`: dotted-path `get` / `set` / `remove` / `setTable` / `addRow` / `rows`, deep `merge`, and JSON round-trip with ISO dates. `ReportDataType` handles inference and coercion.
- `ReportCsv.parse` / `rows` / `write`: delimiter detection (`,` `;` tab), quotes, BOM, and typed columns.

**Named elements and runtime data.**

- Templates keep element names unique: `uniqueElementName`, `assignElementNames`, `elementNamed` (case-insensitive), `duplicateElementNames`, `isValidElementName`.
- `QudsReportEngine`:
  - Host data: the `data` constructor parameter (`ReportData`) is merged under the map passed to each export.
  - `export(format, {data})` / `exportSync`. `ReportExportFormat` moved here from the editor.
  - Element access by name: `elementNames`, `element`, `elementAs<T>`.
  - Setters by name: `setText` (with `literal`), `setImage`, `setBarcode`, `setTableRows`, `setChartRows`, `setChartPoints`, `setVisible`.
  - An unknown name or wrong type throws `ReportElementException`.

**Bilingual, categorized templates with saved images.**

- `ReportTemplates.all` now has 16 templates: eight families, each with an Arabic (RTL) and an English version.
  - New families: product catalog (a photo per row) and certificate of appreciation.
  - New English versions of the VAT invoice, account statement, receipt voucher and inventory report, and an Arabic version of the commercial invoice and the sales dashboard.
  - Existing ids are unchanged.
- `ReportTemplateInfo` gains `family`, `language` (`ReportTemplateLanguage`), `familyTitle` / `familyTitleAr`, `strings`, `images()` and `package()`.
  - Both versions share one layout with `[[key]]` tokens filled from per-language strings.
- `ReportTemplates.families`, `variants`, `find`, `counterpart` and `inCategory`.
- `ReportTemplateCategory` gains `hr` (Human resources) and bilingual `title` / `titleAr` / `titleFor`.
- Templates carry pre-saved PNG images (logo, stamp, signature, seal, product photos) in their package.
  - The images are drawn by the new `ReportTemplateArt` (`logo`, `stamp`, `signature`, `seal`, `product(ReportProductArt)`), an anti-aliased pure-Dart rasterizer.
- `AMOUNTWORDS(amount, 'USD', 'en'|'ar')` and the `words:USD` format spell amounts in English (`EnglishWords`, 21 currencies).
- The `dateAr:` format uses Arabic month and day names (`10 أكتوبر 2026`).

**Fixes.**

- Elements that share a top edge now paint in document order. Before, an unstable sort could draw a filled shape over the text placed on it (for example, the receipt voucher amount).
- Raw deflate now emits overlapping matches and caps hash-chain walks, so long runs (for example, transparent PNG rows) compress fast and much smaller.

**Docs.**

- The README links to the Quds Report Studio installers for Windows and Linux, which design `.qrep` reports for this engine. The pub.dev screenshots include the studio and the new templates.

## 0.6.0

**Band report engine (`quds_reports.dart`).**

- `.qrep` templates:
  - `QudsReportXmlParser` gives line:column diagnostics.
  - `QudsReportXmlWriter` round-trips templates.
  - The mutable `ReportTemplate` model is built for designers.
- `QudsExpressionEngine`:
  - `System.*`, `Variables.*`, and `Data.*` paths; arithmetic, comparisons, and aggregates.
  - Formats such as `currency:LYD` and dates.
  - Arabic `TAFQEET(amount, code)` (`ArabicTafqeet`).
- Generator:
  - Report, page, and group headers/footers, detail bands, and repeating tables.
  - `canGrow` text, page splitting, and `System.TotalPages`.
  - BiDi, Arabic shaping, and RTL x mirroring (`mirrorRtl`).
- `QudsReportEngine.fromXml(xml)` exports with `exportToPdf`, `exportToExcel`, and `exportToWord`.
- `ReportMockData.infer` builds preview data from a template's bindings.
- Charts (`<Chart>` / `ReportChartElement`):
  - Types: bar, horizontal bar, stacked bar, line, area, pie, donut.
  - Data: a dataset grouped by a category expression with `sum`/`avg`/`count`/`min`/`max`/`first`/`last`, sorting, and top N; or static `<Point>` values.
  - PDF and preview draw vectors (`ReportPathPrimitive`); RTL templates mirror the plot.
  - DOCX and XLSX embed native DrawingML charts; XLSX adds the data table.
- `ReportTemplates.all`: six ready-made templates with sample data (Arabic VAT invoice, English invoice, sales dashboard, account statement, inventory, receipt voucher).
- `ReportCompleter`: suggestions inside `{{ }}` and expressions: functions with signatures, `Data`/row fields from the preview data, `System`/`Group`/`Variables`, format specs after `|`, and currency codes in `TAFQEET`/`FORMAT`.
- Typed template variables (`<Var name type value format description/>`): `text` (may hold `{{ }}`), `number`, `boolean`, `date` (ISO, `today`, `now`), `list` (`;`-separated), and `expression`. Later variables can use earlier ones, host `variables:` still override, and the validator flags values that don't fit their type.
- `XlsxSheetBuilder.addChart` anchors a DrawingML chart part on a sheet.
- XLSX builder `style(rightToLeft:)` emits `readingOrder="2"`.
- `ReportCompleter.formats` exposes the format specs (with samples) that the designer offers as presets.
- XLSX and DOCX report exports: transparent text on a filled shape takes the shape's fill (white titles on a colored banner stay readable). XLSX chart placeholder rows get explicit heights, so the chart no longer overlaps its data table in LibreOffice.
- `tool/dump_report_shots.dart` renders every bundled template to PDF (and the sales dashboard to XLSX/DOCX through LibreOffice) for the README gallery.
- Limits are listed in `docs/STANDARDS.md`.

**PDF fidelity.** Five waves: OpenType marks, appearances, page graft, AcroForm write,
and a first slice of “files people send”.

- GPOS LookupType 4 (MarkToBase, including type-9 extensions). Combining
  marks use font anchors for `paintDx` / `paintDy`; the previous
  “center of advance” placement is the fallback.
- FreeText `/AP` (then Tx on fill) is a Form XObject through `LineBreaker`
  + Arabic shaping + a glyf Identity-H subset. Helvetica is not used for
  non-Latin text. `/NeedAppearances` stays if generation cannot embed a face.
- `PdfFile.appendPages` / `mergeFrom` rebuild via `PdfPageGraft`, so fonts
  and images survive. `PdfToolbox` remains the batch assembler.
- `pdf_widgets` `TextField` / `Checkbox` / `Radio` still draw marks. Pass
  `acroForm: true` (or use `ChoiceField`) to emit real `/Tx` `/Btn` `/Ch`
  fields on the writer `PdfDocument`.
- `/JBIG2Decode` decodes MMR generic regions (scanner dual-tone) with the
  same size cap as other filters. Arithmetic coding, symbol dictionaries,
  and JPX stay typed-unsupported placeholders.
- Signature fields: ByteRange coverage plus CMS `SignedData` `messageDigest`
  match (`valid` / `invalid`). Unknown digest algorithms are `unsupported`.
  Creating signatures and trusting a system root list are still out.

## 0.5.3

- High-value `pdf_widgets`: `PageNumber`, `HeaderFooter`, `SignatureLine`,
  `KeepTogether`, `Badge`, `Callout`, `Steps`, `DataGrid`, `Barcode` (Code128),
  `QrCode`, and `SvgImage` (path subset).
- Bilingual widget catalog via `pdf_widgets_samples.dart` /
  `example/pdf_widgets_catalog.dart`.
- Skip invisible BiDi marks (`LRE`/`PDF`/`LRM`/…) so `intl` dates do not
  paint as `.notdef` boxes.
- Reorder Arabic by grapheme cluster so tashkeel (ضمة on `أُنشئت`) stays
  on its letter after PDF export.

## 0.5.2

- Do not mid-cut Arabic chart axis labels (keeps joining forms intact).

## 0.5.1

- Soft-wrapped `Text` keeps the full max width so RTL `start` / `justify`
  paint on the start edge (headers, bullets, paragraphs).
- `TextAlign.justify` origins follow direction instead of always left.
- `Bullet` uses `TextAlign.start`. Chart titles follow direction; long axis
  labels are shortened to fit their slot.

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
