# Quds Office Suite — Standards coverage

This document states what the packages implement relative to common
**ISO/IEC 29500 (Office Open XML)** and **PDF 1.7** expectations. It is a
**general-purpose library** contract — not a fidelity claim against any single
vendor product.

See also [MISSION.md](MISSION.md) (Phases 1–6), [ROADMAP.md](ROADMAP.md),
and the PDF-as-a-file program in [PDF.md](PDF.md).

## Supported (engine)

| Area | Coverage |
| --- | --- |
| OPC packages | DOCX / XLSX / PPTX open + save, repair, Agile passwords, isolates |
| Word | Sections, paras/runs, tables, lists (multilevel numbering subset), headers/footers, styles (`basedOn`/fonts), comments, TOC, hyperlinks, fields (PAGE/NUMPAGES/DATE/TIME/REF/SEQ/TOC/CITATION/INDEX/HYPERLINK/FILENAME/FILESIZE/AUTHOR/TITLE/MERGEFIELD), footnotes/endnotes, OMML, BiDi/RTL, layout → PDF |
| Excel | Sheets, shared strings, styles, formulas (broad catalog), merges, freeze, RTL, charts/pictures, named ranges/tables, shallow CF/validation, **simple SUM pivot** (not Power Pivot), **CSV import helper** (not full Power Query), print area/titles/header-footer model, cell borders vs gridlines in PDF |
| PowerPoint | Slides, shapes (limited presets + stroke), tables, images/charts (RTL chart write), notes, masters/layouts (subset), transitions/animations including Morph + reverse show, shape hyperlink URIs in PDF |
| PDF 1.7 export | Word layout replay, Excel geometry-aware grid + print titles/HF, PPT slides/notes/master shapes/strokes/URI annots, TTF/`glyf` subset (multi-face via `OfficeFontSet`), PNG/JPEG, Word TOC/URI links, `/Outlines` bookmarks. Widget composer: `pdf_widgets.dart` (flex/text/table/chart → `PdfCanvas`; not a Word DSL) |
| PDF file (`PdfFile`) | Open ISO 32000-1 (xref table/stream, incremental, ObjStm). Standard security Rev 2–4; Rev 5/6 attempted. Display list: paths (`m`/`l`/`c`/`v`/`y`/`re` through CTM), `S`/`s`/`f`/`B`/`b`/`b*` (fill+stroke keeps the path), `W`/`W*` clip + `q`/`Q`, `J`/`j`/`M`/`d` stroke style, DeviceRGB/Gray/CMYK (ICC-less), `/ICCBased` via `/N` only, `gs` (LW/LC/LJ/ML/D/ca/CA/`BM` Normal·Multiply·Screen), JPEG/Flate/LZW/CCITT (G3 1-D + G4) images, ImageMask stencil, Indexed palette, Form XObjects (`Matrix` + `BBox` clip), inline `BI`/`EI`, Type 3 `CharProcs`, `sh` Type 2 axial + Type 3 radial, OCG `BDC`/`EMC` + `setLayerVisible`, `Tj`/`TJ`/`Tr` + ToUnicode + WinAnsi/MacRoman/PDFDoc + `/ActualText`. Annotate + `/AP`, AcroForm fill, `/XFA` flag (no extract), XFDF, ViewerPreferences, page insert/delete/rotate/merge/extract, incremental save. `PdfToolbox` writes a **new** file and grafts each page dict plus Contents and inherited Resources (fonts/images survive extract/merge). `/Rotate` is a clockwise 90° turn and does not rewrite MediaBox. Stamp, page numbers, and Bates are a Helvetica overlay stream (`/ca` opacity) — not an embedded face and not Arabic shaping. Crop changes CropBox only. `appendPages` / `mergeFrom` rebuild via `PdfPageGraft` so fonts and images survive; `PdfToolbox` remains the batch assembler. Viewer/editor in `quds_office_editor` |
| PDF options | Optional PDF/A-2b-oriented catalog extras (`PdfSaveOptions.pdfA`: XMP, OutputIntent, MarkInfo); optional tagged structure from outlines (`tagged`). Reader **detects** PDF/A from XMP (`pdfAProfile`) and warns that incremental markup may fail a validator. Not certified |
| PDF structure / Sig | `/StructTreeRoot` is exposed as `PdfFile.structTree` (read). `PdfExtract.readingOrder` walks Alt/ActualText. `/Sig` fields: `ByteRange` coverage, then CMS `SignedData` `messageDigest` match → `valid` / `invalid` / `unverified` / `broken` / `unsupported`. RSA/ECDSA and a system trust list are **not** applied. Creating signatures is out |
| Fonts | Writer: glyf TrueType embed + subset; multi-face fallback. Reader: `/FontFile2` glyf metrics when `SfntFont` parses; `/Widths`/`W`/`DW`; Standard 14 AFM widths (Helvetica, Times, Courier, Symbol, ZapfDingbats). Raw `/FontFile3` CFF is **wrapped as OTTO** (`PdfCffHost`) so the Flutter host can load it — the engine does **not** rasterize CFF outlines. OpenType `GPOS` LookupType 4 MarkToBase (and type-9 wrappers) positions Arabic tashkeel; other GPOS/GSUB lookups are ignored |
| Image filters | Flate (+ predictor), ASCIIHex/85, RunLength, LZW, DCT (JPEG passthrough), CCITTFaxDecode G3 1-D and G4 (mixed G3 2-D `K>0` is 1-D best-effort). `/SMask` on DeviceGray/RGB Flate is composed to RGBA in-engine; JPEG+/SMask DCT attaches `softMaskJpeg` for host compose. **JBIG2** MMR generic regions decode (size-capped); arithmetic / symbol / text regions stay `PdfFilterUnsupported`. **JPX stays** unsupported (placeholder on that XObject) |
| Band reports (`.qrep`) | `quds_reports.dart`: `.qrep` is a ZIP package (`layout.xml` + embedded PNG/JPEG `images/` + embedded TrueType `fonts/` with regular and bold faces only, legacy plain XML accepted, 64 MB per entry) via `ReportPackage`; embedded fonts must be single `.ttf` files with `glyf` outlines whose `OS/2 fsType` allows embedding (`.ttc` collections and CFF `.otf` are refused, italic faces are not embedded); XML parse/validate/write with line:column diagnostics; `QudsExpressionEngine` (`System.*` / `Variables.*` / `Data.*` paths, arithmetic, comparisons, `SUM`/`COUNT`/`AVG`/`MIN`/`MAX`, Arabic `TAFQEET(amount, code)` for regional currencies, English or Arabic `AMOUNTWORDS(amount, code, lang)`, `words:` and Gregorian `dateAr:` formats); bands ReportHeader → PageHeader → GroupHeader → Detail → GroupFooter → PageFooter → ReportSummary with grouping, sorting, filters, `visibleWhen`; `canGrow` text, page breaks (a free-form detail row honors `newPageBefore` / `newPageAfter`), repeating table headers, `System.TotalPages`; UAX #9 BiDi + Arabic shaping + GPOS marks; RTL mirroring of element x (`mirrorRtl`). Exports: PDF (glyf subset, vector Code128 / QR), XLSX (typed cells, `readingOrder` for RTL), DOCX (live `PAGE`/`NUMPAGES`, repeating table header). `ReportMockData.infer` builds preview data from a template's bindings. Charts (`<Chart>`: bar, horizontal bar, stacked bar, 100% stacked bar, line, area, stacked area, pie, donut, combo, waterfall, gauge, bullet, funnel, scatter, bubble, radar, heatmap, sparkline, extruded bar, extruded pie, extruded donut) aggregate a dataset by category (`sum`/`avg`/`count`/`min`/`max`/`first`/`last`, sort, top N) or plot static points; PDF draws them as vectors, DOCX and XLSX get native DrawingML charts. 18 ready-made templates ship as `.qrep` files in `quds_office_editor/templates/` (each with a `template.json` `ReportTemplateManifest`; read by `ReportTemplateInfo.decode` and `ReportTemplateLibrary`): nine categorized families (VAT invoice, commercial invoice, product catalog, account statement, receipt voucher, inventory, sales dashboard, certificate, class certificates), each in an Arabic RTL and an English version. A free-form detail band's `newPageBefore` / `newPageAfter` starts a new page per row. Most carry pre-saved PNG images (logo, stamp, signature, seal, product photos) originally drawn procedurally by `ReportTemplateArt`; these are illustrations, not photographs. The code catalog `ReportTemplates` is deprecated until 2.0. `<DataSchema>` declares typed fields and tables with calculated columns (applied by `prepare()` before every export); packages may carry design-time `data/sample.json`; `ReportData` / `ReportCsv` build host data; elements carry unique names and `QudsReportEngine` fills them by name (`setText`, `setImage`, `setBarcode`, `setTableRows`, `setChartRows`, `setChartPoints`, `setVisible`). Designer in `quds_office_editor` (`QudsReportDesigner`) with a data explorer (`ReportDataExplorer`) |
| Optional media | PPT `/ppt/media/` sync/hydrate via `quds_office_engine_optional.dart` (not on default export) |

