part of 'widgets.dart';

/// Walks a [Document] once and builds a [WmlDocument].
abstract final class WordTranslator {
  /// toDocument API.
  static WmlDocument toDocument(Document source) {
    final ThemeData rootTheme = source.theme ?? ThemeData.base();
    final List<WmlSection> sections = <WmlSection>[];
    final List<String> stamps = <String>[];
    if (source.pages.isEmpty) {
      sections.add(
        WmlSection(
          blocks: <WmlBlock>[
            WmlParagraph(inlines: <WmlInline>[WmlRun(text: '')]),
          ],
        ),
      );
    } else {
      for (int i = 0; i < source.pages.length; i++) {
        sections.add(
          _section(source, source.pages[i], rootTheme, stamps, sectionIndex: i),
        );
      }
    }
    final WmlDocument document = WmlDocument(
      sections: sections,
      styles: _themedStyles(rootTheme),
      watermark: stamps.isEmpty ? source.watermark : stamps.first,
      properties: OfficeDocumentProperties(
        title: source.title,
        creator: source.author.isEmpty ? source.creator : source.author,
        subject: source.subject,
        keywords: source.keywords,
      ),
    );
    WordToc.refreshAll(document);
    return document;
  }
}

List<WmlStyle> _themedStyles(ThemeData theme) {
  return <WmlStyle>[
    for (final WmlStyle style in WordStyles.catalog)
      WmlStyle(
        id: style.id,
        name: style.name,
        nameAr: style.nameAr,
        headingLevel: style.headingLevel,
        justification: style.justification,
        bold: style.bold,
        italic: style.italic,
        fontSizePoints: style.fontSizePoints,
        color: style.headingLevel != null
            ? (_hex(theme.header1.color) ?? style.color)
            : style.color,
        spacingBefore: style.spacingBefore,
        spacingAfter: style.spacingAfter,
        font: theme.defaultTextStyle.font,
        csFont: theme.defaultTextStyle.font,
      ),
  ];
}

WmlSection _section(
  Document source,
  Page page,
  ThemeData rootTheme,
  List<String> stamps, {
  int sectionIndex = 0,
}) {
  final PageTheme pageTheme = page.pageTheme;
  final ThemeData theme = pageTheme.theme ?? rootTheme;
  final PdfPageFormat format = pageTheme.resolvedFormat;
  final EdgeInsets margin =
      pageTheme.margin ??
      EdgeInsets.fromLTRB(
        format.marginLeft,
        format.marginTop,
        format.marginRight,
        format.marginBottom,
      );
  final Context ctx = Context(
    theme: theme,
    pageFormat: format,
    textDirection: pageTheme.textDirection ?? TextDirection.ltr,
  );
  final _Walk walk = _Walk(ctx, stamps: stamps);
  final List<WmlBlock> blocks = <WmlBlock>[];
  for (final Widget child in page.childrenOf(ctx)) {
    blocks.addAll(walk.blocks(child));
  }
  if (blocks.isEmpty) {
    blocks.add(walk.paragraph(<WmlInline>[WmlRun(text: '')]));
  }
  return WmlSection(
    blocks: blocks,
    pageSize: WmlPageSize(width: format.width, height: format.height),
    margins: WmlPageMargins(
      top: margin.top,
      bottom: margin.bottom,
      left: margin.left,
      right: margin.right,
    ),
    breakKind: WmlSectionBreakKind.nextPage,
    linkToPrevious: sectionIndex == 0,
    header: page.header == null ? <WmlParagraph>[] : walk.chrome(page.header!(ctx)),
    footer: page.footer == null ? <WmlParagraph>[] : walk.chrome(page.footer!(ctx)),
  );
}

class _Walk {
  _Walk(
    this.ctx, {
    this.linkUrl,
    this.linkAnchor,
    this.alignOverride,
    this.fill,
    this.borderColor,
    this.keepTogether = false,
    this.bookmark,
    List<String>? stamps,
    List<int>? numberedSeq,
  }) : stamps = stamps ?? <String>[],
       numberedSeq = numberedSeq ?? <int>[0];

  Context ctx;
  final String? linkUrl;
  final String? linkAnchor;
  final TextAlign? alignOverride;
  final String? fill;
  final String? borderColor;
  final bool keepTogether;
  final String? bookmark;
  final List<String> stamps;
  final List<int> numberedSeq;

