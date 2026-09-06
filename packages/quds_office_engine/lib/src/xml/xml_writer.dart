import 'xml_reader.dart';

/// High-speed buffered XML 1.0 serializer.
///
/// Writes compact Office-compatible XML (no pretty-print). Namespace
/// prefixes are emitted exactly as the caller specifies.
class XmlWriter {
  XmlWriter({StringSink? sink}) : _sink = sink ?? StringBuffer();

  final StringSink _sink;
  final List<_OpenElement> _stack = <_OpenElement>[];
  bool _inStartTag = false;
  bool _declarationWritten = false;

  void writeStartDocument({
    String version = '1.0',
    String encoding = 'UTF-8',
    bool standalone = true,
  }) {
    if (_declarationWritten) {
      throw StateError('XML declaration already written');
    }
    _sink
      ..write('<?xml version="')
      ..write(version)
      ..write('" encoding="')
      ..write(encoding)
      ..write('" standalone="')
      ..write(standalone ? 'yes' : 'no')
      ..write('"?>');
    _declarationWritten = true;
  }

  void writeProcessingInstruction(String target, String data) {
    _closeStartTag();
    _sink
      ..write('<?')
      ..write(target);
    if (data.isNotEmpty) {
      _sink
        ..write(' ')
        ..write(data);
    }
    _sink.write('?>');
  }

  void writeComment(String text) {
    _closeStartTag();
    if (text.contains('--')) {
      throw ArgumentError('XML comments cannot contain --');
    }
    _sink
      ..write('<!--')
      ..write(text)
      ..write('-->');
  }

  void writeStartElement(
    String localName, {
    String? prefix,
    String? namespaceUri,
  }) {
    _closeStartTag();
    _sink.write('<');
    final String qname = _qname(prefix, localName);
    _sink.write(qname);
    _stack.add(_OpenElement(qname: qname, namespaceUri: namespaceUri));
    _inStartTag = true;
    if (namespaceUri != null && prefix != null) {
      writeAttribute(prefix.isEmpty ? 'xmlns' : 'xmlns:$prefix', namespaceUri);
    } else if (namespaceUri != null && prefix == null) {
      writeAttribute('xmlns', namespaceUri);
    }
  }

  void writeEmptyElement(
    String localName, {
    String? prefix,
    String? namespaceUri,
    Map<String, String>? attributes,
  }) {
    writeStartElement(localName, prefix: prefix, namespaceUri: namespaceUri);
    if (attributes != null) {
      attributes.forEach(writeAttribute);
    }
    writeEndElement();
  }

  void writeAttribute(String name, String value) {
    if (!_inStartTag) {
      throw StateError('Attributes can only be written on an open start tag');
    }
    _sink
      ..write(' ')
      ..write(name)
      ..write('="')
      ..write(encodeXmlAttribute(value))
      ..write('"');
  }

  void writeNamespace(String prefix, String uri) {
    if (prefix.isEmpty) {
      writeAttribute('xmlns', uri);
    } else {
      writeAttribute('xmlns:$prefix', uri);
    }
  }

  void writeText(String text) {
    _closeStartTag();
    _sink.write(encodeXmlText(text));
  }

  void writeCdata(String text) {
    _closeStartTag();
    if (text.contains(']]>')) {
      throw ArgumentError('CDATA cannot contain ]]>');
    }
    _sink
      ..write('<![CDATA[')
      ..write(text)
      ..write(']]>');
  }

  void writeRaw(String xml) {
    _closeStartTag();
    _sink.write(xml);
  }

  void writeEndElement() {
    if (_stack.isEmpty) {
      throw StateError('No open element to close');
    }
    final _OpenElement open = _stack.removeLast();
    if (_inStartTag) {
      _sink.write('/>');
      _inStartTag = false;
      return;
    }
    _sink
      ..write('</')
      ..write(open.qname)
      ..write('>');
  }

  void writeEndDocument() {
    while (_stack.isNotEmpty) {
      writeEndElement();
    }
  }

  String toXml() {
    writeEndDocument();
    return _sink.toString();
  }

  @override
  String toString() => _sink.toString();

  void _closeStartTag() {
    if (_inStartTag) {
      _sink.write('>');
      _inStartTag = false;
    }
  }

  static String _qname(String? prefix, String localName) {
    if (prefix == null || prefix.isEmpty) {
      return localName;
    }
    return '$prefix:$localName';
  }
}

class _OpenElement {
  _OpenElement({required this.qname, this.namespaceUri});

  final String qname;
  final String? namespaceUri;
}
