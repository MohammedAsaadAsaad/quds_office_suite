import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart';

/// Writes Office bytes plus a matching print-layout PDF.
class GallerySink {
  GallerySink(this.root, {this.font});

  final Directory root;
  final SfntFont? font;
  final List<String> written = <String>[];

  void office(
    String relativePath,
    Uint8List bytes, {
    String? title,
    bool notesPages = false,
    Uint8List? pdfBytes,
  }) {
    final File file = File('${root.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    written.add(relativePath);

    final String stem = relativePath.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final Uint8List pdf =
        pdfBytes ??
        OfficePdfExport.fromBytes(
          bytes,
          font: font,
          title: title ?? stem.split('/').last,
        );
    final String pdfName = '$stem.pdf';
    File('${root.path}/$pdfName').writeAsBytesSync(pdf);
    written.add(pdfName);

    if (notesPages) {
      final Uint8List notes = OfficePdfExport.presentation(
        SlideDeserializer().readBytes(bytes),
        font: font,
        title: '${title ?? stem} notes',
        mode: PdfSlideExportMode.notesPages,
      );
      final String notesName = '$stem.notes.pdf';
      File('${root.path}/$notesName').writeAsBytesSync(notes);
      written.add(notesName);
    }
  }

  void writeManifest() {
    final StringBuffer buf = StringBuffer()
      ..writeln('Quds Office Engine gallery')
      ..writeln(
        'font: ${font == null ? 'Helvetica fallback' : 'embedded SFNT subset'}',
      )
      ..writeln();
    for (final String name in written) {
      final File file = File('${root.path}/$name');
      buf.writeln('${file.lengthSync().toString().padLeft(10)}  $name');
    }
    File('${root.path}/manifest.txt').writeAsStringSync(buf.toString());
  }
}

SfntFont? loadSystemUiFont() {
  const List<String> candidates = <String>[
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
    '/usr/share/fonts/truetype/freefont/FreeSans.ttf',
  ];
  for (final String path in candidates) {
    final File file = File(path);
    if (file.existsSync()) {
      return SfntFont.parse(file.readAsBytesSync());
    }
  }
  return null;
}
