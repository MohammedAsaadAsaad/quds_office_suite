import 'dart:convert';
import 'dart:typed_data';

import '../../builders/drawingml_charts.dart';
import '../../builders/office_markup.dart';
import '../../office/office_document_properties.dart';
import '../../opc/content_types.dart';
import '../../opc/opc_archive.dart';
import '../../opc/package_part.dart';
import '../../opc/relationships.dart';
import '../../sheet/serial/sheet_drawing_io.dart';
import '../../visual/office_visual.dart';
import '../../visual/png_bytes.dart';
import '../../xml/namespaces.dart';
import '../../xml/xml_reader.dart';
import '../../xml/xml_writer.dart';
import '../anim/pml_motion_io.dart';
import '../model/pml_presentation.dart';
import '../shapes/drawingml.dart';

/// Class SlideDeserializer.
class SlideDeserializer {
  /// read API.
  PmlPresentation read(OpcPackage package) {
    final PmlPresentation pres = PmlPresentation(
      package: package,
      slides: <PmlSlide>[],
      properties: OfficeDocumentProperties.fromPackage(package),
    );
    final part = package.getPart('/ppt/presentation.xml');
    if (part == null) {
      return pres;
    }
    final XmlPullReader reader = XmlPullReader(part.readText());
    while (reader.next()) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      if (reader.localName == 'sldId') {
        final int id = int.parse(reader.getAttribute('id') ?? '256');
        pres.slides.add(PmlSlide(id: id));
      } else if (reader.localName == 'sldSection') {
        final String name = reader.getAttribute('name') ?? 'Section';
        final int start = int.tryParse(reader.getAttribute('start') ?? '0') ?? 0;
        pres.sections.add(PmlSection(name: name, startIndex: start));
      } else if (reader.localName == 'sldSz') {
        pres.slideWidth = int.parse(
          reader.getAttribute('cx') ?? '${pres.slideWidth}',
        );
        pres.slideHeight = int.parse(
          reader.getAttribute('cy') ?? '${pres.slideHeight}',
        );
      }
    }
    final String? masterBg = _masterBackground(package);
    if (masterBg != null && masterBg.isNotEmpty) {
      pres.master.background = masterBg;
    }
    for (int i = 0; i < pres.slides.length; i++) {
      final String uri = '/ppt/slides/slide${i + 1}.xml';
      final slidePart = package.getPart(uri);
      if (slidePart != null) {
        final String slideXml = slidePart.readText();
        pres.slides[i].shapes.addAll(parseSlideShapes(slideXml));
        parseSlideMotion(slideXml, pres.slides[i]);
        pres.slides[i].hidden = _slideIsHidden(slideXml);
        final RelationshipCollection rels = package.relationshipsFor(uri);
        _bindSlideMedia(pres.slides[i], package, rels);
        final PackageRelationship? notesRel = rels.firstByType(
          RelationshipTypes.notesSlide,
        );
        if (notesRel != null) {
          final notesPart = package.getPart(rels.resolve(notesRel));
          if (notesPart != null) {
            pres.slides[i].notes = parseSlideShapes(notesPart.readText())
                .map((PmlShape s) => s.text.trim())
                .where((String t) => t.isNotEmpty)
                .join('\n');
          }
        }
      }
    }
    return pres;
  }

  /// readBytes API.
  PmlPresentation readBytes(Uint8List bytes, {String? password}) =>
      read(OpcPackage.openBytes(bytes, password: password));

  static bool _slideIsHidden(String xml) {
    final int start = xml.indexOf('<p:sld');
    if (start < 0) {
      return false;
    }
    final int end = xml.indexOf('>', start);
    if (end < 0) {
      return false;
    }
    final String attrs = xml.substring(start, end);
    return RegExp(r'''\bshow\s*=\s*["'](?:0|false)["']''').hasMatch(attrs);
  }

  static String? _masterBackground(OpcPackage package) {
    for (final String uri in <String>[
      '/ppt/slideMasters/slideMaster1.xml',
      '/ppt/slideMasters/slideMaster2.xml',
    ]) {
      final part = package.getPart(uri);
      if (part == null) {
        continue;
      }
      final XmlPullReader reader = XmlPullReader(part.readText());
      var inBg = false;
      var fillPending = false;
      while (reader.next()) {
        if (reader.eventType == XmlEventType.endElement) {
          if (reader.localName == 'bg' || reader.localName == 'bgPr') {
            inBg = false;
            fillPending = false;
          }
          continue;
        }
        if (reader.eventType != XmlEventType.startElement) {
          continue;
        }
        if (reader.localName == 'bg' || reader.localName == 'bgPr') {
          inBg = true;
        } else if (reader.localName == 'solidFill' && inBg) {
          fillPending = true;
        } else if (reader.localName == 'srgbClr' && fillPending) {
          final String? val = reader.getAttribute('val');
          if (val != null && val.isNotEmpty) {
            return val;
          }
        }
      }
    }
    return null;
  }

  static void _bindSlideMedia(
    PmlSlide slide,
    OpcPackage package,
    RelationshipCollection rels,
  ) {
    for (final PmlShape shape in slide.shapes) {
      final String? rid = shape.embedRelId;
      if (rid == null || rid.isEmpty) {
        continue;
      }
      final PackageRelationship? rel = rels.byId(rid);
      if (rel == null) {
        continue;
      }
      final part = package.getPart(rels.resolve(rel));
      if (part == null) {
        continue;
      }
      if (rel.type == RelationshipTypes.image) {
        final PictureAdjust picture =
            shape.visual?.picture.copy() ?? PictureAdjust();
        shape.visual = OfficeVisual(
          kind: shape.visual?.kind ?? OfficeVisualKind.picture,
          title: shape.visual?.title ?? shape.name,
          imageBytes: part.readBytes(),
          width: shape.transform.widthPoints,
          height: shape.transform.heightPoints,
          picture: picture,
        );
      } else if (rel.type == RelationshipTypes.chart) {
        shape.visual = parseChartVisual(
          part.readText(),
          width: shape.transform.widthPoints,
          height: shape.transform.heightPoints,
        );
      }
    }
  }
}

