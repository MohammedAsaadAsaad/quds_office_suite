/// Measure, wrap, and paint helpers for PDF widgets.
library;

import '../../bidi/line_breaker.dart';
import '../../fonts/font_metrics.dart';
import '../../fonts/font_subsetter.dart';
import '../../pdf/file/text/pdf_std14.dart';
import '../../pdf/pdf_canvas.dart';
import 'pw_core.dart';
import 'pw_style.dart';
import 'pw_types.dart';

/// Resolved size / color / weight for a run.
class PwResolvedStyle {
  /// PwResolvedStyle API.
  PwResolvedStyle(Context context, TextStyle? style)
    : merged = context.theme.defaultTextStyle.merge(style);

  /// merged API.
  final TextStyle merged;

  /// fontSize API.
  double get fontSize => merged.fontSize ?? 11;

  /// color API.
  String get color => merged.color ?? '212121';

  /// bold API.
  bool get bold => merged.fontWeight == FontWeight.bold;

  /// italic API.
  bool get italic => merged.fontStyle == FontStyle.italic;

  /// lineHeight API.
  double lineHeight(Context context) {
    final double factor = merged.lineHeightFactor;
    final face = context.faceFor(bold: bold);
    if (face != null) {
      return FontMetrics(
            font: face,
            fontSizePoints: fontSize,
          ).lineHeight *
          factor;
    }
    return fontSize * factor;
  }

  /// baseline API.
  double baseline(Context context) {
    final face = context.faceFor(bold: bold);
    if (face != null) {
      return FontMetrics(
        font: face,
        fontSizePoints: fontSize,
      ).ascender;
    }
    return fontSize * 0.8;
  }
}

/// Width of [text] in points.
double pwMeasureText(Context context, String text, TextStyle? style) {
  final PwResolvedStyle resolved = PwResolvedStyle(context, style);
  context.useText(text);
  if (context.faceFor(bold: resolved.bold) != null) {
    final face = context.faceFor(bold: resolved.bold)!;
    double width = FontMetrics(
      font: face,
      fontSizePoints: resolved.fontSize,
    ).measureText(text);
    final double tracking = resolved.merged.letterSpacing ?? 0;
    if (tracking != 0 && text.isNotEmpty) {
      width += tracking * (text.runes.length - 1);
    }
    return width;
  }
  double width = 0;
  var i = 0;
  for (final int cp in text.runes) {
    if (i > 0) {
      width += resolved.merged.letterSpacing ?? 0;
    }
    width += _stdAdvance(cp, resolved.fontSize);
    i++;
  }
  return width;
}

/// UAX wrap of [text] to [maxWidth].
List<BrokenLine> pwWrapText(
  Context context,
  String text,
  double maxWidth,
  TextStyle? style, {
  TextAlign align = TextAlign.start,
}) {
  final PwResolvedStyle resolved = PwResolvedStyle(context, style);
  context.useText(text);
  final double tracking = resolved.merged.letterSpacing ?? 0;
  final face = context.faceFor(bold: resolved.bold);
  final int units = text.runes.length;
  final double perGlyphTrack =
      units > 1 ? tracking * (units - 1) / units : 0;
  return LineBreaker.breakLines(
    text: text,
    maxWidth: maxWidth < 1 ? 1 : maxWidth,
    widthOf: (int cp) {
      if (face != null) {
        return FontMetrics(
              font: face,
              fontSizePoints: resolved.fontSize,
            ).characterWidth(cp) +
            perGlyphTrack;
      }
      return _stdAdvance(cp, resolved.fontSize) + perGlyphTrack;
    },
    glyphIdOf: (int cp) => face?.glyphIdFor(cp) ?? cp,
    baseLevel: context.textDirection == TextDirection.rtl ? 1 : 0,
    justify: align == TextAlign.justify,
  );
}

/// Paints one wrapped line. [origin] is the top-left of the line box.
void pwPaintLine(
  Context context,
  BrokenLine line,
  PwOffset origin,
  double maxWidth,
  TextStyle? style,
  TextAlign align,
) {
  final PdfCanvas? canvas = context.canvas;
  if (canvas == null) {
    return;
  }
  final PwResolvedStyle resolved = PwResolvedStyle(context, style);
  final double boxTop = origin.dy;
  final double baseline = boxTop + resolved.baseline(context);
  var startX = origin.dx;
  final double slack = (maxWidth - line.width).clamp(0, double.infinity);
  final bool rtl = context.textDirection == TextDirection.rtl;
  switch (_resolvedAlign(align, rtl)) {
    case TextAlign.right:
      startX += slack;
    case TextAlign.center:
      startX += slack / 2;
    default:
      break;
  }
  var x = startX;
  for (final ShapedGlyph glyph in line.glyphs) {
    final double extra = glyph.isSpace && line.justificationRatio != 0
        ? line.justificationRatio * 3
        : 0;
    _paintGlyph(context, canvas, glyph.codePoint, x, baseline, resolved);
    x += glyph.advance + extra;
  }
  final TextDecoration? deco = resolved.merged.decoration;
  if (deco != null && deco != TextDecoration.none && line.width > 0) {
    canvas.endText();
    canvas.setStrokeColor(resolved.color);
    canvas.setLineWidth(0.6);
    final double x0 = startX;
    final double x1 = startX + (maxWidth < line.width ? line.width : line.width);
    if (deco.contains(TextDecoration.underline)) {
      canvas.moveTo(x0, baseline + 1.4);
      canvas.lineTo(x1, baseline + 1.4);
      canvas.stroke();
    }
    if (deco.contains(TextDecoration.lineThrough)) {
      canvas.moveTo(x0, boxTop + resolved.lineHeight(context) * 0.55);
      canvas.lineTo(x1, boxTop + resolved.lineHeight(context) * 0.55);
      canvas.stroke();
    }
  }
}

