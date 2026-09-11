import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

void main() {
  testWidgets('QudsPdfViewer opens writer bytes', (WidgetTester tester) async {
    final PdfDocument doc = PdfDocument(title: 'Viewer');
    final PdfCanvas canvas = PdfCanvas(300, 400)
      ..rect(10, 10, 40, 20)
      ..fill();
    doc.addPage(PdfPage(width: 300, height: 400, content: canvas.toStream()));
    final PdfViewerController controller = PdfViewerController.fromBytes(
      doc.save(),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: QudsPdfViewer(controller: controller),
      ),
    );
    expect(controller.pageCount, 1);
    expect(find.byType(PdfCanvasView), findsOneWidget);
    controller.dispose();
  });

  test('editor highlight then save grows the package', () {
    final PdfDocument doc = PdfDocument();
    final PdfCanvas canvas = PdfCanvas(300, 400)..rect(10, 10, 40, 20)..fill();
    doc.addPage(PdfPage(width: 300, height: 400, content: canvas.toStream()));
    final PdfEditorController editor = PdfEditorController.fromBytes(doc.save());
    editor.setSelection(
      PdfTextSelection.run(
        0,
        0,
        const PdfTextRun(text: 'Hi', x: 10, y: 10, width: 20, height: 12),
      ),
    );
    editor.highlightSelection();
    final int before = editor.file!.originalBytes.length;
    expect(editor.saveBytes().length, greaterThan(before));
    editor.undo();
    expect(editor.file!.annotsOn(0), isEmpty);
    editor.dispose();
  });

  test('setScale zooms about the view center and clamps', () {
    final PdfDocument doc = PdfDocument();
    final PdfCanvas canvas = PdfCanvas(300, 400)..rect(10, 10, 40, 20)..fill();
    doc.addPage(PdfPage(width: 300, height: 400, content: canvas.toStream()));
    final PdfEditorController editor = PdfEditorController.fromBytes(doc.save());
    editor.viewport.extent = const Size(400, 300);
    editor.viewport.origin = const Offset(0, 200);
    editor.setScale(2, animate: false);
    expect(editor.viewport.scale, 2);
    expect(editor.viewport.origin.dy, greaterThan(200));
    editor.setScale(0.1, animate: false);
    expect(editor.viewport.scale, VirtualViewport.minScale);
    editor.setScale(10, animate: false);
    expect(editor.viewport.scale, VirtualViewport.maxScale);
    editor.zoomBy(1, animate: false);
    expect(editor.viewport.scale, VirtualViewport.maxScale);
    editor.dispose();
  });

  testWidgets('viewer canvas picks up controller scale', (WidgetTester tester) async {
    final PdfDocument doc = PdfDocument();
    final PdfCanvas canvas = PdfCanvas(300, 400)..rect(10, 10, 40, 20)..fill();
    doc.addPage(PdfPage(width: 300, height: 400, content: canvas.toStream()));
    final PdfViewerController controller = PdfViewerController.fromBytes(
      doc.save(),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: QudsPdfViewer(controller: controller),
      ),
    );
    controller.setScale(2, animate: false);
    await tester.pump();
    final PdfCanvasView view = tester.widget(find.byType(PdfCanvasView));
    expect(view.scale, 2);
    expect(controller.viewport.scale, 2);
    controller.dispose();
  });

  test('goToPage scrolls the stack and thumbs can be hit', () {
    final PdfDocument doc = PdfDocument();
    for (int i = 0; i < 3; i++) {
      final PdfCanvas canvas = PdfCanvas(300, 400)..rect(10, 10, 40, 20)..fill();
      doc.addPage(PdfPage(width: 300, height: 400, content: canvas.toStream()));
    }
    final PdfEditorController editor = PdfEditorController.fromBytes(doc.save());
    editor.viewport.extent = const Size(400, 300);
    editor.goToPage(2);
    expect(editor.pageIndex, 2);
    expect(editor.viewport.origin.dy, greaterThan(400));
    editor.viewport.origin = Offset.zero;
    editor.viewport.extent = const Size(400, 200);
    editor.adoptVisiblePage();
    expect(editor.pageIndex, 0);
    editor.dispose();
  });

  test('text selection copies a run slice and word bounds', () {
    const PdfTextRun run = PdfTextRun(
      text: 'Hello PDF',
      x: 10,
      y: 20,
      width: 90,
      height: 12,
    );
    final PdfDisplayList list = PdfDisplayList(
      page: const PdfPageInfo(
        index: 0,
        mediaBox: PdfBox(llx: 0, lly: 0, urx: 300, ury: 400),
        cropBox: PdfBox(llx: 0, lly: 0, urx: 300, ury: 400),
      ),
      runs: <PdfTextRun>[run],
    );
    final PdfTextSelection range = PdfTextSelection(
      anchor: const PdfTextHit(page: 0, run: 0, offset: 0),
      extent: const PdfTextHit(page: 0, run: 0, offset: 5),
    );
    expect(range.plainText(<PdfDisplayList>[list]), 'Hello');
    expect(range.boxes(<PdfDisplayList>[list]), isNotEmpty);
    expect(PdfTextSelection.offsetAt(run, 10), 0);
    expect(PdfTextSelection.offsetAt(run, 100), 9);
    expect(
      PdfTextSelection.word(
        const PdfTextHit(page: 0, run: 0, offset: 7),
        run,
      ).plainText(<PdfDisplayList>[list]),
      'PDF',
    );
  });
}