  _Walk fork({
    Context? ctx,
    String? linkUrl,
    String? linkAnchor,
    TextAlign? alignOverride,
    String? fill,
    String? borderColor,
    bool? keepTogether,
    String? bookmark,
  }) {
    return _Walk(
      ctx ?? this.ctx,
      linkUrl: linkUrl ?? this.linkUrl,
      linkAnchor: linkAnchor ?? this.linkAnchor,
      alignOverride: alignOverride ?? this.alignOverride,
      fill: fill ?? this.fill,
      borderColor: borderColor ?? this.borderColor,
      keepTogether: keepTogether ?? this.keepTogether,
      bookmark: bookmark ?? this.bookmark,
      stamps: stamps,
      numberedSeq: numberedSeq,
    );
  }

  List<WmlBlock> blocks(Widget widget) {
    switch (widget) {
      case Text():
        return <WmlBlock>[
          paragraph(
            _inlinesFromText(widget.text, widget.style),
            align: widget.textAlign,
            direction: widget.textDirection,
          ),
        ];
      case RichText():
        return _rich(widget);
      case Paragraph():
        return <WmlBlock>[_paragraphWidget(widget)];
      case Header():
        return <WmlBlock>[_header(widget)];
      case Bullet():
        return _listItem(
          widget.child ??
              (widget.text == null
                  ? const SizedBox()
                  : Text(widget.text!, style: widget.style, textAlign: widget.textAlign)),
          numbered: false,
          level: 0,
          margin: widget.margin,
          padding: widget.padding,
        );
      case Numbered():
        return _listItem(
          widget.child ??
              (widget.text == null
                  ? const SizedBox()
                  : Text(widget.text!, style: widget.style, textAlign: widget.textAlign)),
          numbered: true,
          level: widget.level,
          margin: widget.margin,
        );
      case Footer():
        return <WmlBlock>[_footerRow(widget)];
      case Padding():
        return _padded(widget.padding, widget.child);
      case Align():
        return fork(alignOverride: _textAlignOf(widget.alignment)).blocks(
          widget.child,
        );
      case SizedBox():
        if (widget.child != null) {
          return blocks(widget.child!);
        }
        return <WmlBlock>[
          paragraph(
            <WmlInline>[WmlRun(text: '')],
            before: widget.height ?? 0,
            after: 0,
          ),
        ];
      case Divider():
        return <WmlBlock>[_divider(widget)];
      case NewPage():
        return <WmlBlock>[
          WmlParagraph(
            inlines: <WmlInline>[WmlRun(text: '')],
            properties: WmlParagraphProps(pageBreakBefore: true),
          ),
        ];
      case Column():
        final List<WmlBlock> out = <WmlBlock>[];
        for (final Widget child in widget.children) {
          out.addAll(blocks(child));
        }
        return out;
      case Row():
        return <WmlBlock>[_row(widget)];
      case Flexible():
        return blocks(widget.child);
      case Flex():
        return widget.direction == Axis.horizontal
            ? <WmlBlock>[
                _row(
                  Row(
                    children: widget.children,
                    mainAxisAlignment: widget.mainAxisAlignment,
                    crossAxisAlignment: widget.crossAxisAlignment,
                  ),
                ),
              ]
            : _columnChildren(widget.children);
      case ListView():
        return _listView(widget);
      case Wrap():
        return _columnChildren(widget.children, gap: widget.runSpacing);
      case GridView():
        return <WmlBlock>[_grid(widget)];
      case Theme():
        final _Walk nested = fork(
          ctx: Context(
            theme: widget.data,
            pageFormat: ctx.pageFormat,
            textDirection: ctx.textDirection,
            pageNumber: ctx.pageNumber,
            pagesCount: ctx.pagesCount,
          ),
        );
        return nested.blocks(widget.child);
      case Table():
        return <WmlBlock>[_table(widget)];
      case Image():
        return <WmlBlock>[
          WmlVisual(
            visual: OfficeVisual(
              kind: OfficeVisualKind.picture,
              imageBytes: widget.image.bytes,
              width: widget.width ?? 240,
              height: widget.height ?? 160,
            ),
          ),
        ];
      case Chart():
        return <WmlBlock>[
          WmlVisual(
            visual: OfficeVisual(
              kind: widget.kind,
              title: widget.title,
              points: widget.points,
              width: widget.width,
              height: widget.height,
            ),
          ),
        ];
      case UrlLink():
        return fork(linkUrl: widget.destination).blocks(widget.child);
      case Link():
        return fork(linkAnchor: widget.destination).blocks(widget.child);
      case Container():
        return _container(widget);
      case DecoratedBox():
        return fork(
          fill: widget.decoration.color,
          borderColor: widget.decoration.border?.stroke,
        ).blocks(widget.child);
      case ConstrainedBox():
        return blocks(widget.child);
      case LimitedBox():
        return blocks(widget.child);
      case AspectRatio():
        return blocks(widget.child);
      case FittedBox():
        return blocks(widget.child);
      case FullPage():
        return blocks(widget.child);
      case OverflowBox():
        return blocks(widget.child);
      case Opacity():
        return blocks(widget.child);
      case VerticalDivider():
        return <WmlBlock>[
          _divider(
            Divider(
              height: widget.width,
              thickness: widget.thickness,
              color: widget.color,
            ),
          ),
        ];
      case Directionality():
        return fork(
          ctx: Context(
            theme: ctx.theme,
            pageFormat: ctx.pageFormat,
            textDirection: widget.textDirection,
            pageNumber: ctx.pageNumber,
            pagesCount: ctx.pagesCount,
          ),
        ).blocks(widget.child);
      case DefaultTextStyle():
        return fork(
          ctx: Context(
            theme: ctx.theme.copyWith(
              defaultTextStyle: widget.style,
              textAlign: widget.textAlign,
            ),
            pageFormat: ctx.pageFormat,
            textDirection: ctx.textDirection,
            pageNumber: ctx.pageNumber,
            pagesCount: ctx.pagesCount,
          ),
        ).blocks(widget.child);
      case Builder():
        return blocks(widget.builder(ctx));
      case Inseparable():
        return fork(keepTogether: !widget.canSpan).blocks(widget.child);
      case Anchor():
        return fork(bookmark: widget.name).blocks(
          widget.child ?? const SizedBox(),
        );
      case Watermark():
        stamps.add(_plainText(widget.child));
        return <WmlBlock>[];
      case TableOfContent():
        return <WmlBlock>[
          WmlToc(
            title: widget.title,
            minLevel: widget.minLevel,
            maxLevel: widget.maxLevel,
            showPageNumbers: widget.showPageNumbers,
          ),
        ];
      case Placeholder():
        return <WmlBlock>[
          paragraph(
            <WmlInline>[WmlRun(text: '', properties: _run(null))],
            before: widget.fallbackHeight / 4,
            after: widget.fallbackHeight / 4,
          )..properties.borderColor = _hex(widget.color) ?? widget.color,
        ];
      case Lorem():
        return <WmlBlock>[
          paragraph(_inlinesFromText(LoremText.generate(words: widget.length), null)),
        ];
      case Icon():
        return <WmlBlock>[_icon(widget)];
      case Checkbox():
        return <WmlBlock>[
          paragraph(
            _inlinesFromText(
              '${widget.value ? '☑' : '☐'} ${widget.name}'.trim(),
              null,
            ),
          ),
        ];
      case TextField():
        return <WmlBlock>[
          fork(borderColor: ctx.theme.rule).paragraph(
            _inlinesFromText(widget.value, null),
          ),
        ];
      case Circle():
        return <WmlBlock>[_shapeFrame(widget.width, widget.height, widget.fillColor, widget.strokeColor)];
      case Rectangle():
        return <WmlBlock>[_shapeFrame(widget.width, widget.height, widget.fillColor, widget.strokeColor)];
      case Stack():
        return _stack(widget);
      case Positioned():
        return <WmlBlock>[
          WmlFrame(
            x: widget.left ?? 72,
            y: widget.top ?? 72,
            width: widget.width ?? 200,
            height: widget.height ?? 80,
            blocks: blocks(widget.child),
          ),
        ];
      case Partition():
        return blocks(widget.child);
      case Partitions():
        return <WmlBlock>[_partitions(widget)];
    }
  }

