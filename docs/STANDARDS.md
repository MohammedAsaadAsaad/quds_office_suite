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
| PDF file (`PdfFile`) | Open ISO 32000-1 (xref table/stream, incremental, ObjStm). Standard security Rev 2–4; Rev 5/6 attempted. Display list: paths (`m`/`l`/`c`/`v`/`y`/`re` through CTM), `S`/`s`/`f`/`B`/`b`/`b*` (fill+stroke keeps the path), `W`/`W*` clip + `q`/`Q`, `J`/`j`/`M`/`d` stroke style, DeviceRGB/Gray/CMYK (ICC-less), `/ICCBased` via `/N` only, `gs` (LW/LC/LJ/ML/D/ca/CA/`BM` Normal·Multiply·Screen), JPEG/Flate/LZW/CCITT (G3 1-D + G4) images, ImageMask stencil, Indexed palette, Form XObjects (`Matrix` + `BBox` clip), inline `BI`/`EI`, Type 3 `CharProcs`, `sh` Type 2 axial + Type 3 radial, OCG `BDC`/`EMC` + `setLayerVisible`, `Tj`/`TJ`/`Tr` + ToUnicode + WinAnsi/MacRoman/PDFDoc + `/ActualText`. Annotate + `/AP`, AcroForm fill, `/XFA` flag (no extract), XFDF, ViewerPreferences, page insert/delete/rotate/merge/extract, incremental save. `PdfToolbox` writes a **new** file and grafts each page dict plus Contents and inherited Resources (fonts/images survive extract/merge). `/Rotate` is a clockwise 90° turn and does not rewrite MediaBox. Stamp, page numbers, and Bates are a Helvetica overlay stream (`/ca` opacity) — not an embedded face and not Arabic shaping. Crop changes CropBox only. Incremental `appendPages` still snapshots content and can drop Resources — use `PdfToolbox` for real files. Viewer/editor in `quds_office_editor` |
| PDF options | Optional PDF/A-2b-oriented catalog extras (`PdfSaveOptions.pdfA`: XMP, OutputIntent, MarkInfo); optional tagged structure from outlines (`tagged`). Reader **detects** PDF/A from XMP (`pdfAProfile`) and warns that incremental markup may fail a validator. Not certified |
| PDF structure / Sig | `/StructTreeRoot` is exposed as `PdfFile.structTree` (read). `PdfExtract.readingOrder` walks Alt/ActualText. `/Sig` fields: `ByteRange` coverage → `unverified` / `broken` / `unsupported`. PKCS#7 / CMS bytes are **not** verified. Creating signatures is out |
| Fonts | Writer: glyf TrueType embed + subset; multi-face fallback. Reader: `/FontFile2` glyf metrics when `SfntFont` parses; `/Widths`/`W`/`DW`; Standard 14 AFM widths (Helvetica, Times, Courier, Symbol, ZapfDingbats). Raw `/FontFile3` CFF is **wrapped as OTTO** (`PdfCffHost`) so the Flutter host can load it — the engine does **not** rasterize CFF outlines |
| Image filters | Flate (+ predictor), ASCIIHex/85, RunLength, LZW, DCT (JPEG passthrough), CCITTFaxDecode G3 1-D and G4 (mixed G3 2-D `K>0` is 1-D best-effort). `/SMask` on DeviceGray/RGB Flate is composed to RGBA in-engine; JPEG+/SMask DCT attaches `softMaskJpeg` for host compose. **JBIG2 and JPX stay** `PdfFilterUnsupported` (placeholder on that XObject) |
| Optional media | PPT `/ppt/media/` sync/hydrate via `quds_office_engine_optional.dart` (not on default export) |

## Explicitly limited / out of scope (short term)

- Legacy binary `.doc` / `.xls` / `.ppt`, VBA/macros, ActiveX
- Full Word field zoo, full theme/style matrix, real DrawingML SmartArt (`dgm:`)
- Full Excel LAMBDA / Power Pivot / rich pivot / Power Query beyond CSV helper
- PPTX audio/video as a default core feature (optional media helper only)
- PDF **content-stream reflow** (edit body text like Word) — out of [PDF.md](PDF.md)
- OCR, image recompress, and PDF-to-Office layout recovery (not implemented)
- PKCS#7 public-key encryption; **creating** digital signatures; **verifying** CMS / PAdES (ByteRange coverage only)
- In-engine CFF / Type 1 glyph raster (host OTTO wrap only); raw Type 1 `/FontFile` PFB; JBIG2; JPEG2000; ICC profile apply ( `/N` fallback only); Type 1/2/3 patterns; shadings other than Type 2/3 strips
- True sanitizing redaction of every operator in a content stream (overlay + extract filter only)
- Full PDF encryption of the **written** OOXML-export file; certified PDF/A or PDF/UA authoring
- Third-party viewer smoke of incremental `/AP` is manual (Adobe / LibreOffice)
- ODF: text extract only
- Some formula names remain **aliases or documented stubs** (see `FormulaGuide`); unknown names return `#NAME?`

## Design rules

- No document-specific or customer-specific code paths in the library.
- Layout heuristics (e.g. clearing header pictures) use OOXML margins and
  visual sizes only.
- Missing Excel formula names return `#NAME?` rather than silent wrong answers
  (except a few documented aliases / stubs).
