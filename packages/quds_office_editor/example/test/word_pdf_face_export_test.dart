import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_engine/quds_office_engine.dart';
import 'package:quds_office_studio/studio_files.dart';
import 'package:quds_office_studio/studio_pdf_faces.dart';

const String _phrase = 'تقرير ربع سنوي';

void main() {
  test('Word PDF embeds Tajawal when that face is registered', () {
    final SfntFont? tajawal = StudioPdfFaces.tryFamily('Tajawal');
    expect(tajawal, isNotNull, reason: 'example/fonts/Tajawal-Regular.ttf');
    expect(StudioPdfFaces.coversArabic(tajawal!), isTrue);

    final WmlDocument doc = _doc(_phrase, family: 'Arial');
    final OfficeFontSet fonts = StudioFiles.exportFontSetForWord(
      doc,
      themeFamily: 'Tajawal',
    );
    expect(fonts.primary?.familyName, 'Tajawal');

    final Uint8List pdf = OfficePdfExport.word(
      doc,
      fonts: fonts,
      title: 'Tajawal',
    );
    final String ascii = latin1.decode(pdf, allowInvalid: true);
    expect(ascii, contains('/Tajawal'));
    expect(ascii, contains('/Identity-H'));
    expect(ascii, isNot(contains('/NotoNaskhArabic')));

    final String inflated = _inflateAll(pdf);
    expect(inflated.toLowerCase(), contains('fef3'));
    final String folded = ArabicShaper.foldPresentation(
      PdfExtract.pageText(PdfFile.open(pdf), 0),
    );
    for (final int cp in _phrase.runes) {
      if (cp == 0x20) {
        continue;
      }
      expect(folded.runes, contains(cp));
    }
  });

  test('Word PDF embeds Cairo when that is the run face', () {
    final SfntFont? cairo = StudioPdfFaces.tryFamily('Cairo');
    expect(cairo, isNotNull, reason: 'example/fonts/Cairo-Regular.ttf');
    expect(StudioPdfFaces.coversArabic(cairo!), isTrue);

    final WmlDocument doc = _doc(_phrase, family: 'Cairo');
    final OfficeFontSet fonts = StudioFiles.exportFontSetForWord(
      doc,
      themeFamily: 'Tajawal',
    );
    expect(fonts.primary?.familyName, 'Cairo');

    final Uint8List pdf = OfficePdfExport.word(
      doc,
      fonts: fonts,
      title: 'Cairo',
    );
    final String ascii = latin1.decode(pdf, allowInvalid: true);
    expect(ascii, contains('/Cairo'));
    expect(ascii, contains('/Identity-H'));
    expect(ascii, isNot(contains('/Tajawal')));
    expect(ascii, isNot(contains('/NotoNaskhArabic')));
    expect(_inflateAll(pdf).toLowerCase(), contains('fef3'));
  });
}

WmlDocument _doc(String text, {required String family}) {
  return WmlDocument(
    sections: <WmlSection>[
      WmlSection(
        blocks: <WmlBlock>[
          WmlParagraph(
            properties: WmlParagraphProps(
              rightToLeft: true,
              justification: WmlJustification.right,
            ),
            inlines: <WmlInline>[
              WmlRun(
                text: text,
                properties: WmlRunProps(asciiFont: family, csFont: family),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

String _inflateAll(Uint8List pdf) {
  final StringBuffer out = StringBuffer();
  final List<int> mark = 'stream\n'.codeUnits;
  var i = 0;
  while (i < pdf.length - mark.length) {
    var hit = true;
    for (int k = 0; k < mark.length; k++) {
      if (pdf[i + k] != mark[k]) {
        hit = false;
        break;
      }
    }
    if (!hit) {
      i++;
      continue;
    }
    final int start = i + mark.length;
    final int end = _indexOf(pdf, 'endstream', start);
    if (end < 0) {
      break;
    }
    var payload = Uint8List.sublistView(pdf, start, end);
    if (payload.isNotEmpty && payload.last == 0x0A) {
      payload = Uint8List.sublistView(payload, 0, payload.length - 1);
    }
    if (payload.length >= 2 && payload[0] == 0x78) {
      try {
        out.write(
          utf8.decode(PdfFlate.decompress(payload), allowMalformed: true),
        );
      } on Object {
        out.write(latin1.decode(payload, allowInvalid: true));
      }
    } else {
      out.write(latin1.decode(payload, allowInvalid: true));
    }
    i = end + 9;
  }
  return out.toString();
}

int _indexOf(Uint8List data, String token, int from) {
  final List<int> needle = token.codeUnits;
  for (int i = from; i <= data.length - needle.length; i++) {
    var ok = true;
    for (int k = 0; k < needle.length; k++) {
      if (data[i + k] != needle[k]) {
        ok = false;
        break;
      }
    }
    if (ok) {
      return i;
    }
  }
  return -1;
}
