/// Document-level colors, type, and page size shared by Word, PPTX, XLSX, and PDF.
///
/// This is a pure-Dart brand token set. It is intentionally separate from the
/// Flutter editor chrome theme (`OfficeTheme` in `quds_office_editor`).
class OfficePalette {
  /// OfficePalette API.
  const OfficePalette({
    this.primary = '2E75B6',
    this.primaryLight = 'D6E3F0',
    this.accent = '548235',
    this.muted = '666666',
    this.highlight = 'C9A227',
    this.surface = 'FFFFFF',
    this.onPrimary = 'FFFFFF',
    this.tableHeader = '1F4E79',
    this.tableBand = 'F2F2F2',
    this.rule = '808080',
  });

  /// primary API.
  final String primary;

  /// primaryLight API.
  final String primaryLight;

  /// accent API.
  final String accent;

  /// muted API.
  final String muted;

  /// highlight API.
  final String highlight;

  /// surface API.
  final String surface;

  /// onPrimary API.
  final String onPrimary;

  /// tableHeader API.
  final String tableHeader;

  /// tableBand API.
  final String tableBand;

  /// rule API.
  final String rule;

  /// chartCycle API.
  List<String> get chartCycle => <String>[
    primary,
    accent,
    highlight,
    'C45C12',
    '5B2C6F',
    tableHeader,
  ];
}

/// Page extents used by document builders (EMU) and PDF (points).
class OfficePageSize {
  /// OfficePageSize API.
  const OfficePageSize({required this.widthEmu, required this.heightEmu});

  /// A4 portrait: 11906 × 16838 twips → EMU (twip × 635).
  static const OfficePageSize a4Portrait = OfficePageSize(
    widthEmu: 7560310,
    heightEmu: 10692130,
  );

  /// a4Landscape API.
  static const OfficePageSize a4Landscape = OfficePageSize(
    widthEmu: 10692130,
    heightEmu: 7560310,
  );

  /// Widescreen 16:9 slide (13.333" × 7.5").
  static const OfficePageSize widescreen = OfficePageSize(
    widthEmu: 12192000,
    heightEmu: 6858000,
  );

  /// widthEmu API.
  final int widthEmu;

  /// heightEmu API.
  final int heightEmu;

  /// PDF / typographic points (1 pt = 12 700 EMU).
  double get widthPoints => widthEmu / 12700;

  /// heightPoints API.
  double get heightPoints => heightEmu / 12700;

  /// Word `w:pgSz` twips (1 twip = 635 EMU).
  int get widthTwips => widthEmu ~/ 635;

  /// heightTwips API.
  int get heightTwips => heightEmu ~/ 635;
}

/// Word `w:pgMar` in twips. Defaults match a typical 0.79" office margin.
class OfficePageMargins {
  /// OfficePageMargins API.
  const OfficePageMargins({
    this.topTwips = 1134,
    this.rightTwips = 1134,
    this.bottomTwips = 1134,
    this.leftTwips = 1134,
    this.headerTwips = 708,
    this.footerTwips = 708,
  });

  /// Near-bleed margins so a full-page figure fills the A4 sheet.
  static const bleed = OfficePageMargins(
    topTwips: 72,
    rightTwips: 72,
    bottomTwips: 72,
    leftTwips: 72,
    headerTwips: 0,
    footerTwips: 0,
  );

  /// topTwips API.
  final int topTwips;

  /// rightTwips API.
  final int rightTwips;

  /// bottomTwips API.
  final int bottomTwips;

  /// leftTwips API.
  final int leftTwips;

  /// headerTwips API.
  final int headerTwips;

  /// footerTwips API.
  final int footerTwips;

  /// horizontalTwips API.
  int get horizontalTwips => leftTwips + rightTwips;

  /// verticalTwips API.
  int get verticalTwips => topTwips + bottomTwips;
}

/// Product-agnostic document theme injected into fluent builders.
class OfficeDocumentTheme {
  /// OfficeDocumentTheme API.
  const OfficeDocumentTheme({
    this.palette = const OfficePalette(),
    this.fontFamily = 'Arial',
    this.rtl = false,
    this.page = OfficePageSize.a4Portrait,
    this.margins = const OfficePageMargins(),
  });

  /// palette API.
  final OfficePalette palette;

  /// fontFamily API.
  final String fontFamily;

  /// rtl API.
  final bool rtl;

  /// page API.
  final OfficePageSize page;

  /// margins API.
  final OfficePageMargins margins;

  /// light API.
  factory OfficeDocumentTheme.light({
    bool rtl = false,
    OfficePageSize page = OfficePageSize.a4Portrait,
    String fontFamily = 'Arial',
    OfficePageMargins margins = const OfficePageMargins(),
  }) {
    return OfficeDocumentTheme(
      rtl: rtl,
      page: page,
      fontFamily: fontFamily,
      margins: margins,
    );
  }

  /// dark API.
  factory OfficeDocumentTheme.dark({
    bool rtl = false,
    OfficePageSize page = OfficePageSize.a4Portrait,
    String fontFamily = 'Arial',
    OfficePageMargins margins = const OfficePageMargins(),
  }) {
    return OfficeDocumentTheme(
      palette: const OfficePalette(
        primary: '5B9BD5',
        primaryLight: '1F4E79',
        accent: '70AD47',
        muted: 'BBBBBB',
        highlight: 'E2C044',
        surface: '2B2B2B',
        onPrimary: '1A1A1A',
        tableHeader: '4472C4',
        tableBand: '3A3A3A',
        rule: '888888',
      ),
      rtl: rtl,
      page: page,
      fontFamily: fontFamily,
      margins: margins,
    );
  }

  /// custom API.
  factory OfficeDocumentTheme.custom({
    OfficePalette palette = const OfficePalette(),
    bool rtl = false,
    OfficePageSize page = OfficePageSize.a4Portrait,
    String fontFamily = 'Arial',
    OfficePageMargins margins = const OfficePageMargins(),
  }) {
    return OfficeDocumentTheme(
      palette: palette,
      rtl: rtl,
      page: page,
      fontFamily: fontFamily,
      margins: margins,
    );
  }

  /// colorAt API.
  String colorAt(int index) {
    final List<String> cycle = palette.chartCycle;
    if (cycle.isEmpty) {
      return palette.primary;
    }
    final int i = index % cycle.length;
    return cycle[i < 0 ? i + cycle.length : i];
  }
}
