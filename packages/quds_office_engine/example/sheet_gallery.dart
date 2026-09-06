import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart';

void _put(
  SmlWorksheet sheet,
  String a1,
  Object? value, {
  String? formula,
}) {
  final SmlCell cell = sheet.cellA1(a1);
  if (formula != null) {
    cell.type = SmlCellType.formula;
    cell.formula = formula;
    cell.value = value ?? formula;
    return;
  }
  if (value is num) {
    cell.type = SmlCellType.number;
    cell.value = value;
    return;
  }
  if (value is bool) {
    cell.type = SmlCellType.boolean;
    cell.value = value;
    return;
  }
  cell.type = SmlCellType.string;
  cell.value = value;
}

/// Formula workbook the PDF printer evaluates (SUM, AVERAGE, IF, sheet refs).
SmlWorkbook engineWorkbook() {
  final SmlWorksheet inputs = SmlWorksheet(name: 'Inputs', sheetId: 1);
  final List<List<Object?>> grid = <List<Object?>>[
    <Object?>['Module', 'Q1', 'Q2', 'Q3', 'Q4'],
    <Object?>['Word', 42, 48, 51, 55],
    <Object?>['Excel', 36, 41, 39, 47],
    <Object?>['Slides', 28, 33, 37, 40],
    <Object?>['PDF', 18, 22, 31, 44],
  ];
  for (int r = 0; r < grid.length; r++) {
    for (int c = 0; c < grid[r].length; c++) {
      _put(inputs, SmlCellRef(c, r).a1, grid[r][c]);
    }
  }

  final SmlWorksheet calc = SmlWorksheet(name: 'Calc', sheetId: 2);
  _put(calc, 'A1', 'Metric');
  _put(calc, 'B1', 'Value');
  _put(calc, 'A2', 'Year total');
  _put(calc, 'B2', null, formula: '=SUM(Inputs!B2:E5)');
  _put(calc, 'A3', 'Word average');
  _put(calc, 'B3', null, formula: '=AVERAGE(Inputs!B2:E2)');
  _put(calc, 'A4', 'PDF grew?');
  _put(calc, 'B4', null, formula: '=IF(Inputs!E5>Inputs!B5,"yes","no")');
  _put(calc, 'A5', 'Q4 stack');
  _put(calc, 'B5', null, formula: '=SUM(Inputs!E2:E5)');

  inputs.drawings.add(
    SmlDrawing(
      visual: OfficeVisual(
        kind: OfficeVisualKind.chartColumn,
        title: 'Units by quarter',
        points: const <ChartPoint>[
          ChartPoint(label: 'Q1', value: 124, color: '2B579A'),
          ChartPoint(label: 'Q2', value: 144, color: '217346'),
          ChartPoint(label: 'Q3', value: 158, color: 'B7472A'),
          ChartPoint(label: 'Q4', value: 186, color: 'ED7D31'),
        ],
        width: 280,
        height: 150,
      ),
      col: 6,
      row: 1,
    ),
  );
  calc.drawings.add(
    SmlDrawing(
      visual: OfficeVisual(
        kind: OfficeVisualKind.chartLine,
        title: 'PDF ramp',
        points: const <ChartPoint>[
          ChartPoint(label: 'Q1', value: 18, color: '2B579A'),
          ChartPoint(label: 'Q2', value: 22, color: '2B579A'),
          ChartPoint(label: 'Q3', value: 31, color: '2B579A'),
          ChartPoint(label: 'Q4', value: 44, color: '2B579A'),
        ],
        width: 260,
        height: 140,
      ),
      col: 3,
      row: 1,
    ),
  );

  return SmlWorkbook(sheets: <SmlWorksheet>[inputs, calc]);
}

