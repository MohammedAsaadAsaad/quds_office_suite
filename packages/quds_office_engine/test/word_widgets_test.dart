import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart';
import 'package:quds_office_engine/word_widgets.dart' as ww;
import 'package:test/test.dart';

void main() {
  test('round-trips Arabic and English paragraphs', () {
    final ww.Document doc = ww.Document(
      theme: ww.ThemeData.withFont(base: 'Noto Naskh Arabic'),
    );
    doc.addPage(
      ww.MultiPage(
        textDirection: ww.TextDirection.rtl,
        build: (ww.Context context) => <ww.Widget>[
          ww.Header(level: 1, text: 'ملخص الربع'),
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
          const ww.NewPage(),
          const ww.SizedBox(height: 16),
          const ww.Text('Hello after the break'),
        ],
      ),
    );
    final WmlDocument model = doc.toModel();
    expect(model.paragraphs.first.text, 'ملخص الربع');
    expect(model.paragraphs.first.properties.styleId, 'Heading1');
    expect(model.paragraphs.first.properties.rightToLeft, isTrue);
    expect(
      model.paragraphs.any((WmlParagraph p) => p.properties.pageBreakBefore),
      isTrue,
    );
    final WmlDocument opened = WordDeserializer().read(
      WordSerializer().write(doc.toModel()),
    );
    expect(
      opened.paragraphs.map((WmlParagraph p) => p.text).join(' '),
      contains('ملخص الربع'),
    );
    expect(
      opened.paragraphs.map((WmlParagraph p) => p.text).join(' '),
      contains('مهم'),
    );
    expect(
      opened.paragraphs.map((WmlParagraph p) => p.text).join(' '),
      contains('Hello after the break'),
    );
  });

  test('round-trips bullets tables links and padding', () {
    final ww.Document doc = ww.Document();
    doc.addPage(
      ww.MultiPage(
        build: (ww.Context context) => <ww.Widget>[
          ww.Bullet(text: 'Word'),
          ww.Bullet(text: 'Excel'),
          ww.Numbered(text: 'One'),
          ww.Table.fromTextArray(
            headers: <String>['KPI', 'Q1'],
            data: <List<String>>[
              <String>['Docs', '120'],
            ],
          ),
          const ww.UrlLink(
            destination: 'https://example.com',
            child: ww.Text('Docs'),
          ),
          const ww.Divider(),
          const ww.Align(
            alignment: ww.Alignment.center,
            child: ww.Padding(
              padding: ww.EdgeInsets.all(12),
              child: ww.Text('Padded'),
            ),
          ),
        ],
      ),
    );
    final WmlDocument model = doc.toModel();
    expect(
      model.paragraphs.any((WmlParagraph p) => p.properties.numId == 1),
      isTrue,
    );
    expect(
      model.paragraphs.any((WmlParagraph p) => p.properties.numId == 2),
      isTrue,
    );
    expect(model.sections.first.blocks.whereType<WmlTable>(), isNotEmpty);
    final WmlTable table = model.sections.first.blocks
        .whereType<WmlTable>()
        .first;
    expect(table.rows.first.cells.first.fillColor, isNotEmpty);
    expect(table.rows[1].cells.first.fillColor, isNull);
    expect(
      model.paragraphs.any(
        (WmlParagraph p) => p.inlines.whereType<WmlRun>().any(
          (WmlRun r) => r.hyperlink?.url == 'https://example.com',
        ),
      ),
      isTrue,
    );
    expect(
      model.paragraphs.any((WmlParagraph p) => p.properties.borderColor != null),
      isTrue,
    );
    final WmlParagraph padded = model.paragraphs.firstWhere(
      (WmlParagraph p) => p.text == 'Padded',
    );
    expect(padded.properties.justification, WmlJustification.center);
    expect(padded.properties.indent.left, 12);
    final WmlDocument opened = WordDeserializer().read(
      WordSerializer().write(model),
    );
    expect(
      opened.paragraphs.map((WmlParagraph p) => p.text).join(' '),
      contains('Word'),
    );
    expect(opened.sections.first.blocks.whereType<WmlTable>(), isNotEmpty);
  });

  test('middle MultiPage is an independent landscape section', () {
    final ww.Document doc = ww.Document();
    doc.addPage(
      ww.MultiPage(
        pageFormat: ww.PdfPageFormat.a4,
        build: (ww.Context context) => <ww.Widget>[
          ww.Header(level: 1, text: 'Front'),
        ],
      ),
    );
    doc.addPage(
      ww.MultiPage(
        pageFormat: ww.PdfPageFormat.a4,
        orientation: ww.PageOrientation.landscape,
        header: (ww.Context context) => const ww.Text('Landscape appendix'),
        build: (ww.Context context) => <ww.Widget>[
          ww.Header(level: 1, text: 'Wide table'),
        ],
      ),
    );
    doc.addPage(
      ww.MultiPage(
        pageFormat: ww.PdfPageFormat.a4,
        build: (ww.Context context) => <ww.Widget>[
          ww.Header(level: 1, text: 'Back'),
        ],
      ),
    );
    final WmlDocument model = doc.toModel();
    expect(model.sections, hasLength(3));
    expect(model.sections[0].pageSize.isLandscape, isFalse);
    expect(model.sections[1].pageSize.isLandscape, isTrue);
    expect(model.sections[2].pageSize.isLandscape, isFalse);
    expect(model.sections[1].breakKind, WmlSectionBreakKind.nextPage);
    expect(model.sections[1].linkToPrevious, isFalse);
    expect(model.sections[1].header.first.text, contains('Landscape appendix'));
    expect(model.sections[1].pageSize.width, greaterThan(model.sections[0].pageSize.width));

    final Uint8List bytes = WordSerializer().writeBytes(model);
    final String xml = OpcPackage.openBytes(
      bytes,
    ).getPart('/word/document.xml')!.readText();
    expect(xml.split('<w:sectPr').length - 1, 3);
    expect(xml, contains('w:orient="landscape"'));
    final WmlDocument opened = WordDeserializer().readBytes(bytes);
    expect(opened.sections, hasLength(3));
    expect(opened.sections[1].pageSize.isLandscape, isTrue);
    expect(
      opened.sections[1].pageSize.width,
      greaterThan(opened.sections[1].pageSize.height),
    );
  });

  test('writes header footer page number image and page format', () {
    final Uint8List png = Uint8List.fromList(_png1x1);
    final ww.Document doc = ww.Document();
    doc.addPage(
      ww.MultiPage(
        pageFormat: ww.PdfPageFormat.letter,
        header: (ww.Context context) =>
            ww.Header(level: 0, text: 'تقرير'),
        footer: (ww.Context context) => ww.Footer(
          title: ww.Text('${context.pageNumber}'),
        ),
        build: (ww.Context context) => <ww.Widget>[
          ww.Image(ww.MemoryImage(png), width: 80, height: 80),
          ww.Chart(
            title: 'KPI',
            points: const <ChartPoint>[
              ChartPoint(label: 'Q1', value: 12),
              ChartPoint(label: 'Q2', value: 18),
            ],
          ),
        ],
      ),
    );
    final WmlDocument model = doc.toModel();
    expect(model.sections.first.pageSize.width, closeTo(8.5 * 72, 0.01));
    expect(model.sections.first.header, isNotEmpty);
    expect(model.sections.first.header.first.text, contains('تقرير'));
    expect(model.sections.first.footer, isNotEmpty);
    expect(
      model.sections.first.footer.first.properties.fieldInstruction,
      contains('PAGE'),
    );
    expect(
      model.visuals.where(
        (WmlVisual v) => v.visual.kind == OfficeVisualKind.picture,
      ),
      isNotEmpty,
    );
    expect(
      model.visuals.where(
        (WmlVisual v) => v.visual.kind == OfficeVisualKind.chartColumn,
      ),
      isNotEmpty,
    );
    final WmlDocument opened = WordDeserializer().read(
      WordSerializer().write(model),
    );
    expect(opened.sections.first.header, isNotEmpty);
    expect(opened.visuals, isNotEmpty);
  });

  test('row expands as a borderless table and save skips the XML builder', () async {
    final ww.Document doc = ww.Document(
      theme: ww.ThemeData.withFont(base: 'Calibri'),
    );
    doc.addPage(
      ww.MultiPage(
        build: (ww.Context context) => <ww.Widget>[
          ww.Header(level: 2, text: 'Row'),
          const ww.Row(
            children: <ww.Widget>[
              ww.Text('Left'),
              ww.Expanded(flex: 2, child: ww.Text('Wide')),
            ],
          ),
        ],
      ),
    );
    final WmlDocument model = doc.toModel();
    final WmlTable row = model.sections.first.blocks
        .whereType<WmlTable>()
        .single;
    expect(row.grid.length, 2);
    expect(row.grid[1], greaterThan(row.grid[0]));
    final Uint8List bytes = await doc.save();
    expect(bytes.take(2).toList(), <int>[0x50, 0x4B]);
    final OpcPackage package = OpcPackage.openBytes(bytes);
    final String styles = package.getPart('/word/styles.xml')!.readText();
    expect(styles.contains('docDefaults'), isFalse);
    expect(styles.contains('Calibri'), isTrue);
    final WmlDocument opened = WordDeserializer().read(
      WordSerializer().write(model),
    );
    expect(opened.sections.first.blocks.whereType<WmlTable>(), isNotEmpty);
    expect(opened.paragraphs.first.properties.styleId, 'Heading2');
  });

  test('toPdf writes a PDF and banded heading defaults apply', () async {
    final ww.Document doc = ww.Document();
    doc.addPage(
      ww.MultiPage(
        build: (ww.Context context) => <ww.Widget>[
          ww.Header(level: 1, text: 'Report'),
          ww.Table.fromTextArray(
            headers: <String>['A', 'B'],
            data: <List<String>>[
              <String>['1', '2'],
              <String>['3', '4'],
            ],
          ),
        ],
      ),
    );
    final WmlTable table = doc
        .toModel()
        .sections
        .first
        .blocks
        .whereType<WmlTable>()
        .single;
    expect(table.rows[2].cells.first.fillColor, isNotEmpty);
    final Uint8List pdf = await doc.toPdf(title: 'Widgets');
    expect(pdf.take(5).toList(), <int>[37, 80, 68, 70, 45]);
  });

  test('maps extra pdf widgets onto Word model', () {
    final ww.Document doc = ww.Document(watermark: 'CONFIDENTIAL');
    doc.addPage(
      ww.MultiPage(
        build: (ww.Context context) => <ww.Widget>[
          ww.Watermark.text('DRAFT'),
          const ww.TableOfContent(),
          ww.Header(level: 1, text: 'Intro'),
          ww.Builder(
            builder: (ww.Context ctx) => ww.Text('Built ${ctx.pageNumber}'),
          ),
          const ww.Directionality(
            textDirection: ww.TextDirection.rtl,
            child: ww.Text('يمين'),
          ),
          const ww.DefaultTextStyle(
            style: ww.TextStyle(fontWeight: ww.FontWeight.bold),
            child: ww.Text('Bold default'),
          ),
          ww.Inseparable(child: ww.Paragraph(text: 'Keep')),
          const ww.Anchor(name: 'here', child: ww.Text('Bookmark')),
          ww.Container(
            color: 'EEF3F9',
            padding: const ww.EdgeInsets.all(6),
            child: const ww.Text('Boxed'),
          ),
          ww.ListView(
            children: const <ww.Widget>[ww.Text('A'), ww.Text('B')],
          ),
          ww.GridView(
            crossAxisCount: 2,
            children: const <ww.Widget>[
              ww.Text('1'),
              ww.Text('2'),
              ww.Text('3'),
              ww.Text('4'),
            ],
          ),
          const ww.Partitions(
            children: <ww.Partition>[
              ww.Partition(flex: 1, child: ww.Text('Col A')),
              ww.Partition(flex: 2, child: ww.Text('Col B')),
            ],
          ),
          const ww.Checkbox(value: true, name: 'Done'),
          const ww.TextField(value: 'Name'),
          const ww.Icon(ww.IconData(0x2713)),
          const ww.Lorem(length: 8),
          const ww.Placeholder(),
          const ww.Circle(fillColor: '2B579A', width: 24, height: 24),
          const ww.Stack(
            children: <ww.Widget>[
              ww.Text('Base'),
              ww.Positioned(left: 40, top: 40, child: ww.Text('Float')),
            ],
          ),
          ww.RichText(
            text: ww.TextSpan(
              children: <ww.InlineSpan>[
                const ww.TextSpan(text: 'Hi '),
                const ww.WidgetSpan(child: ww.Text('span')),
              ],
            ),
          ),
        ],
      ),
    );
    final WmlDocument model = doc.toModel();
    expect(model.watermark, 'DRAFT');
    expect(model.sections.first.blocks.whereType<WmlToc>(), isNotEmpty);
    expect(
      model.paragraphs.any((WmlParagraph p) => p.text.contains('Intro')),
      isTrue,
    );
    expect(
      model.paragraphs.any((WmlParagraph p) => p.properties.rightToLeft == true),
      isTrue,
    );
    expect(
      model.paragraphs.any((WmlParagraph p) => p.properties.keepTogether),
      isTrue,
    );
    expect(
      model.paragraphs.any((WmlParagraph p) => p.properties.bookmarkName == 'here'),
      isTrue,
    );
    expect(
      model.paragraphs.any((WmlParagraph p) => p.properties.shadingFill == 'EEF3F9'),
      isTrue,
    );
    expect(
      model.paragraphs.any((WmlParagraph p) => p.text.contains('☑')),
      isTrue,
    );
    expect(model.sections.first.blocks.whereType<WmlFrame>(), isNotEmpty);
    expect(model.sections.first.blocks.whereType<WmlTable>().length, greaterThan(1));
    final WmlDocument opened = WordDeserializer().read(
      WordSerializer().write(model),
    );
    expect(opened.watermark, isNotEmpty);
    expect(
      opened.paragraphs.map((WmlParagraph p) => p.text).join(' '),
      contains('Intro'),
    );
  });
}

const List<int> _png1x1 = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A,
  0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00,
  0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
  0xAE, 0x42, 0x60, 0x82,
];
