import 'dart:convert';
import 'dart:typed_data';

import '../../opc/content_types.dart';
import '../../opc/opc_archive.dart';
import '../../opc/package_part.dart';
import '../../opc/relationships.dart';
import '../../xml/namespaces.dart';
import '../../xml/xml_reader.dart';
import '../../xml/xml_writer.dart';
import '../formula/dep_graph.dart';
import '../model/sml_workbook.dart';
import '../shared_strings.dart';
import '../styles/sml_styles.dart';
import 'sheet_drawing_io.dart';

/// Class SheetDeserializer.
class SheetDeserializer {
  /// read API.
  SmlWorkbook read(OpcPackage package) {
    final SharedStringTable sst =
        package.getPart('/xl/sharedStrings.xml') == null
        ? SharedStringTable()
        : SharedStringTable.parse(
            package.getPart('/xl/sharedStrings.xml')!.readText(),
          );
    SmlStyleSheet? styles;
    if (package.getPart('/xl/styles.xml') != null) {
      styles = SmlStyleSheet.parse(
        package.getPart('/xl/styles.xml')!.readText(),
      );
    }
    final SmlWorkbook book = SmlWorkbook(
      sheets: <SmlWorksheet>[],
      sharedStrings: sst.values,
      package: package,
      styles: styles,
    );
    final PackagePart? wb = package.getPart('/xl/workbook.xml');
    if (wb == null) {
      return book;
    }
    final RelationshipCollection rels = package.relationshipsFor(
      '/xl/workbook.xml',
    );
    final XmlPullReader reader = XmlPullReader(wb.readText());
    while (reader.next()) {
      if (reader.eventType != XmlEventType.startElement ||
          reader.localName != 'sheet') {
        continue;
      }
      final String name = reader.getAttribute('name') ?? 'Sheet';
      final int id = int.parse(reader.getAttribute('sheetId') ?? '1');
      final String? rid = reader.getAttribute(
        'id',
        namespaceUri: OfficeNamespaces.r,
      );
      final SmlWorksheet sheet = SmlWorksheet(name: name, sheetId: id);
      if (rid != null) {
        final PackageRelationship? rel = rels.byId(rid);
        if (rel != null) {
          final String uri = rels.resolve(rel);
          final PackagePart? part = package.getPart(uri);
          if (part != null) {
            _readSheet(part.readText(), sheet, sst, package, uri);
          }
        }
      }
      book.sheets.add(sheet);
    }
    if (book.sheets.isEmpty) {
      book.sheets.add(SmlWorksheet(name: 'Sheet1', sheetId: 1));
    }
    return book;
  }

  /// readBytes API.
  SmlWorkbook readBytes(Uint8List bytes, {String? password}) =>
      read(OpcPackage.openBytes(bytes, password: password));

  void _readSheet(
    String xml,
    SmlWorksheet sheet,
    SharedStringTable sst,
    OpcPackage package,
    String sheetUri,
  ) {
    final XmlPullReader reader = XmlPullReader(xml);
    SmlCell? current;
    while (reader.next()) {
      if (reader.eventType == XmlEventType.startElement &&
          reader.localName == 'sheetView') {
        final String? rtl = reader.getAttribute('rightToLeft');
        sheet.rightToLeft = rtl == '1' || rtl?.toLowerCase() == 'true';
      }
      if (reader.eventType == XmlEventType.startElement &&
          reader.localName == 'pane') {
        final int x = int.tryParse(reader.getAttribute('xSplit') ?? '0') ?? 0;
        final int y = int.tryParse(reader.getAttribute('ySplit') ?? '0') ?? 0;
        sheet.freezeCols = x.clamp(0, SmlWorksheet.excelColumnCount - 1);
        sheet.freezeRows = y.clamp(0, SmlWorksheet.excelRowCount - 1);
      }
      if (reader.eventType == XmlEventType.startElement &&
          reader.localName == 'col') {
        final int min = int.tryParse(reader.getAttribute('min') ?? '1') ?? 1;
        final int max =
            int.tryParse(reader.getAttribute('max') ?? '$min') ?? min;
        final double? width = double.tryParse(
          reader.getAttribute('width') ?? '',
        );
        if (width != null) {
          final double px = SmlWorksheet.columnWidthFromExcel(width);
          final int from = (min - 1).clamp(
            0,
            SmlWorksheet.excelColumnCount - 1,
          );
          final int to = (max - 1).clamp(0, SmlWorksheet.excelColumnCount - 1);
          for (int c = from; c <= to; c++) {
            sheet.columnWidths[c] = px;
          }
        }
      }
      if (reader.eventType == XmlEventType.startElement &&
          reader.localName == 'row') {
        final int r = (int.tryParse(reader.getAttribute('r') ?? '1') ?? 1) - 1;
        final double? ht = double.tryParse(reader.getAttribute('ht') ?? '');
        if (ht != null && r >= 0 && r < SmlWorksheet.excelRowCount) {
          sheet.rowHeights[r] = SmlWorksheet.rowHeightFromExcel(ht);
        }
      }
      if (reader.eventType == XmlEventType.startElement &&
          reader.localName == 'c') {
        final String ref = reader.getAttribute('r') ?? 'A1';
        final String? t = reader.getAttribute('t');
        final int s = int.parse(reader.getAttribute('s') ?? '0');
        current = sheet.cellA1(ref);
        current.styleIndex = s;
        current.type = switch (t) {
          's' => SmlCellType.string,
          'b' => SmlCellType.boolean,
          'e' => SmlCellType.error,
          'str' => SmlCellType.string,
          _ => SmlCellType.number,
        };
      } else if (reader.eventType == XmlEventType.startElement &&
          reader.localName == 'f' &&
          current != null) {
        // formula text follows
      } else if (reader.eventType == XmlEventType.characters &&
          current != null) {
        // assigned below via element-end tracking
      } else if (reader.eventType == XmlEventType.endElement &&
          reader.localName == 'c') {
        current = null;
      }
      if (reader.eventType == XmlEventType.startElement &&
          (reader.localName == 'v' || reader.localName == 'f') &&
          current != null) {
        final String name = reader.localName;
        final String text = _readText(reader);
        if (name == 'f') {
          current.formula = text;
          current.type = SmlCellType.formula;
        } else if (current.type == SmlCellType.string &&
            int.tryParse(text) != null) {
          current.value = sst[int.parse(text)];
        } else if (current.type == SmlCellType.boolean) {
          current.value = text == '1' || text.toLowerCase() == 'true';
        } else {
          current.value = double.tryParse(text) ?? text;
        }
      }
    }
    SheetDrawingIo.readSheet(sheet, package, sheetUri);
  }

