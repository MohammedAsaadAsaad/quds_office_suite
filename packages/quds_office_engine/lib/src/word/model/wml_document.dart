import '../../opc/ole/embedded_part.dart';
import '../../opc/opc_archive.dart';
import '../../visual/office_visual.dart';
import '../math/omml_document.dart';
import '../properties/wml_properties.dart';

/// Class WmlBlock.
sealed class WmlBlock {
  /// WmlBlock API.
  WmlBlock();
}

/// Class WmlInline.
sealed class WmlInline {
  /// WmlInline API.
  WmlInline();
}

/// Class WmlRun.
class WmlRun extends WmlInline {
  /// WmlRun API.
  WmlRun({
    this.text = '',
    WmlRunProps? properties,
    this.hyperlink,
    List<int>? commentIds,
  }) : properties = properties ?? WmlRunProps(),
       commentIds = commentIds ?? <int>[];

  /// text API.
  String text;

  /// properties API.
  WmlRunProps properties;

  /// hyperlink API.
  WmlHyperlink? hyperlink;

  /// commentIds API.
  List<int> commentIds;
}

/// Class WmlComment.
class WmlComment {
  /// WmlComment API.
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
  }) : paragraphs =
           paragraphs ??
           <WmlParagraph>[
             WmlParagraph(inlines: <WmlInline>[WmlRun(text: text)]),
           ],
       visuals = visuals ?? <WmlVisual>[];

  /// id API.
  int id;

  /// author API.
  String author;

  /// initials API.
  String initials;

  /// dateIso API.
  String dateIso;

  /// paragraphs API.
  List<WmlParagraph> paragraphs;

  /// visuals API.
  List<WmlVisual> visuals;

  /// parentId API.
  int? parentId;

  /// resolved API.
  bool resolved;

  /// isReply API.
  bool get isReply => parentId != null;

  /// text API.
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

  /// text API.
  set text(String value) {
    final WmlRunProps props = paragraphs.isEmpty
        ? WmlRunProps(fontSizeHalfPoints: 20)
        : (paragraphs.first.inlines
                  .whereType<WmlRun>()
                  .firstOrNull
                  ?.properties
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

  /// copy API.
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
  /// WmlHyperlink API.
  const WmlHyperlink({this.anchor, this.url, this.file});

  /// Internal bookmark or heading target (`w:anchor`).
  final String? anchor;

  /// url API.
  final String? url;

  /// file API.
  final String? file;

  /// isInternal API.
  bool get isInternal => anchor != null && anchor!.isNotEmpty;

  /// isWeb API.
  bool get isWeb {
    final String? value = url;
    if (value == null || value.isEmpty) {
      return false;
    }
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('mailto:');
  }

  /// isFile API.
  bool get isFile => file != null && file!.isNotEmpty;

  /// displayTarget API.
  String get displayTarget => url ?? file ?? anchor ?? '';

  /// copy API.
  WmlHyperlink copy() => WmlHyperlink(anchor: anchor, url: url, file: file);

  /// fromTarget API.
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

/// Class WmlBreak.
class WmlBreak extends WmlInline {
  /// WmlBreak API.
  WmlBreak(this.type);

  /// type API.
  final WmlBreakType type;
}

/// Class WmlObject.
class WmlObject extends WmlInline {
  /// WmlObject API.
  WmlObject({
    required this.relationshipId,
    this.embedded,
    this.width = 200,
    this.height = 120,
  });

  /// relationshipId API.
  String relationshipId;

  /// embedded API.
  IsolatedEmbeddedPackage? embedded;

  /// width API.
  double width;

  /// height API.
  double height;
}

/// Class WmlParagraph.
class WmlParagraph extends WmlBlock {
  /// WmlParagraph API.
  WmlParagraph({List<WmlInline>? inlines, WmlParagraphProps? properties})
    : inlines = inlines ?? <WmlInline>[],
      properties = properties ?? WmlParagraphProps();

  /// inlines API.
  List<WmlInline> inlines;

  /// properties API.
  WmlParagraphProps properties;

  /// text API.
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

/// Class WmlTableCell.
class WmlTableCell {
  /// WmlTableCell API.
  WmlTableCell({
    List<WmlBlock>? blocks,
    this.gridSpan = 1,
    this.vMerge = WmlVMerge.none,
    this.width,
    this.fillColor,
  }) : blocks = blocks ?? <WmlBlock>[];

  /// blocks API.
  List<WmlBlock> blocks;

  /// gridSpan API.
  int gridSpan;

  /// vMerge API.
  WmlVMerge vMerge;

  /// width API.
  double? width;

  /// fillColor API.
  String? fillColor;
}

/// Class WmlTableRow.
class WmlTableRow {
  /// WmlTableRow API.
  WmlTableRow({List<WmlTableCell>? cells, this.cantSplit = false, this.height})
    : cells = cells ?? <WmlTableCell>[];

  /// cells API.
  List<WmlTableCell> cells;

  /// cantSplit API.
  bool cantSplit;

  /// height API.
  double? height;
}

/// Class WmlVisual.
class WmlVisual extends WmlBlock {
  /// WmlVisual API.
  WmlVisual({required this.visual});

  /// visual API.
  OfficeVisual visual;
}

/// Absolutely positioned text box / shape, independent of the story flow.
class WmlFrame extends WmlBlock {
  /// WmlFrame API.
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

  /// x API.
  double x;

  /// y API.
  double y;

  /// width API.
  double width;

  /// height API.
  double height;

  /// anchor API.
  WmlFrameAnchor anchor;

  /// wrap API.
  WmlFrameWrap wrap;

  /// fillColor API.
  String? fillColor;

  /// strokeColor API.
  String? strokeColor;

  /// blocks API.
  List<WmlBlock> blocks;

  /// pageX API.
  double pageX(WmlSection section) =>
      anchor == WmlFrameAnchor.margin ? section.margins.left + x : x;

  /// pageY API.
  double pageY(WmlSection section) =>
      anchor == WmlFrameAnchor.margin ? section.margins.top + y : y;
}

/// Class WmlEquation.
class WmlEquation extends WmlBlock {
  /// WmlEquation API.
  WmlEquation({required this.math});

  /// math API.
  OmmlEquation math;
}

/// Class WmlTocEntry.
class WmlTocEntry {
  /// WmlTocEntry API.
  WmlTocEntry({
    required this.text,
    required this.level,
    required this.headingParagraphIndex,
    this.pageNumber = 1,
  });

  /// text API.
  String text;

  /// level API.
  int level;

  /// headingParagraphIndex API.
  int headingParagraphIndex;

  /// pageNumber API.
  int pageNumber;
}

/// Live table of contents built from heading paragraphs.
class WmlToc extends WmlBlock {
  /// WmlToc API.
  WmlToc({
    this.minLevel = 1,
    this.maxLevel = 3,
    this.showPageNumbers = true,
    String title = 'Table of Contents',
    List<WmlTocEntry>? entries,
    WmlParagraph? titleParagraph,
    List<WmlParagraph>? itemParagraphs,
  }) : title = title,
       entries = entries ?? <WmlTocEntry>[],
       titleParagraph =
           titleParagraph ??
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

  /// minLevel API.
  int minLevel;

  /// maxLevel API.
  int maxLevel;

  /// showPageNumbers API.
  bool showPageNumbers;

  /// title API.
  String title;

  /// entries API.
  List<WmlTocEntry> entries;

  /// titleParagraph API.
  WmlParagraph titleParagraph;

  /// itemParagraphs API.
  List<WmlParagraph> itemParagraphs;
}

/// Class WmlTable.
class WmlTable extends WmlBlock {
  /// WmlTable API.
  WmlTable({
    List<double>? grid,
    List<WmlTableRow>? rows,
    WmlTableProps? properties,
  }) : grid = grid ?? <double>[],
       rows = rows ?? <WmlTableRow>[],
       properties = properties ?? WmlTableProps();

  /// grid API.
  List<double> grid;

  /// rows API.
  List<WmlTableRow> rows;

  /// properties API.
  WmlTableProps properties;
}

/// Class WmlSection.
class WmlSection {
  /// WmlSection API.
  WmlSection({
    List<WmlBlock>? blocks,
    this.pageSize = const WmlPageSize(),
    this.margins = const WmlPageMargins(),
    this.columnCount = 1,
    this.columnSpace = 36,
    this.columnSep = false,
    List<WmlParagraph>? header,
    List<WmlParagraph>? footer,
  }) : blocks = blocks ?? <WmlBlock>[],
       header = header ?? <WmlParagraph>[],
       footer = footer ?? <WmlParagraph>[];

  /// blocks API.
  List<WmlBlock> blocks;

  /// pageSize API.
  WmlPageSize pageSize;

  /// margins API.
  WmlPageMargins margins;

  /// columnCount API.
  int columnCount;

  /// columnSpace API.
  double columnSpace;

  /// columnSep API.
  bool columnSep;

  /// header API.
  List<WmlParagraph> header;

  /// footer API.
  List<WmlParagraph> footer;

  /// contentWidth API.
  double get contentWidth => pageSize.width - margins.left - margins.right;

  /// contentHeight API.
  double get contentHeight => pageSize.height - margins.top - margins.bottom;

  /// resolvedColumnCount API.
  int get resolvedColumnCount => columnCount < 1 ? 1 : columnCount;

  /// columnWidth API.
  double get columnWidth {
    final int n = resolvedColumnCount;
    return ((contentWidth - columnSpace * (n - 1)) / n).clamp(12, contentWidth);
  }

  /// columnOriginX API.
  double columnOriginX(int index) =>
      margins.left + index * (columnWidth + columnSpace);
}

/// Class WmlDocument.
class WmlDocument {
  /// WmlDocument API.
  WmlDocument({
    List<WmlSection>? sections,
    List<WmlComment>? comments,
    this.package,
  }) : sections = sections ?? <WmlSection>[WmlSection()],
       comments = comments ?? <WmlComment>[];

  /// sections API.
  List<WmlSection> sections;

  /// comments API.
  List<WmlComment> comments;

  /// package API.
  OpcPackage? package;

  /// empty API.
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

  /// paragraphs API.
  Iterable<WmlParagraph> get paragraphs sync* {
    for (final WmlSection section in sections) {
      yield* _paragraphsIn(section.blocks);
    }
  }

  /// sectionIndexOf API.
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

  /// visuals API.
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

  /// equations API.
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
