import 'arabic_shaping.dart';
import 'grapheme_clusters.dart';
import 'uax9_bidi.dart';

/// A laid-out line of shaped visual glyphs.
class BrokenLine {
  BrokenLine({
    required this.glyphs,
    required this.width,
    required this.logicalStart,
    required this.logicalEnd,
    required this.justificationRatio,
  });

  final List<ShapedGlyph> glyphs;
  final double width;
  final int logicalStart;
  final int logicalEnd;
  final double justificationRatio;
}

/// Shaped visual glyph with document metrics in points.
class ShapedGlyph {
  const ShapedGlyph({
    required this.codePoint,
    required this.glyphId,
    required this.advance,
    required this.logicalIndex,
    required this.level,
    this.isSpace = false,
  });

  final int codePoint;
  final int glyphId;
  final double advance;
  final int logicalIndex;
  final int level;
  final bool isSpace;
}

/// Width provider used by the breaker (typically [FontMetrics.characterWidth]).
typedef GlyphWidthFn = double Function(int codePoint);

typedef GlyphIdFn = int Function(int codePoint);

/// UAX #14 opportunities + Knuth–Plass least-demerits wrapping.
abstract final class LineBreaker {
  static List<BrokenLine> breakLines({
    required String text,
    required double maxWidth,
    required GlyphWidthFn widthOf,
    GlyphIdFn glyphIdOf = _identityGlyph,
    int? baseLevel,
    double spaceStretch = 3,
    double spaceShrink = 1,
  }) {
    if (text.isEmpty) {
      return <BrokenLine>[
        BrokenLine(
          glyphs: const <ShapedGlyph>[],
          width: 0,
          logicalStart: 0,
          logicalEnd: 0,
          justificationRatio: 0,
        ),
      ];
    }
    final BidiParagraph bidi = Uax9Bidi.reorder(text, baseLevel: baseLevel);
    // Wrap in logical order, then apply UAX #9 L2 per line. Reordering the
    // whole paragraph first inverts RTL wraps (logical start on a later line).
    final List<ShapedGlyph> logical = _logicalGlyphs(
      text,
      bidi,
      widthOf,
      glyphIdOf,
    );
    if (logical.isEmpty) {
      return <BrokenLine>[];
    }

    final List<int> breaks = _knuthPlass(
      logical,
      maxWidth,
      spaceStretch,
      spaceShrink,
    );
    final List<BrokenLine> lines = <BrokenLine>[];
    for (int i = 0; i < breaks.length - 1; i++) {
      final int from = breaks[i];
      var to = breaks[i + 1];
      while (to > from && logical[to - 1].isSpace) {
        to--;
      }
      final List<ShapedGlyph> slice = _reorderLine(logical.sublist(from, to));
      double width = 0;
      var spaces = 0;
      for (final ShapedGlyph g in slice) {
        width += g.advance;
        if (g.isSpace) {
          spaces++;
        }
      }
      var ratio = 0.0;
      if (spaces > 0 && width < maxWidth && i != breaks.length - 2) {
        ratio = (maxWidth - width) / (spaces * spaceStretch);
        width = maxWidth;
      }
      int logStart = text.length;
      int logEnd = 0;
      for (final ShapedGlyph g in slice) {
        if (g.logicalIndex < logStart) {
          logStart = g.logicalIndex;
        }
        if (g.logicalIndex + 1 > logEnd) {
          logEnd = g.logicalIndex + 1;
        }
      }
      if (slice.isEmpty) {
        logStart = 0;
        logEnd = 0;
      }
      lines.add(
        BrokenLine(
          glyphs: slice,
          width: width,
          logicalStart: logStart,
          logicalEnd: logEnd,
          justificationRatio: ratio,
        ),
      );
    }
    return lines;
  }

  static List<ShapedGlyph> _reorderLine(List<ShapedGlyph> logicalSlice) {
    if (logicalSlice.length < 2) {
      return logicalSlice;
    }
    final List<int> levels = <int>[
      for (final ShapedGlyph g in logicalSlice) g.level,
    ];
    final List<int> order = Uax9Bidi.visualOrder(levels);
    return <ShapedGlyph>[for (final int i in order) logicalSlice[i]];
  }

  static List<ShapedGlyph> _logicalGlyphs(
    String text,
    BidiParagraph bidi,
    GlyphWidthFn widthOf,
    GlyphIdFn glyphIdOf,
  ) {
    final List<int> cps = text.runes.toList();
    final List<int> offsets = <int>[0];
    var utf16 = 0;
    for (final int cp in cps) {
      utf16 += cp > 0xFFFF ? 2 : 1;
      offsets.add(utf16);
    }
    final List<ShapedGlyph> logical = <ShapedGlyph>[];
    for (int logicalCpIndex = 0; logicalCpIndex < cps.length; logicalCpIndex++) {
      final int cp = cps[logicalCpIndex];
      final int logicalIndex = offsets[logicalCpIndex];
      if (_isTashkeel(cp)) {
        logical.add(
          ShapedGlyph(
            codePoint: cp,
            glyphId: glyphIdOf(cp),
            advance: 0,
            logicalIndex: logicalIndex,
            level: bidi.levels[logicalCpIndex],
          ),
        );
        continue;
      }
      logical.add(
        ShapedGlyph(
          codePoint: cp,
          glyphId: glyphIdOf(cp),
          advance: widthOf(cp),
          logicalIndex: logicalIndex,
          level: bidi.levels[logicalCpIndex],
          isSpace: _isBreakSpace(cp),
        ),
      );
    }
    // Presentation forms use logical-neighbour joining on the original string.
    final List<ShapedChar> shaped = ArabicShaper.shape(text);
    final Map<int, ShapedChar> byLogical = <int, ShapedChar>{
      for (final ShapedChar s in shaped) s.logicalIndex: s,
    };
    return logical.map((ShapedGlyph g) {
      final ShapedChar? s = byLogical[g.logicalIndex];
      if (s == null) {
        return g;
      }
      return ShapedGlyph(
        codePoint: s.codePoint,
        glyphId: glyphIdOf(s.codePoint),
        advance: s.advanceFactor == 0 ? 0 : widthOf(s.codePoint),
        logicalIndex: g.logicalIndex,
        level: g.level,
        isSpace: g.isSpace,
      );
    }).toList();
  }

