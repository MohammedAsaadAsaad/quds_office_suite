import 'dart:convert';
import 'dart:typed_data';

import '../../opc/content_types.dart';
import '../../opc/opc_archive.dart';
import '../../opc/package_part.dart';
import '../../opc/relationships.dart';
import '../../xml/namespaces.dart';
import '../../xml/xml_writer.dart';
import '../../visual/office_visual.dart';
import '../math/omml_io.dart';
import '../model/wml_document.dart';
import '../model/word_toc.dart';
import '../properties/wml_properties.dart';
import 'word_drawing_io.dart';

/// Writes a [WmlDocument] back to a `.docx` OPC package.
class WordSerializer {
  var _docPrId = 1;
  final List<({String id, String target})> _externalLinks =
      <({String id, String target})>[];
  final Set<int> _openComments = <int>{};

  Uint8List writeBytes(WmlDocument document, {String? password}) {
    return write(document).save(password: password);
  }

  OpcPackage write(WmlDocument document) {
    final OpcPackage package =
        document.package ?? OpcPackage.create(OpcPackageKind.word);
    if (package.getPart('/word/document.xml') == null) {
      package.createPart(
        '/word/document.xml',
        OfficeContentTypes.wordMain,
        utf8.encode('<w:document xmlns:w="${OfficeNamespaces.w}"/>'),
      );
      if (package.packageRelationships.firstByType(RelationshipTypes.officeDocument) ==
          null) {
        package.packageRelationships.add(
          type: RelationshipTypes.officeDocument,
          target: 'word/document.xml',
        );
      }
    }
    _externalLinks.clear();
    _openComments.clear();
    _syncEmbeddings(document, package);
    final Map<OfficeVisual, String> imageIds = _syncImages(document, package);
    package.getPart('/word/document.xml')!.writeText(
      _documentXml(document, imageIds),
    );
    _syncHyperlinkRels(package);
    _syncComments(document, package);
    document.package = package;
    return package;
  }

  void _syncHyperlinkRels(OpcPackage package) {
    final RelationshipCollection rels =
        package.relationshipsFor('/word/document.xml');
    for (final ({String id, String target}) link in _externalLinks) {
      final PackageRelationship? existing = rels.byId(link.id);
      if (existing != null) {
        continue;
      }
      rels.add(
        id: link.id,
        type: RelationshipTypes.hyperlink,
        target: link.target,
        targetMode: RelationshipTargetMode.external,
      );
    }
  }

  void _syncEmbeddings(WmlDocument document, OpcPackage package) {
    var oleIndex = 1;
    for (final WmlParagraph paragraph in document.paragraphs) {
      for (final WmlInline inline in paragraph.inlines) {
        if (inline is! WmlObject || inline.embedded == null) {
          continue;
        }
        final String uri = '/word/embeddings/oleObject$oleIndex.bin';
        oleIndex++;
        final Uint8List bin = inline.embedded!.pack();
        if (package.getPart(uri) == null) {
          package.createPart(uri, OfficeContentTypes.oleObject, bin);
        } else {
          package.getPart(uri)!.writeBytes(bin);
        }
        final String target = OpcUris.relativize('/word/document.xml', uri);
        final existing = package
            .relationshipsFor('/word/document.xml')
            .items
            .where((r) => r.target == target);
        if (existing.isEmpty) {
          inline.relationshipId = package
              .relationshipsFor('/word/document.xml')
              .add(type: RelationshipTypes.oleObject, target: target)
              .id;
        } else {
          inline.relationshipId = existing.first.id;
        }
      }
    }
  }

  Map<OfficeVisual, String> _syncImages(
    WmlDocument document,
    OpcPackage package,
  ) {
    return WordDrawingIo.syncVisuals(
      document.visuals.map((WmlVisual wrap) => wrap.visual),
      package,
    );
  }