## Explicitly limited / out of scope (short term)

- Legacy binary `.doc` / `.xls` / `.ppt`, VBA/macros, ActiveX
- Full Word field zoo, full theme/style matrix, real DrawingML SmartArt (`dgm:`)
- Full Excel LAMBDA / Power Pivot / rich pivot / Power Query beyond CSV helper
- PPTX audio/video as a default core feature (optional media helper only)
- PDF **content-stream reflow** (edit body text like Word) — out of [PDF.md](PDF.md)
- OCR, image recompress, and PDF-to-Office layout recovery (not implemented)
- PKCS#7 public-key encryption; **creating** digital signatures; CMS verify is digest-only (no RSA/ECDSA, no system roots)
- In-engine CFF / Type 1 glyph raster (host OTTO wrap only); raw Type 1 `/FontFile` PFB; JBIG2 arithmetic/symbol/text regions; JPEG2000; ICC profile apply ( `/N` fallback only); Type 1/2/3 patterns; shadings other than Type 2/3 strips
- True sanitizing redaction of every operator in a content stream (overlay + extract filter only)
- Full PDF encryption of the **written** OOXML-export file; certified PDF/A or PDF/UA authoring
- Third-party viewer smoke of incremental `/AP` is manual (Adobe / LibreOffice)
- Band reports:
  - Report fonts must be TrueType `glyf` faces (CFF/OTF is rejected because it cannot be subset). Without a registered face, Latin falls back to Helvetica and other scripts are not drawn.
  - Data schema:
    - Calculated columns are row-level. A formula sees the row's own columns, including calculated columns declared before it, plus `Data.*`, `Variables.*`, and aggregates over whole data sets. A formula that fails prints null, or throws when `strict`.
    - Only the types `text`, `number`, `boolean`, and `date` exist. A value that cannot be coerced stays as given. Nested tables inside rows are not part of the schema.
    - `ReportCsv` reads the whole text in memory. The data explorer is meant for design-time sample data, not for large data sets.
    - Sample data lives in the package for designing and previewing. Exports use only the data the host passes or sets.
  - Translucent colors (`#AARRGGBB` with partial alpha) are painted opaque in PDF.
  - When a block does not fit on a page, text splits by line and rectangles split. Images, barcodes, ellipses, and lines move whole; one taller than an empty page overflows the bottom margin.
  - QR covers versions 1–10 at ECC-M (byte mode). Code128 covers printable ASCII only.
  - XLSX export is data-oriented. It omits page header/footer bands, images, barcodes, and shapes (charts are exported).
  - DOCX export omits barcodes and every shape except horizontal lines (written as paragraph rules). Header/footer bands carry text, rules, and images only.
  - In XLSX and DOCX, transparent text sitting on a filled shape takes that shape's fill as a cell fill or paragraph shading. The shape's outline, corner radius, and any area outside the text are not reproduced.
  - Charts:
    - Native DOCX/XLSX charts carry literal values (`c:numLit`/`c:strLit`), not references to worksheet cells. XLSX also writes the chart's data as a table under the chart.
    - PDF and preview arcs are flattened to polylines (at most 3° per segment). The area fill is an opaque tint of the series color.
    - Extruded charts are an oblique drawing (front, top, and side) in PDF and preview. Word and Excel receive `bar3DChart` / `pie3DChart` with `view3D`. Scatter and bubble export as native XY charts. Gauge becomes a donut. Waterfall, bullet, funnel, heatmap, and sparkline print as vectors; Word and Excel get the nearest bar or line chart.
    - Shape maps color closed regions (the bundled Natural Earth 1:110m country atlas, or a shapefile / GeoJSON imported into `shapes/<name>.qmap`) by a category key. PDF and preview draw the polygons, a value legend, and labels on wide regions. Word and Excel get a bar chart of the region values. The atlas matches ISO alpha-2, alpha-3, and English, Arabic, and French country names.
    - Charts move whole across page breaks. A chart taller than an empty page overflows the bottom margin.
    - DOCX header/footer bands omit charts.
    - A chart bound to the same dataset as a sorted Detail band sees the rows in the Detail sort order.
  - The designer canvas is schematic: it shows template text with `{{…}}` bindings and one table body row. Data-bound charts on the canvas plot sample values over sample categories. The live preview, which uses the engine layout and mock or host data, is the exact output.
- ODF: text extract only
- Some formula names remain **aliases or documented stubs** (see `FormulaGuide`); unknown names return `#NAME?`

## Design rules

- No document-specific or customer-specific code paths in the library.
- Layout heuristics (e.g. clearing header pictures) use OOXML margins and
  visual sizes only.
- Missing Excel formula names return `#NAME?` rather than silent wrong answers
  (except a few documented aliases / stubs).
