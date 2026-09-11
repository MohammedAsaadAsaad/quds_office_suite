/// Build every Studio PDF gallery sample and rasterize page 1 (and more) to PNG.
///
/// Run from example/:
///   dart run tool/dump_gallery_shots.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart';

import '../lib/studio_files.dart';
import '../lib/studio_pdf_gallery.dart';

void main() {
  final Directory out = Directory(
    '${Directory.systemTemp.path}/quds_gallery_shots',
  )..createSync(recursive: true);
  for (final FileSystemEntity e in out.listSync()) {
    e.deleteSync(recursive: true);
  }

  final SfntFont? latin = StudioFiles.latinExportFont();
  final OfficeFontSet fonts = StudioFiles.exportFontSetCovering(const <String>[
    'Hello مرحبا',
  ]);
  stdout.writeln('out: ${out.path}');
  stdout.writeln('latin: ${latin != null}');

  var ok = 0;
  var fail = 0;
  for (final StudioPdfSample sample in StudioPdfGallery.all) {
    try {
      final Uint8List bytes = sample.build(font: latin, fonts: fonts);
      if (bytes.length < 100 ||
          String.fromCharCodes(bytes.take(5)) != '%PDF-') {
        throw StateError('not a pdf (${bytes.length} bytes)');
      }
      final File pdf = File('${out.path}/${sample.fileName}');
      pdf.writeAsBytesSync(bytes);
      final String prefix = '${out.path}/${sample.id}';
      final ProcessResult r = Process.runSync('pdftoppm', <String>[
        '-png',
        '-r',
        '110',
        pdf.path,
        prefix,
      ]);
      if (r.exitCode != 0) {
        throw StateError('pdftoppm: ${r.stderr}');
      }
      final List<File> pngs = out
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.contains('/${sample.id}-'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
      stdout.writeln(
        'OK  ${sample.id}  pdf=${bytes.length}  pages=${pngs.length}',
      );
      ok++;
    } catch (e, st) {
      stderr.writeln('FAIL ${sample.id}: $e');
      stderr.writeln('$st');
      fail++;
    }
  }
  stdout.writeln('done ok=$ok fail=$fail → ${out.path}');
  if (fail != 0) {
    exit(1);
  }
}
