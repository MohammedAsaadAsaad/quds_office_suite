import 'dart:convert';
import 'dart:typed_data';

import '../fonts/font_subsetter.dart';
import '../fonts/sfnt_parser.dart';
import '../opc/zip/crc32.dart';
import '../sheet/model/sml_workbook.dart';
import '../slide/model/pml_presentation.dart';
import '../word/model/wml_document.dart';
import 'office_pdf_export.dart';
import 'pdf_font.dart';
import 'pdf_stream.dart';

/// Native PDF 1.7 compiler.
class PdfDocument {
  /// PdfDocument API.
  PdfDocument({this.title = 'Quds Office', this.author = ''});

  /// title API.
  final String title;

  /// author API.
  final String author;

  /// pages API.
  final List<PdfPage> pages = <PdfPage>[];

  /// addPage API.
  void addPage(PdfPage page) => pages.add(page);

  /// Lays out [document] and emits a PDF with an optional embedded [font].
  static Uint8List fromWord(
    WmlDocument document, {
    SfntFont? font,
    String title = 'Quds Office',
  }) => OfficePdfExport.word(document, font: font, title: title);

  /// Landscape page per slide from a PPTX archive.
  static Uint8List fromPptx(
    Uint8List bytes, {
    SfntFont? font,
    String title = 'Quds Office',
    String? password,
  }) => OfficePdfExport.fromBytes(
    bytes,
    font: font,
    title: title,
    password: password,
  );

  /// Print-layout PDF for every worksheet in [book].
  static Uint8List fromWorkbook(
    SmlWorkbook book, {
    SfntFont? font,
    String title = 'Quds Office',
  }) => OfficePdfExport.workbook(book, font: font, title: title);

  /// One PDF page per slide from an in-memory deck.
  static Uint8List fromPresentation(
    PmlPresentation deck, {
    SfntFont? font,
    String title = 'Quds Office',
  }) => OfficePdfExport.presentation(deck, font: font, title: title);

