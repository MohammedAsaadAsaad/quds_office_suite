// Renders README screenshots with the real fonts. Skipped unless
// QUDS_SHOTS_DIR is set:
//   QUDS_SHOTS_DIR=../../doc/screenshots flutter test test/shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_editor/quds_office_editor.dart';
import 'package:quds_report_studio/main.dart';
import 'package:quds_report_studio/src/recent_files.dart';
import 'package:quds_report_studio/src/report_studio_page.dart';

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

void main() {
  testWidgets('report studio screenshots', (WidgetTester tester) async {
    await tester.runAsync(_loadFonts);
    debugDisableShadows = false;
    final GlobalKey boundary = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(1600, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final Directory temp = Directory.systemTemp.createTempSync('qrs_shots');
    addTearDown(() => temp.deleteSync(recursive: true));
    final RecentFiles recent = RecentFiles(store: File('${temp.path}/r.json'));

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ReportStudioApp(recent: recent),
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

    page.document.newFromTemplate(ReportTemplates.byId('sales_performance')!);
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

    page.document.newFromTemplate(ReportTemplates.byId('invoice_en')!);
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

    page.document.newFromTemplate(ReportTemplates.byId('sales_invoice_ar')!);
    await tester.pump();
    await tester.runAsync(() => _save(boundary, 'studio_rtl_invoice.png'));

    await tester.tap(find.text('File'));
    await tester.pump();
    await tester.tap(find.text('New from template'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() => _save(boundary, 'studio_templates_menu.png'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    debugDisableShadows = true;
  }, skip: _outDir == null);
}
