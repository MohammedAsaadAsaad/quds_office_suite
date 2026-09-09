# Changelog

All notable changes to `quds_office_engine` are documented here.

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
