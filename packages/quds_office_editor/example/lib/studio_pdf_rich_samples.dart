import 'dart:typed_data';

import 'package:quds_office_engine/pdf_widgets.dart' as pw;

import 'studio_pdf_faces.dart';

/// Widget atlas: charts, table, checklist, chips, and an Arabic page.
Uint8List studioWidgetAtlasPdf() {
  final pw.Document doc = pw.Document(
    title: 'pdf_widgets atlas',
    author: 'Quds Studio',
    font: StudioPdfFaces.tajawal(),
    fontBold: StudioPdfFaces.tajawalBold(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      footer: (pw.Context context) => const pw.Footer(
        leading: pw.Text(
          'QUDS OFFICE  ·  WIDGET ATLAS',
          style: pw.TextStyle(fontSize: 8, color: '78716C'),
        ),
      ),
      build: (pw.Context context) => <pw.Widget>[
        pw.Watermark.text('ATLAS'),
        _band(
          kicker: 'PDF WIDGETS  ·  SHOWCASE',
          face: 'Tajawal',
          color: '3730A3',
          ink: 'E0E7FF',
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Widget atlas',
          style: const pw.TextStyle(
            fontSize: 26,
            fontWeight: pw.FontWeight.bold,
            color: '312E81',
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'A multi-page layout that exercises the constraint widgets: '
          'charts, tables, grids, checklists, links, and an RTL page.',
          style: const pw.TextStyle(fontSize: 11, color: '44403C', height: 1.45),
        ),
        pw.SizedBox(height: 14),
        _kpiRow(
          accent: '3730A3',
          wash: 'EEF2FF',
          items: const <(String, String, String)>[
            ('12', 'Widgets', 'in this pack'),
            ('4', 'Pages', 'flowed, not clipped'),
            ('73%', 'Water', 'programme access'),
            ('19', 'Open', 'field cases'),
          ],
        ),
        pw.SizedBox(height: 16),
        _sectionLabel('Charts', '3730A3'),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Chart(
              type: pw.ChartType.bar,
              title: 'Service access',
              width: 250,
              height: 148,
              points: const <pw.ChartPoint>[
                pw.ChartPoint(label: 'Water', value: 73, color: '3730A3'),
                pw.ChartPoint(label: 'Shelter', value: 61, color: '6366F1'),
                pw.ChartPoint(label: 'Health', value: 54, color: 'A5B4FC'),
                pw.ChartPoint(label: 'Power', value: 42, color: 'C7D2FE'),
              ],
            ),
            pw.SizedBox(width: 12),
            pw.Chart(
              type: pw.ChartType.pie,
              title: 'Case mix',
              width: 250,
              height: 148,
              points: const <pw.ChartPoint>[
                pw.ChartPoint(label: 'Open', value: 19, color: '3730A3'),
                pw.ChartPoint(label: 'Review', value: 11, color: '6366F1'),
                pw.ChartPoint(label: 'Closed', value: 27, color: 'C7D2FE'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Chart(
          type: pw.ChartType.line,
          title: 'Weekly field visits',
          width: 520,
          height: 140,
          points: const <pw.ChartPoint>[
            pw.ChartPoint(label: 'W1', value: 18, color: '3730A3'),
            pw.ChartPoint(label: 'W2', value: 24, color: '3730A3'),
            pw.ChartPoint(label: 'W3', value: 21, color: '3730A3'),
            pw.ChartPoint(label: 'W4', value: 31, color: '3730A3'),
            pw.ChartPoint(label: 'W5', value: 28, color: '3730A3'),
          ],
        ),
        pw.SizedBox(height: 16),
        _sectionLabel('Checklist', '3730A3'),
        pw.SizedBox(height: 8),
        _check('Identity-H subset embeds Cairo and Tajawal', done: true),
        _check('MultiPage carries leftover widgets to the next sheet', done: true),
        _check('RTL lines start at the right edge', done: true),
        _check('Certified PDF/A — not claimed by this sample', done: false),
        pw.SizedBox(height: 14),
        _sectionLabel('Widget families', '3730A3'),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: const <String>['Family', 'Widgets', 'Used here'],
          columnWidths: const <double>[1.2, 2.4, 2.2],
          headerDecoration: '3730A3',
          oddRowDecoration: 'EEF2FF',
          cellStyle: const pw.TextStyle(fontSize: 9, color: '292524'),
          headerStyle: const pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: 'FFFFFF',
          ),
          data: const <List<String>>[
            <String>['Text', 'Text, Header, Bullet, Paragraph', 'titles and notes'],
            <String>['Layout', 'Row, Column, Grid, Wrap', 'KPI row and chips'],
            <String>['Data', 'Table, Chart', 'access and case mix'],
            <String>['Chrome', 'Footer, Watermark, UrlLink', 'every page'],
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <pw.Widget>[
            for (final String label in <String>[
              'MultiPage',
              'Table',
              'Chart',
              'GridView',
              'Checkbox',
              'Bullet',
              'UrlLink',
              'Watermark',
            ])
              _chip(label, 'EEF2FF', '3730A3'),
          ],
        ),
        pw.SizedBox(height: 12),
        const pw.Bullet(
          text: 'Charts are vector boxes, not images. Labels stay in the file font.',
        ),
        const pw.Bullet(
          text: 'A single Column that overflows a Page is clipped. These samples flow.',
        ),
        pw.UrlLink(
          destination: 'https://quds.office/samples/widgets',
          child: pw.Text(
            'Sample notes  ·  quds.office/samples/widgets',
            style: const pw.TextStyle(
              fontSize: 9,
              color: '4338CA',
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
        pw.NewPage(),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: _band(
            kicker: 'الصفحة العربية  ·  اتجاه من اليمين',
            face: 'تجوال',
            color: '3730A3',
            ink: 'E0E7FF',
          ),
        ),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Text(
            'أطلس الأدوات',
            textAlign: pw.TextAlign.start,
            style: const pw.TextStyle(
              fontSize: 26,
              fontWeight: pw.FontWeight.bold,
              color: '312E81',
            ),
          ),
        ),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Text(
            'هذه الصفحة تكمل الأطلس بالعربية. المؤشرات والجدول ينزلان '
            'من اليمين، والنص القصير لا يبقى على الحافة اليسرى.',
            textAlign: pw.TextAlign.start,
            style: const pw.TextStyle(fontSize: 12, color: '44403C', height: 1.5),
          ),
        ),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: _kpiRow(
            accent: '3730A3',
            wash: 'EEF2FF',
            items: const <(String, String, String)>[
              ('73%', 'مياه', 'الوصول في الحي'),
              ('61%', 'مأوى', 'استقرار جزئي'),
              ('19', 'ملفات', 'بانتظار التحقق'),
            ],
          ),
        ),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Table.fromTextArray(
            headers: const <String>['الحي', 'المياه', 'الحالة'],
            columnWidths: const <double>[2, 1, 1.4],
            headerDecoration: '3730A3',
            oddRowDecoration: 'EEF2FF',
            cellStyle: const pw.TextStyle(fontSize: 10, color: '292524'),
            headerStyle: const pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: 'FFFFFF',
            ),
            data: const <List<String>>[
              <String>['التحرير', '73%', 'متابعة'],
              <String>['الرمال', '61%', 'مستقر'],
              <String>['الشجاعية', '48%', 'أولوية'],
            ],
          ),
        ),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Text(
            'يبقى التحقق الميداني في منتصف أيلول قبل إغلاق الملفات المفتوحة.',
            textAlign: pw.TextAlign.start,
            style: const pw.TextStyle(fontSize: 11, color: '57534E', height: 1.45),
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

/// Arabic field-clinic day sheet in Cairo, with a short English close.
Uint8List studioFieldClinicPdf() {
  final pw.Document doc = pw.Document(
    title: 'كشف عيادة ميدانية — القاهرة',
    author: 'Quds Studio',
    font: StudioPdfFaces.cairo(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      textDirection: pw.TextDirection.rtl,
      footer: (pw.Context context) => const pw.Footer(
        leading: pw.Text(
          'عيادة التحرير  ·  13 أيلول 2026',
          style: pw.TextStyle(fontSize: 8, color: '78716C'),
        ),
      ),
      build: (pw.Context context) => <pw.Widget>[
        _band(
          kicker: 'قدس  ·  عيادة ميدانية',
          face: 'Cairo',
          color: '0F6E56',
          ink: 'D1FAE5',
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'كشف عيادة التحرير',
          textAlign: pw.TextAlign.start,
          style: const pw.TextStyle(fontSize: 26, color: '134E4A'),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'الأحد 13 أيلول 2026  ·  الفترة الصباحية  ·  ثلاثة أطباء وممرضتان',
          textAlign: pw.TextAlign.start,
          style: const pw.TextStyle(fontSize: 11, color: '57534E'),
        ),
        pw.SizedBox(height: 14),
        _kpiRow(
          accent: '0F6E56',
          wash: 'ECFDF5',
          items: const <(String, String, String)>[
            ('86', 'مراجع', 'حتى الظهر'),
            ('14', 'تحويل', 'إلى المستشفى'),
            ('7', 'نواقص', 'في الصيدلية'),
          ],
        ),
        pw.SizedBox(height: 14),
        _sectionLabel('الزيارات', '0F6E56'),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: const <String>['الفترة', 'العيادة', 'المراجعون', 'ملاحظة'],
          columnWidths: const <double>[1.1, 1.4, 1, 2.2],
          headerDecoration: '0F6E56',
          oddRowDecoration: 'ECFDF5',
          cellStyle: const pw.TextStyle(fontSize: 9, color: '292524'),
          headerStyle: const pw.TextStyle(fontSize: 9, color: 'FFFFFF'),
          data: const <List<String>>[
            <String>['08:00', 'أطفال', '31', 'سعال موسمي مرتفع'],
            <String>['09:30', 'نساء', '22', 'ثلاث حالات متابعة'],
            <String>['11:00', 'مزمن', '18', 'نقص أنسولين جزئي'],
            <String>['12:30', 'إصابات', '15', 'ضمادات كافية'],
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Chart(
          title: 'المراجعون حسب العيادة',
          width: 500,
          height: 150,
          points: const <pw.ChartPoint>[
            pw.ChartPoint(label: 'أطفال', value: 31, color: '0F6E56'),
            pw.ChartPoint(label: 'نساء', value: 22, color: '14B8A6'),
            pw.ChartPoint(label: 'مزمن', value: 18, color: '5EEAD4'),
            pw.ChartPoint(label: 'إصابات', value: 15, color: '99F6E4'),
          ],
        ),
        pw.SizedBox(height: 14),
        _sectionLabel('صرف الصيدلية', '0F6E56'),
        pw.SizedBox(height: 8),
        _check('محلول وريدي — الكمية تغطي يومين', done: true, accent: '0F6E56', yes: 'تم', no: 'ناقص'),
        _check('مضاد حيوي أطفال — تحت الحد الأدنى', done: false, accent: '0F6E56', yes: 'تم', no: 'ناقص'),
        _check('ضمادات معقمة — تم الجرد صباحا', done: true, accent: '0F6E56', yes: 'تم', no: 'ناقص'),
        _check('أنسولين — طلب تعزيز قبل المغرب', done: false, accent: '0F6E56', yes: 'تم', no: 'ناقص'),
        pw.SizedBox(height: 10),
        pw.Text(
          'يُغلق الكشف عند الرابعة. التحويلات العاجلة تُسجَّل في دفتر المناوبة '
          'قبل مغادرة الفريق الأخير.',
          textAlign: pw.TextAlign.start,
          style: const pw.TextStyle(fontSize: 11, color: '44403C', height: 1.5),
        ),
        pw.NewPage(),
        pw.Directionality(
          textDirection: pw.TextDirection.ltr,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: <pw.Widget>[
              _band(
                kicker: 'ENGLISH CLOSE  ·  SAME CLINIC',
                face: 'Cairo',
                color: '134E4A',
                ink: 'CCFBF1',
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'Morning close',
                style: const pw.TextStyle(fontSize: 22, color: '134E4A'),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Eighty-six patients were seen before noon. Fourteen were '
                'referred onward. Insulin and paediatric antibiotics need a '
                'resupply before the evening shift.',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: '44403C',
                  height: 1.5,
                ),
              ),
              pw.SizedBox(height: 10),
              const pw.Bullet(text: 'Keep the referral log with the duty nurse.'),
              const pw.Bullet(text: 'Do not close insulin cases without a dose note.'),
            ],
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

/// Board packet: agenda, decisions, budget chart, Arabic minutes.
Uint8List studioBoardPacketPdf() {
  final pw.Document doc = pw.Document(
    title: 'Board packet — 13 September 2026',
    author: 'Quds Studio',
    font: StudioPdfFaces.tajawal(),
    fontBold: StudioPdfFaces.tajawalBold(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      footer: (pw.Context context) => const pw.Footer(
        leading: pw.Text(
          'QUDS OFFICE  ·  BOARD',
          style: pw.TextStyle(fontSize: 8, color: '78716C'),
        ),
      ),
      build: (pw.Context context) => <pw.Widget>[
        pw.Watermark.text(
          'BOARD',
          style: const pw.TextStyle(
            fontSize: 42,
            fontWeight: pw.FontWeight.bold,
            color: 'F5F5F4',
          ),
        ),
        _band(
          kicker: 'QUDS OFFICE  ·  13 SEP 2026',
          face: 'Packet',
          color: '9A3412',
          ink: 'FFEDD5',
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Board packet',
          style: const pw.TextStyle(
            fontSize: 26,
            fontWeight: pw.FontWeight.bold,
            color: '9A3412',
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Ninety minutes. Decisions are numbered. Figures are in thousands.',
          style: const pw.TextStyle(fontSize: 11, color: '57534E'),
        ),
        pw.SizedBox(height: 14),
        _sectionLabel('Agenda', '9A3412'),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: const <String>['Time', 'Item', 'Owner', 'Ask'],
          columnWidths: const <double>[0.9, 2.2, 1.3, 1.6],
          headerDecoration: '9A3412',
          oddRowDecoration: 'FFF7ED',
          cellStyle: const pw.TextStyle(fontSize: 9, color: '292524'),
          headerStyle: const pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: 'FFFFFF',
          ),
          data: const <List<String>>[
            <String>['09:00', 'Access figures', 'Field desk', 'Note only'],
            <String>['09:20', 'Shelter budget', 'Finance', 'Approve'],
            <String>['09:45', 'Open cases', 'Protection', 'Prioritise'],
            <String>['10:10', 'Next quarter', 'Chair', 'Confirm dates'],
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: <pw.Widget>[
                  _sectionLabel('Decisions', '9A3412'),
                  pw.SizedBox(height: 8),
                  _check('D1  Keep the water target at 73%', done: true, accent: '9A3412'),
                  _check('D2  Release shelter top-up', done: true, accent: '9A3412'),
                  _check('D3  Hold new hires until October', done: false, accent: '9A3412'),
                  _check('D4  Publish the public brief Friday', done: false, accent: '9A3412'),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Chart(
              type: pw.ChartType.pie,
              title: 'Spend mix',
              width: 230,
              height: 150,
              points: const <pw.ChartPoint>[
                pw.ChartPoint(label: 'Water', value: 38, color: '9A3412'),
                pw.ChartPoint(label: 'Shelter', value: 27, color: 'EA580C'),
                pw.ChartPoint(label: 'Health', value: 21, color: 'FDBA74'),
                pw.ChartPoint(label: 'Admin', value: 14, color: 'FED7AA'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        _sectionLabel('Quarter budget', '9A3412'),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: const <String>['Line', 'Plan', 'Spent', 'Left'],
          columnWidths: const <double>[2.2, 1, 1, 1],
          headerDecoration: '7C2D12',
          oddRowDecoration: 'FFF7ED',
          cellAlignments: const <int, pw.Alignment>{
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          headerAlignments: const <int, pw.Alignment>{
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          cellStyle: const pw.TextStyle(fontSize: 9, color: '292524'),
          headerStyle: const pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: 'FFFFFF',
          ),
          data: const <List<String>>[
            <String>['Water points', '420', '310', '110'],
            <String>['Shelter kits', '280', '190', '90'],
            <String>['Clinic consumables', '150', '96', '54'],
            <String>['Field transport', '70', '41', '29'],
          ],
        ),
        pw.SizedBox(height: 12),
        const pw.Bullet(text: 'Figures are thousands of local units, not dollars.'),
        const pw.Bullet(text: 'Unspent shelter funds stay ring-fenced.'),
        pw.NewPage(),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: _band(
            kicker: 'محضر مختصر  ·  بالعربية',
            face: 'Tajawal',
            color: '9A3412',
            ink: 'FFEDD5',
          ),
        ),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Text(
            'ما اتُفق عليه',
            textAlign: pw.TextAlign.start,
            style: const pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: '9A3412',
            ),
          ),
        ),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Text(
            'ثبّت المجلس هدف الوصول إلى المياه عند 73 بالمئة، وأفرج عن '
            'دفعة المأوى، وأجّل التوظيف الجديد إلى تشرين الأول. يُنشر '
            'الموجز العام يوم الجمعة.',
            textAlign: pw.TextAlign.start,
            style: const pw.TextStyle(fontSize: 12, color: '44403C', height: 1.55),
          ),
        ),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Table.fromTextArray(
            headers: const <String>['البند', 'القرار'],
            columnWidths: const <double>[1.2, 3],
            headerDecoration: '9A3412',
            oddRowDecoration: 'FFF7ED',
            cellStyle: const pw.TextStyle(fontSize: 10, color: '292524'),
            headerStyle: const pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: 'FFFFFF',
            ),
            data: const <List<String>>[
              <String>['المياه', 'الإبقاء على 73%'],
              <String>['المأوى', 'صرف الدفعة'],
              <String>['التوظيف', 'مؤجّل'],
            ],
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

/// Neighbourhood recovery brief: cards, chart, table, Arabic notes.
Uint8List studioRecoveryBriefPdf() {
  final pw.Document doc = pw.Document(
    title: 'Recovery corridor — Al Tahreer',
    author: 'Quds Studio',
    font: StudioPdfFaces.cairo(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      footer: (pw.Context context) => const pw.Footer(
        leading: pw.Text(
          'RECOVERY CORRIDOR  ·  Q3 2026',
          style: pw.TextStyle(fontSize: 8, color: '78716C'),
        ),
      ),
      build: (pw.Context context) => <pw.Widget>[
        _band(
          kicker: 'QUDS OFFICE  ·  CORRIDOR',
          face: 'Cairo',
          color: '134E4A',
          ink: 'CCFBF1',
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Recovery corridor',
          style: const pw.TextStyle(fontSize: 26, color: '134E4A'),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Three neighbourhoods on the same water and shelter line. '
          'Figures are the mid-September count.',
          style: const pw.TextStyle(fontSize: 11, color: '57534E', height: 1.4),
        ),
        pw.SizedBox(height: 12),
        pw.GridView(
          crossAxisCount: 3,
          childAspectRatio: 1.35,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: <pw.Widget>[
            _placeCard('Al Tahreer', '73%', 'Water lead', '0F6E56', 'ECFDF5'),
            _placeCard('Al Rimal', '61%', 'Shelter hold', '0F766E', 'F0FDFA'),
            _placeCard('Shuja\'iyya', '48%', 'Priority', 'B45309', 'FFF7ED'),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Chart(
          type: pw.ChartType.line,
          title: 'Water access, May to September',
          width: 500,
          height: 146,
          points: const <pw.ChartPoint>[
            pw.ChartPoint(label: 'May', value: 41, color: '0F6E56'),
            pw.ChartPoint(label: 'Jun', value: 49, color: '0F6E56'),
            pw.ChartPoint(label: 'Jul', value: 55, color: '0F6E56'),
            pw.ChartPoint(label: 'Aug', value: 64, color: '0F6E56'),
            pw.ChartPoint(label: 'Sep', value: 73, color: '0F6E56'),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(
          headers: const <String>['Place', 'Households', 'Water', 'Open files'],
          columnWidths: const <double>[1.6, 1.2, 1, 1.2],
          headerDecoration: '134E4A',
          oddRowDecoration: 'F0FDFA',
          cellAlignments: const <int, pw.Alignment>{
            1: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.center,
          },
          cellStyle: const pw.TextStyle(fontSize: 9, color: '292524'),
          headerStyle: const pw.TextStyle(fontSize: 9, color: 'FFFFFF'),
          data: const <List<String>>[
            <String>['Al Tahreer', '1,240', '73%', '6'],
            <String>['Al Rimal', '980', '61%', '8'],
            <String>['Shuja\'iyya', '1,510', '48%', '11'],
          ],
        ),
        pw.SizedBox(height: 10),
        const pw.Bullet(text: 'Shuja\'iyya stays first in the tanker roster.'),
        const pw.Bullet(text: 'Shelter kits already staged in Al Rimal are not moved.'),
        pw.NewPage(),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: _band(
            kicker: 'ملاحظة عربية  ·  الممر نفسه',
            face: 'Cairo',
            color: '134E4A',
            ink: 'CCFBF1',
          ),
        ),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Text(
            'أين يقف الممر',
            textAlign: pw.TextAlign.start,
            style: const pw.TextStyle(fontSize: 22, color: '134E4A'),
          ),
        ),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Text(
            'ارتفع الوصول إلى المياه في التحرير إلى 73 بالمئة. الرمال مستقرة '
            'جزئيا. الشجاعية ما زالت الأولوية: ثمانية وأربعون بالمئة، وأحد '
            'عشر ملفا مفتوحا.',
            textAlign: pw.TextAlign.start,
            style: const pw.TextStyle(fontSize: 12, color: '44403C', height: 1.55),
          ),
        ),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: _kpiRow(
            accent: '134E4A',
            wash: 'F0FDFA',
            items: const <(String, String, String)>[
              ('73%', 'التحرير', 'مياه'),
              ('61%', 'الرمال', 'مأوى'),
              ('48%', 'الشجاعية', 'أولوية'),
            ],
          ),
        ),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Text(
            'لا تُنقل أطقم المأوى الموجودة في الرمال. صهريج الشجاعية يبقى '
            'أول الرحلة حتى إغلاق الأسبوع.',
            textAlign: pw.TextAlign.start,
            style: const pw.TextStyle(fontSize: 11, color: '57534E', height: 1.5),
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
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: pw.Row(
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Text(
            kicker,
            style: pw.TextStyle(
              color: ink,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
        ),
        pw.Text(
          face,
          style: const pw.TextStyle(color: 'FFFFFF', fontSize: 12),
        ),
      ],
    ),
  );
}

pw.Widget _sectionLabel(String text, String color) {
  return pw.Text(
    text,
    textAlign: pw.TextAlign.start,
    style: pw.TextStyle(fontSize: 13, color: color),
  );
}

pw.Widget _kpiRow({
  required String accent,
  required String wash,
  required List<(String, String, String)> items,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      for (int i = 0; i < items.length; i++) ...<pw.Widget>[
        if (i > 0) pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: pw.BoxDecoration(color: wash, borderRadius: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: <pw.Widget>[
                pw.Text(
                  items[i].$1,
                  textAlign: pw.TextAlign.start,
                  style: pw.TextStyle(fontSize: 16, color: accent),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  items[i].$2,
                  textAlign: pw.TextAlign.start,
                  style: const pw.TextStyle(fontSize: 9, color: '292524'),
                ),
                pw.Text(
                  items[i].$3,
                  textAlign: pw.TextAlign.start,
                  style: const pw.TextStyle(fontSize: 8, color: '78716C'),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

pw.Widget _check(
  String label, {
  required bool done,
  String accent = '3730A3',
  String yes = 'done',
  String no = 'open',
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Checkbox(value: done, size: 11),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: pw.Text(
            label,
            textAlign: pw.TextAlign.start,
            style: pw.TextStyle(
              fontSize: 10,
              color: done ? '292524' : '78716C',
            ),
          ),
        ),
        pw.Text(
          done ? yes : no,
          style: pw.TextStyle(fontSize: 8, color: accent),
        ),
      ],
    ),
  );
}

pw.Widget _chip(String label, String wash, String ink) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: pw.BoxDecoration(color: wash, borderRadius: 10),
    child: pw.Text(
      label,
      style: pw.TextStyle(fontSize: 8, color: ink),
    ),
  );
}

pw.Widget _placeCard(
  String name,
  String value,
  String note,
  String accent,
  String wash,
) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(color: wash, borderRadius: 4),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(name, style: pw.TextStyle(fontSize: 10, color: accent)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 16, color: accent)),
        pw.Text(note, style: const pw.TextStyle(fontSize: 8, color: '57534E')),
      ],
    ),
  );
}
