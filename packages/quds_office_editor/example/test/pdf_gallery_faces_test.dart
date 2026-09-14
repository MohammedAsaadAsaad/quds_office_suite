import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_engine/quds_office_engine.dart';
import 'package:quds_office_studio/studio_pdf_faces.dart';
import 'package:quds_office_studio/studio_pdf_gallery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Cairo and Tajawal gallery samples embed Arabic', () async {
    await StudioPdfFaces.ensureLoaded();
    const String taqrir = '062a06420631064a0631';

    final StudioPdfSample cairo = StudioPdfGallery.all.firstWhere(
      (StudioPdfSample sample) => sample.id == 'widgets-cairo-quarterly',
    );
    final StudioPdfSample tajawal = StudioPdfGallery.all.firstWhere(
      (StudioPdfSample sample) => sample.id == 'widgets-tajawal-briefing',
    );
    expect(cairo.kind, StudioPdfSampleKind.pdfWidgets);
    expect(tajawal.kind, StudioPdfSampleKind.pdfWidgets);
    expect(
      StudioPdfGallery.widgetSamples.map((StudioPdfSample s) => s.id),
      containsAll(<String>[cairo.id, tajawal.id]),
    );

    final Uint8List cairoBytes = cairo.build();
    final Uint8List tajawalBytes = tajawal.build();
    expect(String.fromCharCodes(cairoBytes.take(5)), '%PDF-');
    expect(String.fromCharCodes(tajawalBytes.take(5)), '%PDF-');

    final String cairoPdf = String.fromCharCodes(cairoBytes);
    final String tajawalPdf = String.fromCharCodes(tajawalBytes);
    expect(cairoPdf, contains('/Cairo'));
    expect(cairoPdf.toLowerCase(), contains(taqrir));
    expect(tajawalPdf, contains('/Tajawal'));
    expect(tajawalPdf.toLowerCase(), contains(taqrir));
    expect(cairoPdf, isNot(contains('Liberation')));
    _expectBilingualPages(
      cairoBytes,
      english: 'Al Tahreer',
      arabicFirst: true,
    );
    _expectBilingualPages(
      tajawalBytes,
      english: 'Water access',
      arabicFirst: false,
    );
    expect(StudioPdfFaces.cairo().familyName, 'Cairo');
    expect(StudioPdfFaces.tajawal().familyName, 'Tajawal');
    expect(StudioPdfFaces.tajawalBold().familyName, 'Tajawal');
    for (final String id in <String>[
      'widgets-contents-guide',
      'widgets-arabic-contents',
    ]) {
      final PdfFile file = PdfFile.open(
        StudioPdfGallery.all.firstWhere((StudioPdfSample s) => s.id == id).build(),
      );
      expect(file.pageCount, greaterThan(2), reason: id);
      final List<PdfAnnot> jumps = file
          .annotsOn(0)
          .where((PdfAnnot annot) => annot.goToPage != null && annot.goToPage! > 0)
          .toList();
      expect(jumps.length, greaterThanOrEqualTo(3), reason: id);
    }

    for (final String id in <String>[
      'widgets-atlas',
      'widgets-field-clinic',
      'widgets-board-packet',
      'widgets-recovery-brief',
      'widgets-arabic-contents',
    ]) {
      final StudioPdfSample sample = StudioPdfGallery.all.firstWhere(
        (StudioPdfSample item) => item.id == id,
      );
      final PdfFile file = PdfFile.open(sample.build());
      expect(file.pageCount, greaterThan(1), reason: id);
      final String all = PdfExtract.documentText(file);
      expect(_hasArabic(all), isTrue, reason: id);
    }
  });
}

void _expectBilingualPages(
  Uint8List bytes, {
  required String english,
  required bool arabicFirst,
}) {
  final PdfFile file = PdfFile.open(bytes);
  expect(file.pageCount, 2);
  final String page0 = PdfExtract.pageText(file, 0);
  final String page1 = PdfExtract.pageText(file, 1);
  final String arabicPage = arabicFirst ? page0 : page1;
  final String englishPage = arabicFirst ? page1 : page0;
  expect(_hasArabic(arabicPage), isTrue, reason: arabicPage);
  expect(englishPage, contains(english));
  expect(_hasArabic(englishPage), isFalse, reason: englishPage);
}

bool _hasArabic(String text) {
  for (final int cp in text.runes) {
    if ((cp >= 0x0600 && cp <= 0x06FF) ||
        (cp >= 0xFB50 && cp <= 0xFDFF) ||
        (cp >= 0xFE70 && cp <= 0xFEFF)) {
      return true;
    }
  }
  return false;
}
