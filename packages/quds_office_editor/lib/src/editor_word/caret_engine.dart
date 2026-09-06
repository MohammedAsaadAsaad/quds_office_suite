import 'dart:ui';

import 'package:quds_office_engine/quds_office_engine.dart';

/// BiDi-aware visual caret plus disjoint selection rectangles.
class CaretEngine {
  /// CaretEngine API.
  CaretEngine();

  /// Index into [WmlDocument.paragraphs].
  int paragraphIndex = 0;

  /// logicalIndex API.
  int logicalIndex = 0;

  /// selectionAnchor API.
  int selectionAnchor = 0;

  /// selectionAnchorParagraph API.
  int selectionAnchorParagraph = 0;

  /// visible API.
  var visible = true;

  /// now API.
  DateTime _lastBlink = DateTime.now();

  /// resetBlink API.
  void resetBlink() {
    visible = true;
    _lastBlink = DateTime.now();
  }

  /// tick API.
  void tick(Duration elapsed) {
    if (DateTime.now().difference(_lastBlink).inMilliseconds >= 500) {
      visible = !visible;
      _lastBlink = DateTime.now();
    }
  }

  /// RegExp API.
  static final RegExp _wordChar = RegExp(r'[\p{L}\p{N}\p{M}]', unicode: true);

  /// isCollapsed API.
  bool get isCollapsed =>
      selectionAnchorParagraph == paragraphIndex &&
      selectionAnchor == logicalIndex;

  /// normalizedRange API.
  ({int startPara, int startIdx, int endPara, int endIdx}) get normalizedRange {
    final bool forward =
        selectionAnchorParagraph < paragraphIndex ||
        (selectionAnchorParagraph == paragraphIndex &&
            selectionAnchor <= logicalIndex);
    if (forward) {
      return (
        startPara: selectionAnchorParagraph,
        startIdx: selectionAnchor,
        endPara: paragraphIndex,
        endIdx: logicalIndex,
      );
    }
    return (
      startPara: paragraphIndex,
      startIdx: logicalIndex,
      endPara: selectionAnchorParagraph,
      endIdx: selectionAnchor,
    );
  }

  /// collapseSelection API.
  void collapseSelection() {
    selectionAnchorParagraph = paragraphIndex;
    selectionAnchor = logicalIndex;
    resetBlink();
  }

  /// moveLogical API.
  void moveLogical(int delta, int max) {
    logicalIndex = (logicalIndex + delta).clamp(0, max);
    collapseSelection();
  }

  /// Selects the word that contains [index], or the nearest token.
  void selectWord(String text, int index) {
    final ({int start, int end}) span = wordBounds(text, index);
    selectionAnchorParagraph = paragraphIndex;
    selectionAnchor = span.start;
    logicalIndex = span.end;
    resetBlink();
  }

  /// Selects the whole paragraph.
  void selectParagraph(String text) {
    selectionAnchorParagraph = paragraphIndex;
    selectionAnchor = 0;
    logicalIndex = text.length;
    resetBlink();
  }

  static ({int start, int end}) wordBounds(String text, int index) {
    if (text.isEmpty) {
      return (start: 0, end: 0);
    }
    var i = index.clamp(0, text.length);
    if (i == text.length) {
      i = text.length - 1;
    }
    if (!_isWordChar(text, i) && i > 0 && _isWordChar(text, i - 1)) {
      i--;
    }
    var start = i;
    var end = i + 1;
    if (_isWordChar(text, i)) {
      while (start > 0 && _isWordChar(text, start - 1)) {
        start--;
      }
      while (end < text.length && _isWordChar(text, end)) {
        end++;
      }
    } else if (_isSpace(text, i)) {
      while (start > 0 && _isSpace(text, start - 1)) {
        start--;
      }
      while (end < text.length && _isSpace(text, end)) {
        end++;
      }
    } else {
      while (start > 0 &&
          !_isWordChar(text, start - 1) &&
          !_isSpace(text, start - 1)) {
        start--;
      }
      while (end < text.length &&
          !_isWordChar(text, end) &&
          !_isSpace(text, end)) {
        end++;
      }
    }
    return (start: start, end: end);
  }

  /// Line between `\n` characters that contains [index].
  static ({int start, int end}) paragraphBounds(String text, int index) {
    if (text.isEmpty) {
      return (start: 0, end: 0);
    }
    final int i = index.clamp(0, text.length);
    var start = i;
    while (start > 0 && text[start - 1] != '\n') {
      start--;
    }
    var end = i;
    while (end < text.length && text[end] != '\n') {
      end++;
    }
    return (start: start, end: end);
  }

  /// coversIndex API.
  bool coversIndex(int paragraph, int index) {
    if (isCollapsed) {
      return false;
    }
    final ({int startPara, int startIdx, int endPara, int endIdx}) range =
        normalizedRange;
    if (paragraph < range.startPara || paragraph > range.endPara) {
      return false;
    }
    if (paragraph == range.startPara && index < range.startIdx) {
      return false;
    }
    if (paragraph == range.endPara && index > range.endIdx) {
      return false;
    }
    return true;
  }