  String _documentXml(
    WmlDocument document,
    Map<OfficeVisual, String> imageIds,
  ) {
    final XmlWriter w = XmlWriter();
    w.writeStartDocument();
    w.writeStartElement('document', prefix: 'w');
    w.writeNamespace('w', OfficeNamespaces.w);
    w.writeNamespace('r', OfficeNamespaces.r);
    w.writeNamespace('o', OfficeNamespaces.o);
    w.writeNamespace('m', OfficeNamespaces.m);
    w.writeNamespace('wp', OfficeNamespaces.wp);
    w.writeNamespace('a', OfficeNamespaces.a);
    w.writeNamespace('pic', OfficeNamespaces.pic);
    w.writeNamespace('c', OfficeNamespaces.c);
    w.writeStartElement('body', prefix: 'w');
    for (int i = 0; i < document.sections.length; i++) {
      final WmlSection section = document.sections[i];
      for (final WmlBlock block in section.blocks) {
        _writeBlock(w, block, imageIds);
      }
      _writeSectPr(w, section);
    }
    w.writeEndElement();
    w.writeEndElement();
    return w.toXml();
  }

  void _writeBlock(
    XmlWriter w,
    WmlBlock block,
    Map<OfficeVisual, String> imageIds,
  ) {
    switch (block) {
      case WmlParagraph():
        _writeParagraph(w, block);
      case WmlTable():
        _writeTable(w, block, imageIds);
      case WmlFrame():
        _writeFrame(w, block, imageIds);
      case WmlVisual():
        final String? rId = imageIds[block.visual];
        if (rId != null) {
          if (block.visual.isChart) {
            WordDrawingIo.writeChart(
              w,
              relationshipId: rId,
              visual: block.visual,
              docPrId: _docPrId++,
            );
          } else {
            WordDrawingIo.writeInline(
              w,
              relationshipId: rId,
              visual: block.visual,
              docPrId: _docPrId++,
            );
          }
        } else {
          _writeParagraph(
            w,
            WmlParagraph(
              inlines: <WmlInline>[
                WmlRun(
                  text: '[${block.visual.kind.name}] ${block.visual.title}',
                ),
              ],
            ),
          );
        }
      case WmlEquation():
        w.writeStartElement('p', prefix: 'w');
        OmmlIo.writeEquation(w, block.math);
        w.writeEndElement();
      case WmlToc():
        _writeToc(w, block);
    }
  }

  void _writeToc(XmlWriter w, WmlToc toc) {
    WordToc.ensureBody(toc);
    _writeParagraph(w, toc.titleParagraph);
    w.writeStartElement('p', prefix: 'w');
    _writePPr(w, WmlParagraphProps());
    _writeFieldChar(w, 'begin');
    w.writeStartElement('r', prefix: 'w');
    w.writeStartElement('instrText', prefix: 'w');
    w.writeAttribute('xml:space', 'preserve');
    w.writeText(' TOC \\o "${toc.minLevel}-${toc.maxLevel}" \\h \\z \\u ');
    w.writeEndElement();
    w.writeEndElement();
    _writeFieldChar(w, 'separate');
    w.writeEndElement();
    final int count = toc.itemParagraphs.length;
    for (int i = 0; i < count; i++) {
      final WmlParagraph para = _copyParagraph(toc.itemParagraphs[i]);
      para.properties.tabs = <WmlTabStop>[
        WmlTabStop(
          position: 468,
          alignment: WmlTabAlignment.right,
          leader: WmlTabLeader.dot,
        ),
      ];
      if (toc.showPageNumbers && i < toc.entries.length) {
        para.inlines.add(WmlRun(text: '\t${toc.entries[i].pageNumber}'));
      }
      _writeParagraph(w, para);
    }
    w.writeStartElement('p', prefix: 'w');
    _writeFieldChar(w, 'end');
    w.writeEndElement();
  }

  WmlParagraph _copyParagraph(WmlParagraph source) {
    return WmlParagraph(
      properties: source.properties,
      inlines: <WmlInline>[
        for (final WmlInline inline in source.inlines)
          if (inline is WmlRun)
            WmlRun(
              text: inline.text,
              properties: inline.properties.copy(),
              hyperlink: inline.hyperlink?.copy(),
              commentIds: List<int>.from(inline.commentIds),
            )
          else
            inline,
      ],
    );
  }

