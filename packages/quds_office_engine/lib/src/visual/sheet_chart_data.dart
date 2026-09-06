import '../builders/office_markup.dart';
import '../sheet/formula/formula_eval.dart';
import '../sheet/model/sml_workbook.dart';
import 'office_visual.dart';

/// Builds chart points from a worksheet range, evaluating formulas.
abstract final class SheetChartData {
  static List<ChartPoint> fromRange({
    required SmlWorkbook book,
    required SmlWorksheet sheet,
    required SmlCellRef from,
    required SmlCellRef to,
  }) {
    final int r0 = from.row < to.row ? from.row : to.row;
    final int r1 = from.row > to.row ? from.row : to.row;
    final int c0 = from.col < to.col ? from.col : to.col;
    final int c1 = from.col > to.col ? from.col : to.col;
    final List<ChartPoint> points = <ChartPoint>[];
    if (r0 == r1) {
      for (int c = c0; c <= c1; c++) {
        points.add(
          ChartPoint(
            label: _columnLabel(sheet, c, r0),
            value: _number(book, sheet, SmlCellRef(c, r0)) ?? 0,
            color: VisualPalette.fills[points.length % VisualPalette.fills.length],
          ),
        );
      }
    } else if (c0 == c1) {
      for (int r = r0; r <= r1; r++) {
        points.add(
          ChartPoint(
            label: _rowLabel(sheet, c0, r),
            value: _number(book, sheet, SmlCellRef(c0, r)) ?? 0,
            color: VisualPalette.fills[points.length % VisualPalette.fills.length],
          ),
        );
      }
    } else {
      for (int r = r0; r <= r1; r++) {
        String label = sheet.cell(SmlCellRef(c0, r)).asString;
        double? value;
        for (int c = c1; c >= c0; c--) {
          value = _number(book, sheet, SmlCellRef(c, r));
          if (value != null) {
            break;
          }
        }
        if (label.isEmpty) {
          label = SmlCellRef(c0, r).a1;
        }
        if (value == null && label.isEmpty) {
          continue;
        }
        points.add(
          ChartPoint(
            label: label,
            value: value ?? 0,
            color: VisualPalette.fills[points.length % VisualPalette.fills.length],
          ),
        );
      }
    }
    return points;
  }

  static void refreshDrawing(
    SmlWorkbook book,
    SmlWorksheet sheet,
    SmlDrawing drawing,
  ) {
    final String? fromA1 = drawing.sourceFromA1;
    final String? toA1 = drawing.sourceToA1;
    if (fromA1 == null || toA1 == null || !drawing.visual.isChart) {
      return;
    }
    final SmlCellRef from = SmlCellRef.parse(fromA1);
    final SmlCellRef to = SmlCellRef.parse(toA1);
    final List<ChartPoint> next = fromRange(
      book: book,
      sheet: sheet,
      from: from,
      to: to,
    );
    if (next.isEmpty) {
      return;
    }
    final List<ChartPoint> previous = drawing.visual.points;
    final List<ChartPoint> merged = <ChartPoint>[
      for (int i = 0; i < next.length; i++)
        next[i].copyWith(
          color: i < previous.length ? previous[i].color : next[i].color,
        ),
    ];
    drawing.visual.points
      ..clear()
      ..addAll(merged);
  }

  static void refreshSheet(SmlWorkbook book, SmlWorksheet sheet) {
    for (final SmlDrawing drawing in sheet.drawings) {
      refreshDrawing(book, sheet, drawing);
    }
  }

  static void refreshWorkbook(SmlWorkbook book) {
    for (final SmlWorksheet sheet in book.sheets) {
      refreshSheet(book, sheet);
    }
  }

  static double? _number(
    SmlWorkbook book,
    SmlWorksheet sheet,
    SmlCellRef ref,
  ) {
    final SmlCell cell = sheet.cell(ref);
    if (cell.formula != null && cell.formula!.isNotEmpty) {
      final Object? value = FormulaEvaluator.evaluateCell(book, sheet, cell);
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value);
      }
      return null;
    }
    return cell.asNumber;
  }

  static String _columnLabel(SmlWorksheet sheet, int col, int valueRow) {
    for (int r = valueRow - 1; r >= 0; r--) {
      final SmlCell cell = sheet.cell(SmlCellRef(col, r));
      if (cell.formula != null && cell.formula!.isNotEmpty) {
        continue;
      }
      final String text = cell.asString.trim();
      if (text.isEmpty) {
        continue;
      }
      if (cell.asNumber != null && cell.type == SmlCellType.number) {
        continue;
      }
      return text;
    }
    return SmlCellRef(col, valueRow).a1;
  }

  static String _rowLabel(SmlWorksheet sheet, int valueCol, int row) {
    for (int c = valueCol - 1; c >= 0; c--) {
      final SmlCell cell = sheet.cell(SmlCellRef(c, row));
      if (cell.formula != null && cell.formula!.isNotEmpty) {
        continue;
      }
      final String text = cell.asString.trim();
      if (text.isEmpty) {
        continue;
      }
      if (cell.asNumber != null && cell.type == SmlCellType.number) {
        continue;
      }
      return text;
    }
    return SmlCellRef(valueCol, row).a1;
  }
}
