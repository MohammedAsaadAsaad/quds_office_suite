# quds_office_engine

<p>
  <a href="https://pub.dev/packages/quds_office_engine"><img alt="pub" src="https://img.shields.io/pub/v/quds_office_engine.svg"/></a>
  <a href="https://pub.dev/packages/quds_office_engine/score"><img alt="likes" src="https://img.shields.io/pub/likes/quds_office_engine?label=likes"/></a>
  <a href="../../LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-0B1F3A"/></a>
  <img alt="platforms" src="https://img.shields.io/badge/platforms-VM%20·%20web%20·%20Flutter-0175C2"/>
</p>

**Pure Dart Office Open XML + PDF.** Open, build, mutate, and export
`.docx` / `.xlsx` / `.pptx` without Flutter, `dart:ui`, or a native Office install.

This is the model and IO half of [Quds Office Suite](https://github.com/MohammedAsaadAsaad/quds_office_suite).
For interactive canvases, add [`quds_office_editor`](https://pub.dev/packages/quds_office_editor).

<p dir="rtl">
محرّك Office مكتوب بـ Dart فقط: قراءة وكتابة ملفات وورد وإكسل وبوربوينت،
ومحرّك معادلات، وتصدير PDF 1.7، ودعم العربية و RTL — بدون Flutter.
</p>

---

## Why a dedicated engine

| You need | What the engine does |
| --- | --- |
| Generate reports on a server | Builders return `Uint8List` you can write or stream |
| Open real Office files | OPC package + WordprocessingML / SpreadsheetML / PresentationML |
| Excel that actually calculates | Formula AST, functions, dependency graph |
| Arabic that looks right | UAX #9 BiDi, Arabic shaping, grapheme line breaks |
| Print / archive | Native PDF 1.7 with subsetted fonts, images, and links |
| Large files in a UI | `OfficeIsolateOpen` / `OfficeIsolateSave` keep the UI isolate free |
| Damaged or encrypted packages | Repair heuristics and password-aware open |

No hidden “call Microsoft Graph” step. The bytes are yours.

---

## Install

```yaml
dependencies:
  quds_office_engine: ^0.1.0
```

```bash
dart pub add quds_office_engine
```

SDK: Dart **3.12+**. Works in Flutter apps, CLI tools, isolates, and web (where
`dart:io` is not required — pass `Uint8List` yourself).

---

## Word — build a `.docx`

```dart
import 'dart:io';
import 'package:quds_office_engine/quds_office_engine.dart';

void main() {
  final theme = OfficeDocumentTheme.custom(
    palette: const OfficePalette(primary: '2B579A', accent: 'C9A227'),
    rtl: true,
  );

  final bytes = (DocxDocumentBuilder(theme: theme)
        ..header(left: 'Quds Office', right: 'سري')
        ..footer(left: 'القدس', right: 'Page')
        ..heading('تقرير الربع')
        ..paragraph('ملخص تنفيذي بالعربية والإنجليزية.')
        ..note('Generated without Microsoft Office.')
        ..bulletList(['Word', 'Excel', 'PowerPoint'])
        ..table([
          ['KPI', 'Q1', 'Q2'],
          ['Docs', '120', '148'],
          ['Slides', '36', '41'],
        ])
        ..hyperlink('Documentation', 'https://pub.dev/packages/quds_office_engine')
        ..pageBreak()
        ..heading('Appendix', level: 2)
        ..barChart(
          title: 'Volume',
          series: const [
            ChartPoint(label: 'Q1', value: 120),
            ChartPoint(label: 'Q2', value: 148),
          ],
        ))
      .build();

  File('report.docx').writeAsBytesSync(bytes);
}
```

### Open and inspect

```dart
final document = WordDeserializer().readBytes(bytes);
final text = OfficeTextExtractor.extract(bytes, name: 'report.docx');
print(text.plainString);

final plain = DocxPlainReader.read(bytes);
print(plain.paragraphs);
print(plain.tables);
print(plain.hyperlinks);
```

The full `WmlDocument` model covers runs, paragraphs, tables, sections,
headers/footers, comments, hyperlinks, TOC, drawings, and OMML equations.

---

## Excel — build a `.xlsx`

```dart
final book = XlsxWorkbookBuilder(theme: theme);
final header = book.style(bold: true, fillRgb: '2B579A', color: 'FFFFFFFF');
final sheet = book.addSheet('Budget')
  ..rightToLeft = true
  ..freezeRows = 1
  ..addRow(['البند', 'العدد', 'السعر'], style: header)
  ..addRow(['ورق', 40, 1.25])
  ..addRow(['حبر', 12, 8.5]);
sheet.columnWidths.add((min: 1, max: 3, width: 18));
File('budget.xlsx').writeAsBytesSync(book.build());
```

### Formulas (the real model)

`XlsxWorkbookBuilder` is a styled writer. For calculation, use `SmlWorkbook`:

```dart
final sheet = SmlWorksheet(name: 'Calc', sheetId: 1);
sheet.cellA1('A1').value = 10;
sheet.cellA1('A2').value = 20;
final total = sheet.cellA1('A3')..formula = '=SUM(A1:A2)';

final workbook = SmlWorkbook(sheets: [sheet]);
FormulaDepGraph(workbook).recalculate();
print(total.asNumber); // 30

final xlsx = SheetSerializer().writeBytes(workbook);
```

Supported families include:

- **Math** — `SUM`, `AVERAGE`, `MIN`, `MAX`, `ROUND*`, `PRODUCT`, `POWER`, `SQRT`, `MOD`, `GCD`, `LCM`, `SUMPRODUCT`, …
- **Logic** — `IF`, `IFS`, `IFERROR`, `IFNA`, `AND`, `OR`, `XOR`, `NOT`, `SWITCH`
- **Lookup** — `VLOOKUP`, `INDEX`, `MATCH`
- **Text** — `CONCAT` / `CONCATENATE`, `LEFT`, `RIGHT`, `MID`, `LEN`, `TRIM`, `UPPER`, `LOWER`, `SUBSTITUTE`, …
- **Stat** — `COUNT`, `COUNTA`, `COUNTIF(S)`, `SUMIF(S)`, `AVERAGEIF`, `STDEV`, `VAR`, `MEDIAN`
- **Date** — `DATE`, `TODAY`, `NOW`, and related serials

Cross-sheet references and a dependency graph are part of the evaluator.

```dart
final names = XlsxGridReader.listSheets(xlsx);
final rows = XlsxGridReader.readSheet(xlsx, sheetIndex: 0);
```

---

## PowerPoint — build a `.pptx`

```dart
final deck = (PptxDeckBuilder(theme: theme, showSlideNumber: true)
      ..addCoverSlide(
        title: 'Quds Office Engine',
        subtitle: 'OPC · Formulas · PDF',
      )
      ..addKpiSlide(
        title: 'This quarter',
        cards: [
          (label: 'Documents', value: '148'),
          (label: 'Decks', value: '41'),
        ],
      )
      ..addTitleBodySlide(
        title: 'Agenda',
        bullets: ['Builders', 'Models', 'Export'],
      )
      ..addPieChartSlide(
        title: 'Mix',
        series: const [
          ChartPoint(label: 'Word', value: 50),
          ChartPoint(label: 'Excel', value: 30),
          ChartPoint(label: 'Slides', value: 20),
        ],
      )
      ..addClosingSlide(title: 'شكراً', subtitle: 'quds_office_engine'))
    .build();

File('deck.pptx').writeAsBytesSync(deck);
```

The `PmlPresentation` model stores shapes, tables, notes, hidden slides,
**animations**, and **transitions**. `PmlSlideShow` is a click-driven clock:

```dart
final show = PmlSlideShow(presentation)..start(from: 0);
show.next();          // fire the next click, or transition forward
show.elapse(16);      // advance the clock
show.previous();      // reverse the last animation or the last transition
print(show.transitionProgress);
print(show.sample(shapeId).opacity);
```

`previous()` is not a jump. Entrances fly back out along the same path;
transitions replay as if the slide show were a video in reverse.

---

## PDF 1.7

```dart
// Any OOXML package:
final pdf = OfficePdfExport.fromBytes(docx, title: 'Report');

// Or from models:
OfficePdfExport.word(document, font: font, title: 'Word');
OfficePdfExport.workbook(workbook, font: font, title: 'Excel');
OfficePdfExport.presentation(
  presentation,
  font: font,
  title: 'Slides',
  mode: PdfSlideExportMode.notesPages,
);
```

Word uses the layout engine (pages, tables, headers/footers, visuals, TOC
links). Excel prints evaluated grids (A4 / landscape / Letter). PowerPoint
emits one landscape page per slide, or notes pages.

For a block-oriented report that never existed as OOXML:

```dart
final pdf = (PdfReportBuilder(
      theme: theme,
      header: 'Quds',
      footer: 'Page',
    )
      ..titleText('Quarterly')
      ..body('Narrative…')
      ..kpiRow([(label: 'NPS', value: '72')])
      ..table([
        ['A', 'B'],
        ['1', '2'],
      ]))
    .build();
```

Embed a covering `SfntFont` (DejaVu, Liberation, Noto) so Arabic *and* Latin
glyphs subset into the file. The canvas will not draw `.notdef` tofu.

---

## Open large files off the UI isolate

```dart
final payload = await OfficeIsolateOpen.word(
  bytes,
  onProgress: (p) => print('${p.stage} ${(p.value * 100).round()}%'),
);
final document = payload.document;
final laidOut = payload.laidOut;
```

The same pattern exists for workbooks and presentations. Saves can also run
on a worker isolate.

---

## Extract text (search, RAG, previews)

```dart
final extracted = OfficeTextExtractor.extract(bytes, name: 'file.docx');
print(extracted.kind);        // word / sheet / slide / ODF / …
print(extracted.plainString);
```

DOCX, XLSX, PPTX, and OpenDocument text/sheet/presentation are supported.
PDF text extraction is not in this version — use the OOXML extractors, or
export *to* PDF.

---

## Theming

Branding is injected through `OfficeDocumentTheme`. The engine does not
hardcode a product name into documents.

```dart
final theme = OfficeDocumentTheme.custom(
  palette: const OfficePalette(
    primary: '2B579A',
    accent: '217346',
    muted: '5B5B5B',
    highlight: 'C9A227',
  ),
  rtl: true,
  page: OfficePageSize.a4Portrait,
);
```

---

## Package layout

```text
lib/src/
├── opc/        ZIP, relationships, content types, OLE, crypto, repair, isolates
├── xml/        Streaming reader / writer, Office namespaces
├── word/       WML model, layout, OMML math, comments, TOC, serialize
├── sheet/      SML model, styles, formula AST + functions
├── slide/      PML model, DrawingML, animations, Morph, serialize
├── pdf/        PDF 1.7 document, fonts, images, Office export
├── bidi/       UAX #9, shaping, line breaker, office direction
├── fonts/      SFNT parse, metrics, subset, outlines
├── builders/   Fluent DOCX / XLSX / PPTX writers
└── extract/    Plain-text extraction
```

---

## Examples

| Script | Writes |
| --- | --- |
| [`example/engine_quickstart.dart`](example/engine_quickstart.dart) | One DOCX + PDF |
| [`example/rich_export_gallery.dart`](example/rich_export_gallery.dart) | Word, Excel, PowerPoint galleries + PDF |
| [`example/word_gallery.dart`](example/word_gallery.dart) | Word-only |
| [`example/sheet_gallery.dart`](example/sheet_gallery.dart) | Excel-only |
| [`example/slide_gallery.dart`](example/slide_gallery.dart) | PowerPoint-only |

```bash
cd packages/quds_office_engine
dart run example/engine_quickstart.dart
dart run example/rich_export_gallery.dart
```

---

## Compatibility

| Format | Read | Write | Notes |
| --- | --- | --- | --- |
| `.docx` | Yes | Yes | Sections, tables, drawings, comments, TOC, OMML |
| `.xlsx` | Yes | Yes | Styles, formulas, freeze, RTL, charts |
| `.pptx` | Yes | Yes | Shapes, notes, hidden slides, motion |
| `.odt` / `.ods` / `.odp` | Extract | — | Text extraction |
| `.pdf` | — | Yes | Native 1.7 compile |
| Password-protected OOXML | Yes | Yes | When a password is supplied |

Files are intended to open in Microsoft Office, LibreOffice, and OnlyOffice.
Exotic VBA / ActiveX / legacy binary (`.doc` / `.xls` / `.ppt`) is out of scope.

---

## Design rules

- **100% type-safe** — no `dynamic`, no untyped maps in the public API.
- **Uint8List in, Uint8List out** — you own storage, networking, and encryption at rest.
- **No Flutter** — this package must stay embeddable in `dart:io` servers.

Interactive editing lives in [`quds_office_editor`](https://pub.dev/packages/quds_office_editor).

---

## License

MIT © Mohammed Asaad Asaad
