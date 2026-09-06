import 'package:flutter/painting.dart';
import 'package:quds_office_engine/quds_office_engine.dart';

/// Rebuilds a logical string for Flutter/HarfBuzz painting.
///
/// The layout engine stores glyphs in visual order and may remap Arabic
/// letters to presentation forms. [TextPainter] must receive the original
/// logical letters plus the run's bidi direction, or the line is drawn
/// reversed and unjoined.
abstract final class PaintRunText {
  static const List<String> fontFallbacks = <String>[
    'Noto Naskh Arabic',
    'Noto Sans Arabic',
    'Tajawal',
    'DejaVu Sans',
    'Segoe UI',
    'Tahoma',
    'Arial',
  ];

  static const List<String> latinFallbacks = <String>[
    'Calibri',
    'Carlito',
    'Liberation Serif',
    'Times New Roman',
    'Noto Serif',
    'DejaVu Serif',
    'Georgia',
    'serif',
  ];

  static String familyFor({
    required String text,
    String? runFamily,
    String? themeFamily,
  }) {
    return OfficeTypeface.paintFamily(
      text: text,
      runFamily: runFamily,
      themeFamily: themeFamily,
    );
  }

  static List<String> fallbacksFor(String text, {String? runFamily}) {
    final List<String> base = looksRtl(text) ? fontFallbacks : latinFallbacks;
    if (runFamily == null || runFamily.isEmpty) {
      return base;
    }
    return <String>[
      runFamily,
      ...base.where((String family) => family != runFamily),
    ];
  }

  static bool isRtlLevel(int level) => level.isOdd;

  static bool looksRtl(String text) => OfficeTypeface.isRtlText(text);

  static TextDirection directionFor({
    required int bidiLevel,
    String text = '',
  }) {
    if (isRtlLevel(bidiLevel) || looksRtl(text)) {
      return TextDirection.rtl;
    }
    return TextDirection.ltr;
  }

  static String logicalSlice(String paragraph, Iterable<int> logicalIndices) {
    if (paragraph.isEmpty) {
      return '';
    }
    var start = paragraph.length;
    var end = 0;
    for (final int i in logicalIndices) {
      if (i < 0 || i >= paragraph.length) {
        continue;
      }
      if (i < start) {
        start = i;
      }
      var e = i + 1;
      final int cu = paragraph.codeUnitAt(i);
      if (cu >= 0xD800 && cu <= 0xDBFF && i + 1 < paragraph.length) {
        e = i + 2;
      }
      while (e < paragraph.length && _isMark(paragraph.codeUnitAt(e))) {
        e++;
      }
      if (e > end) {
        end = e;
      }
    }
    if (start >= end) {
      return '';
    }
    return paragraph.substring(start, end);
  }

  static bool samePaintRun(LaidOutGlyph a, LaidOutGlyph b) {
    return a.color == b.color &&
        a.fontSize == b.fontSize &&
        a.bold == b.bold &&
        a.italic == b.italic &&
        a.underline == b.underline &&
        a.highlight == b.highlight &&
        a.fontFamily == b.fontFamily &&
        a.vertAlign == b.vertAlign &&
        a.commentIds.join(',') == b.commentIds.join(',') &&
        a.glyph.level.isOdd == b.glyph.level.isOdd;
  }

  /// Measures each paint run and places it after the previous one.
  ///
  /// Glyph X is always the left of the run plus a share of [TextPainter.width].
  /// Using caret offsets inside the painter put later runs on top of earlier
  /// ones (styled words and mixed LTR/RTL).
  static void fitLine(
    LaidOutLine line,
    String paragraph, {
    String? themeFamily,
  }) {
    if (line.glyphs.isEmpty) {
      return;
    }
    final double origin = line.x;
    final double previousWidth = line.width;
    var x = line.x;
    var start = 0;
    while (start < line.glyphs.length) {
      final LaidOutGlyph first = line.glyphs[start];
      var end = start + 1;
      while (end < line.glyphs.length &&
          samePaintRun(first, line.glyphs[end])) {
        end++;
      }
      final List<LaidOutGlyph> run = line.glyphs.sublist(start, end);
      final String text = runText(paragraph, run);
      if (text.isEmpty) {
        for (final LaidOutGlyph glyph in run) {
          glyph.x = x;
          x += glyph.advance;
        }
        start = end;
        continue;
      }
      final TextPainter painter = painterFor(
        text: text,
        first: first,
        themeFamily: themeFamily,
      )..layout();
      _placeRun(run, painter.width, x);
      x += painter.width;
      start = end;
    }
    line.width = (x - line.x).clamp(0, double.infinity);
    _realignAfterFit(line, origin, previousWidth);
  }

