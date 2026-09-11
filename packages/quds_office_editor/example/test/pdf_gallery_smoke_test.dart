import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:quds_office_studio/studio_pdf_gallery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF gallery samples produce valid PDF bytes', () {
    final Directory out = Directory(
      '${Directory.systemTemp.path}/quds_pdf_samples_smoke',
    )..createSync(recursive: true);
    for (final StudioPdfSample sample in StudioPdfGallery.all) {
      // Skip Al Tahreer in CI-ish smoke if assets missing — still try.
      final Uint8List bytes = sample.build();
      expect(bytes.length, greaterThan(200), reason: sample.id);
      expect(
        String.fromCharCodes(bytes.take(5)),
        '%PDF-',
        reason: sample.id,
      );
      File('${out.path}/${sample.fileName}').writeAsBytesSync(bytes);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
