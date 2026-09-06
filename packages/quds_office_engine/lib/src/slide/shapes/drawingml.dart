import '../../visual/drawingml_visual_io.dart';
import '../../visual/office_visual.dart';
import '../../xml/namespaces.dart';
import '../../xml/xml_writer.dart';
import '../../xml/xml_reader.dart';
import '../anim/pml_motion_io.dart';
import '../model/pml_presentation.dart';

List<PmlShape> parseSlideShapes(String xml) {
  final List<PmlShape> shapes = <PmlShape>[];
  final XmlPullReader reader = XmlPullReader(xml);
  PmlShape? current;
  var fillPending = false;
  var textFillPending = false;
  var inSpPr = false;
  var inTxBody = false;
  var inLn = false;
  var inTbl = false;
  var inTcPr = false;
  List<PmlTableCell>? currentRow;
  PmlTableCell? currentCell;
  while (reader.next()) {
    if (reader.eventType == XmlEventType.endElement) {
      if (reader.localName == 'spPr') {
        inSpPr = false;
        inLn = false;
        fillPending = false;
      } else if (reader.localName == 'ln') {
        inLn = false;
        fillPending = false;
      } else if (reader.localName == 'txBody') {
        inTxBody = false;
        textFillPending = false;
      } else if (reader.localName == 'tcPr') {
        inTcPr = false;
      } else if (reader.localName == 'tc') {
        currentCell = null;
        inTcPr = false;
      } else if (reader.localName == 'tr') {
        currentRow = null;
      } else if (reader.localName == 'tbl') {
        inTbl = false;
        currentRow = null;
        currentCell = null;
        inTcPr = false;
      } else if (reader.localName == 'sp' ||
          reader.localName == 'cxnSp' ||
          reader.localName == 'pic' ||
          reader.localName == 'graphicFrame') {
        current = null;
        inSpPr = false;
        inTxBody = false;
        inLn = false;
        fillPending = false;
        textFillPending = false;
        inTbl = false;
        inTcPr = false;
        currentRow = null;
        currentCell = null;
      }
      continue;
    }
    if (reader.eventType != XmlEventType.startElement) {
      continue;
    }
    if (reader.localName == 'sp' ||
        reader.localName == 'cxnSp' ||
        reader.localName == 'pic' ||
        reader.localName == 'graphicFrame') {
      current = PmlShape(
        id: shapes.length + 2,
        name: 'Shape',
        fillColor: '',
      );
      shapes.add(current);
      fillPending = false;
      textFillPending = false;
      inSpPr = false;
      inTxBody = false;
      inLn = false;
    } else if (reader.localName == 'spPr') {
      inSpPr = current != null;
      inLn = false;
    } else if (reader.localName == 'ln' && inSpPr) {
      inLn = true;
    } else if (reader.localName == 'txBody') {
      inTxBody = current != null;
    } else if (reader.localName == 'rPr' && current != null) {
      final int? sz = int.tryParse(reader.getAttribute('sz') ?? '');
      if (sz != null && sz > 0 && current.fontSizePt <= 0) {
        current.fontSizePt = sz / 100.0;
      }
    } else if (reader.localName == 'cNvPr' && current != null) {
      current.id = int.parse(reader.getAttribute('id') ?? '${current.id}');
      current.name = reader.getAttribute('name') ?? current.name;
    } else if (reader.localName == 'srcRect' && current != null) {
      current.visual ??= OfficeVisual(kind: OfficeVisualKind.picture);
      DrawingmlVisualIo.applySrcRect(current.visual!.picture, reader);
    } else if (reader.localName == 'lum' && current != null) {
      current.visual ??= OfficeVisual(kind: OfficeVisualKind.picture);
      DrawingmlVisualIo.applyLum(current.visual!.picture, reader);
    } else if (reader.localName == 'alphaModFix' && current != null) {
      current.visual ??= OfficeVisual(kind: OfficeVisualKind.picture);
      current.visual!.picture.transparency =
          DrawingmlVisualIo.alphaToTransparency(reader.getAttribute('amt'));
    } else if (reader.localName == 'outerShdw' && current != null) {
      current.visual ??= OfficeVisual(kind: OfficeVisualKind.picture);
      current.visual!.picture.shadow = true;
    } else if (reader.localName == 'xfrm' && current != null) {
      final int rot = int.tryParse(reader.getAttribute('rot') ?? '0') ?? 0;
      current.transform = PmlTransform(
        x: current.transform.x,
        y: current.transform.y,
        cx: current.transform.cx,
        cy: current.transform.cy,
        rot: rot,
      );
      current.visual ??= OfficeVisual(kind: OfficeVisualKind.picture);
      DrawingmlVisualIo.applyXfrm(current.visual!.picture, reader);
    } else if (reader.localName == 'off' && current != null) {
      current.transform = PmlTransform(
        x: int.parse(reader.getAttribute('x') ?? '0'),
        y: int.parse(reader.getAttribute('y') ?? '0'),
        cx: current.transform.cx,
        cy: current.transform.cy,
        rot: current.transform.rot,
      );
    } else if (reader.localName == 'ext' && current != null) {
      current.transform = PmlTransform(
        x: current.transform.x,
        y: current.transform.y,
        cx: int.parse(reader.getAttribute('cx') ?? '0'),
        cy: int.parse(reader.getAttribute('cy') ?? '0'),
        rot: current.transform.rot,
      );
    } else if (reader.localName == 'prstGeom' && current != null) {
      current.preset = switch (reader.getAttribute('prst')) {
        'ellipse' => PmlShapePreset.ellipse,
        'roundRect' => PmlShapePreset.roundRect,
        'triangle' => PmlShapePreset.triangle,
        'straightConnector1' => PmlShapePreset.connector,
        _ => PmlShapePreset.rect,
      };
    } else if (reader.localName == 'noFill' &&
        inSpPr &&
        !inLn &&
        current != null) {
      current.fillColor = '';
      fillPending = false;
    } else if (reader.localName == 'solidFill' && inSpPr && !inLn) {
      fillPending = current != null;
    } else if (reader.localName == 'solidFill' && inTxBody) {
      textFillPending = current != null;
    } else if (reader.localName == 'tbl' && current != null) {
      current.table ??= PmlTable();
      inTbl = true;
    } else if (reader.localName == 'tblPr' && current?.table != null) {
      final String? rtl = reader.getAttribute('rtl');
      if (rtl != null) {
        current!.table!.rightToLeft = rtl == '1' || rtl.toLowerCase() == 'true';
      }
    } else if (reader.localName == 'tr' && current?.table != null) {
      currentRow = <PmlTableCell>[];
      current!.table!.rows.add(currentRow);
    } else if (reader.localName == 'tc' && currentRow != null) {
      currentCell = PmlTableCell();
      currentRow.add(currentCell);
    } else if (reader.localName == 'tcPr' && currentCell != null) {
      inTcPr = true;
    } else if (reader.localName == 'srgbClr' && current != null) {
      final String? val = reader.getAttribute('val');
      if (val != null && val.isNotEmpty) {
        if (inTcPr && currentCell != null) {
          currentCell.fillColor = val;
        } else if (fillPending) {
          current.fillColor = val;
        } else if (textFillPending) {
          current.textColor = val;
        } else if (currentCell != null && currentCell.textColor.isEmpty) {
          currentCell.textColor = val;
        }
      }
      fillPending = false;
      textFillPending = false;
    } else if ((reader.localName == 'blip' || reader.localName == 'chart') &&
        current != null) {
      current.embedRelId =
          reader.getAttribute('embed') ?? reader.getAttribute('id');
    } else if (reader.localName == 'pPr' && current != null && inTxBody) {
      final String? algn = reader.getAttribute('algn');
      current.textAlign = switch (algn) {
        'ctr' => PmlTextAlign.center,
        'r' => PmlTextAlign.right,
        'just' => PmlTextAlign.justify,
        'l' => PmlTextAlign.left,
        _ => current.textAlign,
      };
      final String? rtl = reader.getAttribute('rtl');
      if (rtl != null) {
        current.rightToLeft = rtl == '1' || rtl.toLowerCase() == 'true';
      }
    } else if (reader.localName == 'p' && current != null) {
      if (currentCell != null &&
          currentCell.text.isNotEmpty &&
          !currentCell.text.endsWith('\n')) {
        currentCell.text += '\n';
      } else if (!inTbl &&
          current.text.isNotEmpty &&
          !current.text.endsWith('\n')) {
        current.text += '\n';
      }
    } else if (reader.localName == 't' && current != null && !reader.isEmptyElement) {
      final int depth = reader.depth;
      while (reader.next() && reader.depth >= depth) {
        if (reader.eventType == XmlEventType.characters) {
          if (currentCell != null) {
            currentCell.text += reader.text;
          } else if (!inTbl) {
            current.text += reader.text;
          }
        }
      }
    }
  }
  return shapes;
}

