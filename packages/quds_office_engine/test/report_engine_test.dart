import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart';
import 'package:test/test.dart';

const String invoiceXml = r'''<?xml version="1.0" encoding="UTF-8"?>
<QudsReport name="AdvancedInvoice" isRtl="true" pageSize="A4" orientation="Portrait" defaultFont="Cairo">
    <Settings>
        <Margins top="20mm" bottom="20mm" left="15mm" right="15mm"/>
        <Colors primary="#1F4E78" secondary="#595959" text="#000000" background="#FFFFFF"/>
    </Settings>
    <Variables>
        <Var name="CompanyName" value="شركة القدس للتقنية المتقدمة"/>
        <Var name="TaxNumber" value="TRN-987654321"/>
    </Variables>
    <Bands>
        <ReportHeader height="45mm">
            <Element type="Text" x="10mm" y="10mm" width="110mm" height="15mm" fontSize="20" bold="true" color="primary">
                {{Variables.CompanyName}}
            </Element>
            <Element type="Text" x="130mm" y="10mm" width="70mm" height="8mm" alignment="right" fontSize="10">
                التاريخ: {{System.CurrentDate}} ({{System.CurrentTime}})
            </Element>
            <Element type="Text" x="130mm" y="18mm" width="70mm" height="8mm" alignment="right" fontSize="10" color="secondary">
                الرقم الضريبي: {{Variables.TaxNumber}}
            </Element>
            <Element type="Shape" kind="Line" x1="10mm" y1="40mm" x2="200mm" y2="40mm" strokeWidth="0.5" color="primary"/>
        </ReportHeader>
        <PageHeader height="10mm">
            <Element type="Text" x="10mm" y="2mm" width="100mm" height="6mm" fontSize="9" color="secondary">
                فاتورة مبيعات رسمية - مرجع: {{Data.invoiceNo}}
            </Element>
        </PageHeader>
        <Detail dataSet="items" rowHeight="8mm">
            <Table x="10mm" y="5mm" width="190mm" showGrid="true" borderColor="#D3D3D3">
                <Columns>
                    <Column width="25mm" header="الرمز" align="center"/>
                    <Column width="95mm" header="وصف الصنف" align="right"/>
                    <Column width="20mm" header="الكمية" align="center"/>
                    <Column width="25mm" header="السعر الفردي" align="left"/>
                    <Column width="25mm" header="الإجمالي" align="left"/>
                </Columns>
                <RowTemplate>
                    <Cell field="item.code"/>
                    <Cell field="item.description"/>
                    <Cell field="item.qty"/>
                    <Cell field="item.price" format="currency:LYD"/>
                    <Cell field="item.total" format="currency:LYD" bold="true"/>
                </RowTemplate>
            </Table>
        </Detail>
        <GroupFooter height="20mm">
            <Element type="Text" x="130mm" y="5mm" width="40mm" height="8mm" bold="true" alignment="right">
                المجموع الفرعي:
            </Element>
            <Element type="Text" x="170mm" y="5mm" width="30mm" height="8mm" alignment="left">
                {{SUM(items.total)}}
            </Element>
        </GroupFooter>
        <PageFooter height="12mm">
            <Element type="Shape" kind="Line" x1="10mm" y1="2mm" x2="200mm" y2="2mm" strokeWidth="0.3" color="secondary"/>
            <Element type="Text" x="10mm" y="4mm" width="100mm" height="6mm" fontSize="8" color="secondary">
                تم الاستخراج بواسطة نظام Quds Office Suite
            </Element>
            <Element type="Text" x="150mm" y="4mm" width="50mm" height="6mm" alignment="right" fontSize="9" bold="true">
                الصفحة {{System.PageNumber}} من {{System.TotalPages}}
            </Element>
        </PageFooter>
        <ReportSummary height="35mm">
            <Element type="Text" x="10mm" y="5mm" width="190mm" height="8mm" bold="true">
                المبلغ بالحروف: {{TAFQEET(SUM(items.total), 'LYD')}}
            </Element>
            <Element type="Text" x="140mm" y="20mm" width="60mm" height="8mm" alignment="center">
                توقيع المسؤول / ....................
            </Element>
        </ReportSummary>
    </Bands>
</QudsReport>
''';

Map<String, Object?> invoiceData(int count) => <String, Object?>{
  'invoiceNo': 'INV-2026-001',
  'items': <Map<String, Object?>>[
    for (int i = 0; i < count; i++)
      <String, Object?>{
        'code': 'P${(i + 1).toString().padLeft(2, '0')}',
        'description': 'تطوير حزمة Dart رقم ${i + 1}',
        'qty': 1 + i % 3,
        'price': 500,
        'total': 500 * (1 + i % 3),
      },
  ],
};

ReportFontRegistry loadFonts() {
  final ReportFontRegistry fonts = ReportFontRegistry();
  final File regular = File(
    '../quds_office_editor/fonts/NotoNaskhArabic-Regular.ttf',
  );
  final File bold = File(
    '../quds_office_editor/fonts/NotoNaskhArabic-Bold.ttf',
  );
  if (regular.existsSync()) {
    fonts.registerBytes(
      'Noto Naskh Arabic',
      regular.readAsBytesSync(),
      bold: bold.existsSync() ? bold.readAsBytesSync() : null,
    );
  }
  final File latin = File(
    '../quds_office_editor/fonts/LiberationSans-Regular.ttf',
  );
  if (latin.existsSync()) {
    fonts.registerBytes('Liberation Sans', latin.readAsBytesSync());
  }
  return fonts;
}

