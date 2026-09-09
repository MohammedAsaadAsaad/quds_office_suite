import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart'
    show PngBytes, SfntFont;
import 'package:quds_office_engine/word_widgets.dart' as ww;

/// تقرير ربع سنوي احترافي يعرض شجرة الودجتات ثم يكتب DOCX وPDF.
Future<void> main(List<String> args) async {
  final Directory out = Directory(
    args.isEmpty ? 'example/out/word_report' : args.first,
  )..createSync(recursive: true);

  final SfntFont? font = _loadReportFont();
  if (font == null) {
    stderr.writeln(
      'No SFNT font with Arabic coverage found; PDF text will be incomplete.',
    );
  }

  final Uint8List banner = _brandBanner();
  final ww.Document doc = _buildReport(banner);

  final Uint8List docx = await doc.save();
  final Uint8List pdf = await doc.toPdf(
    title: 'تقرير الأداء — الربع الثالث 2026',
    font: font,
  );
  File('${out.path}/quarterly_report.docx').writeAsBytesSync(docx);
  File('${out.path}/quarterly_report.pdf').writeAsBytesSync(pdf);
  stdout.writeln('Wrote ${out.path}/quarterly_report.docx  (${docx.length} bytes)');
  stdout.writeln('Wrote ${out.path}/quarterly_report.pdf   (${pdf.length} bytes)');
  if (font != null) {
    stdout.writeln('PDF font: ${font.familyName}');
  }
}

ww.Document _buildReport(Uint8List banner) {
  final ww.Document doc = ww.Document(
    theme: ww.ThemeData.withFont(base: 'Noto Naskh Arabic'),
    title: 'تقرير الأداء — الربع الثالث 2026',
    author: 'مكتب القدس',
    subject: 'تقرير إداري ربع سنوي',
    keywords: 'Quds, Office, Word, widgets',
    creator: 'quds_office_engine',
  );
  doc.addPage(_portraitFront(banner));
  doc.addPage(_landscapeAppendix());
  doc.addPage(_portraitBack());
  return doc;
}