OfficeVisual parseChartVisual(
  String xml, {
  double width = 360,
  double height = 180,
}) {
  return DrawingmlVisualIo.parseChart(xml, name: 'Chart', width: width, height: height);
}

String slideToXml(PmlSlide slide, {Map<PmlShape, String>? embedIds}) {
  final XmlWriter w = XmlWriter();
  w.writeStartDocument();
  w.writeStartElement('sld', prefix: 'p');
  if (slide.hidden) {
    w.writeAttribute('show', '0');
  }
  w.writeNamespace('p', OfficeNamespaces.p);
  w.writeNamespace('a', OfficeNamespaces.a);
  w.writeNamespace('r', OfficeNamespaces.r);
  w.writeNamespace('c', OfficeNamespaces.c);
  w.writeStartElement('cSld', prefix: 'p');
  w.writeStartElement('spTree', prefix: 'p');
  w.writeStartElement('nvGrpSpPr', prefix: 'p');
  w.writeEmptyElement(
    'cNvPr',
    prefix: 'p',
    attributes: <String, String>{'id': '1', 'name': ''},
  );
  w.writeEmptyElement('cNvGrpSpPr', prefix: 'p');
  w.writeEmptyElement('nvPr', prefix: 'p');
  w.writeEndElement();
  w.writeEmptyElement('grpSpPr', prefix: 'p');
  for (final PmlShape shape in slide.shapes) {
    final OfficeVisual? visual = shape.visual;
    final String? embed = embedIds?[shape] ?? shape.embedRelId;
    if (shape.table != null) {
      _writeSlideTable(w, shape);
    } else if (visual != null && visual.isChart && embed != null) {
      _writeSlideChart(w, shape, visual, embed);
    } else if (visual != null &&
        (visual.isPicture || visual.isDiagram) &&
        embed != null) {
      _writeSlidePicture(w, shape, visual, embed);
    } else {
      _writeSlideShape(w, shape);
    }
  }
  w.writeEndElement();
  w.writeEndElement();
  writeSlideMotion(w, slide);
  w.writeEndElement();
  return w.toXml();
}

