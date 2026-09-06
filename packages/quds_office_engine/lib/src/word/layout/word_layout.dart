import 'dart:math' as math;

import '../../bidi/line_breaker.dart';
import '../../fonts/font_metrics.dart';
import '../../fonts/office_typeface.dart';
import '../../fonts/sfnt_parser.dart';
import '../../visual/office_visual.dart';
import '../math/omml_document.dart';
import '../math/omml_layout.dart';
import '../model/wml_document.dart';
import '../model/wml_run_edit.dart';
import '../model/word_comment.dart';
import '../model/word_link.dart';
import '../model/word_table.dart';
import '../model/word_toc.dart';
import '../properties/wml_properties.dart';

/// Class LaidOutGlyph.
class LaidOutGlyph {
  /// LaidOutGlyph API.
  LaidOutGlyph({
    required this.glyph,
    required this.x,
    required this.y,
    required this.color,
    required this.fontSize,
    required this.bold,
    required this.underline,
    this.italic = false,
    this.strike = false,
    this.highlight,
    this.fontFamily,
    this.vertAlign = WmlVertAlign.baseline,
    this.hyperlink,
    List<int>? commentIds,
    double? advance,
  }) : commentIds = commentIds ?? const <int>[],
       advance = advance ?? glyph.advance;

  /// glyph API.
  final ShapedGlyph glyph;

  /// x API.
  double x;

  /// y API.
  final double y;

  /// color API.
  final String color;

  /// fontSize API.
  final double fontSize;

  /// bold API.
  final bool bold;

  /// underline API.
  final WmlUnderline underline;

  /// italic API.
  final bool italic;

  /// strike API.
  final bool strike;

  /// highlight API.
  final String? highlight;

  /// fontFamily API.
  final String? fontFamily;

  /// vertAlign API.
  final WmlVertAlign vertAlign;

  /// hyperlink API.
  final WmlHyperlink? hyperlink;

  /// commentIds API.
  final List<int> commentIds;

  /// advance API.
  double advance;
}

/// Class LaidOutLine.
class LaidOutLine {
  /// LaidOutLine API.
  LaidOutLine({
    required this.glyphs,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.pageIndex,
    required this.justification,
    this.paragraphIndex = 0,
    this.listLabel,
    this.isParagraphStart = false,
    this.isFooter = false,
    this.overlayText,
    this.overlayColor,
    this.overlaySize = 11,
    this.overlayBold = false,
    this.sourceText,
    this.tocTargetParagraph,
    this.tocLeader = false,
    this.hyperlink,
  });

  /// glyphs API.
  final List<LaidOutGlyph> glyphs;

  /// x API.
  double x;

  /// y API.
  final double y;

  /// width API.
  double width;

  /// height API.
  final double height;

  /// pageIndex API.
  final int pageIndex;

  /// justification API.
  final WmlJustification justification;

  /// paragraphIndex API.
  final int paragraphIndex;

  /// listLabel API.
  final String? listLabel;

  /// isParagraphStart API.
  final bool isParagraphStart;

  /// isFooter API.
  final bool isFooter;

  /// overlayText API.
  final String? overlayText;

  /// overlayColor API.
  final String? overlayColor;

  /// overlaySize API.
  final double overlaySize;

  /// overlayBold API.
  final bool overlayBold;

  /// sourceText API.
  final String? sourceText;

  /// tocTargetParagraph API.
  final int? tocTargetParagraph;

  /// tocLeader API.
  final bool tocLeader;

  /// hyperlink API.
  final WmlHyperlink? hyperlink;
}

/// Enum LaidOutBoxKind.
enum LaidOutBoxKind {
  tableCell,
  picture,
  chart,
  diagram,
  equation,
  tocEntry,
  frame,
  columnSep,
}

/// Decorative box in page coordinates (table cell, picture, chart).
class LaidOutBox {
  /// LaidOutBox API.
  LaidOutBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.fillColor,
    this.strokeColor = 'B0B0B0',
    this.paragraphIndex,
    this.paragraphEnd,
    this.kind = LaidOutBoxKind.tableCell,
    this.visual,
    this.equation,
    this.omml,
    this.table,
    this.tableRow,
    this.tableCol,
    this.tableGridCol,
    this.frame,
  });

  /// x API.
  double x;

  /// y API.
  double y;

  /// width API.
  double width;

  /// height API.
  double height;

  /// fillColor API.
  String? fillColor;

  /// strokeColor API.
  String strokeColor;

  /// paragraphIndex API.
  int? paragraphIndex;

  /// paragraphEnd API.
  int? paragraphEnd;

  /// kind API.
  LaidOutBoxKind kind;

  /// visual API.
  OfficeVisual? visual;

  /// equation API.
  WmlEquation? equation;

  /// omml API.
  LaidOutOmml? omml;

  /// table API.
  WmlTable? table;

  /// tableRow API.
  int? tableRow;

  /// tableCol API.
  int? tableCol;

  /// tableGridCol API.
  int? tableGridCol;

  /// frame API.
  WmlFrame? frame;
}