/// Paints wrapped paragraphs; returns the height used.
double pwPaintParagraph(
  Context context,
  String text,
  PwOffset origin,
  double maxWidth,
  TextStyle? style,
  TextAlign align,
) {
  final PwResolvedStyle resolved = PwResolvedStyle(context, style);
  final double lh = resolved.lineHeight(context);
  final List<BrokenLine> lines = pwWrapText(
    context,
    text,
    maxWidth,
    style,
    align: align,
  );
  var y = origin.dy;
  for (final BrokenLine line in lines) {
    pwPaintLine(context, line, PwOffset(origin.dx, y), maxWidth, style, align);
    y += lh;
  }
  return y - origin.dy;
}

void _paintGlyph(
  Context context,
  PdfCanvas canvas,
  int codePoint,
  double x,
  double baseline,
  PwResolvedStyle style,
) {
  final face = context.faceFor(bold: style.bold);
  if (face != null) {
    final ({FontSubset? subset, String fontName}) embed =
        context.embedFor(bold: style.bold);
    final int gid = embed.subset != null
        ? (embed.subset!.unicodeToNewGlyph[codePoint] ?? 0)
        : face.glyphIdFor(codePoint);
    // Real bold face: never fake-stroke. Faux bold only without fontBold.
    final bool fauxBold =
        style.bold && context.document.fontBold == null;
    canvas.showGlyph(
      x: x,
      y: baseline,
      fontSize: style.fontSize,
      glyphId: gid,
      color: style.color,
      italic: style.italic,
      bold: fauxBold,
      fontName: embed.fontName,
    );
    return;
  }
  if (codePoint >= 32 && codePoint <= 126) {
    canvas.showLatin(
      x: x,
      y: baseline,
      fontSize: style.fontSize,
      text: String.fromCharCode(codePoint),
      color: style.color,
    );
  }
}

TextAlign _resolvedAlign(TextAlign align, bool rtl) {
  return switch (align) {
    TextAlign.start => rtl ? TextAlign.right : TextAlign.left,
    TextAlign.end => rtl ? TextAlign.left : TextAlign.right,
    TextAlign.justify => TextAlign.left,
    _ => align,
  };
}

double _stdAdvance(int codePoint, double fontSize) {
  if (codePoint < 32) {
    return 0;
  }
  final int code = codePoint <= 255 ? codePoint : 32;
  return PdfStd14.width('Helvetica', code) / 1000.0 * fontSize;
}

/// Paints a [BoxDecoration] behind a child.
void pwPaintDecoration(
  Context context,
  PwOffset offset,
  PwSize size,
  BoxDecoration decoration,
) {
  final PdfCanvas? canvas = context.canvas;
  if (canvas == null) {
    return;
  }
  canvas.endText();
  if (decoration.shape == BoxShape.circle) {
    if (decoration.color != null) {
      canvas.setFillColor(decoration.color!);
      canvas.ellipse(offset.dx, offset.dy, size.width, size.height);
      canvas.fill();
    }
    final Border? border = decoration.border;
    if (border != null && border.top.width > 0) {
      canvas.setStrokeColor(border.top.color);
      canvas.setLineWidth(border.top.width);
      canvas.ellipse(offset.dx, offset.dy, size.width, size.height);
      canvas.stroke();
    }
    return;
  }
  if (decoration.color != null) {
    canvas.setFillColor(decoration.color!);
    if (decoration.borderRadius > 0.2) {
      canvas.roundedRect(
        offset.dx,
        offset.dy,
        size.width,
        size.height,
        decoration.borderRadius,
      );
      canvas.fill();
    } else {
      canvas.fillRect(
        offset.dx,
        offset.dy,
        size.width,
        size.height,
        decoration.color!,
      );
    }
  }
  final Border? border = decoration.border;
  if (border == null) {
    return;
  }
  void side(BorderSide s, double x1, double y1, double x2, double y2) {
    if (s.width <= 0) {
      return;
    }
    canvas.setStrokeColor(s.color);
    canvas.setLineWidth(s.width);
    canvas.moveTo(x1, y1);
    canvas.lineTo(x2, y2);
    canvas.stroke();
  }

  final double r = offset.dx + size.width;
  final double b = offset.dy + size.height;
  side(border.top, offset.dx, offset.dy, r, offset.dy);
  side(border.right, r, offset.dy, r, b);
  side(border.bottom, offset.dx, b, r, b);
  side(border.left, offset.dx, offset.dy, offset.dx, b);
}
