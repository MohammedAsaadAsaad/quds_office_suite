import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

void main() {
  test('word controller inserts, undoes, and respects viewing mode', () {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument.empty(text: 'Hi'),
    );
    controller.caret
      ..logicalIndex = 2
      ..selectionAnchor = 2;
    controller.insertText('!');
    expect(controller.document.paragraphs.first.text, 'Hi!');
    expect(controller.isDirty, isTrue);
    controller.undo();
    expect(controller.document.paragraphs.first.text, 'Hi');
    expect(
      controller.laidOut.pages.first.lines
          .expand((LaidOutLine line) => line.glyphs)
          .map((LaidOutGlyph g) => String.fromCharCode(g.glyph.codePoint))
          .join(),
      contains('Hi'),
    );
    expect(controller.canRedo, isTrue);
    controller.redo();
    expect(controller.document.paragraphs.first.text, 'Hi!');
    controller.undo();
    expect(controller.document.paragraphs.first.text, 'Hi');
    controller.setMode(OfficeInteractionMode.viewing);
    controller.insertText('nope');
    expect(controller.document.paragraphs.first.text, 'Hi');
    expect(controller.config.allowsMutation, isFalse);
  });

  test('backspace at the start of a paragraph joins the previous one', () {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Hello')]),
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'World')]),
            ],
          ),
        ],
      ),
    );
    controller.caret
      ..paragraphIndex = 1
      ..logicalIndex = 0
      ..collapseSelection();
    controller.deleteSelectionOr(backward: true);
    expect(controller.document.paragraphs.length, 1);
    expect(controller.document.paragraphs.first.text, 'HelloWorld');
    expect(controller.caret.paragraphIndex, 0);
    expect(controller.caret.logicalIndex, 5);
    controller.undo();
    final List<WmlParagraph> restored = controller.document.paragraphs.toList();
    expect(restored.length, 2);
    expect(restored[0].text, 'Hello');
    expect(restored[1].text, 'World');
  });

  test('backspace on an empty paragraph moves to the previous end', () {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlParagraph(
                inlines: <WmlInline>[
                  WmlRun(text: 'بسم الله الرحمن الرحيم وبه نستعين وعليه نتوكل'),
                ],
              ),
              WmlParagraph(),
            ],
          ),
        ],
      ),
    );
    controller.caret
      ..paragraphIndex = 1
      ..logicalIndex = 0
      ..collapseSelection();
    controller.deleteSelectionOr(backward: true);
    expect(controller.document.paragraphs.length, 1);
    expect(controller.caret.paragraphIndex, 0);
    expect(
      controller.caret.logicalIndex,
      controller.document.paragraphs.first.text.length,
    );
  });

  test('delete at the end of a paragraph joins the next one', () {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Hello')]),
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'World')]),
            ],
          ),
        ],
      ),
    );
    controller.caret
      ..paragraphIndex = 0
      ..logicalIndex = 5
      ..collapseSelection();
    controller.deleteSelectionOr(backward: false);
    expect(controller.document.paragraphs.first.text, 'HelloWorld');
    expect(controller.caret.logicalIndex, 5);
  });

  test('word controller deletes with backspace and delete', () {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument.empty(text: 'Hello'),
    );
    controller.caret
      ..logicalIndex = 5
      ..collapseSelection();
    controller.deleteSelectionOr(backward: true);
    expect(controller.document.paragraphs.first.text, 'Hell');
    controller.caret
      ..logicalIndex = 1
      ..collapseSelection();
    controller.deleteSelectionOr(backward: false);
    expect(controller.document.paragraphs.first.text, 'Hll');
    controller.caret
      ..logicalIndex = 1
      ..selectionAnchor = 3
      ..selectionAnchorParagraph = 0;
    controller.deleteSelectionOr(backward: true);
    expect(controller.document.paragraphs.first.text, 'H');
  });

  testWidgets('word editor backspace key deletes a character', (
    WidgetTester tester,
  ) async {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument.empty(text: 'Hi'),
    );
    controller.caret
      ..logicalIndex = 2
      ..collapseSelection();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 600,
          child: QudsWordEditor(controller: controller),
        ),
      ),
    );
    await tester.tap(find.byType(WordCanvas));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controller.document.paragraphs.first.text, 'H');
  });

  testWidgets('word editor ctrl+z undoes and ctrl+y redoes', (
    WidgetTester tester,
  ) async {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument.empty(text: 'Hi'),
    );
    controller.caret
      ..logicalIndex = 2
      ..collapseSelection();
    controller.insertText('!');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 600,
          child: QudsWordEditor(controller: controller),
        ),
      ),
    );
    await tester.tap(find.byType(WordCanvas));
    await tester.pump();
    expect(controller.document.paragraphs.first.text, 'Hi!');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.document.paragraphs.first.text, 'Hi');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.document.paragraphs.first.text, 'Hi!');
  });

  testWidgets('word editor ctrl+a selects the whole document', (
    WidgetTester tester,
  ) async {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'One')]),
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Two')]),
            ],
          ),
        ],
      ),
    );
    controller.caret
      ..paragraphIndex = 0
      ..logicalIndex = 1
      ..collapseSelection();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 600,
          child: QudsWordEditor(controller: controller),
        ),
      ),
    );
    await tester.tap(find.byType(WordCanvas));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.caret.selectionAnchorParagraph, 0);
    expect(controller.caret.selectionAnchor, 0);
    expect(controller.caret.paragraphIndex, 1);
    expect(controller.caret.logicalIndex, 3);
    expect(controller.caret.isCollapsed, isFalse);
  });

  test('sheet controller toggles rightToLeft and moves selection', () {
    final SheetEditorController controller = SheetEditorController();
    expect(controller.sheet.rightToLeft, isFalse);
    controller.setSheetRightToLeft(true);
    expect(controller.sheet.rightToLeft, isTrue);
    controller.selection.selectCell(const SmlCellRef(1, 0));
    controller.moveSelection(1, 0);
    expect(controller.selection.focus.a1, 'C1');
    controller.toggleSheetRightToLeft();
    expect(controller.sheet.rightToLeft, isFalse);
  });

  test('sheet navigation follows Excel limits and keeps the cell in view', () {
    final SheetEditorController controller = SheetEditorController();
    controller.viewport.extent = const Size(400, 300);
    controller.moveSelectionTo(const SmlCellRef(20, 40));
    expect(controller.selection.focus.a1, 'U41');
    expect(controller.viewport.origin.dx, greaterThan(100));
    expect(controller.viewport.origin.dy, greaterThan(100));
    controller.viewport.origin = const Offset(10000, 5000);
    controller.clampSheetViewport();
    expect(controller.viewport.origin.dx, lessThan(2000));
    expect(controller.viewport.origin.dy, lessThan(2000));
    controller.moveSelection(0, SmlWorksheet.excelRowCount);
    expect(controller.selection.focus.row, SmlWorksheet.excelRowCount - 1);
    controller.moveSelectionTo(const SmlCellRef(0, 0));
    controller.nudgeColumnWidth(32);
    expect(controller.sheet.columnWidth(0), closeTo(96, 0.6));
    controller.undo();
    expect(controller.sheet.columnWidth(0), SmlWorksheet.defaultColumnWidthPx);
    controller.selection.selectRow(2);
    controller.nudgeRowHeight(12);
    expect(controller.sheet.rowHeightAt(2), closeTo(32, 0.6));
  });

  test('freeze panes follow the Excel selection rules', () {
    final SheetEditorController controller = SheetEditorController();
    controller.selection.selectRow(3);
    controller.freezePanesFromSelection();
    expect(controller.sheet.freezeRows, 3);
    expect(controller.sheet.freezeCols, 0);
    controller.toggleFreezePanes();
    expect(controller.hasFrozenPanes, isFalse);
    controller.selection.selectColumn(2);
    controller.freezePanesFromSelection();
    expect(controller.sheet.freezeCols, 2);
    expect(controller.sheet.freezeRows, 0);
    controller.unfreezePanes();
    controller.selection.selectCell(const SmlCellRef(2, 4));
    controller.freezePanesFromSelection();
    expect(controller.sheet.freezeCols, 2);
    expect(controller.sheet.freezeRows, 4);
    controller.toggleFreezePanes();
    expect(controller.hasFrozenPanes, isFalse);
    controller.viewport.extent = const Size(400, 300);
    controller.viewport.origin = Offset.zero;
    controller.selection.selectRow(3);
    expect(controller.selection.focus.col, 0);
    expect(controller.selection.focus.a1, 'A4');
    controller.freezePanesFromSelection();
    expect(controller.viewport.origin.dx, 0);
    expect(controller.selection.focus.col, 0);
  });

  testWidgets('sheet arrow keys move between cells', (WidgetTester tester) async {
    final SheetEditorController controller = SheetEditorController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 640,
          height: 400,
          child: QudsSheetEditor(controller: controller),
        ),
      ),
    );
    await tester.tapAt(tester.getTopLeft(find.byType(SheetGrid)) + const Offset(60, 58));
    await tester.pump();
    expect(controller.selection.focus.a1, 'A1');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection.focus.a1, 'B1');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.selection.focus.a1, 'B2');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.selection.focus.a1, 'A2');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(controller.selection.focus.a1, 'A1');
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection.focus.a1, 'B1');
  });

  testWidgets('rtl sheet inverts horizontal arrow keys', (
    WidgetTester tester,
  ) async {
    final SheetEditorController controller = SheetEditorController();
    controller.setSheetRightToLeft(true);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: 640,
          height: 400,
          child: QudsSheetEditor(controller: controller),
        ),
      ),
    );
    final RenderBox box = tester.renderObject(find.byType(SheetGrid));
    final Offset origin = tester.getTopLeft(find.byType(SheetGrid));
    await tester.tapAt(origin + Offset(box.size.width - 28 - 32, 58));
    await tester.pump();
    expect(controller.selection.focus.a1, 'A1');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.selection.focus.a1, 'B1');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection.focus.a1, 'A1');
  });

  test('sheet Ctrl+arrow jumps by same occupancy', () {
    final SheetEditorController controller = SheetEditorController();
    controller.sheet.cellA1('A1').value = 1;
    controller.sheet.cellA1('B1').value = 2;
    controller.sheet.cellA1('D1').value = 4;
    controller.selection.selectCell(const SmlCellRef(0, 0));
    controller.jumpSelectionByOccupancy(1, 0);
    expect(controller.selection.focus.a1, 'B1');
    controller.jumpSelectionByOccupancy(1, 0);
    expect(controller.selection.focus.a1, 'D1');
    controller.jumpSelectionByOccupancy(-1, 0);
    expect(controller.selection.focus.a1, 'A1');
    controller.jumpSelectionByOccupancy(-1, 0);
    expect(controller.selection.focus.a1, 'A1');
    controller.jumpSelectionByOccupancy(0, 1);
    expect(controller.selection.focus.a1, 'A1');
  });

  testWidgets('sheet Ctrl+arrow keys follow same occupancy', (
    WidgetTester tester,
  ) async {
    final SheetEditorController controller = SheetEditorController();
    controller.sheet.cellA1('A1').value = 1;
    controller.sheet.cellA1('C1').value = 3;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 640,
          height: 400,
          child: QudsSheetEditor(controller: controller),
        ),
      ),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(SheetGrid)) + const Offset(60, 58),
    );
    await tester.pump();
    expect(controller.selection.focus.a1, 'A1');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.selection.focus.a1, 'C1');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.selection.focus.a1, 'C1');
  });

  test('sheet controller ctrl+a selects the used range', () {
    final SheetEditorController controller = SheetEditorController();
    controller.sheet.cellA1('A1').value = 1;
    controller.sheet.cellA1('C4').value = 9;
    controller.selection.selectCell(const SmlCellRef(0, 0));
    controller.selectAll();
    expect(controller.selection.anchor.a1, 'A1');
    expect(controller.selection.focus.a1, 'C4');
  });

  test('slide controller selectAll selects text while editing', () {
    final SlideEditorController controller = SlideEditorController(
      presentation: PmlPresentation(
        slides: <PmlSlide>[
          PmlSlide(
            id: 256,
            shapes: <PmlShape>[
              PmlShape(id: 2, name: 'Title', text: 'Hello'),
            ],
          ),
        ],
      ),
    );
    controller.selectShape(controller.slide.shapes.first);
    controller.beginTextEdit();
    controller.textEditor.setCaret(2);
    controller.selectAll();
    expect(controller.textEditor.selectionBase, 0);
    expect(controller.textEditor.caretIndex, 5);
    expect(controller.textEditor.hasSelection, isTrue);
  });

  test('reorderSlide moves a deck card and keeps the active index', () {
    final PmlSlide first = PmlSlide(
      id: 256,
      shapes: <PmlShape>[PmlShape(id: 2, name: 'A', text: 'A')],
    );
    final PmlSlide second = PmlSlide(
      id: 257,
      shapes: <PmlShape>[PmlShape(id: 2, name: 'B', text: 'B')],
    );
    final PmlSlide third = PmlSlide(
      id: 258,
      shapes: <PmlShape>[PmlShape(id: 2, name: 'C', text: 'C')],
    );
    final SlideEditorController controller = SlideEditorController(
      presentation: PmlPresentation(
        slides: <PmlSlide>[first, second, third],
      ),
    );
    controller.setActiveSlide(0);
    controller.reorderSlide(0, 2);
    expect(controller.presentation.slides.map((PmlSlide s) => s.id), <int>[
      257,
      258,
      256,
    ]);
    expect(controller.activeSlideIndex, 2);
    controller.undo();
    expect(controller.presentation.slides.first.id, 256);
    expect(controller.activeSlideIndex, 0);
  });

  test('slide text edit selects a word, paragraph, and drag range', () {
    final SlideEditorController controller = SlideEditorController(
      presentation: PmlPresentation(
        slides: <PmlSlide>[
          PmlSlide(
            id: 256,
            shapes: <PmlShape>[
              PmlShape(
                id: 2,
                name: 'Title',
                text: 'Quds Office\nStudio toolbar',
              ),
            ],
          ),
        ],
      ),
    );
    controller.selectShape(controller.slide.shapes.first);
    controller.beginTextEdit();
    controller.selectTextWordAt(6);
    expect(
      controller.textEditor.formulaBar.substring(
        controller.textEditor.selectionStart,
        controller.textEditor.selectionEnd,
      ),
      'Office',
    );
    controller.selectTextParagraphAt(14);
    expect(
      controller.textEditor.formulaBar.substring(
        controller.textEditor.selectionStart,
        controller.textEditor.selectionEnd,
      ),
      'Studio toolbar',
    );
    controller.placeTextCaret(0);
    controller.placeTextCaret(4, extend: true);
    expect(controller.textEditor.selectionStart, 0);
    expect(controller.textEditor.caretIndex, 4);
    expect(controller.textEditor.hasSelection, isTrue);
  });

  test('word controller formats only the selected range', () {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument.empty(text: 'Hello world'),
    );
    controller.caret
      ..logicalIndex = 5
      ..selectionAnchor = 0;
    controller.applyRunFormat((WmlRunProps p) => p.bold = true);
    final List<WmlRun> runs = controller.document.paragraphs.first.inlines
        .whereType<WmlRun>()
        .toList();
    expect(runs.length, greaterThanOrEqualTo(2));
    expect(runs.first.text, 'Hello');
    expect(runs.first.properties.bold, isTrue);
    expect(
      runs.any((WmlRun r) => r.text.contains('world') && !r.properties.bold),
      isTrue,
    );
    final LaidOutDocument laid = controller.laidOut;
    final List<LaidOutGlyph> glyphs = laid.pages.first.lines
        .expand((LaidOutLine line) => line.glyphs)
        .toList();
    expect(glyphs.where((LaidOutGlyph g) => g.bold).length, 5);
    expect(glyphs.where((LaidOutGlyph g) => !g.bold).length, greaterThan(0));
  });

  test('word controller applies font face and size at the caret run', () {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument.empty(text: 'Hello world'),
    );
    controller.caret
      ..logicalIndex = 1
      ..collapseSelection();
    controller.applyRunFormat((WmlRunProps p) {
      p.asciiFont = 'Tajawal';
      p.csFont = 'Tajawal';
      p.fontSizeHalfPoints = 28;
    });
    final WmlRun run = controller.document.paragraphs.first.inlines
        .whereType<WmlRun>()
        .first;
    expect(run.properties.asciiFont, 'Tajawal');
    expect(run.properties.fontSizeHalfPoints, 28);
    expect(controller.laidOut.pages, isNotEmpty);
    expect(
      controller.laidOut.pages.first.lines
          .expand((LaidOutLine line) => line.glyphs)
          .any((LaidOutGlyph g) => g.fontFamily == 'Tajawal'),
      isTrue,
    );
  });

  test('word controller extends selection across table cells', () {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlTable(
                grid: <double>[140, 140],
                rows: <WmlTableRow>[
                  WmlTableRow(
                    cells: <WmlTableCell>[
                      WmlTableCell(
                        blocks: <WmlBlock>[
                          WmlParagraph(
                            inlines: <WmlInline>[WmlRun(text: 'Left')],
                          ),
                        ],
                      ),
                      WmlTableCell(
                        blocks: <WmlBlock>[
                          WmlParagraph(
                            inlines: <WmlInline>[WmlRun(text: 'Right')],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    controller.caret
      ..paragraphIndex = 0
      ..logicalIndex = 0
      ..collapseSelection();
    controller.moveCaret(10, extend: true);
    expect(controller.caret.paragraphIndex, 1);
    expect(controller.caret.logicalIndex, 5);
    expect(controller.caret.selectionAnchorParagraph, 0);
    expect(controller.caret.coversParagraph(0), isTrue);
    expect(controller.caret.coversParagraph(1), isTrue);
    controller.applyRunFormat((WmlRunProps p) => p.bold = true);
    final List<WmlParagraph> paras = controller.document.paragraphs.toList();
    expect(
      paras[0].inlines.whereType<WmlRun>().every(
        (WmlRun r) => r.properties.bold,
      ),
      isTrue,
    );
    expect(
      paras[1].inlines.whereType<WmlRun>().any((WmlRun r) => r.properties.bold),
      isTrue,
    );
  });

  test('word caret lands on a chart between paragraphs and can delete it', () {
    final WmlVisual chart = WmlVisual(
      visual: OfficeVisual(
        kind: OfficeVisualKind.chartColumn,
        title: 'Sales',
        points: OfficeVisual.sampleSeries(),
      ),
    );
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Before')]),
              chart,
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'After')]),
            ],
          ),
        ],
      ),
    );
    controller.caret
      ..paragraphIndex = 0
      ..logicalIndex = 6
      ..collapseSelection();
    controller.moveCaret(1);
    expect(controller.selectedVisual, same(chart));
    expect(controller.document.visuals.length, 1);
    controller.deleteSelectionOr(backward: false);
    expect(controller.document.visuals, isEmpty);
    expect(controller.selectedVisual, isNull);
    expect(controller.document.sections.first.blocks.length, 2);
    controller.undo();
    expect(controller.document.visuals.length, 1);
    expect(controller.selectedVisual, same(chart));
    controller.cycleSelectedVisualKind();
    expect(chart.visual.kind, OfficeVisualKind.chartBar);
    controller.mutateSelectedVisual((OfficeVisual visual) {
      visual
        ..cycleTitle(arabic: false)
        ..addSamplePoint(arabic: false)
        ..chart.showDataLabels = true;
    });
    expect(chart.visual.points, hasLength(5));
    expect(chart.visual.chart.showDataLabels, isTrue);
    controller.undo();
    expect(chart.visual.points, hasLength(4));
  });

  test('word range selection includes a chart between paragraphs', () {
    final WmlVisual chart = WmlVisual(
      visual: OfficeVisual(
        kind: OfficeVisualKind.chartColumn,
        title: 'Mix',
        points: OfficeVisual.sampleSeries(),
      ),
    );
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Title')]),
              chart,
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Body')]),
            ],
          ),
        ],
      ),
    );
    controller.caret
      ..paragraphIndex = 0
      ..logicalIndex = 0
      ..collapseSelection();
    controller.moveCaret(12, extend: true);
    expect(controller.caret.paragraphIndex, 1);
    expect(controller.visualsInSelection, contains(chart));
    expect(controller.isVisualInSelection(chart.visual), isTrue);
    controller.deleteSelectionOr(backward: true);
    expect(controller.document.visuals, isEmpty);
    expect(controller.document.paragraphs.first.text, isEmpty);
  });

  test('word arrows move the caret along a line', () {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument.empty(text: 'Hello'),
    );
    controller.caret
      ..logicalIndex = 2
      ..collapseSelection();
    controller.moveCaretVisual(toRight: true);
    expect(controller.caret.logicalIndex, greaterThan(2));
    controller.moveCaretVisual(toRight: false);
    expect(controller.caret.logicalIndex, 2);
    controller.selectAll();
    expect(controller.caret.logicalIndex, 5);
    expect(controller.caret.selectionAnchor, 0);
  });

  test('sheet controller selects a drawing and can delete it', () {
    final SmlDrawing drawing = SmlDrawing(
      visual: OfficeVisual(
        kind: OfficeVisualKind.chartPie,
        title: 'Share',
        points: OfficeVisual.sampleSeries(),
      ),
      col: 3,
      row: 1,
    );
    final SheetEditorController controller = SheetEditorController(
      workbook: SmlWorkbook(
        sheets: <SmlWorksheet>[
          SmlWorksheet(name: 'Sheet1', sheetId: 1, drawings: <SmlDrawing>[drawing]),
        ],
      ),
    );
    controller.selectDrawing(0);
    expect(controller.selectedDrawing, same(drawing));
    controller.clearSelectedCells();
    expect(controller.sheet.drawings, isEmpty);
    expect(controller.selectedDrawingIndex, isNull);
    controller.undo();
    expect(controller.sheet.drawings, contains(drawing));
    controller.selectDrawing(0);
    controller.nudgeSelectedDrawing(1, 2);
    expect(drawing.col, 4);
    expect(drawing.row, 3);
    controller.selectDrawing(0);
    controller.mutateSelectedDrawing((OfficeVisual visual) {
      visual.kind = OfficeVisualKind.chartLine;
      visual.chart.showLegend = false;
    });
    expect(drawing.visual.kind, OfficeVisualKind.chartLine);
    expect(drawing.visual.chart.showLegend, isFalse);
    controller.undo();
    expect(drawing.visual.kind, OfficeVisualKind.chartPie);
    controller.selectDrawing(0);
    controller.beginDrawingTransform();
    controller.previewDrawingMove(40, 20);
    controller.commitDrawingTransform();
    expect(drawing.col, greaterThanOrEqualTo(4));
    controller.undo();
    expect(drawing.offsetX, 0);
  });

  test('linked sheet chart follows evaluated cells including zero', () {
    final SmlWorkbook book = SmlWorkbook(
      sheets: <SmlWorksheet>[SmlWorksheet(name: 'Data', sheetId: 1)],
    );
    final SmlWorksheet sheet = book.sheets.first;
    sheet.cell(const SmlCellRef(0, 0)).value = 'Q1';
    sheet.cell(const SmlCellRef(1, 0)).value = 'Q2';
    sheet.cell(const SmlCellRef(0, 0)).type = SmlCellType.string;
    sheet.cell(const SmlCellRef(1, 0)).type = SmlCellType.string;
    sheet.cell(const SmlCellRef(0, 1)).value = 10;
    sheet.cell(const SmlCellRef(1, 1)).value = 20;
    sheet.drawings.add(
      SmlDrawing(
        visual: OfficeVisual(
          kind: OfficeVisualKind.chartColumn,
          points: OfficeVisual.sampleSeries(),
        ),
        sourceFromA1: 'A2',
        sourceToA1: 'B2',
      ),
    );
    final SheetEditorController controller = SheetEditorController(workbook: book);
    expect(controller.sheet.drawings.first.visual.points[0].value, 10);
    expect(controller.sheet.drawings.first.visual.points[1].value, 20);
    sheet.cell(const SmlCellRef(1, 1)).value = 0;
    controller.recalculateWorkbook();
    expect(controller.sheet.drawings.first.visual.points[1].value, 0);
    sheet.cell(const SmlCellRef(1, 1)).value = 44;
    controller.recalculateWorkbook();
    expect(controller.sheet.drawings.first.visual.points[1].value, 44);
  });

  testWidgets('sheet chart drag on the canvas moves the drawing', (
    WidgetTester tester,
  ) async {
    final SmlDrawing drawing = SmlDrawing(
      visual: OfficeVisual(
        kind: OfficeVisualKind.chartColumn,
        title: 'Budget',
        points: OfficeVisual.sampleSeries(),
        width: 200,
        height: 120,
      ),
      col: 0,
      row: 0,
    );
    final SheetEditorController controller = SheetEditorController(
      workbook: SmlWorkbook(
        sheets: <SmlWorksheet>[
          SmlWorksheet(
            name: 'Sheet1',
            sheetId: 1,
            drawings: <SmlDrawing>[drawing],
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 640,
          height: 400,
          child: QudsSheetEditor(controller: controller),
        ),
      ),
    );
    await tester.pump();
    final Offset origin = tester.getTopLeft(find.byType(SheetGrid));
    await tester.timedDragFrom(
      origin + const Offset(28 + 40, 28 + 20 + 40),
      const Offset(80, 30),
      const Duration(milliseconds: 240),
    );
    await tester.pump();
    expect(controller.selectedDrawingIndex, 0);
    expect(
      drawing.col > 0 || drawing.offsetX > 8,
      isTrue,
    );
  });

  test('sheet controller clears the selected cell', () {
    final SheetEditorController controller = SheetEditorController();
    controller.selection.selectCell(const SmlCellRef(0, 0));
    controller.beginCellEdit(initial: '42', replace: true);
    controller.commitCellEdit();
    expect(controller.sheet.cell(const SmlCellRef(0, 0)).asString, '42');
    controller.clearSelectedCells();
    expect(controller.sheet.cell(const SmlCellRef(0, 0)).asString, isEmpty);
    controller.undo();
    expect(controller.sheet.cell(const SmlCellRef(0, 0)).asString, '42');
  });

  test('sheet controller edits a cell and can save bytes', () {
    final SheetEditorController controller = SheetEditorController();
    controller.selection.selectCell(const SmlCellRef(0, 0));
    controller.beginCellEdit(initial: '42', replace: true);
    controller.commitCellEdit();
    expect(controller.sheet.cell(const SmlCellRef(0, 0)).asString, '42');
    expect(controller.saveBytes().length, greaterThan(100));
    controller.undo();
    expect(controller.sheet.cell(const SmlCellRef(0, 0)).asString, isEmpty);
  });

  test('sheet cell display evaluates formulas and edits in place', () {
    final SheetEditorController controller = SheetEditorController(
      workbook: SmlWorkbook(
        sheets: <SmlWorksheet>[
          SmlWorksheet(name: 'Sheet1', sheetId: 1),
        ],
      ),
    );
    controller.sheet.cell(const SmlCellRef(0, 0)).value = 2;
    controller.sheet.cell(const SmlCellRef(0, 0)).type = SmlCellType.number;
    controller.sheet.cell(const SmlCellRef(1, 0)).value = 3;
    controller.sheet.cell(const SmlCellRef(1, 0)).type = SmlCellType.number;
    final SmlCell sum = controller.sheet.cell(const SmlCellRef(2, 0));
    sum.type = SmlCellType.formula;
    sum.formula = '=A1+B1';
    sum.value = sum.formula;
    expect(controller.cellDisplayText(sum), '5');
    controller.selection.selectCell(const SmlCellRef(2, 0));
    controller.beginCellEdit();
    expect(controller.cellEditor.editing, isTrue);
    expect(controller.cellDisplayText(sum), '=A1+B1');
    controller.cellEditor.formulaBar = '9';
    controller.commitCellEdit();
    expect(controller.sheet.cell(const SmlCellRef(2, 0)).asString, '9');
  });

  test('sheet commit evaluates formula and recalculates dependents', () {
    final SheetEditorController controller = SheetEditorController();
    controller.selection.selectCell(const SmlCellRef(0, 0));
    controller.beginCellEdit(initial: '2', replace: true);
    controller.commitCellEdit();
    controller.selection.selectCell(const SmlCellRef(1, 0));
    controller.beginCellEdit(initial: '3', replace: true);
    controller.commitCellEdit();
    controller.selection.selectCell(const SmlCellRef(2, 0));
    controller.beginCellEdit(initial: '=A1+B1', replace: true);
    expect(controller.cellEditor.formulaBar, '=A1+B1');
    controller.commitCellEdit();
    final SmlCell sum = controller.sheet.cell(const SmlCellRef(2, 0));
    expect(sum.formula, '=A1+B1');
    expect(sum.value, 5);
    expect(controller.cellDisplayText(sum), '5');
    expect(controller.formulaBarText, '=A1+B1');

    controller.selection.selectCell(const SmlCellRef(0, 0));
    controller.beginCellEdit(initial: '10', replace: true);
    controller.commitCellEdit();
    expect(controller.cellDisplayText(sum), '13');
    expect(sum.value, 13);
    expect(sum.formula, '=A1+B1');

    controller.selection.selectCell(const SmlCellRef(2, 0));
    controller.beginCellEdit();
    expect(controller.cellDisplayText(sum), '=A1+B1');
    final List<(FormulaRefSpan, Color)> highlights =
        FormulaRefStyle.colored(controller.cellEditor.formulaBar);
    expect(highlights, hasLength(2));
    expect(highlights[0].$2, FormulaRefStyle.palette[0]);
    expect(highlights[1].$2, FormulaRefStyle.palette[1]);
    expect(
      FormulaRefStyle.colored('=A1+A1').map(((FormulaRefSpan, Color) e) => e.$2),
      everyElement(FormulaRefStyle.palette[0]),
    );
    controller.cancelCellEdit();
    expect(controller.cellDisplayText(sum), '13');
  });

  test('sheet edit backspace deletes and function suggestions apply', () {
    final SheetEditorController controller = SheetEditorController();
    controller.selection.selectCell(const SmlCellRef(0, 0));
    controller.beginCellEdit(initial: '=SU', replace: true);
    expect(controller.functionSuggestions.map((FormulaFnDoc d) => d.name),
        contains('SUM'));
    expect(controller.highlightedFunction, isNotNull);
    controller.deleteEditBackward();
    expect(controller.cellEditor.formulaBar, '=S');
    controller.cellEditor.replaceRange(
      controller.cellEditor.caretIndex,
      controller.cellEditor.caretIndex,
      'U',
    );
    expect(controller.applyFunctionSuggestion(), isTrue);
    expect(controller.cellEditor.formulaBar, startsWith('=SUM('));
    expect(controller.cellEditor.editing, isTrue);
    expect(controller.functionSuggestions, isEmpty);
  });

  test('sheet edit click points at another cell instead of committing', () {
    final SheetEditorController controller = SheetEditorController();
    controller.selection.selectCell(const SmlCellRef(2, 0));
    controller.beginCellEdit(initial: '=', replace: true);
    controller.pointEditRef(const SmlCellRef(0, 0));
    expect(controller.cellEditor.editing, isTrue);
    expect(controller.cellEditor.formulaBar, '=A1');
    expect(controller.selection.focus.a1, 'C1');
    controller.pointEditRef(const SmlCellRef(1, 0));
    expect(controller.cellEditor.formulaBar, '=B1');
    controller.cellEditor.replaceRange(
      controller.cellEditor.caretIndex,
      controller.cellEditor.caretIndex,
      '+',
    );
    controller.pointEditRef(const SmlCellRef(2, 1));
    expect(controller.cellEditor.formulaBar, '=B1+C2');
    controller.pointEditRef(const SmlCellRef(3, 2), extend: true);
    expect(controller.cellEditor.formulaBar, '=B1+C2:D3');
    expect(controller.cellEditor.editing, isTrue);
    expect(controller.selection.focus.a1, 'C1');
  });

  testWidgets('tapping another cell inserts a formula reference', (
    WidgetTester tester,
  ) async {
    final SheetEditorController controller = SheetEditorController();
    controller.selection.selectCell(const SmlCellRef(2, 0));
    controller.beginCellEdit(initial: '=', replace: true);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 640,
          height: 400,
          child: QudsSheetEditor(controller: controller),
        ),
      ),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(SheetGrid)) + const Offset(60, 58),
    );
    await tester.pump();
    expect(controller.cellEditor.editing, isTrue);
    expect(controller.cellEditor.formulaBar, '=A1');
    expect(controller.selection.focus.a1, 'C1');
  });

  test('slide controller edits shape text in place', () {
    final PmlShape shape = PmlShape(id: 2, name: 'Title', text: 'Hello');
    final SlideEditorController controller = SlideEditorController(
      presentation: PmlPresentation(
        slides: <PmlSlide>[
          PmlSlide(id: 256, shapes: <PmlShape>[shape]),
        ],
      ),
    );
    controller.selectShape(shape);
    controller.beginTextEdit(initial: 'Hi there', replace: true);
    expect(shape.text, 'Hi there');
    expect(controller.editingText, isTrue);
    controller.commitTextEdit();
    expect(controller.editingText, isFalse);
    expect(shape.text, 'Hi there');
    controller.undo();
    expect(shape.text, 'Hello');
  });

  test('word clipboard pastes source formatting or plain text', () async {
    OfficeClipboard.instance.useSystem = false;
    OfficeClipboard.instance.clear();
    final WmlParagraph para = WmlParagraph(
      inlines: <WmlInline>[
        WmlRun(text: 'Bold', properties: WmlRunProps(bold: true)),
        WmlRun(text: 'Plain'),
      ],
    );
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(blocks: <WmlBlock>[para]),
        ],
      ),
    );
    controller.caret
      ..selectionAnchor = 0
      ..logicalIndex = 4;
    expect(controller.canCopy, isTrue);
    await controller.copyToClipboard();
    controller.caret
      ..logicalIndex = para.text.length
      ..collapseSelection();
    await controller.pasteFromClipboard();
    expect(controller.document.paragraphs.first.text, 'BoldPlainBold');
    final WmlRun pasted = controller.document.paragraphs.first.inlines
        .whereType<WmlRun>()
        .last;
    expect(pasted.properties.bold, isTrue);
    await controller.pasteFromClipboard(mode: OfficePasteMode.keepTextOnly);
    expect(controller.document.paragraphs.first.text, 'BoldPlainBoldBold');
    OfficeClipboard.instance.useSystem = true;
  });

  test('word cut paste restores heading style and table structure', () async {
    OfficeClipboard.instance.useSystem = false;
    OfficeClipboard.instance.clear();
    final WmlParagraph heading = WmlParagraph(
      properties: WmlParagraphProps(headingLevel: 2, styleId: 'Heading2'),
      inlines: <WmlInline>[
        WmlRun(
          text: 'Tool map',
          properties: WmlRunProps(
            bold: true,
            color: '1F4E79',
            fontSizeHalfPoints: 28,
          ),
        ),
      ],
    );
    final WmlTable table = WmlTable(
      grid: <double>[120, 120],
      rows: <WmlTableRow>[
        WmlTableRow(
          cells: <WmlTableCell>[
            WmlTableCell(
              fillColor: '1F4E79',
              blocks: <WmlBlock>[
                WmlParagraph(
                  inlines: <WmlInline>[
                    WmlRun(
                      text: 'Surface',
                      properties: WmlRunProps(bold: true, color: 'FFFFFF'),
                    ),
                  ],
                ),
              ],
            ),
            WmlTableCell(
              fillColor: '1F4E79',
              blocks: <WmlBlock>[
                WmlParagraph(
                  inlines: <WmlInline>[
                    WmlRun(
                      text: 'Status',
                      properties: WmlRunProps(bold: true, color: 'FFFFFF'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(blocks: <WmlBlock>[heading, table]),
        ],
      ),
    );
    controller.selectAll();
    await controller.cutToClipboard();
    expect(controller.document.sections.first.blocks.length, 1);
    expect(controller.document.sections.first.blocks.first, isA<WmlParagraph>());
    expect(
      controller.document.sections.first.blocks.whereType<WmlTable>(),
      isEmpty,
    );
    await controller.pasteFromClipboard();
    final List<WmlBlock> blocks = controller.document.sections.first.blocks;
    expect(blocks[0], isA<WmlParagraph>());
    expect((blocks[0] as WmlParagraph).properties.headingLevel, 2);
    expect((blocks[0] as WmlParagraph).text, 'Tool map');
    expect(blocks[1], isA<WmlTable>());
    final WmlTable pasted = blocks[1] as WmlTable;
    expect(pasted.rows.first.cells.first.fillColor, '1F4E79');
    expect(
      (pasted.rows.first.cells.first.blocks.first as WmlParagraph).text,
      'Surface',
    );
    OfficeClipboard.instance.useSystem = true;
  });

  test('word merge and split consecutive table cells', () {
    final WmlTable table = WmlTable(
      grid: <double>[80, 80],
      rows: <WmlTableRow>[
        WmlTableRow(
          cells: <WmlTableCell>[
            WmlTableCell(
              blocks: <WmlBlock>[
                WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'A')]),
              ],
            ),
            WmlTableCell(
              blocks: <WmlBlock>[
                WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'B')]),
              ],
            ),
          ],
        ),
      ],
    );
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(blocks: <WmlBlock>[table]),
        ],
      ),
    );
    controller.caret
      ..selectionAnchorParagraph = 0
      ..selectionAnchor = 0
      ..paragraphIndex = 1
      ..logicalIndex = 1;
    expect(controller.canMergeTableCells, isTrue);
    controller.mergeTableCells();
    expect(table.rows.first.cells.length, 1);
    expect(table.rows.first.cells.first.gridSpan, 2);
    expect(controller.canUnmergeTableCells, isTrue);
    controller.unmergeTableCells();
    expect(table.rows.first.cells.length, 2);
    expect(table.rows.first.cells.first.gridSpan, 1);
  });

  test('word page margins and orientation update layout', () {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument.empty(text: 'Hi'),
    );
    final double before = controller.document.sections.first.contentWidth;
    controller.setPageMargins(WmlPageMargins.narrow);
    expect(controller.pageMargins.matches(WmlPageMargins.narrow), isTrue);
    expect(
      controller.document.sections.first.contentWidth,
      greaterThan(before),
    );
    controller.setPageLandscape(true);
    expect(controller.isPageLandscape, isTrue);
    controller.undo();
    expect(controller.isPageLandscape, isFalse);
    expect(controller.pageCount, greaterThan(0));
  });

  test('selectTable covers every cell paragraph', () {
    final WmlParagraph a = WmlParagraph(
      inlines: <WmlInline>[WmlRun(text: 'A')],
    );
    final WmlParagraph b = WmlParagraph(
      inlines: <WmlInline>[WmlRun(text: 'B')],
    );
    final WmlParagraph c = WmlParagraph(
      inlines: <WmlInline>[WmlRun(text: 'C')],
    );
    final WmlTable table = WmlTable(
      grid: <double>[80, 80],
      rows: <WmlTableRow>[
        WmlTableRow(
          cells: <WmlTableCell>[
            WmlTableCell(blocks: <WmlBlock>[a]),
            WmlTableCell(blocks: <WmlBlock>[b]),
          ],
        ),
        WmlTableRow(
          cells: <WmlTableCell>[
            WmlTableCell(blocks: <WmlBlock>[c]),
            WmlTableCell(
              blocks: <WmlBlock>[
                WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'D')]),
              ],
            ),
          ],
        ),
      ],
    );
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Before')]),
              table,
            ],
          ),
        ],
      ),
    );
    controller.selectTable(table);
    expect(controller.selectedTable, same(table));
    expect(controller.caret.coversParagraph(1), isTrue);
    expect(controller.caret.coversParagraph(2), isTrue);
    expect(controller.caret.coversParagraph(3), isTrue);
    expect(controller.caret.coversParagraph(4), isTrue);
    expect(controller.caret.coversParagraph(0), isFalse);
  });

  test('selectTableBand selects a column or row without the whole table', () {
    final WmlParagraph a = WmlParagraph(
      inlines: <WmlInline>[WmlRun(text: 'A')],
    );
    final WmlParagraph b = WmlParagraph(
      inlines: <WmlInline>[WmlRun(text: 'B')],
    );
    final WmlParagraph c = WmlParagraph(
      inlines: <WmlInline>[WmlRun(text: 'C')],
    );
    final WmlParagraph d = WmlParagraph(
      inlines: <WmlInline>[WmlRun(text: 'D')],
    );
    final WmlTable table = WmlTable(
      grid: <double>[80, 80],
      rows: <WmlTableRow>[
        WmlTableRow(
          cells: <WmlTableCell>[
            WmlTableCell(blocks: <WmlBlock>[a]),
            WmlTableCell(blocks: <WmlBlock>[b]),
          ],
        ),
        WmlTableRow(
          cells: <WmlTableCell>[
            WmlTableCell(blocks: <WmlBlock>[c]),
            WmlTableCell(blocks: <WmlBlock>[d]),
          ],
        ),
      ],
    );
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Before')]),
              table,
            ],
          ),
        ],
      ),
    );
    controller.selectTableBand(table, column: true, from: 0, to: 0);
    expect(controller.selectedTable, isNull);
    expect(controller.selectedTableBand?.column, isTrue);
    expect(controller.selectedTableBand?.from, 0);
    expect(controller.selectedTableBand?.to, 0);
    expect(controller.caret.coversParagraph(1), isTrue);
    expect(controller.caret.coversParagraph(3), isTrue);

    controller.selectTableBand(table, column: false, from: 0, to: 0);
    expect(controller.selectedTableBand?.column, isFalse);
    expect(controller.caret.coversParagraph(1), isTrue);
    expect(controller.caret.coversParagraph(2), isTrue);
    expect(controller.caret.coversParagraph(3), isFalse);

    controller.selectTableBand(table, column: true, from: 0, to: 1);
    expect(controller.selectedTableBand?.from, 0);
    expect(controller.selectedTableBand?.to, 1);
    expect(controller.caret.coversParagraph(1), isTrue);
    expect(controller.caret.coversParagraph(4), isTrue);

    controller.selectTable(table);
    expect(controller.selectedTableBand, isNull);
    expect(controller.selectedTable, same(table));
  });

  test('insertSectionBreak and header edit target the active section', () {
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'First')]),
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Second')]),
            ],
          ),
        ],
      ),
    );
    controller.caret
      ..paragraphIndex = 0
      ..logicalIndex = 5
      ..collapseSelection();
    controller.insertSectionBreak();
    expect(controller.document.sections.length, 2);
    expect(controller.document.sections.first.blocks.length, 1);
    expect(controller.sectionIndexAtCaret, 1);

    controller.beginHeaderFooterEdit(0, footer: false);
    expect(controller.isEditingHeader, isTrue);
    expect(controller.headerFooterParagraphs, isNotEmpty);
    controller.insertText('Banner');
    expect(controller.document.sections.first.header.first.text, 'Banner');
    controller.endHeaderFooterEdit();
    expect(controller.isEditingHeaderFooter, isFalse);
    expect(controller.document.paragraphs.first.text, 'First');
  });

  test('word delete removes a selected table instead of emptying it', () {
    final WmlParagraph before = WmlParagraph(
      inlines: <WmlInline>[WmlRun(text: 'Before')],
    );
    final WmlTable table = WmlTable(
      grid: <double>[80],
      rows: <WmlTableRow>[
        WmlTableRow(
          cells: <WmlTableCell>[
            WmlTableCell(
              fillColor: '1F4E79',
              blocks: <WmlBlock>[
                WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Cell')]),
              ],
            ),
          ],
        ),
      ],
    );
    final WmlParagraph after = WmlParagraph(
      inlines: <WmlInline>[WmlRun(text: 'After')],
    );
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(blocks: <WmlBlock>[before, table, after]),
        ],
      ),
    );
    controller.selectTable(table);
    controller.deleteSelectionOr(backward: true);
    expect(
      controller.document.sections.first.blocks.whereType<WmlTable>(),
      isEmpty,
    );
    expect(
      controller.document.sections.first.blocks.whereType<WmlParagraph>().length,
      2,
    );
    expect(controller.document.paragraphs.first.text, 'Before');
    expect(controller.document.paragraphs.last.text, 'After');
  });

  test('word delete of a spanning selection removes the table', () {
    final WmlParagraph before = WmlParagraph(
      inlines: <WmlInline>[WmlRun(text: 'Before')],
    );
    final WmlTable table = WmlTable(
      grid: <double>[80],
      rows: <WmlTableRow>[
        WmlTableRow(
          cells: <WmlTableCell>[
            WmlTableCell(
              blocks: <WmlBlock>[
                WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Cell')]),
              ],
            ),
          ],
        ),
      ],
    );
    final WmlParagraph after = WmlParagraph(
      inlines: <WmlInline>[WmlRun(text: 'After')],
    );
    final WordEditorController controller = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(blocks: <WmlBlock>[before, table, after]),
        ],
      ),
    );
    controller.selectAll();
    controller.deleteSelectionOr(backward: true);
    expect(
      controller.document.sections.first.blocks.whereType<WmlTable>(),
      isEmpty,
    );
    expect(controller.document.paragraphs.first.text, '');
  });

  test('sheet clipboard copies a range and pastes values', () async {
    OfficeClipboard.instance.useSystem = false;
    OfficeClipboard.instance.clear();
    final SheetEditorController controller = SheetEditorController();
    controller.sheet.cell(const SmlCellRef(0, 0)).value = 1;
    controller.sheet.cell(const SmlCellRef(1, 0)).formula = '=A1+1';
    controller.sheet.cell(const SmlCellRef(1, 0)).type = SmlCellType.formula;
    controller.selection
      ..selectCell(const SmlCellRef(0, 0))
      ..extendTo(const SmlCellRef(1, 0));
    await controller.copyToClipboard();
    controller.selection.selectCell(const SmlCellRef(0, 2));
    await controller.pasteFromClipboard();
    expect(controller.sheet.cell(const SmlCellRef(0, 2)).value, 1);
    expect(controller.sheet.cell(const SmlCellRef(1, 2)).formula, '=A1+1');
    controller.selection.selectCell(const SmlCellRef(0, 3));
    await controller.pasteFromClipboard(mode: OfficePasteMode.keepTextOnly);
    expect(controller.sheet.cell(const SmlCellRef(0, 3)).asString, '1');
    OfficeClipboard.instance.useSystem = true;
  });

  test('slide clipboard duplicates a selected shape', () async {
    OfficeClipboard.instance.useSystem = false;
    OfficeClipboard.instance.clear();
    final PmlShape shape = PmlShape(
      id: 2,
      name: 'Card',
      text: 'Hello',
      fillColor: '2B579A',
    );
    final SlideEditorController controller = SlideEditorController(
      presentation: PmlPresentation(
        slides: <PmlSlide>[
          PmlSlide(id: 256, shapes: <PmlShape>[shape]),
        ],
      ),
    );
    controller.selectShape(shape);
    await controller.copyToClipboard();
    await controller.pasteFromClipboard();
    expect(controller.slide.shapes.length, 2);
    expect(controller.slide.shapes.last.text, 'Hello');
    expect(controller.slide.shapes.last.fillColor, '2B579A');
    expect(controller.slide.shapes.last.id, isNot(shape.id));
    OfficeClipboard.instance.useSystem = true;
  });

  test('slide text edit keeps the shape rotation', () {
    final PmlShape shape = PmlShape(
      id: 2,
      name: 'Title',
      text: 'Hello',
      transform: const PmlTransform(x: 127000, y: 127000, rot: 1200000),
    );
    final SlideEditorController controller = SlideEditorController(
      presentation: PmlPresentation(
        slides: <PmlSlide>[
          PmlSlide(id: 256, shapes: <PmlShape>[shape]),
        ],
      ),
    );
    controller.selectShape(shape);
    controller.beginTextEdit();
    controller.textEditor.formulaBar = 'Edited';
    controller.commitTextEdit();
    expect(controller.editingText, isFalse);
    expect(shape.text, 'Edited');
    expect(shape.transform.rot, 1200000);
  });

  test('slide controller nudges a shape via undoable transform', () {
    final PmlShape shape = PmlShape(id: 2, name: 'Box', text: 'A');
    final SlideEditorController controller = SlideEditorController(
      presentation: PmlPresentation(
        slides: <PmlSlide>[
          PmlSlide(id: 256, shapes: <PmlShape>[shape]),
        ],
      ),
    );
    controller.selectShape(shape);
    final int x0 = shape.transform.x;
    controller.applyTransform(
      shape,
      PmlTransform(
        x: x0 + 25400,
        y: shape.transform.y,
        cx: shape.transform.cx,
        cy: shape.transform.cy,
        rot: 5400000,
      ),
    );
    expect(shape.transform.x, x0 + 25400);
    expect(shape.transform.rotationDegrees, 90);
    controller.undo();
    expect(shape.transform.x, x0);
    expect(shape.transform.rot, 0);
  });

  test('slide controller edits a picture visual', () {
    final OfficeVisual picture = OfficeVisual(
      kind: OfficeVisualKind.picture,
      imageBytes: PngBytes.studioCard(),
    );
    final PmlShape shape = PmlShape(
      id: 2,
      name: 'Photo',
      visual: picture,
    );
    final SlideEditorController controller = SlideEditorController(
      presentation: PmlPresentation(
        slides: <PmlSlide>[
          PmlSlide(id: 256, shapes: <PmlShape>[shape]),
        ],
      ),
    );
    controller.selectShape(shape);
    controller.mutateSelectedShapeVisual((OfficeVisual visual) {
      visual
        ..rotateBy(90)
        ..cropBy(0.08)
        ..cycleBorder();
    });
    expect(picture.picture.rotationDeg, 90);
    expect(picture.picture.borderWidth, greaterThan(0));
    controller.undo();
    expect(picture.picture.rotationDeg, 0);
  });

  test('slide controller applies transitions, animations, and slideshow clicks', () {
    final PmlShape shape = PmlShape(id: 2, name: 'Box', text: 'A');
    final SlideEditorController controller = SlideEditorController(
      presentation: PmlPresentation(
        slides: <PmlSlide>[
          PmlSlide(id: 256, shapes: <PmlShape>[shape]),
          PmlSlide(
            id: 257,
            shapes: <PmlShape>[PmlShape(id: 2, name: 'Next', text: 'B')],
          ),
        ],
      ),
    );
    controller.setSlideTransition(
      const PmlSlideTransition(kind: PmlTransitionKind.wipe),
      applyToAll: true,
    );
    expect(controller.presentation.slides[1].transition.kind, PmlTransitionKind.wipe);
    controller.selectShape(shape);
    controller.addShapeAnimation(PmlAnimPreset.fade);
    expect(controller.slide.animations, hasLength(1));
    controller.startShow(from: 0);
    expect(controller.isPresenting, isTrue);
    expect(controller.showSamples[2]?.visible, isFalse);
    controller.showNext();
    controller.tickShow(600);
    expect(controller.showSamples[2]?.visible, isTrue);
    controller.showNext();
    expect(controller.slideShow?.isTransitioning, isTrue);
    controller.endShow();
    expect(controller.isPresenting, isFalse);
    controller.setActiveSlide(0);
    controller.selectShape(shape);
    controller.addShapeAnimation(PmlAnimPreset.peekIn);
    controller.updateShapeAnimation(
      controller.selectedAnimationIndex!,
      direction: PmlTransitionDir.up,
      durationMs: 1200,
      delayMs: 250,
    );
    expect(controller.selectedAnimation!.direction, PmlTransitionDir.up);
    expect(controller.selectedAnimation!.durationMs, 1200);
    controller.previewAnimations();
    expect(controller.isPreviewing, isTrue);
    expect(controller.isPresenting, isFalse);
    controller.tickShow(80);
    expect(controller.slideShow?.slideIndex, 0);
    for (int i = 0; i < 80; i++) {
      controller.tickShow(32);
      if (!controller.isPreviewing) {
        break;
      }
    }
    expect(controller.isPreviewing, isFalse);
    controller.previewAnimations();
    expect(controller.isPreviewing, isTrue);
    for (int i = 0; i < 80; i++) {
      controller.tickShow(32);
      if (!controller.isPreviewing) {
        break;
      }
    }
    expect(controller.isPreviewing, isFalse);
  });

  test('theme copyWith and Arabic strings stay typed', () {
    final OfficeTheme branded = OfficeTheme.light.copyWith(
      selectionFill: const Color(0x3300AA55),
      fontFamily: 'Noto Naskh Arabic',
    );
    expect(branded.fontFamily, 'Noto Naskh Arabic');
    expect(
      const OfficeSurfaceConfig(
        strings: OfficeStrings.arabic,
      ).strings.wordEditor,
      'مستند وورد',
    );
  });

  testWidgets('QudsOfficeHost embeds a word editor with custom chrome', (
    WidgetTester tester,
  ) async {
    late OfficeController ready;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 600,
          child: QudsOfficeHost(
            kind: OpcPackageKind.word,
            config: const OfficeSurfaceConfig(
              mode: OfficeInteractionMode.viewing,
              theme: OfficeTheme.dark,
              showRulers: false,
            ),
            toolbarBuilder: (BuildContext context, OfficeController c) {
              return SizedBox(
                height: 28,
                child: Text(c.config.strings.viewing),
              );
            },
            onControllerReady: (OfficeController c) => ready = c,
          ),
        ),
      ),
    );
    expect(ready, isA<WordEditorController>());
    expect(ready.mode, OfficeInteractionMode.viewing);
    expect(find.text('Viewing'), findsOneWidget);
    expect(find.byType(WordCanvas), findsOneWidget);
  });

  testWidgets('QudsSheetEditor and QudsSlideEditor mount', (
    WidgetTester tester,
  ) async {
    final SheetEditorController sheet = SheetEditorController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 640,
          height: 400,
          child: QudsSheetEditor(controller: sheet),
        ),
      ),
    );
    expect(find.byType(SheetGrid), findsOneWidget);

    final SlideEditorController slides = SlideEditorController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 640,
          height: 400,
          child: QudsSlideEditor(
            controller: slides,
            config: const OfficeSurfaceConfig(
              mode: OfficeInteractionMode.selecting,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SlideStage), findsOneWidget);
  });

  test('choosing a transition or animation starts a quick preview', () {
    final PmlShape shape = PmlShape(id: 2, name: 'Box', text: 'A');
    final SlideEditorController controller = SlideEditorController(
      presentation: PmlPresentation(
        slides: <PmlSlide>[
          PmlSlide(id: 256, shapes: <PmlShape>[shape]),
          PmlSlide(id: 257),
        ],
      ),
    );
    controller.setSlideTransition(
      const PmlSlideTransition(kind: PmlTransitionKind.fade),
    );
    expect(controller.isPreviewing, isTrue);
    expect(controller.isPresenting, isFalse);
    controller.endShow();
    controller.selectShape(shape);
    controller.addShapeAnimation(PmlAnimPreset.flyIn);
    expect(controller.isPreviewing, isTrue);
    expect(controller.slide.animations, hasLength(1));
  });

  test('Morph preview uses the previous slide as the outgoing pair', () {
    final SlideEditorController controller = SlideEditorController(
      presentation: PmlPresentation(
        slides: <PmlSlide>[
          PmlSlide(
            id: 256,
            shapes: <PmlShape>[
              PmlShape(
                id: 2,
                name: 'Title',
                text: 'A',
                transform: const PmlTransform(x: 0, y: 0, cx: 1000000, cy: 1000000),
              ),
            ],
          ),
          PmlSlide(
            id: 257,
            shapes: <PmlShape>[
              PmlShape(
                id: 2,
                name: 'Title',
                text: 'A',
                transform: const PmlTransform(
                  x: 2000000,
                  y: 0,
                  cx: 1000000,
                  cy: 1000000,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    controller.setActiveSlide(1);
    controller.setSlideTransition(
      const PmlSlideTransition(kind: PmlTransitionKind.morph, durationMs: 400),
    );
    expect(controller.isPreviewing, isTrue);
    expect(controller.slideShow?.isTransitioning, isTrue);
    expect(controller.slideShow?.outgoingSlide?.id, 256);
    expect(controller.slide.transition.kind, PmlTransitionKind.morph);
    final PmlSlide outgoing = controller.slideShow!.outgoingSlide!;
    final List<PmlMorphFrame> mid = PmlMorph.frames(
      outgoing,
      controller.slide,
      0.5,
    );
    expect(mid, hasLength(1));
    expect(mid.first.transform.x, 1000000);
  });

  testWidgets('F5 starts and ends a slide show', (WidgetTester tester) async {
    final SlideEditorController slides = SlideEditorController(
      presentation: PmlPresentation(
        slides: <PmlSlide>[
          PmlSlide(id: 256, shapes: <PmlShape>[PmlShape(id: 2, name: 'A')]),
          PmlSlide(id: 257, shapes: <PmlShape>[PmlShape(id: 2, name: 'B')]),
        ],
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 640,
          height: 400,
          child: QudsSlideEditor(controller: slides),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pump();
    expect(slides.isPresenting, isTrue);
    expect(slides.activeSlideIndex, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pump();
    expect(slides.isPresenting, isFalse);
  });

  test('slide controller loads builder deck notes and word builder bytes', () {
    final Uint8List pptx =
        (PptxDeckBuilder()..addCoverSlide(title: 'Title', notes: 'Speak this'))
            .build();
    final SlideEditorController slides = SlideEditorController.fromBytes(pptx);
    expect(slides.speakerNotes, contains('Speak this'));
    expect(slides.saveBytes().isNotEmpty, isTrue);

    final Uint8List docx =
        (DocxDocumentBuilder()
              ..heading('Title')
              ..paragraph('Item A'))
            .build();
    final WordEditorController word = WordEditorController.fromBytes(docx);
    expect(
      word.document.paragraphs.map((WmlParagraph p) => p.text).join(' '),
      contains('Title'),
    );
  });

  test('word controller inserts and deletes table rows and columns', () {
    final WordEditorController word = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlTable(
                grid: <double>[120, 120],
                rows: <WmlTableRow>[
                  WmlTableRow(
                    cells: <WmlTableCell>[
                      WmlTableCell(
                        blocks: <WmlBlock>[
                          WmlParagraph(
                            inlines: <WmlInline>[WmlRun(text: 'A1')],
                          ),
                        ],
                      ),
                      WmlTableCell(
                        blocks: <WmlBlock>[
                          WmlParagraph(
                            inlines: <WmlInline>[WmlRun(text: 'B1')],
                          ),
                        ],
                      ),
                    ],
                  ),
                  WmlTableRow(
                    cells: <WmlTableCell>[
                      WmlTableCell(
                        blocks: <WmlBlock>[
                          WmlParagraph(
                            inlines: <WmlInline>[WmlRun(text: 'A2')],
                          ),
                        ],
                      ),
                      WmlTableCell(
                        blocks: <WmlBlock>[
                          WmlParagraph(
                            inlines: <WmlInline>[WmlRun(text: 'B2')],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    expect(word.isInTable, isTrue);
    expect(word.tableAtCaret?.row, 0);
    word.insertTableRow(after: true);
    final WmlTable table = word.document.sections.first.blocks.first as WmlTable;
    expect(table.rows.length, 3);
    word.undo();
    expect(table.rows.length, 2);
    word.insertTableColumn(after: true);
    expect(WordTable.columnCount(table), 3);
    word.deleteTableColumn();
    expect(WordTable.columnCount(table), 2);
  });

  test('word tab walks table cells across then down', () {
    final WordEditorController word = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlTable(
                grid: <double>[120, 120],
                rows: <WmlTableRow>[
                  WmlTableRow(
                    cells: <WmlTableCell>[
                      WmlTableCell(
                        blocks: <WmlBlock>[
                          WmlParagraph(
                            inlines: <WmlInline>[WmlRun(text: 'A1')],
                          ),
                        ],
                      ),
                      WmlTableCell(
                        blocks: <WmlBlock>[
                          WmlParagraph(
                            inlines: <WmlInline>[WmlRun(text: 'B1')],
                          ),
                        ],
                      ),
                    ],
                  ),
                  WmlTableRow(
                    cells: <WmlTableCell>[
                      WmlTableCell(
                        blocks: <WmlBlock>[
                          WmlParagraph(
                            inlines: <WmlInline>[WmlRun(text: 'A2')],
                          ),
                        ],
                      ),
                      WmlTableCell(
                        blocks: <WmlBlock>[
                          WmlParagraph(
                            inlines: <WmlInline>[WmlRun(text: 'B2')],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    expect(word.moveTableCell(forward: true), isTrue);
    expect(word.tableAtCaret?.row, 0);
    expect(word.tableAtCaret?.col, 1);
    expect(word.document.paragraphs.toList()[word.caret.paragraphIndex].text, 'B1');
    expect(word.moveTableCell(forward: true), isTrue);
    expect(word.tableAtCaret?.row, 1);
    expect(word.tableAtCaret?.col, 0);
    expect(word.document.paragraphs.toList()[word.caret.paragraphIndex].text, 'A2');
    expect(word.moveTableCell(forward: false), isTrue);
    expect(word.tableAtCaret?.row, 0);
    expect(word.tableAtCaret?.col, 1);
    expect(word.moveTableCell(forward: true), isTrue);
    expect(word.moveTableCell(forward: true), isTrue);
    expect(word.moveTableCell(forward: true), isTrue);
    expect(word.tableAtCaret?.row, 2);
    expect(word.tableAtCaret?.col, 0);
    expect(
      (word.document.sections.first.blocks.first as WmlTable).rows.length,
      3,
    );
  });

  test('sheet controller inserts rows and columns with undo', () {
    final SheetEditorController sheet = SheetEditorController();
    sheet.sheet.cellA1('A1').value = 10;
    sheet.sheet.cellA1('A2').value = 20;
    sheet.selection.selectCell(SmlCellRef.parse('A2'));
    sheet.insertSheetRows(after: false);
    expect(sheet.sheet.cellA1('A1').value, 10);
    expect(sheet.sheet.cellA1('A2').hasContent, isFalse);
    expect(sheet.sheet.cellA1('A3').value, 20);
    sheet.undo();
    expect(sheet.sheet.cellA1('A2').value, 20);
    sheet.selection.selectCell(SmlCellRef.parse('A1'));
    sheet.insertSheetCols(after: true);
    expect(sheet.sheet.cellA1('A1').value, 10);
    expect(sheet.sheet.cellA1('B1').hasContent, isFalse);
  });

  test('office context menu dismiss is safe to call twice', () {
    expect(() => OfficeContextMenu.dismiss(null), returnsNormally);
  });

  test('office context menu builds table actions', () {
    final WordEditorController word = WordEditorController();
    final WmlTable table = WmlTable(
      grid: <double>[80, 80],
      rows: <WmlTableRow>[
        WmlTableRow(
          cells: <WmlTableCell>[
            WmlTableCell(),
            WmlTableCell(),
          ],
        ),
      ],
    );
    final List<OfficeContextAction> actions = OfficeContextMenu.word(
      hit: OfficeContextHit(
        kind: OfficeContextKind.table,
        globalPosition: Offset.zero,
        table: table,
        tableRow: 0,
        tableCol: 0,
      ),
      controller: word,
    );
    expect(
      actions.map((OfficeContextAction a) => a.id),
      containsAll(<String>[
        'cut',
        'copy',
        'paste',
        'insertRowAbove',
        'insertRowBelow',
        'insertColLeft',
        'insertColRight',
        'mergeTableCells',
        'unmergeTableCells',
        'autoFitContents',
        'autoFitWindow',
        'autoFitFixed',
      ]),
    );
  });

  test('slide sorter hide and show actions toggle hidden with undo', () {
    final SlideEditorController slides = SlideEditorController(
      presentation: PmlPresentation(
        slides: <PmlSlide>[
          PmlSlide(id: 256),
          PmlSlide(id: 257),
        ],
      ),
    );
    expect(
      OfficeContextMenu.slideSorter(controller: slides, index: 0)
          .single
          .id,
      'hideSlide',
    );
    slides.setSlideHidden(0, true);
    expect(slides.presentation.slides.first.hidden, isTrue);
    expect(
      OfficeContextMenu.slideSorter(controller: slides, index: 0)
          .single
          .id,
      'showSlide',
    );
    slides.undo();
    expect(slides.presentation.slides.first.hidden, isFalse);
  });
}
