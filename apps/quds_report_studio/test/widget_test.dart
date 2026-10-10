import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_editor/quds_office_editor.dart';
import 'package:quds_report_studio/main.dart';
import 'package:quds_report_studio/src/recent_files.dart';
import 'package:quds_report_studio/src/report_document.dart';
import 'package:quds_report_studio/src/report_studio_page.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('qrs_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('documents track unsaved changes and round-trip files', () async {
    final ReportDocument doc = ReportDocument();
    doc.newFromTemplate(ReportTemplates.all.first);
    expect(doc.dirty, isFalse);
    expect(doc.fileName, '${ReportTemplates.all.first.id}.qrep');

    doc.controller.addVariable();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(doc.dirty, isTrue);

    final String path = '${temp.path}/sample.qrep';
    await doc.saveTo(path);
    expect(doc.dirty, isFalse);
    expect(doc.path, path);
    expect(doc.name, 'sample');

    doc.controller.undo();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(doc.dirty, isTrue);
    doc.controller.redo();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(doc.dirty, isFalse);

    final ReportDocument other = ReportDocument();
    await other.open(path);
    expect(other.controller.template.variables, hasLength(1));
    expect(other.dirty, isFalse);
    doc.dispose();
    other.dispose();
  });

  test('recent files persist newest first without duplicates', () async {
    final File store = File('${temp.path}/cfg/recent.json');
    final RecentFiles recent = RecentFiles(store: store);
    await recent.add('/a.qrep');
    await recent.add('/b.qrep');
    await recent.add('/a.qrep');
    expect(recent.paths, <String>['/a.qrep', '/b.qrep']);

    final RecentFiles again = RecentFiles(store: store);
    await again.load();
    expect(again.paths, <String>['/a.qrep', '/b.qrep']);
    await again.remove('/b.qrep');
    expect(again.paths, <String>['/a.qrep']);
  });

  testWidgets('studio shows the designer, title, and status bar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final RecentFiles recent = RecentFiles(
      store: File('${temp.path}/recent.json'),
    );
    await tester.pumpWidget(ReportStudioApp(recent: recent));
    await tester.pump();

    expect(find.byType(QudsReportDesigner), findsOneWidget);
    expect(
      find.textContaining(ReportTemplates.all.first.id, findRichText: true),
      findsWidgets,
    );
    expect(find.text('Saved'), findsOneWidget);
    expect(find.textContaining('variables'), findsOneWidget);

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    expect(find.text('New from template'), findsOneWidget);
    expect(find.text('Open recent'), findsOneWidget);

    final ReportStudioPageState state = tester.state(
      find.byType(ReportStudioPage),
    );
    expect(state.document.dirty, isFalse);
  });
}