final DateTime fixedNow = DateTime(2026, 10, 10, 9, 30);

QudsReportEngine invoiceEngine() => QudsReportEngine.fromXml(
  invoiceXml,
  fonts: loadFonts(),
  clock: () => fixedNow,
  userName: 'tester',
);

List<String> pageTexts(ReportPageLayout page) => <String>[
  for (final ReportPrimitive p in page.primitives)
    if (p is ReportTextPrimitive) p.text,
];

String partText(Uint8List zip, String uri) =>
    utf8.decode(OpcPackage.openBytes(zip).getPart(uri)!.bytesView);

void main() {
  group('Arabic Tafqeet', () {
    test('whole and fractional dinars', () {
      expect(ArabicTafqeet.amount(500, 'LYD'), 'فقط خمسمائة دينار ليبي لا غير');
      expect(
        ArabicTafqeet.amount(1250.5, 'LYD'),
        'فقط ألف ومائتان وخمسون ديناراً ليبياً وخمسمائة درهم لا غير',
      );
    });

    test('counted nouns follow dual and plural forms', () {
      expect(ArabicTafqeet.amount(2, 'LYD'), contains('ديناران'));
      expect(ArabicTafqeet.amount(3, 'LYD'), contains('دنانير'));
      expect(ArabicTafqeet.amount(11, 'LYD'), contains('ديناراً'));
      expect(ArabicTafqeet.amount(1000000, 'LYD'), contains('مليون'));
    });
  });

  group('Expression engine', () {
    final QudsExpressionEngine engine = QudsExpressionEngine();
    final ReportRecord data = ReportValue.from(invoiceData(3)) as ReportRecord;
    final List<ReportValue> rows = (data.field('items')! as ReportList).items;
    final ReportScope scope = ReportScope(
      data: data,
      variables: const ReportRecord(<String, ReportValue>{
        'CompanyName': ReportText('Quds'),
      }),
      system: ReportSystemInfo(
        now: fixedNow,
        pageNumber: 2,
        totalPages: 5,
        userName: 'u',
      ),
    );

    test('inline arithmetic on the current row', () {
      final ReportScope rowScope = scope.copyWith(row: rows[1], rowIndex: 1);
      expect(
        engine.evaluateSource('item.price * item.qty', rowScope).asNumber,
        1000,
      );
      expect(
        engine.interpolate('{{ item.price * item.qty }}', rowScope),
        '1000',
      );
    });

    test('aggregates over a data set and row-relative aggregates', () {
      expect(engine.evaluateSource('SUM(items.total)', scope).asNumber, 3000);
      expect(engine.evaluateSource('COUNT(items)', scope).asNumber, 3);
      expect(engine.evaluateSource('MAX(items.total)', scope).asNumber, 1500);
      expect(engine.evaluateSource('AVG(items.total)', scope).asNumber, 1000);
      final ReportScope group = scope.copyWith(
        aggregateRows: rows.sublist(0, 2),
      );
      expect(engine.evaluateSource('SUM(item.total)', group).asNumber, 1500);
    });

    test('system values, variables, and formats', () {
      expect(
        engine.interpolate(
          '{{System.PageNumber}}/{{System.TotalPages}}',
          scope,
        ),
        '2/5',
      );
      expect(engine.interpolate('{{Variables.CompanyName}}', scope), 'Quds');
      expect(engine.interpolate('{{System.CurrentDate}}', scope), '2026/10/10');
      expect(
        engine.interpolate('{{ 1250.5 | currency:LYD }}', scope),
        '1,250.500 د.ل',
      );
      expect(
        engine.interpolate("{{TAFQEET(SUM(items.total), 'LYD')}}", scope),
        'فقط ثلاثة آلاف دينار ليبي لا غير',
      );
    });

    test('logic and null-safe arithmetic', () {
      expect(
        engine.interpolate(
          "{{ IF(SUM(items.total) > 2000, 'big', 'small') }}",
          scope,
        ),
        'big',
      );
      expect(engine.evaluateSource('10 / 0', scope).isNull, isTrue);
      expect(engine.evaluateSource("missing ?? 'x'", scope).displayText, 'x');
    });

    test('unknown functions are rejected', () {
      expect(
        () => engine.evaluateSource('NOPE(1)', scope),
        throwsA(isA<ReportExpressionException>()),
      );
    });
  });

  group('Template XML', () {
    test('parses the invoice template', () {
      final ReportParseResult result = QudsReportXmlParser().parse(invoiceXml);
      expect(result.hasErrors, isFalse, reason: result.diagnostics.join('\n'));
      final ReportTemplate t = result.template;
      expect(t.isRtl, isTrue);
      expect(t.bands.map((ReportBand b) => b.kind), <ReportBandKind>[
        ReportBandKind.reportHeader,
        ReportBandKind.pageHeader,
        ReportBandKind.detail,
        ReportBandKind.groupFooter,
        ReportBandKind.pageFooter,
        ReportBandKind.reportSummary,
      ]);
      expect(t.margins.left, closeTo(15 * 72 / 25.4, 0.01));
      final ReportTableElement table = t.detail!.elements
          .whereType<ReportTableElement>()
          .single;
      expect(table.columns.length, 5);
      expect(table.cells[3].format, 'currency:LYD');
      expect(table.cells[4].bold, isTrue);
      final ReportShapeElement line = t
          .band(ReportBandKind.reportHeader)!
          .elements
          .whereType<ReportShapeElement>()
          .single;
      expect(line.kind, ReportShapeKind.line);
      expect(line.width, closeTo(190 * 72 / 25.4, 0.01));
      expect(t.resolveColor('primary', ReportColor.black).hex, '1F4E78');
    });

    test('round-trips through the writer', () {
      final ReportTemplate first = QudsReportXmlParser()
          .parse(invoiceXml)
          .templateOrThrow;
      final String xml = const QudsReportXmlWriter().write(first);
      final ReportTemplate second = QudsReportXmlParser()
          .parse(xml)
          .templateOrThrow;
      expect(second.bands.length, first.bands.length);
      for (int i = 0; i < first.bands.length; i++) {
        expect(second.bands[i].kind, first.bands[i].kind);
        expect(second.bands[i].elements.length, first.bands[i].elements.length);
      }
      final ReportTableElement table = second.detail!.elements
          .whereType<ReportTableElement>()
          .single;
      expect(table.cells.map((ReportTableCell c) => c.field), <String>[
        'item.code',
        'item.description',
        'item.qty',
        'item.price',
        'item.total',
      ]);
    });

    test('mirrorRtl defaults on and round-trips when disabled', () {
      final QudsReportXmlParser parser = QudsReportXmlParser();
      expect(parser.parse(invoiceXml).templateOrThrow.mirrored, isTrue);
      final ReportTemplate flat = parser
          .parse(
            invoiceXml.replaceFirst(
              'isRtl="true"',
              'isRtl="true" mirrorRtl="false"',
            ),
          )
          .templateOrThrow;
      expect(flat.mirrored, isFalse);
      final String xml = const QudsReportXmlWriter().write(flat);
      expect(xml, contains('mirrorRtl="false"'));
      expect(parser.parse(xml).templateOrThrow.mirrored, isFalse);
    });

    test('mock data covers every binding and previews cleanly', () {
      final ReportTemplate t = QudsReportXmlParser()
          .parse(invoiceXml)
          .templateOrThrow;
      expect(ReportMockData.datasets(t), <String>['items']);
      expect(
        ReportMockData.rowFields(t),
        containsAll(<String>['code', 'description', 'qty', 'price', 'total']),
      );
      final Map<String, Object?> data = ReportMockData.infer(t, rows: 6);
      expect(data['invoiceNo'], 'INV-2026-001');
      final List<Object?> rows = data['items']! as List<Object?>;
      expect(rows, hasLength(6));
      final Map<String, Object?> second = rows[1]! as Map<String, Object?>;
      expect(
        second['total'],
        (second['qty']! as num) * (second['price']! as num),
      );
      final ReportDocumentLayout layout = QudsReportEngine(
        t,
        fonts: loadFonts(),
      ).layout(data);
      expect(layout.pages, isNotEmpty);
      expect(layout.warnings, isEmpty);
    });

    test('reports structural errors', () {
      final ReportParseResult r = QudsReportXmlParser().parse(
        '<QudsReport><Bands><GroupFooter height="10mm"/></Bands></QudsReport>',
      );
      expect(r.hasErrors, isTrue);
      expect(() => r.templateOrThrow, throwsA(isA<ReportTemplateException>()));
    });

    test('validate flags unknown functions', () {
      final QudsReportEngine engine = QudsReportEngine.fromXml(
        invoiceXml.replaceFirst(
          '{{SUM(items.total)}}',
          '{{TOTALIZE(items.total)}}',
        ),
      );
      final List<ReportDiagnostic> issues = engine.validate();
      expect(issues, hasLength(1));
      expect(issues.single.message, contains('TOTALIZE'));
      expect(invoiceEngine().validate(), isEmpty);
    });
  });

  group('Pagination', () {
    test('short invoice fits one page with header, footer, and summary', () {
      final ReportDocumentLayout layout = invoiceEngine().layout(
        invoiceData(3),
      );
      expect(layout.pages, hasLength(1));
      final List<String> texts = pageTexts(layout.pages.single);
      expect(texts, contains('شركة القدس للتقنية المتقدمة'));
      expect(texts, contains('التاريخ: 2026/10/10 (09:30)'));
      expect(texts, contains('فاتورة مبيعات رسمية - مرجع: INV-2026-001'));
      expect(texts, contains('الصفحة 1 من 1'));
      expect(texts, contains('1,500.000 د.ل'));
      expect(texts, contains('3000'));
      expect(
        texts,
        contains('المبلغ بالحروف: فقط ثلاثة آلاف دينار ليبي لا غير'),
      );
      expect(layout.warnings, isEmpty);
    });

    test('long invoice breaks pages and repeats headers', () {
      final ReportDocumentLayout layout = invoiceEngine().layout(
        invoiceData(80),
      );
      final int n = layout.pages.length;
      expect(n, greaterThan(2));
      final ReportTemplate t = layout.template;
      final double bodyBottom = t.pageHeight - t.margins.bottom;
      for (final ReportPageLayout page in layout.pages) {
        final List<String> texts = pageTexts(page);
        expect(texts, contains('فاتورة مبيعات رسمية - مرجع: INV-2026-001'));
        expect(texts, contains('الصفحة ${page.pageNumber} من $n'));
        expect(texts.where((String s) => s == 'الرمز'), hasLength(1));
        expect(
          texts.contains('شركة القدس للتقنية المتقدمة'),
          page.pageNumber == 1,
        );
        for (final ReportPrimitive p in page.primitives) {
          expect(p.bounds.bottom, lessThanOrEqualTo(bodyBottom + 0.5));
          expect(p.bounds.top, greaterThanOrEqualTo(t.margins.top - 0.5));
        }
      }
      final Set<String> codes = <String>{
        for (final ReportPageLayout page in layout.pages)
          for (final String s in pageTexts(page))
            if (RegExp(r'^P\d\d$').hasMatch(s)) s,
      };
      expect(codes, hasLength(80));
      final List<String> last = pageTexts(layout.pages.last);
      expect(
        last.any((String s) => s.startsWith('المبلغ بالحروف: فقط')),
        isTrue,
      );
    });

    test('rows stay ordered and table rows never overlap', () {
      final ReportDocumentLayout layout = invoiceEngine().layout(
        invoiceData(40),
      );
      final List<String> order = <String>[];
      for (final ReportPageLayout page in layout.pages) {
        final List<ReportTextPrimitive> codes = <ReportTextPrimitive>[
          for (final ReportPrimitive p in page.primitives)
            if (p is ReportTextPrimitive && RegExp(r'^P\d\d$').hasMatch(p.text))
              p,
        ];
        for (int i = 1; i < codes.length; i++) {
          expect(
            codes[i].bounds.top,
            greaterThanOrEqualTo(codes[i - 1].bounds.bottom - 0.01),
          );
        }
        order.addAll(codes.map((ReportTextPrimitive p) => p.text));
      }
      expect(order, <String>[
        for (int i = 1; i <= 40; i++) 'P${i.toString().padLeft(2, '0')}',
      ]);
    });

    test('grouping, sorting, and filtering with subtotals', () {
      const String xml = '''
<QudsReport name="Groups" pageSize="A5">
  <Bands>
    <GroupHeader height="8mm" groupBy="item.cat">
      <Text x="10mm" y="1mm" width="100mm" height="6mm">Group {{Group.Key}} ({{Group.Count}})</Text>
    </GroupHeader>
    <Detail dataSet="rows" rowHeight="6mm" sortBy="item.amount desc" filter="item.amount > 0">
      <Text x="10mm" y="0" width="60mm" height="6mm">{{item.name}}</Text>
    </Detail>
    <GroupFooter height="8mm">
      <Text x="10mm" y="1mm" width="100mm" height="6mm">Subtotal {{SUM(item.amount)}}</Text>
    </GroupFooter>
    <ReportSummary height="8mm">
      <Text x="10mm" y="1mm" width="100mm" height="6mm">Total {{SUM(rows.amount)}}</Text>
    </ReportSummary>
  </Bands>
</QudsReport>''';
      final ReportDocumentLayout layout = QudsReportEngine.fromXml(xml).layout(
        <String, Object?>{
          'rows': <Map<String, Object?>>[
            <String, Object?>{'name': 'a', 'cat': 'X', 'amount': 5},
            <String, Object?>{'name': 'b', 'cat': 'Y', 'amount': 7},
            <String, Object?>{'name': 'c', 'cat': 'X', 'amount': 9},
            <String, Object?>{'name': 'd', 'cat': 'Y', 'amount': 0},
          ],
        },
      );
      expect(pageTexts(layout.pages.single), <String>[
        'Group X (2)',
        'c',
        'a',
        'Subtotal 14',
        'Group Y (1)',
        'b',
        'Subtotal 7',
        'Total 21',
      ]);
    });

    test('RTL templates mirror element x from the right edge', () {
      ReportTextPrimitive company(String xml) {
        final ReportDocumentLayout layout = QudsReportEngine.fromXml(
          xml,
          clock: () => fixedNow,
        ).layout(invoiceData(1));
        return layout.pages.first.primitives
            .whereType<ReportTextPrimitive>()
            .firstWhere((ReportTextPrimitive p) => p.text.startsWith('شركة'));
      }

      const double mm = 72 / 25.4;
      final ReportTextPrimitive mirrored = company(invoiceXml);
      expect(mirrored.bounds.left, closeTo((210 - 10 - 110) * mm, 0.5));
      final ReportTextPrimitive literal = company(
        invoiceXml.replaceFirst(
          'isRtl="true"',
          'isRtl="true" mirrorRtl="false"',
        ),
      );
      expect(literal.bounds.left, closeTo(10 * mm, 0.5));
    });

    test('can-grow text pushes later elements down', () {
      const String xml = '''
<QudsReport name="Grow" pageSize="A4">
  <Bands>
    <ReportHeader height="20mm">
      <Text x="20mm" y="0" width="40mm" height="6mm">{{Data.long}}</Text>
      <Text x="20mm" y="8mm" width="40mm" height="6mm">after</Text>
    </ReportHeader>
  </Bands>
</QudsReport>''';
      final ReportDocumentLayout layout = QudsReportEngine.fromXml(xml).layout(
        <String, Object?>{'long': List<String>.filled(40, 'word').join(' ')},
      );
      final List<ReportTextPrimitive> texts = layout.pages.single.primitives
          .whereType<ReportTextPrimitive>()
          .toList();
      final ReportTextPrimitive grown = texts.first;
      final ReportTextPrimitive after = texts.last;
      expect(grown.shaped.lines.length, greaterThan(1));
      expect(
        after.bounds.top,
        greaterThanOrEqualTo(grown.bounds.bottom + 2 * 72 / 25.4 - 0.5),
      );
    });
  });

  group('Exports', () {
    test('PDF embeds fonts and extracts Arabic text', () async {
      final Uint8List pdf = await invoiceEngine().exportToPdf(invoiceData(5));
      expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
      expect(latin1.decode(pdf), contains('/FontFile2'));
      final String text = ArabicShaper.foldPresentation(
        PdfExtract.pageText(PdfFile.open(pdf), 0),
      );
      expect(text, contains('INV-2026-001'));
      // Extraction yields RTL runs in visual (painted) order.
      final String company = String.fromCharCodes(
        'شركة القدس'.runes.toList().reversed,
      );
      expect(text, contains(company));
      expect(text, contains('P01'));
    });

    test('Excel keeps numbers typed and the sheet right-to-left', () async {
      final Uint8List xlsx = await invoiceEngine().exportToExcel(
        invoiceData(4),
      );
      final List<List<String>> grid = XlsxGridReader.readSheet(xlsx);
      final int header = grid.indexWhere(
        (List<String> r) => r.contains('الرمز'),
      );
      expect(header, greaterThanOrEqualTo(0));
      expect(grid[header + 1].first, 'P01');
      expect(grid[header + 1][4], '500');
      final String sheet = partText(xlsx, '/xl/worksheets/sheet1.xml');
      expect(sheet, contains('rightToLeft="1"'));
      expect(sheet, contains('<v>1500</v>'));
      final String styles = partText(xlsx, '/xl/styles.xml');
      expect(styles, contains('د.ل'));
      expect(styles, contains('readingOrder="2"'));
      final List<String> flat = <String>[
        for (final List<String> r in grid) ...r,
      ];
      expect(flat, contains('شركة القدس للتقنية المتقدمة'));
    });

    test('Word has a repeating table header and live page fields', () async {
      final Uint8List docx = await invoiceEngine().exportToWord(invoiceData(4));
      final String doc = partText(docx, '/word/document.xml');
      expect(doc, contains('<w:tblHeader/>'));
      expect(doc, contains('<w:bidiVisual/>'));
      expect(doc, contains('شركة القدس للتقنية المتقدمة'));
      expect(doc, contains('1,500.000 د.ل'));
      for (final String part in <String>[
        '/word/document.xml',
        '/word/header1.xml',
        '/word/footer1.xml',
      ]) {
        for (final RegExpMatch cell in RegExp(
          '<w:tc>.*?</w:tc>',
          dotAll: true,
        ).allMatches(partText(docx, part))) {
          expect(cell.group(0), isNot(contains('<w:ind ')), reason: part);
        }
      }
      final String footer = partText(docx, '/word/footer1.xml');
      expect(footer, contains(' PAGE '));
      expect(footer, contains(' NUMPAGES '));
      expect(partText(docx, '/word/header1.xml'), contains('INV-2026-001'));
      final List<List<List<String>>> tables = DocxPlainReader.read(docx).tables;
      expect(
        tables.any(
          (List<List<String>> t) => t.isNotEmpty && t.first.contains('الرمز'),
        ),
        isTrue,
      );
    });
  });

  group('Charts', () {
    const String chartXml = '''
<QudsReport name="Charts" pageSize="A4" defaultFont="Liberation Sans">
  <Bands>
    <ReportHeader height="90mm">
      <Chart name="bars" x="10mm" y="0" width="120mm" height="60mm" chartType="bar" title="Sales {{Data.year}}" dataSet="Data.sales" category="Row.region" sortBy="value" sortOrder="desc" limit="3" showValues="true" valueFormat="n0">
        <Series name="Amount" value="Row.amount" color="#1F4E79"/>
        <Series name="Count" value="Row.amount"/>
      </Chart>
      <Chart name="pie" x="135mm" y="0" width="60mm" height="60mm" chartType="pie" showValues="true">
        <Point label="A" value="30" color="#FF0000"/>
        <Point label="B" value="10 + 10"/>
        <Point label="C" value="Data.extra"/>
      </Chart>
    </ReportHeader>
    <Detail dataSet="sales" height="6mm">
      <Text x="10mm" y="0" width="60mm" height="6mm">{{item.region}}</Text>
    </Detail>
  </Bands>
</QudsReport>''';

    Map<String, Object?> chartData() => <String, Object?>{
      'year': 2026,
      'extra': 50,
      'sales': <Map<String, Object?>>[
        <String, Object?>{'region': 'North', 'amount': 10},
        <String, Object?>{'region': 'South', 'amount': 40},
        <String, Object?>{'region': 'North', 'amount': 25},
        <String, Object?>{'region': 'East', 'amount': 5},
        <String, Object?>{'region': 'West', 'amount': 20},
      ],
    };

    QudsReportEngine chartEngine(String xml) => QudsReportEngine.fromXml(
      xml,
      fonts: loadFonts(),
      clock: () => fixedNow,
    );

    ReportFlowChart flowChart(ReportDocumentLayout layout, String id) {
      for (final ReportFlowEntry e in layout.flow) {
        if (e is ReportFlowBand) {
          for (final ReportFlowItem i in e.items) {
            if (i is ReportFlowChart && i.elementId == id) {
              return i;
            }
          }
        }
      }
      throw StateError('no chart $id');
    }

    String idOf(QudsReportEngine e, String name) => e.template.bands
        .expand((ReportBand b) => b.elements)
        .firstWhere((ReportElement el) => el.name == name)
        .id;

    test('parses series and points and round-trips through the writer', () {
      final QudsReportEngine engine = chartEngine(chartXml);
      expect(
        engine.diagnostics.where(
          (ReportDiagnostic d) => d.severity == ReportDiagnosticSeverity.error,
        ),
        isEmpty,
      );
      final ReportChartElement bars =
          engine.template.bands.first.elements.first as ReportChartElement;
      expect(bars.chartType, ReportChartType.bar);
      expect(bars.series.map((ReportChartSeries s) => s.name), <String>[
        'Amount',
        'Count',
      ]);
      expect(bars.sortBy, ReportChartSort.value);
      expect(bars.descending, isTrue);
      expect(bars.limit, 3);
      final QudsReportEngine again = chartEngine(engine.toXml());
      final ReportChartElement pie =
          again.template.bands.first.elements[1] as ReportChartElement;
      expect(pie.chartType, ReportChartType.pie);
      expect(pie.points.map((ReportChartPoint p) => p.value), <String>[
        '30',
        '10 + 10',
        'Data.extra',
      ]);
      expect(pie.points.first.color, '#FF0000');
      expect(again.toXml(), engine.toXml());
    });

    test('aggregates rows by category, sorts, and limits', () {
      final QudsReportEngine engine = chartEngine(chartXml);
      final ReportDocumentLayout layout = engine.layout(chartData());
      final ReportChartData bars = flowChart(layout, idOf(engine, 'bars')).data;
      expect(bars.title, 'Sales 2026');
      expect(bars.categories, <String>['South', 'North', 'West']);
      expect(bars.series.first.values, <double>[40, 35, 20]);
      final ReportChartData pie = flowChart(layout, idOf(engine, 'pie')).data;
      expect(pie.categories, <String>['A', 'B', 'C']);
      expect(pie.series.single.values, <double>[30, 20, 50]);
      expect(pie.pointColors.first, const ReportColor(0xFFFF0000));
    });

    test('average, count, and last aggregates', () {
      String xml(String aggregate) => chartXml.replaceFirst(
        'sortBy="value" sortOrder="desc" limit="3"',
        'aggregate="$aggregate"',
      );
      List<double> values(String aggregate) {
        final QudsReportEngine engine = chartEngine(xml(aggregate));
        return flowChart(
          engine.layout(chartData()),
          idOf(engine, 'bars'),
        ).data.series.first.values;
      }

      expect(values('avg'), <double>[17.5, 40, 5, 20]);
      expect(values('count'), <double>[2, 1, 1, 1]);
      expect(values('last'), <double>[25, 40, 5, 20]);
    });

    test('draws bars, wedges, and mirrored RTL plots', () {
      final QudsReportEngine engine = chartEngine(chartXml);
      final ReportPageLayout page = engine.layout(chartData()).pages.first;
      final String barsId = idOf(engine, 'bars');
      final String pieId = idOf(engine, 'pie');
      final List<ReportRectPrimitive> bars = <ReportRectPrimitive>[
        for (final ReportPrimitive p in page.primitives)
          if (p is ReportRectPrimitive &&
              p.elementId == barsId &&
              p.fill == const ReportColor(0xFF1F4E79) &&
              p.bounds.width > 10)
            p,
      ];
      expect(bars, hasLength(3));
      expect(bars.first.bounds.height, greaterThan(bars.last.bounds.height));
      final List<ReportPathPrimitive> wedges = <ReportPathPrimitive>[
        for (final ReportPrimitive p in page.primitives)
          if (p is ReportPathPrimitive && p.elementId == pieId) p,
      ];
      expect(wedges, hasLength(3));
      expect(wedges.every((ReportPathPrimitive w) => w.closed), isTrue);
      expect(
        page.primitives.whereType<ReportTextPrimitive>().map(
          (ReportTextPrimitive t) => t.text,
        ),
        containsAll(<String>['Sales 2026', '50%', '40']),
      );

      final QudsReportEngine rtl = chartEngine(
        chartXml.replaceFirst('name="Charts"', 'name="Charts" isRtl="true"'),
      );
      final String rtlBars = idOf(rtl, 'bars');
      final List<ReportRectPrimitive> mirrored = <ReportRectPrimitive>[
        for (final ReportPrimitive p
            in rtl.layout(chartData()).pages.first.primitives)
          if (p is ReportRectPrimitive &&
              p.elementId == rtlBars &&
              p.fill == const ReportColor(0xFF1F4E79) &&
              p.bounds.width > 10)
            p,
      ];
      expect(
        mirrored.first.bounds.left,
        greaterThan(mirrored.last.bounds.left),
      );
    });

    test('a chart crossing the page bottom moves to the next page whole', () {
      final String xml = chartXml
          .replaceFirst(
            '<ReportHeader height="90mm">',
            '<ReportHeader height="260mm">',
          )
          .replaceAll('y="0" width="120mm"', 'y="230mm" width="120mm"');
      final QudsReportEngine engine = chartEngine(xml);
      final ReportDocumentLayout layout = engine.layout(chartData());
      final String barsId = idOf(engine, 'bars');
      final List<int> pagesWithBars = <int>[
        for (final ReportPageLayout page in layout.pages)
          if (page.primitives.any((ReportPrimitive p) => p.elementId == barsId))
            page.pageNumber,
      ];
      expect(pagesWithBars, <int>[2]);
    });

    test('exports vector PDF paths and native Word / Excel charts', () async {
      final QudsReportEngine engine = chartEngine(chartXml);
      final Uint8List pdf = await engine.exportToPdf(chartData());
      expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');

      final Uint8List docx = await engine.exportToWord(chartData());
      final String doc = partText(docx, '/word/document.xml');
      expect(doc, contains('drawingml/2006/chart'));
      final String wordChart = partText(docx, '/word/charts/chart1.xml');
      expect(wordChart, contains('<c:barChart>'));
      expect(wordChart, contains('South'));
      expect(
        partText(docx, '/word/charts/chart2.xml'),
        contains('<c:pieChart>'),
      );

      final Uint8List xlsx = await engine.exportToExcel(chartData());
      final String sheet = partText(xlsx, '/xl/worksheets/sheet1.xml');
      expect(sheet, contains('<drawing r:id="rIdDrawing1"/>'));
      expect(
        partText(xlsx, '/xl/drawings/drawing1.xml'),
        contains('r:id="rIdChart2"'),
      );
      expect(partText(xlsx, '/xl/charts/chart1.xml'), contains('<c:barChart>'));
      final List<List<String>> grid = XlsxGridReader.readSheet(xlsx);
      final int header = grid.indexWhere(
        (List<String> r) => r.contains('Amount'),
      );
      expect(header, greaterThanOrEqualTo(0));
      expect(grid[header + 1], containsAllInOrder(<String>['South', '40']));
    });
  });

  group('Ready-made templates', () {
    for (final ReportTemplateInfo info in ReportTemplates.all) {
      test('${info.id} parses, validates, and exports', () async {
        final QudsReportEngine engine = QudsReportEngine.fromXml(
          info.xml,
          fonts: loadFonts(),
          clock: () => fixedNow,
        );
        final List<ReportDiagnostic> errors = <ReportDiagnostic>[
          for (final ReportDiagnostic d in <ReportDiagnostic>[
            ...engine.diagnostics,
            ...engine.validate(),
          ])
            if (d.severity == ReportDiagnosticSeverity.error) d,
        ];
        expect(errors, isEmpty);
        expect(engine.template.isRtl, info.rtl);
        final Map<String, Object?> data = info.sampleData();
        final ReportDocumentLayout layout = engine.layout(data);
        expect(layout.warnings, isEmpty);
        final List<String> texts = <String>[
          for (final ReportPageLayout p in layout.pages) ...pageTexts(p),
        ];
        expect(texts.where((String t) => t.contains('#ERR')), isEmpty);
        expect(
          ascii.decode((await engine.exportToPdf(data)).sublist(0, 5)),
          '%PDF-',
        );
        expect(await engine.exportToExcel(data), isNotEmpty);
        expect(await engine.exportToWord(data), isNotEmpty);
        expect(chartEngineRoundTrip(engine), engine.toXml());
      });
    }
  });

  group('Completion', () {
    final ReportTemplate t = QudsReportXmlParser().parse('''
<QudsReport name="C">
  <Variables><Variable name="title" value="Sales"/></Variables>
  <Bands><Detail dataSet="items" height="8mm"/></Bands>
</QudsReport>''').templateOrThrow;
    final ReportCompleter c = ReportCompleter(
      template: t,
      band: t.band(ReportBandKind.detail),
      data: <String, Object?>{
        'customer': 'Ali',
        'seller': <String, Object?>{'name': 'Quds', 'phone': '091'},
        'items': <Object?>[
          <String, Object?>{'name': 'Pen', 'qty': 2, 'price': 5.5},
        ],
      },
    );
    List<String> inserts(ReportCompletionResult? r) => <String>[
      for (final ReportCompletionItem i in r!.items) i.insert,
    ];

    test('roots after {{ and nothing outside bindings', () {
      final ReportCompletionResult? r = c.complete('Hi {{', 5);
      expect(
        inserts(r),
        containsAll(<String>['item', 'Data', 'System', 'Variables', 'SUM()']),
      );
      expect(c.complete('{{a}} b', 7), isNull);
      expect(c.complete('plain', 3), isNull);
      expect(c.complete('{{item.qty * ', 13), isNull);
      expect(c.complete('{{item.qty * ', 13, force: true), isNotNull);
    });

    test('fields come from rows and records of the data', () {
      final ReportCompletionResult? r = c.complete('{{item.q', 8);
      expect(inserts(r).first, 'qty');
      expect(r!.start, 7);
      expect(inserts(c.complete('{{Data.seller.', 14)), <String>[
        'name',
        'phone',
      ]);
      expect(inserts(c.complete('{{items.', 8)), contains('price'));
      expect(inserts(c.complete('{{System.Pa', 11)).first, 'PageNumber');
      expect(inserts(c.complete('{{Variables.', 12)), <String>['title']);
      expect(
        inserts(c.complete('item.', 5, expression: true)),
        contains('qty'),
      );
    });

    test('functions insert parentheses with the caret inside', () {
      const String text = '{{SU';
      final ReportCompletionResult r = c.complete(text, 4)!;
      final ReportCompletionItem sum = r.items.first;
      expect(sum.insert, 'SUM()');
      final (String out, int caret) = r.apply(text, sum);
      expect(out, '{{SUM()');
      expect(caret, 6);
    });

    test('formats after | and currencies inside TAFQEET', () {
      expect(
        inserts(c.complete('{{item.price | cur', 18)),
        containsAll(<String>['currency:LYD', 'currencyCode:USD']),
      );
      expect(
        inserts(c.complete('{{x | currency:E', 16)),
        contains('currency:EGP'),
      );
      expect(inserts(c.complete("{{TAFQEET(1, 'L", 15)), contains('LYD'));
      expect(c.complete("{{UPPER('L", 10), isNull);
      expect(c.complete('{{a || b', 8), isNull);
    });
  });

  group('Template variables', () {
    const String xml = r'''<QudsReport name="Vars">
  <Variables>
    <Var name="company" value="Quds Co"/>
    <Var name="rate" type="number" value="0.15" format="percent" description="VAT rate"/>
    <Var name="showNotes" type="boolean" value="yes"/>
    <Var name="issued" type="date" value="2026-03-05" format="date:dd/MM/yyyy"/>
    <Var name="regions" type="list" value="North; South; 30"/>
    <Var name="total" type="expression" value="SUM(Data.items.amount)"/>
    <Var name="tax" type="expression" value="Variables.total * Variables.rate"/>
    <Var name="greeting" value="Hello {{Data.customer}}"/>
  </Variables>
  <Bands>
    <ReportHeader height="60mm">
      <Text x="0" y="0" width="150mm" height="6mm">{{Variables.company}}|{{Variables.rate | percent}}|{{IF(Variables.showNotes, 'notes', 'none')}}</Text>
      <Text x="0" y="8mm" width="150mm" height="6mm">{{Variables.issued | date:dd/MM/yyyy}}|{{COUNT(Variables.regions)}}|{{Variables.tax | n2}}</Text>
      <Text x="0" y="16mm" width="150mm" height="6mm">{{Variables.greeting}}|{{YEAR(Variables.issued)}}</Text>
    </ReportHeader>
  </Bands>
</QudsReport>''';
    final Map<String, Object?> data = <String, Object?>{
      'customer': 'Ali',
      'items': <Object?>[
        <String, Object?>{'amount': 100},
        <String, Object?>{'amount': 300},
      ],
    };

    test('typed values evaluate in order and round-trip', () {
      final QudsReportEngine engine = QudsReportEngine.fromXml(
        xml,
        fonts: loadFonts(),
      );
      expect(engine.validate(), isEmpty);
      final List<ReportVariable> vars = engine.template.variables;
      expect(vars.map((ReportVariable v) => v.type), <ReportVariableType>[
        ReportVariableType.text,
        ReportVariableType.number,
        ReportVariableType.boolean,
        ReportVariableType.date,
        ReportVariableType.list,
        ReportVariableType.expression,
        ReportVariableType.expression,
        ReportVariableType.text,
      ]);
      expect(vars[1].placeholder, '{{Variables.rate | percent}}');
      expect(vars[1].description, 'VAT rate');
      expect(vars[4].listItems, <String>['North', 'South', '30']);
      final List<String> texts = pageTexts(engine.layout(data).pages.first);
      expect(texts, contains('Quds Co|15%|notes'));
      expect(texts, contains('05/03/2026|3|60.00'));
      expect(texts, contains('Hello Ali|2026'));
      final String again = QudsReportEngine.fromXml(engine.toXml()).toXml();
      expect(again, engine.toXml());
      expect(engine.toXml(), contains('type="expression"'));
    });

    test('host values override and invalid literals are reported', () {
      final QudsReportEngine engine = QudsReportEngine.fromXml(
        xml,
        fonts: loadFonts(),
        variables: <String, Object?>{'company': 'Host Ltd', 'rate': 0.2},
      );
      final List<String> texts = pageTexts(engine.layout(data).pages.first);
      expect(texts, contains('Host Ltd|20%|notes'));
      expect(texts, contains('05/03/2026|3|80.00'));

      final ReportParseResult bad = QudsReportXmlParser().parse(
        '<QudsReport><Variables>'
        '<Var name="n" type="number" value="abc"/>'
        '<Var name="d" type="date" value="31-31-2026"/>'
        '<Var name="x" type="weird" value="1"/>'
        '</Variables><Bands><Detail height="5mm"/></Bands></QudsReport>',
      );
      final List<String> messages = <String>[
        for (final ReportDiagnostic d in bad.diagnostics) d.toString(),
      ];
      expect(
        messages.where((String m) => m.contains('not a number')),
        hasLength(1),
      );
      expect(
        messages.where((String m) => m.contains('not a valid date')),
        hasLength(1),
      );
      expect(
        messages.where((String m) => m.contains('Unknown variable type')),
        hasLength(1),
      );
    });
  });
}

String chartEngineRoundTrip(QudsReportEngine engine) =>
    QudsReportEngine.fromXml(engine.toXml()).toXml();
