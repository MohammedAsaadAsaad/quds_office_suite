import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart';

/// Minimal engine sample: write a branded Arabic/English DOCX and a PDF.
void main(List<String> args) {
  final Directory out = Directory(
    args.isEmpty ? 'example/out/quickstart' : args.first,
  )..createSync(recursive: true);

  final OfficeDocumentTheme theme = OfficeDocumentTheme.custom(
    palette: const OfficePalette(primary: '2B579A', accent: '217346'),
    rtl: true,
    page: OfficePageSize.a4Portrait,
  );

  final Uint8List docx = (DocxDocumentBuilder(theme: theme)
        ..heading('Quds Office Engine')
        ..paragraph('Pure Dart Office Open XML — no Flutter, no dart:ui.')
        ..note('القدس · Word · Excel · PowerPoint · PDF')
        ..bulletList(<String>['Builders', 'Models', 'Formulas', 'PDF 1.7'])
        ..table(<List<String>>[
          <String>['Package', 'Runtime'],
          <String>['quds_office_engine', 'Dart'],
          <String>['quds_office_editor', 'Flutter RenderBox'],
        ]))
      .build();

  File('${out.path}/quickstart.docx').writeAsBytesSync(docx);
  File('${out.path}/quickstart.pdf').writeAsBytesSync(
    OfficePdfExport.fromBytes(docx, title: 'Quds Office Engine'),
  );

  stdout.writeln('Wrote ${out.path}/quickstart.docx');
  stdout.writeln('Wrote ${out.path}/quickstart.pdf');
}