  List<WmlParagraph> chrome(Widget widget) {
    if (widget is Footer) {
      final WmlParagraph row = _footerParagraph(widget);
      _stampFields(row);
      return <WmlParagraph>[row];
    }
    final List<WmlBlock> produced = blocks(widget);
    final List<WmlParagraph> out = <WmlParagraph>[];
    for (final WmlBlock block in produced) {
      if (block is WmlParagraph) {
        _stampFields(block);
        out.add(block);
      } else if (block is WmlTable) {
        for (final WmlTableRow row in block.rows) {
          for (final WmlTableCell cell in row.cells) {
            for (final WmlBlock inner in cell.blocks) {
              if (inner is WmlParagraph) {
                _stampFields(inner);
                out.add(inner);
              }
            }
          }
        }
      }
    }
    return out;
  }

  void _stampFields(WmlParagraph paragraph) {
    final String text = paragraph.text;
    if (text.trim() == '${ctx.pageNumber}') {
      WordFields.stamp(paragraph, WmlFieldKind.page, result: '${ctx.pageNumber}');
    }
  }

  WmlParagraph _paragraphWidget(Paragraph widget) {
    final EdgeInsets pad = widget.padding ?? EdgeInsets.zero;
    return paragraph(
      _inlinesFromText(
        widget.text ?? '',
        ctx.theme.paragraphStyle.merge(widget.style),
      ),
      align: widget.textAlign,
      before: widget.margin.top + pad.top,
      after: widget.margin.bottom + pad.bottom,
      indentLeft: widget.margin.left + pad.left,
      indentRight: widget.margin.right + pad.right,
    );
  }

