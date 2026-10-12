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
import 'package:quds_report_studio/src/studio_templates.dart';

late List<ReportTemplateInfo> _bundled;

/// Lets real file I/O started inside a widget test finish: pumps until
/// [done] holds (or five seconds pass).
Future<void> settleIo(WidgetTester tester, {bool Function()? done}) async {
  for (int i = 0; i < 250 && !(done?.call() ?? i >= 8); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

StudioTemplates _catalog() =>
    StudioTemplates(bundled: _bundled, persist: false);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _bundled = await ReportTemplateLibrary.bundled();
  });
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('qrs_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('documents track unsaved changes and round-trip files', () async {
    final ReportDocument doc = ReportDocument();
    doc.newFromTemplate(_bundled.first);
    expect(doc.dirty, isFalse);
    expect(doc.fileName, '${_bundled.first.id}.qrep');

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
    File(legacy).writeAsStringSync(_bundled.first.xml);
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
    await tester.pumpWidget(
      ReportStudioApp(templates: _catalog(), recent: recent),
    );
    await tester.pump();

    expect(find.byType(QudsReportDesigner), findsOneWidget);
    expect(
      find.textContaining(_bundled.first.id, findRichText: true),
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

  testWidgets('a file with problems opens quietly; the status bar lists them', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final String path = '${temp.path}/broken.qrep';
    final ReportPackage good = _bundled.first.package();
    File(path).writeAsBytesSync(
      ReportPackage(
        xml: good.xml.replaceFirst(
          '<Bands>',
          '<Variables><Var name="broken" value="{{SUM(x}}"/></Variables>'
              '<Bands>',
        ),
        images: good.images,
        fonts: good.fonts,
      ).encode(),
    );
    await tester.pumpWidget(
      ReportStudioApp(
        templates: _catalog(),
        recent: RecentFiles(store: File('${temp.path}/recent.json')),
        initialPath: path,
      ),
    );
    await settleIo(
      tester,
      done: () =>
          tester
              .state<ReportStudioPageState>(find.byType(ReportStudioPage))
              .document
              .path ==
          path,
    );
    expect(find.byType(SnackBar), findsNothing);
    final ReportDesignerController c = tester
        .state<ReportStudioPageState>(find.byType(ReportStudioPage))
        .document
        .controller;
    expect(c.problems.where((ReportDiagnostic d) => d.isError), isNotEmpty);
    expect(find.byType(ReportProblemsPanel), findsNothing);

    await tester.tap(find.byTooltip('Show problems'));
    await tester.pumpAndSettle();
    expect(c.problemsOpen, isTrue);
    final Rect panel = tester.getRect(find.byType(ReportProblemsPanel));
    await tester.tapAt(
      panel.topLeft + const Offset(200, RenderReportProblems.headerHeight + 20),
    );
    await tester.pump();
    expect(c.inspectorPage, ReportInspectorPage.variables);
    expect(c.selectedVariablePath, 'broken');

    await tester.tap(find.byTooltip('Hide problems'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportProblemsPanel), findsNothing);
  });

  test('settings remember the theme and the language', () async {
    final File store = File('${temp.path}/settings.json');
    final StudioSettings settings = StudioSettings(store: store);
    expect(settings.theme, StudioThemeChoice.system);
    expect(settings.language, StudioLanguage.system);
    int changes = 0;
    settings.addListener(() => changes++);
    await settings.setTheme(StudioThemeChoice.dark);
    await settings.setLanguage(StudioLanguage.arabic);
    await settings.setLanguage(StudioLanguage.arabic);
    expect(changes, 2);

    final StudioSettings again = StudioSettings(store: store);
    await again.load();
    expect(again.theme, StudioThemeChoice.dark);
    expect(again.language, StudioLanguage.arabic);
  });

  testWidgets('settings switch the studio to Arabic and the dark theme', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final RecentFiles recent = RecentFiles(
      store: File('${temp.path}/recent.json'),
    );
    final StudioSettings settings = StudioSettings(persist: false);
    await tester.pumpWidget(
      ReportStudioApp(
        templates: _catalog(),
        recent: recent,
        settings: settings,
      ),
    );
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(settings.language, StudioLanguage.arabic);
    expect(find.text('محفوظ'), findsOneWidget);
    expect(find.text('ملف'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(ReportStudioPage))),
      TextDirection.rtl,
    );
    final ReportStudioPageState state = tester.state(
      find.byType(ReportStudioPage),
    );
    await tester.pump();
    expect(state.document.controller.strings.isRtl, isTrue);

    await settings.setTheme(StudioThemeChoice.dark);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(ReportStudioPage))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('prints the report at its page size', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final RecentFiles recent = RecentFiles(
      store: File('${temp.path}/recent.json'),
    );
    final List<(Uint8List, String, double, double)> jobs =
        <(Uint8List, String, double, double)>[];
    await tester.pumpWidget(
      ReportStudioApp(
        templates: _catalog(),
        recent: recent,
        printer:
            (
              Uint8List document, {
              required String name,
              required double width,
              required double height,
            }) async {
              jobs.add((document, name, width, height));
              return true;
            },
      ),
    );
    await tester.pump();
    final ReportStudioPageState state = tester.state(
      find.byType(ReportStudioPage),
    );
    final ReportTemplate t = state.document.controller.template;

    await tester.tap(find.byTooltip('Print (Ctrl+P)'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(jobs, hasLength(1));
    expect(String.fromCharCodes(jobs.first.$1.take(5)), '%PDF-');
    expect(jobs.first.$2, state.document.name);
    expect(jobs.first.$3, t.pageWidth);
    expect(jobs.first.$4, t.pageHeight);

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Print…'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(jobs, hasLength(2));
  });

  test('user templates save, reload, and accept plain report files', () async {
    final Directory dir = Directory('${temp.path}/templates');
    final StudioTemplates catalog = StudioTemplates(
      bundled: _bundled,
      folder: dir,
    );
    await catalog.load();
    expect(catalog.user, isEmpty);

    final ReportTemplateInfo source = _bundled.first;
    final ReportTemplateInfo saved = await catalog.save(
      source.package(),
      title: 'فاتورتي',
      category: ReportTemplateCategory.finance,
      rtl: true,
    );
    expect(saved.id, StudioTemplates.idFor('فاتورتي'));
    expect(saved.id, startsWith('template_'));
    expect(saved.category, ReportTemplateCategory.finance);
    expect(saved.language, ReportTemplateLanguage.arabic);
    expect(saved.images().keys.toSet(), source.images().keys.toSet());

    await catalog.save(
      source.package(),
      title: 'فاتورتي',
      category: ReportTemplateCategory.sales,
      rtl: true,
    );
    expect(catalog.user, hasLength(1), reason: 'same title replaces');
    expect(catalog.user.single.category, ReportTemplateCategory.sales);

    File('${dir.path}/Plain Report.qrep').writeAsBytesSync(
      ReportPackage(
        xml: _bundled.firstWhere((ReportTemplateInfo t) => !t.rtl).xml,
      ).encode(),
    );
    File('${dir.path}/broken.qrep').writeAsStringSync('not a report');
    await catalog.load();
    expect(catalog.user.map((ReportTemplateInfo t) => t.title), <String>[
      'Plain Report',
      'فاتورتي',
    ]);
    expect(catalog.user.first.id, 'plain_report');
    expect(catalog.user.first.language, ReportTemplateLanguage.english);
    expect(catalog.skipped, <String>['broken.qrep']);
    expect(catalog.all, hasLength(_bundled.length + 2));
  });

  testWidgets('saves the report as a template and opens it from My templates', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final RecentFiles recent = RecentFiles(
      store: File('${temp.path}/recent.json'),
    );
    final StudioTemplates catalog = StudioTemplates(
      bundled: _bundled,
      folder: Directory('${temp.path}/templates'),
    );
    await tester.pumpWidget(
      ReportStudioApp(templates: catalog, recent: recent),
    );
    await tester.pump();
    final ReportStudioPageState state = tester.state(
      find.byType(ReportStudioPage),
    );
    final ReportDesignerController c = state.document.controller;
    c.select(null);
    c.setProperty('name', 'Branch invoice');
    expect(c.template.name, 'Branch invoice');

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finance'));
    await settleIo(tester, done: () => catalog.user.isNotEmpty);
    expect(catalog.user.single.title, 'Branch invoice');
    expect(
      File('${temp.path}/templates/branch_invoice.qrep').existsSync(),
      isTrue,
    );

    state.document.newBlank();
    await tester.pump();
    await tester.tap(find.text('File'));
    await settleIo(tester);
    await tester.tap(find.text('New from template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My templates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Branch invoice'));
    await tester.pumpAndSettle();
    expect(c.template.name, 'Branch invoice');
    expect(state.document.fileName, 'branch_invoice.qrep');
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
    await tester.pumpWidget(
      ReportStudioApp(templates: _catalog(), recent: recent),
    );
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
