/// ECMA-376 / OPC namespace URIs used across Word, Excel, PowerPoint, and DrawingML.
abstract final class OfficeNamespaces {
  static const String contentTypes =
      'http://schemas.openxmlformats.org/package/2006/content-types';
  static const String relationships =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const String officeRelationships =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const String officeRelationshipsOfficeDocument =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument';

  /// WordprocessingML (`w:`).
  static const String w =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

  /// Word 2012 comment extensions (`w15:`).
  static const String w15 =
      'http://schemas.microsoft.com/office/word/2012/wordml';

  /// Shared office relationships (`r:`).
  static const String r =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  /// Office Math (`m:`).
  static const String m =
      'http://schemas.openxmlformats.org/officeDocument/2006/math';

  /// DrawingML main (`a:`).
  static const String a =
      'http://schemas.openxmlformats.org/drawingml/2006/main';

  /// PresentationML (`p:`).
  static const String p =
      'http://schemas.openxmlformats.org/presentationml/2006/main';

  /// SpreadsheetML (`x:` / `main`).
  static const String x =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

  /// VML (`v:`).
  static const String v = 'urn:schemas-microsoft-com:vml';

  /// Office VML / OLE (`o:`).
  static const String o = 'urn:schemas-microsoft-com:office:office';

  /// Markup compatibility (`mc:`).
  static const String mc =
      'http://schemas.openxmlformats.org/markup-compatibility/2006';

  /// Word 2010 (`w14:`).
  static const String w14 =
      'http://schemas.microsoft.com/office/word/2010/wordml';

  /// DrawingML Wordprocessing Drawing (`wp:`).
  static const String wp =
      'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';

  /// DrawingML Chart (`c:`).
  static const String c =
      'http://schemas.openxmlformats.org/drawingml/2006/chart';

  /// DrawingML Picture (`pic:`).
  static const String pic =
      'http://schemas.openxmlformats.org/drawingml/2006/picture';

  /// Spreadsheet DrawingML (`xdr:`).
  static const String xdr =
      'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing';

  /// DrawingML table (`a:tbl` graphicData URI).
  static const String drawingmlTable =
      'http://schemas.openxmlformats.org/drawingml/2006/table';

  /// XML namespace (`xml:`).
  static const String xml = 'http://www.w3.org/XML/1998/namespace';

  /// XML Schema instance.
  static const String xsi = 'http://www.w3.org/2001/XMLSchema-instance';

  /// Dublin Core.
  static const String dc = 'http://purl.org/dc/elements/1.1/';
  static const String dcterms = 'http://purl.org/dc/terms/';
  static const String coreProperties =
      'http://schemas.openxmlformats.org/package/2006/metadata/core-properties';
  static const String extendedProperties =
      'http://schemas.openxmlformats.org/officeDocument/2006/extended-properties';
  static const String customProperties =
      'http://schemas.openxmlformats.org/officeDocument/2006/custom-properties';
  static const String docPropsVt =
      'http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes';

  static const Map<String, String> prefixToUri = <String, String>{
    'w': w,
    'r': r,
    'm': m,
    'a': a,
    'p': p,
    'x': x,
    'v': v,
    'o': o,
    'mc': mc,
    'w14': w14,
    'wp': wp,
    'c': c,
    'pic': pic,
    'xdr': xdr,
    'xml': xml,
    'xsi': xsi,
    'dc': dc,
    'dcterms': dcterms,
    'cp': coreProperties,
    'vt': docPropsVt,
  };

  static const Map<String, String> uriToPrefix = <String, String>{
    w: 'w',
    r: 'r',
    m: 'm',
    a: 'a',
    p: 'p',
    x: 'x',
    v: 'v',
    o: 'o',
    mc: 'mc',
    w14: 'w14',
    wp: 'wp',
    c: 'c',
    pic: 'pic',
    xdr: 'xdr',
    xml: 'xml',
    xsi: 'xsi',
    dc: 'dc',
    dcterms: 'dcterms',
    coreProperties: 'cp',
    docPropsVt: 'vt',
    contentTypes: '',
    relationships: '',
  };

  static String? prefixFor(String namespaceUri) => uriToPrefix[namespaceUri];

  static String? uriFor(String prefix) => prefixToUri[prefix];
}

/// OPC relationship type URIs used when allocating `.rels` entries.
abstract final class RelationshipTypes {
  static const String officeDocument =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument';
  static const String coreProperties =
      'http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties';
  static const String extendedProperties =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties';
  static const String customProperties =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/custom-properties';
  static const String styles =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles';
  static const String fontTable =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable';
  static const String numbering =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering';
  static const String settings =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings';
  static const String image =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image';
  static const String hyperlink =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink';
  static const String oleObject =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/oleObject';
  static const String package =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/package';
  static const String sharedStrings =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings';
  static const String worksheet =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet';
  static const String theme =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme';
  static const String slide =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide';
  static const String slideLayout =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout';
  static const String slideMaster =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster';
  static const String chart =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart';
  static const String comments =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments';
  static const String commentsExtended =
      'http://schemas.microsoft.com/office/2011/relationships/commentsExtended';
  static const String presProps =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/presProps';
  static const String viewProps =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/viewProps';
  static const String tableStyles =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/tableStyles';
  static const String notesSlide =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide';
  static const String notesMaster =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesMaster';
  static const String header =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/header';
  static const String footer =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer';
  static const String drawing =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing';
}
