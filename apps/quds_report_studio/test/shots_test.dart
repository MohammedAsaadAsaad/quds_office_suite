// Renders README screenshots with the real fonts. Skipped unless
// QUDS_SHOTS_DIR is set:
//   QUDS_SHOTS_DIR=screenshots flutter test test/shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_editor/quds_office_editor.dart';
import 'package:quds_report_studio/main.dart';
import 'package:quds_report_studio/src/device_fonts.dart';
import 'package:quds_report_studio/src/recent_files.dart';
import 'package:quds_report_studio/src/report_studio_page.dart';
import 'package:quds_report_studio/src/studio_settings.dart';
import 'package:quds_report_studio/src/studio_templates.dart';

final String? _outDir = Platform.environment['QUDS_SHOTS_DIR'];

Future<void> _loadFonts() async {
  final String editorFonts =
      '${Directory.current.path}/../../packages/quds_office_editor/fonts';
  final Map<String, List<String>> families = <String, List<String>>{
    'Liberation Sans': <String>[
      'LiberationSans-Regular.ttf',
      'LiberationSans-Bold.ttf',
      'LiberationSans-Italic.ttf',
      'LiberationSans-BoldItalic.ttf',
    ],
    'Liberation Serif': <String>[
      'LiberationSerif-Regular.ttf',
      'LiberationSerif-Bold.ttf',
      'LiberationSerif-Italic.ttf',
    ],
    'Liberation Mono': <String>['LiberationMono-Regular.ttf'],
    'Noto Naskh Arabic': <String>[
      'NotoNaskhArabic-Regular.ttf',
      'NotoNaskhArabic-Bold.ttf',
    ],
  };
  for (final MapEntry<String, List<String>> f in families.entries) {
    final FontLoader loader = FontLoader(f.key);
    for (final String file in f.value) {
      final Uint8List bytes = File('$editorFonts/$file').readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
  final String flutterRoot = File(
    Platform.resolvedExecutable,
  ).parent.parent.parent.parent.parent.parent.path;
  final File icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final FontLoader loader = FontLoader('MaterialIcons')
      ..addFont(
        Future<ByteData>.value(ByteData.sublistView(icons.readAsBytesSync())),
      );
    await loader.load();
  }
}

Future<void> _save(GlobalKey key, String name) async {
  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ui.Image image = await boundary.toImage(pixelRatio: 1);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  final Directory dir = Directory(_outDir!)..createSync(recursive: true);
  File('${dir.path}/$name').writeAsBytesSync(data!.buffer.asUint8List());
}

late List<ReportTemplateInfo> _bundled;

ReportTemplateInfo _byId(String id) =>
    _bundled.firstWhere((ReportTemplateInfo t) => t.id == id);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _bundled = await ReportTemplateLibrary.bundled();
  });
  testWidgets('report studio screenshots', (WidgetTester tester) async {
    await tester.runAsync(_loadFonts);
    debugDisableShadows = false;
    final GlobalKey boundary = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(1600, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final Directory temp = Directory.systemTemp.createTempSync('qrs_shots');
    addTearDown(() => temp.deleteSync(recursive: true));
    final RecentFiles recent = RecentFiles(store: File('${temp.path}/r.json'));
    final StudioSettings settings = StudioSettings(persist: false);
    final StudioTemplates catalog = StudioTemplates(
      bundled: _bundled,
      folder: Directory('${temp.path}/templates'),
    );
    await tester.runAsync(() async {
      for (final String id in <String>['receipt_voucher_en', 'inventory_ar']) {
        final ReportTemplateInfo info = _byId(id);
        await catalog.save(
          info.package(),
          title: id == 'inventory_ar' ? 'جرد الفرع الرئيسي' : 'Branch receipt',
          category: info.category,
          rtl: info.rtl,
        );
      }
    });

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ReportStudioApp(
          templates: catalog,
          recent: recent,
          settings: settings,
          deviceFonts: StudioDeviceFonts(),
        ),
      ),
    );
    await tester.runAsync(() => ReportBundledFonts.shared());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final ReportStudioPageState page = tester.state(
      find.byType(ReportStudioPage),
    );
    final ReportDesignerController c = page.document.controller;
    c.addVariable(name: 'companyName', value: 'Quds Trading Co.');
    c.addVariable(
      name: 'vatRate',
      type: ReportVariableType.number,
      value: '15',
    );
    c.setProperty('var.1.format', 'percent');
    await tester.pump();
    await tester.runAsync(() => _save(boundary, 'studio_report_settings.png'));
    c.addVariable(name: 'stats.sum', type: ReportVariableType.number);
    c.addVariable(name: 'stats.avg', type: ReportVariableType.number);
    c.addVariable(name: 'stats.count', type: ReportVariableType.number);
    c.addVariable(name: 'company.address', value: 'Ramallah');
    c.selectedVariablePath = 'stats.avg';
    c.inspectorPage = ReportInspectorPage.variables;
    await tester.pump();
    await tester.runAsync(() => _save(boundary, 'studio_variables.png'));
    c.inspectorPage = ReportInspectorPage.properties;

    final ReportElement text = c.template.allElements
        .map(((ReportBand, ReportElement) be) => be.$2)
        .whereType<ReportTextElement>()
        .firstWhere(
          (ReportTextElement t) => (t.style.bold ?? false) && t.text.length > 6,
        );
    c.select(text.id);
    await tester.pump();
    await tester.runAsync(() => _save(boundary, 'studio_text_inspector.png'));

    final RenderReportInspector inspector = tester.renderObject(
      find.byType(ReportInspector),
    );
    inspector.openPalette('color');
    await tester.pump();
    await tester.runAsync(() => _save(boundary, 'studio_color_palette.png'));
    inspector.openPalette(null);

    page.document.newFromTemplate(_byId('sales_performance'));
    await tester.pump();
    final ReportElement chart = c.template.allElements
        .map(((ReportBand, ReportElement) be) => be.$2)
        .firstWhere((ReportElement e) => e is ReportChartElement);
    c.select(chart.id);
    await tester.pump();
    await tester.runAsync(() => _save(boundary, 'studio_chart.png'));

    c.select(null);
    c.togglePreview();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => _save(boundary, 'studio_preview.png'));
    c.togglePreview();
    await tester.pump();

    page.document.newFromTemplate(_byId('invoice_en'));
    await tester.pump();
    final ReportTextElement bound = c.template.allElements
        .map(((ReportBand, ReportElement) be) => be.$2)
        .whereType<ReportTextElement>()
        .firstWhere((ReportTextElement t) => t.text.contains('{{Data.'));
    c.beginTextEdit(bound.id);
    c.textEditor.replaceRange(0, c.textEditor.formulaBar.length, '{{Data.');
    await tester.pump();
    await tester.runAsync(() => _save(boundary, 'studio_autocomplete.png'));
    c.cancelTextEdit();
    await tester.pump();

    c.select(null);
    c.toggleData();
    c.selectDataTable('items');
    c.addDataColumn(
      name: 'lineTotal',
      type: ReportDataType.number,
      expression: 'qty * unitPrice',
    );
    c.setProperty('data.col.format', 'n2');
    c.selectDataCell(2, c.dataColumn);
    await tester.pump();
    await tester.runAsync(() => _save(boundary, 'studio_data_explorer.png'));
    c.selectDataTable('');
    c.selectDataCell(3, 1);
    await tester.pump();
    await tester.runAsync(() => _save(boundary, 'studio_data_fields.png'));
    c.toggleData();
    await tester.pump();
    final ReportTextElement line = c.template.allElements
        .map(((ReportBand, ReportElement) be) => be.$2)
        .whereType<ReportTextElement>()
        .firstWhere((ReportTextElement t) => t.text.contains('{{Data.'));
    c.beginTextEdit(line.id);
    c.textEditor.replaceRange(
      0,
      c.textEditor.formulaBar.length,
      'Lines total: {{SUM(items.line',
    );
    await tester.pump();
    await tester.runAsync(
      () => _save(boundary, 'studio_calculated_autocomplete.png'),
    );
    c.cancelTextEdit();
    c.select(null);
    page.document.newFromTemplate(_byId('invoice_en'));
    await tester.pump();
    c.addImage(
      'company_logo.png',
      PngBytes.rgb(
        width: 360,
        height: 120,
        plot: (int x, int y, List<int> rgb) {
          final bool mark = (x - 60) * (x - 60) + (y - 60) * (y - 60) < 1600;
          rgb[0] = mark ? 245 : 30 + x ~/ 6;
          rgb[1] = mark ? 158 : 58 + y ~/ 4;
          rgb[2] = mark ? 11 : 138;
        },
      ),
    );
    c.addImage(
      'paid_stamp.png',
      PngBytes.rgb(
        width: 200,
        height: 200,
        plot: (int x, int y, List<int> rgb) {
          final int d = (x - 100) * (x - 100) + (y - 100) * (y - 100);
          final bool ring = d < 9000 && d > 6400;
          rgb[0] = ring ? 200 : 255;
          rgb[1] = ring ? 30 : 255;
          rgb[2] = ring ? 40 : 255;
        },
      ),
    );
    c.inspectorPage = ReportInspectorPage.images;
    for (int i = 0; i < 4; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
    }
    await tester.pump();
    await tester.runAsync(() => _save(boundary, 'studio_images.png'));
    c.insertImage('company_logo');
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => _save(boundary, 'studio_image_element.png'));

    page.document.newFromTemplate(_byId('invoice_en'));
    c.select(null);
    await tester.runAsync(c.loadDeviceFamilies);
    c.inspectorPage = ReportInspectorPage.fonts;
    final List<String> installed = c.deviceFamilies ?? const <String>[];
    final String family = installed.contains('Lato')
        ? 'Lato'
        : installed.firstWhere(
            (String f) => f.contains('Sans'),
            orElse: () => 'Liberation Serif',
          );
    await tester.runAsync(() => c.embedDeviceFont(family));
    c.setProperty('font.0.default', 'true');
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => _save(boundary, 'studio_fonts.png'));
    c.beginPropertyEdit('font.add');
    final InlineCellEditor query = c.propertyEditor;
    query.replaceRange(0, query.formulaBar.length, 'Noto');
    // Widget tests paint unknown families as boxes; load what the picker shows.
    await tester.runAsync(() async {
      final StudioDeviceFonts device = StudioDeviceFonts();
      for (final ReportCompletionItem item
          in c.completion?.items.take(10) ?? const <ReportCompletionItem>[]) {
        final ReportFontFiles? files = await device.load(item.insert);
        final Uint8List? bytes = files?.regular ?? files?.bold;
        if (bytes != null) {
          await (FontLoader(item.insert)
                ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes))))
              .load();
        }
      }
    });
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() => _save(boundary, 'studio_font_picker.png'));
    c.cancelPropertyEdit();
    await tester.pump();

    page.document.newFromTemplate(_byId('sales_invoice_ar'));
    await tester.pump();
    await tester.runAsync(() => _save(boundary, 'studio_rtl_invoice.png'));

    await tester.tap(find.text('File'));
    await tester.pump();
    await tester.tap(find.text('New from template'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Sales  ·  المبيعات'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Product catalog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() => _save(boundary, 'studio_templates_menu.png'));
    await tester.tap(find.text('My templates'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() => _save(boundary, 'studio_my_templates.png'));
    await tester.tap(find.text('Sales  ·  المبيعات'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Product catalog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('العربية'));
    await tester.pump();
    c.zoom = 1.1;
    c.inspectorPage = ReportInspectorPage.images;
    c.togglePreview();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => _save(boundary, 'studio_template_catalog.png'));
    c.togglePreview();

    page.document.newFromTemplate(_byId('certificate_en'));
    c.zoom = 0.95;
    c.togglePreview();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => _save(boundary, 'studio_template_certificate.png'),
    );
    c.togglePreview();
    await tester.pump();

    page.document.newFromTemplate(_byId('sales_invoice_ar'));
    c.zoom = 0.9;
    await settings.setLanguage(StudioLanguage.arabic);
    await tester.pumpAndSettle();
    c.addVariable(name: 'stats.sum', type: ReportVariableType.number);
    c.addVariable(name: 'stats.avg', type: ReportVariableType.number);
    c.selectedVariablePath = 'stats.sum';
    c.inspectorPage = ReportInspectorPage.variables;
    await tester.pump();
    await tester.runAsync(() => _save(boundary, 'studio_arabic_ui.png'));

    await settings.setTheme(StudioThemeChoice.dark);
    await tester.pumpAndSettle();
    await tester.runAsync(() => _save(boundary, 'studio_dark_arabic.png'));

    await settings.setLanguage(StudioLanguage.english);
    page.document.newFromTemplate(_byId('invoice_en'));
    c.zoom = 0.9;
    final ReportTextElement title = c.template.allElements
        .map(((ReportBand, ReportElement) be) => be.$2)
        .whereType<ReportTextElement>()
        .firstWhere(
          (ReportTextElement t) => (t.style.bold ?? false) && t.text.length > 6,
        );
    c.select(title.id);
    await tester.pumpAndSettle();
    await tester.runAsync(() => _save(boundary, 'studio_dark.png'));

    await settings.setTheme(StudioThemeChoice.light);
    page.document.newFromTemplate(_byId('invoice_en'));
    c.zoom = 0.9;
    final List<ReportTextElement> texts = c.template.allElements
        .map(((ReportBand, ReportElement) be) => be.$2)
        .whereType<ReportTextElement>()
        .toList();
    c.select(texts[3].id);
    c.setProperty('text', '{{FORMATDATE(Data.invoice.date)}}');
    c.select(texts[1].id);
    c.setProperty('width', '260');
    c.select(texts[5].id);
    c.setProperty('visibleWhen', 'Data.total >');
    c.addVariable(
      name: 'discountRate',
      type: ReportVariableType.number,
      value: '5 percent',
    );
    c.select(null);
    c.problemsOpen = true;
    await tester.pumpAndSettle();
    c.revealDiagnostic(c.problems.first);
    await tester.pumpAndSettle();
    await tester.runAsync(() => _save(boundary, 'studio_problems.png'));
    await settings.setLanguage(StudioLanguage.arabic);
    await tester.pumpAndSettle();
    c.revealDiagnostic(c.problems[1]);
    await tester.pumpAndSettle();
    await tester.runAsync(() => _save(boundary, 'studio_problems_arabic.png'));
    await tester.pumpWidget(const SizedBox.shrink());
    debugDisableShadows = true;
  }, skip: _outDir == null);
}
