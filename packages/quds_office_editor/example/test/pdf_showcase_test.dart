import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_engine/quds_office_engine.dart';
import 'package:quds_office_studio/studio_pdf_faces.dart';
import 'package:quds_office_studio/studio_pdf_gallery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('showcase tabs cover English, Arabic, and a spanned ledger', () async {
    await StudioPdfFaces.ensureLoaded();
    expect(
      StudioPdfGallery.showcaseSamples.map((StudioPdfSample s) => s.id),
      <String>[
        'showcase-ayat-wa-ashar',
        'showcase-harbour-close',
        'showcase-layl-al-qamar',
        'showcase-two-shores',
        'showcase-cairo-night',
      ],
    );

    final PdfFile diwan = PdfFile.open(
      StudioPdfGallery.all
          .firstWhere((StudioPdfSample s) => s.id == 'showcase-ayat-wa-ashar')
          .build(),
    );
    expect(diwan.pageCount, greaterThan(3));
    expect(String.fromCharCodes(diwan.originalBytes), contains('/Tajawal'));
    final String diwanText = PdfExtract.documentText(diwan);
    expect(_hasArabic(diwanText), isTrue);
    expect(diwanText, contains('قِفَا'));
    expect(diwanText.contains('\u064F'), isTrue, reason: 'damma in tashkeel');

    final PdfFile harbour = PdfFile.open(
      StudioPdfGallery.all
          .firstWhere((StudioPdfSample s) => s.id == 'showcase-harbour-close')
          .build(),
    );
    expect(harbour.pageCount, greaterThan(1));
    expect(PdfExtract.pageText(harbour, 0), contains('Harbour'));
    expect(PdfExtract.documentText(harbour), contains('HQ-18'));
    expect(PdfExtract.pageText(harbour, 0), isNot(contains('HQ-18')));

    final PdfFile qamar = PdfFile.open(
      StudioPdfGallery.all
          .firstWhere((StudioPdfSample s) => s.id == 'showcase-layl-al-qamar')
          .build(),
    );
    expect(qamar.pageCount, greaterThan(1));
    expect(_hasArabic(PdfExtract.pageText(qamar, 0)), isTrue);
    expect(_hasArabic(PdfExtract.pageText(qamar, 1)), isTrue);

    final PdfFile shores = PdfFile.open(
      StudioPdfGallery.all
          .firstWhere((StudioPdfSample s) => s.id == 'showcase-two-shores')
          .build(),
    );
    expect(shores.pageCount, 1);
    final String shoreText = PdfExtract.pageText(shores, 0);
    expect(shoreText, contains('Quay'));
    expect(_hasArabic(shoreText), isTrue);

    final Uint8List cairo = StudioPdfGallery.all
        .firstWhere((StudioPdfSample s) => s.id == 'showcase-cairo-night')
        .build();
    expect(String.fromCharCodes(cairo), contains('/Cairo'));
    final PdfFile night = PdfFile.open(cairo);
    expect(night.pageCount, greaterThan(1));
    expect(_hasArabic(PdfExtract.pageText(night, 0)), isTrue);
    expect(PdfExtract.pageText(night, night.pageCount - 1), contains('Hand-off'));
  });
}

bool _hasArabic(String text) {
  for (final int cp in text.runes) {
    if (cp >= 0x0600 && cp <= 0x06FF) {
      return true;
    }
    if (cp >= 0xFE70 && cp <= 0xFEFF) {
      return true;
    }
  }
  return false;
}
