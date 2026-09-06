import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart';
import 'package:test/test.dart';

void main() {
  final SfntFont? font = _tryFont();

  test('Word PDF keeps pages, headers, tables, lists, and pictures', () {
    final WmlDocument doc = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          header: <WmlParagraph>[
            WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Quds header')]),
          ],
          footer: <WmlParagraph>[
            WmlParagraph(
              properties: WmlParagraphProps(
                justification: WmlJustification.center,
                pageNumberField: true,
              ),
            ),
          ],
          blocks: <WmlBlock>[
            WmlParagraph(
              properties: WmlParagraphProps(listLabel: '1. '),
              inlines: <WmlInline>[
                WmlRun(
                  text: 'Phase one',
                  properties: WmlRunProps(
                    bold: true,
                    underline: WmlUnderline.double,
                    highlight: 'yellow',
                    strike: true,
                  ),
                ),
              ],
            ),
            WmlTable(
              grid: <double>[160, 160],
              rows: <WmlTableRow>[
                WmlTableRow(
                  cells: <WmlTableCell>[
                    WmlTableCell(
                      fillColor: '2B579A',
                      blocks: <WmlBlock>[
                        WmlParagraph(
                          inlines: <WmlInline>[WmlRun(text: 'Alpha')],
                        ),
                      ],
                    ),
                    WmlTableCell(
                      blocks: <WmlBlock>[
                        WmlParagraph(
                          inlines: <WmlInline>[WmlRun(text: 'Beta')],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            WmlVisual(
              visual: OfficeVisual(
                kind: OfficeVisualKind.picture,
                imageBytes: PngBytes.studioCard(width: 48, height: 28),
                width: 160,
                height: 80,
              ),
            ),
            WmlParagraph(
              properties: WmlParagraphProps(pageBreakBefore: true),
              inlines: <WmlInline>[WmlRun(text: 'Second page')],
            ),
          ],
        ),
      ],
    );

    final Uint8List pdf = OfficePdfExport.word(
      doc,
      font: font,
      title: 'Word PDF',
    );
    expect(_header(pdf), '%PDF-1.7');
    expect(_pageCount(pdf), 2);
    expect(_ascii(pdf).contains('/Im1'), isTrue);
    expect(_inflated(pdf).join(), contains('re'));
  });

  test('Excel PDF evaluates formulas and paginates every sheet', () {
    final SmlWorkbook book = SmlWorkbook(
      sheets: <SmlWorksheet>[
        SmlWorksheet(name: 'Data', sheetId: 1),
        SmlWorksheet(name: 'Calc', sheetId: 2),
      ],
      styles: SmlStyleSheet(cellXfsNumFmt: <int>[0, 2]),
    );
    book.sheets[0].cellA1('A1').value = 10;
    book.sheets[0].cellA1('A2').value = 20;
    book.sheets[0].cellA1('A3').value = 30;
    book.sheets[1].cellA1('A1').formula = '=SUM(Data!A1:A3)';
    book.sheets[1].cellA1('B1').value = 12.3;
    book.sheets[1].cellA1('B1').styleIndex = 1;
    book.sheets[1].drawings.add(
      SmlDrawing(
        visual: OfficeVisual(
          kind: OfficeVisualKind.chartColumn,
          title: 'Mix',
          points: OfficeVisual.sampleSeries(),
        ),
        col: 3,
        row: 1,
      ),
    );

    expect(
      FormulaEvaluator.evaluateCell(
        book,
        book.sheets[1],
        book.sheets[1].cellA1('A1'),
      ),
      60,
    );
    expect(book.styles!.format(12.3, 1), '12.30');

    final Uint8List pdf = OfficePdfExport.workbook(
      book,
      font: font,
      title: 'Sheet PDF',
    );
    expect(_header(pdf), '%PDF-1.7');
    expect(_pageCount(pdf), 2);
    if (font == null) {
      final String body = _inflated(pdf).join();
      expect(body, contains('Data'));
      expect(body, contains('60'));
      expect(body, contains('12.30'));
    } else {
      expect(_ascii(pdf), contains('/CIDFont'));
    }

    final Uint8List landscape = OfficePdfExport.workbook(
      book,
      options: PdfSheetPrintOptions.a4Landscape(),
    );
    expect(_ascii(landscape), contains('/MediaBox [0 0 841.890 595.280]'));
  });

  test('PowerPoint PDF emits one page per slide including rotation', () {
    final PmlPresentation deck = PmlPresentation(
      slides: <PmlSlide>[
        PmlSlide(
          id: 256,
          shapes: <PmlShape>[
            PmlShape(
              id: 2,
              name: 'Title',
              text: 'مرحبا Office',
              fillColor: '2B579A',
              transform: const PmlTransform(
                x: 200000,
                y: 200000,
                cx: 4000000,
                cy: 800000,
                rot: 30 * 60000,
              ),
            ),
            PmlShape(
              id: 3,
              name: 'Chart',
              visual: OfficeVisual(
                kind: OfficeVisualKind.chartPie,
                title: 'Share',
                points: OfficeVisual.sampleSeries(),
              ),
              transform: const PmlTransform(
                x: 800000,
                y: 1600000,
                cx: 5000000,
                cy: 2800000,
              ),
            ),
          ],
          notes: 'Speaker notes for slide one',
        ),
        PmlSlide(
          id: 257,
          shapes: <PmlShape>[
            PmlShape(
              id: 4,
              name: 'Oval',
              preset: PmlShapePreset.ellipse,
              text: 'Round',
              fillColor: '217346',
            ),
          ],
        ),
      ],
    );

    final Uint8List slides = OfficePdfExport.presentation(
      deck,
      font: font,
      title: 'Deck PDF',
    );
    expect(_header(slides), '%PDF-1.7');
    expect(_pageCount(slides), 2);
    final String slideStream = _inflated(slides).join();
    expect(slideStream, contains('cm'));
    expect(slideStream, contains('0 -1'));
    if (font != null) {
      for (final Match m in RegExp(
        r'\[<([0-9a-fA-F]+)>\] TJ',
      ).allMatches(slideStream)) {
        expect(
          int.parse(m.group(1)!, radix: 16),
          lessThan(512),
          reason: 'PDF must address the subset font, not source glyph ids',
        );
      }
    }

    final Uint8List notes = OfficePdfExport.presentation(
      deck,
      mode: PdfSlideExportMode.notesPages,
    );
    expect(_pageCount(notes), 2);
    expect(_ascii(notes), contains('595.28'));
    if (font == null) {
      expect(_inflated(notes).join(), contains('Speaker notes'));
    }
  });

  test('fromBytes dispatches Word, Excel, and PowerPoint packages', () {
    final Uint8List docx = WordSerializer().writeBytes(
      WmlDocument.empty(text: 'Export me'),
    );
    final SmlWorkbook book = SmlWorkbook();
    book.firstSheet.cellA1('A1').value = 7;
    final Uint8List xlsx = SheetSerializer().writeBytes(book);
    final Uint8List pptx = SlideSerializer().writeBytes(
      PmlPresentation(
        slides: <PmlSlide>[
          PmlSlide(
            id: 256,
            shapes: <PmlShape>[PmlShape(id: 2, name: 'T', text: 'Deck')],
          ),
        ],
      ),
    );

    expect(_header(OfficePdfExport.fromBytes(docx)), '%PDF-1.7');
    expect(_header(OfficePdfExport.fromBytes(xlsx)), '%PDF-1.7');
    expect(_header(PdfDocument.fromPptx(pptx)), '%PDF-1.7');
    expect(_pageCount(PdfDocument.fromWorkbook(book)), 1);
  });

  test('keeps a distinct image XObject for each picture', () {
    final Uint8List red = PngBytes.rgb(
      width: 24,
      height: 16,
      plot: (int x, int y, List<int> rgb) {
        rgb[0] = 200;
        rgb[1] = 10;
        rgb[2] = 10;
      },
    );
    final Uint8List blue = PngBytes.rgb(
      width: 32,
      height: 20,
      plot: (int x, int y, List<int> rgb) {
        rgb[0] = 10;
        rgb[1] = 20;
        rgb[2] = 210;
      },
    );
    final WmlDocument doc = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            WmlVisual(
              visual: OfficeVisual(
                kind: OfficeVisualKind.picture,
                imageBytes: red,
                width: 120,
                height: 80,
              ),
            ),
            WmlParagraph(
              properties: WmlParagraphProps(pageBreakBefore: true),
              inlines: <WmlInline>[WmlRun(text: 'Next')],
            ),
            WmlVisual(
              visual: OfficeVisual(
                kind: OfficeVisualKind.picture,
                imageBytes: blue,
                width: 140,
                height: 90,
              ),
            ),
          ],
        ),
      ],
    );
    final Uint8List pdf = OfficePdfExport.word(doc, font: font, title: 'Pics');
    final String ascii = _ascii(pdf);
    expect(ascii, contains('/Im1'));
    expect(ascii, contains('/Im2'));
    expect(ascii, contains('/Width 24'));
    expect(ascii, contains('/Width 32'));
    final String body = _inflated(pdf).join();
    expect(body, contains('/Im1 Do'));
    expect(body, contains('/Im2 Do'));
  });

  test('Excel PDF uses Helvetica for Latin when the CID face lacks it', () {
    final SfntFont? noto = _tryNoto();
    if (noto == null) {
      return;
    }
    final SmlWorkbook book = SmlWorkbook();
    book.firstSheet.cellA1('A1').value = 'عنوان';
    book.firstSheet.cellA1('B1').value = 4200;
    final Uint8List pdf = OfficePdfExport.workbook(
      book,
      font: noto,
      title: 'Mixed',
    );
    expect(_ascii(pdf), contains('/Length1'));
    final String body = _inflated(pdf).join();
    expect(body, contains('(A)'));
    expect(body, contains('(B)'));
    expect(RegExp(r'\[<[0-9a-fA-F]+>\] TJ').hasMatch(body), isTrue);
    expect(body.contains('[<0000>] TJ'), isFalse);
  });

  test('Word PDF writes TOC and web link annotations', () {
    final WmlDocument doc = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            WmlToc(title: 'Contents', minLevel: 1, maxLevel: 2),
            WmlParagraph(
              inlines: <WmlInline>[
                WordLink.linkedRun(
                  'Site',
                  const WmlHyperlink(url: 'https://example.com/docs'),
                ),
              ],
            ),
            WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Intro heading')])
              ..properties.headingLevel = 1
              ..properties.styleId = 'Heading1'
              ..properties.bookmarkName = '_Heading1_Intro',
            WmlParagraph(
              properties: WmlParagraphProps(pageBreakBefore: true),
              inlines: <WmlInline>[WmlRun(text: 'After the break')],
            ),
            WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Second heading')])
              ..properties.headingLevel = 2
              ..properties.styleId = 'Heading2'
              ..properties.bookmarkName = '_Heading2_Second',
          ],
        ),
      ],
    );
    WordToc.applyHeading(doc.paragraphs.elementAt(2), 1);
    WordToc.applyHeading(doc.paragraphs.elementAt(4), 2);
    WordToc.refreshAll(doc);
    final Uint8List pdf = OfficePdfExport.word(doc, font: font, title: 'Links');
    final String ascii = _ascii(pdf);
    expect(ascii, contains('/Annot'));
    expect(ascii, contains('/GoTo'));
    expect(ascii, contains('/URI'));
    expect(ascii, contains('https://example.com/docs'));
    expect(ascii, contains('/Link'));
  });
}

SfntFont? _tryFont() =>
    _tryPath('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');

SfntFont? _tryNoto() =>
    _tryPath('/usr/share/fonts/truetype/noto/NotoNaskhArabic-Regular.ttf');

SfntFont? _tryPath(String path) {
  if (!File(path).existsSync()) {
    return null;
  }
  return SfntFont.parse(File(path).readAsBytesSync());
}

String _header(Uint8List pdf) => String.fromCharCodes(pdf.take(8));

String _ascii(Uint8List pdf) => String.fromCharCodes(pdf);

int _pageCount(Uint8List pdf) {
  final Match? match = RegExp(r'/Count (\d+)').firstMatch(_ascii(pdf));
  expect(match, isNotNull);
  return int.parse(match!.group(1)!);
}

List<String> _inflated(Uint8List pdf) {
  final List<String> out = <String>[];
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
        out.add(String.fromCharCodes(PdfFlate.decompress(payload)));
      } catch (_) {}
    }
    i = end + 9;
  }
  return out;
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
