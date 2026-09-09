part of 'widgets.dart';

/// Page-level tokens. Same role as `pw.PageTheme`.
class PageTheme {
  /// PageTheme API.
  const PageTheme({
    PdfPageFormat? pageFormat,
    this.theme,
    this.orientation = PageOrientation.natural,
    this.margin,
    this.textDirection,
  }) : pageFormat = pageFormat ?? PdfPageFormat.standard;

  /// pageFormat API.
  final PdfPageFormat pageFormat;

  /// theme API.
  final ThemeData? theme;

  /// orientation API.
  final PageOrientation orientation;

  /// margin API.
  final EdgeInsets? margin;

  /// textDirection API.
  final TextDirection? textDirection;

  /// resolvedFormat API.
  PdfPageFormat get resolvedFormat {
    if (orientation == PageOrientation.landscape &&
        pageFormat.height > pageFormat.width) {
      return pageFormat.landscape;
    }
    return pageFormat;
  }
}

/// Single-child page. Same constructor as `pw.Page`.
class Page {
  /// Page API.
  Page({
    PageTheme? pageTheme,
    PdfPageFormat? pageFormat,
    required BuildCallback build,
    ThemeData? theme,
    PageOrientation? orientation,
    EdgeInsets? margin,
    TextDirection? textDirection,
  }) : pageTheme =
           pageTheme ??
           PageTheme(
             pageFormat: pageFormat,
             theme: theme,
             orientation: orientation ?? PageOrientation.natural,
             margin: margin,
             textDirection: textDirection,
           ),
       _build = build,
       _buildList = null,
       header = null,
       footer = null;

  Page._multi({
    required this.pageTheme,
    required BuildListCallback build,
    this.header,
    this.footer,
  }) : _build = null,
       _buildList = build;

  /// pageTheme API.
  final PageTheme pageTheme;

  /// header API.
  final BuildCallback? header;

  /// footer API.
  final BuildCallback? footer;

  final BuildCallback? _build;
  final BuildListCallback? _buildList;

  /// childrenOf API.
  List<Widget> childrenOf(Context context) {
    if (_buildList != null) {
      return _buildList(context);
    }
    return <Widget>[_build!(context)];
  }
}

/// Flowing Word section. Same constructor as `pw.MultiPage`.
class MultiPage extends Page {
  /// MultiPage API.
  MultiPage({
    PageTheme? pageTheme,
    PdfPageFormat? pageFormat,
    required BuildListCallback build,
    BuildCallback? header,
    BuildCallback? footer,
    ThemeData? theme,
    PageOrientation? orientation,
    EdgeInsets? margin,
    TextDirection? textDirection,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  }) : super._multi(
         pageTheme:
             pageTheme ??
             PageTheme(
               pageFormat: pageFormat,
               theme: theme,
               orientation: orientation ?? PageOrientation.natural,
               margin: margin,
               textDirection: textDirection,
             ),
         build: build,
         header: header,
         footer: footer,
       );

  /// mainAxisAlignment API.
  final MainAxisAlignment mainAxisAlignment;

  /// crossAxisAlignment API.
  final CrossAxisAlignment crossAxisAlignment;
}

/// Immutable after [addPage], like `pw.Document`.
class Document {
  /// Document API.
  Document({
    this.theme,
    this.title = '',
    this.author = '',
    this.creator = '',
    this.subject = '',
    this.keywords = '',
    this.watermark = '',
  });

  /// theme API.
  final ThemeData? theme;

  /// title API.
  final String title;

  /// author API.
  final String author;

  /// creator API.
  final String creator;

  /// subject API.
  final String subject;

  /// keywords API.
  final String keywords;

  /// Diagonal stamp written into the first header part.
  final String watermark;

  final List<Page> _pages = <Page>[];

  /// pages API.
  List<Page> get pages => List<Page>.unmodifiable(_pages);

  /// addPage API.
  void addPage(Page page) {
    _pages.add(page);
  }

  /// Compiles the widget tree to the live Word model.
  WmlDocument toModel() => WordTranslator.toDocument(this);

  /// Writes a `.docx` package. Same return as `pw.Document.save`.
  Future<Uint8List> save() async {
    return WordSerializer().writeBytes(toModel());
  }

  /// Archives the compiled model as PDF 1.7.
  ///
  /// Pass [font] so Arabic and other non-WinAnsi text is laid out and
  /// embedded. Without a font, only ASCII Latin is painted.
  Future<Uint8List> toPdf({String? title, SfntFont? font}) async {
    return OfficePdfExport.word(
      toModel(),
      font: font,
      title: title ?? (this.title.isEmpty ? 'Document' : this.title),
    );
  }
}
