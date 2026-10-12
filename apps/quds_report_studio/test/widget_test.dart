import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_editor/quds_office_editor.dart';
import 'package:quds_report_studio/main.dart';
import 'package:quds_report_studio/src/device_fonts.dart';
import 'package:quds_report_studio/src/file_association.dart';
import 'package:quds_report_studio/src/recent_files.dart';
import 'package:quds_report_studio/src/report_document.dart';
import 'package:quds_report_studio/src/report_studio_page.dart';
import 'package:quds_report_studio/src/studio_settings.dart';

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

  test('saves embedded images in the .qrep package', () async {
    final ReportDocument doc = ReportDocument();
    final Uint8List logo = PngBytes.rgb(
      width: 2,
      height: 2,
      plot: (int x, int y, List<int> rgb) => rgb[0] = 255,
    );
    doc.controller.addImage('logo.png', logo);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(doc.dirty, isTrue, reason: 'adding an image is an edit');

    final String path = '${temp.path}/logo.qrep';
    await doc.saveTo(path);
    final Uint8List saved = File(path).readAsBytesSync();
    expect(ReportPackage.isPackage(saved), isTrue);
    expect(ReportPackage.decode(saved).images['logo'], logo);

    doc.controller.removeImage('logo');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(doc.dirty, isTrue);
    doc.controller.undo();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(doc.dirty, isFalse);

    final ReportDocument other = ReportDocument();
    await other.open(path);
    expect(other.controller.images['logo'], logo);

    final String legacy = '${temp.path}/legacy.qrep';
    File(legacy).writeAsStringSync(ReportTemplates.all.first.xml);
    await other.open(legacy);
    expect(other.controller.images, isEmpty);
    expect(other.name, 'legacy');
    expect(other.dirty, isFalse);
    doc.dispose();
    other.dispose();
  });

  test('saves explorer sample data and tracks its edits', () async {
    final ReportDocument doc = ReportDocument();
    doc.newBlank();
    final ReportDesignerController c = doc.controller;
    expect(c.hasSampleData, isFalse);
    expect(c.addDataField('note'), isTrue);
    expect(c.setDataField('note', 'first'), isTrue);
    expect(c.importDataText('lines.csv', 'name,qty\nPen,2\nInk,5\n'), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(doc.dirty, isTrue, reason: 'sample data is part of the file');

    final String path = '${temp.path}/data.qrep';
    await doc.saveTo(path);
    expect(
      ReportPackage.decode(File(path).readAsBytesSync()).sampleData!['note'],
      'first',
    );
    c.setDataField('note', 'second');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(doc.dirty, isTrue);
    c.undo();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(doc.dirty, isFalse);

    final ReportDocument other = ReportDocument();
    await other.open(path);
    expect(other.controller.sampleData!['note'], 'first');
    expect(other.controller.mockData['lines'], hasLength(2));
    expect(
      other.controller.dataTables
          .firstWhere((ReportDataTableView t) => t.name == 'lines')
          .columns
          .map((ReportDataColumnView x) => x.name),
      <String>['name', 'qty'],
    );
    expect(other.dirty, isFalse);
    doc.dispose();
    other.dispose();
  });

  test('scans installed fonts and embeds them in the package', () async {
    const String bundled = '../../packages/quds_office_editor/fonts';
    final StudioDeviceFonts device = StudioDeviceFonts(
      folders: <String>[bundled, '${temp.path}/missing'],
    );
    expect(await device.families(), <String>[
      'Liberation Mono',
      'Liberation Sans',
      'Liberation Serif',
      'Noto Naskh Arabic',
    ]);
    final ReportFontFiles sans = (await device.load('Liberation Sans'))!;
    expect(
      sans.regular,
      File('$bundled/LiberationSans-Regular.ttf').readAsBytesSync(),
    );
    expect(
      sans.bold,
      File('$bundled/LiberationSans-Bold.ttf').readAsBytesSync(),
    );
    expect(await device.load('Nope'), isNull);
    expect(
      StudioDeviceFonts.pick(<DeviceFontFace>[
        (path: 'light', weight: 300),
        (path: 'book', weight: 450),
        (path: 'black', weight: 900),
        (path: 'semi', weight: 600),
      ]),
      ((path: 'book', weight: 450), (path: 'semi', weight: 600)),
    );

    final ReportDocument doc = ReportDocument();
    doc.controller.embedFont('Liberation Sans', sans);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(doc.dirty, isTrue, reason: 'embedding a font is an edit');
    final String path = '${temp.path}/fonts.qrep';
    await doc.saveTo(path);
    final ReportDocument other = ReportDocument();
    await other.open(path);
    expect(other.controller.embeddedFamilies, <String>['Liberation Sans']);
    expect(other.controller.embeddedFonts['Liberation Sans']!.bold, sans.bold);
    expect(other.dirty, isFalse);
    doc.dispose();
    other.dispose();
  });

  test('settings remember the inspector width', () async {
    final File store = File('${temp.path}/cfg/settings.json');
    final StudioSettings settings = StudioSettings(store: store);
    await settings.load();
    expect(settings.inspectorWidth, StudioSettings.defaultInspectorWidth);
    await settings.setInspectorWidth(412.4);

    final StudioSettings again = StudioSettings(store: store);
    await again.load();
    expect(again.inspectorWidth, 412);

    store.writeAsStringSync('not json');
    final StudioSettings corrupt = StudioSettings(store: store);
    await corrupt.load();
    expect(corrupt.inspectorWidth, StudioSettings.defaultInspectorWidth);
  });

  test('settings remember where .qrep files were associated', () async {
    final File store = File('${temp.path}/settings.json');
    final StudioSettings settings = StudioSettings(store: store);
    await settings.setInspectorWidth(400);
    await settings.setAssociatedExecutable('/opt/app/quds_report_studio');
    final StudioSettings again = StudioSettings(store: store);
    await again.load();
    expect(again.inspectorWidth, 400);
    expect(again.associatedExecutable, '/opt/app/quds_report_studio');
  });

  test('association files declare the .qrep type and escape paths', () {
    expect(QrepFileAssociation.mimeXml(), contains('<glob pattern="*.qrep"'));
    expect(
      QrepFileAssociation.mimeXml(),
      contains('type="${QrepFileAssociation.mimeType}"'),
    );
    final String entry = QrepFileAssociation.desktopEntry(
      r'/home/u/My Apps/100% $studio/quds_report_studio',
    );
    expect(
      entry,
      contains(r'Exec="/home/u/My Apps/100%% \\$studio/quds_report_studio" %f'),
    );
    expect(entry, contains('MimeType=${QrepFileAssociation.mimeType};'));
    expect(
      File('packaging/linux/quds-report-studio.xml').readAsStringSync(),
      QrepFileAssociation.mimeXml(),
    );
    expect(
      File(
        'packaging/linux/com.quds.quds_report_studio.desktop.in',
      ).readAsStringSync().replaceFirst('@EXEC@', '"/a/b"'),
      QrepFileAssociation.desktopEntry('/a/b'),
    );
    final String reg = QrepFileAssociation.registryScript(
      r'C:\Program Files\Quds Report Studio\quds_report_studio.exe',
    );
    expect(reg, startsWith('Windows Registry Editor Version 5.00\r\n'));
    expect(
      reg,
      contains(
        r'@="\"C:\\Program Files\\Quds Report Studio\\quds_report_studio.exe\" \"%1\""',
      ),
    );
    expect(reg, contains(r'[HKEY_CURRENT_USER\Software\Classes\.qrep]'));
    expect(reg, contains('@="QudsReportStudio.qrep"'));
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

  testWidgets('new from template walks category, family and language', (
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

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New from template'));
    await tester.pumpAndSettle();
    for (final ReportTemplateCategory c in ReportTemplateCategory.values) {
      expect(find.text('${c.title}  ·  ${c.titleAr}'), findsOneWidget);
    }
    await tester.tap(find.text('Sales  ·  المبيعات'));
    await tester.pumpAndSettle();
    expect(find.text('كتالوج المنتجات'), findsOneWidget);
    await tester.tap(find.text('Product catalog'));
    await tester.pumpAndSettle();
    expect(find.text('العربية'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    final ReportStudioPageState state = tester.state(
      find.byType(ReportStudioPage),
    );
    final ReportDesignerController c = state.document.controller;
    expect(state.document.fileName, 'product_catalog_en.qrep');
    expect(c.template.isRtl, isFalse);
    expect(c.images.keys, contains('product_laptop'));
    expect(state.document.dirty, isFalse);
  });
}
