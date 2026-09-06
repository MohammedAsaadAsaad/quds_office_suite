import '../../opc/ole/embedded_part.dart';
import '../../opc/opc_archive.dart';
import '../../visual/office_visual.dart';
import '../math/omml_document.dart';
import '../properties/wml_properties.dart';

sealed class WmlBlock {
  WmlBlock();
}

sealed class WmlInline {
  WmlInline();
}

class WmlRun extends WmlInline {
  WmlRun({
    this.text = '',
    WmlRunProps? properties,
    this.hyperlink,
    List<int>? commentIds,
  })  : properties = properties ?? WmlRunProps(),
        commentIds = commentIds ?? <int>[];

  String text;
  WmlRunProps properties;
  WmlHyperlink? hyperlink;
  List<int> commentIds;
}

class WmlComment {
  WmlComment({
    required this.id,
    this.author = 'Quds Office',
    this.initials = 'QO',
    this.dateIso = '',
    String text = '',
    List<WmlParagraph>? paragraphs,
    List<WmlVisual>? visuals,
    this.parentId,
    this.resolved = false,
  })  : paragraphs = paragraphs ??
            <WmlParagraph>[
              WmlParagraph(
                inlines: <WmlInline>[WmlRun(text: text)],
              ),
            ],
        visuals = visuals ?? <WmlVisual>[];

  int id;
  String author;
  String initials;
  String dateIso;
  List<WmlParagraph> paragraphs;
  List<WmlVisual> visuals;
  int? parentId;
  bool resolved;

  bool get isReply => parentId != null;

  String get text {
    final StringBuffer buffer = StringBuffer();
    for (final WmlParagraph paragraph in paragraphs) {
      final String line = paragraph.text;
      if (line.isEmpty) {
        continue;
      }
      if (buffer.isNotEmpty) {
        buffer.write('\n');
      }
      buffer.write(line);
    }
    return buffer.toString();
  }

  set text(String value) {
    final WmlRunProps props = paragraphs.isEmpty
        ? WmlRunProps(fontSizeHalfPoints: 20)
        : (paragraphs.first.inlines.whereType<WmlRun>().firstOrNull?.properties
                .copy() ??
            WmlRunProps(fontSizeHalfPoints: 20));
    paragraphs
      ..clear()
      ..add(
        WmlParagraph(
          inlines: <WmlInline>[WmlRun(text: value, properties: props)],
        ),
      );
  }

  WmlComment copy() => WmlComment(
        id: id,
        author: author,
        initials: initials,
        dateIso: dateIso,
        paragraphs: <WmlParagraph>[
          for (final WmlParagraph paragraph in paragraphs)
            WmlParagraph(
              properties: paragraph.properties,
              inlines: <WmlInline>[
                for (final WmlInline inline in paragraph.inlines)
                  if (inline is WmlRun)
                    WmlRun(
                      text: inline.text,
                      properties: inline.properties.copy(),
                      hyperlink: inline.hyperlink,
                      commentIds: List<int>.from(inline.commentIds),
                    )
                  else
                    inline,
              ],
            ),
        ],
        visuals: <WmlVisual>[
          for (final WmlVisual visual in visuals)
            WmlVisual(visual: visual.visual.copy()),
        ],
        parentId: parentId,
        resolved: resolved,
      );
}

/// Office-style hyperlink: heading/bookmark, web URL, or local file.
class WmlHyperlink {
  const WmlHyperlink({this.anchor, this.url, this.file});

  /// Internal bookmark or heading target (`w:anchor`).
  final String? anchor;
  final String? url;
  final String? file;

  bool get isInternal => anchor != null && anchor!.isNotEmpty;

  bool get isWeb {
    final String? value = url;
    if (value == null || value.isEmpty) {
      return false;
    }
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('mailto:');
  }

  bool get isFile => file != null && file!.isNotEmpty;

  String get displayTarget => url ?? file ?? anchor ?? '';

  WmlHyperlink copy() =>
      WmlHyperlink(anchor: anchor, url: url, file: file);

  static WmlHyperlink? fromTarget(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    if (value.startsWith('#')) {
      return WmlHyperlink(anchor: value.substring(1));
    }
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('mailto:')) {
      return WmlHyperlink(url: value);
    }
    if (value.startsWith('file:') ||
        value.startsWith('/') ||
        value.contains('\\') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value)) {
      return WmlHyperlink(file: value);
    }
    return WmlHyperlink(anchor: value);
  }
}

class WmlBreak extends WmlInline {
  WmlBreak(this.type);