  /// coversParagraph API.
  bool coversParagraph(int index) {
    final int a = selectionAnchorParagraph < paragraphIndex
        ? selectionAnchorParagraph
        : paragraphIndex;
    final int b = selectionAnchorParagraph > paragraphIndex
        ? selectionAnchorParagraph
        : paragraphIndex;
    if (a == b && selectionAnchor == logicalIndex) {
      return false;
    }
    return index >= a && index <= b;
  }

  static bool _isWordChar(String text, int index) {
    if (index < 0 || index >= text.length) {
      return false;
    }
    return _wordChar.hasMatch(text[index]);
  }

  static bool _isSpace(String text, int index) {
    if (index < 0 || index >= text.length) {
      return false;
    }
    return text[index].trim().isEmpty;
  }

  /// moveVisual API.
  void moveVisual(BrokenLine line, bool right) {
    final double x = logicalToVisualX(line, logicalIndex);
    final double next = right ? x + 1 : x - 1;
    logicalIndex = visualXToLogical(line, next);
    collapseSelection();
  }

  /// selectionRects API.
  List<Rect> selectionRects(
    BrokenLine line,
    double y,
    double height, {
    int? paragraph,
  }) {
    final int linePara = paragraph ?? paragraphIndex;
    final int aPara = selectionAnchorParagraph;
    final int bPara = paragraphIndex;
    final int aIdx = selectionAnchor;
    final int bIdx = logicalIndex;
    final bool forward = aPara < bPara || (aPara == bPara && aIdx <= bIdx);
    final int startPara = forward ? aPara : bPara;
    final int endPara = forward ? bPara : aPara;
    final int startIdx = forward ? aIdx : bIdx;
    final int endIdx = forward ? bIdx : aIdx;
    if (startPara == endPara && startIdx == endIdx) {
      return const <Rect>[];
    }
    if (linePara < startPara || linePara > endPara) {
      return const <Rect>[];
    }
    final int from;
    final int to;
    if (startPara == endPara) {
      from = startIdx;
      to = endIdx;
    } else if (linePara == startPara) {
      from = startIdx;
      to = 1 << 20;
    } else if (linePara == endPara) {
      from = 0;
      to = endIdx;
    } else {
      from = 0;
      to = 1 << 20;
    }
    if (line.glyphs.isEmpty && from < to) {
      return <Rect>[Rect.fromLTWH(0, y, 8, height)];
    }
    final List<Rect> rects = <Rect>[];
    var x = 0.0;
    double? runStart;
    for (final ShapedGlyph g in line.glyphs) {
      final bool inside = g.logicalIndex >= from && g.logicalIndex < to;
      if (inside) {
        runStart ??= x;
      } else if (runStart != null) {
        rects.add(Rect.fromLTWH(runStart, y, x - runStart, height));
        runStart = null;
      }
      x += g.advance;
    }
    if (runStart != null) {
      rects.add(Rect.fromLTWH(runStart, y, x - runStart, height));
    }
    return rects;
  }

  /// caretRect API.
  Rect caretRect(BrokenLine line, double y, double height) {
    final double x = logicalToVisualX(line, logicalIndex);
    return Rect.fromLTWH(x, y, 1.5, height);
  }

  /// Inclusive logical range covered by [line] (min index … end after last).
  static ({int min, int max}) logicalSpan(LaidOutLine line) {
    if (line.glyphs.isEmpty) {
      return (min: 0, max: 0);
    }
    var min = line.glyphs.first.glyph.logicalIndex;
    var max = min + 1;
    for (final LaidOutGlyph glyph in line.glyphs) {
      if (glyph.glyph.logicalIndex < min) {
        min = glyph.glyph.logicalIndex;
      }
      final int end = glyph.glyph.logicalIndex + 1;
      if (end > max) {
        max = end;
      }
    }
    return (min: min, max: max);
  }

  /// True when this caret should be painted on [line].
  ///
  /// Uses min/max logical indices so RTL visual order (high index first)
  /// still matches. The exclusive end belongs to [line] only when it is
  /// the last line of the paragraph.
  bool isOnLine(LaidOutLine line, {required bool lastOfParagraph}) {
    if (line.paragraphIndex != paragraphIndex) {
      return false;
    }
    if (line.glyphs.isEmpty) {
      return lastOfParagraph;
    }
    final (:int min, :int max) = logicalSpan(line);
    if (logicalIndex < min) {
      return false;
    }
    if (logicalIndex < max) {
      return true;
    }
    return logicalIndex == max && lastOfParagraph;
  }

  /// Direction hook: true when the glyph at the caret is RTL.
  bool rtlAtCaret(BrokenLine line) {
    for (final ShapedGlyph g in line.glyphs) {
      if (g.logicalIndex == logicalIndex) {
        return g.level.isOdd;
      }
    }
    return line.glyphs.isNotEmpty && line.glyphs.last.level.isOdd;
  }
}
