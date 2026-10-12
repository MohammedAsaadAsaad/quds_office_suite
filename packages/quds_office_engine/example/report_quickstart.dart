// Band reports in pure Dart: a `.qrep` template + data → PDF, XLSX, DOCX.
//
//   dart run example/report_quickstart.dart [out-dir] [font-dir]
//
// `font-dir` (optional) holds TrueType faces to embed, e.g. the editor
// package's `fonts/` folder. Arabic templates need an Arabic face there.
import 'dart:io';

import 'package:quds_office_engine/quds_reports.dart';

const String _template = '''<?xml version="1.0" encoding="UTF-8"?>
<QudsReport name="Order summary" pageSize="A4" orientation="Portrait" defaultFontSize="10">
  <Settings>
    <Margins top="15mm" bottom="15mm" left="15mm" right="15mm"/>
    <Colors primary="#1E3A8A" light="#F4F7FB"/>
  </Settings>
  <Variables>
    <Var name="vatRate" type="number" value="0.15" format="percent"/>
  </Variables>
  <Bands>
    <ReportHeader height="24mm">
      <Shape kind="RoundedRectangle" x="0mm" y="0mm" width="180mm" height="18mm" fill="primary" strokeWidth="0" cornerRadius="3pt"/>
      <Text x="5mm" y="3mm" width="120mm" height="8mm" fontSize="16" bold="true" color="#FFFFFF">Order summary</Text>
      <Text x="5mm" y="11mm" width="120mm" height="5mm" color="#DBEAFE">{{Data.customer}} · {{System.CurrentDate | date:dd MMM yyyy}}</Text>
    </ReportHeader>
    <Detail dataSource="Data.items" height="8mm">
      <Text x="0mm" y="1mm" width="110mm" height="6mm">{{item.name}}</Text>
      <Text x="110mm" y="1mm" width="20mm" height="6mm" alignment="right">{{item.qty}}</Text>
      <Text x="130mm" y="1mm" width="50mm" height="6mm" alignment="right">{{item.qty * item.price | n2}}</Text>
    </Detail>
    <ReportSummary height="20mm">
      <Text x="90mm" y="2mm" width="40mm" height="6mm" alignment="right">VAT {{Variables.vatRate | percent}}</Text>
      <Text x="130mm" y="2mm" width="50mm" height="6mm" alignment="right">{{SUM(item.qty * item.price) * Variables.vatRate | n2}}</Text>
      <Text x="90mm" y="9mm" width="40mm" height="7mm" alignment="right" bold="true">Total</Text>
      <Text x="130mm" y="9mm" width="50mm" height="7mm" alignment="right" bold="true">{{SUM(item.qty * item.price) * (1 + Variables.vatRate) | currency:USD}}</Text>
    </ReportSummary>
  </Bands>
</QudsReport>''';

Future<void> main(List<String> args) async {
  final Directory out = Directory(args.isNotEmpty ? args[0] : 'report_out')
    ..createSync(recursive: true);
  final ReportFontRegistry fonts = ReportFontRegistry();
  if (args.length > 1) {
    final String dir = args[1];
    fonts.registerBytes(
      'Liberation Sans',
      File('$dir/LiberationSans-Regular.ttf').readAsBytesSync(),
      bold: File('$dir/LiberationSans-Bold.ttf').readAsBytesSync(),
    );
    fonts.registerBytes(
      'Noto Naskh Arabic',
      File('$dir/NotoNaskhArabic-Regular.ttf').readAsBytesSync(),
      bold: File('$dir/NotoNaskhArabic-Bold.ttf').readAsBytesSync(),
    );
    fonts.defaultFamily = 'Liberation Sans';
  }

  // 1. Your own template.
  final QudsReportEngine engine = QudsReportEngine.fromXml(
    _template,
    fonts: fonts,
  );
  final Map<String, Object?> data = <String, Object?>{
    'customer': 'Northwind Traders',
    'items': <Map<String, Object?>>[
      <String, Object?>{'name': 'Laptop 14"', 'qty': 2, 'price': 1250.0},
      <String, Object?>{'name': 'Monitor 27" 4K', 'qty': 3, 'price': 410.0},
      <String, Object?>{'name': 'Docking station', 'qty': 2, 'price': 189.5},
    ],
  };
  for (final ReportDiagnostic d in engine.validate()) {
    stdout.writeln('${d.severity.name}: ${d.path}: ${d.message}');
  }
  File(
    '${out.path}/order.pdf',
  ).writeAsBytesSync(await engine.exportToPdf(data));
  File(
    '${out.path}/order.xlsx',
  ).writeAsBytesSync(await engine.exportToExcel(data));
  File(
    '${out.path}/order.docx',
  ).writeAsBytesSync(await engine.exportToWord(data));

  // 2. A bundled template with its saved images and sample data.
  final ReportTemplateInfo dashboard = ReportTemplates.byId(
    'sales_performance',
  )!;
  final QudsReportEngine sales = QudsReportEngine.fromPackage(
    dashboard.package().encode(),
    fonts: fonts,
  );
  File(
    '${out.path}/${dashboard.id}.pdf',
  ).writeAsBytesSync(await sales.exportToPdf(dashboard.sampleData()));

  stdout.writeln(
    'Wrote order.pdf/.xlsx/.docx and ${dashboard.id}.pdf to ${out.path}',
  );
}