/// Fluent builder: styles, freeze, merge, number formats, an RTL sheet.
Uint8List builderWorkbook() {
  final XlsxWorkbookBuilder book = XlsxWorkbookBuilder(
    theme: OfficeDocumentTheme.light(),
  );
  final int title = book.style(
    bold: true,
    size: 16,
    color: '1F4E79',
  );
  final int header = book.style(
    bold: true,
    fillRgb: '2B579A',
    color: 'FFFFFF',
    border: true,
    horizontal: 'center',
  );
  final int money = book.style(numFmt: '0.00', border: true, horizontal: 'right');
  final int band = book.style(fillRgb: 'F2F2F2', border: true);
  final int pct = book.style(numFmt: '0.00%', border: true);

  final XlsxSheetBuilder summary = book.addSheet('Summary');
  summary
    ..freezeRows = 2
    ..merge(0, 0, 0, 3)
    ..addRow(<Object?>['Styled OPC workbook'], style: title)
    ..addRow(<Object?>['SKU', 'Units', 'Price', 'Share'], style: header)
    ..addRow(<Object?>['W-01', 120, 9.5, 0.40], style: band)
    ..addRow(<Object?>['X-02', 80, 11.0, 0.35])
    ..addRow(<Object?>['P-03', 95, 8.25, 0.25], style: band)
    ..colWidth(0, 14)
    ..colWidth(1, 10)
    ..colWidth(2, 10)
    ..colWidth(3, 10);
  summary
    ..setCell(2, 2, 9.5, style: money)
    ..setCell(3, 2, 11.0, style: money)
    ..setCell(4, 2, 8.25, style: money)
    ..setCell(2, 3, 0.40, style: pct)
    ..setCell(3, 3, 0.35, style: pct)
    ..setCell(4, 3, 0.25, style: pct);

  final XlsxSheetBuilder arabic = book.addSheet('لوحة');
  arabic
    ..rightToLeft = true
    ..freezeRows = 1
    ..autoFilterRef = 'A1:C4'
    ..addRow(<Object?>['البند', 'العدد', 'جاهز'], style: header)
    ..addRow(<Object?>['تصدير PDF', 3, true])
    ..addRow(<Object?>['ملفات Word', 3, true], style: band)
    ..addRow(<Object?>['شرائح', 3, true])
    ..fitColumnWidths(fromRow: 0, toRow: 3, colCount: 3);

  return book.build();
}

/// Third Excel shape: a small catalog with line amounts as formulas.
SmlWorkbook catalogWorkbook() {
  final SmlWorksheet catalog = SmlWorksheet(name: 'Catalog', sheetId: 1);
  final List<List<Object?>> rows = <List<Object?>>[
    <Object?>['SKU', 'Item', 'Qty', 'Price'],
    <Object?>['ENG-W', 'Word layout kit', 12, 9.5],
    <Object?>['ENG-X', 'Sheet eval kit', 8, 11],
    <Object?>['ENG-P', 'Slide paint kit', 15, 8.25],
  ];
  for (int r = 0; r < rows.length; r++) {
    for (int c = 0; c < rows[r].length; c++) {
      _put(catalog, SmlCellRef(c, r).a1, rows[r][c]);
    }
  }
  _put(catalog, 'E1', 'Amount');
  for (int r = 1; r <= 3; r++) {
    _put(catalog, 'E${r + 1}', null, formula: '=C${r + 1}*D${r + 1}');
  }
  _put(catalog, 'A6', 'Lines');
  _put(catalog, 'B6', null, formula: '=COUNTA(A2:A4)');
  _put(catalog, 'A7', 'Total');
  _put(catalog, 'B7', null, formula: '=SUM(E2:E4)');

  final SmlWorksheet notes = SmlWorksheet(name: 'Notes', sheetId: 2);
  _put(notes, 'A1', 'PDF prints every sheet');
  _put(notes, 'A2', 'Formulas are evaluated at export time');
  _put(notes, 'A3', 'Charts ride as SmlDrawing visuals');
  catalog.drawings.add(
    SmlDrawing(
      visual: OfficeVisual(
        kind: OfficeVisualKind.chartBar,
        title: 'Qty',
        points: const <ChartPoint>[
          ChartPoint(label: 'Word', value: 12, color: '2B579A'),
          ChartPoint(label: 'Sheet', value: 8, color: '217346'),
          ChartPoint(label: 'Slide', value: 15, color: 'B7472A'),
        ],
        width: 240,
        height: 130,
      ),
      col: 6,
      row: 0,
    ),
  );
  return SmlWorkbook(sheets: <SmlWorksheet>[catalog, notes]);
}
