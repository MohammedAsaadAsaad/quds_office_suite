import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart';

/// Quarterly Word report via [DocxDocumentBuilder] (no widget DSL).
void main(List<String> args) {
  final Directory out = Directory(
    args.isEmpty ? 'example/out/word_report' : args.first,
  )..createSync(recursive: true);

  final OfficeDocumentTheme theme = OfficeDocumentTheme.custom(
    palette: const OfficePalette(primary: '1F4E79', accent: 'C9A227'),
    rtl: true,
  );
  final Uint8List docx = (DocxDocumentBuilder(theme: theme)
        ..header(left: 'مجموعة القدس', right: 'سري')
        ..footer(left: 'تقرير الأداء', pageNumber: true)
        ..heading('تقرير الأداء الربعي')
        ..paragraph(
          'يلخّص هذا التقرير نتائج الربع الثالث من عام 2026: الوثائق، '
          'الجداول، والرسوم. ملف وورد أصيل عبر DocxDocumentBuilder.',
        )
        ..heading('المؤشرات', level: 2)
        ..table([
          ['المؤشر', 'الربع الثاني', 'الربع الثالث', 'التغيّر'],
          ['وثائق', '148', '172', '+16%'],
          ['شرائح', '41', '55', '+34%'],
          ['جداول', '96', '110', '+15%'],
        ])
        ..heading('الحجم', level: 2)
        ..barChart(
          title: 'الحجم',
          series: const [
            ChartPoint(label: 'Q1', value: 120),
            ChartPoint(label: 'Q2', value: 148),
            ChartPoint(label: 'Q3', value: 172),
          ],
        )
        ..note('أُنشئ دون Microsoft Office.')
        ..hyperlink(
          'التوثيق',
          'https://pub.dev/packages/quds_office_engine',
        ))
      .build();

  File('${out.path}/quarterly_report.docx').writeAsBytesSync(docx);
  stdout.writeln('Wrote ${out.path}/quarterly_report.docx  (${docx.length} bytes)');
}
