// Renders README screenshots with the real fonts. Skipped unless
// QUDS_SHOTS_DIR is set:
//   QUDS_SHOTS_DIR=screenshots flutter test test/studio_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_editor/quds_office_editor.dart';
import 'package:quds_office_studio/main.dart';

final String? _outDir = Platform.environment['QUDS_SHOTS_DIR'];

Future<void> _loadFonts() async {
  await OfficeHostFonts.ensureRegistered();
  final String fonts = '${Directory.current.path}/../fonts';
  final String local = '${Directory.current.path}/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String file in files) {
      final Uint8List bytes = File(file).readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  final List<String> sans = <String>[
    '$fonts/LiberationSans-Regular.ttf',
    '$fonts/LiberationSans-Bold.ttf',
    '$fonts/LiberationSans-Italic.ttf',
    '$fonts/LiberationSans-BoldItalic.ttf',
  ];
  for (final String alias in <String>[
    'Segoe UI',
    'Aptos',
    'Calibri Light',
    'Tahoma',
    'Verdana',
    'Arial Black',
  ]) {
    await family(alias, sans);
  }
  await family('Cambria', <String>[
    '$fonts/LiberationSerif-Regular.ttf',
    '$fonts/LiberationSerif-Bold.ttf',
  ]);
  await family('Cairo', <String>['$local/Cairo-Regular.ttf']);
  await family('Tajawal', <String>[
    '$local/Tajawal-Regular.ttf',
    '$local/Tajawal-Bold.ttf',
  ]);
  final String flutterRoot = File(
    Platform.resolvedExecutable,
  ).parent.parent.parent.parent.parent.parent.path;
  final File icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    await family('MaterialIcons', <String>[icons.path]);
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
  testWidgets('capture Word, Excel, PowerPoint, and PDF studio frames', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(_loadFonts);
    debugDisableShadows = false;
    final GlobalKey boundaryKey = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(1760, 990));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(key: boundaryKey, child: const QudsOfficeStudioApp()),
    );
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    await settle();
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    tester.binding.handlePointerEvent(mouse.hover(const Offset(640, 400)));
    tester.binding.handlePointerEvent(mouse.scroll(const Offset(0, 1250)));
    await settle();
    await tester.runAsync(() => _save(boundaryKey, 'word.png'));

    for (final (String tab, String file) in <(String, String)>[
      ('Excel', 'excel.png'),
      ('PowerPoint', 'powerpoint.png'),
      ('PDF', 'pdf.png'),
    ]) {
      await tester.tap(find.text(tab).first);
      await settle();
      if (tab == 'PDF') {
        await tester.tap(find.text('صفحة').first);
      }
      await settle();
      await tester.runAsync(() => _save(boundaryKey, file));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    debugDisableShadows = true;
  }, skip: _outDir == null);
}
