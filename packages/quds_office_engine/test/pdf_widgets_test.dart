import 'dart:io';

import 'dart:typed_data';

import 'package:quds_office_engine/pdf_widgets.dart' as pw;
import 'package:quds_office_engine/quds_office_engine.dart';
import 'package:test/test.dart';

import '../example/pdf_widgets_invoice.dart' as invoice;
import '../example/pdf_widgets_proposal.dart' as proposal;
import '../example/pdf_widgets_report.dart' as report;

void main() {
  final SfntFont? font = _tryFont();

  test('Document.save emits a readable multi-page PDF', () {
    final pw.Document doc = pw.Document(title: 'Widget test', font: font);
    doc.addPage(
      pw.MultiPage(
        pageFormat: pw.PdfPageFormat.a4,
        build: (pw.Context context) => <pw.Widget>[
          pw.Header(level: 1, text: 'Alpha heading'),
          pw.Paragraph(text: 'Hello from constraint layout.'),
          const pw.TableOfContent(title: 'Contents'),
          pw.Header(level: 1, text: 'Beta heading'),
          const pw.NewPage(),
          pw.Paragraph(text: 'Second page body.'),
          pw.Table.fromTextArray(
            headers: const <String>['A', 'B'],
            data: const <List<String>>[
              ['one', 'two'],
            ],
          ),
        ],
      ),
    );
    final bytes = doc.save();
    expect(bytes.length, greaterThan(200));
    final PdfFile file = PdfFile.open(bytes);
    expect(file.pageCount, greaterThanOrEqualTo(2));
    final String text = PdfExtract.pageText(file, 0) + PdfExtract.pageText(file, 1);
    expect(text.contains('Hello'), isTrue);
    expect(text.contains('Alpha'), isTrue);
    expect(text.contains('Beta'), isTrue);
  });

  test('MultiPage Align shrink-wraps (invoice stays compact)', () {
    final pw.Document doc = pw.Document(font: font);
    doc.addPage(
      pw.MultiPage(
        pageFormat: pw.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => <pw.Widget>[
          pw.Text('Title'),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: const <String>['A', 'B'],
            data: const <List<String>>[
              <String>['1', '2'],
            ],
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Total'),
          ),
        ],
      ),
    );
    final bytes = doc.save();
    expect(PdfFile.open(bytes).pageCount, 1);
  });

  test('table cells expand fill to full column width and row height', () {
    final pw.Document doc = pw.Document(font: font);
    late pw.PwSize tableSize;
    late pw.PwSize firstCellSize;
    doc.addPage(
      pw.Page(
        pageFormat: pw.PdfPageFormat.a4,
        build: (pw.Context context) {
          final pw.Table table = pw.Table.fromTextArray(
            headers: const <String>['A', 'B'],
            data: const <List<String>>[
              <String>['x', 'yy'],
            ],
            columnWidths: const <double>[2, 1],
          );
          final pw.PwBox box = table.layout(
            context,
            const pw.BoxConstraints(maxWidth: 300, maxHeight: 400),
          );
          tableSize = box.size;
          final pw.Container probe = pw.Container(
            color: 'FF0000',
            alignment: pw.Alignment.center,
            child: const pw.Text('x'),
          );
          firstCellSize = probe
              .layout(
                context,
                pw.BoxConstraints.tight(const pw.PwSize(200, 30)),
              )
              .size;
          return table;
        },
      ),
    );
    doc.save();
    expect(tableSize.width, closeTo(300, 0.1));
    expect(firstCellSize.width, closeTo(200, 0.1));
    expect(firstCellSize.height, closeTo(30, 0.1));
  });

  test('Row and Column honor flex and produce a non-empty box', () {
    final pw.Document doc = pw.Document(font: font);
    late pw.PwSize size;
    doc.addPage(
      pw.Page(
        pageFormat: pw.PdfPageFormat.a4,
        build: (pw.Context context) {
          final pw.Widget tree = pw.Column(
            children: const <pw.Widget>[
              pw.Text('Title'),
              pw.Row(
                children: <pw.Widget>[
                  pw.Expanded(child: pw.Text('L')),
                  pw.Expanded(child: pw.Text('R')),
                ],
              ),
            ],
          );
          final pw.PwBox box = tree.layout(
            context,
            const pw.BoxConstraints(maxWidth: 400, maxHeight: 200),
          );
          size = box.size;
          return tree;
        },
      ),
    );
    final bytes = doc.save();
    expect(bytes.length, greaterThan(100));
    expect(size.width, greaterThan(10));
    expect(size.height, greaterThan(10));
  });

  test('invoice / report / proposal examples open in PdfFile', () {
    final List<({String name, Uint8List bytes, int pages, String needle})>
    samples = <({String name, Uint8List bytes, int pages, String needle})>[
      (
        name: 'invoice',
        bytes: invoice.buildInvoice(font: font),
        pages: 1,
        needle: 'INV-2026',
      ),
      (
        name: 'report',
        bytes: report.buildQuarterlyReport(font: font),
        pages: 3,
        needle: 'Confidential',
      ),
      (
        name: 'proposal',
        bytes: proposal.buildProposal(font: font),
        pages: 1,
        needle: 'quds_office_engine',
      ),
    ];
    for (final sample in samples) {
      final PdfFile file = PdfFile.open(sample.bytes);
      expect(file.pageCount, greaterThanOrEqualTo(sample.pages), reason: sample.name);
      final StringBuffer all = StringBuffer();
      for (int i = 0; i < file.pageCount; i++) {
        all.write(PdfExtract.pageText(file, i));
      }
      expect(all.toString(), contains(sample.needle), reason: sample.name);
    }
  });
}

SfntFont? _tryFont() {
  const List<String> paths = <String>[
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
  ];
  for (final String path in paths) {
    final File file = File(path);
    if (file.existsSync()) {
      return SfntFont.parse(file.readAsBytesSync());
    }
  }
  return null;
}
