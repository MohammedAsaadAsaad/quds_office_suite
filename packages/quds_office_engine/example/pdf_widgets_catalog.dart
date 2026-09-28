import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/pdf_widgets_samples.dart';
import 'package:quds_office_engine/quds_office_engine.dart' show SfntFont;

/// Writes the bilingual widgets catalog PDF.
void main(List<String> args) {
  final Directory out = Directory(
    args.isEmpty ? 'example/out/pdf_widgets' : args.first,
  )..createSync(recursive: true);
  final Uint8List bytes = buildWidgetsCatalog(
    font: _loadFont(),
    fontBold: _loadBoldFont(),
  );
  final File file = File('${out.path}/widgets_catalog_bilingual.pdf');
  file.writeAsBytesSync(bytes);
  stdout.writeln('Wrote ${file.path}  (${bytes.length} bytes)');
}

SfntFont? _loadBoldFont() {
  const List<String> paths = <String>[
    '/home/mohammed/.local/share/fonts/Tajawal-Bold.ttf',
    '/usr/share/fonts/truetype/noto/NotoSansArabic-Bold.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
  ];
  for (final String path in paths) {
    final File file = File(path);
    if (file.existsSync()) {
      return SfntFont.parse(file.readAsBytesSync());
    }
  }
  return null;
}

SfntFont? _loadFont() {
  const List<String> paths = <String>[
    '/home/mohammed/.local/share/fonts/Tajawal-Regular.ttf',
    '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  ];
  for (final String path in paths) {
    final File file = File(path);
    if (file.existsSync()) {
      return SfntFont.parse(file.readAsBytesSync());
    }
  }
  return null;
}
