import 'xml_reader.dart';
import 'xml_writer.dart';

/// Lightweight mutable XML node.
sealed class XmlNode {
  XmlNode({this.parent});

  XmlElement? parent;

  XmlNode copy();

  void writeTo(XmlWriter writer);
}

/// Attribute on an [XmlElement].
class XmlAttribute {
  XmlAttribute({
    required this.localName,
    required this.value,
    this.prefix = '',
    this.namespaceUri = '',
  });

  String localName;
  String value;
  String prefix;
  String namespaceUri;

  String get qualifiedName => prefix.isEmpty ? localName : '$prefix:$localName';

  XmlAttribute copy() => XmlAttribute(
    localName: localName,
    value: value,
    prefix: prefix,
    namespaceUri: namespaceUri,
  );
}

/// Element node with attributes and ordered children.
class XmlElement extends XmlNode {
  XmlElement({
    required this.localName,
    this.prefix = '',
    this.namespaceUri = '',
    List<XmlAttribute>? attributes,
    List<XmlNode>? children,
    super.parent,
  }) : attributes = attributes ?? <XmlAttribute>[],
       children = children ?? <XmlNode>[];

  String localName;
  String prefix;
  String namespaceUri;
  final List<XmlAttribute> attributes;
  final List<XmlNode> children;

  String get qualifiedName => prefix.isEmpty ? localName : '$prefix:$localName';

  String? getAttribute(String localName, {String? namespaceUri}) {
    for (final XmlAttribute attr in attributes) {
      if (attr.localName != localName) {
        continue;
      }
      if (namespaceUri == null || attr.namespaceUri == namespaceUri) {
        return attr.value;
      }
    }
    return null;
  }

  void setAttribute(
    String localName,
    String value, {
    String prefix = '',
    String namespaceUri = '',
  }) {
    for (final XmlAttribute attr in attributes) {
      if (attr.localName == localName &&
          (namespaceUri.isEmpty || attr.namespaceUri == namespaceUri)) {
        attr.value = value;
        if (prefix.isNotEmpty) {
          attr.prefix = prefix;
        }
        if (namespaceUri.isNotEmpty) {
          attr.namespaceUri = namespaceUri;
        }
        return;
      }
    }
    attributes.add(
      XmlAttribute(
        localName: localName,
        value: value,
        prefix: prefix,
        namespaceUri: namespaceUri,
      ),
    );
  }

  void removeAttribute(String localName, {String? namespaceUri}) {
    attributes.removeWhere((XmlAttribute attr) {
      if (attr.localName != localName) {
        return false;
      }
      return namespaceUri == null || attr.namespaceUri == namespaceUri;
    });
  }

  void addChild(XmlNode node) {
    node.parent = this;
    children.add(node);
  }

  void addText(String text) {
    if (text.isEmpty) {
      return;
    }
    addChild(XmlText(text));
  }

  Iterable<XmlElement> get childElements sync* {
    for (final XmlNode child in children) {
      if (child is XmlElement) {
        yield child;
      }
    }
  }

  XmlElement? firstChild(String localName, {String? namespaceUri}) {
    for (final XmlElement child in childElements) {
      if (child.localName != localName) {
        continue;
      }
      if (namespaceUri == null || child.namespaceUri == namespaceUri) {
        return child;
      }
    }
    return null;
  }

  List<XmlElement> childrenNamed(String localName, {String? namespaceUri}) {
    return childElements
        .where((XmlElement e) {
          if (e.localName != localName) {
            return false;
          }
          return namespaceUri == null || e.namespaceUri == namespaceUri;
        })
        .toList(growable: false);
  }

  String get text {
    final StringBuffer buffer = StringBuffer();
    _collectText(this, buffer);
    return buffer.toString();
  }

  set text(String value) {
    children
      ..clear()
      ..add(XmlText(value)..parent = this);
  }

  @override
  XmlElement copy() {
    final XmlElement clone = XmlElement(
      localName: localName,
      prefix: prefix,
      namespaceUri: namespaceUri,
      attributes: attributes
          .map((XmlAttribute a) => a.copy())
          .toList(growable: true),
    );
    for (final XmlNode child in children) {
      clone.addChild(child.copy());
    }
    return clone;
  }