  final WmlBreakType type;
}

class WmlObject extends WmlInline {
  WmlObject({
    required this.relationshipId,
    this.embedded,
    this.width = 200,
    this.height = 120,
  });

  String relationshipId;
  IsolatedEmbeddedPackage? embedded;
  double width;
  double height;
}

class WmlParagraph extends WmlBlock {
  WmlParagraph({
    List<WmlInline>? inlines,
    WmlParagraphProps? properties,
  })  : inlines = inlines ?? <WmlInline>[],
        properties = properties ?? WmlParagraphProps();

  List<WmlInline> inlines;
  WmlParagraphProps properties;

  String get text {
    final StringBuffer buffer = StringBuffer();
    for (final WmlInline inline in inlines) {
      if (inline is WmlRun) {
        buffer.write(inline.text);
      }
    }
    return buffer.toString();
  }
}

class WmlTableCell {
  WmlTableCell({
    List<WmlBlock>? blocks,
    this.gridSpan = 1,
    this.vMerge = WmlVMerge.none,
    this.width,
    this.fillColor,
  }) : blocks = blocks ?? <WmlBlock>[];

  List<WmlBlock> blocks;
  int gridSpan;
  WmlVMerge vMerge;
  double? width;
  String? fillColor;
}

class WmlTableRow {
  WmlTableRow({
    List<WmlTableCell>? cells,
    this.cantSplit = false,
    this.height,
  }) : cells = cells ?? <WmlTableCell>[];

  List<WmlTableCell> cells;
  bool cantSplit;
  double? height;
}

class WmlVisual extends WmlBlock {
  WmlVisual({required this.visual});

  OfficeVisual visual;
}

/// Absolutely positioned text box / shape, independent of the story flow.
class WmlFrame extends WmlBlock {
  WmlFrame({
    this.x = 72,
    this.y = 72,
    this.width = 200,
    this.height = 120,
    this.anchor = WmlFrameAnchor.page,
    this.wrap = WmlFrameWrap.none,
    this.fillColor,
    this.strokeColor,
    List<WmlBlock>? blocks,
  }) : blocks = blocks ?? <WmlBlock>[];

  double x;
  double y;
  double width;
  double height;
  WmlFrameAnchor anchor;
  WmlFrameWrap wrap;
  String? fillColor;
  String? strokeColor;
  List<WmlBlock> blocks;

  double pageX(WmlSection section) =>
      anchor == WmlFrameAnchor.margin ? section.margins.left + x : x;

  double pageY(WmlSection section) =>
      anchor == WmlFrameAnchor.margin ? section.margins.top + y : y;
}

class WmlEquation extends WmlBlock {
  WmlEquation({required this.math});

  OmmlEquation math;
}

class WmlTocEntry {
  WmlTocEntry({
    required this.text,
    required this.level,
    required this.headingParagraphIndex,
    this.pageNumber = 1,
  });

  String text;
  int level;
  int headingParagraphIndex;
  int pageNumber;
}

/// Live table of contents built from heading paragraphs.
class WmlToc extends WmlBlock {
  WmlToc({
    this.minLevel = 1,
    this.maxLevel = 3,
    this.showPageNumbers = true,
    String title = 'Table of Contents',
    List<WmlTocEntry>? entries,
    WmlParagraph? titleParagraph,
    List<WmlParagraph>? itemParagraphs,
  })  : title = title,
        entries = entries ?? <WmlTocEntry>[],
        titleParagraph = titleParagraph ??
            WmlParagraph(
              properties: WmlParagraphProps(
                styleId: 'TOCHeading',
                spacingAfter: 10,
                spacingBefore: 0,
              ),
              inlines: <WmlInline>[
                WmlRun(
                  text: title,
                  properties: WmlRunProps(
                    bold: true,
                    fontSizeHalfPoints: 28,
                    color: '1F4E79',
                  ),
                ),
              ],
            ),
        itemParagraphs = itemParagraphs ?? <WmlParagraph>[];

  int minLevel;
  int maxLevel;
  bool showPageNumbers;
  String title;
  List<WmlTocEntry> entries;
  WmlParagraph titleParagraph;
  List<WmlParagraph> itemParagraphs;
}

class WmlTable extends WmlBlock {
  WmlTable({
    List<double>? grid,
    List<WmlTableRow>? rows,
    WmlTableProps? properties,
  })  : grid = grid ?? <double>[],
        rows = rows ?? <WmlTableRow>[],
        properties = properties ?? WmlTableProps();

  List<double> grid;
  List<WmlTableRow> rows;
  WmlTableProps properties;
}

