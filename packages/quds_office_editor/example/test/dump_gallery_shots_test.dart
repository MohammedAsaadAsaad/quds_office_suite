import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_engine/quds_office_engine.dart';
import 'package:quds_office_studio/studio_files.dart';
import 'package:quds_office_studio/studio_pdf_gallery.dart';

void main() {
  test('dump every Studio PDF gallery sample to PNG', () {
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
    // ignore: avoid_print
    print('out=${out.path} latin=${latin != null}');

    var fail = 0;
    for (final StudioPdfSample sample in StudioPdfGallery.all) {
      try {
        final Uint8List bytes = sample.build(font: latin, fonts: fonts);
        expect(bytes.length, greaterThan(100));
        final File pdf = File('${out.path}/${sample.fileName}');
        pdf.writeAsBytesSync(bytes);
        final ProcessResult r = Process.runSync('pdftoppm', <String>[
          '-png',
          '-r',
          '110',
          '-f',
          '1',
          '-l',
          '2',
          pdf.path,
          '${out.path}/${sample.id}',
        ]);
        expect(r.exitCode, 0, reason: '${sample.id}: ${r.stderr}');
        final PdfFile file = PdfFile.open(bytes);
        // ignore: avoid_print
        print('OK ${sample.id} pages=${file.pageCount} bytes=${bytes.length}');
      } catch (e) {
        fail++;
        // ignore: avoid_print
        print('FAIL ${sample.id}: $e');
      }
    }
    expect(fail, 0);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