void _writeSlideShape(XmlWriter w, PmlShape shape) {
  w.writeStartElement('sp', prefix: 'p');
  w.writeStartElement('nvSpPr', prefix: 'p');
  w.writeEmptyElement(
    'cNvPr',
    prefix: 'p',
    attributes: <String, String>{'id': '${shape.id}', 'name': shape.name},
  );
  w.writeEmptyElement('cNvSpPr', prefix: 'p');
  w.writeEmptyElement('nvPr', prefix: 'p');
  w.writeEndElement();
  w.writeStartElement('spPr', prefix: 'p');
  w.writeStartElement('xfrm', prefix: 'a');
  if (shape.transform.rot != 0) {
    w.writeAttribute('rot', '${shape.transform.rot}');
  }
  w.writeEmptyElement(
    'off',
    prefix: 'a',
    attributes: <String, String>{
      'x': '${shape.transform.x}',
      'y': '${shape.transform.y}',
    },
  );
  w.writeEmptyElement(
    'ext',
    prefix: 'a',
    attributes: <String, String>{
      'cx': '${shape.transform.cx}',
      'cy': '${shape.transform.cy}',
    },
  );
  w.writeEndElement();
  w.writeEmptyElement(
    'prstGeom',
    prefix: 'a',
    attributes: <String, String>{
      'prst': switch (shape.preset) {
        PmlShapePreset.roundRect => 'roundRect',
        PmlShapePreset.ellipse => 'ellipse',
        PmlShapePreset.triangle => 'triangle',
        PmlShapePreset.connector => 'straightConnector1',
        PmlShapePreset.freeform => 'rect',
        PmlShapePreset.rect => 'rect',
      },
    },
  );
  if (shape.fillColor.isNotEmpty) {
    w.writeStartElement('solidFill', prefix: 'a');
    w.writeEmptyElement(
      'srgbClr',
      prefix: 'a',
      attributes: <String, String>{'val': shape.fillColor},
    );
    w.writeEndElement();
  }
  w.writeEndElement();
  if (shape.text.isNotEmpty) {
    w.writeStartElement('txBody', prefix: 'p');
    w.writeEmptyElement('bodyPr', prefix: 'a');
    w.writeStartElement('p', prefix: 'a');
    if (shape.rightToLeft != null || shape.textAlign != PmlTextAlign.left) {
      final Map<String, String> pPr = <String, String>{};
      if (shape.textAlign != PmlTextAlign.left) {
        pPr['algn'] = switch (shape.textAlign) {
          PmlTextAlign.center => 'ctr',
          PmlTextAlign.right => 'r',
          PmlTextAlign.justify => 'just',
          PmlTextAlign.left => 'l',
        };
      }
      if (shape.rightToLeft != null) {
        pPr['rtl'] = shape.rightToLeft! ? '1' : '0';
      }
      w.writeEmptyElement('pPr', prefix: 'a', attributes: pPr);
    }
    w.writeStartElement('r', prefix: 'a');
    w.writeStartElement('t', prefix: 'a');
    w.writeText(shape.text);
    w.writeEndElement();
    w.writeEndElement();
    w.writeEndElement();
    w.writeEndElement();
  }
  w.writeEndElement();
}