  static List<int> _knuthPlass(
    List<ShapedGlyph> glyphs,
    double maxWidth,
    double stretch,
    double shrink,
  ) {
    final int n = glyphs.length;
    final List<double> widths = List<double>.filled(n + 1, 0);
    for (int i = 0; i < n; i++) {
      widths[i + 1] = widths[i] + glyphs[i].advance;
    }
    final List<int> legal = <int>[0];
    for (int i = 0; i < n; i++) {
      if (_canBreakAfter(glyphs, i)) {
        legal.add(i + 1);
      }
    }
    if (legal.last != n) {
      legal.add(n);
    }

    final List<double> demerits = List<double>.filled(legal.length, double.infinity);
    final List<int> pred = List<int>.filled(legal.length, 0);
    demerits[0] = 0;
    for (int j = 1; j < legal.length; j++) {
      for (int i = 0; i < j; i++) {
        final int from = legal[i];
        final int to = legal[j];
        double w = widths[to] - widths[from];
        // trailing spaces do not count
        var t = to - 1;
        while (t >= from && glyphs[t].isSpace) {
          w -= glyphs[t].advance;
          t--;
        }
        if (w > maxWidth + shrink && j != legal.length - 1) {
          continue;
        }
        var badness = 0.0;
        if (w > maxWidth) {
          badness = ((w - maxWidth) / (shrink <= 0 ? 1 : shrink)) * 4 + 20;
        } else if (j != legal.length - 1) {
          final double slack = maxWidth - w;
          badness = slack / (stretch <= 0 ? 1 : stretch);
        }
        final double cost = demerits[i] + badness * badness * 100 + 10;
        if (cost < demerits[j]) {
          demerits[j] = cost;
          pred[j] = i;
        }
      }
      if (demerits[j].isInfinite) {
        // Forced overflow: take the previous legal break.
        demerits[j] = demerits[j - 1] + 10000;
        pred[j] = j - 1;
      }
    }
    final List<int> points = <int>[];
    var k = legal.length - 1;
    while (k > 0) {
      points.add(legal[k]);
      k = pred[k];
    }
    points.add(0);
    return points.reversed.toList();
  }

  static bool _canBreakAfter(List<ShapedGlyph> glyphs, int i) {
    final int cp = glyphs[i].codePoint;
    if (cp == 0x000A || cp == 0x000D) {
      return true;
    }
    if (i == glyphs.length - 1) {
      return true;
    }
    final int next = glyphs[i + 1].codePoint;
    if (_isBreakSpace(cp)) {
      return true;
    }
    // UAX #14: BA, ZW, HY allow break after; GL/WJ forbid.
    if (cp == 0x200B || cp == 0x00AD || cp == 0x2010 || cp == 0x002D) {
      return true;
    }
    if (cp == 0x00A0 || cp == 0x2060 || cp == 0x200D) {
      return false;
    }
    // Do not break inside a grapheme (tashkeel already zero-width).
    if (_isTashkeel(next)) {
      return false;
    }
    return false;
  }

  static bool _isBreakSpace(int cp) =>
      cp == 0x0020 || cp == 0x0009 || cp == 0x2000 || cp == 0x3000;

  static bool _isTashkeel(int cp) =>
      (cp >= 0x064B && cp <= 0x065F) || cp == 0x0670;

  static int _identityGlyph(int cp) => cp;
}

/// Hit-test a visual X offset on [line] and return the logical UTF-16 index.
int visualXToLogical(BrokenLine line, double x) {
  var cursor = 0.0;
  for (final ShapedGlyph g in line.glyphs) {
    final double mid = cursor + g.advance / 2;
    if (x <= mid) {
      return g.logicalIndex;
    }
    cursor += g.advance;
  }
  return line.logicalEnd;
}

/// Maps a logical index to a visual caret X on [line].
double logicalToVisualX(BrokenLine line, int logicalIndex) {
  var cursor = 0.0;
  for (final ShapedGlyph g in line.glyphs) {
    if (g.logicalIndex == logicalIndex) {
      return cursor;
    }
    cursor += g.advance;
  }
  return line.width;
}

/// Expose cluster bounds for caret engines.
List<GraphemeCluster> caretClusters(String text) =>
    GraphemeClusters.segment(text);