  List<int> _peekCommentIds(WmlParagraph paragraph, int index) {
    for (int i = index; i < paragraph.inlines.length; i++) {
      final WmlInline inline = paragraph.inlines[i];
      if (inline is WmlRun) {
        return inline.commentIds;
      }
    }
    return const <int>[];
  }

  void _openCommentStarts(XmlWriter w, List<int> ids) {
    for (final int id in ids) {
      if (_openComments.add(id)) {
        w.writeEmptyElement(
          'commentRangeStart',
          prefix: 'w',
          attributes: <String, String>{'w:id': '$id'},
        );
      }
    }
  }

  void _closeCommentsNotIn(XmlWriter w, List<int> keep) {
    final List<int> closing = <int>[
      for (final int id in _openComments)
        if (!keep.contains(id)) id,
    ];
    for (final int id in closing) {
      _openComments.remove(id);
      w.writeEmptyElement(
        'commentRangeEnd',
        prefix: 'w',
        attributes: <String, String>{'w:id': '$id'},
      );
      w.writeStartElement('r', prefix: 'w');
      w.writeEmptyElement(
        'commentReference',
        prefix: 'w',
        attributes: <String, String>{'w:id': '$id'},
      );
      w.writeEndElement();
    }
  }

  void _syncComments(WmlDocument document, OpcPackage package) {
    const String uri = '/word/comments.xml';
    const String extUri = '/word/commentsExtended.xml';
    final RelationshipCollection rels =
        package.relationshipsFor('/word/document.xml');
    if (document.comments.isEmpty) {
      package.getPart(uri)?.writeText(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:comments xmlns:w="${OfficeNamespaces.w}"/>',
      );
      package.getPart(extUri)?.writeText(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w15:commentsEx xmlns:w15="${OfficeNamespaces.w15}"/>',
      );
      return;
    }
    final Map<OfficeVisual, String> imageIds = WordDrawingIo.syncVisuals(
      <OfficeVisual>[
        for (final WmlComment comment in document.comments)
          for (final WmlVisual visual in comment.visuals) visual.visual,
      ],
      package,
      partUri: uri,
      mediaPrefix: 'commentImage',
    );
    final XmlWriter w = XmlWriter();
    w.writeStartDocument();
    w.writeStartElement('comments', prefix: 'w');
    w.writeNamespace('w', OfficeNamespaces.w);
    w.writeNamespace('r', OfficeNamespaces.r);
    w.writeNamespace('wp', OfficeNamespaces.wp);
    w.writeNamespace('a', OfficeNamespaces.a);
    w.writeNamespace('pic', OfficeNamespaces.pic);
    for (final WmlComment comment in document.comments) {
      w.writeStartElement('comment', prefix: 'w');
      w.writeAttribute('w:id', '${comment.id}');
      w.writeAttribute('w:author', comment.author);
      w.writeAttribute('w:initials', comment.initials);
      if (comment.dateIso.isNotEmpty) {
        w.writeAttribute('w:date', comment.dateIso);
      }
      if (comment.paragraphs.isEmpty && comment.visuals.isEmpty) {
        _writeParagraph(w, WmlParagraph(inlines: <WmlInline>[WmlRun()]));
      }
      for (final WmlParagraph paragraph in comment.paragraphs) {
        _writeParagraph(w, paragraph);
      }
      for (final WmlVisual visual in comment.visuals) {
        _writeBlock(w, visual, imageIds);
      }
      w.writeEndElement();
    }
    w.writeEndElement();
    final PackagePart? existing = package.getPart(uri);
    if (existing == null) {
      package.createPart(
        uri,
        OfficeContentTypes.wordComments,
        utf8.encode(w.toXml()),
      );
    } else {
      existing.writeText(w.toXml());
    }
    if (rels.firstByType(RelationshipTypes.comments) == null) {
      rels.add(
        type: RelationshipTypes.comments,
        target: 'comments.xml',
        id: 'rIdComments',
      );
    }
    _syncCommentsExtended(document, package, rels);
  }

