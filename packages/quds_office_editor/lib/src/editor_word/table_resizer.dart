import 'package:flutter/services.dart';

/// Hover-within-3px table divider detection.
class TableResizer {
  TableResizer({required this.columnXs, this.tolerance = 3});

  final List<double> columnXs;
  final double tolerance;
  int? hoverColumn;
  double? dragStart;

  MouseCursor cursorFor(double x) {
    hoverColumn = _near(x);
    return hoverColumn == null
        ? SystemMouseCursors.basic
        : SystemMouseCursors.resizeColumn;
  }

  double applyDrag(double x) {
    if (hoverColumn == null) {
      return 0;
    }
    // First move is measured from the divider, not from the pointer, so a
    // hover-then-drag sequence (e.g. 101 then 110) actually widens the column.
    dragStart ??= columnXs[hoverColumn!];
    final double delta = x - dragStart!;
    dragStart = x;
    columnXs[hoverColumn!] += delta;
    return delta;
  }

  int? _near(double x) {
    for (int i = 0; i < columnXs.length; i++) {
      if ((columnXs[i] - x).abs() <= tolerance) {
        return i;
      }
    }
    return null;
  }
}