  WmlParagraph _header(Header widget) {
    final int level = widget.level.clamp(0, 5);
    final TextStyle style = ctx.theme.headerStyle(level).merge(widget.textStyle);
    final EdgeInsets margin =
        widget.margin ??
        EdgeInsets.only(
          top: level == 0 ? 0 : (level == 1 ? 3 : 2) * PdfPageFormat.mm,
          bottom: (level <= 1 ? 5 : 4) * PdfPageFormat.mm,
        );
    final EdgeInsets pad = widget.padding ?? EdgeInsets.zero;
    final List<WmlInline> inlines = widget.text != null
        ? _inlinesFromText(widget.text!, style)
        : _firstInlines(widget.child!);
    final WmlParagraph paragraph = this.paragraph(
      inlines,
      before: margin.top + pad.top,
      after: margin.bottom + pad.bottom,
    );
    if (level == 0) {
      WordStyles.apply(paragraph, 'Title');
    } else {
      WordStyles.apply(paragraph, 'Heading$level');
    }
    paragraph.properties
      ..rightToLeft = ctx.rtl ? true : paragraph.properties.rightToLeft
      ..justification = ctx.rtl
          ? WmlJustification.right
          : paragraph.properties.justification;
    for (final WmlInline inline in paragraph.inlines) {
      if (inline is! WmlRun) {
        continue;
      }
      _applyStyle(inline.properties, style);
    }
    return paragraph;
  }

  List<WmlBlock> _listItem(
    Widget child, {
    required bool numbered,
    required int level,
    required EdgeInsets margin,
    EdgeInsets? padding,
  }) {
    final List<WmlBlock> produced = _padded(
      EdgeInsets.only(
        left: margin.left + (padding?.left ?? 0),
        right: margin.right + (padding?.right ?? 0),
        top: margin.top + (padding?.top ?? 0),
        bottom: margin.bottom + (padding?.bottom ?? 0),
      ),
      child,
    );
    if (produced.isEmpty) {
      final WmlParagraph empty = paragraph(<WmlInline>[WmlRun(text: '')]);
      WordLists.applyLevel(empty, numbered: numbered, level: level);
      return <WmlBlock>[empty];
    }
    final WmlBlock first = produced.first;
    if (first is WmlParagraph) {
      WordLists.applyLevel(first, numbered: numbered, level: level);
      if (numbered) {
        numberedSeq[0] += 1;
        first.properties.listLabel = '${numberedSeq[0]}. ';
      } else {
        numberedSeq[0] = 0;
      }
    }
    return produced;
  }

  List<WmlBlock> _padded(EdgeInsets pad, Widget child) {
    final List<WmlBlock> inner = blocks(child);
    for (final WmlBlock block in inner) {
      if (block is! WmlParagraph) {
        continue;
      }
      block.properties
        ..spacingBefore = block.properties.spacingBefore + pad.top
        ..spacingAfter = block.properties.spacingAfter + pad.bottom
        ..indent = WmlIndent(
          left: block.properties.indent.left + pad.left,
          right: block.properties.indent.right + pad.right,
        );
    }
    return inner;
  }