/// Class SlideSerializer.
class SlideSerializer {
  /// writeBytes API.
  Uint8List writeBytes(PmlPresentation pres, {String? password}) =>
      write(pres).save(password: password);

  /// write API.
  OpcPackage write(PmlPresentation pres) {
    final OpcPackage package =
        pres.package ?? OpcPackage.create(OpcPackageKind.slide);
    package.getPart('/ppt/presentation.xml')!.writeText(_presentationXml(pres));
    for (int i = 0; i < pres.slides.length; i++) {
      final String uri = '/ppt/slides/slide${i + 1}.xml';
      if (package.getPart(uri) == null) {
        package.createPart(uri, OfficeContentTypes.slide, utf8.encode(''));
        package
            .relationshipsFor('/ppt/presentation.xml')
            .add(
              type: RelationshipTypes.slide,
              target: 'slides/slide${i + 1}.xml',
            );
      }
      final Map<PmlShape, String> embedIds = _syncSlideVisuals(
        pres.slides[i],
        package,
        uri,
      );
      package
          .getPart(uri)!
          .writeText(slideToXml(pres.slides[i], embedIds: embedIds));
      _syncNotesSlide(pres.slides[i], package, uri, i + 1);
    }
    pres.properties.writeToPackage(package);
    pres.package = package;
    return package;
  }

  static Map<PmlShape, String> _syncSlideVisuals(
    PmlSlide slide,
    OpcPackage package,
    String slideUri,
  ) {
    final Map<PmlShape, String> ids = <PmlShape, String>{};
    final RelationshipCollection rels = package.relationshipsFor(slideUri);
    var mediaIndex = 1;
    var chartIndex = 1;
    for (final PmlShape shape in slide.shapes) {
      final OfficeVisual? visual = shape.visual;
      if (visual == null) {
        continue;
      }
      if (visual.isChart) {
        final String uri = '/ppt/charts/chart$chartIndex.xml';
        chartIndex++;
        final String xml = _chartXml(visual);
        final PackagePart? existing = package.getPart(uri);
        if (existing == null) {
          package.createPart(
            uri,
            OfficeContentTypes.drawingChart,
            utf8.encode(xml),
          );
        } else {
          existing.writeText(xml);
        }
        final String target = OpcUris.relativize(slideUri, uri);
        PackageRelationship? found;
        for (final PackageRelationship rel in rels.items) {
          if (rel.target == target && rel.type == RelationshipTypes.chart) {
            found = rel;
            break;
          }
        }
        found ??= rels.add(type: RelationshipTypes.chart, target: target);
        ids[shape] = found.id;
        shape.embedRelId = found.id;
        continue;
      }
      if (!visual.isPicture && !visual.isDiagram) {
        continue;
      }
      final Uint8List bytes = PngBytes.fromVisual(visual);
      final String mime = WordLikeMedia.mimeOf(bytes);
      final String uri =
          '/ppt/media/image$mediaIndex${WordLikeMedia.extensionOf(mime)}';
      mediaIndex++;
      final PackagePart? existing = package.getPart(uri);
      if (existing == null) {
        package.createPart(uri, mime, bytes);
      } else {
        existing.writeBytes(bytes);
      }
      final String target = OpcUris.relativize(slideUri, uri);
      PackageRelationship? found;
      for (final PackageRelationship rel in rels.items) {
        if (rel.target == target && rel.type == RelationshipTypes.image) {
          found = rel;
          break;
        }
      }
      found ??= rels.add(type: RelationshipTypes.image, target: target);
      ids[shape] = found.id;
      shape.embedRelId = found.id;
    }
    return ids;
  }

