import 'dart:typed_data';

import 'package:quds_office_engine/pdf_widgets.dart' as pw;

import 'studio_pdf_faces.dart';

/// English harbour close: gradient hero, charts, and a ledger that spans pages.
Uint8List studioHarbourClosePdf() {
  final pw.Document doc = pw.Document(
    title: 'Harbour close — west quay',
    author: 'Quds Studio',
    font: StudioPdfFaces.tajawal(),
    fontBold: StudioPdfFaces.tajawalBold(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 40),
      footer: (pw.Context context) => const pw.Footer(
        leading: pw.Text(
          'WEST QUAY  ·  CLOSE OF WATCH',
          style: pw.TextStyle(fontSize: 8, color: '64748B'),
        ),
      ),
      build: (pw.Context context) => <pw.Widget>[
        _hero(
          kicker: 'QUDS  ·  NIGHT LEDGER  ·  13 SEP 2026',
          title: 'Harbour close',
          line: 'West quay finished the watch with two berths still open.',
          colors: const <String>['0B1F3A', '0E7490'],
        ),
        pw.SizedBox(height: 12),
        _kpiRow(
          items: const <(String, String, String)>[
            ('18', 'Movements', 'logged this watch'),
            ('2', 'Berths', 'still open'),
            ('94%', 'Cranes', 'available'),
            ('6', 'Holds', 'awaiting tally'),
          ],
          wash: 'E0F2FE',
          ink: '0C4A6E',
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'The night board',
          style: const pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: '0B1F3A',
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Values sit on the marks. The ledger below is one table: when the '
          'page fills, the header repeats on the next sheet instead of clipping.',
          style: const pw.TextStyle(fontSize: 10, color: '334155', height: 1.4),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Chart(
              type: pw.ChartType.bar,
              title: 'Berth hours',
              width: 250,
              height: 150,
              points: const <pw.ChartPoint>[
                pw.ChartPoint(label: 'A1', value: 11, color: '0E7490'),
                pw.ChartPoint(label: 'A2', value: 8, color: '0891B2'),
                pw.ChartPoint(label: 'B1', value: 14, color: '155E75'),
                pw.ChartPoint(label: 'C3', value: 5, color: '67E8F9'),
              ],
            ),
            pw.SizedBox(width: 10),
            pw.Chart(
              type: pw.ChartType.pie,
              title: 'Hold status',
              width: 250,
              height: 150,
              points: const <pw.ChartPoint>[
                pw.ChartPoint(label: 'Tallied', value: 22, color: '0E7490'),
                pw.ChartPoint(label: 'Open', value: 6, color: 'F59E0B'),
                pw.ChartPoint(label: 'Hold', value: 3, color: '0B1F3A'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Chart(
          type: pw.ChartType.line,
          title: 'Tide window used',
          width: 520,
          height: 128,
          points: const <pw.ChartPoint>[
            pw.ChartPoint(label: '18h', value: 12, color: '0E7490'),
            pw.ChartPoint(label: '20h', value: 19, color: '0E7490'),
            pw.ChartPoint(label: '22h', value: 16, color: '0E7490'),
            pw.ChartPoint(label: '00h', value: 23, color: '0E7490'),
            pw.ChartPoint(label: '02h', value: 14, color: '0E7490'),
            pw.ChartPoint(label: '04h', value: 9, color: '0E7490'),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Movement ledger',
          style: const pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: '0B1F3A',
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Table.fromTextArray(
          headers: const <String>['Ref', 'Berth', 'Cargo', 'Tonnes', 'Watch'],
          columnWidths: const <double>[0.8, 0.7, 2.2, 0.9, 1.1],
          cellHeight: 20,
          headerDecoration: '0B1F3A',
          oddRowDecoration: 'F0F9FF',
          cellStyle: const pw.TextStyle(fontSize: 8, color: '1E293B'),
          headerStyle: const pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: 'FFFFFF',
          ),
          data: <List<String>>[
            for (int i = 1; i <= 18; i++)
              <String>[
                'HQ-${i.toString().padLeft(2, '0')}',
                i.isEven ? 'B1' : 'A2',
                i.isEven ? 'Bagged grain' : 'Timber packs',
                '${40 + i * 3}',
                i < 10 ? 'Evening' : 'Night',
              ],
          ],
        ),
        pw.SizedBox(height: 10),
        const pw.Bullet(text: 'A2 stays open until the 06:40 pilot.'),
        const pw.Bullet(text: 'C3 crane three is down; do not assign a new lift.'),
        pw.UrlLink(
          destination: 'https://quds.office/samples/harbour',
          child: pw.Text(
            'Watch notes  ·  quds.office/samples/harbour',
            style: const pw.TextStyle(
              fontSize: 9,
              color: '0E7490',
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

/// Arabic night ledger in Tajawal: gradient, charts, and a spanning table.
Uint8List studioLaylAlQamarPdf() {
  final pw.Document doc = pw.Document(
    title: 'ليل القمر — دفتر الحي',
    author: 'Quds Studio',
    font: StudioPdfFaces.tajawal(),
    fontBold: StudioPdfFaces.tajawalBold(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 40),
      textDirection: pw.TextDirection.rtl,
      footer: (pw.Context context) => const pw.Footer(
        leading: pw.Text(
          'حي القمر  ·  إغلاق الوردية',
          style: pw.TextStyle(fontSize: 8, color: '64748B'),
        ),
      ),
      build: (pw.Context context) => <pw.Widget>[
        _hero(
          kicker: 'قدس  ·  دفتر ليلي  ·  13 أيلول 2026',
          title: 'ليل القمر',
          line: 'أُغلق الحي على ست زيارات معلّقة ومخزن ماء ما زال مفتوحاً.',
          colors: const <String>['3B0764', 'BE185D'],
          rtl: true,
        ),
        pw.SizedBox(height: 12),
        _kpiRow(
          items: const <(String, String, String)>[
            ('41', 'زيارة', 'في هذه الوردية'),
            ('6', 'ملفات', 'بانتظار الإغلاق'),
            ('88%', 'ماء', 'الوصول الليلي'),
            ('3', 'فرق', 'ما زالت في الشارع'),
          ],
          wash: 'FDF2F8',
          ink: '831843',
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'لوحة الوردية',
          textAlign: pw.TextAlign.start,
          style: const pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: '3B0764',
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'الرسم يحمل القيم على الأعمدة، والدفتر جدول واحد. عندما تمتلئ '
          'الصفحة يُعاد صف العناوين في الصفحة التالية ولا يُقص الصف.',
          textAlign: pw.TextAlign.start,
          style: const pw.TextStyle(fontSize: 11, color: '3F3F46', height: 1.45),
        ),
        pw.SizedBox(height: 10),
        pw.Chart(
          type: pw.ChartType.bar,
          title: 'زيارات الأحياء',
          width: 520,
          height: 150,
          points: const <pw.ChartPoint>[
            pw.ChartPoint(label: 'القمر', value: 16, color: '9D174D'),
            pw.ChartPoint(label: 'الرمل', value: 11, color: 'BE185D'),
            pw.ChartPoint(label: 'النور', value: 9, color: 'DB2777'),
            pw.ChartPoint(label: 'البحر', value: 5, color: 'F9A8D4'),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Chart(
              type: pw.ChartType.line,
              title: 'ساعات الفرق',
              width: 250,
              height: 132,
              points: const <pw.ChartPoint>[
                pw.ChartPoint(label: '20', value: 3, color: '9D174D'),
                pw.ChartPoint(label: '22', value: 5, color: '9D174D'),
                pw.ChartPoint(label: '00', value: 4, color: '9D174D'),
                pw.ChartPoint(label: '02', value: 6, color: '9D174D'),
                pw.ChartPoint(label: '04', value: 2, color: '9D174D'),
              ],
            ),
            pw.SizedBox(width: 10),
            pw.Chart(
              type: pw.ChartType.pie,
              title: 'نوع الزيارة',
              width: 250,
              height: 132,
              points: const <pw.ChartPoint>[
                pw.ChartPoint(label: 'ماء', value: 18, color: '9D174D'),
                pw.ChartPoint(label: 'مأوى', value: 12, color: 'DB2777'),
                pw.ChartPoint(label: 'طب', value: 11, color: '3B0764'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'دفتر الزيارات',
          textAlign: pw.TextAlign.start,
          style: const pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: '3B0764',
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Table.fromTextArray(
          headers: const <String>['الرمز', 'الحي', 'الطلب', 'الحالة'],
          columnWidths: const <double>[0.8, 1.2, 2.2, 1.2],
          cellHeight: 22,
          headerDecoration: '3B0764',
          oddRowDecoration: 'FDF2F8',
          cellAlignment: pw.Alignment.centerRight,
          headerAlignment: pw.Alignment.centerRight,
          cellStyle: const pw.TextStyle(fontSize: 9, color: '3F3F46'),
          headerStyle: const pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: 'FFFFFF',
          ),
          data: <List<String>>[
            for (int i = 1; i <= 16; i++)
              <String>[
                'ق-${i.toString().padLeft(2, '0')}',
                const <String>['القمر', 'الرمل', 'النور', 'البحر'][i % 4],
                i.isEven ? 'تعبئة خزان' : 'كشف مأوى',
                i < 8 ? 'أُغلق' : 'معلّق',
              ],
          ],
        ),
        pw.SizedBox(height: 10),
        const pw.Bullet(text: 'مخزن الماء في القمر يبقى مفتوحاً حتى السادسة.'),
        const pw.Bullet(text: 'لا تُغلق ملفات النور قبل توقيع الفريق الثالث.'),
      ],
    ),
  );
  return doc.save();
}

/// One landscape sheet: English shore beside an Arabic shore.
Uint8List studioTwoShoresPdf() {
  final pw.Document doc = pw.Document(
    title: 'Two shores',
    author: 'Quds Studio',
    font: StudioPdfFaces.tajawal(),
    fontBold: StudioPdfFaces.tajawalBold(),
  );
  doc.addPage(
    pw.Page(
      pageFormat: pw.PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          _hero(
            kicker: 'ONE WATCH  ·  TWO SHORES',
            title: 'Two shores',
            line: 'The same night, written once in each direction.',
            colors: const <String>['134E4A', 'CA8A04'],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Expanded(child: _englishShore()),
              pw.SizedBox(width: 14),
              pw.Expanded(child: _arabicShore()),
            ],
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// Cairo Arabic clinic poster with a gradient wash and a short English close.
Uint8List studioCairoNightPdf() {
  final pw.Document doc = pw.Document(
    title: 'ليل القاهرة — إغلاق العيادة',
    author: 'Quds Studio',
    font: StudioPdfFaces.cairo(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 40),
      textDirection: pw.TextDirection.rtl,
      footer: (pw.Context context) => const pw.Footer(
        leading: pw.Text(
          'عيادة القاهرة  ·  خط Cairo',
          style: pw.TextStyle(fontSize: 8, color: '78716C'),
        ),
      ),
      build: (pw.Context context) => <pw.Widget>[
        _hero(
          kicker: 'CAIRO  ·  إغلاق ليلي',
          title: 'عيادة القاهرة',
          line: 'ثلاث ورديات، مخزن واحد، وصفحة إنجليزية في آخر الدفتر.',
          colors: const <String>['14532D', '65A30D'],
          rtl: true,
          bold: false,
        ),
        pw.SizedBox(height: 12),
        _kpiRow(
          items: const <(String, String, String)>[
            ('64', 'مراجع', 'حتى منتصف الليل'),
            ('9', 'تحويل', 'إلى المستشفى'),
            ('100%', 'لقاح', 'البرد الليلي'),
          ],
          wash: 'F0FDF4',
          ink: '14532D',
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'ما تغيّر بعد المغرب',
          textAlign: pw.TextAlign.start,
          style: const pw.TextStyle(fontSize: 15, color: '14532D'),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'الخط هنا Cairo لا تجوال. العنوان كبير بلا تظليل وهمي لأن الوجه '
          'بلا ملف عريض منفصل. الجدول يمتد إذا طال، والتدرج شرائط لا ظل محوري.',
          textAlign: pw.TextAlign.start,
          style: const pw.TextStyle(fontSize: 11, color: '3F3F46', height: 1.5),
        ),
        pw.SizedBox(height: 10),
        pw.Chart(
          title: 'أسباب الزيارة',
          width: 520,
          height: 146,
          points: const <pw.ChartPoint>[
            pw.ChartPoint(label: 'حرارة', value: 22, color: '166534'),
            pw.ChartPoint(label: 'جرح', value: 14, color: '4D7C0F'),
            pw.ChartPoint(label: 'سعال', value: 18, color: '65A30D'),
            pw.ChartPoint(label: 'أخرى', value: 10, color: 'BBF7D0'),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(
          headers: const <String>['الساعة', 'العيادة', 'ما تم'],
          columnWidths: const <double>[1, 1.4, 2.4],
          cellHeight: 22,
          headerDecoration: '14532D',
          oddRowDecoration: 'F0FDF4',
          cellAlignment: pw.Alignment.centerRight,
          headerAlignment: pw.Alignment.centerRight,
          cellStyle: const pw.TextStyle(fontSize: 10, color: '1C1917'),
          headerStyle: const pw.TextStyle(fontSize: 10, color: 'FFFFFF'),
          data: const <List<String>>[
            <String>['20:10', 'أطفال', 'جرعة برد للدفعة الأخيرة'],
            <String>['21:40', 'جراحة', 'خياطة بسيطة بلا تحويل'],
            <String>['23:05', 'نسائية', 'استشارة ثم عودة للمنزل'],
            <String>['00:30', 'صيدلية', 'إغلاق الجرد الليلي'],
            <String>['02:15', 'استقبال', 'تحويلان إلى المستشفى المرجعي'],
          ],
        ),
        pw.NewPage(),
        pw.Directionality(
          textDirection: pw.TextDirection.ltr,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _hero(
                kicker: 'ENGLISH CLOSE  ·  SAME NIGHT',
                title: 'Hand-off note',
                line: 'Cairo embeds this page too. The Arabic pages stay RTL.',
                colors: const <String>['14532D', '0F766E'],
                bold: false,
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Morning team: nine referrals are already logged. Do not reopen '
                'the cold-vaccine count. The pharmacy tally closed at 00:30.',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: '1C1917',
                  height: 1.45,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Chart(
                type: pw.ChartType.line,
                title: 'Referrals by hour',
                width: 360,
                height: 130,
                points: const <pw.ChartPoint>[
                  pw.ChartPoint(label: '20', value: 1, color: '166534'),
                  pw.ChartPoint(label: '22', value: 2, color: '166534'),
                  pw.ChartPoint(label: '00', value: 3, color: '166534'),
                  pw.ChartPoint(label: '02', value: 3, color: '166534'),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _englishShore() {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: const pw.BoxDecoration(color: '134E4A'),
        child: pw.Text(
          'WEST  ·  ENGLISH',
          style: const pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: 'FFFFFF',
          ),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'Quay lights stayed on.',
        style: const pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: '134E4A',
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        'Grain finished first. Timber waits for the dawn crane.',
        style: const pw.TextStyle(fontSize: 9, color: '3F3F46', height: 1.35),
      ),
      pw.SizedBox(height: 8),
      pw.Chart(
        title: 'West tonnes',
        width: 340,
        height: 120,
        showLegend: false,
        points: const <pw.ChartPoint>[
          pw.ChartPoint(label: 'Grain', value: 80, color: '0F766E'),
          pw.ChartPoint(label: 'Timber', value: 36, color: 'CA8A04'),
          pw.ChartPoint(label: 'Fuel', value: 22, color: '134E4A'),
        ],
      ),
    ],
  );
}

pw.Widget _arabicShore() {
  return pw.Directionality(
    textDirection: pw.TextDirection.rtl,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const pw.BoxDecoration(color: '9A3412'),
          child: pw.Text(
            'الشرق  ·  عربي',
            style: const pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: 'FFFFFF',
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'أضواء الرصيف لم تُطفأ.',
          textAlign: pw.TextAlign.start,
          style: const pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: '9A3412',
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'أُنهي القمح أولاً. الخشب ينتظر رافعة الفجر.',
          textAlign: pw.TextAlign.start,
          style: const pw.TextStyle(fontSize: 9, color: '3F3F46', height: 1.35),
        ),
        pw.SizedBox(height: 8),
        pw.Chart(
          title: 'أطنان الشرق',
          width: 340,
          height: 120,
          showLegend: false,
          points: const <pw.ChartPoint>[
            pw.ChartPoint(label: 'قمح', value: 64, color: 'C2410C'),
            pw.ChartPoint(label: 'خشب', value: 28, color: 'CA8A04'),
            pw.ChartPoint(label: 'وقود', value: 19, color: '9A3412'),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _hero({
  required String kicker,
  required String title,
  required String line,
  required List<String> colors,
  bool rtl = false,
  bool bold = true,
}) {
  return pw.Container(
    height: 86,
    padding: const pw.EdgeInsets.fromLTRB(16, 12, 16, 10),
    alignment: rtl ? pw.Alignment.topRight : pw.Alignment.topLeft,
    decoration: pw.BoxDecoration(
      gradient: pw.LinearGradient(colors: colors, vertical: false),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          kicker,
          textAlign: pw.TextAlign.start,
          style: const pw.TextStyle(fontSize: 8, color: 'E2E8F0'),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          title,
          textAlign: pw.TextAlign.start,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: 'FFFFFF',
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          line,
          textAlign: pw.TextAlign.start,
          style: const pw.TextStyle(fontSize: 9, color: 'F8FAFC', height: 1.3),
        ),
      ],
    ),
  );
}

pw.Widget _kpiRow({
  required List<(String, String, String)> items,
  required String wash,
  required String ink,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      for (int i = 0; i < items.length; i++) ...<pw.Widget>[
        if (i > 0) pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: pw.BoxDecoration(color: wash),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  items[i].$1,
                  textAlign: pw.TextAlign.start,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: ink,
                  ),
                ),
                pw.Text(
                  items[i].$2,
                  textAlign: pw.TextAlign.start,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: ink,
                  ),
                ),
                pw.Text(
                  items[i].$3,
                  textAlign: pw.TextAlign.start,
                  style: const pw.TextStyle(fontSize: 7, color: '57534E'),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}