  static String _readText(XmlPullReader reader) {
    if (reader.isEmptyElement) {
      return '';
    }
    final StringBuffer buffer = StringBuffer();
    final int depth = reader.depth;
    while (reader.next() && reader.depth >= depth) {
      if (reader.eventType == XmlEventType.characters) {
        buffer.write(reader.text);
      }
    }
    return buffer.toString();
  }
}

/// Class SheetSerializer.
class SheetSerializer {
  /// writeBytes API.
  Uint8List writeBytes(
    SmlWorkbook book, {
    bool recalculate = true,
    String? password,
  }) {
    return write(book, recalculate: recalculate).save(password: password);
  }

  /// write API.
  OpcPackage write(SmlWorkbook book, {bool recalculate = true}) {
    if (recalculate) {
      FormulaDepGraph(book).recalculate();
    }
    final OpcPackage package =
        book.package ?? OpcPackage.create(OpcPackageKind.sheet);
    final SharedStringTable sst = SharedStringTable();
    for (final SmlWorksheet sheet in book.sheets) {
      for (final SmlCell cell in sheet.allCells) {
        if (cell.type == SmlCellType.string || cell.value is String) {
          sst.intern(cell.asString);
        }
      }
    }
    if (package.getPart('/xl/sharedStrings.xml') == null) {
      package.createPart(
        '/xl/sharedStrings.xml',
        OfficeContentTypes.sheetSharedStrings,
        utf8.encode(sst.toXml()),
      );
    } else {
      package.getPart('/xl/sharedStrings.xml')!.writeText(sst.toXml());
    }
    package.getPart('/xl/workbook.xml')!.writeText(_workbookXml(book));
    final RelationshipCollection rels = package.relationshipsFor(
      '/xl/workbook.xml',
    );
    for (int i = 0; i < book.sheets.length; i++) {
      final String uri = '/xl/worksheets/sheet${i + 1}.xml';
      if (package.getPart(uri) == null) {
        package.createPart(
          uri,
          OfficeContentTypes.sheetWorksheet,
          utf8.encode(''),
        );
        rels.add(
          type: RelationshipTypes.worksheet,
          target: 'worksheets/sheet${i + 1}.xml',
        );
      }
      SheetDrawingIo.syncSheet(book.sheets[i], package, uri, i + 1);
      package
          .getPart(uri)!
          .writeText(_sheetXml(book.sheets[i], sst, package, uri));
    }
    if (package
            .relationshipsFor('/xl/workbook.xml')
            .firstByType(RelationshipTypes.sharedStrings) ==
        null) {
      package
          .relationshipsFor('/xl/workbook.xml')
          .add(
            type: RelationshipTypes.sharedStrings,
            target: 'sharedStrings.xml',
          );
    }
    book.package = package;
    book.sharedStrings = sst.values;
    return package;
  }

  String _workbookXml(SmlWorkbook book) {
    final XmlWriter w = XmlWriter();
    w.writeStartDocument();
    w.writeStartElement('workbook');
    w.writeAttribute('xmlns', OfficeNamespaces.x);
    w.writeNamespace('r', OfficeNamespaces.r);
    w.writeStartElement('sheets');
    for (int i = 0; i < book.sheets.length; i++) {
      final SmlWorksheet s = book.sheets[i];
      w.writeStartElement('sheet');
      w.writeAttribute('name', s.name);
      w.writeAttribute('sheetId', '${s.sheetId}');
      w.writeAttribute('r:id', 'rId${i + 1}');
      w.writeEndElement();
    }
    w.writeEndElement();
    w.writeEndElement();
    return w.toXml();
  }

