import 'sfnt_parser.dart';

/// Horizontal metrics resolved in typographic points (1 pt = 1/72 inch).
class FontMetrics {
  FontMetrics({
    required this.font,
    required this.fontSizePoints,
  });

  final SfntFont font;
  final double fontSizePoints;

  double get emSquare => fontSizePoints;

  double get ascender => font.unitsToPoints(font.ascender, fontSizePoints);

  double get descender => font.unitsToPoints(font.descender, fontSizePoints);

  double get lineGap => font.unitsToPoints(font.lineGap, fontSizePoints);

  double get capHeight => font.unitsToPoints(font.capHeight, fontSizePoints);

  /// Recommended default line height including gap.
  double get lineHeight => ascender - descender + lineGap;

  double advanceWidth(int glyphId) =>
      font.unitsToPoints(font.advanceWidth(glyphId), fontSizePoints);

  double leftSideBearing(int glyphId) {
    if (glyphId < 0 || glyphId >= font.leftSideBearings.length) {
      return 0;
    }
    return font.unitsToPoints(font.leftSideBearings[glyphId], fontSizePoints);
  }

  /// Width of [codePoint] after cmap lookup, in points.
  double characterWidth(int codePoint) =>
      advanceWidth(font.glyphIdFor(codePoint));

  /// Sum of glyph advances for [text], ignoring kerning.
  double measureText(String text) {
    double width = 0;
    for (final int unit in text.runes) {
      width += characterWidth(unit);
    }
    return width;
  }
}