class WmlSection {
  WmlSection({
    List<WmlBlock>? blocks,
    this.pageSize = const WmlPageSize(),
    this.margins = const WmlPageMargins(),
    this.columnCount = 1,
    this.columnSpace = 36,
    this.columnSep = false,
    List<WmlParagraph>? header,
    List<WmlParagraph>? footer,
  })  : blocks = blocks ?? <WmlBlock>[],
        header = header ?? <WmlParagraph>[],
        footer = footer ?? <WmlParagraph>[];

  List<WmlBlock> blocks;
  WmlPageSize pageSize;
  WmlPageMargins margins;
  int columnCount;
  double columnSpace;
  bool columnSep;
  List<WmlParagraph> header;
  List<WmlParagraph> footer;

  double get contentWidth =>
      pageSize.width - margins.left - margins.right;

  double get contentHeight =>
      pageSize.height - margins.top - margins.bottom;

  int get resolvedColumnCount => columnCount < 1 ? 1 : columnCount;

  double get columnWidth {
    final int n = resolvedColumnCount;
    return ((contentWidth - columnSpace * (n - 1)) / n).clamp(12, contentWidth);
  }

  double columnOriginX(int index) =>
      margins.left + index * (columnWidth + columnSpace);
}

class WmlDocument {
  WmlDocument({
    List<WmlSection>? sections,
    List<WmlComment>? comments,
    this.package,
  })  : sections = sections ?? <WmlSection>[WmlSection()],
        comments = comments ?? <WmlComment>[];

  List<WmlSection> sections;
  List<WmlComment> comments;
  OpcPackage? package;

  factory WmlDocument.empty({String text = ''}) {
    return WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            WmlParagraph(inlines: <WmlInline>[WmlRun(text: text)]),
          ],
        ),
      ],
    );
  }

  Iterable<WmlParagraph> get paragraphs sync* {
    for (final WmlSection section in sections) {
      yield* _paragraphsIn(section.blocks);
    }
  }

  int sectionIndexOf(WmlParagraph paragraph) {
    for (int i = 0; i < sections.length; i++) {
      for (final WmlParagraph candidate in _paragraphsIn(sections[i].blocks)) {
        if (identical(candidate, paragraph)) {
          return i;
        }
      }
    }
    return 0;
  }

  Iterable<WmlVisual> get visuals sync* {
    for (final WmlSection section in sections) {
      yield* _visualsIn(section.blocks);
    }
  }

  static Iterable<WmlVisual> _visualsIn(List<WmlBlock> blocks) sync* {
    for (final WmlBlock block in blocks) {
      switch (block) {
        case WmlVisual():
          yield block;
        case WmlFrame():
          yield* _visualsIn(block.blocks);
        case WmlTable(:final List<WmlTableRow> rows):
          for (final WmlTableRow row in rows) {
            for (final WmlTableCell cell in row.cells) {
              yield* _visualsIn(cell.blocks);
            }
          }
        case WmlParagraph():
          break;
        case WmlEquation():
          break;
        case WmlToc():
          break;
      }
    }
  }

  static Iterable<WmlParagraph> _paragraphsIn(List<WmlBlock> blocks) sync* {
    for (final WmlBlock block in blocks) {
      switch (block) {
        case WmlParagraph():
          yield block;
        case WmlTable(:final List<WmlTableRow> rows):
          for (final WmlTableRow row in rows) {
            for (final WmlTableCell cell in row.cells) {
              yield* _paragraphsIn(cell.blocks);
            }
          }
        case WmlFrame():
          yield* _paragraphsIn(block.blocks);
        case WmlVisual():
          break;
        case WmlEquation():
          break;
        case WmlToc():
          yield block.titleParagraph;
          yield* block.itemParagraphs;
      }
    }
  }

  Iterable<WmlEquation> get equations sync* {
    for (final WmlSection section in sections) {
      yield* _equationsIn(section.blocks);
    }
  }

  static Iterable<WmlEquation> _equationsIn(List<WmlBlock> blocks) sync* {
    for (final WmlBlock block in blocks) {
      switch (block) {
        case WmlEquation():
          yield block;
        case WmlTable(:final List<WmlTableRow> rows):
          for (final WmlTableRow row in rows) {
            for (final WmlTableCell cell in row.cells) {
              yield* _equationsIn(cell.blocks);
            }
          }
        case WmlFrame():
          yield* _equationsIn(block.blocks);
        case WmlParagraph():
        case WmlVisual():
        case WmlToc():
          break;
      }
    }
  }
}
