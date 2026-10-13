// Designer frames for the chart gallery and the country shape map.
//   QUDS_SHOTS_DIR=screenshots flutter test test/chart_shots_test.dart
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
}

Future<void> _save(GlobalKey key, String name) async {
  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ui.Image image = await boundary.toImage(pixelRatio: 1);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  final Directory dir = Directory(_outDir!)..createSync(recursive: true);
  File('${dir.path}/$name').writeAsBytesSync(data!.buffer.asUint8List());
}

void _reveal(ReportDesignerController c, String name) {
  final List<(ReportBand, ReportElement)> all = c.template.allElements.toList();
  final int index = all.indexWhere(
    ((ReportBand, ReportElement) be) => be.$2.name == name,
  );
  final ReportBandKind kind = all[index].$1.kind;
  final int at = all[index].$1.elements.indexOf(all[index].$2);
  c.revealDiagnostic(
    ReportDiagnostic(
      ReportDiagnosticSeverity.warning,
      'Bands/${kind.xmlName}/Chart[$at]',
      'show',
    ),
  );
}

void main() {
  testWidgets('chart gallery and shape map screenshots', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(_loadFonts);
    debugDisableShadows = false;
    final GlobalKey boundary = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(1600, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final Directory temp = Directory.systemTemp.createTempSync('qrs_chart');
    addTearDown(() => temp.deleteSync(recursive: true));
    final List<ReportTemplateInfo> bundled =
        await tester.runAsync(ReportTemplateLibrary.bundled) ??
        const <ReportTemplateInfo>[];
    final ReportTemplateInfo gallery = bundled.firstWhere(
      (ReportTemplateInfo t) => t.id == 'chart_gallery_en',
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ReportStudioApp(
          templates: StudioTemplates(
            bundled: bundled,
            folder: Directory('${temp.path}/templates'),
          ),
          recent: RecentFiles(store: File('${temp.path}/r.json')),
          settings: StudioSettings(persist: false),
          deviceFonts: StudioDeviceFonts(),
        ),
      ),
    );
    await tester.runAsync(() => ReportBundledFonts.shared());
    await tester.pump(const Duration(milliseconds: 100));
    final ReportStudioPageState page = tester.state(
      find.byType(ReportStudioPage),
    );
    final ReportDesignerController c = page.document.controller;
    page.document.newFromTemplate(gallery);
    c.zoom = 0.55;
    _reveal(c, 'combo');
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => _save(boundary, 'studio_chart_gallery.png'));

    c.zoom = 0.72;
    _reveal(c, 'worldMap');
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => _save(boundary, 'studio_shape_map.png'));

    c.zoom = 0.85;
    c.togglePreview();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final RenderReportPreview preview = tester.renderObject(
      find.byType(ReportPreviewSurface),
    );
    preview.showPage(4);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => _save(boundary, 'studio_shape_map_preview.png'));
    await tester.pumpWidget(const SizedBox.shrink());
    debugDisableShadows = true;
  }, skip: _outDir == null);
}
