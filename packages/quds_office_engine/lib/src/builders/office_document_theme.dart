/// Document-level colors, type, and page size shared by Word, PPTX, XLSX, and PDF.
///
/// This is a pure-Dart brand token set. It is intentionally separate from the
/// Flutter editor chrome theme (`OfficeTheme` in `quds_office_editor`).
class OfficePalette {
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

  final String primary;
  final String primaryLight;
  final String accent;
  final String muted;
  final String highlight;
  final String surface;
  final String onPrimary;
  final String tableHeader;
  final String tableBand;
  final String rule;

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
  const OfficePageSize({
    required this.widthEmu,
    required this.heightEmu,
  });

  /// A4 portrait: 11906 × 16838 twips → EMU (twip × 635).
  static const OfficePageSize a4Portrait = OfficePageSize(
    widthEmu: 7560310,
    heightEmu: 10692130,
  );

  static const OfficePageSize a4Landscape = OfficePageSize(
    widthEmu: 10692130,
    heightEmu: 7560310,
  );

  /// Widescreen 16:9 slide (13.333" × 7.5").
  static const OfficePageSize widescreen = OfficePageSize(
    widthEmu: 12192000,
    heightEmu: 6858000,
  );

  final int widthEmu;
  final int heightEmu;

  /// PDF / typographic points (1 pt = 12 700 EMU).
  double get widthPoints => widthEmu / 12700;

  double get heightPoints => heightEmu / 12700;

  /// Word `w:pgSz` twips (1 twip = 635 EMU).
  int get widthTwips => widthEmu ~/ 635;

  int get heightTwips => heightEmu ~/ 635;
}

/// Word `w:pgMar` in twips. Defaults match a typical 0.79" office margin.
class OfficePageMargins {
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

  final int topTwips;
  final int rightTwips;
  final int bottomTwips;
  final int leftTwips;
  final int headerTwips;
  final int footerTwips;

  int get horizontalTwips => leftTwips + rightTwips;
  int get verticalTwips => topTwips + bottomTwips;
}

/// Product-agnostic document theme injected into fluent builders.
class OfficeDocumentTheme {
  const OfficeDocumentTheme({
    this.palette = const OfficePalette(),
    this.fontFamily = 'Arial',
    this.rtl = false,
    this.page = OfficePageSize.a4Portrait,
    this.margins = const OfficePageMargins(),
  });

  final OfficePalette palette;
  final String fontFamily;
  final bool rtl;
  final OfficePageSize page;
  final OfficePageMargins margins;

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

  String colorAt(int index) {
    final List<String> cycle = palette.chartCycle;
    if (cycle.isEmpty) {
      return palette.primary;
    }
    final int i = index % cycle.length;
    return cycle[i < 0 ? i + cycle.length : i];
  }
}
