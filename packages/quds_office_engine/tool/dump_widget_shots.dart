/// Build widget gallery samples + rasterize with pdftoppm (no Flutter).
///
///   cd packages/quds_office_engine && dart run tool/dump_widget_shots.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/pdf_widgets.dart' as pw;
import 'package:quds_office_engine/quds_office_engine.dart';

import '../example/pdf_widgets_invoice.dart' as invoice;
import '../example/pdf_widgets_proposal.dart' as proposal;
import '../example/pdf_widgets_report.dart' as report;

void main() {
  final Directory out = Directory(
    '${Directory.systemTemp.path}/quds_widget_shots',
  )..createSync(recursive: true);
  for (final FileSystemEntity e in out.listSync()) {
    e.deleteSync(recursive: true);
  }

  final SfntFont? font = _loadFont();
  stdout.writeln('out=${out.path} font=${font != null}');

  final Map<String, Uint8List Function(SfntFont?)> samples =
      <String, Uint8List Function(SfntFont?)>{
    'engine_invoice': invoice.buildInvoice,
    'engine_proposal': proposal.buildProposal,
    'engine_report': report.buildReport,
    'studio_invoice': _studioInvoice,
    'studio_proposal': _studioProposal,
    'studio_quarterly': _studioQuarterly,
    'studio_agenda': _studioAgenda,
    'studio_dossier': _studioDossier,
  };

  var fail = 0;
  for (final MapEntry<String, Uint8List Function(SfntFont?)> e
      in samples.entries) {
    try {
      final Uint8List bytes = e.value(font);
      File('${out.path}/${e.key}.pdf').writeAsBytesSync(bytes);
      final ProcessResult r = Process.runSync('pdftoppm', <String>[
        '-png',
        '-r',
        '120',
        '${out.path}/${e.key}.pdf',
        '${out.path}/${e.key}',
      ]);
      if (r.exitCode != 0) {
        throw StateError('${r.stderr}');
      }
      final PdfFile file = PdfFile.open(bytes);
      stdout.writeln(
        'OK ${e.key} bytes=${bytes.length} pages=${file.pageCount}',
      );
    } catch (err) {
      stderr.writeln('FAIL ${e.key}: $err');
      fail++;
    }
  }
  stdout.writeln('done fail=$fail');
  if (fail != 0) {
    exit(1);
  }
}

SfntFont? _loadFont() {
  const List<String> paths = <String>[
    '../quds_office_editor/fonts/LiberationSans-Regular.ttf',
    'fonts/LiberationSans-Regular.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
  ];
  for (final String p in paths) {
    final File f = File(p);
    if (f.existsSync()) {
      return SfntFont.parse(f.readAsBytesSync());
    }
  }
  return null;
}

