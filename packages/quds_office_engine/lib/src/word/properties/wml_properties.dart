// WordprocessingML paragraph / run / table properties.
// Measurements are stored in points (1 twip = 1/20 pt, w:sz is half-points).

enum WmlJustification { left, right, center, justify, distributed }

enum WmlUnderline { none, single, double, dotted, wavy }

enum WmlLineSpacingRule { auto, exact, atLeast }

enum WmlVertAlign { baseline, superscript, subscript }

/// Word-like script metrics: about two-thirds size, raised or lowered.
extension WmlVertAlignMetrics on WmlVertAlign {
  double get fontScale => switch (this) {
        WmlVertAlign.baseline => 1,
        WmlVertAlign.superscript || WmlVertAlign.subscript => 0.65,
      };

  double baselineShift(double baseFontSize) => switch (this) {
        WmlVertAlign.superscript => -baseFontSize * 0.35,
        WmlVertAlign.subscript => baseFontSize * 0.14,
        WmlVertAlign.baseline => 0,
      };

  double paintTop({
    required double lineY,
    required double lineHeight,
    required double fontSize,
  }) =>
      switch (this) {
        WmlVertAlign.baseline => lineY,
        WmlVertAlign.superscript => lineY,
        WmlVertAlign.subscript =>
          lineY + (lineHeight - fontSize).clamp(0, lineHeight),
      };
}

enum WmlTabAlignment { left, center, right, decimal }

enum WmlTabLeader { none, dot, hyphen, underscore }

enum WmlVMerge { none, restart, cont }

enum WmlBreakType { page, column, textWrapping }

enum WmlFrameAnchor { page, margin }

enum WmlFrameWrap { none, square }

class WmlPageSize {
  const WmlPageSize({this.width = 595.28, this.height = 841.89});

  factory WmlPageSize.a4() => const WmlPageSize();

  factory WmlPageSize.letter() =>
      const WmlPageSize(width: 612, height: 792);

  factory WmlPageSize.legal() =>
      const WmlPageSize(width: 612, height: 1008);

  factory WmlPageSize.a3() =>
      const WmlPageSize(width: 841.89, height: 1190.55);

  final double width;
  final double height;

  bool get isLandscape => width > height + 0.5;

  WmlPageSize get portrait =>
      isLandscape ? WmlPageSize(width: height, height: width) : this;

  WmlPageSize get landscape =>
      isLandscape ? this : WmlPageSize(width: height, height: width);

  bool matches(WmlPageSize other) =>
      (width - other.width).abs() < 1 && (height - other.height).abs() < 1;

  WmlPageSize copyWith({double? width, double? height}) =>
      WmlPageSize(width: width ?? this.width, height: height ?? this.height);
}

class WmlPageMargins {
  const WmlPageMargins({
    this.top = 72,
    this.bottom = 72,
    this.left = 72,
    this.right = 72,
  });

  /// Word Normal: 1" on every side.
  static const WmlPageMargins normal = WmlPageMargins();

  /// Word Narrow: 0.5" on every side.
  static const WmlPageMargins narrow = WmlPageMargins(
    top: 36,
    bottom: 36,
    left: 36,
    right: 36,
  );

  /// Word Moderate: 1" top/bottom, 0.75" left/right.
  static const WmlPageMargins moderate = WmlPageMargins(
    top: 72,
    bottom: 72,
    left: 54,
    right: 54,
  );

  /// Word Wide: 1" top/bottom, 2" left/right.
  static const WmlPageMargins wide = WmlPageMargins(
    top: 72,
    bottom: 72,
    left: 144,
    right: 144,
  );

  final double top;
  final double bottom;
  final double left;
  final double right;

  bool matches(WmlPageMargins other) =>
      (top - other.top).abs() < 0.5 &&
      (bottom - other.bottom).abs() < 0.5 &&
      (left - other.left).abs() < 0.5 &&
      (right - other.right).abs() < 0.5;

  WmlPageMargins copyWith({
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) =>
      WmlPageMargins(
        top: top ?? this.top,
        bottom: bottom ?? this.bottom,
        left: left ?? this.left,
        right: right ?? this.right,
      );
}

class WmlIndent {
  const WmlIndent({
    this.left = 0,
    this.right = 0,
    this.firstLine = 0,
    this.hanging = 0,
  });

  final double left;
  final double right;
  final double firstLine;
  final double hanging;
}

class WmlTabStop {
  const WmlTabStop({
    required this.position,
    this.alignment = WmlTabAlignment.left,
    this.leader = WmlTabLeader.none,
  });

  final double position;
  final WmlTabAlignment alignment;
  final WmlTabLeader leader;
}

class WmlBorder {
  const WmlBorder({
    this.style = 'single',
    this.sizeEighths = 8,
    this.color = '000000',
  });

  final String style;
  final int sizeEighths;
  final String color;
}

class WmlParagraphProps {
  WmlParagraphProps({
    this.justification = WmlJustification.left,
    this.lineSpacing = 1.15,
    this.lineSpacingRule = WmlLineSpacingRule.auto,
    this.spacingBefore = 0,
    this.spacingAfter = 8,
    this.indent = const WmlIndent(),
    List<WmlTabStop>? tabs,
    this.keepTogether = false,
    this.pageBreakBefore = false,
    this.columnBreakBefore = false,
    this.numId,
    this.ilvl = 0,
    this.listLabel,
    this.pageNumberField = false,
    this.headingLevel,
    this.styleId,
    this.fieldInstruction,
    this.fieldBegin = false,
    this.fieldEnd = false,
    this.bookmarkName,
    this.rightToLeft,
  }) : tabs = tabs ?? <WmlTabStop>[];

