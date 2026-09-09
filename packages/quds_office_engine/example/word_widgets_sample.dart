import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/word_widgets.dart' as ww;

/// Builds a branded Arabic/English DOCX from the widget tree (no editor).
Future<void> main(List<String> args) async {
  final Directory out = Directory(
    args.isEmpty ? 'example/out/word_widgets' : args.first,
  )..createSync(recursive: true);

  final ww.Document doc = ww.Document(
    theme: ww.ThemeData.withFont(base: 'Noto Naskh Arabic'),
    title: 'تقرير',
  );
  doc.addPage(
    ww.MultiPage(
      pageFormat: ww.PdfPageFormat.a4,
      textDirection: ww.TextDirection.rtl,
      header: (ww.Context context) => ww.Header(level: 0, text: 'تقرير'),
      footer: (ww.Context context) => ww.Footer(
        leading: const ww.Text('سري'),
        title: ww.Text('${context.pageNumber}'),
      ),
      build: (ww.Context context) => <ww.Widget>[
        ww.Header(level: 1, text: 'ملخص الربع'),
        ww.Paragraph(text: 'العربية والإنجليزية.'),
        ww.RichText(
          text: ww.TextSpan(
            children: <ww.InlineSpan>[
              const ww.TextSpan(text: 'العربية والإنجليزية. '),
              ww.TextSpan(
                text: 'مهم',
                style: const ww.TextStyle(
                  fontWeight: ww.FontWeight.bold,
                  color: '2B579A',
                ),
              ),
            ],
          ),
        ),
        ww.Bullet(text: 'Word'),
        ww.Bullet(text: 'Excel'),
        ww.Table.fromTextArray(
          headers: <String>['KPI', 'Q1'],
          data: <List<String>>[
            <String>['Docs', '120'],
          ],
        ),
        const ww.NewPage(),
        const ww.Row(
          children: <ww.Widget>[
            ww.Text('Left'),
            ww.Expanded(flex: 2, child: ww.Text('Wide')),
          ],
        ),
      ],
    ),
  );

  final Uint8List bytes = await doc.save();
  File('${out.path}/widgets.docx').writeAsBytesSync(bytes);
  stdout.writeln('Wrote ${out.path}/widgets.docx');
}