ww.MultiPage _portraitFront(Uint8List banner) {
  return ww.MultiPage(
    pageFormat: ww.PdfPageFormat.a4,
    textDirection: ww.TextDirection.rtl,
    margin: const ww.EdgeInsets.fromLTRB(54, 56, 54, 56),
    header: (ww.Context context) => _chromeHeader('مجموعة القدس  ·  مكتب التقارير'),
    footer: (ww.Context context) => _chromeFooter(context),
    build: (ww.Context context) => <ww.Widget>[
      ww.Watermark.text('مسودة'),
      ww.Image(ww.MemoryImage(banner), width: 460, height: 72),
      const ww.Text(
        'QUDS OFFICE',
        style: ww.TextStyle(
          color: '1F4E79',
          fontWeight: ww.FontWeight.bold,
          fontSize: 11,
        ),
      ),
      const ww.SizedBox(height: 10),
      ww.Header(level: 1, text: 'تقرير الأداء الربعي'),
      ww.Paragraph(
        text:
            'يلخّص هذا التقرير نتائج الربع الثالث من عام 2026: الوثائق، الجداول، '
            'والرسوم، مع عيّنة من كل ودجت في طبقة word/widgets — الناتج ملف وورد '
            'أصيل وليس صفحة PDF مرسومة.',
      ),
      ww.RichText(
        text: ww.TextSpan(
          children: <ww.InlineSpan>[
            const ww.TextSpan(text: 'التصنيف: '),
            ww.TextSpan(
              text: 'داخلي',
              style: const ww.TextStyle(
                fontWeight: ww.FontWeight.bold,
                color: 'C0392B',
              ),
            ),
            const ww.TextSpan(text: '  ·  الفترة: '),
            ww.TextSpan(
              text: '1 يوليو — 30 سبتمبر 2026',
              style: const ww.TextStyle(fontStyle: ww.FontStyle.italic),
            ),
            const ww.WidgetSpan(
              child: ww.Icon(ww.IconData(0x2713), size: 11, color: '217346'),
            ),
          ],
        ),
      ),
      const ww.Divider(color: '2B579A', height: 14),
      const ww.TableOfContent(
        title: 'المحتويات',
        minLevel: 1,
        maxLevel: 2,
      ),
      ww.Header(level: 2, text: 'الملخص التنفيذي'),
      ww.Container(
        color: 'EEF3F9',
        padding: const ww.EdgeInsets.all(10),
        margin: const ww.EdgeInsets.only(bottom: 8),
        child: ww.Column(
          children: <ww.Widget>[
            ww.Paragraph(
              text:
                  'ارتفع إصدار الوثائق بنسبة 18٪، واستقرّ متوسط زمن الحفظ تحت '
                  'ثانيتين، مع اكتمال مسار الترجمة من شجرة الودجتات إلى DOCX.',
            ),
            const ww.Row(
              children: <ww.Widget>[
                ww.Expanded(
                  child: ww.Text(
                    '120 مستنداً',
                    style: ww.TextStyle(
                      fontWeight: ww.FontWeight.bold,
                      color: '1F4E79',
                    ),
                  ),
                ),
                ww.Expanded(
                  child: ww.Text(
                    '18٪ نمو',
                    style: ww.TextStyle(
                      fontWeight: ww.FontWeight.bold,
                      color: '217346',
                    ),
                  ),
                ),
                ww.Flexible(
                  child: ww.Text(
                    '0 أعطال حرجة',
                    style: ww.TextStyle(fontWeight: ww.FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ww.Paragraph(
        text:
            'الجداول العريضة والرسم البياني في القسم التالي على صفحات أفقية '
            '(سكشن مستقل في وسط الملف) ثم يعود المتن إلى A4 عمودي.',
      ),
    ],
  );
}

ww.MultiPage _landscapeAppendix() {
  return ww.MultiPage(
    pageFormat: ww.PdfPageFormat.a4,
    orientation: ww.PageOrientation.landscape,
    textDirection: ww.TextDirection.rtl,
    margin: const ww.EdgeInsets.fromLTRB(48, 44, 48, 44),
    header: (ww.Context context) =>
        _chromeHeader('ملحق أفقي مستقل  ·  مؤشرات الأداء'),
    footer: (ww.Context context) => _chromeFooter(context, trailing: 'Landscape'),
    build: (ww.Context context) => <ww.Widget>[
      ww.Header(level: 1, text: 'مؤشرات الأداء'),
      ww.Paragraph(
        text:
            'هذا سكشن وورد مستقل (`nextPage`) بعرض A4 أفقي في وسط التقرير — '
            'ليس استدارة للملف كله. بعد هذا الملحق يعود السكشن التالي للعمودي.',
      ),
      ww.Table.fromTextArray(
        headers: <String>[
          'المكتب',
          'Q1',
          'Q2',
          'Q3',
          'النمو',
          'الحفظ (ث)',
          'PDF',
          'الحالة',
        ],
        data: <List<String>>[
          <String>['القدس', '28', '31', '42', '+35٪', '1.6', '9', 'مكتمل'],
          <String>['رام الله', '22', '26', '31', '+19٪', '1.8', '7', 'مكتمل'],
          <String>['غزة', '18', '21', '27', '+29٪', '2.1', '6', 'جزئي'],
          <String>['بيروت', '8', '9', '11', '+22٪', '1.9', '3', 'مكتمل'],
          <String>['عمّان', '6', '5', '6', '0٪', '2.0', '1', 'مستقر'],
          <String>['الدوحة', '2', '2', '3', '+50٪', '1.7', '1', 'جديد'],
        ],
      ),
      const ww.SizedBox(height: 10),
      ww.Chart(
        title: 'إصدار الوثائق حسب الربع',
        width: 680,
        height: 180,
        points: const <ww.ChartPoint>[
          ww.ChartPoint(label: 'Q1', value: 86, color: '8FAADC'),
          ww.ChartPoint(label: 'Q2', value: 102, color: '5B9BD5'),
          ww.ChartPoint(label: 'Q3', value: 120, color: '2B579A'),
        ],
      ),
    ],
  );
}

ww.MultiPage _portraitBack() {
  return ww.MultiPage(
    pageFormat: ww.PdfPageFormat.a4,
    textDirection: ww.TextDirection.rtl,
    margin: const ww.EdgeInsets.fromLTRB(54, 56, 54, 56),
    header: (ww.Context context) => _chromeHeader('مجموعة القدس  ·  مكتب التقارير'),
    footer: (ww.Context context) => _chromeFooter(context),
    build: (ww.Context context) => <ww.Widget>[
        ww.Header(level: 2, text: 'الإنجازات والمخاطر'),
        ww.Partitions(
          children: <ww.Partition>[
            ww.Partition(
              flex: 1,
              child: ww.Column(
                children: <ww.Widget>[
                  ww.Header(level: 3, text: 'أُنجز'),
                  ww.Bullet(text: 'طبقة Document / MultiPage'),
                  ww.Bullet(text: 'جداول من fromTextArray'),
                  ww.Bullet(text: 'ترويسة وتذييل برقم الصفحة'),
                ],
              ),
            ),
            ww.Partition(
              flex: 1,
              child: ww.Column(
                children: <ww.Widget>[
                  ww.Header(level: 3, text: 'التالي'),
                  ww.Numbered(text: 'مراجعة التنسيقات مع وورد'),
                  ww.Numbered(text: 'ربط الاستوديو عند الطلب'),
                  ww.Numbered(text: 'قوالب تقارير إضافية'),
                ],
              ),
            ),
          ],
        ),
        ww.Header(level: 2, text: 'التوزيع الجغرافي'),
        ww.GridView(
          crossAxisCount: 3,
          children: <ww.Widget>[
            _kpiTile('القدس', '42'),
            _kpiTile('رام الله', '31'),
            _kpiTile('غزة', '27'),
            _kpiTile('بيروت', '11'),
            _kpiTile('عمّان', '6'),
            _kpiTile('الدوحة', '3'),
          ],
        ),
        const ww.NewPage(),
        ww.Header(level: 1, text: 'التفاصيل التشغيلية'),
        ww.Header(level: 2, text: 'مسار البناء'),
        ww.Flex(
          direction: ww.Axis.horizontal,
          children: const <ww.Widget>[
            ww.Text('شجرة ودجتات'),
            ww.Spacer(),
            ww.Text('→'),
            ww.Spacer(),
            ww.Text('WmlDocument'),
            ww.Spacer(),
            ww.Text('→'),
            ww.Spacer(),
            ww.Text('DOCX / PDF'),
          ],
        ),
        const ww.SizedBox(height: 8),
        ww.ListView(
          spacing: 2,
          children: const <ww.Widget>[
            ww.Text('1. ترجمة واحدة بلا تخطيط صفحات في المترجم.'),
            ww.Text('2. الأنماط تُكتب في styles.xml من ThemeData.'),
            ww.Text('3. التذييل يختم حقل PAGE.'),
          ],
        ),
        ww.Wrap(
          runSpacing: 4,
          children: const <ww.Widget>[
            ww.Text('وسوم: '),
            ww.Text('Word  ·  '),
            ww.Text('PDF  ·  '),
            ww.Text('RTL  ·  '),
            ww.Text('Office Open XML'),
          ],
        ),
        ww.Header(level: 2, text: 'اعتماد وملاحظات'),
        ww.Directionality(
          textDirection: ww.TextDirection.ltr,
          child: ww.Paragraph(
            textAlign: ww.TextAlign.left,
            text:
                'English note: this file is a real Word document (pPr/rPr/tables), '
                'exported also as PDF 1.7 from the same model.',
          ),
        ),
        const ww.DefaultTextStyle(
          style: ww.TextStyle(fontSize: 10, color: '1F4E79'),
          child: ww.Text('نص بأسلوب افتراضي أزرق داكن عبر DefaultTextStyle.'),
        ),
        ww.Inseparable(
          child: ww.Paragraph(
            text:
                'هذه الفقرة تُحفظ معاً (keepTogether) حتى لا تنقسم على حد الصفحة '
                'إن أمكن ذلك في وورد.',
          ),
        ),
        ww.Anchor(
          name: 'approval',
          child: ww.Header(level: 3, text: 'اعتماد الإدارة'),
        ),
        ww.Builder(
          builder: (ww.Context ctx) => ww.Paragraph(
            text:
                'بُنيت هذه الفقرة وقت الترجمة (Builder) — صفحة المعاينة ${ctx.pageNumber}.',
          ),
        ),
        ww.Theme(
          data: ww.ThemeData(
            defaultTextStyle: const ww.TextStyle(fontSize: 10, color: '217346'),
          ),
          child: const ww.Text('سطر أخضر داخل Theme محلي.'),
        ),
        ww.DecoratedBox(
          decoration: ww.BoxDecoration(
            color: 'FFF8E7',
            border: ww.Border.all(color: 'D4A017'),
          ),
          child: const ww.Padding(
            padding: ww.EdgeInsets.all(8),
            child: ww.Text('تنبيه: الأرقام أولية حتى إغلاق الدفاتر في 7 أكتوبر.'),
          ),
        ),
        const ww.SizedBox(height: 8),
        ww.Center(
          child: ww.UrlLink(
            destination: 'https://example.com/reports/q3-2026',
            child: const ww.Text(
              'رابط الأرشيف الكامل',
              style: ww.TextStyle(
                color: '0563C1',
                decoration: ww.TextDecoration.underline,
              ),
            ),
          ),
        ),
        const ww.Link(
          destination: 'approval',
          child: ww.Text('العودة إلى اعتماد الإدارة'),
        ),
        ww.Header(level: 2, text: 'نماذج خفيفة وأشكال'),
        ww.Row(
          children: <ww.Widget>[
            const ww.Expanded(
              child: ww.Column(
                children: <ww.Widget>[
                  ww.Checkbox(value: true, name: 'راجعت الأرقام'),
                  ww.Checkbox(value: false, name: 'بانتظار التدقيق'),
                  ww.TextField(name: 'المدير', value: '________________'),
                ],
              ),
            ),
            ww.Expanded(
              child: ww.Container(
                color: 'EEF3F9',
                padding: const ww.EdgeInsets.all(8),
                child: const ww.Column(
                  children: <ww.Widget>[
                    ww.Text(
                      'شارة الحالة',
                      style: ww.TextStyle(
                        fontSize: 9,
                        fontWeight: ww.FontWeight.bold,
                        color: '2B579A',
                      ),
                    ),
                    ww.Text(
                      'أزرق = معتمد  ·  أخضر = مكتمل',
                      style: ww.TextStyle(fontSize: 8, color: '666666'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const ww.SizedBox(height: 10),
        const ww.Placeholder(fallbackHeight: 28, color: '8FAADC'),
        ww.Header(level: 2, text: 'نص تجريبي'),
        const ww.Lorem(length: 40),
        ww.Paragraph(
          margin: const ww.EdgeInsets.only(top: 12),
          text:
              '— انتهى تقرير الربع الثالث. الملفات المرفقة: Word (.docx) وPDF 1.7 '
              'من النموذج نفسه عبر OfficePdfExport.word.',
        ),
    ],
  );
}

ww.Widget _chromeHeader(String text) {
  return ww.Text(
    text,
    style: const ww.TextStyle(fontSize: 9, color: '2B579A'),
  );
}

ww.Widget _chromeFooter(ww.Context context, {String trailing = 'Q3 2026'}) {
  return ww.Footer(
    leading: const ww.Text(
      'سري — للاستخدام الداخلي',
      style: ww.TextStyle(fontSize: 8, color: '666666'),
    ),
    title: ww.Text(
      '${context.pageNumber}',
      style: const ww.TextStyle(fontSize: 9, color: '2B579A'),
    ),
    trailing: ww.Text(
      trailing,
      style: const ww.TextStyle(fontSize: 8, color: '666666'),
    ),
  );
}

ww.Widget _kpiTile(String city, String value) {
  return ww.Container(
    color: 'F7F9FC',
    padding: const ww.EdgeInsets.all(8),
    margin: const ww.EdgeInsets.all(3),
    alignment: ww.Alignment.center,
    child: ww.Column(
      children: <ww.Widget>[
        ww.Text(
          value,
          style: const ww.TextStyle(
            fontSize: 16,
            fontWeight: ww.FontWeight.bold,
            color: '2B579A',
          ),
        ),
        ww.Text(city, style: const ww.TextStyle(fontSize: 9, color: '666666')),
      ],
    ),
  );
}

SfntFont? _loadReportFont() {
  const List<String> candidates = <String>[
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/noto/NotoNaskhArabic-Regular.ttf',
    '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf',
    '/home/mohammed/.local/share/fonts/Tajawal-Regular.ttf',
  ];
  for (final String path in candidates) {
    final File file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    final SfntFont font = SfntFont.parse(file.readAsBytesSync());
    if (font.hasTable('glyf') &&
        font.glyphIdFor(0x41) != 0 &&
        font.glyphIdFor(0x627) != 0) {
      return font;
    }
  }
  return null;
}

Uint8List _brandBanner() {
  return PngBytes.rgb(
    width: 640,
    height: 96,
    plot: (int x, int y, List<int> rgb) {
      final double t = x / 639;
      rgb[0] = (0x1F + ((0x2B - 0x1F) * t)).round();
      rgb[1] = (0x4E + ((0x57 - 0x4E) * t)).round();
      rgb[2] = (0x79 + ((0x9A - 0x79) * t)).round();
      if (y < 4 || y > 91) {
        rgb[0] = 0x17;
        rgb[1] = 0x36;
        rgb[2] = 0x55;
      }
    },
  );
}