  WmlJustification justification;
  double lineSpacing;
  WmlLineSpacingRule lineSpacingRule;
  double spacingBefore;
  double spacingAfter;
  WmlIndent indent;
  List<WmlTabStop> tabs;
  bool keepTogether;
  bool pageBreakBefore;
  bool columnBreakBefore;
  int? numId;
  int ilvl;
  String? listLabel;
  bool pageNumberField;
  /// Word heading 1–9. `null` is body text (Normal).
  int? headingLevel;
  String? styleId;
  String? fieldInstruction;
  bool fieldBegin;
  bool fieldEnd;
  String? bookmarkName;

  /// Word `w:bidi`. `null` lets UAX #9 pick the paragraph level.
  bool? rightToLeft;

  /// Embedding level for [LineBreaker]: 1 RTL, 0 LTR, `null` auto.
  int? get bidiBaseLevel {
    if (rightToLeft == true) {
      return 1;
    }
    if (rightToLeft == false) {
      return 0;
    }
    return justification == WmlJustification.right ? 1 : null;
  }

  WmlParagraphProps copy() => WmlParagraphProps(
        justification: justification,
        lineSpacing: lineSpacing,
        lineSpacingRule: lineSpacingRule,
        spacingBefore: spacingBefore,
        spacingAfter: spacingAfter,
        indent: indent,
        tabs: List<WmlTabStop>.from(tabs),
        keepTogether: keepTogether,
        pageBreakBefore: pageBreakBefore,
        columnBreakBefore: columnBreakBefore,
        numId: numId,
        ilvl: ilvl,
        listLabel: listLabel,
        pageNumberField: pageNumberField,
        headingLevel: headingLevel,
        styleId: styleId,
        fieldInstruction: fieldInstruction,
        fieldBegin: fieldBegin,
        fieldEnd: fieldEnd,
        bookmarkName: bookmarkName,
        rightToLeft: rightToLeft,
      );
}

/// Maps Word `w:highlight` names (and raw hex) to RRGGBB.
abstract final class WmlHighlight {
  static String? toRgb(String? value) {
    if (value == null || value.isEmpty || value == 'none') {
      return null;
    }
    switch (value) {
      case 'yellow':
        return 'FFFF00';
      case 'green':
        return '00FF00';
      case 'cyan':
        return '00FFFF';
      case 'magenta':
        return 'FF00FF';
      case 'blue':
        return '0000FF';
      case 'red':
        return 'FF0000';
      case 'darkBlue':
        return '000080';
      case 'darkCyan':
        return '008080';
      case 'darkGreen':
        return '008000';
      case 'darkMagenta':
        return '800080';
      case 'darkRed':
        return '800000';
      case 'darkYellow':
        return '808000';
      case 'darkGray':
        return '808080';
      case 'lightGray':
        return 'C0C0C0';
      case 'black':
        return '000000';
      case 'white':
        return 'FFFFFF';
      default:
        final String hex = value.replaceFirst('#', '');
        if (hex.length == 6) {
          return hex.toUpperCase();
        }
        return null;
    }
  }
}

class WmlRunProps {
  WmlRunProps({
    this.bold = false,
    this.italic = false,
    this.underline = WmlUnderline.none,
    this.strike = false,
    this.color = '000000',
    this.highlight,
    this.fontSizeHalfPoints = 22,
    this.asciiFont = 'Calibri',
    this.csFont = 'Arial',
    this.vertAlign = WmlVertAlign.baseline,
  });

  bool bold;
  bool italic;
  WmlUnderline underline;
  bool strike;
  String color;
  String? highlight;
  int fontSizeHalfPoints;
  String asciiFont;
  String csFont;
  WmlVertAlign vertAlign;

  double get fontSizePoints => fontSizeHalfPoints / 2.0;

  WmlRunProps copy() => WmlRunProps(
        bold: bold,
        italic: italic,
        underline: underline,
        strike: strike,
        color: color,
        highlight: highlight,
        fontSizeHalfPoints: fontSizeHalfPoints,
        asciiFont: asciiFont,
        csFont: csFont,
        vertAlign: vertAlign,
      );
}

class WmlTableProps {
  WmlTableProps({
    this.alignment = WmlJustification.left,
    this.floating = false,
    this.cellMargin = 4,
    this.rightToLeft = false,
  });

  WmlJustification alignment;
  bool floating;
  double cellMargin;

  /// Word `w:bidiVisual` — first column is drawn on the right.
  bool rightToLeft;

  WmlTableProps copy() => WmlTableProps(
        alignment: alignment,
        floating: floating,
        cellMargin: cellMargin,
        rightToLeft: rightToLeft,
      );
}

int pointsToTwips(double points) => (points * 20).round();

double twipsToPoints(int twips) => twips / 20.0;

int? parseHexInt(String? raw) {
  if (raw == null || raw.isEmpty || raw == 'auto') {
    return null;
  }
  return int.tryParse(raw.replaceFirst('#', ''), radix: 16);
}
