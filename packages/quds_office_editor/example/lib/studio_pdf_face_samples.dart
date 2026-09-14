import 'dart:typed_data';

import 'package:quds_office_engine/pdf_widgets.dart' as pw;

import 'studio_pdf_faces.dart';

/// Arabic phrase the gallery samples must contain.
const String studioQuarterlyPhrase = 'تقرير ربع سنوي';

const String _arabicBody =
    'يلخص هذا التقرير تقدم برامج التعافي في حي التحرير خلال '
    'الربع الثالث من عام 2026. ارتفع الوصول إلى المياه إلى 73 بالمئة، '
    'واستقرت الملاجئ المتضررة جزئيا، بينما بقيت ملفات مفتوحة بانتظار '
    'التحقق الميداني في منتصف أيلول.';

const String _englishBody =
    'This quarterly note follows the same Al Tahreer programme in English. '
    'Water access reached 73 percent, partially damaged shelters were '
    'stabilized, and a small set of cases remains open for field verification '
    'in mid-September.';

/// Cairo card: Arabic title and body, English panel on the next page.
Uint8List studioCairoQuarterlyPdf() {
  final pw.Document doc = pw.Document(
    title: '$studioQuarterlyPhrase — Cairo',
    author: 'Quds Studio',
    font: StudioPdfFaces.cairo(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      textDirection: pw.TextDirection.rtl,
      build: (pw.Context context) => <pw.Widget>[
          _band(
            kicker: 'QUDS OFFICE  ·  CAIRO',
            face: 'Cairo',
            color: '0F6E56',
            ink: 'D1FAE5',
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            studioQuarterlyPhrase,
            textAlign: pw.TextAlign.start,
            style: const pw.TextStyle(
              fontSize: 28,
              color: '0F6E56',
              height: 1.25,
            ),
          ),
          pw.Header(
            level: 1,
            text: 'ملخص الربع الثالث',
            textStyle: const pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.normal,
              color: '134E4A',
            ),
          ),
          pw.Text(
            _arabicBody,
            textAlign: pw.TextAlign.start,
            style: const pw.TextStyle(
              fontSize: 12,
              color: '292524',
              height: 1.55,
            ),
          ),
          pw.SizedBox(height: 16),
          _facts(
            accent: '0F6E56',
            wash: 'ECFDF5',
            items: const <(String, String)>[
              ('الوصول إلى المياه', '73%'),
              ('استقرار الملاجئ', '61%'),
              ('ملفات مفتوحة', '19'),
            ],
          ),
          pw.NewPage(),
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: _englishPanel(
              accent: '0F6E56',
              wash: 'F0FDFA',
              heading: 'Field note',
            ),
          ),
        ],
    ),
  );
  return doc.save();
}

/// Tajawal card: English title and body, Arabic panel on the next page.
Uint8List studioTajawalBriefingPdf() {
  final pw.Document doc = pw.Document(
    title: 'Quarterly briefing — $studioQuarterlyPhrase',
    author: 'Quds Studio',
    font: StudioPdfFaces.tajawal(),
    fontBold: StudioPdfFaces.tajawalBold(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      textDirection: pw.TextDirection.ltr,
      build: (pw.Context context) => <pw.Widget>[
          _band(
            kicker: 'QUDS OFFICE  ·  TAJAWAL',
            face: 'Tajawal',
            color: '9A3412',
            ink: 'FFEDD5',
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Quarterly briefing',
            style: const pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: '9A3412',
              height: 1.15,
            ),
          ),
          pw.Header(
            level: 1,
            text: 'Service access',
            textStyle: const pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: '7C2D12',
            ),
          ),
          pw.Text(
            _englishBody,
            style: const pw.TextStyle(
              fontSize: 12,
              color: '292524',
              height: 1.55,
            ),
          ),
          pw.SizedBox(height: 16),
          _facts(
            accent: '9A3412',
            wash: 'FFF7ED',
            items: const <(String, String)>[
              ('Water access', '73%'),
              ('Shelters stable', '61%'),
              ('Open cases', '19'),
            ],
          ),
          pw.NewPage(),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: pw.BoxDecoration(
                color: 'FFF7ED',
                borderRadius: 6,
                border: pw.Border.all(color: 'FDBA74', width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: <pw.Widget>[
                  pw.Text(
                    'ARABIC  ·  RTL',
                    textAlign: pw.TextAlign.start,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: 'C2410C',
                      letterSpacing: 1.1,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Header(
                    level: 2,
                    text: studioQuarterlyPhrase,
                    textStyle: const pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: '9A3412',
                    ),
                  ),
                  pw.Text(
                    _arabicBody,
                    textAlign: pw.TextAlign.start,
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: '44403C',
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
    ),
  );
  return doc.save();
}

pw.Widget _band({
  required String kicker,
  required String face,
  required String color,
  required String ink,
}) {
  return pw.Container(
    color: color,
    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: pw.Row(
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Text(
            kicker,
            style: pw.TextStyle(
              color: ink,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
        pw.Text(
          face,
          style: const pw.TextStyle(
            color: 'FFFFFF',
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _facts({
  required String accent,
  required String wash,
  required List<(String, String)> items,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      for (int i = 0; i < items.length; i++) ...<pw.Widget>[
        if (i > 0) pw.SizedBox(width: 8),
        pw.Expanded(child: _factTile(items[i].$1, items[i].$2, accent, wash)),
      ],
    ],
  );
}

pw.Widget _factTile(String label, String value, String accent, String wash) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(color: wash, borderRadius: 4),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: accent,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: '57534E'),
        ),
      ],
    ),
  );
}

pw.Widget _englishPanel({
  required String accent,
  required String wash,
  required String heading,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 16),
    decoration: pw.BoxDecoration(
      color: wash,
      borderRadius: 6,
      border: pw.Border.all(color: '99F6E4', width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        pw.Text(
          'ENGLISH  ·  LTR',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: accent,
            letterSpacing: 1.1,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          heading,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: accent,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          _englishBody,
          style: const pw.TextStyle(
            fontSize: 11,
            color: '44403C',
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