  void _syncCommentsExtended(
    WmlDocument document,
    OpcPackage package,
    RelationshipCollection rels,
  ) {
    const String uri = '/word/commentsExtended.xml';
    final XmlWriter w = XmlWriter();
    w.writeStartDocument();
    w.writeStartElement('commentsEx', prefix: 'w15');
    w.writeNamespace('w15', OfficeNamespaces.w15);
    for (final WmlComment comment in document.comments) {
      w.writeEmptyElement(
        'commentEx',
        prefix: 'w15',
        attributes: <String, String>{
          'w15:paraId': comment.id.toRadixString(16).padLeft(8, '0'),
          if (comment.parentId != null)
            'w15:paraIdParent':
                comment.parentId!.toRadixString(16).padLeft(8, '0'),
          'w15:done': comment.resolved ? '1' : '0',
        },
      );
    }
    w.writeEndElement();
    final PackagePart? existing = package.getPart(uri);
    if (existing == null) {
      package.createPart(
        uri,
        OfficeContentTypes.wordCommentsExtended,
        utf8.encode(w.toXml()),
      );
    } else {
      existing.writeText(w.toXml());
    }
    if (rels.firstByType(RelationshipTypes.commentsExtended) == null) {
      rels.add(
        type: RelationshipTypes.commentsExtended,
        target: 'commentsExtended.xml',
        id: 'rIdCommentsEx',
      );
    }
  }

  void _writeFieldChar(XmlWriter w, String type) {
    w.writeStartElement('r', prefix: 'w');
    w.writeEmptyElement(
      'fldChar',
      prefix: 'w',
      attributes: <String, String>{'w:fldCharType': type},
    );
    w.writeEndElement();
  }

  void _writeParagraph(XmlWriter w, WmlParagraph paragraph) {
    w.writeStartElement('p', prefix: 'w');
    _writePPr(w, paragraph.properties);
    if (paragraph.properties.columnBreakBefore &&
        !paragraph.inlines.any(
          (WmlInline inline) =>
              inline is WmlBreak && inline.type == WmlBreakType.column,
        )) {
      w.writeStartElement('r', prefix: 'w');
      w.writeStartElement('br', prefix: 'w');
      w.writeAttribute('w:type', 'column');
      w.writeEndElement();
      w.writeEndElement();
    }
    final String? bookmark = paragraph.properties.bookmarkName;
    if (bookmark != null && bookmark.isNotEmpty) {
      w.writeEmptyElement(
        'bookmarkStart',
        prefix: 'w',
        attributes: <String, String>{
          'w:id': '${bookmark.hashCode & 0x7fffffff}',
          'w:name': bookmark,
        },
      );
    }
    var i = 0;
    while (i < paragraph.inlines.length) {
      final WmlInline inline = paragraph.inlines[i];
      if (inline is WmlRun) {
        _openCommentStarts(w, inline.commentIds);
      }
      if (inline is WmlRun && inline.hyperlink != null) {
        final WmlHyperlink link = inline.hyperlink!;
        var end = i + 1;
        while (end < paragraph.inlines.length) {
          final WmlInline next = paragraph.inlines[end];
          if (next is! WmlRun || next.hyperlink?.displayTarget != link.displayTarget) {
            break;
          }
          end++;
        }
        w.writeStartElement('hyperlink', prefix: 'w');
        if (link.isInternal) {
          w.writeAttribute('w:anchor', link.anchor!);
        } else {
          w.writeAttribute('r:id', _externalLinkId(link));
        }
        w.writeAttribute('w:history', '1');
        for (int r = i; r < end; r++) {
          final WmlRun run = paragraph.inlines[r] as WmlRun;
          if (r > i) {
            _openCommentStarts(w, run.commentIds);
          }
          _writeRun(w, run);
        }
        w.writeEndElement();
        _closeCommentsNotIn(w, _peekCommentIds(paragraph, end));
        i = end;
        continue;
      }
      switch (inline) {
        case WmlRun():
          _writeRun(w, inline);
        case WmlBreak():
          w.writeStartElement('r', prefix: 'w');
          w.writeStartElement('br', prefix: 'w');
          if (inline.type == WmlBreakType.page) {
            w.writeAttribute('w:type', 'page');
          } else if (inline.type == WmlBreakType.column) {
            w.writeAttribute('w:type', 'column');
          }
          w.writeEndElement();
          w.writeEndElement();
        case WmlObject():
          w.writeStartElement('r', prefix: 'w');
          w.writeStartElement('object', prefix: 'w');
          w.writeStartElement('OLEObject', prefix: 'o');
          w.writeAttribute('r:id', inline.relationshipId);
          w.writeEndElement();
          w.writeEndElement();
          w.writeEndElement();
      }
      _closeCommentsNotIn(w, _peekCommentIds(paragraph, i + 1));
      i++;
    }
    _closeCommentsNotIn(w, const <int>[]);
    if (bookmark != null && bookmark.isNotEmpty) {
      w.writeEmptyElement(
        'bookmarkEnd',
        prefix: 'w',
        attributes: <String, String>{
          'w:id': '${bookmark.hashCode & 0x7fffffff}',
        },
      );
    }
    w.writeEndElement();
  }