  @override
  void writeTo(XmlWriter writer) {
    writer.writeStartElement(localName, prefix: prefix.isEmpty ? null : prefix);
    for (final XmlAttribute attr in attributes) {
      writer.writeAttribute(attr.qualifiedName, attr.value);
    }
    if (children.isEmpty) {
      writer.writeEndElement();
      return;
    }
    for (final XmlNode child in children) {
      child.writeTo(writer);
    }
    writer.writeEndElement();
  }

  static void _collectText(XmlNode node, StringBuffer buffer) {
    switch (node) {
      case XmlText(:final String text):
        buffer.write(text);
      case XmlCdata(:final String text):
        buffer.write(text);
      case XmlElement(:final List<XmlNode> children):
        for (final XmlNode child in children) {
          _collectText(child, buffer);
        }
      case XmlComment():
        break;
    }
  }
}

/// Character data node.
class XmlText extends XmlNode {
  XmlText(this.text, {super.parent});

  String text;

  @override
  XmlText copy() => XmlText(text);

  @override
  void writeTo(XmlWriter writer) => writer.writeText(text);
}

/// CDATA node.
class XmlCdata extends XmlNode {
  XmlCdata(this.text, {super.parent});

  String text;

  @override
  XmlCdata copy() => XmlCdata(text);

  @override
  void writeTo(XmlWriter writer) => writer.writeCdata(text);
}

/// Comment node.
class XmlComment extends XmlNode {
  XmlComment(this.text, {super.parent});

  String text;

  @override
  XmlComment copy() => XmlComment(text);

  @override
  void writeTo(XmlWriter writer) => writer.writeComment(text);
}

/// Document wrapper holding an optional XML declaration and a root element.
class XmlDocument {
  XmlDocument({this.root, this.standalone = true});

  XmlElement? root;
  bool standalone;

  factory XmlDocument.parse(String xml) {
    final XmlPullReader reader = XmlPullReader(xml);
    final XmlDocument doc = XmlDocument();
    final List<XmlElement> stack = <XmlElement>[];
    while (reader.next()) {
      switch (reader.eventType) {
        case XmlEventType.xmlDeclaration:
          if (reader.text.contains('standalone="no"')) {
            doc.standalone = false;
          }
        case XmlEventType.startElement:
          final XmlElement element = XmlElement(
            localName: reader.localName,
            prefix: reader.prefix,
            namespaceUri: reader.namespaceUri,
          );
          for (int i = 0; i < reader.attributeCount; i++) {
            element.attributes.add(
              XmlAttribute(
                localName: reader.attributeLocalName(i),
                value: reader.attributeValue(i),
                prefix: reader.attributePrefix(i),
                namespaceUri: reader.attributeNamespace(i),
              ),
            );
          }
          if (stack.isEmpty) {
            doc.root = element;
          } else {
            stack.last.addChild(element);
          }
          stack.add(element);
        case XmlEventType.endElement:
          if (stack.isNotEmpty) {
            stack.removeLast();
          }
        case XmlEventType.characters:
          if (stack.isEmpty) {
            break;
          }
          if (reader.isWhitespace && stack.last.children.isEmpty) {
            break;
          }
          stack.last.addText(reader.text);
        case XmlEventType.cdata:
          if (stack.isNotEmpty) {
            stack.last.addChild(XmlCdata(reader.text));
          }
        case XmlEventType.comment:
          if (stack.isNotEmpty) {
            stack.last.addChild(XmlComment(reader.text));
          }
        case XmlEventType.endDocument:
        case XmlEventType.none:
        case XmlEventType.processingInstruction:
        case XmlEventType.dtd:
          break;
      }
    }
    return doc;
  }

  String toXmlString({bool declaration = true}) {
    final XmlWriter writer = XmlWriter();
    if (declaration) {
      writer.writeStartDocument(standalone: standalone);
    }
    root?.writeTo(writer);
    return writer.toXml();
  }
}