  /// save API.
  Uint8List save({FontSubset? subset, SfntFont? font}) {
    final List<_PdfObj> objects = <_PdfObj>[];
    int nextId = 1;
    int alloc() => nextId++;

    final int infoId = alloc();
    final int catalogId = alloc();
    final int pagesId = alloc();
    final List<int> pageIds = <int>[for (final _ in pages) alloc()];
    final List<int> contentIds = <int>[for (final _ in pages) alloc()];
    int? fontId;
    int? cidId;
    int? descId;
    int? fileId;
    int? toUnicodeId;
    final int helveticaId = alloc();
    if (subset != null) {
      fontId = alloc();
      cidId = alloc();
      descId = alloc();
      fileId = alloc();
      toUnicodeId = alloc();
    }
    final List<List<int>> pageImageIds = <List<int>>[
      for (final PdfPage page in pages)
        <int>[for (final PdfEmbeddedImage _ in page.images) alloc()],
    ];
    final List<List<int>> pageAnnotIds = <List<int>>[
      for (final PdfPage page in pages)
        <int>[for (final PdfLinkAnnot _ in page.links) alloc()],
    ];

    objects.add(
      _PdfObj(
        infoId,
        '<</Title ${_pdfString(title)}/Author ${_pdfString(author)}/Producer ${_pdfString('Quds Office Engine')}>>',
      ),
    );

    final String kids = pageIds.map((int id) => '$id 0 R').join(' ');
    objects.add(
      _PdfObj(pagesId, '<</Type /Pages/Count ${pages.length}/Kids [$kids]>>'),
    );

    if (subset != null &&
        fontId != null &&
        cidId != null &&
        descId != null &&
        fileId != null &&
        toUnicodeId != null) {
      final PdfCidFont cid = PdfCidFont.build(subset, font!);
      objects.add(_PdfObj(fontId, cid.type0Dict(cidId, toUnicodeId)));
      objects.add(_PdfObj(cidId, cid.cidFontDict(descId)));
      objects.add(_PdfObj(descId, cid.descriptorDict(fileId)));
      objects.add(
        _PdfObj.stream(
          fileId,
          cid.fontFile,
          extra: '/Length1 ${cid.fontFile.length}',
        ),
      );
      objects.add(_PdfObj.stream(toUnicodeId, utf8.encode(cid.toUnicodeCmap)));
    }
    objects.add(
      _PdfObj(
        helveticaId,
        '<</Type /Font/Subtype /Type1/BaseFont /Helvetica>>',
      ),
    );
    for (int i = 0; i < pages.length; i++) {
      final PdfPage page = pages[i];
      for (int j = 0; j < page.links.length; j++) {
        objects.add(
          _PdfObj(pageAnnotIds[i][j], _linkDict(page.links[j], page, pageIds)),
        );
      }
    }
    for (int i = 0; i < pages.length; i++) {
      final PdfPage page = pages[i];
      for (int j = 0; j < page.images.length; j++) {
        final PdfEmbeddedImage img = page.images[j];
        final int id = pageImageIds[i][j];
        if (img.jpeg) {
          objects.add(
            _PdfObj.rawStream(
              id,
              img.bytes,
              extra:
                  '/Type /XObject/Subtype /Image/Width ${img.width}'
                  '/Height ${img.height}/ColorSpace /DeviceRGB'
                  '/BitsPerComponent 8/Filter /DCTDecode',
            ),
          );
        } else {
          objects.add(
            _PdfObj.stream(
              id,
              img.bytes,
              extra:
                  '/Type /XObject/Subtype /Image/Width ${img.width}'
                  '/Height ${img.height}/ColorSpace /DeviceRGB'
                  '/BitsPerComponent 8',
            ),
          );
        }
      }
    }

    for (int i = 0; i < pages.length; i++) {
      final PdfPage page = pages[i];
      final StringBuffer fonts = StringBuffer('/F2 $helveticaId 0 R');
      if (fontId != null) {
        fonts.write('/F1 $fontId 0 R');
      }
      final StringBuffer xos = StringBuffer();
      for (int j = 0; j < page.images.length; j++) {
        xos.write('/${page.images[j].name} ${pageImageIds[i][j]} 0 R');
      }
      final String xoRes = xos.isEmpty ? '' : '/XObject <<$xos>>';
      final String annots = pageAnnotIds[i].isEmpty
          ? ''
          : '/Annots [${pageAnnotIds[i].map((int id) => '$id 0 R').join(' ')}]';
      objects.add(
        _PdfObj(
          pageIds[i],
          '<</Type /Page/Parent $pagesId 0 R/MediaBox [0 0 ${_n(page.width)} ${_n(page.height)}]'
          '/Contents ${contentIds[i]} 0 R/Resources <</Font <<$fonts>>$xoRes'
          '/ProcSet [/PDF /Text /ImageC]>>$annots>>',
        ),
      );
      objects.add(_PdfObj.stream(contentIds[i], page.content));
    }

    objects.add(_PdfObj(catalogId, '<</Type /Catalog/Pages $pagesId 0 R>>'));

    objects.sort((a, b) => a.id - b.id);
    final BytesBuilder body = BytesBuilder(copy: false);
    body.add(utf8.encode('%PDF-1.7\n%\xE2\xE3\xCF\xD3\n'));
    final List<int> offsets = List<int>.filled(nextId, 0);
    for (final _PdfObj obj in objects) {
      offsets[obj.id] = body.length;
      body.add(obj.serialize());
    }
    final int xrefAt = body.length;
    final StringBuffer xref = StringBuffer('xref\n0 $nextId\n');
    xref.write('0000000000 65535 f \n');
    for (int i = 1; i < nextId; i++) {
      xref.write('${offsets[i].toString().padLeft(10, '0')} 00000 n \n');
    }
    body.add(utf8.encode(xref.toString()));
    final int id1 = Crc32.compute(utf8.encode(title));
    final int id2 = Crc32.compute(body.toBytes());
    body.add(
      utf8.encode(
        'trailer\n<</Size $nextId/Root $catalogId 0 R/Info $infoId 0 R'
        '/ID [<${id1.toRadixString(16).padLeft(8, '0')}>'
        '<${id2.toRadixString(16).padLeft(8, '0')}>]>>\n'
        'startxref\n$xrefAt\n%%EOF\n',
      ),
    );
    return body.takeBytes();
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(3);

  String _linkDict(PdfLinkAnnot link, PdfPage page, List<int> pageIds) {
    final double llx = link.x;
    final double lly = page.height - (link.y + link.height);
    final double urx = link.x + link.width;
    final double ury = page.height - link.y;
    final String rect = '${_n(llx)} ${_n(lly)} ${_n(urx)} ${_n(ury)}';
    final String action;
    final String? uri = link.uri;
    final int? destPage = link.destPage;
    final String? file = link.file;
    if (uri != null && uri.isNotEmpty) {
      action = '/A <</S /URI/URI ${_pdfUri(uri)}>>';
    } else if (destPage != null && destPage >= 0 && destPage < pageIds.length) {
      final double destTop = pages[destPage].height - (link.destY ?? 0);
      action =
          '/A <</S /GoTo/D [${pageIds[destPage]} 0 R /XYZ 0 ${_n(destTop)} 0]>>';
    } else if (file != null && file.isNotEmpty) {
      action = '/A <</S /Launch/F ${_pdfString(file)}>>';
    } else {
      action = '';
    }
    return '<</Type /Annot/Subtype /Link/Rect [$rect]/Border [0 0 0]/H /I$action>>';
  }

  static String _pdfString(String value) {
    final String escaped = value
        .replaceAll('\\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
    return '($escaped)';
  }

  static String _pdfUri(String value) {
    var ascii = true;
    for (final int unit in value.codeUnits) {
      if (unit < 32 || unit > 126) {
        ascii = false;
        break;
      }
    }
    if (ascii) {
      return _pdfString(value);
    }
    final String hex = utf8.encode(value).map((int b) {
      return b.toRadixString(16).padLeft(2, '0');
    }).join();
    return '<$hex>';
  }
}

/// Class PdfEmbeddedImage.
class PdfEmbeddedImage {
  /// PdfEmbeddedImage API.
  const PdfEmbeddedImage({
    required this.name,
    required this.width,
    required this.height,
    required this.bytes,
    this.jpeg = false,
  });

  /// name API.
  final String name;

  /// width API.
  final int width;

  /// height API.
  final int height;

  /// bytes API.
  final Uint8List bytes;

  /// jpeg API.
  final bool jpeg;
}

/// Class PdfLinkAnnot.
class PdfLinkAnnot {
  /// PdfLinkAnnot API.
  const PdfLinkAnnot({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.uri,
    this.destPage,
    this.destY,
    this.file,
  });

  /// x API.
  final double x;

  /// y API.
  final double y;

  /// width API.
  final double width;

  /// height API.
  final double height;

  /// uri API.
  final String? uri;

  /// destPage API.
  final int? destPage;

  /// destY API.
  final double? destY;

  /// file API.
  final String? file;
}

/// Class PdfPage.
class PdfPage {
  /// PdfPage API.
  PdfPage({
    required this.width,
    required this.height,
    required this.content,
    this.images = const <PdfEmbeddedImage>[],
    this.links = const <PdfLinkAnnot>[],
  });

  /// width API.
  final double width;

  /// height API.
  final double height;

  /// content API.
  final Uint8List content;

  /// images API.
  final List<PdfEmbeddedImage> images;

  /// links API.
  final List<PdfLinkAnnot> links;
}

class _PdfObj {
  /// stream API.
  _PdfObj(this.id, this.dict) : stream = null, extra = '';

  /// stream API.
  _PdfObj.stream(this.id, List<int> data, {this.extra = ''})
    : dict = '',
      stream = PdfFlate.compress(data);

  /// rawStream API.
  _PdfObj.rawStream(this.id, List<int> data, {this.extra = ''})
    : dict = '',
      stream = data is Uint8List ? data : Uint8List.fromList(data);

  /// id API.
  final int id;

  /// dict API.
  final String dict;

  /// stream API.
  final Uint8List? stream;

  /// extra API.
  final String extra;

  /// serialize API.
  Uint8List serialize() {
    if (stream == null) {
      return utf8.encode('$id 0 obj\n$dict\nendobj\n');
    }
    final String filter = extra.contains('/Filter')
        ? ''
        : '/Filter /FlateDecode ';
    final String header =
        '$id 0 obj\n<</Length ${stream!.length}$filter$extra>>\nstream\n';
    final BytesBuilder b = BytesBuilder(copy: false);
    b.add(utf8.encode(header));
    b.add(stream!);
    b.add(utf8.encode('\nendstream\nendobj\n'));
    return b.takeBytes();
  }
}