void _writeSlidePicture(
  XmlWriter w,
  PmlShape shape,
  OfficeVisual visual,
  String relationshipId,
) {
  final PictureAdjust adj = visual.picture;
  final String name = adj.altTitle.isNotEmpty ? adj.altTitle : shape.name;
  final String descr =
      adj.altDescription.isNotEmpty ? adj.altDescription : name;
  w.writeStartElement('pic', prefix: 'p');
  w.writeStartElement('nvPicPr', prefix: 'p');
  w.writeStartElement('cNvPr', prefix: 'p');
  w.writeAttribute('id', '${shape.id}');
  w.writeAttribute('name', name);
  w.writeAttribute('descr', descr);
  w.writeEndElement();
  w.writeStartElement('cNvPicPr', prefix: 'p');
  w.writeEmptyElement(
    'picLocks',
    prefix: 'a',
    attributes: <String, String>{
      'noChangeAspect': adj.lockAspect ? '1' : '0',
    },
  );
  w.writeEndElement();
  w.writeEmptyElement('nvPr', prefix: 'p');
  w.writeEndElement();
  w.writeStartElement('blipFill', prefix: 'p');
  DrawingmlVisualIo.writeBlip(w, relationshipId: relationshipId, adj: adj);
  DrawingmlVisualIo.writeSrcRect(w, adj);
  w.writeStartElement('stretch', prefix: 'a');
  w.writeEmptyElement('fillRect', prefix: 'a');
  w.writeEndElement();
  w.writeEndElement();
  w.writeStartElement('spPr', prefix: 'p');
  DrawingmlVisualIo.writeXfrm(
    w,
    cx: shape.transform.cx,
    cy: shape.transform.cy,
    adj: adj,
    offX: shape.transform.x,
    offY: shape.transform.y,
  );
  w.writeStartElement('prstGeom', prefix: 'a');
  w.writeAttribute('prst', 'rect');
  w.writeEmptyElement('avLst', prefix: 'a');
  w.writeEndElement();
  DrawingmlVisualIo.writeLine(w, adj);
  DrawingmlVisualIo.writeShadow(w, adj);
  w.writeEndElement();
  w.writeEndElement();
}