  WmlParagraph _divider(Divider widget) {
    return WmlParagraph(
      inlines: <WmlInline>[WmlRun(text: '', properties: _run(null))],
      properties: WmlParagraphProps(
        spacingBefore: ((widget.height ?? 16) - (widget.thickness ?? 1)) / 2,
        spacingAfter: ((widget.height ?? 16) - (widget.thickness ?? 1)) / 2,
        borderColor: _hex(widget.color) ?? ctx.theme.rule,
        justification: _justify(null),
        rightToLeft: ctx.rtl ? true : null,
      ),
    );
  }

  WmlTable _row(Row widget) {
    final List<int> flex = <int>[
      for (final Widget child in widget.children)
        child is Flexible ? (child.flex < 1 ? 1 : child.flex) : 1,
    ];
    final int sum = flex.fold<int>(0, (int a, int b) => a + b);
    final double total = ctx.pageFormat.contentWidth;
    final List<double> grid = <double>[
      for (final int f in flex) total * (f / (sum == 0 ? 1 : sum)),
    ];
    final List<WmlTableCell> cells = <WmlTableCell>[];
    for (int i = 0; i < widget.children.length; i++) {
      Widget child = widget.children[i];
      if (child is Flexible) {
        child = child.child;
      }
      cells.add(WmlTableCell(width: grid[i], blocks: blocks(child)));
    }
    return WmlTable(
      grid: grid,
      rows: <WmlTableRow>[WmlTableRow(cells: cells)],
      properties: WmlTableProps(
        alignment: _justify(null),
        rightToLeft: ctx.rtl,
        borders: false,
      ),
    );
  }

  WmlTable _footerRow(Footer widget) {
    return _row(
      Row(
        children: <Widget>[
          widget.leading ?? const SizedBox(),
          Expanded(child: widget.title ?? const SizedBox()),
          widget.trailing ?? const SizedBox(),
        ],
      ),
    );
  }

  WmlParagraph _footerParagraph(Footer widget) {
    final List<WmlInline> inlines = <WmlInline>[
      ..._firstInlines(widget.leading ?? const SizedBox()),
      WmlRun(text: '\t', properties: _run(null)),
      ..._firstInlines(widget.title ?? const SizedBox()),
      WmlRun(text: '\t', properties: _run(null)),
      ..._firstInlines(widget.trailing ?? const SizedBox()),
    ];
    final double width = ctx.pageFormat.contentWidth;
    return WmlParagraph(
      inlines: inlines,
      properties: WmlParagraphProps(
        justification: ctx.rtl ? WmlJustification.right : WmlJustification.left,
        rightToLeft: ctx.rtl ? true : null,
        tabs: <WmlTabStop>[
          WmlTabStop(position: width / 2, alignment: WmlTabAlignment.center),
          WmlTabStop(position: width, alignment: WmlTabAlignment.right),
        ],
      ),
    );
  }

  WmlTable _table(Table widget) {
    var cols = 1;
    for (final TableRow row in widget.children) {
      if (row.children.length > cols) {
        cols = row.children.length;
      }
    }
    final double total = ctx.pageFormat.contentWidth;
    final List<double> grid = widget.columnWidths == null
        ? List<double>.filled(cols, total / cols)
        : <double>[
            for (int i = 0; i < cols; i++)
              i < widget.columnWidths!.length
                  ? widget.columnWidths![i]
                  : total / cols,
          ];
    final String headerFill = widget is _TableFromArray
        ? (widget.headerFill ?? ctx.theme.tableHeaderFill)
        : ctx.theme.tableHeaderFill;
    final String oddFill = widget is _TableFromArray
        ? (widget.oddFill ?? ctx.theme.tableBandFill)
        : ctx.theme.tableBandFill;
    final bool banded = widget is _TableFromArray ? widget.banded : true;
    var dataIndex = 0;
    final List<WmlTableRow> rows = <WmlTableRow>[];
    for (final TableRow row in widget.children) {
      final bool header = row.repeat;
      final bool band = banded && !header && dataIndex.isOdd;
      final List<WmlTableCell> cells = <WmlTableCell>[];
      for (int i = 0; i < row.children.length; i++) {
        final List<WmlBlock> inner = header
            ? _headerCells(row.children[i])
            : blocks(row.children[i]);
        cells.add(
          WmlTableCell(
            fillColor: header
                ? headerFill
                : band
                ? oddFill
                : null,
            width: i < grid.length ? grid[i] : null,
            blocks: inner.isEmpty
                ? <WmlBlock>[paragraph(<WmlInline>[WmlRun(text: '')])]
                : inner,
          ),
        );
      }
      if (!header) {
        dataIndex++;
      }
      rows.add(WmlTableRow(cells: cells));
    }
    return WmlTable(
      grid: grid,
      rows: rows,
      properties: WmlTableProps(
        alignment: _justify(null),
        rightToLeft: ctx.rtl,
        borders: widget.border,
        borderColor: ctx.theme.rule,
      ),
    );
  }