  void _writeRun(XmlWriter w, WmlRun inline) {
    w.writeStartElement('r', prefix: 'w');
    _writeRPr(w, inline.properties);
    w.writeStartElement('t', prefix: 'w');
    w.writeAttribute('xml:space', 'preserve');
    w.writeText(inline.text);
    w.writeEndElement();
    w.writeEndElement();
  }

  String _externalLinkId(WmlHyperlink link) {
    final String target = link.url ?? link.file ?? '';
    for (final ({String id, String target}) existing in _externalLinks) {
      if (existing.target == target) {
        return existing.id;
      }
    }
    final String id = 'rIdLink${_externalLinks.length + 1}';
    _externalLinks.add((id: id, target: target));
    return id;
  }

  void _writePPr(XmlWriter w, WmlParagraphProps p) {
    w.writeStartElement('pPr', prefix: 'w');
    w.writeEmptyElement(
      'jc',
      prefix: 'w',
      attributes: <String, String>{
        'w:val': switch (p.justification) {
          WmlJustification.center => 'center',
          WmlJustification.right => 'right',
          WmlJustification.justify => 'both',
          WmlJustification.distributed => 'distribute',
          WmlJustification.left => 'left',
        },
      },
    );
    w.writeStartElement('spacing', prefix: 'w');
    w.writeAttribute('w:before', '${pointsToTwips(p.spacingBefore)}');
    w.writeAttribute('w:after', '${pointsToTwips(p.spacingAfter)}');
    if (p.lineSpacingRule == WmlLineSpacingRule.auto) {
      w.writeAttribute('w:line', '${(p.lineSpacing * 240).round()}');
      w.writeAttribute('w:lineRule', 'auto');
    } else {
      w.writeAttribute('w:line', '${pointsToTwips(p.lineSpacing)}');
      w.writeAttribute(
        'w:lineRule',
        p.lineSpacingRule == WmlLineSpacingRule.exact ? 'exact' : 'atLeast',
      );
    }
    w.writeEndElement();
    w.writeStartElement('ind', prefix: 'w');
    w.writeAttribute('w:left', '${pointsToTwips(p.indent.left)}');
    w.writeAttribute('w:right', '${pointsToTwips(p.indent.right)}');
    if (p.indent.firstLine > 0) {
      w.writeAttribute('w:firstLine', '${pointsToTwips(p.indent.firstLine)}');
    }
    if (p.indent.hanging > 0) {
      w.writeAttribute('w:hanging', '${pointsToTwips(p.indent.hanging)}');
    }
    w.writeEndElement();
    if (p.tabs.isNotEmpty) {
      w.writeStartElement('tabs', prefix: 'w');
      for (final WmlTabStop tab in p.tabs) {
        w.writeStartElement('tab', prefix: 'w');
        w.writeAttribute('w:val', tab.alignment.name);
        w.writeAttribute('w:pos', '${pointsToTwips(tab.position)}');
        if (tab.leader != WmlTabLeader.none) {
          w.writeAttribute('w:leader', tab.leader.name);
        }
        w.writeEndElement();
      }
      w.writeEndElement();
    }
    if (p.keepTogether) {
      w.writeEmptyElement('keepLines', prefix: 'w');
    }
    if (p.pageBreakBefore) {
      w.writeEmptyElement('pageBreakBefore', prefix: 'w');
    }
    if (p.styleId != null && p.styleId!.isNotEmpty) {
      w.writeEmptyElement(
        'pStyle',
        prefix: 'w',
        attributes: <String, String>{'w:val': p.styleId!},
      );
    }
    if (p.headingLevel != null && p.headingLevel! >= 1) {
      w.writeEmptyElement(
        'outlineLvl',
        prefix: 'w',
        attributes: <String, String>{'w:val': '${p.headingLevel! - 1}'},
      );
    }
    if (p.rightToLeft == true) {
      w.writeEmptyElement('bidi', prefix: 'w');
    } else if (p.rightToLeft == false) {
      w.writeEmptyElement(
        'bidi',
        prefix: 'w',
        attributes: <String, String>{'w:val': '0'},
      );
    }
    w.writeEndElement();
  }

