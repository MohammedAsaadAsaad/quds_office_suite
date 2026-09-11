import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:quds_office_engine/pdf_file.dart';

/// One caret/hit in visual run order (`page`, `run`, code-unit `offset`).
class PdfTextHit {
  /// PdfTextHit API.
  const PdfTextHit({
    required this.page,
    required this.run,
    required this.offset,
  });

  /// page API.
  final int page;

  /// run API.
  final int run;

  /// offset API.
  final int offset;

  /// compareTo API.
  int compareTo(PdfTextHit other) {
    if (page != other.page) {
      return page.compareTo(other.page);
    }
    if (run != other.run) {
      return run.compareTo(other.run);
    }
    return offset.compareTo(other.offset);
  }
}

/// Interactive PDF text range (ISO 32000 display-list runs).
class PdfTextSelection {
  /// PdfTextSelection API.
  const PdfTextSelection({
    required this.anchor,
    required this.extent,
  });

  /// Collapsed caret.
  factory PdfTextSelection.collapsed(PdfTextHit hit) =>
      PdfTextSelection(anchor: hit, extent: hit);

  /// Whole [run] on [page].
  factory PdfTextSelection.run(int page, int runIndex, PdfTextRun run) {
    return PdfTextSelection(
      anchor: PdfTextHit(page: page, run: runIndex, offset: 0),
      extent: PdfTextHit(
        page: page,
        run: runIndex,
        offset: run.text.length,
      ),
    );
  }

  /// Word around [hit] using whitespace boundaries.
  factory PdfTextSelection.word(PdfTextHit hit, PdfTextRun run) {
    final String text = run.text;
    var start = hit.offset.clamp(0, text.length);
    var end = start;
    while (start > 0 && !_sep(text.codeUnitAt(start - 1))) {
      start--;
    }
    while (end < text.length && !_sep(text.codeUnitAt(end))) {
      end++;
    }
    if (start == end && end < text.length) {
      end++;
    }
    return PdfTextSelection(
      anchor: PdfTextHit(page: hit.page, run: hit.run, offset: start),
      extent: PdfTextHit(page: hit.page, run: hit.run, offset: end),
    );
  }

  /// Drag anchor.
  final PdfTextHit anchor;

  /// Drag extent.
  final PdfTextHit extent;

  /// isCollapsed API.
  bool get isCollapsed => anchor.compareTo(extent) == 0;

  /// Normalized start ≤ end.
  PdfTextSelection get normalized {
    return anchor.compareTo(extent) <= 0
        ? this
        : PdfTextSelection(anchor: extent, extent: anchor);
  }

  /// extendTo API.
  PdfTextSelection extendTo(PdfTextHit hit) =>
      PdfTextSelection(anchor: anchor, extent: hit);

  /// Unicode for copy / find.
  String plainText(List<PdfDisplayList> lists) {
    final StringBuffer buf = StringBuffer();
    _visit(lists, (int _, PdfTextRun run, int from, int to, bool breakBefore) {
      if (from >= to) {
        return;
      }
      if (buf.isNotEmpty && breakBefore) {
        buf.write('\n');
      }
      buf.write(run.text.substring(from, to));
    });
    return buf.toString();
  }

  /// Highlight boxes in page space, tagged with the page index.
  List<({int page, Rect rect})> boxes(List<PdfDisplayList> lists) {
    final List<({int page, Rect rect})> out = <({int page, Rect rect})>[];
    _visit(lists, (int page, PdfTextRun run, int from, int to, bool _) {
      if (from >= to) {
        return;
      }
      out.add((page: page, rect: sliceRect(run, from, to)));
    });
    return out;
  }

  /// Primary visual run (highlight / redact fallback).
  PdfTextRun? primaryRun(List<PdfDisplayList> lists) {
    final PdfTextSelection n = normalized;
    if (n.anchor.page < 0 || n.anchor.page >= lists.length) {
      return null;
    }
    final List<PdfTextRun> runs = lists[n.anchor.page].runs;
    if (n.anchor.run < 0 || n.anchor.run >= runs.length) {
      return null;
    }
    return runs[n.anchor.run];
  }

  void _visit(
    List<PdfDisplayList> lists,
    void Function(
      int page,
      PdfTextRun run,
      int from,
      int to,
      bool breakBefore,
    ) emit,
  ) {
    final PdfTextSelection n = normalized;
    if (lists.isEmpty) {
      return;
    }
    final int p0 = n.anchor.page.clamp(0, lists.length - 1);
    final int p1 = n.extent.page.clamp(0, lists.length - 1);
    for (int p = p0; p <= p1; p++) {
      final List<PdfTextRun> runs = lists[p].runs;
      if (runs.isEmpty) {
        continue;
      }
      final int r0 = p == p0 ? n.anchor.run.clamp(0, runs.length - 1) : 0;
      final int r1 = p == p1
          ? n.extent.run.clamp(0, runs.length - 1)
          : runs.length - 1;
      for (int r = r0; r <= r1; r++) {
        final PdfTextRun run = runs[r];
        final int len = run.text.length;
        final int from = (p == p0 && r == n.anchor.run)
            ? n.anchor.offset.clamp(0, len)
            : 0;
        final int to = (p == p1 && r == n.extent.run)
            ? n.extent.offset.clamp(0, len)
            : len;
        emit(p, run, from, to, run.breakBefore);
      }
    }
  }

  /// Sub-rectangle of [run] for code units `[from, to)`.
  static Rect sliceRect(PdfTextRun run, int from, int to) {
    final int n = run.text.length;
    if (n <= 0 || run.width <= 0) {
      return Rect.fromLTWH(run.x, run.y, math.max(run.width, 1), run.height);
    }
    final int a = from.clamp(0, n);
    final int b = to.clamp(0, n);
    final double x0 = run.x + run.width * (a / n);
    final double x1 = run.x + run.width * (b / n);
    return Rect.fromLTRB(
      math.min(x0, x1),
      run.y,
      math.max(x0, x1),
      run.y + math.max(run.height, 1),
    );
  }

  /// Code-unit index at page-space [x].
  static int offsetAt(PdfTextRun run, double x) {
    final int n = run.text.length;
    if (n <= 0 || run.width <= 0) {
      return 0;
    }
    final double t = ((x - run.x) / run.width).clamp(0.0, 1.0);
    return (t * n).round().clamp(0, n);
  }

  /// Hit-test pad so thin PDF em-boxes stay selectable.
  static bool containsPadded(PdfTextRun run, double x, double y) {
    const double pad = 3;
    return x >= run.x - pad &&
        y >= run.y - pad &&
        x <= run.x + run.width + pad &&
        y <= run.y + run.height + pad;
  }

  static bool _sep(int unit) {
    return unit == 0x20 ||
        unit == 0x09 ||
        unit == 0x0A ||
        unit == 0x0D ||
        unit == 0xA0;
  }
}
