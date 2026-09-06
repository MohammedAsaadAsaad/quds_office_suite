import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

void main() {
  test('command pipeline undo/redo insert and delete', () {
    var text = 'ab';
    final CommandPipeline pipe = CommandPipeline();
    pipe.commit(
      InsertTextDelta(
        getText: () => text,
        setText: (String v) => text = v,
        index: 2,
        text: 'c',
      ),
    );
    expect(text, 'abc');
    pipe.undo();
    expect(text, 'ab');
    pipe.redo();
    expect(text, 'abc');
  });

  WmlDocument tableDoc() {
    return WmlDocument(
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
    );
  }

  test('paint run rebuilds logical Arabic for HarfBuzz', () {
    const String text = 'ملاحظات الميدان';
    expect(PaintRunText.looksRtl(text), isTrue);
    expect(PaintRunText.looksRtl('Hello'), isFalse);
    expect(
      PaintRunText.logicalSlice(text, <int>[0, 1, 2, 3, 4, 5, 6]),
      'ملاحظات',
    );
    expect(
      PaintRunText.logicalSlice(text, <int>[8, 9, 10, 11, 12, 13, 14]),
      'الميدان',
    );
    expect(
      PaintRunText.directionFor(bidiLevel: 1, text: text),
      TextDirection.rtl,
    );
    expect(
      PaintRunText.directionFor(bidiLevel: 0, text: 'Hello'),
      TextDirection.ltr,
    );
    expect(
      PaintRunText.familyFor(text: 'مرحبا', runFamily: 'Calibri'),
      'Noto Naskh Arabic',
    );
    expect(
      PaintRunText.familyFor(text: 'مرحبا', runFamily: 'Tajawal'),
      'Tajawal',
    );
    expect(
      PaintRunText.familyFor(text: 'Hello', runFamily: 'Georgia'),
      'Georgia',
    );
  });

  test(
    'script runs stay in their own paint group and sit off the baseline',
    () {
      LaidOutGlyph glyph(WmlVertAlign align, {double x = 0}) {
        return LaidOutGlyph(
          glyph: const ShapedGlyph(
            codePoint: 0x32,
            glyphId: 1,
            advance: 6,
            logicalIndex: 0,
            level: 0,
          ),
          x: x,
          y: 20,
          color: '000000',
          fontSize: align == WmlVertAlign.baseline ? 11 : 7.15,
          bold: false,
          underline: WmlUnderline.none,
          vertAlign: align,
        );
      }

      expect(
        PaintRunText.samePaintRun(
          glyph(WmlVertAlign.baseline),
          glyph(WmlVertAlign.superscript),
        ),
        isFalse,
      );
      expect(
        WmlVertAlign.subscript.paintTop(
          lineY: 72,
          lineHeight: 14,
          fontSize: 7.15,
        ),
        closeTo(72 + (14 - 7.15), 0.01),
      );
      expect(
        WmlVertAlign.superscript.paintTop(
          lineY: 72,
          lineHeight: 14,
          fontSize: 7.15,
        ),
        72,
      );
    },
  );

  test('caret selects a word and a paragraph', () {
    const String text = 'Hello field team — مرحبا بالفريق';
    final CaretEngine caret = CaretEngine();
    caret.selectWord(text, 8);
    expect(text.substring(caret.selectionAnchor, caret.logicalIndex), 'field');
    caret.selectWord(text, 0);
    expect(text.substring(caret.selectionAnchor, caret.logicalIndex), 'Hello');
    caret.selectWord(text, 22);
    expect(text.substring(caret.selectionAnchor, caret.logicalIndex), 'مرحبا');
    caret.selectParagraph(text);
    expect(caret.selectionAnchor, 0);
    expect(caret.logicalIndex, text.length);
    const String box = 'Hello field\nNext line';
    expect(
      box.substring(
        CaretEngine.wordBounds(box, 8).start,
        CaretEngine.wordBounds(box, 8).end,
      ),
      'field',
    );
    expect(CaretEngine.paragraphBounds(box, 0), (start: 0, end: 11));
    expect(CaretEngine.paragraphBounds(box, 13), (start: 12, end: 21));
  });

  test('caret stays on an RTL line whose visual order is reversed', () {
    final List<LaidOutGlyph> glyphs = <LaidOutGlyph>[
      for (int i = 5; i >= 0; i--)
        LaidOutGlyph(
          glyph: ShapedGlyph(
            codePoint: 0x0627 + i,
            glyphId: i,
            advance: 8,
            logicalIndex: i,
            level: 1,
          ),
          x: (5 - i) * 8.0,
          y: 20,
          color: '000000',
          fontSize: 11,
          bold: false,
          underline: WmlUnderline.none,
        ),
    ];
    final LaidOutLine line = LaidOutLine(
      glyphs: glyphs,
      x: 72,
      y: 72,
      width: 48,
      height: 14,
      pageIndex: 0,
      justification: WmlJustification.right,
    );
    final CaretEngine caret = CaretEngine()..logicalIndex = 3;
    expect(caret.isOnLine(line, lastOfParagraph: true), isTrue);
    caret.logicalIndex = 6;
    expect(caret.isOnLine(line, lastOfParagraph: true), isTrue);
    caret.logicalIndex = 6;
    expect(caret.isOnLine(line, lastOfParagraph: false), isFalse);
  });

  test('caret covers a contiguous range of table paragraphs', () {
    final CaretEngine caret = CaretEngine()
      ..selectionAnchorParagraph = 0
      ..selectionAnchor = 0
      ..paragraphIndex = 1
      ..logicalIndex = 5;
    expect(caret.isCollapsed, isFalse);
    expect(caret.coversParagraph(0), isTrue);
    expect(caret.coversParagraph(1), isTrue);
    expect(caret.coversParagraph(2), isFalse);
    final List<Rect> start = caret.selectionRects(
      BrokenLine(
        glyphs: const <ShapedGlyph>[],
        width: 40,
        logicalStart: 0,
        logicalEnd: 4,
        justificationRatio: 0,
      ),
      0,
      12,
      paragraph: 0,
    );
    expect(start, isNotEmpty);
  });

  test('selection matrix and table resizer', () {
    final SelectionMatrix m = SelectionMatrix();
    m.selectCell(const SmlCellRef(1, 2));
    m.extendTo(const SmlCellRef(3, 4));
    expect(m.contains(const SmlCellRef(2, 3)), isTrue);
    expect(m.contains(const SmlCellRef(0, 0)), isFalse);
    m.selectColumn(1);
    m.extendColumnsTo(3);
    expect(m.isFullColumnSelection, isTrue);
    expect(m.contains(const SmlCellRef(2, 0)), isTrue);
    expect(m.contains(const SmlCellRef(2, 50)), isTrue);
    expect(m.contains(const SmlCellRef(0, 0)), isFalse);
    m.selectRow(4);
    m.extendRowsTo(6);
    expect(m.isFullRowSelection, isTrue);
    expect(m.contains(const SmlCellRef(0, 5)), isTrue);
    expect(m.contains(const SmlCellRef(20, 5)), isTrue);
    expect(m.contains(const SmlCellRef(0, 3)), isFalse);
    expect(m.focus.col, 0);
    expect(m.anchor.col, 0);

    final TableResizer r = TableResizer(columnXs: <double>[100, 200]);
    expect(r.cursorFor(101), SystemMouseCursors.resizeColumn);
    r.applyDrag(110);
    expect(r.columnXs[0], greaterThan(100));
  });

  testWidgets('Word canvas and sheet grid mount as RenderBoxes', (
    WidgetTester tester,
  ) async {
    final WmlDocument doc = WmlDocument.empty(text: 'Hello');
    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: WordCanvas(document: doc, laidOut: laid, caret: CaretEngine()),
      ),
    );
    expect(
      tester.renderObject(find.byType(WordCanvas)),
      isA<RenderWordCanvas>(),
    );

    await tester.tap(find.byType(WordCanvas));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 300,
          child: SheetGrid(
            sheet: SmlWorkbook().firstSheet,
            selection: SelectionMatrix(),
          ),
        ),
      ),
    );
    expect(tester.renderObject(find.byType(SheetGrid)), isA<RenderSheetGrid>());
  });

  testWidgets('Word canvas cursor follows handles, objects, and text', (
    WidgetTester tester,
  ) async {
    final WordEditorController word = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Hello')]),
              WmlVisual(
                visual: OfficeVisual(
                  kind: OfficeVisualKind.chartColumn,
                  title: 'Chart',
                  points: OfficeVisual.sampleSeries(arabic: false),
                  width: 200,
                  height: 120,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    word.selectVisual(word.document.visuals.first);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 900,
          height: 800,
          child: WordCanvas(
            document: word.document,
            laidOut: word.laidOut,
            caret: word.caret,
            selectedVisual: word.selectedVisual,
          ),
        ),
      ),
    );
    final RenderWordCanvas render =
        tester.renderObject(find.byType(WordCanvas)) as RenderWordCanvas;
    final LaidOutBox box = word.laidOut.pages.first.frames.firstWhere(
      (LaidOutBox frame) => frame.visual != null,
    );
    Offset toWindow(double pageX, double pageY) {
      const double scale = 96 / 72;
      final double pageW = word.laidOut.pageSize.width * scale;
      final double left = render.size.width > pageW + 64
          ? (render.size.width - pageW) / 2
          : 32;
      return Offset(pageX * scale + left, pageY * scale + 24);
    }

    expect(
      render.cursorFor(toWindow(box.x + box.width, box.y + box.height)),
      SystemMouseCursors.resizeUpLeftDownRight,
    );
    expect(
      render.cursorFor(toWindow(box.x + box.width / 2, box.y + box.height / 2)),
      SystemMouseCursors.move,
    );
    expect(render.cursorFor(const Offset(8, 8)), SystemMouseCursors.basic);
  });

  testWidgets('word canvas click hits the second table cell', (
    WidgetTester tester,
  ) async {
    final WmlDocument doc = tableDoc();
    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    final CaretEngine caret = CaretEngine();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 900,
          height: 700,
          child: WordCanvas(document: doc, laidOut: laid, caret: caret),
        ),
      ),
    );
    final RenderBox box = tester.renderObject(find.byType(WordCanvas));
    final LaidOutLine right = laid.pages.first.lines[1];
    const double scale = 96 / 72;
    final double pageW = laid.pageSize.width * scale;
    final double pageLeft = box.size.width > pageW + 64
        ? (box.size.width - pageW) / 2
        : 32;
    final Offset local = Offset(
      pageLeft + (right.x + right.width / 2) * scale,
      24 + (right.y + right.height / 2) * scale,
    );
    await tester.tapAt(tester.getTopLeft(find.byType(WordCanvas)) + local);
    await tester.pump();
    expect(caret.paragraphIndex, 1);
  });

  test('caret coversIndex includes the selected range', () {
    final CaretEngine caret = CaretEngine()
      ..logicalIndex = 8
      ..selectionAnchor = 2;
    expect(caret.coversIndex(0, 2), isTrue);
    expect(caret.coversIndex(0, 8), isTrue);
    expect(caret.coversIndex(0, 1), isFalse);
    expect(caret.coversIndex(0, 9), isFalse);
    caret.collapseSelection();
    expect(caret.coversIndex(0, 8), isFalse);
  });

  testWidgets('right click inside a text selection keeps the range', (
    WidgetTester tester,
  ) async {
    final WmlDocument doc = WmlDocument.empty(text: 'Hello world');
    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    final CaretEngine caret = CaretEngine()
      ..logicalIndex = 11
      ..selectionAnchor = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 900,
          height: 700,
          child: WordCanvas(document: doc, laidOut: laid, caret: caret),
        ),
      ),
    );
    final RenderBox box = tester.renderObject(find.byType(WordCanvas));
    final LaidOutLine line = laid.pages.first.lines.first;
    const double scale = 96 / 72;
    final double pageW = laid.pageSize.width * scale;
    final double pageLeft = box.size.width > pageW + 64
        ? (box.size.width - pageW) / 2
        : 32;
    final Offset local = Offset(
      pageLeft + (line.x + line.width / 2) * scale,
      24 + (line.y + line.height / 2) * scale,
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(WordCanvas)) + local,
      buttons: kSecondaryButton,
    );
    await tester.pump();
    expect(caret.isCollapsed, isFalse);
    expect(caret.selectionAnchor, 0);
    expect(caret.logicalIndex, 11);
  });

  testWidgets('right click outside a text selection keeps the range', (
    WidgetTester tester,
  ) async {
    final WmlDocument doc = WmlDocument.empty(text: 'Hello world');
    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    final CaretEngine caret = CaretEngine()
      ..logicalIndex = 5
      ..selectionAnchor = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 900,
          height: 700,
          child: WordCanvas(document: doc, laidOut: laid, caret: caret),
        ),
      ),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(WordCanvas)) + const Offset(40, 40),
      buttons: kSecondaryButton,
    );
    await tester.pump();
    expect(caret.isCollapsed, isFalse);
    expect(caret.selectionAnchor, 0);
    expect(caret.logicalIndex, 5);
  });

  testWidgets('right click keeps a multi-cell table selection', (
    WidgetTester tester,
  ) async {
    final WmlDocument doc = WmlDocument(
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
                        WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'NEI')]),
                      ],
                    ),
                    WmlTableCell(
                      blocks: <WmlBlock>[
                        WmlParagraph(
                          inlines: <WmlInline>[WmlRun(text: 'PROFILE')],
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
    );
    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    final CaretEngine caret = CaretEngine()
      ..selectionAnchorParagraph = 0
      ..selectionAnchor = 0
      ..paragraphIndex = 1
      ..logicalIndex = 7;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 900,
          height: 700,
          child: WordCanvas(document: doc, laidOut: laid, caret: caret),
        ),
      ),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(WordCanvas)) + const Offset(80, 80),
      buttons: kSecondaryButton,
    );
    await tester.pump();
    expect(caret.isCollapsed, isFalse);
    expect(caret.selectionAnchorParagraph, 0);
    expect(caret.paragraphIndex, 1);
  });

  testWidgets('sheet drag extends a contiguous cell range', (
    WidgetTester tester,
  ) async {
    final SelectionMatrix selection = SelectionMatrix();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 300,
          child: SheetGrid(
            sheet: SmlWorkbook().firstSheet,
            selection: selection,
          ),
        ),
      ),
    );
    final Offset origin = tester.getTopLeft(find.byType(SheetGrid));
    await tester.timedDragFrom(
      origin + const Offset(60, 58),
      const Offset(128, 20),
      const Duration(milliseconds: 200),
    );
    await tester.pump();
    expect(selection.contains(const SmlCellRef(0, 0)), isTrue);
    expect(selection.contains(const SmlCellRef(2, 1)), isTrue);
    expect(selection.anchor.col, 0);
    expect(selection.anchor.row, 0);
    expect(selection.focus.col, greaterThan(0));
    expect(selection.focus.row, greaterThan(0));
  });

  testWidgets('header drag keeps whole columns and whole rows', (
    WidgetTester tester,
  ) async {
    final SelectionMatrix selection = SelectionMatrix();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 300,
          child: SheetGrid(
            sheet: SmlWorkbook().firstSheet,
            selection: selection,
          ),
        ),
      ),
    );
    final Offset origin = tester.getTopLeft(find.byType(SheetGrid));
    await tester.timedDragFrom(
      origin + const Offset(28 + 32, 28 + 10),
      const Offset(128, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pump();
    expect(selection.isFullColumnSelection, isTrue);
    expect(selection.anchor.col, 0);
    expect(selection.focus.col, greaterThan(0));
    expect(selection.contains(const SmlCellRef(1, 40)), isTrue);
    await tester.timedDragFrom(
      origin + const Offset(10, 28 + 20 + 30),
      const Offset(0, 40),
      const Duration(milliseconds: 200),
    );
    await tester.pump();
    expect(selection.isFullRowSelection, isTrue);
    expect(selection.contains(SmlCellRef(12, selection.focus.row)), isTrue);
  });

  testWidgets('rtl sheet places column A on the right', (
    WidgetTester tester,
  ) async {
    final SelectionMatrix selection = SelectionMatrix();
    final SmlWorksheet sheet = SmlWorkbook().firstSheet..rightToLeft = true;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: 400,
          height: 300,
          child: SheetGrid(sheet: sheet, selection: selection),
        ),
      ),
    );
    final RenderBox box = tester.renderObject(find.byType(SheetGrid));
    final Offset origin = tester.getTopLeft(find.byType(SheetGrid));
    final double a1 = box.size.width - 28 - 32;
    await tester.tapAt(origin + Offset(a1, 58));
    await tester.pump();
    expect(selection.focus.col, 0);
    expect(selection.focus.row, 0);
    await tester.tapAt(origin + Offset(a1 - 64, 58));
    await tester.pump();
    expect(selection.focus.col, 1);
  });

  testWidgets('sheet scroll and hit-test reach past the used-range window', (
    WidgetTester tester,
  ) async {
    final SelectionMatrix selection = SelectionMatrix();
    final VirtualViewport viewport = VirtualViewport();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 300,
          child: SheetGrid(
            sheet: SmlWorkbook().firstSheet,
            selection: selection,
            viewport: viewport,
          ),
        ),
      ),
    );
    viewport.origin = const Offset(20 * 64, 30 * 20);
    await tester.pump();
    final Offset origin = tester.getTopLeft(find.byType(SheetGrid));
    await tester.tapAt(origin + const Offset(28 + 32, 28 + 20 + 10));
    await tester.pump();
    expect(selection.focus.col, 20);
    expect(selection.focus.row, 30);
  });

  testWidgets('frozen row stays put after vertical scroll', (
    WidgetTester tester,
  ) async {
    final SelectionMatrix selection = SelectionMatrix();
    final VirtualViewport viewport = VirtualViewport();
    final SmlWorksheet sheet = SmlWorkbook().firstSheet..freezeRows = 1;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 300,
          child: SheetGrid(
            sheet: sheet,
            selection: selection,
            viewport: viewport,
          ),
        ),
      ),
    );
    viewport.origin = const Offset(0, 80);
    await tester.pump();
    final Offset origin = tester.getTopLeft(find.byType(SheetGrid));
    await tester.tapAt(origin + const Offset(60, 58));
    await tester.pump();
    expect(selection.focus.col, 0);
    expect(selection.focus.row, 0);
    await tester.tapAt(origin + const Offset(60, 28 + 20 + 20 + 10));
    await tester.pump();
    expect(selection.focus.row, greaterThan(0));
  });

  testWidgets('dragging a column header edge resizes the column', (
    WidgetTester tester,
  ) async {
    final SmlWorksheet sheet = SmlWorkbook().firstSheet;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 300,
          child: SheetGrid(
            sheet: sheet,
            selection: SelectionMatrix(),
            onResizeColumn: sheet.setColumnWidth,
          ),
        ),
      ),
    );
    final Offset origin = tester.getTopLeft(find.byType(SheetGrid));
    await tester.timedDragFrom(
      origin + const Offset(28 + 64, 28 + 10),
      const Offset(40, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pump();
    expect(sheet.columnWidth(0), greaterThan(80));
  });

  testWidgets('dragging a row header edge resizes the row', (
    WidgetTester tester,
  ) async {
    final SmlWorksheet sheet = SmlWorkbook().firstSheet;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 300,
          child: SheetGrid(
            sheet: sheet,
            selection: SelectionMatrix(),
            onResizeRow: sheet.setRowHeight,
          ),
        ),
      ),
    );
    final Offset origin = tester.getTopLeft(find.byType(SheetGrid));
    await tester.timedDragFrom(
      origin + const Offset(14, 28 + 20 + 20),
      const Offset(0, 24),
      const Duration(milliseconds: 200),
    );
    await tester.pump();
    expect(sheet.rowHeightAt(0), greaterThan(28));
  });

  test('viewport clamp stops endless scrolling', () {
    final VirtualViewport view = VirtualViewport(
      origin: const Offset(-200, -400),
      extent: const Size(800, 600),
    );
    view.clampTo(content: const Size(700, 900), view: const Size(800, 600));
    expect(view.origin.dx, 0);
    expect(view.origin.dy, 0);
    view.origin = const Offset(80, 2000);
    view.clampTo(content: const Size(700, 900), view: const Size(800, 600));
    expect(view.origin.dx, 0);
    expect(view.origin.dy, 300);
  });

  test('slide snap guidelines and transform handles', () {
    final SnapGuidelines snaps = SnapGuidelines();
    snaps.addTarget(const Rect.fromLTWH(100, 40, 80, 40));
    final Offset delta = snaps.snap(const Rect.fromLTWH(102, 38, 50, 30));
    expect(delta.dx, -2);
    expect(delta.dy, 2);
    expect(snaps.activeGuideCount, 2);
    snaps.snap(const Rect.fromLTWH(300, 200, 40, 20));
    expect(snaps.activeGuideCount, 0);

    final TransformHandles handles = TransformHandles(
      const Rect.fromLTWH(10, 10, 100, 80),
    );
    expect(handles.hit(const Offset(10, 10)), 0);
    expect(handles.hit(handles.rotateHandle), 8);
    expect(handles.points.length, 8);
    expect(handles.rotateHandle.dy, lessThan(handles.bounds.top));
  });

  testWidgets('Slide stage mounts as a RenderBox', (WidgetTester tester) async {
    final PmlSlide slide = PmlSlide(
      id: 256,
      shapes: <PmlShape>[PmlShape(id: 2, name: 'Title', text: 'Deck')],
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 960,
          height: 540,
          child: SlideStage(slide: slide),
        ),
      ),
    );
    expect(
      tester.renderObject(find.byType(SlideStage)),
      isA<RenderSlideStage>(),
    );
  });

  testWidgets('leaving slide text edit does not rotate the shape', (
    WidgetTester tester,
  ) async {
    const PmlTransform rotated = PmlTransform(
      x: 1270000,
      y: 635000,
      cx: 2540000,
      cy: 1270000,
      rot: 1500000,
    );
    final PmlShape shape = PmlShape(
      id: 2,
      name: 'Title',
      text: 'Deck',
      transform: rotated,
    );
    var editing = true;
    var transformed = false;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 960,
          height: 540,
          child: SlideStage(
            slide: PmlSlide(id: 256, shapes: <PmlShape>[shape]),
            selected: shape,
            editing: editing,
            onCommitEdit: () {
              editing = false;
            },
            onTransform: (PmlShape _, PmlTransform __) {
              transformed = true;
            },
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(editing, isFalse);
    expect(transformed, isFalse);
    expect(shape.transform.rot, 1500000);
  });

  test('styled runs do not overlap after paint fit', () {
    final WmlDocument doc = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            WmlParagraph(
              inlines: <WmlInline>[
                WmlRun(
                  text: 'underline',
                  properties: WmlRunProps(underline: WmlUnderline.single),
                ),
                WmlRun(text: ' and '),
                WmlRun(
                  text: 'highlight',
                  properties: WmlRunProps(highlight: 'FFF2CC'),
                ),
                WmlRun(text: ' apply only'),
              ],
            ),
          ],
        ),
      ],
    );
    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    final String text = doc.paragraphs.first.text;
    for (final LaidOutLine line in laid.pages.first.lines) {
      PaintRunText.fitLine(line, text);
    }
    final List<LaidOutGlyph> glyphs = laid.pages.first.lines
        .expand((LaidOutLine line) => line.glyphs)
        .toList();
    for (int i = 1; i < glyphs.length; i++) {
      expect(glyphs[i].x, greaterThanOrEqualTo(glyphs[i - 1].x - 0.01));
      expect(
        glyphs[i].x,
        greaterThanOrEqualTo(glyphs[i - 1].x + glyphs[i - 1].advance - 0.6),
      );
    }
  });

  test('paint fit places glyphs next to each other without justify gaps', () {
    final WmlDocument doc = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            WmlParagraph(
              properties: WmlParagraphProps(
                justification: WmlJustification.justify,
              ),
              inlines: <WmlInline>[
                WmlRun(
                  text: 'Investment of USD 250,000 in three neighbourhoods now',
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    expect(laid.pages.first.lines, isNotEmpty);
    for (final LaidOutLine line in laid.pages.first.lines) {
      PaintRunText.fitLine(line, doc.paragraphs.first.text);
      for (int i = 1; i < line.glyphs.length; i++) {
        final double gap =
            line.glyphs[i].x -
            (line.glyphs[i - 1].x + line.glyphs[i - 1].advance);
        expect(gap.abs(), lessThan(1.5));
      }
    }
  });

  test('embedded host unpacks a nested workbook', () {
    final IsolatedEmbeddedPackage child = EmbeddedPart.create(
      OpcPackageKind.sheet,
    );
    child.package.getPart('/xl/worksheets/sheet1.xml');
    final EmbeddedObjectHost host = EmbeddedObjectHost(child);
    expect(host.asWorkbook(), isNotNull);
  });

  test('Word controller inserts and edits an equation', () {
    final WordEditorController word = WordEditorController();
    word.insertEquation(OmmlGallery.byId('pythagorean').build());
    expect(word.selectedEquation, isNotNull);
    expect(word.document.equations, isNotEmpty);
    expect(
      word.laidOut.pages.first.frames.any(
        (LaidOutBox box) => box.kind == LaidOutBoxKind.equation,
      ),
      isTrue,
    );
    word.insertEquationText('+');
    expect(OmmlLinear.write(word.selectedEquation!.math.root), contains('+'));
    word.applyEquationStructure(OmmlStructure.squareRoot);
    expect(
      word.selectedEquation!.math.root.children
              .whereType<OmmlRad>()
              .isNotEmpty ||
          OmmlEdit.slots(word.selectedEquation!.math.root).any(
            (OmmlSeq slot) => slot.children.whereType<OmmlRad>().isNotEmpty,
          ),
      isTrue,
    );
    word.setEquationView(OmmlView.linear);
    expect(word.selectedEquation!.math.view, OmmlView.linear);
    word.deleteSelectedEquation();
    expect(word.selectedEquation, isNull);
    expect(word.document.equations, isEmpty);
  });

  test('Word equation cells navigate and stay editable after reopen', () {
    final WordEditorController word = WordEditorController();
    word.insertEquation(OmmlGallery.byId('quadratic').build());
    expect(word.selectedEquation, isNotNull);
    final int start = word.equationSlot;
    word.moveEquationSlot(1);
    expect(word.equationSlot, isNot(start));
    word.moveEquationArrow(dx: 0, dy: 1);
    word.insertEquationText('k');
    expect(OmmlLinear.write(word.selectedEquation!.math.root), contains('k'));

    final Uint8List bytes = word.saveBytes();
    final WordEditorController opened = WordEditorController();
    opened.loadBytes(bytes);
    expect(opened.document.equations, isNotEmpty);
    opened.selectEquation(opened.document.equations.first);
    expect(opened.selectedEquation, isNotNull);
    opened.insertEquationText('Q');
    expect(OmmlLinear.write(opened.selectedEquation!.math.root), contains('Q'));
    expect(
      opened.laidOut.pages.first.frames.any(
        (LaidOutBox box) =>
            box.kind == LaidOutBoxKind.equation && box.omml != null,
      ),
      isTrue,
    );
  });

  test('equation arrows move by character and cross cells at the edges', () {
    final WordEditorController word = WordEditorController();
    word.insertEquation(OmmlGallery.byId('quadratic').build());
    word.moveEquationSlot(1);
    final int second = word.equationSlot;
    expect(word.equationCaret, 0);
    word.moveEquationArrow(dx: -1, dy: 0);
    expect(word.equationSlot, isNot(second));
    expect(word.equationCaret, word.equationEditingText().length);
    word.moveEquationArrow(dx: 1, dy: 0);
    expect(word.equationSlot, second);
    expect(word.equationCaret, 0);
    if (word.equationEditingText().isNotEmpty) {
      word.moveEquationArrow(dx: 1, dy: 0);
      expect(word.equationCaret, 1);
      word.insertEquationText('z');
      expect(word.equationEditingText(), contains('z'));
    }
  });

  test('equation backspace deletes letters then the empty tool', () {
    final WordEditorController word = WordEditorController();
    word.insertEquation(OmmlEquation.empty());
    expect(word.selectedEquation, isNotNull);
    word.applyEquationStructure(OmmlStructure.fractionBar);
    word.applyEquationStructure(OmmlStructure.squareRoot);
    expect(word.document.equations, isNotEmpty);
    word.insertEquationText('ab');
    expect(word.equationEditingText(), 'ab');
    word.deleteEquationContent(backward: true);
    expect(word.equationEditingText(), 'a');
    expect(word.selectedEquation, isNotNull);
    word.deleteEquationContent(backward: true);
    expect(word.equationEditingText(), isEmpty);
    expect(word.selectedEquation, isNotNull);
    word.deleteEquationContent(backward: true);
    expect(word.selectedEquation, isNull);
    expect(word.document.equations, isEmpty);
  });

  test('clicking an equation cell routes IME into that cell', () {
    final WordEditorController word = WordEditorController();
    word.insertEquation(OmmlGallery.byId('quadratic').build());
    expect(word.selectedEquation, isNotNull);
    word.moveEquationSlot(1);
    final String before = word.equationEditingText();
    word.applyImeText('${before}k');
    expect(word.equationEditingText(), contains('k'));
    expect(OmmlLinear.write(word.selectedEquation!.math.root), contains('k'));
  });

  test('Word picture handles resize, move, and crop on the canvas', () {
    final WordEditorController word = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlVisual(
                visual: OfficeVisual(
                  kind: OfficeVisualKind.picture,
                  title: 'Photo',
                  imageBytes: PngBytes.studioCard(),
                  width: 180,
                  height: 100,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    word.selectVisual(word.document.visuals.first);
    expect(word.semanticsLabel, contains('Photo'));
    expect(word.semanticsValue, contains('Picture'));
    word.beginVisualTransform();
    word.previewVisualResize(width: 240, height: 140);
    word.previewVisualMove(20);
    word.previewVisualRotate(45);
    word.commitVisualTransform();
    expect(word.selectedVisual!.visual.width, 240);
    expect(word.selectedVisual!.visual.height, 140);
    expect(word.selectedVisual!.visual.offsetX, 20);
    expect(word.selectedVisual!.visual.picture.rotationDeg, 45);
    word.togglePictureCropMode();
    expect(word.pictureCropMode, isTrue);
    word.beginVisualTransform();
    word.previewVisualCrop(left: 0.1, top: 0.05, right: 0.1, bottom: 0.05);
    word.commitVisualTransform();
    expect(word.selectedVisual!.visual.picture.cropLeft, closeTo(0.1, 0.001));
    word.togglePictureCropMode();
    expect(word.pictureCropMode, isFalse);
    word.nudgeSelectedVisual(dx: 8);
    expect(word.selectedVisual!.visual.offsetX, greaterThan(20));
  });

  test('Word comments can be inserted, edited, and deleted', () {
    final WordEditorController word = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Hello office')]),
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Second line')]),
            ],
          ),
        ],
      ),
    );
    word.caret.paragraphIndex = 0;
    word.caret.logicalIndex = 8;
    word.caret.collapseSelection();
    word.insertComment(text: 'Look here', author: 'Reviewer', initials: 'RV');
    expect(word.document.comments, hasLength(1));
    expect(word.selectedComment?.text, 'Look here');
    expect(WordComment.idsAt(word.document.paragraphs.first, 0), contains(0));
    expect(WordComment.idsAt(word.document.paragraphs.first, 7), contains(0));
    word.updateComment(0, text: 'Updated note');
    expect(word.selectedComment?.text, 'Updated note');
    word.deleteComment(0);
    expect(word.document.comments, isEmpty);
    expect(word.selectedCommentId, isNull);

    word.caret
      ..paragraphIndex = 0
      ..logicalIndex = 11
      ..selectionAnchorParagraph = 0
      ..selectionAnchor = 6;
    word.insertComment(text: 'office only');
    expect(WordComment.idsAt(word.document.paragraphs.first, 7), contains(0));
    expect(WordComment.idsAt(word.document.paragraphs.first, 0), isEmpty);

    word.replyToComment(0, text: 'Will fix');
    expect(word.document.comments, hasLength(2));
    expect(WordComment.byId(word.document, 1)?.parentId, 0);
    word.setCommentResolved(0, true);
    expect(WordComment.byId(word.document, 0)?.resolved, isTrue);
    word.applyCommentRunFormat(0, (WmlRunProps p) => p.bold = true);
    expect(
      word.document.comments.first.paragraphs.first.inlines
          .whereType<WmlRun>()
          .first
          .properties
          .bold,
      isTrue,
    );
    word.insertCommentVisual(
      0,
      OfficeVisual(
        kind: OfficeVisualKind.picture,
        title: 'Note',
        imageBytes: PngBytes.studioCard(),
        width: 80,
        height: 40,
      ),
    );
    expect(word.document.comments.first.visuals, hasLength(1));
    word.endCommentEdit();
    word.documentCaret
      ..paragraphIndex = 1
      ..logicalIndex = 6
      ..selectionAnchorParagraph = 0
      ..selectionAnchor = 0;
    word.insertComment(text: 'Both paragraphs');
    expect(
      WordComment.idsAt(word.document.paragraphs.toList()[1], 1),
      contains(2),
    );
  });

  test('ribbon formatting bolds only the selected comment range', () {
    final WordEditorController word = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Document body')]),
            ],
          ),
        ],
      ),
    );
    word.insertComment(text: 'Keep this bilingual note');
    expect(word.isEditingComment, isTrue);
    word.commentCaret
      ..paragraphIndex = 0
      ..logicalIndex = 19
      ..selectionAnchorParagraph = 0
      ..selectionAnchor = 10;
    word.applyRunFormat((WmlRunProps props) => props.bold = true);
    final List<WmlRun> runs = word.selectedComment!.paragraphs.first.inlines
        .whereType<WmlRun>()
        .toList();
    expect(
      runs
          .where((WmlRun run) => run.properties.bold)
          .map((WmlRun run) => run.text)
          .join(),
      'bilingual',
    );
    expect(
      runs
          .where((WmlRun run) => !run.properties.bold)
          .map((WmlRun run) => run.text)
          .join(),
      'Keep this  note',
    );
    expect(word.document.paragraphs.first.text, 'Document body');
    expect(
      word.document.paragraphs.first.inlines
          .whereType<WmlRun>()
          .first
          .properties
          .bold,
      isFalse,
    );
  });

  testWidgets('Word headings feed a live table of contents', (
    WidgetTester tester,
  ) async {
    final WordEditorController word = WordEditorController(
      document: WmlDocument(
        sections: <WmlSection>[
          WmlSection(
            blocks: <WmlBlock>[
              WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Intro')]),
            ],
          ),
        ],
      ),
    );
    word.applyHeading(1);
    expect(word.activeHeadingLevel, 1);
    word.insertHeading(level: 2, text: 'Next');
    word.insertTableOfContents(title: 'Contents');
    expect(WordToc.tocs(word.document), hasLength(1));
    expect(
      WordToc.tocs(word.document).single.entries.map((WmlTocEntry e) => e.text),
      containsAll(<String>['Intro', 'Next']),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 900,
          height: 800,
          child: WordCanvas(
            document: word.document,
            laidOut: word.laidOut,
            caret: word.caret,
            onJumpParagraph: word.jumpToParagraph,
          ),
        ),
      ),
    );
    final RenderWordCanvas render =
        tester.renderObject(find.byType(WordCanvas)) as RenderWordCanvas;
    final LaidOutBox box = word.laidOut.pages.first.frames.firstWhere(
      (LaidOutBox frame) => frame.kind == LaidOutBoxKind.tocEntry,
    );
    Offset toWindow(double pageX, double pageY) {
      const double scale = 96 / 72;
      final double pageW = word.laidOut.pageSize.width * scale;
      final double left = render.size.width > pageW + 64
          ? (render.size.width - pageW) / 2
          : 32;
      return Offset(pageX * scale + left, pageY * scale + 24);
    }

    expect(
      render.cursorFor(toWindow(box.x + 8, box.y + 6)),
      SystemMouseCursors.text,
    );
    final WmlToc toc = WordToc.tocs(word.document).single;
    final int titleIndex = word.document.paragraphs.toList().indexOf(
      toc.titleParagraph,
    );
    expect(titleIndex, greaterThanOrEqualTo(0));
    word.caret.paragraphIndex = titleIndex;
    word.caret.selectParagraph(toc.titleParagraph.text);
    word.applyRunFormat((WmlRunProps props) => props.color = 'C00000');
    expect(
      toc.titleParagraph.inlines.whereType<WmlRun>().first.properties.color,
      'C00000',
    );
    word.updateTableOfContents(pageNumbersOnly: true);
    expect(
      toc.titleParagraph.inlines.whereType<WmlRun>().first.properties.color,
      'C00000',
    );
    word.jumpToParagraph(1);
    expect(word.caret.paragraphIndex, 1);
    word.followLink(
      WmlHyperlink(
        anchor: word.document.paragraphs.first.properties.bookmarkName,
      ),
    );
    expect(word.caret.paragraphIndex, 0);
  });
}