Uint8List _studioInvoice(SfntFont? font) {
  final pw.Document doc = pw.Document(title: 'Invoice', font: font);
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) => <pw.Widget>[
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: const pw.BoxDecoration(color: '1A237E'),
          child: pw.Text(
            'QUDS OFFICE  ·  INVOICE',
            style: const pw.TextStyle(
              color: 'FFFFFF',
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: const <pw.Widget>[
                  pw.Text(
                    'Bill to',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                      color: '546E7A',
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Al Tahreer Neighbourhood Trust'),
                  pw.Text('Procurement desk'),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: const <pw.Widget>[
                  pw.Text('Invoice INV-2026-0911'),
                  pw.Text('Issued 11 September 2026'),
                  pw.Text('Due 25 September 2026'),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Table.fromTextArray(
          headers: const <String>['Description', 'Qty', 'Rate', 'Amount'],
          columnWidths: const <double>[3.4, 0.7, 0.9, 1.0],
          headerDecoration: '1A237E',
          data: const <List<String>>[
            <String>['Platform license — Engine (annual)', '1', '2,400', '2,400'],
            <String>['Editor seats', '8', '180', '1,440'],
            <String>['PDF file stack', '1', '950', '950'],
            <String>['Priority support', '1', '420', '420'],
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Amount due: 5,210.00',
            style: const pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: '1A237E',
            ),
          ),
        ),
        pw.SizedBox(height: 16),
        const pw.Bullet(
          text: 'Payable within 14 days. Reference the invoice number.',
        ),
        const pw.Bullet(
          text: 'Generated with pdf_widgets MultiPage + Table.',
        ),
      ],
    ),
  );
  return doc.save();
}

Uint8List _studioProposal(SfntFont? font) {
  final pw.Document doc = pw.Document(title: 'Proposal', font: font);
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (pw.Context c) => <pw.Widget>[
        pw.Header(level: 0, text: 'Project proposal'),
        pw.Paragraph(
          text:
              'This proposal outlines delivery of the Quds Office PDF file stack '
              'for neighbourhood operations: open, annotate, and save without '
              'leaving the Flutter host.',
        ),
        pw.Header(level: 2, text: 'Scope'),
        pw.Bullet(text: 'PdfFile open path with incremental save.'),
        pw.Bullet(text: 'Viewer and editor surfaces on RenderBox.'),
        pw.Bullet(text: 'pdf_widgets composer for branded packets.'),
        pw.Header(level: 2, text: 'Timeline'),
        pw.Paragraph(
          text:
              'Phase gates follow the suite roadmap. Acceptance is pixel-honest '
              'against Evince for the agreed fixture set.',
        ),
        pw.Table.fromTextArray(
          headers: const <String>['Milestone', 'Week', 'Owner'],
          data: const <List<String>>[
            <String>['COS + xref', '1–2', 'Engine'],
            <String>['Display list', '3–4', 'Engine'],
            <String>['Viewer chrome', '5', 'Editor'],
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

Uint8List _studioQuarterly(SfntFont? font) {
  final pw.Document doc = pw.Document(title: 'Quarterly', font: font);
  doc.addPage(
    pw.Page(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context c) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: const pw.BoxDecoration(color: '0D47A1'),
            child: const pw.Text(
              'Q3 briefing',
              style: pw.TextStyle(
                color: 'FFFFFF',
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: <pw.Widget>[
              for (final String kpi in <String>[
                '94%\nOn-time',
                '12\nSites',
                '1.8M\nReach',
              ])
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.only(right: 8),
                    padding: const pw.EdgeInsets.all(12),
                    decoration: const pw.BoxDecoration(
                      color: 'E3F2FD',
                      borderRadius: 6,
                    ),
                    child: pw.Text(
                      kpi,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Paragraph(
            text:
                'Field teams closed the corridor registration backlog. '
                'Partner surge capacity remains the binding constraint for '
                'October household verification.',
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

Uint8List _studioAgenda(SfntFont? font) {
  final pw.Document doc = pw.Document(title: 'Agenda', font: font);
  doc.addPage(
    pw.Page(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context c) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: const pw.BoxDecoration(color: '1565C0'),
            child: const pw.Text(
              'BOARD MEETING AGENDA',
              style: pw.TextStyle(
                color: 'FFFFFF',
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(
              color: 'E8EAF6',
              borderRadius: 6,
            ),
            child: const pw.Text(
              'Attendees: Chair, Ops, Shelter, Finance, Partners',
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Table.fromTextArray(
            headers: const <String>['Time', 'Item', 'Owner', 'Decision'],
            columnWidths: const <double>[1.1, 2.6, 1.2, 1.2],
            headerDecoration: '0D47A1',
            data: const <List<String>>[
              <String>['09:00', 'Opening & quorum', 'Chair', 'Endorse'],
              <String>['09:15', 'Shelter pipeline', 'Shelter', 'Note'],
              <String>['09:45', 'Budget draw-down', 'Finance', 'Approve'],
              <String>['10:15', 'Partner MoU', 'Ops', 'Discuss'],
            ],
          ),
          pw.SizedBox(height: 16),
          const pw.Text(
            'Annexes',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: '1565C0',
            ),
          ),
          const pw.Bullet(text: 'Annex A — attendance sheet'),
          const pw.Bullet(text: 'Annex B — draft resolutions'),
        ],
      ),
    ),
  );
  return doc.save();
}

Uint8List _studioDossier(SfntFont? font) {
  final pw.Document doc = pw.Document(title: 'Dossier', font: font);
  doc.addPage(
    pw.Page(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context c) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(color: 'ECEFF1'),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: const <pw.Widget>[
                  pw.Text(
                    'Facts',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('Population est. 42k'),
                  pw.Text('Registered HH 6,180'),
                  pw.Text('Active partners 9'),
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: const <pw.Widget>[
                pw.Text(
                  'Narrative',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                    color: '1A237E',
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Paragraph(
                  text:
                      'Al Tahreer remains the priority corridor for rental '
                      'subsidy targeting. Verification teams will surge for '
                      'two weeks starting mid-September.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
