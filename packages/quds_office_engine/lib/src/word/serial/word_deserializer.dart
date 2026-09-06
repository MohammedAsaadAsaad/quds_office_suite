import 'dart:typed_data';

import '../../opc/ole/embedded_part.dart';
import '../../opc/opc_archive.dart';
import '../../opc/package_part.dart';
import '../../opc/relationships.dart';
import '../../visual/office_visual.dart';
import '../../xml/namespaces.dart';
import '../../xml/xml_reader.dart';
import '../math/omml_document.dart';
import '../math/omml_io.dart';
import '../model/wml_document.dart';
import '../model/word_comment.dart';
import '../model/word_link.dart';
import '../model/word_toc.dart';
import '../properties/wml_properties.dart';
import 'word_drawing_io.dart';

/// Reads a `.docx` OPC package into a [WmlDocument] tree.
class WordDeserializer {
  final List<WmlEquation> _pendingEquations = <WmlEquation>[];
  final List<WmlVisual> _pendingVisuals = <WmlVisual>[];
  final List<int> _openCommentIds = <int>[];
  OpcPackage? _package;
  String? _docUri;
  WmlSection? _pendingParagraphSectPr;

  /// read API.
  WmlDocument read(OpcPackage package) {
    final PackageRelationship? office = package.packageRelationships
        .firstByType(RelationshipTypes.officeDocument);
    final String docUri = office == null
        ? '/word/document.xml'
        : package.packageRelationships.resolve(office);
    final PackagePart? part = package.getPart(docUri);
    if (part == null) {
      return WmlDocument(package: package);
    }
    final XmlPullReader reader = XmlPullReader(part.readText());
    final WmlDocument document = WmlDocument(
      package: package,
      sections: <WmlSection>[],
    );
    _package = package;
    _docUri = docUri;
    _pendingParagraphSectPr = null;
    WmlSection section = WmlSection();
    while (reader.next()) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      if (reader.localName == 'p' &&
          reader.namespaceUri == OfficeNamespaces.w) {
        _addParagraph(section.blocks, _readParagraph(reader, package, docUri));
        section = _flushParagraphSectPr(document, section);
      } else if ((reader.localName == 'oMathPara' ||
              reader.localName == 'oMath') &&
          (reader.namespaceUri == OfficeNamespaces.m || reader.prefix == 'm')) {
        final OmmlEquation? math = OmmlIo.readFrom(reader);
        if (math != null) {
          section.blocks.add(WmlEquation(math: math));
        }
      } else if (reader.localName == 'tbl' &&
          reader.namespaceUri == OfficeNamespaces.w) {
        section.blocks.add(_readTable(reader, package, docUri));
      } else if (reader.localName == 'sdt' &&
          reader.namespaceUri == OfficeNamespaces.w) {
        section.blocks.addAll(_readSdt(reader, package, docUri));
      } else if (reader.localName == 'sectPr' &&
          reader.namespaceUri == OfficeNamespaces.w) {
        _readSectPr(reader, section, package, docUri);
        document.sections.add(section);
        section = WmlSection();
      }
    }
    if (section.blocks.isNotEmpty || document.sections.isEmpty) {
      document.sections.add(section);
    }
    _ensureHeadersFooters(document, package, docUri);
    _applyNumbering(document, package, docUri);
    _collapseTocFields(document);
    _readComments(document, package, docUri);
    _readCommentsExtended(document, package, docUri);
    return document;
  }

  /// readBytes API.
  WmlDocument readBytes(Uint8List bytes, {String? password}) =>
      read(OpcPackage.openBytes(bytes, password: password));

  List<WmlBlock> _readSdt(
    XmlPullReader reader,
    OpcPackage package,
    String docUri,
  ) {
    var tag = '';
    final List<WmlBlock> blocks = <WmlBlock>[];
    if (reader.isEmptyElement) {
      return blocks;
    }
    final int depth = reader.depth;
    while (reader.next() && reader.depth >= depth) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      if (reader.localName == 'tag') {
        tag =
            reader.getAttribute('val', namespaceUri: OfficeNamespaces.w) ?? tag;
      } else if (reader.localName == 'p' &&
          reader.namespaceUri == OfficeNamespaces.w) {
        _addParagraph(blocks, _readParagraph(reader, package, docUri));
      } else if (reader.localName == 'tbl' &&
          reader.namespaceUri == OfficeNamespaces.w) {
        blocks.add(_readTable(reader, package, docUri));
      } else if (reader.localName == 'sdt' &&
          reader.namespaceUri == OfficeNamespaces.w) {
        blocks.addAll(_readSdt(reader, package, docUri));
      }
    }
    if (tag.startsWith('qudsFrame:')) {
      return <WmlBlock>[_frameFromTag(tag, blocks)];
    }
    return blocks;
  }

  WmlFrame _frameFromTag(String tag, List<WmlBlock> blocks) {
    final List<String> parts = tag.substring('qudsFrame:'.length).split(',');
    double numAt(int i, double fallback) =>
        i < parts.length ? double.tryParse(parts[i]) ?? fallback : fallback;
    final String anchorName = parts.length > 4 ? parts[4] : 'page';
    final String wrapName = parts.length > 5 ? parts[5] : 'none';
    String? colorAt(int i) {
      if (i >= parts.length || parts[i].isEmpty) {
        return null;
      }
      return parts[i];
    }

    return WmlFrame(
      x: numAt(0, 72),
      y: numAt(1, 72),
      width: numAt(2, 200),
      height: numAt(3, 120),
      anchor: anchorName == 'margin'
          ? WmlFrameAnchor.margin
          : WmlFrameAnchor.page,
      wrap: wrapName == 'square' ? WmlFrameWrap.square : WmlFrameWrap.none,
      fillColor: colorAt(6),
      strokeColor: colorAt(7),
      blocks: blocks,
    );
  }

  void _addParagraph(List<WmlBlock> blocks, WmlParagraph paragraph) {
    final bool mathOnly =
        paragraph.inlines.isEmpty && _pendingEquations.isNotEmpty;
    if (!mathOnly) {
      blocks.add(paragraph);
    }
    _flushPending(blocks);
  }

  void _flushPending(List<WmlBlock> blocks) {
    if (_pendingVisuals.isNotEmpty) {
      blocks.addAll(_pendingVisuals);
      _pendingVisuals.clear();
    }
    if (_pendingEquations.isNotEmpty) {
      blocks.addAll(_pendingEquations);
      _pendingEquations.clear();
    }
  }

  bool _takeDrawing(XmlPullReader reader, OpcPackage package, String docUri) {
    if (reader.localName != 'drawing') {
      return false;
    }
    final OfficeVisual? visual = WordDrawingIo.read(reader, package, docUri);
    if (visual != null) {
      _pendingVisuals.add(WmlVisual(visual: visual));
    }
    return true;
  }

  WmlParagraph _readParagraph(
    XmlPullReader reader,
    OpcPackage package,
    String docUri,
  ) {
    final WmlParagraph paragraph = WmlParagraph();
    if (reader.isEmptyElement) {
      return paragraph;
    }
    final int depth = reader.depth;
    while (reader.next() && reader.depth >= depth) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      if (reader.localName == 'pPr') {
        _readPPr(reader, paragraph.properties);
      } else if (reader.localName == 'r') {
        paragraph.inlines.addAll(
          _readRunInlines(reader, package, docUri, paragraph),
        );
      } else if (reader.localName == 'hyperlink') {
        paragraph.inlines.addAll(
          _readHyperlinkInlines(reader, package, docUri, paragraph),
        );
      } else if (reader.localName == 'commentRangeStart') {
        final int? id = int.tryParse(
          reader.getAttribute('id', namespaceUri: OfficeNamespaces.w) ?? '',
        );
        if (id != null && !_openCommentIds.contains(id)) {
          _openCommentIds.add(id);
        }
      } else if (reader.localName == 'commentRangeEnd') {
        final int? id = int.tryParse(
          reader.getAttribute('id', namespaceUri: OfficeNamespaces.w) ?? '',
        );
        if (id != null) {
          _openCommentIds.remove(id);
        }
      } else if (reader.localName == 'bookmarkStart') {
        paragraph.properties.bookmarkName ??= reader.getAttribute(
          'name',
          namespaceUri: OfficeNamespaces.w,
        );
      } else if (reader.localName == 'br') {
        final String? type = reader.getAttribute(
          'type',
          namespaceUri: OfficeNamespaces.w,
        );
        paragraph.inlines.add(
          WmlBreak(
            type == 'page'
                ? WmlBreakType.page
                : type == 'column'
                ? WmlBreakType.column
                : WmlBreakType.textWrapping,
          ),
        );
        if (type == 'column') {
          paragraph.properties.columnBreakBefore = true;
        }
      } else if (reader.localName == 'object' ||
          reader.localName == 'drawing') {
        if (!_takeDrawing(reader, package, docUri)) {
          final WmlObject? obj = _readObject(reader, package, docUri);
          if (obj != null) {
            paragraph.inlines.add(obj);
          }
        }
      } else if (reader.localName == 'oMath' ||
          reader.localName == 'oMathPara') {
        final OmmlEquation? math = OmmlIo.readFrom(reader);
        if (math != null) {
          _pendingEquations.add(WmlEquation(math: math));
        }
      }
    }
    return paragraph;
  }

  List<WmlInline> _readRunInlines(
    XmlPullReader reader,
    OpcPackage package,
    String docUri,
    WmlParagraph paragraph,
  ) {
    final List<WmlInline> inlines = <WmlInline>[];
    final WmlRun run = WmlRun();
    if (reader.isEmptyElement) {
      return inlines;
    }
    final int depth = reader.depth;
    while (reader.next() && reader.depth >= depth) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      if (reader.localName == 'rPr') {
        _readRPr(reader, run.properties);
      } else if (reader.localName == 't') {
        final String text = _elementText(reader);
        if (paragraph.properties.pageNumberField &&
            _cachedPageResult.hasMatch(text)) {
          continue;
        }
        run.text += text;
      } else if (reader.localName == 'instrText') {
        final String instr = _elementText(reader);
        paragraph.properties.fieldInstruction =
            '${paragraph.properties.fieldInstruction ?? ''}$instr';
        if (_isPageField(instr)) {
          paragraph.properties.pageNumberField = true;
        }
      } else if (reader.localName == 'fldChar') {
        final String? type = reader.getAttribute(
          'fldCharType',
          namespaceUri: OfficeNamespaces.w,
        );
        if (type == 'begin') {
          paragraph.properties.fieldBegin = true;
        } else if (type == 'end') {
          paragraph.properties.fieldEnd = true;
        }
      } else if (reader.localName == 'commentReference') {
        continue;
      } else if (reader.localName == 'tab') {
        run.text += '\t';
      } else if (reader.localName == 'object' ||
          reader.localName == 'drawing' ||
          reader.localName == 'OLEObject') {
        if (run.text.isNotEmpty) {
          inlines.add(WmlRun(text: run.text, properties: run.properties));
          run.text = '';
        }
        if (!_takeDrawing(reader, package, docUri)) {
          final WmlObject? obj = _readObject(reader, package, docUri);
          if (obj != null) {
            inlines.add(obj);
          }
        }
      }
    }
    if (run.text.isNotEmpty) {
      run.commentIds.addAll(_openCommentIds);
      inlines.add(run);
    }
    return inlines;
  }

  void _readPPr(XmlPullReader reader, WmlParagraphProps props) {
    if (reader.isEmptyElement) {
      return;
    }
    final int depth = reader.depth;
    while (reader.next() && reader.depth >= depth) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      switch (reader.localName) {
        case 'jc':
          props.justification = _jc(
            reader.getAttribute('val', namespaceUri: OfficeNamespaces.w),
          );
        case 'bidi':
          props.rightToLeft = _onOff(
            reader.getAttribute('val', namespaceUri: OfficeNamespaces.w),
          );
        case 'spacing':
          final String? before = reader.getAttribute(
            'before',
            namespaceUri: OfficeNamespaces.w,
          );
          final String? after = reader.getAttribute(
            'after',
            namespaceUri: OfficeNamespaces.w,
          );
          final String? line = reader.getAttribute(
            'line',
            namespaceUri: OfficeNamespaces.w,
          );
          final String? rule = reader.getAttribute(
            'lineRule',
            namespaceUri: OfficeNamespaces.w,
          );
          if (before != null) {
            props.spacingBefore = twipsToPoints(int.parse(before));
          }
          if (after != null) {
            props.spacingAfter = twipsToPoints(int.parse(after));
          }
          if (line != null) {
            if (rule == 'exact' || rule == 'atLeast') {
              props.lineSpacing = twipsToPoints(int.parse(line));
              props.lineSpacingRule = rule == 'exact'
                  ? WmlLineSpacingRule.exact
                  : WmlLineSpacingRule.atLeast;
            } else {
              props.lineSpacing = int.parse(line) / 240.0;
            }
          }
        case 'ind':
          props.indent = WmlIndent(
            left: _twipAttr(reader, 'left'),
            right: _twipAttr(reader, 'right'),
            firstLine: _twipAttr(reader, 'firstLine'),
            hanging: _twipAttr(reader, 'hanging'),
          );
        case 'keepLines':
          props.keepTogether = true;
        case 'pageBreakBefore':
          props.pageBreakBefore = true;
        case 'numPr':
          _readNumPr(reader, props);
        case 'tabs':
          _readTabs(reader, props);
        case 'pStyle':
          props.styleId = reader.getAttribute(
            'val',
            namespaceUri: OfficeNamespaces.w,
          );
          props.headingLevel ??= WordToc.headingLevelFromStyle(props.styleId);
        case 'outlineLvl':
          final String? raw = reader.getAttribute(
            'val',
            namespaceUri: OfficeNamespaces.w,
          );
          if (raw != null) {
            final int? outline = int.tryParse(raw);
            if (outline != null && outline >= 0 && outline <= 8) {
              props.headingLevel = outline + 1;
              props.styleId ??= 'Heading${outline + 1}';
            }
          }
        case 'sectPr':
          final OpcPackage? package = _package;
          final String? docUri = _docUri;
          if (package != null && docUri != null) {
            _pendingParagraphSectPr = WmlSection();
            _readSectPr(reader, _pendingParagraphSectPr!, package, docUri);
          }
      }
    }
  }

  WmlSection _flushParagraphSectPr(WmlDocument document, WmlSection section) {
    final WmlSection? pending = _pendingParagraphSectPr;
    if (pending == null) {
      return section;
    }
    _pendingParagraphSectPr = null;
    section.pageSize = pending.pageSize;
    section.margins = pending.margins;
    section.columnCount = pending.columnCount;
    section.columnSpace = pending.columnSpace;
    section.columnSep = pending.columnSep;
    if (section.header.isEmpty) {
      section.header.addAll(pending.header);
    }
    if (section.footer.isEmpty) {
      section.footer.addAll(pending.footer);
    }
    document.sections.add(section);
    return WmlSection();
  }

  List<WmlInline> _readHyperlinkInlines(
    XmlPullReader reader,
    OpcPackage package,
    String docUri,
    WmlParagraph paragraph,
  ) {
    final WmlHyperlink? link = _hyperlinkFrom(reader, package, docUri);
    final List<WmlInline> inlines = <WmlInline>[];
    if (reader.isEmptyElement) {
      return inlines;
    }
    final int depth = reader.depth;
    while (reader.next() && reader.depth >= depth) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      if (reader.localName == 'r') {
        for (final WmlInline inline in _readRunInlines(
          reader,
          package,
          docUri,
          paragraph,
        )) {
          if (inline is WmlRun) {
            inline.hyperlink = link;
            if (link != null && inline.properties.color == '000000') {
              WordLink.applyLook(inline);
            }
          }
          inlines.add(inline);
        }
      } else if (reader.localName == 'hyperlink') {
        inlines.addAll(
          _readHyperlinkInlines(reader, package, docUri, paragraph),
        );
      }
    }
    return inlines;
  }

  WmlHyperlink? _hyperlinkFrom(
    XmlPullReader reader,
    OpcPackage package,
    String docUri,
  ) {
    final String? anchor = reader.getAttribute(
      'anchor',
      namespaceUri: OfficeNamespaces.w,
    );
    if (anchor != null && anchor.isNotEmpty) {
      return WmlHyperlink(anchor: anchor);
    }
    final String? rid = reader.getAttribute(
      'id',
      namespaceUri: OfficeNamespaces.r,
    );
    if (rid == null || rid.isEmpty) {
      return null;
    }
    final PackageRelationship? rel = package.relationshipsFor(docUri).byId(rid);
    if (rel == null || rel.target.isEmpty) {
      return null;
    }
    return WmlHyperlink.fromTarget(rel.target);
  }

  void _collapseTocFields(WmlDocument document) {
    for (final WmlSection section in document.sections) {
      final List<WmlBlock> collapsed = <WmlBlock>[];
      WmlToc? open;
      for (final WmlBlock block in section.blocks) {
        if (block is! WmlParagraph) {
          if (open != null) {
            collapsed.add(open);
            open = null;
          }
          collapsed.add(block);
          continue;
        }
        final bool tocInstr = WordToc.isTocInstruction(
          block.properties.fieldInstruction,
        );
        final bool tocStyle =
            WordToc.tocLevelFromStyle(block.properties.styleId) != null;
        final bool tocHeading = WordToc.isTocHeadingStyle(
          block.properties.styleId,
        );
        final bool stillToc =
            tocInstr ||
            tocStyle ||
            tocHeading ||
            block.properties.fieldBegin ||
            block.properties.fieldEnd;
        if (open == null && (tocInstr || tocStyle || tocHeading)) {
          final (int min, int max) = WordToc.rangeFromInstruction(
            block.properties.fieldInstruction,
          );
          open = WmlToc(minLevel: min, maxLevel: max);
          WordToc.absorbResult(open, block);
          if (block.properties.fieldEnd) {
            collapsed.add(open);
            open = null;
          }
          continue;
        }
        if (open != null && stillToc) {
          if (tocInstr) {
            final (int min, int max) = WordToc.rangeFromInstruction(
              block.properties.fieldInstruction,
            );
            open.minLevel = min;
            open.maxLevel = max;
          }
          WordToc.absorbResult(open, block);
          if (block.properties.fieldEnd) {
            collapsed.add(open);
            open = null;
          }
          continue;
        }
        if (open != null) {
          collapsed.add(open);
          open = null;
        }
        collapsed.add(block);
      }
      if (open != null) {
        collapsed.add(open);
      }
      section.blocks
        ..clear()
        ..addAll(collapsed);
    }
  }

  void _readNumPr(XmlPullReader reader, WmlParagraphProps props) {
    if (reader.isEmptyElement) {
      return;
    }
    final int depth = reader.depth;
    while (reader.next() && reader.depth >= depth) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      final String? val = reader.getAttribute(
        'val',
        namespaceUri: OfficeNamespaces.w,
      );
      if (val == null) {
        continue;
      }
      if (reader.localName == 'ilvl') {
        props.ilvl = int.tryParse(val) ?? 0;
      } else if (reader.localName == 'numId') {
        props.numId = int.tryParse(val);
      }
    }
  }

  void _readTabs(XmlPullReader reader, WmlParagraphProps props) {
    if (reader.isEmptyElement) {
      return;
    }
    final int depth = reader.depth;
    while (reader.next() && reader.depth >= depth) {
      if (reader.eventType == XmlEventType.startElement &&
          reader.localName == 'tab') {
        final String? pos = reader.getAttribute(
          'pos',
          namespaceUri: OfficeNamespaces.w,
        );
        final String? val = reader.getAttribute(
          'val',
          namespaceUri: OfficeNamespaces.w,
        );
        final String? leader = reader.getAttribute(
          'leader',
          namespaceUri: OfficeNamespaces.w,
        );
        props.tabs.add(
          WmlTabStop(
            position: pos == null ? 0 : twipsToPoints(int.parse(pos)),
            alignment: switch (val) {
              'center' => WmlTabAlignment.center,
              'right' => WmlTabAlignment.right,
              'decimal' => WmlTabAlignment.decimal,
              _ => WmlTabAlignment.left,
            },
            leader: switch (leader) {
              'dot' => WmlTabLeader.dot,
              'hyphen' => WmlTabLeader.hyphen,
              'underscore' => WmlTabLeader.underscore,
              _ => WmlTabLeader.none,
            },
          ),
        );
      }
    }
  }

  void _readRPr(XmlPullReader reader, WmlRunProps props) {
    if (reader.isEmptyElement) {
      return;
    }
    final int depth = reader.depth;
    while (reader.next() && reader.depth >= depth) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      switch (reader.localName) {
        case 'b':
          props.bold =
              reader.getAttribute('val', namespaceUri: OfficeNamespaces.w) !=
              '0';
        case 'i':
          props.italic =
              reader.getAttribute('val', namespaceUri: OfficeNamespaces.w) !=
              '0';
        case 'strike':
          props.strike = true;
        case 'color':
          props.color =
              reader.getAttribute('val', namespaceUri: OfficeNamespaces.w) ??
              props.color;
        case 'highlight':
          props.highlight = reader.getAttribute(
            'val',
            namespaceUri: OfficeNamespaces.w,
          );
        case 'sz':
        case 'szCs':
          final String? sz = reader.getAttribute(
            'val',
            namespaceUri: OfficeNamespaces.w,
          );
          if (sz != null) {
            props.fontSizeHalfPoints = int.parse(sz);
          }
        case 'u':
          props.underline = switch (reader.getAttribute(
            'val',
            namespaceUri: OfficeNamespaces.w,
          )) {
            'double' => WmlUnderline.double,
            'dotted' => WmlUnderline.dotted,
            'wave' => WmlUnderline.wavy,
            'none' => WmlUnderline.none,
            _ => WmlUnderline.single,
          };
        case 'vertAlign':
          props.vertAlign = switch (reader.getAttribute(
            'val',
            namespaceUri: OfficeNamespaces.w,
          )) {
            'superscript' => WmlVertAlign.superscript,
            'subscript' => WmlVertAlign.subscript,
            _ => WmlVertAlign.baseline,
          };
        case 'rFonts':
          props.asciiFont =
              reader.getAttribute('ascii', namespaceUri: OfficeNamespaces.w) ??
              props.asciiFont;
          props.csFont =
              reader.getAttribute('cs', namespaceUri: OfficeNamespaces.w) ??
              props.csFont;
      }
    }
  }

  WmlTable _readTable(XmlPullReader reader, OpcPackage package, String docUri) {
    final WmlTable table = WmlTable();
    if (reader.isEmptyElement) {
      return table;
    }
    final int depth = reader.depth;
    while (reader.next() && reader.depth >= depth) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      if (reader.localName == 'bidiVisual') {
        table.properties.rightToLeft = true;
      } else if (reader.localName == 'gridCol') {
        final String? w = reader.getAttribute(
          'w',
          namespaceUri: OfficeNamespaces.w,
        );
        table.grid.add(w == null ? 100 : twipsToPoints(int.parse(w)));
      } else if (reader.localName == 'tr') {
        table.rows.add(_readRow(reader, package, docUri));
      }
    }
    return table;
  }

  WmlTableRow _readRow(
    XmlPullReader reader,
    OpcPackage package,
    String docUri,
  ) {
    final WmlTableRow row = WmlTableRow();
    if (reader.isEmptyElement) {
      return row;
    }
    final int depth = reader.depth;
    while (reader.next() && reader.depth >= depth) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      if (reader.localName == 'cantSplit') {
        row.cantSplit = true;
      } else if (reader.localName == 'trHeight') {
        final String? raw = reader.getAttribute(
          'val',
          namespaceUri: OfficeNamespaces.w,
        );
        if (raw != null) {
          row.height = twipsToPoints(int.parse(raw));
        }
      } else if (reader.localName == 'tc') {
        row.cells.add(_readCell(reader, package, docUri));
      }
    }
    return row;
  }

  WmlTableCell _readCell(
    XmlPullReader reader,
    OpcPackage package,
    String docUri,
  ) {
    final WmlTableCell cell = WmlTableCell();
    if (reader.isEmptyElement) {
      return cell;
    }
    final int depth = reader.depth;
    while (reader.next() && reader.depth >= depth) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      if (reader.localName == 'gridSpan') {
        cell.gridSpan = int.parse(
          reader.getAttribute('val', namespaceUri: OfficeNamespaces.w) ?? '1',
        );
      } else if (reader.localName == 'vMerge') {
        final String? val = reader.getAttribute(
          'val',
          namespaceUri: OfficeNamespaces.w,
        );
        cell.vMerge = val == 'restart' ? WmlVMerge.restart : WmlVMerge.cont;
      } else if (reader.localName == 'shd') {
        final String? fill = reader.getAttribute(
          'fill',
          namespaceUri: OfficeNamespaces.w,
        );
        if (fill != null &&
            fill.isNotEmpty &&
            fill.toLowerCase() != 'auto' &&
            fill.toUpperCase() != 'FFFFFF') {
          cell.fillColor = fill;
        }
      } else if (reader.localName == 'p') {
        _addParagraph(cell.blocks, _readParagraph(reader, package, docUri));
      } else if (reader.localName == 'oMathPara' ||
          reader.localName == 'oMath') {
        final OmmlEquation? math = OmmlIo.readFrom(reader);
        if (math != null) {
          cell.blocks.add(WmlEquation(math: math));
        }
      } else if (reader.localName == 'tbl') {
        cell.blocks.add(_readTable(reader, package, docUri));
      }
    }
    return cell;
  }

  void _readSectPr(
    XmlPullReader reader,
    WmlSection section,
    OpcPackage package,
    String docUri,
  ) {
    String? headerRid;
    String? footerRid;
    if (!reader.isEmptyElement) {
      final int depth = reader.depth;
      while (reader.next() && reader.depth >= depth) {
        if (reader.eventType != XmlEventType.startElement) {
          continue;
        }
        if (reader.localName == 'pgSz') {
          section.pageSize = WmlPageSize(
            width: _twipAttr(reader, 'w', fallback: section.pageSize.width),
            height: _twipAttr(reader, 'h', fallback: section.pageSize.height),
          );
        } else if (reader.localName == 'pgMar') {
          section.margins = WmlPageMargins(
            top: _twipAttr(reader, 'top', fallback: 72),
            bottom: _twipAttr(reader, 'bottom', fallback: 72),
            left: _twipAttr(reader, 'left', fallback: 72),
            right: _twipAttr(reader, 'right', fallback: 72),
          );
        } else if (reader.localName == 'cols') {
          section.columnCount = int.parse(
            reader.getAttribute('num', namespaceUri: OfficeNamespaces.w) ?? '1',
          );
          final String? space = reader.getAttribute(
            'space',
            namespaceUri: OfficeNamespaces.w,
          );
          if (space != null) {
            section.columnSpace = twipsToPoints(int.parse(space));
          }
          section.columnSep =
              reader.getAttribute('sep', namespaceUri: OfficeNamespaces.w) ==
              '1';
        } else if (reader.localName == 'headerReference') {
          headerRid = _relationshipId(reader) ?? headerRid;
        } else if (reader.localName == 'footerReference') {
          footerRid = _relationshipId(reader) ?? footerRid;
        }
      }
    }
    if (headerRid != null) {
      section.header.addAll(_readStoryByRid(package, docUri, headerRid));
    }
    if (footerRid != null) {
      section.footer.addAll(_readStoryByRid(package, docUri, footerRid));
    }
  }

  void _ensureHeadersFooters(
    WmlDocument document,
    OpcPackage package,
    String docUri,
  ) {
    final RelationshipCollection rels = package.relationshipsFor(docUri);
    final PackageRelationship? headerRel = rels.firstByType(
      RelationshipTypes.header,
    );
    final PackageRelationship? footerRel = rels.firstByType(
      RelationshipTypes.footer,
    );
    for (final WmlSection section in document.sections) {
      if (section.header.isEmpty && headerRel != null) {
        section.header.addAll(_readStoryByRid(package, docUri, headerRel.id));
      }
      if (section.footer.isEmpty && footerRel != null) {
        section.footer.addAll(_readStoryByRid(package, docUri, footerRel.id));
      }
    }
  }

  List<WmlParagraph> _readStoryByRid(
    OpcPackage package,
    String docUri,
    String rid,
  ) {
    final RelationshipCollection rels = package.relationshipsFor(docUri);
    final PackageRelationship? rel = rels.byId(rid);
    if (rel == null) {
      return <WmlParagraph>[];
    }
    final PackagePart? part = package.getPart(rels.resolve(rel));
    if (part == null) {
      return <WmlParagraph>[];
    }
    final List<WmlParagraph> paragraphs = <WmlParagraph>[];
    final XmlPullReader reader = XmlPullReader(part.readText());
    while (reader.next()) {
      if (reader.eventType == XmlEventType.startElement &&
          reader.localName == 'p' &&
          reader.namespaceUri == OfficeNamespaces.w) {
        paragraphs.add(_readParagraph(reader, package, docUri));
        _pendingEquations.clear();
      }
    }
    return paragraphs;
  }

  void _applyNumbering(
    WmlDocument document,
    OpcPackage package,
    String docUri,
  ) {
    final Map<int, _NumberingLevel> levels = _readNumbering(package, docUri);
    if (levels.isEmpty) {
      for (final WmlParagraph paragraph in document.paragraphs) {
        if (paragraph.properties.numId != null) {
          paragraph.properties.listLabel ??= '• ';
        }
      }
      return;
    }
    final Map<String, int> counters = <String, int>{};
    for (final WmlParagraph paragraph in document.paragraphs) {
      final int? numId = paragraph.properties.numId;
      if (numId == null) {
        continue;
      }
      final _NumberingLevel? level =
          levels[_levelKey(numId, paragraph.properties.ilvl)] ??
          levels[_levelKey(numId, 0)];
      if (level == null) {
        paragraph.properties.listLabel ??= '• ';
        continue;
      }
      if (level.isBullet) {
        paragraph.properties.listLabel = level.bulletLabel();
        continue;
      }
      final String key = '$numId:${paragraph.properties.ilvl}';
      final int next = (counters[key] ?? (level.start - 1)) + 1;
      counters[key] = next;
      paragraph.properties.listLabel = level.decimalLabel(next);
    }
  }

  Map<int, _NumberingLevel> _readNumbering(OpcPackage package, String docUri) {
    final RelationshipCollection rels = package.relationshipsFor(docUri);
    final PackageRelationship? rel = rels.firstByType(
      RelationshipTypes.numbering,
    );
    final PackagePart? part = rel == null
        ? package.getPart('/word/numbering.xml')
        : package.getPart(rels.resolve(rel));
    if (part == null) {
      return <int, _NumberingLevel>{};
    }
    return _indexNumbering(part.readText());
  }

  Map<int, _NumberingLevel> _indexNumbering(String xml) {
    final Map<int, int> numToAbstract = <int, int>{};
    final Map<int, Map<int, _NumberingLevel>> byAbstract =
        <int, Map<int, _NumberingLevel>>{};
    var abstractId = -1;
    var ilvl = 0;
    var fmt = 'bullet';
    var text = '•';
    var start = 1;
    var haveLevel = false;
    var numId = -1;

    void flushLevel() {
      if (!haveLevel || abstractId < 0) {
        return;
      }
      byAbstract.putIfAbsent(abstractId, () => <int, _NumberingLevel>{})[ilvl] =
          _NumberingLevel(fmt: fmt, text: text, start: start);
      haveLevel = false;
    }

    final XmlPullReader reader = XmlPullReader(xml);
    while (reader.next()) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      switch (reader.localName) {
        case 'abstractNum':
          flushLevel();
          abstractId =
              int.tryParse(
                reader.getAttribute(
                      'abstractNumId',
                      namespaceUri: OfficeNamespaces.w,
                    ) ??
                    '',
              ) ??
              -1;
        case 'lvl':
          flushLevel();
          ilvl =
              int.tryParse(
                reader.getAttribute('ilvl', namespaceUri: OfficeNamespaces.w) ??
                    '0',
              ) ??
              0;
          fmt = 'bullet';
          text = '•';
          start = 1;
          haveLevel = true;
        case 'start':
          start =
              int.tryParse(
                reader.getAttribute('val', namespaceUri: OfficeNamespaces.w) ??
                    '1',
              ) ??
              1;
        case 'numFmt':
          fmt =
              reader.getAttribute('val', namespaceUri: OfficeNamespaces.w) ??
              fmt;
        case 'lvlText':
          text =
              reader.getAttribute('val', namespaceUri: OfficeNamespaces.w) ??
              text;
        case 'num':
          flushLevel();
          numId =
              int.tryParse(
                reader.getAttribute(
                      'numId',
                      namespaceUri: OfficeNamespaces.w,
                    ) ??
                    '',
              ) ??
              -1;
        case 'abstractNumId':
          final int abs =
              int.tryParse(
                reader.getAttribute('val', namespaceUri: OfficeNamespaces.w) ??
                    '',
              ) ??
              -1;
          if (numId >= 0 && abs >= 0) {
            numToAbstract[numId] = abs;
          }
      }
    }
    flushLevel();

    final Map<int, _NumberingLevel> mapped = <int, _NumberingLevel>{};
    numToAbstract.forEach((int instanceId, int absId) {
      final Map<int, _NumberingLevel>? levels = byAbstract[absId];
      if (levels == null) {
        return;
      }
      levels.forEach((int level, _NumberingLevel def) {
        mapped[_levelKey(instanceId, level)] = def;
      });
    });
    return mapped;
  }

  static int _levelKey(int numId, int ilvl) => (numId << 8) | (ilvl & 0xFF);

  static String _elementText(XmlPullReader reader) {
    if (reader.isEmptyElement) {
      return '';
    }
    final int depth = reader.depth;
    final StringBuffer buffer = StringBuffer();
    while (reader.next() && reader.depth >= depth) {
      if (reader.eventType == XmlEventType.characters ||
          reader.eventType == XmlEventType.cdata) {
        buffer.write(reader.text);
      }
    }
    return buffer.toString();
  }

  static bool _isPageField(String instr) {
    final String upper = instr.toUpperCase();
    return RegExp(r'(^|[^A-Z])PAGE([^A-Z]|$)').hasMatch(upper);
  }

  /// RegExp API.
  static final RegExp _cachedPageResult = RegExp(r'^\s*\d+\s*$');

  WmlObject? _readObject(
    XmlPullReader reader,
    OpcPackage package,
    String docUri,
  ) {
    String? rid = _relationshipId(reader);
    if (!reader.isEmptyElement) {
      final int depth = reader.depth;
      while (reader.next() && reader.depth >= depth) {
        if (reader.eventType != XmlEventType.startElement) {
          continue;
        }
        rid ??= _relationshipId(reader);
      }
    }
    if (rid == null) {
      return null;
    }
    final PackageRelationship? rel = package.relationshipsFor(docUri).byId(rid);
    IsolatedEmbeddedPackage? embedded;
    if (rel != null && rel.targetMode == RelationshipTargetMode.internal) {
      final String target = package.relationshipsFor(docUri).resolve(rel);
      final PackagePart? part = package.getPart(target);
      if (part != null) {
        try {
          embedded = EmbeddedPart.unpack(part.readBytes());
        } on Object {
          if (part.contentType.contains('sheet') || target.endsWith('.xlsx')) {
            embedded = IsolatedEmbeddedPackage(
              package: OpcPackage.openBytes(part.readBytes()),
              kind: OpcPackageKind.sheet,
            );
          }
        }
      }
    }
    return WmlObject(relationshipId: rid, embedded: embedded);
  }

  static String? _relationshipId(XmlPullReader reader) {
    return reader.getAttribute('id', namespaceUri: OfficeNamespaces.r) ??
        reader.getAttribute('id') ??
        reader.getAttribute('embed', namespaceUri: OfficeNamespaces.r) ??
        reader.getAttribute('embed');
  }

  static WmlJustification _jc(String? val) {
    return switch (val) {
      'center' => WmlJustification.center,
      'right' => WmlJustification.right,
      'both' || 'justify' => WmlJustification.justify,
      'distribute' => WmlJustification.distributed,
      _ => WmlJustification.left,
    };
  }

  static bool _onOff(String? val) {
    if (val == null || val.isEmpty) {
      return true;
    }
    switch (val.toLowerCase()) {
      case '0':
      case 'false':
      case 'off':
        return false;
      default:
        return true;
    }
  }

  static double _twipAttr(
    XmlPullReader reader,
    String name, {
    double fallback = 0,
  }) {
    final String? raw = reader.getAttribute(
      name,
      namespaceUri: OfficeNamespaces.w,
    );
    if (raw == null) {
      return fallback;
    }
    return twipsToPoints(int.parse(raw));
  }

  void _readComments(WmlDocument document, OpcPackage package, String docUri) {
    final PackageRelationship? rel = package
        .relationshipsFor(docUri)
        .firstByType(RelationshipTypes.comments);
    if (rel == null) {
      return;
    }
    final PackagePart? part = package.getPart(
      package.relationshipsFor(docUri).resolve(rel),
    );
    if (part == null) {
      return;
    }
    final XmlPullReader reader = XmlPullReader(part.readText());
    while (reader.next()) {
      if (reader.eventType != XmlEventType.startElement ||
          reader.localName != 'comment') {
        continue;
      }
      final int id =
          int.tryParse(
            reader.getAttribute('id', namespaceUri: OfficeNamespaces.w) ?? '',
          ) ??
          document.comments.length;
      final String author =
          reader.getAttribute('author', namespaceUri: OfficeNamespaces.w) ??
          'Quds Office';
      final String initials =
          reader.getAttribute('initials', namespaceUri: OfficeNamespaces.w) ??
          '';
      final String dateIso =
          reader.getAttribute('date', namespaceUri: OfficeNamespaces.w) ?? '';
      final List<WmlParagraph> paragraphs = <WmlParagraph>[];
      final List<WmlVisual> visuals = <WmlVisual>[];
      final StringBuffer fallback = StringBuffer();
      final int depth = reader.depth;
      final String commentsUri = package.relationshipsFor(docUri).resolve(rel);
      while (reader.next() && reader.depth >= depth) {
        if (reader.eventType != XmlEventType.startElement) {
          continue;
        }
        if (reader.localName == 'p') {
          paragraphs.add(_readParagraph(reader, package, commentsUri));
        } else if (reader.localName == 'drawing') {
          _takeDrawing(reader, package, commentsUri);
        } else if (reader.localName == 't') {
          if (fallback.isNotEmpty) {
            fallback.write('\n');
          }
          fallback.write(_elementText(reader));
        }
      }
      for (final WmlVisual visual in _pendingVisuals) {
        visuals.add(visual);
      }
      _pendingVisuals.clear();
      document.comments.add(
        WmlComment(
          id: id,
          author: author,
          initials: initials,
          dateIso: dateIso,
          text: fallback.toString(),
          paragraphs: paragraphs.isEmpty ? null : paragraphs,
          visuals: visuals,
        ),
      );
    }
  }

  void _readCommentsExtended(
    WmlDocument document,
    OpcPackage package,
    String docUri,
  ) {
    final PackageRelationship? rel = package
        .relationshipsFor(docUri)
        .firstByType(RelationshipTypes.commentsExtended);
    if (rel == null) {
      return;
    }
    final PackagePart? part = package.getPart(
      package.relationshipsFor(docUri).resolve(rel),
    );
    if (part == null) {
      return;
    }
    final XmlPullReader reader = XmlPullReader(part.readText());
    while (reader.next()) {
      if (reader.eventType != XmlEventType.startElement ||
          reader.localName != 'commentEx') {
        continue;
      }
      final String paraId =
          reader.getAttribute('paraId', namespaceUri: OfficeNamespaces.w15) ??
          reader.getAttribute('paraId') ??
          '';
      final String? parent =
          reader.getAttribute(
            'paraIdParent',
            namespaceUri: OfficeNamespaces.w15,
          ) ??
          reader.getAttribute('paraIdParent');
      final String done =
          reader.getAttribute('done', namespaceUri: OfficeNamespaces.w15) ??
          reader.getAttribute('done') ??
          '0';
      final int? id = int.tryParse(paraId, radix: 16);
      if (id == null) {
        continue;
      }
      final WmlComment? comment = WordComment.byId(document, id);
      if (comment == null) {
        continue;
      }
      comment.resolved = done == '1' || done.toLowerCase() == 'true';
      if (parent != null && parent.isNotEmpty) {
        comment.parentId = int.tryParse(parent, radix: 16);
      }
    }
  }
}

class _NumberingLevel {
  const _NumberingLevel({
    required this.fmt,
    required this.text,
    required this.start,
  });

  /// fmt API.
  final String fmt;

  /// text API.
  final String text;

  /// start API.
  final int start;

  /// isBullet API.
  bool get isBullet =>
      fmt == 'bullet' || (text.isNotEmpty && text.codeUnitAt(0) >= 0xF000);

  /// bulletLabel API.
  String bulletLabel() => '• ';

  /// decimalLabel API.
  String decimalLabel(int value) {
    if (text.contains('%1')) {
      return '${text.replaceAll('%1', '$value')} ';
    }
    return '$value. ';
  }
}
