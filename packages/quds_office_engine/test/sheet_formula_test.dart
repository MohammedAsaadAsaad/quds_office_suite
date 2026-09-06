import 'package:quds_office_engine/quds_office_engine.dart';
import 'package:test/test.dart';

void main() {
  test('evaluates arithmetic, logic, lookup, and text functions', () {
    final SmlWorkbook book = SmlWorkbook();
    final SmlWorksheet s = book.firstSheet;
    s.cellA1('A1').value = 10;
    s.cellA1('A2').value = 20;
    s.cellA1('A3').value = 30;
    s.cellA1('B1').value = 'hello';
    final FormulaContext ctx = FormulaContext(
      workbook: book,
      sheet: s,
      origin: SmlCellRef.parse('C1'),
    );

    expect(evaluateFormula('=SUM(A1:A3)', ctx), 60);
    expect(evaluateFormula('=COUNTA(A1:A3)', ctx), 3);
    expect(evaluateFormula('=AVERAGE(A1:A3)', ctx), 20);
    expect(evaluateFormula('=IF(A1>5,"yes","no")', ctx), 'yes');
    expect(evaluateFormula('=AND(TRUE,1)', ctx), isTrue);
    expect(evaluateFormula('=CONCATENATE(B1,"!")', ctx), 'hello!');
    expect(evaluateFormula('=LEFT(B1,2)', ctx), 'he');
    expect(evaluateFormula('=ROUND(1.26,1)', ctx), closeTo(1.3, 0.0001));
    expect(evaluateFormula('=2^3+1', ctx), 9);
    expect(evaluateFormula('=A1+A2', ctx), 30);
    expect(evaluateFormula('=SUM(A1 : A3)', ctx), 60);
    expect(evaluateFormula('=SUM(A1; A3)', ctx), 40);
    expect(evaluateFormula('=A1*10%', ctx), 1);
    expect(evaluateFormula('=  A1 + A2  ', ctx), 30);

    s.cellA1('D1').value = 'x';
    s.cellA1('E1').value = 5;
    s.cellA1('D2').value = 'y';
    s.cellA1('E2').value = 9;
    expect(evaluateFormula('=VLOOKUP("y",D1:E2,2)', ctx), 9);
  });

  test('detects circular references and recalculates a workbook', () {
    final SmlWorkbook book = SmlWorkbook();
    book.firstSheet.cellA1('A1').value = 2;
    book.firstSheet.cellA1('A2').formula = '=A1*3';
    book.firstSheet.cellA1('A3').formula = '=SUM(A1:A2)';
    FormulaDepGraph(book).recalculate();
    expect(book.firstSheet.cellA1('A2').asNumber, 6);
    expect(book.firstSheet.cellA1('A3').asNumber, 8);

    book.firstSheet.cellA1('B1').formula = '=B2';
    book.firstSheet.cellA1('B2').formula = '=B1';
    final FormulaDepGraph g = FormulaDepGraph(book);
    g.recalculate();
    expect(g.circular, isNotEmpty);
  });

  test('round-trips frozen panes', () {
    final SmlWorkbook book = SmlWorkbook();
    book.firstSheet.freezeRows = 4;
    book.firstSheet.freezeCols = 2;
    book.firstSheet.cellA1('C5').value = 1;
    final bytes = SheetSerializer().writeBytes(book);
    final String xml = OpcPackage.openBytes(
      bytes,
    ).getPart('/xl/worksheets/sheet1.xml')!.readText();
    expect(xml, contains('xSplit="2"'));
    expect(xml, contains('ySplit="4"'));
    expect(xml, contains('topLeftCell="C5"'));
    expect(xml, contains('state="frozen"'));
    final SmlWorkbook opened = SheetDeserializer().readBytes(bytes);
    expect(opened.firstSheet.freezeRows, 4);
    expect(opened.firstSheet.freezeCols, 2);
  });

  test('round-trips sheetView rightToLeft', () {
    final SmlWorkbook book = SmlWorkbook();
    book.firstSheet.rightToLeft = true;
    book.firstSheet.cellA1('A1').value = 'مرحبا';
    final bytes = SheetSerializer().writeBytes(book);
    final String xml = OpcPackage.openBytes(
      bytes,
    ).getPart('/xl/worksheets/sheet1.xml')!.readText();
    expect(xml, contains('rightToLeft="1"'));
    expect(xml, contains('<sheetViews>'));
    final SmlWorkbook opened = SheetDeserializer().readBytes(bytes);
    expect(opened.firstSheet.rightToLeft, isTrue);
    expect(opened.firstSheet.cellA1('A1').asString, 'مرحبا');
  });

  test('round-trips a multi-sheet workbook', () {
    final SmlWorkbook book = SmlWorkbook(
      sheets: <SmlWorksheet>[
        SmlWorksheet(name: 'Data', sheetId: 1),
        SmlWorksheet(name: 'Calc', sheetId: 2),
      ],
    );
    book.sheets[0].cellA1('A1').value = 42;
    book.sheets[1].cellA1('A1').formula = '=Data!A1+1';
    FormulaDepGraph(book).recalculate();
    final bytes = SheetSerializer().writeBytes(book);
    final SmlWorkbook opened = SheetDeserializer().readBytes(bytes);
    expect(opened.sheets.length, 2);
    expect(opened.sheetByName('Data')!.cellA1('A1').asNumber, 42);
    expect(opened.sheetByName('Calc')!.cellA1('A1').formula, isNotNull);
  });

  test('parses quoted and unicode sheet names', () {
    final SmlWorkbook book = SmlWorkbook(
      sheets: <SmlWorksheet>[
        SmlWorksheet(name: 'Data', sheetId: 1),
        SmlWorksheet(name: 'لوحة', sheetId: 2),
      ],
    );
    book.sheets[0].cellA1('A1').value = 7;
    book.sheets[1].cellA1('B2').value = 11;
    final FormulaContext ctx = FormulaContext(
      workbook: book,
      sheet: book.sheets[1],
      origin: SmlCellRef.parse('A1'),
    );
    expect(evaluateFormula("='Data'!A1+1", ctx), 8);
    expect(evaluateFormula('=لوحة!B2', ctx), 11);
  });

  test(
    'applyInput caches the computed value and recalculate updates dependents',
    () {
      final SmlWorkbook book = SmlWorkbook();
      final SmlWorksheet s = book.firstSheet;
      FormulaEvaluator.applyInput(book, s, s.cellA1('A1'), '4');
      FormulaEvaluator.applyInput(book, s, s.cellA1('B1'), '6');
      FormulaEvaluator.applyInput(book, s, s.cellA1('C1'), '=A1+B1');
      expect(s.cellA1('C1').value, 10);
      expect(s.cellA1('C1').formula, '=A1+B1');
      expect(s.cellA1('C1').type, SmlCellType.formula);

      FormulaEvaluator.applyInput(book, s, s.cellA1('A1'), '9');
      FormulaEvaluator.recalculate(book);
      expect(s.cellA1('C1').value, 15);
      expect(FormulaEvaluator.evaluateCell(book, s, s.cellA1('C1')), 15);
    },
  );

  test('scans formula references with source offsets', () {
    final List<FormulaRefSpan> refs = FormulaRefScanner.scan('=A1+B1');
    expect(refs, hasLength(2));
    expect(refs[0].lexeme, 'A1');
    expect('=A1+B1'.substring(refs[0].start, refs[0].end), 'A1');
    expect(refs[0].range.start.a1, 'A1');
    expect(refs[1].lexeme, 'B1');
    expect('=A1+B1'.substring(refs[1].start, refs[1].end), 'B1');

    final List<FormulaRefSpan> range = FormulaRefScanner.scan('=SUM(A1:B2)');
    expect(range, hasLength(1));
    expect(range.first.lexeme, 'A1:B2');
    expect(range.first.range.start.a1, 'A1');
    expect(range.first.range.end.a1, 'B2');

    expect(FormulaRefScanner.scan('42'), isEmpty);
    expect(FormulaRefScanner.scan('="A1"+C3'), hasLength(1));
    expect(FormulaRefScanner.scan('="A1"+C3').first.lexeme, 'C3');

    final List<FormulaRefSpan> sheetRef = FormulaRefScanner.scan(
      "='لوحة'!B2+A1",
    );
    expect(sheetRef, hasLength(2));
    expect(sheetRef[0].sheetName, 'لوحة');
    expect(sheetRef[0].onSheet('لوحة'), isTrue);
    expect(sheetRef[0].onSheet('Budget'), isFalse);
    expect(sheetRef[1].onSheet('Budget'), isTrue);
    expect(sheetRef[0].colorKey, isNot(sheetRef[1].colorKey));
    final List<FormulaRefSpan> abs = FormulaRefScanner.scan('=A1+\$A\$1');
    expect(abs, hasLength(2));
    expect(abs[0].colorKey, abs[1].colorKey);
  });

  test('function guide searches names and ignores cell refs', () {
    expect(FormulaFunctionGuide.search('SU').first.name, 'SUM');
    expect(FormulaFunctionGuide.byName('STDEV.S')?.name, 'STDEV');
    expect(FormulaFunctionGuide.all, isNotEmpty);
    final FormulaNameQuery? q = FormulaFunctionGuide.queryAt('=SU', 3);
    expect(q?.prefix, 'SU');
    expect(FormulaFunctionGuide.queryAt('=A1', 3), isNull);
    expect(FormulaFunctionGuide.queryAt('hello', 3), isNull);
  });

  test('formats numbers via styles.xml codes', () {
    expect(applyNumberFormat(0.25, '0%'), '25.00%');
    expect(applyNumberFormat(-3, '[Red]0'), 'RED:-3');
    expect(applyNumberFormat(12.3, '0.00'), '12.30');
  });

  test('column and row metrics stay inside Excel limits', () {
    final SmlWorksheet sheet = SmlWorksheet(name: 'Sheet1', sheetId: 1);
    expect(SmlWorksheet.excelColumnCount, 16384);
    expect(SmlWorksheet.excelRowCount, 1048576);
    expect(sheet.columnAt(0), 0);
    expect(sheet.columnAt(64), 1);
    expect(sheet.columnAt(64 * 20 + 1), 20);
    expect(sheet.rowAt(20 * 40 + 1), 40);
    sheet.setColumnWidth(2, 96);
    expect(sheet.columnLeft(2), 128);
    expect(sheet.columnLeft(3), 224);
    expect(sheet.columnAt(150), 2);
    sheet.setRowHeight(1, 40);
    expect(sheet.rowTop(1), 20);
    expect(sheet.rowTop(2), 60);
    expect(sheet.rowAt(50), 1);
  });

  test('round-trips custom column widths and row heights', () {
    final SmlWorkbook book = SmlWorkbook();
    book.firstSheet.setColumnWidth(0, 96);
    book.firstSheet.setColumnWidth(1, 96);
    book.firstSheet.setRowHeight(2, 40);
    book.firstSheet.cellA1('A1').value = 1;
    final bytes = SheetSerializer().writeBytes(book);
    final String xml = OpcPackage.openBytes(
      bytes,
    ).getPart('/xl/worksheets/sheet1.xml')!.readText();
    expect(xml, contains('<cols>'));
    expect(xml, contains('customWidth="1"'));
    expect(xml, contains('customHeight="1"'));
    final SmlWorkbook opened = SheetDeserializer().readBytes(bytes);
    expect(opened.firstSheet.columnWidth(0), closeTo(96, 0.6));
    expect(opened.firstSheet.columnWidth(1), closeTo(96, 0.6));
    expect(opened.firstSheet.rowHeightAt(2), closeTo(40, 0.6));
  });
}
