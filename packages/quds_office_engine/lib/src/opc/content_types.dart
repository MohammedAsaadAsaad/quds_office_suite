import '../xml/namespaces.dart';
import '../xml/xml_reader.dart';
import '../xml/xml_writer.dart';
import 'package_part.dart';

/// Parsed `[Content_Types].xml` (Defaults + Overrides).
class ContentTypes {
  ContentTypes({Map<String, String>? defaults, Map<String, String>? overrides})
    : defaults = defaults ?? <String, String>{},
      overrides = overrides ?? <String, String>{};

  /// File extension (without dot, lower-case) → MIME type.
  final Map<String, String> defaults;

  /// Absolute OPC part name → MIME type.
  final Map<String, String> overrides;

  factory ContentTypes.standard() {
    return ContentTypes(
      defaults: <String, String>{
        'rels': 'application/vnd.openxmlformats-package.relationships+xml',
        'xml': 'application/xml',
        'bin': 'application/vnd.openxmlformats-officedocument.oleObject',
        'png': 'image/png',
        'jpeg': 'image/jpeg',
        'jpg': 'image/jpeg',
        'gif': 'image/gif',
        'emf': 'image/x-emf',
        'wmf': 'image/x-wmf',
        'svg': 'image/svg+xml',
      },
    );
  }

  factory ContentTypes.parse(String xml) {
    final ContentTypes types = ContentTypes();
    final XmlPullReader reader = XmlPullReader(xml);
    while (reader.next()) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      if (reader.localName == 'Default') {
        final String? ext = reader.getAttribute('Extension');
        final String? type = reader.getAttribute('ContentType');
        if (ext != null && type != null) {
          types.defaults[ext.toLowerCase()] = type;
        }
      } else if (reader.localName == 'Override') {
        final String? part = reader.getAttribute('PartName');
        final String? type = reader.getAttribute('ContentType');
        if (part != null && type != null) {
          types.overrides[OpcUris.normalize(part)] = type;
        }
      }
    }
    return types;
  }

  String contentTypeFor(String partUri) {
    final String uri = OpcUris.normalize(partUri);
    final String? overrideType = overrides[uri];
    if (overrideType != null) {
      return overrideType;
    }
    final int dot = uri.lastIndexOf('.');
    if (dot < 0 || dot == uri.length - 1) {
      return 'application/octet-stream';
    }
    final String ext = uri.substring(dot + 1).toLowerCase();
    return defaults[ext] ?? 'application/octet-stream';
  }

  void setOverride(String partUri, String contentType) {
    overrides[OpcUris.normalize(partUri)] = contentType;
  }

  void removeOverride(String partUri) {
    overrides.remove(OpcUris.normalize(partUri));
  }

  void setDefault(String extension, String contentType) {
    defaults[extension.toLowerCase()] = contentType;
  }

  String toXml() {
    final XmlWriter writer = XmlWriter();
    writer.writeStartDocument();
    writer.writeStartElement(
      'Types',
      namespaceUri: OfficeNamespaces.contentTypes,
    );
    final List<String> extKeys = defaults.keys.toList()..sort();
    for (final String ext in extKeys) {
      writer.writeStartElement('Default');
      writer.writeAttribute('Extension', ext);
      writer.writeAttribute('ContentType', defaults[ext]!);
      writer.writeEndElement();
    }
    final List<String> partKeys = overrides.keys.toList()..sort();
    for (final String part in partKeys) {
      writer.writeStartElement('Override');
      writer.writeAttribute('PartName', part);
      writer.writeAttribute('ContentType', overrides[part]!);
      writer.writeEndElement();
    }
    writer.writeEndElement();
    return writer.toXml();
  }
}

/// Well-known OPC / Office content types.
abstract final class OfficeContentTypes {
  static const String relationships =
      'application/vnd.openxmlformats-package.relationships+xml';
  static const String coreProperties =
      'application/vnd.openxmlformats-package.core-properties+xml';
  static const String wordMain =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml';
  static const String wordTemplate =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.template.main+xml';
  static const String sheetMain =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml';
  static const String sheetWorksheet =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml';
  static const String sheetSharedStrings =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml';
  static const String sheetStyles =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml';
  static const String slideMain =
      'application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml';
  static const String slide =
      'application/vnd.openxmlformats-officedocument.presentationml.slide+xml';
  static const String slideLayout =
      'application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml';
  static const String slideMaster =
      'application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml';
  static const String oleObject =
      'application/vnd.openxmlformats-officedocument.oleObject';
  static const String extendedProperties =
      'application/vnd.openxmlformats-officedocument.extended-properties+xml';
  static const String wordStyles =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml';
  static const String wordSettings =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml';
  static const String wordNumbering =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml';
  static const String wordComments =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml';
  static const String wordCommentsExtended =
      'application/vnd.ms-word.commentsExtended+xml';
  static const String drawingChart =
      'application/vnd.openxmlformats-officedocument.drawingml.chart+xml';
  static const String theme =
      'application/vnd.openxmlformats-officedocument.theme+xml';
  static const String slidePresProps =
      'application/vnd.openxmlformats-officedocument.presentationml.presProps+xml';
  static const String slideViewProps =
      'application/vnd.openxmlformats-officedocument.presentationml.viewProps+xml';
  static const String slideTableStyles =
      'application/vnd.openxmlformats-officedocument.presentationml.tableStyles+xml';
  static const String notesSlide =
      'application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml';
  static const String notesMaster =
      'application/vnd.openxmlformats-officedocument.presentationml.notesMaster+xml';
  static const String wordHeader =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml';
  static const String wordFooter =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml';
  static const String spreadsheetDrawing =
      'application/vnd.openxmlformats-officedocument.drawing+xml';
}