  static void _realignAfterFit(
    LaidOutLine line,
    double origin,
    double previousWidth,
  ) {
    final double dx = switch (line.justification) {
      WmlJustification.right =>
        (origin + previousWidth) - (line.x + line.width),
      WmlJustification.center => (previousWidth - line.width) / 2,
      WmlJustification.left ||
      WmlJustification.justify ||
      WmlJustification.distributed => 0,
    };
    if (dx == 0) {
      return;
    }
    line.x += dx;
    for (final LaidOutGlyph glyph in line.glyphs) {
      glyph.x += dx;
    }
  }

  static TextPainter painterFor({
    required String text,
    required LaidOutGlyph first,
    String? themeFamily,
    Color? color,
    TextDecoration? decoration,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: first.fontSize,
          fontFamily: familyFor(
            text: text,
            runFamily: first.fontFamily,
            themeFamily: themeFamily,
          ),
          fontFamilyFallback: fallbacksFor(text, runFamily: first.fontFamily),
          fontWeight: first.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: first.italic ? FontStyle.italic : FontStyle.normal,
          color: color,
          decoration: decoration,
          height: 1.0,
        ),
      ),
      textDirection: directionFor(bidiLevel: first.glyph.level, text: text),
      maxLines: 1,
    );
  }

  static String runText(String paragraph, List<LaidOutGlyph> run) {
    if (paragraph.isEmpty || run.isEmpty) {
      return '';
    }
    final List<int> indices = <int>[
      for (final LaidOutGlyph glyph in run)
        if (glyph.glyph.logicalIndex >= 0 &&
            glyph.glyph.logicalIndex < paragraph.length)
          glyph.glyph.logicalIndex,
    ]..sort();
    if (indices.isEmpty) {
      return '';
    }
    var start = indices.first;
    var end = indices.last + 1;
    if (end < paragraph.length && _isMark(paragraph.codeUnitAt(end))) {
      while (end < paragraph.length && _isMark(paragraph.codeUnitAt(end))) {
        end++;
      }
    }
    if (end - start <= indices.length + 8) {
      return paragraph.substring(start, end.clamp(0, paragraph.length));
    }
    final StringBuffer buffer = StringBuffer();
    var last = -1;
    for (final int i in indices) {
      if (i == last) {
        continue;
      }
      buffer.writeCharCode(paragraph.codeUnitAt(i));
      last = i;
    }
    return buffer.toString();
  }

  static void _placeRun(List<LaidOutGlyph> run, double width, double originX) {
    var weight = 0.0;
    for (final LaidOutGlyph glyph in run) {
      weight += glyph.glyph.advance;
    }
    if (weight <= 0) {
      weight = run.length.toDouble();
    }
    var x = originX;
    for (int i = 0; i < run.length; i++) {
      final LaidOutGlyph glyph = run[i];
      final double share = i == run.length - 1
          ? originX + width - x
          : width * (glyph.glyph.advance / weight);
      glyph.x = x;
      glyph.advance = share.clamp(0.4, width);
      x += glyph.advance;
    }
  }

  static TextPainter plain({
    required String text,
    required double fontSize,
    required Color color,
    String? themeFamily,
    int maxLines = 1,
    TextAlign? align,
    bool? rtl,
  }) {
    final bool useRtl = rtl ?? looksRtl(text);
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.0,
          fontFamily: familyFor(text: text, themeFamily: themeFamily),
          fontFamilyFallback: fallbacksFor(text),
          color: color,
        ),
      ),
      textDirection: useRtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: align ?? (useRtl ? TextAlign.right : TextAlign.left),
      maxLines: maxLines,
    );
  }

  static int hitIndex(TextPainter painter, Offset local, int textLength) {
    if (textLength <= 0) {
      return 0;
    }
    return painter.getPositionForOffset(local).offset.clamp(0, textLength);
  }

  static double caretDx(TextPainter painter, int index) {
    return painter
        .getOffsetForCaret(TextPosition(offset: index), Rect.zero)
        .dx;
  }

  static bool _isMark(int cu) {
    return (cu >= 0x064B && cu <= 0x065F) ||
        cu == 0x0670 ||
        (cu >= 0x06D6 && cu <= 0x06ED) ||
        (cu >= 0x08D3 && cu <= 0x08FF);
  }
}
