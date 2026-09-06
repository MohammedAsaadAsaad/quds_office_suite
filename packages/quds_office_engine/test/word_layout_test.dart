import 'package:quds_office_engine/quds_office_engine.dart';
import 'package:test/test.dart';

void main() {
  test('table cells are laid out in columns, not stacked', () {
    final WmlDocument doc = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            WmlTable(
              grid: <double>[140, 140],
              rows: <WmlTableRow>[
                WmlTableRow(
                  cells: <WmlTableCell>[
                    WmlTableCell(
                      fillColor: '1F4E79',
                      blocks: <WmlBlock>[
                        WmlParagraph(
                          inlines: <WmlInline>[WmlRun(text: 'Left')],
                        ),
                      ],
                    ),
                    WmlTableCell(
                      blocks: <WmlBlock>[
                        WmlParagraph(
                          inlines: <WmlInline>[WmlRun(text: 'Right')],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    expect(laid.pages, isNotEmpty);
    final List<LaidOutLine> lines = laid.pages.first.lines;
    expect(lines.length, 2);
    expect(lines[1].x, greaterThan(lines[0].x + 40));
    expect((lines[1].y - lines[0].y).abs(), lessThan(1));
    expect(laid.pages.first.frames.length, 2);
    expect(laid.pages.first.frames.first.fillColor, '1F4E79');
    expect(laid.pages.first.frames[0].paragraphIndex, 0);
    expect(laid.pages.first.frames[1].paragraphIndex, 1);
    expect(lines[0].paragraphIndex, 0);
    expect(lines[1].paragraphIndex, 1);
  });

  test('RTL table paints the first logical column on the right', () {
    final WmlDocument doc = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            WmlTable(
              grid: <double>[140, 140],
              properties: WmlTableProps(rightToLeft: true),
              rows: <WmlTableRow>[
                WmlTableRow(
                  cells: <WmlTableCell>[
                    WmlTableCell(
                      blocks: <WmlBlock>[
                        WmlParagraph(
                          inlines: <WmlInline>[WmlRun(text: 'يمين')],
                        ),
                      ],
                    ),
                    WmlTableCell(
                      blocks: <WmlBlock>[
                        WmlParagraph(
                          inlines: <WmlInline>[WmlRun(text: 'يسار')],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    final List<LaidOutBox> frames = laid.pages.first.frames;
    expect(frames.length, 2);
    expect(frames[0].tableCol, 0);
    expect(frames[1].tableCol, 1);
    expect(frames[0].x, greaterThan(frames[1].x));
    final List<LaidOutLine> lines = laid.pages.first.lines;
    expect(lines[0].x, greaterThan(lines[1].x));
  });

  test('superscript and subscript shrink and shift the baseline', () {
    final WmlDocument doc = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            WmlParagraph(
              inlines: <WmlInline>[
                WmlRun(
                  text: 'H',
                  properties: WmlRunProps(fontSizeHalfPoints: 22),
                ),
                WmlRun(
                  text: '2',
                  properties: WmlRunProps(
                    fontSizeHalfPoints: 22,
                    vertAlign: WmlVertAlign.subscript,
                  ),
                ),
                WmlRun(
                  text: 'O',
                  properties: WmlRunProps(fontSizeHalfPoints: 22),
                ),
                WmlRun(
                  text: 'x',
                  properties: WmlRunProps(
                    fontSizeHalfPoints: 22,
                    vertAlign: WmlVertAlign.superscript,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final List<LaidOutGlyph> glyphs = WordLayoutEngine(font: null)
        .layout(doc)
        .pages
        .first
        .lines
        .expand((LaidOutLine line) => line.glyphs)
        .toList();
    expect(glyphs.length, 4);
    expect(glyphs[0].fontSize, 11);
    expect(glyphs[0].vertAlign, WmlVertAlign.baseline);
    expect(glyphs[1].vertAlign, WmlVertAlign.subscript);
    expect(glyphs[1].fontSize, closeTo(11 * 0.65, 0.01));
    expect(glyphs[1].y, greaterThan(glyphs[0].y));
    expect(glyphs[3].vertAlign, WmlVertAlign.superscript);
    expect(glyphs[3].fontSize, closeTo(11 * 0.65, 0.01));
    expect(glyphs[3].y, lessThan(glyphs[0].y));
  });

  test('full-page pictures paginate flush to the page', () {
    final WmlPageSize a4 = WmlPageSize.a4();
    final WmlDocument doc = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          pageSize: a4,
          margins: const WmlPageMargins(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
          ),
          blocks: <WmlBlock>[
            for (int i = 0; i < 3; i++)
              WmlVisual(
                visual: OfficeVisual(
                  kind: OfficeVisualKind.picture,
                  title: 'Page $i',
                  width: a4.width,
                  height: a4.height,
                ),
              ),
          ],
        ),
      ],
    );
    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    expect(laid.pages.length, 3);
    for (final LaidOutPage page in laid.pages) {
      expect(page.frames.length, 1);
      expect(page.frames.first.x, 0);
      expect(page.frames.first.y, 0);
      expect(page.frames.first.width, closeTo(a4.width, 0.01));
      expect(page.frames.first.height, closeTo(a4.height, 0.01));
    }
  });

  test('section columns fill left then right on the same page', () {
    final WmlDocument doc = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          columnCount: 2,
          columnSpace: 20,
          blocks: <WmlBlock>[
            for (int i = 0; i < 40; i++)
              WmlParagraph(
                properties: WmlParagraphProps(spacingAfter: 4),
                inlines: <WmlInline>[
                  WmlRun(
                    text: 'Column line $i with enough words to wrap a bit.',
                    properties: WmlRunProps(fontSizeHalfPoints: 22),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    expect(laid.pages, isNotEmpty);
    final LaidOutPage first = laid.pages.first;
    final double mid = first.width / 2;
    final bool hasLeft = first.lines.any((LaidOutLine line) => line.x < mid);
    final bool hasRight = first.lines.any((LaidOutLine line) => line.x > mid);
    expect(hasLeft, isTrue);
    expect(hasRight, isTrue);
  });

  test('column break moves the next paragraph to the second column', () {
    final WmlDocument doc = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          columnCount: 2,
          blocks: <WmlBlock>[
            WmlParagraph(
              inlines: <WmlInline>[WmlRun(text: 'Left column')],
            ),
            WmlParagraph(
              properties: WmlParagraphProps(columnBreakBefore: true),
              inlines: <WmlInline>[WmlRun(text: 'Right column')],
            ),
          ],
        ),
      ],
    );
    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    final List<LaidOutLine> lines = laid.pages.first.lines
        .where((LaidOutLine line) => line.sourceText == null)
        .toList();
    expect(lines.length, greaterThanOrEqualTo(2));
    expect(lines[1].x, greaterThan(lines[0].x + 40));
    expect((lines[1].y - lines[0].y).abs(), lessThan(8));
  });

  test('absolute frames do not advance the story and keep inner text', () {
    final WmlDocument doc = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            WmlFrame(
              x: 80,
              y: 120,
              width: 180,
              height: 80,
              fillColor: '1F4E79',
              blocks: <WmlBlock>[
                WmlParagraph(
                  inlines: <WmlInline>[WmlRun(text: 'Callout')],
                ),
              ],
            ),
            WmlParagraph(
              inlines: <WmlInline>[WmlRun(text: 'Body after frame')],
            ),
          ],
        ),
      ],
    );
    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    expect(laid.pages.length, 1);
    final LaidOutBox frame = laid.pages.first.frames.firstWhere(
      (LaidOutBox box) => box.kind == LaidOutBoxKind.frame,
    );
    expect(frame.x, 80);
    expect(frame.y, 120);
    expect(frame.fillColor, '1F4E79');
    final LaidOutLine body = laid.pages.first.lines.last;
    expect(body.y, lessThan(100));
    expect(
      laid.pages.first.lines.any(
        (LaidOutLine line) =>
            line.glyphs.isNotEmpty && line.x >= 80 && line.y >= 120,
      ),
      isTrue,
    );
  });

  test('layout keeps global paragraph indices across sections', () {
    final WmlDocument doc = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'One')]),
          ],
        ),
        WmlSection(
          pageSize: const WmlPageSize(width: 400, height: 500),
          blocks: <WmlBlock>[
            WmlParagraph(inlines: <WmlInline>[WmlRun(text: 'Two')]),
          ],
        ),
      ],
    );
    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(doc);
    expect(laid.pages.length, greaterThanOrEqualTo(2));
    expect(laid.pages.first.sectionIndex, 0);
    expect(laid.pages.last.sectionIndex, 1);
    expect(laid.pages.first.lines.first.paragraphIndex, 0);
    expect(laid.pages.last.lines.first.paragraphIndex, 1);
    expect(laid.pages.last.height, 500);
    expect(
      laid.pageStackTop(1, 1),
      greaterThan(laid.pages.first.height),
    );
  });

  test('explicit paragraph bidi sets the layout base level', () {
    expect(WmlParagraphProps(rightToLeft: true).bidiBaseLevel, 1);
    expect(WmlParagraphProps(rightToLeft: false).bidiBaseLevel, 0);
    expect(
      WmlParagraphProps(justification: WmlJustification.right).bidiBaseLevel,
      1,
    );
    expect(WmlParagraphProps().bidiBaseLevel, isNull);

    final WmlDocument rtl = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            WmlParagraph(
              properties: WmlParagraphProps(
                rightToLeft: true,
                justification: WmlJustification.right,
              ),
              inlines: <WmlInline>[WmlRun(text: 'Hello')],
            ),
          ],
        ),
      ],
    );
    final LaidOutDocument laid = WordLayoutEngine(font: null).layout(rtl);
    expect(laid.pages, isNotEmpty);
    expect(laid.pages.first.lines, isNotEmpty);
    expect(laid.pages.first.lines.first.justification, WmlJustification.right);
  });
}
