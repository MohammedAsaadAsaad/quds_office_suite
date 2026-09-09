# Quds Office Suite — Standards coverage

This document states what the packages implement relative to common
**ISO/IEC 29500 (Office Open XML)** and **PDF 1.7** expectations. It is a
**general-purpose library** contract — not a fidelity claim against any single
vendor product.

See also [MISSION.md](MISSION.md) (Phase 1–5) and [ROADMAP.md](ROADMAP.md).

## Supported (engine)

| Area | Coverage |
| --- | --- |
| OPC packages | DOCX / XLSX / PPTX open + save, repair, Agile passwords, isolates |
| Word | Sections, paras/runs, tables, lists (multilevel numbering subset), headers/footers, styles (`basedOn`/fonts), comments, TOC, hyperlinks, fields (PAGE/NUMPAGES/DATE/TIME/REF/SEQ/TOC/CITATION/INDEX/HYPERLINK/FILENAME/FILESIZE/AUTHOR/TITLE/MERGEFIELD), footnotes/endnotes, OMML, BiDi/RTL, layout → PDF |
| Excel | Sheets, shared strings, styles, formulas (broad catalog), merges, freeze, RTL, charts/pictures, named ranges/tables, shallow CF/validation, **simple SUM pivot** (not Power Pivot), **CSV import helper** (not full Power Query), print area/titles/header-footer model, cell borders vs gridlines in PDF |
| PowerPoint | Slides, shapes (limited presets + stroke), tables, images/charts (RTL chart write), notes, masters/layouts (subset), transitions/animations including Morph + reverse show, shape hyperlink URIs in PDF |
| PDF 1.7 | Word layout replay, Excel geometry-aware grid + print titles/HF, PPT slides/notes/master shapes/strokes/URI annots, TTF/`glyf` subset (multi-face via `OfficeFontSet`), PNG/JPEG, Word TOC/URI links, `/Outlines` bookmarks |
| PDF options | Optional PDF/A-2b-oriented catalog extras (`PdfSaveOptions.pdfA`: XMP, OutputIntent, MarkInfo); optional tagged structure from outlines (`tagged`). Not validator-certified PDF/A |
| Fonts | Glyf TrueType embed + subset; multi-face fallback. CFF/`FontFile3` not implemented |
| Optional media | PPT `/ppt/media/` sync/hydrate via `quds_office_engine_optional.dart` (not on default export) |

## Explicitly limited / out of scope (short term)

- Legacy binary `.doc` / `.xls` / `.ppt`, VBA/macros, ActiveX
- Full Word field zoo, full theme/style matrix, real DrawingML SmartArt (`dgm:`)
- Full Excel LAMBDA / Power Pivot / rich pivot / Power Query beyond CSV helper
- PPTX audio/video as a default core feature (optional media helper only)
- PDF import; full PDF encryption of the written file; certified PDF/A
- ODF: text extract only
- Some formula names remain **aliases or documented stubs** (see `FormulaGuide`); unknown names return `#NAME?`

## Design rules

- No document-specific or customer-specific code paths in the library.
- Layout heuristics (e.g. clearing header pictures) use OOXML margins and
  visual sizes only.
- Missing Excel formula names return `#NAME?` rather than silent wrong answers
  (except a few documented aliases / stubs).