void _writeSlideTable(XmlWriter w, PmlShape shape) {
  final PmlTable table = shape.table!;
  w.writeStartElement('graphicFrame', prefix: 'p');
  w.writeStartElement('nvGraphicFramePr', prefix: 'p');
  w.writeEmptyElement(
    'cNvPr',
    prefix: 'p',
    attributes: <String, String>{'id': '${shape.id}', 'name': shape.name},
  );
  w.writeEmptyElement('cNvGraphicFramePr', prefix: 'p');
  w.writeEmptyElement('nvPr', prefix: 'p');
  w.writeEndElement();
  w.writeStartElement('xfrm', prefix: 'p');
  w.writeEmptyElement(
    'off',
    prefix: 'a',
    attributes: <String, String>{
      'x': '${shape.transform.x}',
      'y': '${shape.transform.y}',
    },
  );
  w.writeEmptyElement(
    'ext',
    prefix: 'a',
    attributes: <String, String>{
      'cx': '${shape.transform.cx}',
      'cy': '${shape.transform.cy}',
    },
  );
  w.writeEndElement();
  w.writeStartElement('graphic', prefix: 'a');
  w.writeStartElement('graphicData', prefix: 'a');
  w.writeAttribute('uri', OfficeNamespaces.drawingmlTable);
  w.writeStartElement('tbl', prefix: 'a');
  if (table.rightToLeft) {
    w.writeEmptyElement(
      'tblPr',
      prefix: 'a',
      attributes: <String, String>{'rtl': '1'},
    );
  } else {
    w.writeEmptyElement('tblPr', prefix: 'a');
  }
  final int cols = table.colCount;
  final int colW = cols <= 0 ? shape.transform.cx : shape.transform.cx ~/ cols;
  w.writeStartElement('tblGrid', prefix: 'a');
  for (int i = 0; i < cols; i++) {
    w.writeEmptyElement(
      'gridCol',
      prefix: 'a',
      attributes: <String, String>{'w': '$colW'},
    );
  }
  w.writeEndElement();
  final int rowH =
      table.rowCount <= 0 ? shape.transform.cy : shape.transform.cy ~/ table.rowCount;
  for (final List<PmlTableCell> row in table.rows) {
    w.writeStartElement('tr', prefix: 'a');
    w.writeAttribute('h', '$rowH');
    for (int c = 0; c < cols; c++) {
      final PmlTableCell cell = c < row.length ? row[c] : PmlTableCell();
      w.writeStartElement('tc', prefix: 'a');
      w.writeStartElement('tcPr', prefix: 'a');
      if (cell.fillColor.isNotEmpty) {
        w.writeStartElement('solidFill', prefix: 'a');
        w.writeEmptyElement(
          'srgbClr',
          prefix: 'a',
          attributes: <String, String>{'val': cell.fillColor},
        );
        w.writeEndElement();
      }
      w.writeEndElement();
      w.writeStartElement('txBody', prefix: 'a');
      w.writeEmptyElement('bodyPr', prefix: 'a');
      w.writeStartElement('p', prefix: 'a');
      if (cell.text.isNotEmpty) {
        w.writeStartElement('r', prefix: 'a');
        if (cell.textColor.isNotEmpty) {
          w.writeStartElement('rPr', prefix: 'a');
          w.writeStartElement('solidFill', prefix: 'a');
          w.writeEmptyElement(
            'srgbClr',
            prefix: 'a',
            attributes: <String, String>{'val': cell.textColor},
          );
          w.writeEndElement();
          w.writeEndElement();
        }
        w.writeStartElement('t', prefix: 'a');
        w.writeText(cell.text);
        w.writeEndElement();
        w.writeEndElement();
      }
      w.writeEndElement();
      w.writeEndElement();
      w.writeEndElement();
    }
    w.writeEndElement();
  }
  w.writeEndElement();
  w.writeEndElement();
  w.writeEndElement();
  w.writeEndElement();
}

void _writeSlideChart(
  XmlWriter w,
  PmlShape shape,
  OfficeVisual visual,
  String relationshipId,
) {
  final String name = visual.title.isEmpty ? shape.name : visual.title;
  w.writeStartElement('graphicFrame', prefix: 'p');
  w.writeStartElement('nvGraphicFramePr', prefix: 'p');
  w.writeStartElement('cNvPr', prefix: 'p');
  w.writeAttribute('id', '${shape.id}');
  w.writeAttribute('name', name);
  w.writeEndElement();
  w.writeEmptyElement('cNvGraphicFramePr', prefix: 'p');
  w.writeEmptyElement('nvPr', prefix: 'p');
  w.writeEndElement();
  DrawingmlVisualIo.writeXfrm(
    w,
    cx: shape.transform.cx,
    cy: shape.transform.cy,
    adj: visual.picture,
    offX: shape.transform.x,
    offY: shape.transform.y,
  );
  w.writeStartElement('graphic', prefix: 'a');
  w.writeStartElement('graphicData', prefix: 'a');
  w.writeAttribute('uri', OfficeNamespaces.c);
  w.writeEmptyElement(
    'chart',
    prefix: 'c',
    attributes: <String, String>{'r:id': relationshipId},
  );
  w.writeEndElement();
  w.writeEndElement();
  w.writeEndElement();
}