/// Class LaidOutBand.
class LaidOutBand {
  /// LaidOutBand API.
  const LaidOutBand({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// left API.
  final double left;

  /// top API.
  final double top;

  /// width API.
  final double width;

  /// height API.
  final double height;

  /// contains API.
  bool contains(double x, double y) {
    return x >= left && x <= left + width && y >= top && y <= top + height;
  }
}

/// Class LaidOutPage.
class LaidOutPage {
  /// LaidOutPage API.
  LaidOutPage({
    required this.index,
    required this.width,
    required this.height,
    required this.lines,
    this.sectionIndex = 0,
    List<LaidOutBox>? frames,
    List<LaidOutLine>? header,
    List<LaidOutLine>? footer,
    LaidOutBand? headerBand,
    LaidOutBand? footerBand,
  }) : frames = frames ?? <LaidOutBox>[],
       header = header ?? <LaidOutLine>[],
       footer = footer ?? <LaidOutLine>[],
       headerBand =
           headerBand ?? LaidOutBand(left: 0, top: 0, width: width, height: 72),
       footerBand =
           footerBand ??
           LaidOutBand(left: 0, top: height - 72, width: width, height: 72);

  /// index API.
  final int index;

  /// sectionIndex API.
  final int sectionIndex;

  /// width API.
  final double width;

  /// height API.
  final double height;

  /// lines API.
  final List<LaidOutLine> lines;

  /// frames API.
  final List<LaidOutBox> frames;

  /// header API.
  final List<LaidOutLine> header;

  /// footer API.
  final List<LaidOutLine> footer;

  /// headerBand API.
  final LaidOutBand headerBand;

  /// footerBand API.
  final LaidOutBand footerBand;
}

/// Class LaidOutDocument.
class LaidOutDocument {
  /// LaidOutDocument API.
  LaidOutDocument({required this.pages, required this.pageSize});

  /// pages API.
  final List<LaidOutPage> pages;

  /// pageSize API.
  final WmlPageSize pageSize;

  /// Vertical offset of page [index] in the stacked Word canvas (points × scale).
  double pageStackTop(int index, double scale) {
    var top = 24.0;
    final int last = index < pages.length ? index : pages.length;
    for (int i = 0; i < last; i++) {
      top += pages[i].height * scale + 24;
    }
    if (index >= pages.length) {
      top += (index - pages.length) * (pageSize.height * scale + 24);
    }
    return top;
  }

  /// pageIndexAtContentY API.
  int pageIndexAtContentY(double contentY, double scale) {
    if (pages.isEmpty) {
      return 0;
    }
    var top = 24.0;
    for (int i = 0; i < pages.length; i++) {
      final double bottom = top + pages[i].height * scale;
      if (contentY < bottom + 12) {
        return i;
      }
      top = bottom + 24;
    }
    return pages.length - 1;
  }
}

class _Flow {
  _Flow(this.section, this.pages, this.makePage, this.sectionIndex)
    : pageIndex = pages.length,
      y = section.margins.top;

  /// section API.
  final WmlSection section;

  /// sectionIndex API.
  final int sectionIndex;

  /// pages API.
  final List<LaidOutPage> pages;

  /// Function API.
  final LaidOutPage Function(
    WmlSection section,
    int index,
    List<LaidOutLine> lines,
    List<LaidOutBox> frames, {
    required int sectionIndex,
  })
  /// makePage API.
  makePage;

  /// current API.
  final List<LaidOutLine> current = <LaidOutLine>[];

  /// currentFrames API.
  final List<LaidOutBox> currentFrames = <LaidOutBox>[];

  /// pageIndex API.
  int pageIndex;

  /// columnIndex API.
  int columnIndex = 0;

  /// y API.
  double y;

  /// originX API.
  double get originX => section.columnOriginX(columnIndex);

  /// colWidth API.
  double get colWidth => section.columnWidth;

  /// bottom API.
  double get bottom => section.pageSize.height - section.margins.bottom;

  /// hasContent API.
  bool get hasContent => current.isNotEmpty || currentFrames.isNotEmpty;

  /// flushPage API.
  void flushPage() {
    pages.add(_make());
    current.clear();
    currentFrames.clear();
    pageIndex++;
    columnIndex = 0;
    y = section.margins.top;
  }

  /// nextColumn API.
  void nextColumn() {
    if (columnIndex + 1 < section.resolvedColumnCount) {
      columnIndex++;
      y = section.margins.top;
    } else {
      flushPage();
    }
  }

  /// breakPage API.
  void breakPage() {
    if (hasContent || columnIndex > 0) {
      flushPage();
    }
  }

  /// ensure API.
  void ensure(double height) {
    if (y + height > bottom && (hasContent || columnIndex > 0)) {
      nextColumn();
    }
  }

  /// addSeparators API.
  void addSeparators() {
    if (!section.columnSep || section.resolvedColumnCount < 2) {
      return;
    }
    for (int i = 1; i < section.resolvedColumnCount; i++) {
      final double x = section.columnOriginX(i) - section.columnSpace / 2;
      currentFrames.add(
        LaidOutBox(
          x: x,
          y: section.margins.top,
          width: 0.7,
          height: section.contentHeight,
          fillColor: 'B0B0B0',
          strokeColor: 'B0B0B0',
          kind: LaidOutBoxKind.columnSep,
        ),
      );
    }
  }

  LaidOutPage _make() {
    addSeparators();
    return makePage(
      section,
      pageIndex,
      current,
      currentFrames,
      sectionIndex: sectionIndex,
    );
  }

  /// finish API.
  void finish() {
    if (hasContent || pages.isEmpty) {
      pages.add(_make());
      current.clear();
      currentFrames.clear();
    }
  }
}

/// Flowable pagination: Knuth–Plass lines accumulated into physical pages.
class WordLayoutEngine {
  /// WordLayoutEngine API.
  WordLayoutEngine({required this.font, this.fallbackWidthFactor = 0.5});

  /// font API.
  final SfntFont? font;

  /// fallbackWidthFactor API.
  final double fallbackWidthFactor;

  /// layout API.
  LaidOutDocument layout(WmlDocument document) {
    final List<LaidOutPage> pages = <LaidOutPage>[];
    var paragraphIndex = 0;
    for (int i = 0; i < document.sections.length; i++) {
      paragraphIndex = _layoutSection(
        document.sections[i],
        pages,
        sectionIndex: i,
        paragraphIndex: paragraphIndex,
      );
    }
    if (pages.isEmpty) {
      pages.add(
        _makePage(
          document.sections.first,
          0,
          <LaidOutLine>[],
          <LaidOutBox>[],
          sectionIndex: 0,
        ),
      );
    }
    return LaidOutDocument(
      pages: pages,
      pageSize: document.sections.first.pageSize,
    );
  }

  int _layoutSection(
    WmlSection section,
    List<LaidOutPage> pages, {
    required int sectionIndex,
    required int paragraphIndex,
  }) {
    final _Flow flow = _Flow(section, pages, _makePage, sectionIndex);
    for (final WmlBlock block in section.blocks) {
      switch (block) {
        case WmlParagraph():
          if (block.properties.pageBreakBefore) {
            flow.breakPage();
          } else if (block.properties.columnBreakBefore ||
              _hasBreak(block, WmlBreakType.column)) {
            flow.nextColumn();
          } else if (_hasBreak(block, WmlBreakType.page)) {
            flow.breakPage();
          }
          final ({double y, int pageIndex}) para = _layoutParagraph(
            block,
            section,
            pages,
            flow.current,
            flow.currentFrames,
            flow.pageIndex,
            flow.y,
            paragraphIndex,
            originX: flow.originX,
            maxWidthOverride:
                flow.colWidth -
                block.properties.indent.left -
                block.properties.indent.right,
            flow: flow,
          );
          flow.y = para.y;
          flow.pageIndex = para.pageIndex;
          paragraphIndex++;
          if (flow.y > flow.bottom) {
            flow.nextColumn();
          }
        case WmlTable():
          final ({double y, int pageIndex}) table = _layoutTable(
            block,
            section,
            pages,
            flow.current,
            flow.currentFrames,
            flow.pageIndex,
            flow.y,
            paragraphIndex,
            originX: flow.originX,
            maxWidthOverride: flow.colWidth,
            flow: flow,
          );
          flow.y = table.y;
          flow.pageIndex = table.pageIndex;
          paragraphIndex += _tableParagraphCount(block);
        case WmlVisual():
          final ({double y, int pageIndex}) visual = _layoutVisual(
            block.visual,
            section,
            pages,
            flow.current,
            flow.currentFrames,
            flow.pageIndex,
            flow.y,
            originX: flow.originX,
            maxWidthOverride: flow.colWidth,
            flow: flow,
          );
          flow.y = visual.y;
          flow.pageIndex = visual.pageIndex;
        case WmlFrame():
          paragraphIndex = _layoutFrame(block, section, flow, paragraphIndex);
        case WmlEquation():
          final ({double y, int pageIndex}) equation = _layoutEquation(
            block,
            section,
            pages,
            flow.current,
            flow.currentFrames,
            flow.pageIndex,
            flow.y,
          );
          flow.y = equation.y;
          flow.pageIndex = equation.pageIndex;
        case WmlToc():
          WordToc.ensureBody(block);
          final ({double y, int pageIndex}) toc = _layoutToc(
            block,
            section,
            pages,
            flow.current,
            flow.currentFrames,
            flow.pageIndex,
            flow.y,
            paragraphIndex,
          );
          flow.y = toc.y;
          flow.pageIndex = toc.pageIndex;
          paragraphIndex += 1 + block.itemParagraphs.length;
      }
    }
    flow.finish();
    return paragraphIndex;
  }

  static bool _hasBreak(WmlParagraph paragraph, WmlBreakType type) {
    for (final WmlInline inline in paragraph.inlines) {
      if (inline is WmlBreak && inline.type == type) {
        return true;
      }
    }
    return false;
  }

  static int _tableParagraphCount(WmlTable table) {
    var n = 0;
    for (final WmlTableRow row in table.rows) {
      for (final WmlTableCell cell in row.cells) {
        for (final WmlBlock block in cell.blocks) {
          if (block is WmlParagraph) {
            n++;
          }
        }
      }
    }
    return n;
  }

  List<double> _columnWidths(
    WmlTable table,
    WmlSection section, [
    double? maxWidth,
  ]) {
    final int columns = WordTable.columnCount(table).clamp(1, 64);
    final double available = maxWidth ?? section.contentWidth;
    if (table.grid.isNotEmpty) {
      final List<double> grid = table.grid.length >= columns
          ? table.grid.sublist(0, columns)
          : table.grid;
      if (table.grid.length >= columns) {
        final double used = grid.fold<double>(0, (double a, double b) => a + b);
        if (used > available && used > 0) {
          final double scale = available / used;
          return <double>[for (final double w in grid) w * scale];
        }
        return grid;
      }
      final double used = table.grid.fold<double>(
        0,
        (double a, double b) => a + b,
      );
      final int missing = columns - table.grid.length;
      final double rest = ((available - used) / missing).clamp(36, available);
      return <double>[...table.grid, ...List<double>.filled(missing, rest)];
    }
    return List<double>.filled(columns, available / columns);
  }

  ({double y, int pageIndex}) _layoutParagraph(
    WmlParagraph paragraph,
    WmlSection section,
    List<LaidOutPage> pages,
    List<LaidOutLine> current,
    List<LaidOutBox> currentFrames,
    int pageIndex,
    double y,
    int paragraphIndex, {
    double? originX,
    double? maxWidthOverride,
    String? sourceText,
    int? tocTargetParagraph,
    String? overlayText,
    bool tocLeader = false,
    _Flow? flow,
    bool allowBreak = true,
  }) {
    final WmlRunProps runProps = WmlRunEdit.propsAt(paragraph, 0);
    final double fontSize = runProps.fontSizePoints;
    final FontMetrics? metrics = font == null
        ? null
        : FontMetrics(font: font!, fontSizePoints: fontSize);
    final double lineHeight = _lineHeight(
      paragraph.properties,
      metrics,
      fontSize,
    );
    final String? listLabel = paragraph.properties.listLabel;
    final double listPad = listLabel == null ? 0 : 16;
    final double maxWidth =
        ((maxWidthOverride ??
                    (section.contentWidth -
                        paragraph.properties.indent.left -
                        paragraph.properties.indent.right)) -
                listPad)
            .clamp(12, section.pageSize.width);
    final String text = paragraph.text.isEmpty ? ' ' : paragraph.text;
    final List<BrokenLine> broken = LineBreaker.breakLines(
      text: text,
      maxWidth: maxWidth,
      widthOf: (int cp) =>
          metrics?.characterWidth(cp) ?? fontSize * fallbackWidthFactor,
      glyphIdOf: (int cp) => font?.glyphIdFor(cp) ?? cp,
      baseLevel: paragraph.properties.bidiBaseLevel,
    );
    var cursorY = y + paragraph.properties.spacingBefore;
    var idx = pageIndex;
    var lineOrigin = originX ?? section.margins.left;
    for (final BrokenLine line in broken) {
      if (allowBreak &&
          cursorY + lineHeight >
              section.pageSize.height - section.margins.bottom) {
        if (flow != null) {
          flow.y = cursorY;
          flow.nextColumn();
          cursorY = flow.y;
          idx = flow.pageIndex;
          lineOrigin = flow.originX;
        } else {
          pages.add(
            _makePage(
              section,
              idx,
              current,
              currentFrames,
              sectionIndex: pages.isEmpty ? 0 : pages.last.sectionIndex,
            ),
          );
          current.clear();
          currentFrames.clear();
          idx++;
          cursorY = section.margins.top;
        }
      }
      final double x0 = lineOrigin + paragraph.properties.indent.left + listPad;
      double x = x0;
      if (paragraph.properties.justification == WmlJustification.center) {
        x += (maxWidth - line.width) / 2;
      } else if (paragraph.properties.justification == WmlJustification.right) {
        x += maxWidth - line.width;
      }
      var gx = x;
      final List<LaidOutGlyph> glyphs = <LaidOutGlyph>[];
      for (final ShapedGlyph g in line.glyphs) {
        final WmlRunProps props = WmlRunEdit.propsAt(paragraph, g.logicalIndex);
        final double baseSize = props.fontSizePoints;
        final double size = baseSize * props.vertAlign.fontScale;
        final double scale = fontSize <= 0
            ? props.vertAlign.fontScale
            : size / fontSize;
        glyphs.add(
          LaidOutGlyph(
            glyph: g,
            x: gx,
            y:
                cursorY +
                (metrics?.ascender ?? baseSize * 0.8) +
                props.vertAlign.baselineShift(baseSize),
            color: props.color,
            fontSize: size,
            bold: props.bold,
            underline: props.underline,
            italic: props.italic,
            strike: props.strike,
            highlight: WmlHighlight.toRgb(props.highlight) ?? props.highlight,
            fontFamily: OfficeTypeface.familyForRun(props, g.codePoint),
            vertAlign: props.vertAlign,
            hyperlink: WordLink.at(paragraph, g.logicalIndex),
            commentIds: WordComment.idsAt(paragraph, g.logicalIndex),
            advance: g.advance * scale,
          ),
        );
        gx += g.advance * scale;
      }
      current.add(
        LaidOutLine(
          glyphs: glyphs,
          x: x,
          y: cursorY,
          width: line.width,
          height: lineHeight,
          pageIndex: idx,
          justification: paragraph.properties.justification,
          paragraphIndex: paragraphIndex,
          listLabel: listLabel,
          isParagraphStart: identical(line, broken.first),
          sourceText: sourceText,
          tocTargetParagraph: tocTargetParagraph,
          overlayText: identical(line, broken.last) ? overlayText : null,
          tocLeader: tocLeader && identical(line, broken.last),
        ),
      );
      cursorY += lineHeight;
    }
    return (y: cursorY + paragraph.properties.spacingAfter, pageIndex: idx);
  }

  ({double y, int pageIndex}) _layoutToc(
    WmlToc toc,
    WmlSection section,
    List<LaidOutPage> pages,
    List<LaidOutLine> current,
    List<LaidOutBox> currentFrames,
    int pageIndex,
    double y,
    int paragraphIndex,
  ) {
    var cursorY = y;
    var idx = pageIndex;
    var para = paragraphIndex;
    final ({double y, int pageIndex}) title = _layoutParagraph(
      toc.titleParagraph,
      section,
      pages,
      current,
      currentFrames,
      idx,
      cursorY,
      para,
      sourceText: toc.titleParagraph.text,
    );
    cursorY = title.y;
    idx = title.pageIndex;
    para++;
    final int itemCount = toc.itemParagraphs.length;
    for (int i = 0; i < itemCount; i++) {
      final WmlParagraph item = toc.itemParagraphs[i];
      final WmlTocEntry? entry = i < toc.entries.length ? toc.entries[i] : null;
      final int lineStart = current.length;
      final ({double y, int pageIndex}) laid = _layoutParagraph(
        item,
        section,
        pages,
        current,
        currentFrames,
        idx,
        cursorY,
        para,
        sourceText: item.text,
        tocTargetParagraph: entry?.headingParagraphIndex,
        overlayText: toc.showPageNumbers && entry != null
            ? '${entry.pageNumber}'
            : null,
        tocLeader: toc.showPageNumbers && entry != null,
      );
      cursorY = laid.y;
      idx = laid.pageIndex;
      para++;
      final List<LaidOutLine> entryLines = lineStart <= current.length
          ? current.sublist(lineStart)
          : List<LaidOutLine>.from(current);
      if (entryLines.isNotEmpty && entry != null) {
        final LaidOutLine first = entryLines.first;
        final LaidOutLine last = entryLines.last;
        currentFrames.add(
          LaidOutBox(
            x: section.margins.left,
            y: first.y,
            width: section.contentWidth,
            height: (last.y + last.height) - first.y,
            strokeColor: '00000000',
            kind: LaidOutBoxKind.tocEntry,
            paragraphIndex: entry.headingParagraphIndex,
          ),
        );
      }
    }
    return (y: cursorY + 8, pageIndex: idx);
  }

  ({double y, int pageIndex}) _layoutTable(
    WmlTable table,
    WmlSection section,
    List<LaidOutPage> pages,
    List<LaidOutLine> current,
    List<LaidOutBox> currentFrames,
    int pageIndex,
    double y,
    int paragraphIndex, {
    double? originX,
    double? maxWidthOverride,
    _Flow? flow,
  }) {
    final List<double> cols = _columnWidths(table, section, maxWidthOverride);
    var cursorY = y + 6;
    var idx = pageIndex;
    var para = paragraphIndex;
    const double cellPad = 4;
    final double tableX = originX ?? section.margins.left;
    final double tableWidth = cols.fold<double>(
      0,
      (double sum, double width) => sum + width,
    );
    final bool rtl = table.properties.rightToLeft;

    for (final WmlTableRow row in table.rows) {
      const double estimated = 22.0;
      if (cursorY + estimated >
              section.pageSize.height - section.margins.bottom &&
          (current.isNotEmpty || currentFrames.isNotEmpty)) {
        if (flow != null) {
          flow.y = cursorY;
          flow.nextColumn();
          cursorY = flow.y;
          idx = flow.pageIndex;
        } else {
          pages.add(
            _makePage(
              section,
              idx,
              current,
              currentFrames,
              sectionIndex: pages.isEmpty ? 0 : pages.last.sectionIndex,
            ),
          );
          current.clear();
          currentFrames.clear();
          idx++;
          cursorY = section.margins.top;
        }
      }

      final double rowStartY = cursorY;
      var rowBottom = rowStartY;
      var x = rtl ? tableX + tableWidth : tableX;
      var gridCol = 0;
      final List<LaidOutBox> rowFrames = <LaidOutBox>[];

      final int rowIndex = table.rows.indexOf(row);
      for (int c = 0; c < row.cells.length; c++) {
        final WmlTableCell cell = row.cells[c];
        final int span = WordTable.spanOf(cell);
        var colW = 0.0;
        for (int k = 0; k < span; k++) {
          colW += cols[(gridCol + k).clamp(0, cols.length - 1)];
        }
        if (rtl) {
          x -= colW;
        }
        final int cellParaStart = para;
        var cellY = rowStartY + cellPad;
        for (final WmlBlock block in cell.blocks) {
          if (block is WmlParagraph) {
            final ({double y, int pageIndex}) laid = _layoutParagraph(
              block,
              section,
              pages,
              current,
              currentFrames,
              idx,
              cellY,
              para,
              originX: x + cellPad,
              maxWidthOverride: math.max(12, colW - cellPad * 2),
            );
            cellY = laid.y;
            idx = laid.pageIndex;
            para++;
          } else if (block is WmlEquation) {
            final LaidOutOmml omml = OmmlLayout.layout(
              block.math,
              fontSize: 14,
            );
            currentFrames.add(
              LaidOutBox(
                x: x + cellPad,
                y: cellY,
                width: math.min(colW - cellPad * 2, omml.width),
                height: omml.height,
                fillColor: 'F7FBFF',
                strokeColor: '8FAADC',
                kind: LaidOutBoxKind.equation,
                equation: block,
                omml: omml,
              ),
            );
            cellY += omml.height + 4;
          }
        }
        rowBottom = math.max(rowBottom, cellY + cellPad);
        rowFrames.add(
          LaidOutBox(
            x: x,
            y: rowStartY,
            width: colW,
            height: 0,
            fillColor: cell.vMerge == WmlVMerge.cont ? null : cell.fillColor,
            strokeColor: cell.vMerge == WmlVMerge.cont ? '00000000' : 'B0B0B0',
            paragraphIndex: cellParaStart,
            paragraphEnd: para > cellParaStart ? para - 1 : cellParaStart,
            table: table,
            tableRow: rowIndex,
            tableCol: c,
            tableGridCol: gridCol,
          ),
        );
        if (!rtl) {
          x += colW;
        }
        gridCol += span;
      }

      final double minH = row.height ?? 20;
      final double height = math.max(minH, rowBottom - rowStartY);
      for (final LaidOutBox frame in rowFrames) {
        frame.height = height;
        currentFrames.add(frame);
      }
      cursorY = rowStartY + height;
    }
    _applyVerticalMerges(table, currentFrames);
    return (y: cursorY + 8, pageIndex: idx);
  }

  void _applyVerticalMerges(WmlTable table, List<LaidOutBox> frames) {
    final List<LaidOutBox> mine = <LaidOutBox>[
      for (final LaidOutBox box in frames)
        if (identical(box.table, table) && box.kind == LaidOutBoxKind.tableCell)
          box,
    ];
    for (final LaidOutBox box in mine) {
      final int r = box.tableRow ?? 0;
      final int c = box.tableCol ?? 0;
      if (r >= table.rows.length || c >= table.rows[r].cells.length) {
        continue;
      }
      final WmlTableCell cell = table.rows[r].cells[c];
      if (cell.vMerge != WmlVMerge.restart) {
        continue;
      }
      final int g0 = WordTable.gridStart(table.rows[r], c);
      var bottom = box.y + box.height;
      for (int rr = r + 1; rr < table.rows.length; rr++) {
        final int? i = WordTable.cellIndexAtGrid(table.rows[rr], g0);
        if (i == null || table.rows[rr].cells[i].vMerge != WmlVMerge.cont) {
          break;
        }
        LaidOutBox? cont;
        for (final LaidOutBox other in mine) {
          if (other.tableRow == rr && other.tableCol == i) {
            cont = other;
            break;
          }
        }
        if (cont == null) {
          break;
        }
        bottom = math.max(bottom, cont.y + cont.height);
        cont
          ..height = 0
          ..fillColor = null
          ..strokeColor = '00000000';
      }
      box.height = bottom - box.y;
    }
  }

  int _layoutFrame(
    WmlFrame frame,
    WmlSection section,
    _Flow flow,
    int paragraphIndex,
  ) {
    final double x = frame.pageX(section);
    final double y = frame.pageY(section);
    const double pad = 8;
    flow.currentFrames.add(
      LaidOutBox(
        x: x,
        y: y,
        width: frame.width,
        height: frame.height,
        fillColor: frame.fillColor,
        strokeColor: frame.strokeColor ?? '00000000',
        kind: LaidOutBoxKind.frame,
        frame: frame,
      ),
    );
    var cursorY = y + pad;
    var para = paragraphIndex;
    final double innerX = x + pad;
    final double innerW = math.max(12, frame.width - pad * 2);
    for (final WmlBlock block in frame.blocks) {
      switch (block) {
        case WmlParagraph():
          final ({double y, int pageIndex}) laid = _layoutParagraph(
            block,
            section,
            flow.pages,
            flow.current,
            flow.currentFrames,
            flow.pageIndex,
            cursorY,
            para,
            originX: innerX,
            maxWidthOverride: innerW,
            allowBreak: false,
          );
          cursorY = laid.y;
          para++;
        case WmlVisual():
          final ({double y, int pageIndex}) laid = _layoutVisual(
            block.visual,
            section,
            flow.pages,
            flow.current,
            flow.currentFrames,
            flow.pageIndex,
            cursorY,
            originX: innerX,
            maxWidthOverride: innerW,
            allowBreak: false,
          );
          cursorY = laid.y;
        case WmlTable():
          final ({double y, int pageIndex}) laid = _layoutTable(
            block,
            section,
            flow.pages,
            flow.current,
            flow.currentFrames,
            flow.pageIndex,
            cursorY,
            para,
            originX: innerX,
            maxWidthOverride: innerW,
          );
          cursorY = laid.y;
          para += _tableParagraphCount(block);
        case WmlEquation():
          final ({double y, int pageIndex}) laid = _layoutEquation(
            block,
            section,
            flow.pages,
            flow.current,
            flow.currentFrames,
            flow.pageIndex,
            cursorY,
          );
          cursorY = laid.y;
        case WmlFrame():
          para = _layoutFrame(block, section, flow, para);
        case WmlToc():
          break;
      }
    }
    return para;
  }

  ({double y, int pageIndex}) _layoutVisual(
    OfficeVisual visual,
    WmlSection section,
    List<LaidOutPage> pages,
    List<LaidOutLine> current,
    List<LaidOutBox> currentFrames,
    int pageIndex,
    double y, {
    double? originX,
    double? maxWidthOverride,
    _Flow? flow,
    bool allowBreak = true,
  }) {
    final double maxW = maxWidthOverride ?? section.contentWidth;
    final bool absolute =
        visual.picture.wrap == PictureWrap.behind ||
        visual.picture.wrap == PictureWrap.inFront;
    final double width = visual.width.clamp(
      24,
      absolute ? section.pageSize.width : maxW,
    );
    final double height = visual.height.clamp(
      24,
      absolute ? section.pageSize.height : section.contentHeight,
    );
    if (absolute) {
      currentFrames.add(
        _visualBox(visual, visual.offsetX, visual.offsetY, width, height),
      );
      return (y: y, pageIndex: pageIndex);
    }
    final bool atTop = (y - section.margins.top).abs() < 0.5;
    var cursorY = atTop ? y : y + 8 + visual.offsetY;
    var idx = pageIndex;
    var x0 = (originX ?? section.margins.left) + visual.offsetX;
    if (allowBreak &&
        cursorY + height > section.pageSize.height - section.margins.bottom &&
        (current.isNotEmpty || currentFrames.isNotEmpty)) {
      if (flow != null) {
        flow.y = cursorY;
        flow.nextColumn();
        cursorY = flow.y;
        idx = flow.pageIndex;
        x0 = flow.originX + visual.offsetX;
      } else {
        pages.add(
          _makePage(
            section,
            idx,
            current,
            currentFrames,
            sectionIndex: pages.isEmpty ? 0 : pages.last.sectionIndex,
          ),
        );
        current.clear();
        currentFrames.clear();
        idx++;
        cursorY = section.margins.top;
      }
    }
    currentFrames.add(_visualBox(visual, x0, cursorY, width, height));
    return (y: cursorY + height + 10, pageIndex: idx);
  }

  LaidOutBox _visualBox(
    OfficeVisual visual,
    double x,
    double y,
    double width,
    double height,
  ) {
    return LaidOutBox(
      x: x,
      y: y,
      width: width,
      height: height,
      fillColor: 'FFFFFF',
      strokeColor: '8FAADC',
      kind: visual.isDiagram
          ? LaidOutBoxKind.diagram
          : visual.kind == OfficeVisualKind.picture
          ? LaidOutBoxKind.picture
          : LaidOutBoxKind.chart,
      visual: visual,
    );
  }

  ({double y, int pageIndex}) _layoutEquation(
    WmlEquation equation,
    WmlSection section,
    List<LaidOutPage> pages,
    List<LaidOutLine> current,
    List<LaidOutBox> currentFrames,
    int pageIndex,
    double y,
  ) {
    final LaidOutOmml omml = OmmlLayout.layout(equation.math, fontSize: 16);
    final double width = math.min(
      section.contentWidth,
      math.max(72, omml.width),
    );
    final double height = math.max(28, omml.height);
    var cursorY = y + 8;
    var idx = pageIndex;
    if (cursorY + height > section.pageSize.height - section.margins.bottom &&
        (current.isNotEmpty || currentFrames.isNotEmpty)) {
      pages.add(
        _makePage(
          section,
          idx,
          current,
          currentFrames,
          sectionIndex: pages.isEmpty ? 0 : pages.last.sectionIndex,
        ),
      );
      current.clear();
      currentFrames.clear();
      idx++;
      cursorY = section.margins.top;
    }
    final double x = equation.math.display == OmmlDisplay.display
        ? section.margins.left + (section.contentWidth - width) / 2
        : section.margins.left;
    currentFrames.add(
      LaidOutBox(
        x: x,
        y: cursorY,
        width: width,
        height: height,
        fillColor: 'F7FBFF',
        strokeColor: '8FAADC',
        kind: LaidOutBoxKind.equation,
        equation: equation,
        omml: omml,
      ),
    );
    return (y: cursorY + height + 10, pageIndex: idx);
  }

  static double _lineHeight(
    WmlParagraphProps props,
    FontMetrics? metrics,
    double fontSize,
  ) {
    final double natural = metrics?.lineHeight ?? fontSize * 1.2;
    switch (props.lineSpacingRule) {
      case WmlLineSpacingRule.exact:
        return props.lineSpacing;
      case WmlLineSpacingRule.atLeast:
        return natural > props.lineSpacing ? natural : props.lineSpacing;
      case WmlLineSpacingRule.auto:
        return natural * props.lineSpacing;
    }
  }

  LaidOutPage _makePage(
    WmlSection section,
    int index,
    List<LaidOutLine> lines,
    List<LaidOutBox> frames, {
    required int sectionIndex,
  }) {
    return LaidOutPage(
      index: index,
      sectionIndex: sectionIndex,
      width: section.pageSize.width,
      height: section.pageSize.height,
      lines: List<LaidOutLine>.from(lines),
      frames: List<LaidOutBox>.from(frames),
      header: _chromeLines(section, index + 1, section.header, isFooter: false),
      footer: _chromeLines(section, index + 1, section.footer, isFooter: true),
      headerBand: LaidOutBand(
        left: 0,
        top: 0,
        width: section.pageSize.width,
        height: section.margins.top,
      ),
      footerBand: LaidOutBand(
        left: 0,
        top: section.pageSize.height - section.margins.bottom,
        width: section.pageSize.width,
        height: section.margins.bottom,
      ),
    );
  }

  List<LaidOutLine> _chromeLines(
    WmlSection section,
    int pageNumber,
    List<WmlParagraph> story, {
    required bool isFooter,
  }) {
    if (story.isEmpty) {
      return <LaidOutLine>[];
    }
    final double y = isFooter
        ? section.pageSize.height -
              math.max(22.0, section.margins.bottom * 0.45)
        : math.max(16.0, math.min(24.0, section.margins.top * 0.38));
    final List<LaidOutLine> lines = <LaidOutLine>[];
    var offsetY = 0.0;
    for (int i = 0; i < story.length; i++) {
      final WmlParagraph paragraph = story[i];
      final WmlRunProps run = WmlRunEdit.propsAt(paragraph, 0);
      final bool pageField = paragraph.properties.pageNumberField;
      final String raw = paragraph.text.trim();
      final String text;
      if (pageField) {
        text = raw.isEmpty || _looksLikePageCache(raw)
            ? '$pageNumber'
            : raw.replaceAll(RegExp(r'\b\d+\b'), '$pageNumber');
      } else if (_looksLikePageCache(raw)) {
        text = '$pageNumber';
      } else {
        text = raw;
      }
      final double size = run.fontSizePoints.clamp(8, 16);
      final double width = text.isEmpty
          ? section.contentWidth
          : text.length * size * 0.52;
      var x = section.margins.left;
      if (paragraph.properties.justification == WmlJustification.center) {
        x = (section.pageSize.width - width) / 2;
      } else if (paragraph.properties.justification == WmlJustification.right) {
        x = section.pageSize.width - section.margins.right - width;
      }
      lines.add(
        LaidOutLine(
          glyphs: <LaidOutGlyph>[],
          x: x,
          y: y + offsetY,
          width: width,
          height: size + 3,
          pageIndex: pageNumber - 1,
          paragraphIndex: i,
          justification: paragraph.properties.justification,
          isFooter: isFooter,
          overlayText: text,
          overlayColor: run.color.isEmpty
              ? (isFooter ? '222222' : '6B7280')
              : run.color,
          overlaySize: size,
          overlayBold: run.bold,
          hyperlink: WordLink.firstIn(paragraph),
        ),
      );
      offsetY += size + 4;
    }
    return lines;
  }

  static bool _looksLikePageCache(String text) =>
      RegExp(r'^\d+$').hasMatch(text);
}
