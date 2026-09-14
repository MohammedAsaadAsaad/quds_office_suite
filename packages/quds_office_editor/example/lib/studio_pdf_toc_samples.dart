import 'dart:typed_data';

import 'package:quds_office_engine/pdf_widgets.dart' as pw;

import 'studio_pdf_faces.dart';

/// English TOC whose entries jump to later pages.
Uint8List studioContentsGuidePdf() {
  final pw.Document doc = pw.Document(
    title: 'Contents guide',
    author: 'Quds Studio',
    font: StudioPdfFaces.tajawal(),
    fontBold: StudioPdfFaces.tajawalBold(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
      footer: (pw.Context context) => pw.Footer(
        leading: const pw.Text(
          'QUDS OFFICE  ·  CONTENTS',
          style: pw.TextStyle(fontSize: 8, color: '78716C'),
        ),
        trailing: pw.Text(
          '${context.pageNumber}',
          style: const pw.TextStyle(fontSize: 8, color: '78716C'),
        ),
      ),
      build: (pw.Context context) => <pw.Widget>[
        _kicker('INTERNAL LINKS', '1D4ED8', 'DBEAFE'),
        pw.SizedBox(height: 12),
        pw.Text(
          'Field guide',
          style: const pw.TextStyle(
            fontSize: 26,
            fontWeight: pw.FontWeight.bold,
            color: '1E3A8A',
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Paragraph(
          text:
              'Hover a contents row. The card shows the page the link opens, cropped to the heading.',
          style: const pw.TextStyle(fontSize: 11, color: '334155', lineSpacing: 3),
        ),
        pw.SizedBox(height: 8),
        const pw.TableOfContent(title: 'Contents'),
        const pw.NewPage(),
        _section(
          kicker: '01',
          title: 'Water points',
          band: '0F766E',
          wash: 'CCFBF1',
          body:
              'Three standpipes on the east lane are open from dawn. The south point is closed for a valve change until Thursday.',
          see: 'Clinic hours',
          seeLabel: 'See clinic hours',
        ),
        const pw.NewPage(),
        _section(
          kicker: '02',
          title: 'Clinic hours',
          band: '9A3412',
          wash: 'FFEDD5',
          body:
              'The tent clinic sees walk-ins until 16:00. Referrals for chronic care leave with the afternoon convoy.',
          see: 'Closeout',
          seeLabel: 'See closeout',
        ),
        const pw.NewPage(),
        _section(
          kicker: '03',
          title: 'Closeout',
          band: '6D28D9',
          wash: 'EDE9FE',
          body:
              'Sign the sheet, return radios, and note any gate that stayed shut. The next brief starts from this page.',
        ),
      ],
    ),
  );
  return doc.save();
}

/// Arabic TOC with internal destinations.
Uint8List studioArabicContentsPdf() {
  final pw.Document doc = pw.Document(
    title: 'فهرس المحتويات',
    author: 'Quds Studio',
    font: StudioPdfFaces.cairo(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
      textDirection: pw.TextDirection.rtl,
      footer: (pw.Context context) => pw.Footer(
        leading: const pw.Text(
          'مكتب القدس  ·  فهرس',
          style: pw.TextStyle(fontSize: 8, color: '78716C'),
        ),
        trailing: pw.Text(
          '${context.pageNumber}',
          style: const pw.TextStyle(fontSize: 8, color: '78716C'),
        ),
      ),
      build: (pw.Context context) => <pw.Widget>[
        _kicker('روابط داخل الملف', '9F1239', 'FFE4E6'),
        pw.SizedBox(height: 12),
        pw.Text(
          'دليل الميدان',
          textAlign: pw.TextAlign.right,
          style: const pw.TextStyle(
            fontSize: 26,
            fontWeight: pw.FontWeight.bold,
            color: '881337',
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Paragraph(
          text:
              'مرّر المؤشر فوق بند في الفهرس لترى الصفحة التي يفتحها الرابط، عند العنوان نفسه.',
          textAlign: pw.TextAlign.right,
          style: const pw.TextStyle(fontSize: 11, color: '334155', lineSpacing: 3),
        ),
        pw.SizedBox(height: 8),
        const pw.TableOfContent(title: 'المحتويات'),
        const pw.NewPage(),
        _section(
          kicker: '٠١',
          title: 'نقاط المياه',
          band: '0F766E',
          wash: 'CCFBF1',
          body:
              'ثلاث حنفيات في الحارة الشرقية تعمل من الفجر. النقطة الجنوبية مغلقة لتبديل صمام حتى الخميس.',
          rtl: true,
          see: 'ساعات العيادة',
          seeLabel: 'إلى ساعات العيادة',
        ),
        const pw.NewPage(),
        _section(
          kicker: '٠٢',
          title: 'ساعات العيادة',
          band: '9A3412',
          wash: 'FFEDD5',
          body:
              'خيمة العيادة تستقبل المراجعين حتى الرابعة. إحالات الأمراض المزمنة تخرج مع قافلة العصر.',
          rtl: true,
        ),
        const pw.NewPage(),
        _section(
          kicker: '٠٣',
          title: 'الإغلاق',
          band: '6D28D9',
          wash: 'EDE9FE',
          body:
              'وقّع الكشف، أعد أجهزة اللاسلكي، وسجّل أي بوابة بقيت مغلقة. الإحاطة التالية تبدأ من هذه الصفحة.',
          rtl: true,
        ),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _kicker(String label, String ink, String wash) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: pw.BoxDecoration(
      color: wash,
      borderRadius: 4,
    ),
    child: pw.Text(
      label,
      style: pw.TextStyle(fontSize: 9, color: ink, letterSpacing: 0.6),
    ),
  );
}

pw.Widget _section({
  required String kicker,
  required String title,
  required String band,
  required String wash,
  required String body,
  bool rtl = false,
  String? see,
  String? seeLabel,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: <pw.Widget>[
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: pw.BoxDecoration(
          color: wash,
          borderRadius: 6,
          border: pw.Border.all(color: band, width: 1.2),
        ),
        child: pw.Column(
          crossAxisAlignment: rtl
              ? pw.CrossAxisAlignment.end
              : pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              kicker,
              textAlign: rtl ? pw.TextAlign.right : pw.TextAlign.left,
              style: pw.TextStyle(
                fontSize: 10,
                color: band,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Header(
              level: 1,
              text: title,
              textStyle: pw.TextStyle(
                fontSize: 22,
                color: band,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 12),
      pw.Paragraph(
        text: body,
        textAlign: rtl ? pw.TextAlign.right : pw.TextAlign.left,
        style: const pw.TextStyle(fontSize: 12, color: '1E293B', lineSpacing: 4),
      ),
      if (see != null && seeLabel != null) ...<pw.Widget>[
        pw.SizedBox(height: 10),
        pw.Link(
          destination: see,
          child: pw.Text(
            seeLabel,
            textAlign: rtl ? pw.TextAlign.right : pw.TextAlign.left,
            style: const pw.TextStyle(
              fontSize: 11,
              color: '1565C0',
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
      ],
    ],
  );
}