  String _sheetXml(
    SmlWorksheet sheet,
    SharedStringTable sst,
    OpcPackage package,
    String sheetUri,
  ) {
    final XmlWriter w = XmlWriter();
    w.writeStartDocument();
    w.writeStartElement('worksheet');
    w.writeAttribute('xmlns', OfficeNamespaces.x);
    if (sheet.drawings.isNotEmpty) {
      w.writeNamespace('r', OfficeNamespaces.r);
    }
    _writeSheetViews(w, sheet);
    _writeCols(w, sheet);
    w.writeStartElement('sheetData');
    final Set<int> rowKeys = <int>{
      ...sheet.rows.keys,
      ...sheet.rowHeights.keys,
    };
    final List<int> rowIdx = rowKeys.toList()..sort();
    for (final int r in rowIdx) {
      final SmlRow row = sheet.rows[r] ?? SmlRow(r);
      w.writeStartElement('row');
      w.writeAttribute('r', '${r + 1}');
      final double? ht = sheet.rowHeights[r];
      if (ht != null) {
        w.writeAttribute('ht', '${SmlWorksheet.rowHeightToExcel(ht)}');
        w.writeAttribute('customHeight', '1');
      }
      final List<int> cols = row.cells.keys.toList()..sort();
      for (final int c in cols) {
        final SmlCell cell = row.cells[c]!;
        w.writeStartElement('c');
        w.writeAttribute('r', cell.ref.a1);
        if (cell.formula != null) {
          w.writeStartElement('f');
          w.writeText(
            cell.formula!.startsWith('=')
                ? cell.formula!.substring(1)
                : cell.formula!,
          );
          w.writeEndElement();
          w.writeStartElement('v');
          w.writeText(cell.asString);
          w.writeEndElement();
        } else if (cell.type == SmlCellType.string || cell.value is String) {
          w.writeAttribute('t', 's');
          w.writeStartElement('v');
          w.writeText('${sst.intern(cell.asString)}');
          w.writeEndElement();
        } else if (cell.type == SmlCellType.boolean) {
          w.writeAttribute('t', 'b');
          w.writeStartElement('v');
          w.writeText(cell.value == true ? '1' : '0');
          w.writeEndElement();
        } else if (cell.value != null) {
          w.writeStartElement('v');
          w.writeText(cell.asString);
          w.writeEndElement();
        }
        w.writeEndElement();
      }
      w.writeEndElement();
    }
    w.writeEndElement();
    if (sheet.drawings.isNotEmpty) {
      final String? rid = SheetDrawingIo.drawingRelationshipId(
        package,
        sheetUri,
      );
      if (rid != null) {
        w.writeEmptyElement(
          'drawing',
          attributes: <String, String>{'r:id': rid},
        );
      }
    }
    w.writeEndElement();
    return w.toXml();
  }

  static void _writeSheetViews(XmlWriter w, SmlWorksheet sheet) {
    if (!sheet.rightToLeft && sheet.freezeRows <= 0 && sheet.freezeCols <= 0) {
      return;
    }
    w.writeStartElement('sheetViews');
    w.writeStartElement('sheetView');
    w.writeAttribute('workbookViewId', '0');
    if (sheet.rightToLeft) {
      w.writeAttribute('rightToLeft', '1');
    }
    if (sheet.freezeRows > 0 || sheet.freezeCols > 0) {
      w.writeStartElement('pane');
      w.writeAttribute('xSplit', '${sheet.freezeCols}');
      w.writeAttribute('ySplit', '${sheet.freezeRows}');
      w.writeAttribute(
        'topLeftCell',
        SmlCellRef(sheet.freezeCols, sheet.freezeRows).a1,
      );
      w.writeAttribute('activePane', 'bottomRight');
      w.writeAttribute('state', 'frozen');
      w.writeEndElement();
    }
    w.writeEndElement();
    w.writeEndElement();
  }

  static void _writeCols(XmlWriter w, SmlWorksheet sheet) {
    if (sheet.columnWidths.isEmpty) {
      return;
    }
    final List<int> keys = sheet.columnWidths.keys.toList()..sort();
    w.writeStartElement('cols');
    var i = 0;
    while (i < keys.length) {
      final int start = keys[i];
      final double px = sheet.columnWidths[start]!;
      var end = start;
      while (i + 1 < keys.length &&
          keys[i + 1] == end + 1 &&
          (sheet.columnWidths[keys[i + 1]]! - px).abs() < 0.01) {
        i++;
        end = keys[i];
      }
      w.writeStartElement('col');
      w.writeAttribute('min', '${start + 1}');
      w.writeAttribute('max', '${end + 1}');
      w.writeAttribute('width', '${SmlWorksheet.columnWidthToExcel(px)}');
      w.writeAttribute('customWidth', '1');
      w.writeEndElement();
      i++;
    }
    w.writeEndElement();
  }
}