  void _writeRPr(XmlWriter w, WmlRunProps r) {
    w.writeStartElement('rPr', prefix: 'w');
    if (r.bold) {
      w.writeEmptyElement('b', prefix: 'w');
    }
    if (r.italic) {
      w.writeEmptyElement('i', prefix: 'w');
    }
    if (r.strike) {
      w.writeEmptyElement('strike', prefix: 'w');
    }
    if (r.underline != WmlUnderline.none) {
      w.writeEmptyElement(
        'u',
        prefix: 'w',
        attributes: <String, String>{
          'w:val': switch (r.underline) {
            WmlUnderline.double => 'double',
            WmlUnderline.dotted => 'dotted',
            WmlUnderline.wavy => 'wave',
            _ => 'single',
          },
        },
      );
    }
    w.writeEmptyElement(
      'color',
      prefix: 'w',
      attributes: <String, String>{'w:val': r.color},
    );
    if (r.highlight != null) {
      w.writeEmptyElement(
        'highlight',
        prefix: 'w',
        attributes: <String, String>{'w:val': r.highlight!},
      );
    }
    w.writeEmptyElement(
      'sz',
      prefix: 'w',
      attributes: <String, String>{'w:val': '${r.fontSizeHalfPoints}'},
    );
    w.writeEmptyElement(
      'rFonts',
      prefix: 'w',
      attributes: <String, String>{'w:ascii': r.asciiFont, 'w:cs': r.csFont},
    );
    if (r.vertAlign != WmlVertAlign.baseline) {
      w.writeEmptyElement(
        'vertAlign',
        prefix: 'w',
        attributes: <String, String>{
          'w:val': r.vertAlign == WmlVertAlign.superscript
              ? 'superscript'
              : 'subscript',
        },
      );
    }
    w.writeEndElement();
  }