  List<WmlBlock> _headerCells(Widget child) {
    final List<WmlBlock> inner = blocks(child);
    for (final WmlBlock block in inner) {
      if (block is! WmlParagraph) {
        continue;
      }
      for (final WmlInline inline in block.inlines) {
        if (inline is WmlRun) {
          _applyStyle(inline.properties, ctx.theme.tableHeader);
        }
      }
    }
    return inner;
  }

  List<WmlInline> _firstInlines(Widget widget) {
    if (widget is Text) {
      return _inlinesFromText(widget.text, widget.style);
    }
    if (widget is RichText) {
      return _inlinesFromSpan(widget.text, null);
    }
    if (widget is SizedBox && widget.child != null) {
      return _firstInlines(widget.child!);
    }
    if (widget is Padding) {
      return _firstInlines(widget.child);
    }
    if (widget is Align) {
      return _firstInlines(widget.child);
    }
    if (widget is UrlLink) {
      return fork(linkUrl: widget.destination)._firstInlines(widget.child);
    }
    if (widget is Link) {
      return fork(linkAnchor: widget.destination)._firstInlines(widget.child);
    }
    return <WmlInline>[WmlRun(text: '', properties: _run(null))];
  }

  List<WmlInline> _inlinesFromText(String text, TextStyle? style) {
    return <WmlInline>[
      WmlRun(
        text: text,
        properties: _run(style),
        hyperlink: _hyperlink(),
      ),
    ];
  }

