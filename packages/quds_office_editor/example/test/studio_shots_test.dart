import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_studio/main.dart';

void main() {
  testWidgets('capture Word, Excel, and PowerPoint studio frames', (
    WidgetTester tester,
  ) async {
    final GlobalKey boundaryKey = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: const QudsOfficeStudioApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.runAsync(() => _save(boundaryKey, 'word.png'));

    await tester.tap(find.text('Excel').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.runAsync(() => _save(boundaryKey, 'excel.png'));

    await tester.tap(find.text('PowerPoint').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.runAsync(() => _save(boundaryKey, 'powerpoint.png'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _save(GlobalKey key, String name) async {
  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ui.Image image = await boundary.toImage(pixelRatio: 1);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final Directory dir = Directory(
    '${Directory.current.path}/screenshots',
  );
  dir.createSync(recursive: true);
  File('${dir.path}/$name').writeAsBytesSync(byteData!.buffer.asUint8List());
}