  void _writeTable(
    XmlWriter w,
    WmlTable table,
    Map<OfficeVisual, String> imageIds,
  ) {
    w.writeStartElement('tbl', prefix: 'w');
    w.writeStartElement('tblPr', prefix: 'w');
    if (table.properties.rightToLeft) {
      w.writeEmptyElement('bidiVisual', prefix: 'w');
    }
    w.writeEmptyElement(
      'jc',
      prefix: 'w',
      attributes: <String, String>{
        'w:val': switch (table.properties.alignment) {
          WmlJustification.center => 'center',
          WmlJustification.right => 'right',
          WmlJustification.justify => 'both',
          WmlJustification.distributed => 'distribute',
          WmlJustification.left => 'left',
        },
      },
    );
    w.writeEndElement();
    w.writeStartElement('tblGrid', prefix: 'w');
    for (final double col in table.grid) {
      w.writeEmptyElement(
        'gridCol',
        prefix: 'w',
        attributes: <String, String>{'w:w': '${pointsToTwips(col)}'},
      );
    }
    w.writeEndElement();
    for (final WmlTableRow row in table.rows) {
      w.writeStartElement('tr', prefix: 'w');
      if (row.cantSplit || row.height != null) {
        w.writeStartElement('trPr', prefix: 'w');
        if (row.cantSplit) {
          w.writeEmptyElement('cantSplit', prefix: 'w');
        }
        if (row.height != null) {
          w.writeEmptyElement(
            'trHeight',
            prefix: 'w',
            attributes: <String, String>{
              'w:val': '${pointsToTwips(row.height!)}',
              'w:hRule': 'atLeast',
            },
          );
        }
        w.writeEndElement();
      }
      for (final WmlTableCell cell in row.cells) {
        w.writeStartElement('tc', prefix: 'w');
        w.writeStartElement('tcPr', prefix: 'w');
        if (cell.gridSpan > 1) {
          w.writeEmptyElement(
            'gridSpan',
            prefix: 'w',
            attributes: <String, String>{'w:val': '${cell.gridSpan}'},
          );
        }
        if (cell.vMerge != WmlVMerge.none) {
          w.writeEmptyElement(
            'vMerge',
            prefix: 'w',
            attributes: cell.vMerge == WmlVMerge.restart
                ? <String, String>{'w:val': 'restart'}
                : null,
          );
        }
        w.writeEndElement();
        if (cell.blocks.isEmpty) {
          _writeParagraph(w, WmlParagraph());
        } else {
          for (final WmlBlock block in cell.blocks) {
            _writeBlock(w, block, imageIds);
          }
        }
        w.writeEndElement();
      }
      w.writeEndElement();
    }
    w.writeEndElement();
  }

  void _writeFrame(
    XmlWriter w,
    WmlFrame frame,
    Map<OfficeVisual, String> imageIds,
  ) {
    w.writeStartElement('sdt', prefix: 'w');
    w.writeStartElement('sdtPr', prefix: 'w');
    w.writeEmptyElement(
      'alias',
      prefix: 'w',
      attributes: <String, String>{'w:val': 'Frame'},
    );
    w.writeEmptyElement(
      'tag',
      prefix: 'w',
      attributes: <String, String>{
        'w:val':
            'qudsFrame:${frame.x},${frame.y},${frame.width},${frame.height},'
            '${frame.anchor.name},${frame.wrap.name},'
            '${frame.fillColor ?? ''},${frame.strokeColor ?? ''}',
      },
    );
    w.writeEndElement();
    w.writeStartElement('sdtContent', prefix: 'w');
    if (frame.blocks.isEmpty) {
      _writeParagraph(w, WmlParagraph());
    } else {
      for (final WmlBlock child in frame.blocks) {
        _writeBlock(w, child, imageIds);
      }
    }
    w.writeEndElement();
    w.writeEndElement();
  }

  void _writeSectPr(XmlWriter w, WmlSection section) {
    w.writeStartElement('sectPr', prefix: 'w');
    w.writeEmptyElement(
      'pgSz',
      prefix: 'w',
      attributes: <String, String>{
        'w:w': '${pointsToTwips(section.pageSize.width)}',
        'w:h': '${pointsToTwips(section.pageSize.height)}',
      },
    );
    w.writeEmptyElement(
      'pgMar',
      prefix: 'w',
      attributes: <String, String>{
        'w:top': '${pointsToTwips(section.margins.top)}',
        'w:bottom': '${pointsToTwips(section.margins.bottom)}',
        'w:left': '${pointsToTwips(section.margins.left)}',
        'w:right': '${pointsToTwips(section.margins.right)}',
      },
    );
    if (section.columnCount > 1) {
      w.writeEmptyElement(
        'cols',
        prefix: 'w',
        attributes: <String, String>{
          'w:num': '${section.columnCount}',
          'w:space': '${pointsToTwips(section.columnSpace)}',
          if (section.columnSep) 'w:sep': '1',
        },
      );
    }
    w.writeEndElement();
  }
}