  static String _chartXml(OfficeVisual visual) {
    final String title = visual.title.isEmpty ? 'Chart' : visual.title;
    final List<ChartPoint> points = visual.points.isEmpty
        ? OfficeVisual.sampleSeries()
        : visual.points;
    final bool rtl = visual.chart.rtl;
    return switch (visual.kind) {
      OfficeVisualKind.chartPie => DrawingmlCharts.pie(
        title: title,
        series: points,
        rtl: rtl,
        display: visual.chart,
      ),
      OfficeVisualKind.chartLine => DrawingmlCharts.line(
        title: title,
        series: <ChartSeries>[ChartSeries(name: title, points: points)],
        rtl: rtl,
        display: visual.chart,
      ),
      OfficeVisualKind.chartBar => DrawingmlCharts.bar(
        title: title,
        series: points,
        rtl: rtl,
        display: visual.chart,
      ),
      _ => DrawingmlCharts.bar(
        title: title,
        series: points,
        rtl: rtl,
        horizontal: false,
        display: visual.chart,
      ),
    };
  }

  String _presentationXml(PmlPresentation pres) {
    final XmlWriter w = XmlWriter();
    w.writeStartDocument();
    w.writeStartElement('presentation', prefix: 'p');
    w.writeNamespace('p', OfficeNamespaces.p);
    w.writeNamespace('r', OfficeNamespaces.r);
    w.writeStartElement('sldIdLst', prefix: 'p');
    for (int i = 0; i < pres.slides.length; i++) {
      w.writeStartElement('sldId', prefix: 'p');
      w.writeAttribute('id', '${pres.slides[i].id}');
      w.writeAttribute('r:id', 'rId${i + 1}');
      w.writeEndElement();
    }
    w.writeEndElement();
    w.writeStartElement('sldSz', prefix: 'p');
    w.writeAttribute('cx', '${pres.slideWidth}');
    w.writeAttribute('cy', '${pres.slideHeight}');
    w.writeEndElement();
    if (pres.sections.isNotEmpty) {
      w.writeStartElement('sldSections', prefix: 'p');
      for (final PmlSection section in pres.sections) {
        w.writeEmptyElement(
          'sldSection',
          prefix: 'p',
          attributes: <String, String>{
            'name': section.name,
            'start': '${section.startIndex}',
          },
        );
      }
      w.writeEndElement();
    }
    w.writeEndElement();
    return w.toXml();
  }

  static void _syncNotesSlide(
    PmlSlide slide,
    OpcPackage package,
    String slideUri,
    int index,
  ) {
    if (slide.notes.trim().isEmpty) {
      return;
    }
    final String uri = '/ppt/notesSlides/notesSlide$index.xml';
    final String escaped = slide.notes
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final String xml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:notes xmlns:a="${OfficeNamespaces.a}" xmlns:r="${OfficeNamespaces.r}" '
        'xmlns:p="${OfficeNamespaces.p}">'
        '<p:cSld><p:spTree>'
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr/>'
        '<p:sp><p:nvSpPr><p:cNvPr id="2" name="Notes"/><p:cNvSpPr txBox="1"/>'
        '<p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr>'
        '<p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/>'
        '<a:p><a:r><a:t>$escaped</a:t></a:r></a:p>'
        '</p:txBody></p:sp>'
        '</p:spTree></p:cSld></p:notes>';
    final PackagePart? existing = package.getPart(uri);
    if (existing == null) {
      package.createPart(uri, OfficeContentTypes.notesSlide, utf8.encode(xml));
    } else {
      existing.writeText(xml);
    }
    final RelationshipCollection rels = package.relationshipsFor(slideUri);
    if (rels.firstByType(RelationshipTypes.notesSlide) == null) {
      rels.add(
        type: RelationshipTypes.notesSlide,
        target: '../notesSlides/notesSlide$index.xml',
      );
    }
  }
}
