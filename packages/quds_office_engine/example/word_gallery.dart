import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart';

WmlParagraph _runPara(
  String text, {
  WmlJustification align = WmlJustification.left,
  bool bold = false,
  bool italic = false,
  WmlUnderline underline = WmlUnderline.none,
  bool strike = false,
  String color = '222222',
  String? highlight,
  int size = 22,
  String? listLabel,
  double after = 8,
  bool pageBreak = false,
}) {
  return WmlParagraph(
    properties: WmlParagraphProps(
      justification: align,
      spacingAfter: after,
      spacingBefore: bold && size >= 28 ? 12 : 0,
      listLabel: listLabel,
      pageBreakBefore: pageBreak,
    ),
    inlines: <WmlInline>[
      WmlRun(
        text: text,
        properties: WmlRunProps(
          bold: bold,
          italic: italic,
          underline: underline,
          strike: strike,
          color: color,
          highlight: highlight,
          fontSizeHalfPoints: size,
        ),
      ),
    ],
  );
}

WmlTableCell _cell(String text, {bool header = false, String? fill}) {
  return WmlTableCell(
    fillColor: fill ?? (header ? '2B579A' : 'FFFFFF'),
    blocks: <WmlBlock>[
      WmlParagraph(
        inlines: <WmlInline>[
          WmlRun(
            text: text,
            properties: WmlRunProps(
              bold: header,
              color: header ? 'FFFFFF' : '222222',
              fontSizeHalfPoints: 20,
            ),
          ),
        ],
      ),
    ],
  );
}