  List<WmlInline> _inlinesFromSpan(InlineSpan span, TextStyle? parent) {
    if (span is! TextSpan) {
      return <WmlInline>[];
    }
    final TextStyle? merged = parent == null ? span.style : parent.merge(span.style);
    final List<WmlInline> out = <WmlInline>[];
    if (span.text != null && span.text!.isNotEmpty) {
      out.add(
        WmlRun(
          text: span.text!,
          properties: _run(merged),
          hyperlink: _hyperlink(),
        ),
      );
    }
    for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
      out.addAll(_inlinesFromSpan(child, merged));
    }
    if (out.isEmpty) {
      out.add(WmlRun(text: '', properties: _run(merged)));
    }
    return out;
  }

  WmlHyperlink? _hyperlink() {
    if (linkUrl != null) {
      return WmlHyperlink(url: linkUrl);
    }
    if (linkAnchor != null) {
      return WmlHyperlink(anchor: linkAnchor);
    }
    return null;
  }

  WmlParagraph paragraph(
    List<WmlInline> inlines, {
    TextAlign? align,
    TextDirection? direction,
    double? before,
    double? after,
    double indentLeft = 0,
    double indentRight = 0,
  }) {
    final bool rtl =
        (direction ?? ctx.textDirection) == TextDirection.rtl;
    return WmlParagraph(
      inlines: inlines.isEmpty
          ? <WmlInline>[WmlRun(text: '', properties: _run(null))]
          : inlines,
      properties: WmlParagraphProps(
        justification: _justify(align),
        spacingBefore: before ?? 0,
        spacingAfter: after ?? 8,
        indent: WmlIndent(left: indentLeft, right: indentRight),
        rightToLeft: rtl ? true : null,
        shadingFill: _hex(fill),
        borderColor: _hex(borderColor),
        keepTogether: keepTogether,
        bookmarkName: bookmark,
      ),
    );
  }

  WmlRunProps _run(TextStyle? style) {
    final TextStyle merged = ctx.theme.defaultTextStyle.merge(style);
    return WmlRunProps(
      bold: merged.fontWeight == FontWeight.bold,
      italic: merged.fontStyle == FontStyle.italic,
      underline: merged.decoration?.contains(TextDecoration.underline) == true
          ? WmlUnderline.single
          : WmlUnderline.none,
      color: _hex(merged.color) ?? '000000',
      fontSizeHalfPoints: ((merged.fontSize ?? 11) * 2).round(),
      asciiFont: merged.font ?? ctx.theme.defaultTextStyle.font ?? 'Calibri',
      csFont: merged.font ?? ctx.theme.defaultTextStyle.font ?? 'Arial',
    );
  }

  void _applyStyle(WmlRunProps props, TextStyle style) {
    final WmlRunProps next = _run(style);
    props
      ..bold = next.bold
      ..italic = next.italic
      ..underline = next.underline
      ..color = next.color
      ..fontSizeHalfPoints = next.fontSizeHalfPoints
      ..asciiFont = next.asciiFont
      ..csFont = next.csFont;
  }

  TextAlign _textAlignOf(Alignment alignment) {
    if (alignment.x < -0.3) {
      return TextAlign.left;
    }
    if (alignment.x > 0.3) {
      return TextAlign.right;
    }
    return TextAlign.center;
  }

  WmlJustification _justify(TextAlign? align) {
    final TextAlign resolved =
        align ??
        alignOverride ??
        ctx.theme.textAlign ??
        (ctx.rtl ? TextAlign.right : TextAlign.left);
    return switch (resolved) {
      TextAlign.left || TextAlign.start =>
        ctx.rtl && resolved == TextAlign.start
            ? WmlJustification.right
            : WmlJustification.left,
      TextAlign.right || TextAlign.end =>
        ctx.rtl && resolved == TextAlign.end
            ? WmlJustification.left
            : WmlJustification.right,
      TextAlign.center => WmlJustification.center,
      TextAlign.justify => WmlJustification.justify,
    };
  }

  List<WmlBlock> _rich(RichText widget) {
    final List<WmlBlock> out = <WmlBlock>[];
    final List<WmlInline> current = <WmlInline>[];
    void flush() {
      if (current.isEmpty) {
        return;
      }
      out.add(
        paragraph(
          List<WmlInline>.from(current),
          align: widget.textAlign,
          direction: widget.textDirection,
        ),
      );
      current.clear();
    }

    void visit(InlineSpan span, TextStyle? parent) {
      switch (span) {
        case TextSpan():
          final TextStyle? merged =
              parent == null ? span.style : parent.merge(span.style);
          if (span.text != null && span.text!.isNotEmpty) {
            current.add(
              WmlRun(
                text: span.text!,
                properties: _run(merged),
                hyperlink: _hyperlink(),
              ),
            );
          }
          for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
            visit(child, merged);
          }
        case WidgetSpan():
          flush();
          out.addAll(blocks(span.child));
      }
    }

    visit(widget.text, null);
    flush();
    if (out.isEmpty) {
      out.add(
        paragraph(
          <WmlInline>[WmlRun(text: '', properties: _run(null))],
          align: widget.textAlign,
          direction: widget.textDirection,
        ),
      );
    }
    return out;
  }

  List<WmlBlock> _columnChildren(List<Widget> children, {double gap = 0}) {
    final List<WmlBlock> out = <WmlBlock>[];
    for (int i = 0; i < children.length; i++) {
      out.addAll(blocks(children[i]));
      if (gap > 0 && i < children.length - 1) {
        out.add(
          paragraph(<WmlInline>[WmlRun(text: '')], before: gap, after: 0),
        );
      }
    }
    return out;
  }

  List<WmlBlock> _listView(ListView widget) {
    final List<Widget> items = <Widget>[];
    if (widget.itemBuilder != null) {
      for (int i = 0; i < widget.itemCount; i++) {
        final int index = widget.reverse ? widget.itemCount - 1 - i : i;
        items.add(widget.itemBuilder!(ctx, index));
        if (widget.separatorBuilder != null && i < widget.itemCount - 1) {
          items.add(widget.separatorBuilder!(ctx, index));
        }
      }
    } else {
      items.addAll(widget.reverse ? widget.children.reversed : widget.children);
    }
    final List<WmlBlock> out = _columnChildren(items, gap: widget.spacing);
    return widget.padding == null ? out : _wrapPadding(widget.padding!, out);
  }

  List<WmlBlock> _wrapPadding(EdgeInsets pad, List<WmlBlock> inner) {
    for (final WmlBlock block in inner) {
      if (block is! WmlParagraph) {
        continue;
      }
      block.properties
        ..spacingBefore = block.properties.spacingBefore + pad.top
        ..spacingAfter = block.properties.spacingAfter + pad.bottom
        ..indent = WmlIndent(
          left: block.properties.indent.left + pad.left,
          right: block.properties.indent.right + pad.right,
        );
    }
    return inner;
  }

  WmlTable _grid(GridView widget) {
    final int cols = widget.crossAxisCount < 1 ? 1 : widget.crossAxisCount;
    final List<TableRow> rows = <TableRow>[];
    for (int i = 0; i < widget.children.length; i += cols) {
      final int end = (i + cols) > widget.children.length
          ? widget.children.length
          : i + cols;
      rows.add(TableRow(children: widget.children.sublist(i, end)));
    }
    return _table(
      Table(children: rows, border: false),
    );
  }

  List<WmlBlock> _container(Container widget) {
    final BoxDecoration? deco = widget.resolvedDecoration;
    Widget child = widget.child ?? const SizedBox();
    if (widget.alignment != null) {
      child = Align(alignment: widget.alignment!, child: child);
    }
    if (widget.padding != null) {
      child = Padding(padding: widget.padding!, child: child);
    }
    if (widget.margin != null) {
      child = Padding(padding: widget.margin!, child: child);
    }
    return fork(
      fill: deco?.color,
      borderColor: deco?.border?.stroke,
    ).blocks(child);
  }

  WmlParagraph _icon(Icon widget) {
    final IconThemeData theme = ctx.theme.iconTheme;
    final String glyph = String.fromCharCode(widget.icon.codePoint);
    return paragraph(
      _inlinesFromText(
        glyph,
        TextStyle(
          fontSize: widget.size ?? theme.size,
          color: widget.color ?? theme.color,
          font: widget.font ?? theme.font,
        ),
      ),
    );
  }

  WmlFrame _shapeFrame(
    double width,
    double height,
    String? fill,
    String? stroke,
  ) {
    return WmlFrame(
      width: width,
      height: height,
      fillColor: _hex(fill),
      strokeColor: _hex(stroke),
    );
  }

  List<WmlBlock> _stack(Stack widget) {
    final List<WmlBlock> out = <WmlBlock>[];
    for (final Widget child in widget.children) {
      if (child is Positioned) {
        out.add(
          WmlFrame(
            x: child.left ?? 72,
            y: child.top ?? 72,
            width: child.width ?? 200,
            height: child.height ?? 80,
            blocks: blocks(child.child),
          ),
        );
      } else {
        out.addAll(blocks(child));
      }
    }
    return out;
  }

  WmlTable _partitions(Partitions widget) {
    final List<int> flex = <int>[
      for (final Partition part in widget.children)
        part.width != null ? 0 : (part.flex < 1 ? 1 : part.flex),
    ];
    final double reserved = widget.children.fold<double>(
      0,
      (double sum, Partition part) => sum + (part.width ?? 0),
    );
    final int flexSum = flex.fold<int>(0, (int a, int b) => a + b);
    final double rest = (ctx.pageFormat.contentWidth - reserved).clamp(
      24,
      ctx.pageFormat.contentWidth,
    );
    final List<double> grid = <double>[
      for (int i = 0; i < widget.children.length; i++)
        widget.children[i].width ??
            rest * (flex[i] / (flexSum == 0 ? 1 : flexSum)),
    ];
    return WmlTable(
      grid: grid,
      rows: <WmlTableRow>[
        WmlTableRow(
          cells: <WmlTableCell>[
            for (int i = 0; i < widget.children.length; i++)
              WmlTableCell(
                width: grid[i],
                blocks: blocks(widget.children[i].child),
              ),
          ],
        ),
      ],
      properties: WmlTableProps(borders: false, rightToLeft: ctx.rtl),
    );
  }

  String _plainText(Widget widget) {
    if (widget is Text) {
      return widget.text;
    }
    if (widget is Paragraph) {
      return widget.text ?? '';
    }
    if (widget is Header) {
      return widget.text ?? '';
    }
    if (widget is SizedBox && widget.child != null) {
      return _plainText(widget.child!);
    }
    return '';
  }
}

String? _hex(String? color) {
  if (color == null || color.isEmpty) {
    return null;
  }
  final String hex = color.replaceFirst('#', '').toUpperCase();
  return hex.length == 6 ? hex : null;
}