/// In-memory Word model: bilingual briefing with chrome, table, and visuals.
WmlDocument engineBriefing() {
  return WmlDocument(
    sections: <WmlSection>[
      WmlSection(
        header: <WmlParagraph>[
          _runPara(
            'Quds Office Engine  ·  Word gallery',
            italic: true,
            size: 18,
            color: '595959',
            after: 0,
          ),
        ],
        footer: <WmlParagraph>[
          WmlParagraph(
            properties: WmlParagraphProps(
              justification: WmlJustification.center,
              pageNumberField: true,
            ),
          ),
        ],
        blocks: <WmlBlock>[
          _runPara(
            'Print-faithful Office documents',
            bold: true,
            size: 36,
            color: '1F4E79',
          ),
          _runPara(
            'This briefing is built from WmlDocument, laid out by WordLayoutEngine, '
            'serialized to DOCX, then compiled to PDF 1.7 — the same path the editor uses.',
          ),
          _runPara(
            'يولد المحرك ملفاً ثنائي اللغة: عناوين، قوائم، جداول، صور ورسوم، ثم يصدّرها للطباعة.',
            align: WmlJustification.right,
          ),
          WmlVisual(
            visual: OfficeVisual(
              kind: OfficeVisualKind.picture,
              title: 'Studio card',
              imageBytes: PngBytes.studioCard(),
              width: 300,
              height: 150,
            ),
          ),
          _runPara(
            'What the layout keeps',
            bold: true,
            size: 28,
            color: '1F4E79',
          ),
          _runPara('Headers and footers with a PAGE field', listLabel: '1. '),
          _runPara(
            'Run styles: bold, italic, underline, strike, highlight',
            listLabel: '2. ',
          ),
          WmlParagraph(
            properties: WmlParagraphProps(spacingAfter: 10, listLabel: '3. '),
            inlines: <WmlInline>[
              WmlRun(
                text: 'Bold',
                properties: WmlRunProps(bold: true, fontSizeHalfPoints: 22),
              ),
              WmlRun(text: ' · '),
              WmlRun(
                text: 'italic',
                properties: WmlRunProps(italic: true, fontSizeHalfPoints: 22),
              ),
              WmlRun(text: ' · '),
              WmlRun(
                text: 'double',
                properties: WmlRunProps(
                  underline: WmlUnderline.double,
                  fontSizeHalfPoints: 22,
                ),
              ),
              WmlRun(text: ' · '),
              WmlRun(
                text: 'dotted',
                properties: WmlRunProps(
                  underline: WmlUnderline.dotted,
                  fontSizeHalfPoints: 22,
                ),
              ),
              WmlRun(text: ' · '),
              WmlRun(
                text: 'strike',
                properties: WmlRunProps(strike: true, fontSizeHalfPoints: 22),
              ),
              WmlRun(text: ' · '),
              WmlRun(
                text: 'mark',
                properties: WmlRunProps(
                  highlight: 'yellow',
                  fontSizeHalfPoints: 22,
                ),
              ),
            ],
          ),
          WmlTable(
            grid: <double>[150, 90, 90, 90],
            rows: <WmlTableRow>[
              WmlTableRow(
                cells: <WmlTableCell>[
                  _cell('Surface', header: true),
                  _cell('Pages', header: true),
                  _cell('RTL', header: true),
                  _cell('PDF', header: true),
                ],
              ),
              WmlTableRow(
                cells: <WmlTableCell>[
                  _cell('Word'),
                  _cell('Section'),
                  _cell('Yes'),
                  _cell('fromWord'),
                ],
              ),
              WmlTableRow(
                cells: <WmlTableCell>[
                  _cell('Excel', fill: 'F2F2F2'),
                  _cell('Sheet', fill: 'F2F2F2'),
                  _cell('Headings', fill: 'F2F2F2'),
                  _cell('fromWorkbook', fill: 'F2F2F2'),
                ],
              ),
              WmlTableRow(
                cells: <WmlTableCell>[
                  _cell('PowerPoint'),
                  _cell('Slide'),
                  _cell('Wrap'),
                  _cell('fromPresentation'),
                ],
              ),
            ],
          ),
          WmlVisual(
            visual: OfficeVisual(
              kind: OfficeVisualKind.chartColumn,
              title: 'Export mix',
              points: OfficeVisual.sampleSeries(),
              width: 400,
              height: 170,
            ),
          ),
          WmlVisual(
            visual: OfficeVisual(
              kind: OfficeVisualKind.diagramProcess,
              title: 'Pipeline',
              points: OfficeVisual.sampleSteps(),
              width: 420,
              height: 120,
            ),
          ),
          _runPara(
            'Appendix — second physical page',
            bold: true,
            size: 28,
            color: '1F4E79',
            pageBreak: true,
          ),
          _runPara(
            'Page breaks, list markers, and visuals stay in the PDF in the same '
            'order as the laid-out pages.',
          ),
          _runPara(
            'الملحق يؤكد أن رقم الصفحة في التذييل يزيد مع كل صفحة مطبوعة.',
            align: WmlJustification.right,
          ),
        ],
      ),
      WmlSection(
        columnCount: 2,
        columnSpace: 24,
        columnSep: true,
        header: <WmlParagraph>[
          _runPara(
            'Quds Office Engine  ·  Columns',
            italic: true,
            size: 18,
            color: '595959',
            after: 0,
          ),
        ],
        blocks: <WmlBlock>[
          WmlFrame(
            x: 72,
            y: 56,
            width: 200,
            height: 44,
            fillColor: '1F4E79',
            blocks: <WmlBlock>[
              _runPara(
                'COLUMNS + FRAME',
                bold: true,
                size: 20,
                color: 'FFFFFF',
                after: 0,
              ),
            ],
          ),
          _runPara(
            'Newspaper columns fill the first column, then the next, then a new page. '
            'This is the same w:cols model Word serializes on the section.',
            pageBreak: true,
          ),
          _runPara(
            'Absolute frames sit on the page independently of the story. Use them for '
            'cover bands, callouts, and logos that must not reflow with the body.',
          ),
          _runPara(
            'A column break jumps to the next column on the same page. The gutter and '
            'optional separator come from w:space and w:sep.',
            pageBreak: false,
          ),
          WmlParagraph(
            properties: WmlParagraphProps(
              columnBreakBefore: true,
              spacingAfter: 8,
            ),
            inlines: <WmlInline>[
              WmlRun(
                text:
                    'This paragraph starts in column two because of a column break. '
                    'Tables and pictures that follow stay inside the current column width.',
                properties: WmlRunProps(fontSizeHalfPoints: 22),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// High-level DocxDocumentBuilder: chrome, lists, image, charts, hyperlink.
Uint8List builderReport() {
  final Uint8List card = PngBytes.studioCard(width: 320, height: 160);
  return (DocxDocumentBuilder(theme: OfficeDocumentTheme.light())
        ..header(left: 'Quds Office', center: 'Builder report', date: true)
        ..footer(left: 'example/word', pageNumber: true)
        ..heading('Styled Word package')
        ..paragraph(
          'DocxDocumentBuilder emits a full OPC package: numbering, comments, '
          'header/footer stories, DrawingML charts, and a contain-fitted picture.',
        )
        ..note('Open this .docx in Word, then compare the sibling .pdf.')
        ..bookmark('overview')
        ..bulletList(<String>[
          'Theme colors on headings and table bands',
          'Comments attached to a paragraph',
          'Hyperlink to the public schema site',
        ])
        ..numberedList(<String>[
          'Build the OPC archive',
          'Round-trip with WordDeserializer when needed',
          'Compile PDF with OfficePdfExport.fromBytes',
        ], start: 1)
        ..heading('Release matrix', level: 2)
        ..table(<List<String>>[
          <String>['Channel', 'Word', 'Excel', 'PowerPoint'],
          <String>[
            'Engine model',
            'WmlDocument',
            'SmlWorkbook',
            'PmlPresentation',
          ],
          <String>[
            'Fluent builder',
            'DocxDocumentBuilder',
            'XlsxWorkbookBuilder',
            'PptxDeckBuilder',
          ],
          <String>['PDF entry', 'fromWord', 'fromWorkbook', 'fromPresentation'],
        ])
        ..horizontalRule()
        ..image(card, caption: 'Figure 1 — generated studio card (PNG)')
        ..pieChart(
          title: 'Format share',
          series: const <ChartPoint>[
            ChartPoint(label: 'DOCX', value: 40, color: '2B579A'),
            ChartPoint(label: 'XLSX', value: 35, color: '217346'),
            ChartPoint(label: 'PPTX', value: 25, color: 'B7472A'),
          ],
        )
        ..caption('Figure 2 — pie chart part inside the package')
        ..lineChart(
          title: 'Pages compiled',
          series: const <ChartSeries>[
            ChartSeries(
              name: 'PDF pages',
              points: <ChartPoint>[
                ChartPoint(label: 'Mon', value: 4),
                ChartPoint(label: 'Tue', value: 7),
                ChartPoint(label: 'Wed', value: 6),
                ChartPoint(label: 'Thu', value: 9),
                ChartPoint(label: 'Fri', value: 11),
              ],
            ),
          ],
        )
        ..hyperlink(
          'ECMA-376',
          'https://www.ecma-international.org/publications-and-standards/standards/ecma-376/',
        )
        ..pageBreak()
        ..heading('Closing', level: 2)
        ..paragraph(
          'The PDF next to this file is compiled from the same bytes, not from a screenshot.',
          comments: <String>['Export uses OfficePdfExport.fromBytes.'],
        ))
      .build();
}

/// Short letter with running header/footer — a third Word shape.
Uint8List formalLetter() {
  return (DocxDocumentBuilder()
        ..header(left: 'Quds Office Suite', right: 'Correspondence')
        ..footer(center: 'Confidential when printed', pageNumber: true)
        ..heading('Release notes')
        ..paragraph('Dear reviewer,')
        ..paragraph(
          'Please find three Word packages in this gallery: an engine-model '
          'briefing (layout + visuals), a builder report (OPC features), and '
          'this letter (header/footer only). Each file has a PDF twin.',
        )
        ..bulletList(<String>[
          'docx — open in Microsoft Word or LibreOffice Writer',
          'pdf — print layout from OfficePdfExport',
        ])
        ..spacer()
        ..paragraph('Regards,', italic: true)
        ..paragraph('The engine example', bold: true))
      .build();
}
