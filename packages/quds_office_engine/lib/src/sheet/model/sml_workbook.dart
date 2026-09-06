import '../../opc/opc_archive.dart';
import '../../visual/office_visual.dart';
import '../styles/sml_styles.dart';

/// Enum SmlCellType.
enum SmlCellType { number, string, boolean, error, formula }

/// Class SmlCellRef.
class SmlCellRef {
  /// SmlCellRef API.
  const SmlCellRef(this.col, this.row);

  /// col API.
  final int col;

  /// row API.
  final int row;

  /// parse API.
  factory SmlCellRef.parse(String a1) {
    final Match? match = RegExp(r'^\$?([A-Za-z]+)\$?(\d+)$').firstMatch(a1);
    if (match == null) {
      throw FormatException('Invalid A1 reference: $a1');
    }
    return SmlCellRef(
      _colToIndex(match.group(1)!),
      int.parse(match.group(2)!) - 1,
    );
  }

  /// a1 API.
  String get a1 => '${_indexToCol(col)}${row + 1}';

  static int _colToIndex(String letters) {
    var n = 0;
    for (int i = 0; i < letters.length; i++) {
      n = n * 26 + (letters[i].toUpperCase().codeUnitAt(0) - 64);
    }
    return n - 1;
  }

  static String _indexToCol(int index) {
    var n = index + 1;
    final StringBuffer buffer = StringBuffer();
    while (n > 0) {
      n--;
      buffer.writeCharCode(65 + (n % 26));
      n ~/= 26;
    }
    return buffer.toString().split('').reversed.join();
  }
}

/// Class SmlRange.
class SmlRange {
  /// SmlRange API.
  const SmlRange(this.start, this.end);

  /// start API.
  final SmlCellRef start;

  /// end API.
  final SmlCellRef end;

  /// parse API.
  factory SmlRange.parse(String a1) {
    final int colon = a1.indexOf(':');
    if (colon < 0) {
      final SmlCellRef one = SmlCellRef.parse(a1);
      return SmlRange(one, one);
    }
    return SmlRange(
      SmlCellRef.parse(a1.substring(0, colon)),
      SmlCellRef.parse(a1.substring(colon + 1)),
    );
  }

  /// cells API.
  Iterable<SmlCellRef> get cells sync* {
    final int r0 = start.row < end.row ? start.row : end.row;
    final int r1 = start.row > end.row ? start.row : end.row;
    final int c0 = start.col < end.col ? start.col : end.col;
    final int c1 = start.col > end.col ? start.col : end.col;
    for (int r = r0; r <= r1; r++) {
      for (int c = c0; c <= c1; c++) {
        yield SmlCellRef(c, r);
      }
    }
  }
}

/// Class SmlCell.
class SmlCell {
  /// SmlCell API.
  SmlCell({
    required this.ref,
    this.type = SmlCellType.number,
    this.value,
    this.formula,
    this.styleIndex = 0,
  });

  /// ref API.
  SmlCellRef ref;

  /// type API.
  SmlCellType type;

  /// value API.
  Object? value;

  /// formula API.
  String? formula;

  /// styleIndex API.
  int styleIndex;

  /// asNumber API.
  double? get asNumber {
    final Object? v = value;
    if (v is num) {
      return v.toDouble();
    }
    if (v is String) {
      return double.tryParse(v);
    }
    if (v is bool) {
      return v ? 1 : 0;
    }
    return null;
  }

  /// asString API.
  String get asString => value?.toString() ?? '';

  /// hasContent API.
  bool get hasContent {
    if (formula != null && formula!.isNotEmpty) {
      return true;
    }
    if (value == null) {
      return false;
    }
    return asString.isNotEmpty;
  }
}

/// Class SmlRow.
class SmlRow {
  /// SmlRow API.
  SmlRow(this.index, {Map<int, SmlCell>? cells})
    : cells = cells ?? <int, SmlCell>{};

  /// index API.
  final int index;

  /// cells API.
  final Map<int, SmlCell> cells;

  /// cell API.
  SmlCell cell(int col) =>
      cells.putIfAbsent(col, () => SmlCell(ref: SmlCellRef(col, index)));
}

/// Class SmlWorksheet.
class SmlWorksheet {
  /// SmlWorksheet API.
  SmlWorksheet({
    required this.name,
    required this.sheetId,
    this.rightToLeft = false,
    this.freezeRows = 0,
    this.freezeCols = 0,
    Map<int, SmlRow>? rows,
    List<SmlDrawing>? drawings,
    Map<int, double>? columnWidths,
    Map<int, double>? rowHeights,
  }) : rows = rows ?? <int, SmlRow>{},
       drawings = drawings ?? <SmlDrawing>[],
       columnWidths = columnWidths ?? <int, double>{},
       rowHeights = rowHeights ?? <int, double>{};

  /// Excel worksheet column count (A … XFD).
  static const int excelColumnCount = 16384;

  /// Excel worksheet row count (1 … 1048576).
  static const int excelRowCount = 1048576;

  /// Default rendered column width in CSS pixels (Excel default ≈ 8.43 chars).
  static const double defaultColumnWidthPx = 64;

  /// Default rendered row height in CSS pixels (Excel default 15 pt @ 96 dpi).
  static const double defaultRowHeightPx = 20;

  /// minColumnWidthPx API.
  static const double minColumnWidthPx = 8;

  /// maxColumnWidthPx API.
  static const double maxColumnWidthPx = 800;

  /// minRowHeightPx API.
  static const double minRowHeightPx = 8;

  /// maxRowHeightPx API.
  static const double maxRowHeightPx = 409;

  /// OOXML `col/@width` character units matching [defaultColumnWidthPx].
  static const double excelDefaultColumnWidth = 8.43;

  /// name API.
  String name;

  /// sheetId API.
  int sheetId;

  /// Excel `sheetView/@rightToLeft`: column A sits on the right.
  bool rightToLeft;

  /// Frozen row count (`pane/@ySplit`): rows `[0, freezeRows)` stay pinned.
  int freezeRows;

  /// Frozen column count (`pane/@xSplit`): cols `[0, freezeCols)` stay pinned.
  int freezeCols;

  /// rows API.
  final Map<int, SmlRow> rows;

  /// drawings API.
  final List<SmlDrawing> drawings;

  /// Custom column widths in CSS pixels, keyed by 0-based column index.
  final Map<int, double> columnWidths;

  /// Custom row heights in CSS pixels, keyed by 0-based row index.
  final Map<int, double> rowHeights;

  /// row API.
  SmlRow row(int index) => rows.putIfAbsent(index, () => SmlRow(index));

  /// cell API.
  SmlCell cell(SmlCellRef ref) => row(ref.row).cell(ref.col);

  /// cellA1 API.
  SmlCell cellA1(String a1) => cell(SmlCellRef.parse(a1));

  /// allCells API.
  Iterable<SmlCell> get allCells sync* {
    for (final SmlRow row in rows.values) {
      yield* row.cells.values;
    }
  }

  /// columnWidthFromExcel API.
  static double columnWidthFromExcel(double excelWidth) =>
      excelWidth * defaultColumnWidthPx / excelDefaultColumnWidth;

  /// columnWidthToExcel API.
  static double columnWidthToExcel(double px) =>
      px * excelDefaultColumnWidth / defaultColumnWidthPx;

  /// rowHeightFromExcel API.
  static double rowHeightFromExcel(double points) => points * 96 / 72;

  /// rowHeightToExcel API.
  static double rowHeightToExcel(double px) => px * 72 / 96;

  /// columnWidth API.
  double columnWidth(int col) => columnWidths[col] ?? defaultColumnWidthPx;

  /// rowHeightAt API.
  double rowHeightAt(int row) => rowHeights[row] ?? defaultRowHeightPx;

  /// setColumnWidth API.
  void setColumnWidth(int col, double px) {
    if (col < 0 || col >= excelColumnCount) {
      return;
    }
    final double v = px.clamp(minColumnWidthPx, maxColumnWidthPx);
    if ((v - defaultColumnWidthPx).abs() < 0.5) {
      columnWidths.remove(col);
    } else {
      columnWidths[col] = v;
    }
  }

  /// setRowHeight API.
  void setRowHeight(int row, double px) {
    if (row < 0 || row >= excelRowCount) {
      return;
    }
    final double v = px.clamp(minRowHeightPx, maxRowHeightPx);
    if ((v - defaultRowHeightPx).abs() < 0.5) {
      rowHeights.remove(row);
    } else {
      rowHeights[row] = v;
    }
  }

  /// Content X of the left edge of [col] (or the right edge when
  /// [col] == [excelColumnCount]), in unscaled pixels.
  double columnLeft(int col) {
    final int c = col < 0
        ? 0
        : (col > excelColumnCount ? excelColumnCount : col);
    var x = c * defaultColumnWidthPx;
    if (columnWidths.isEmpty) {
      return x;
    }
    for (final MapEntry<int, double> e in columnWidths.entries) {
      if (e.key >= 0 && e.key < c) {
        x += e.value - defaultColumnWidthPx;
      }
    }
    return x;
  }

  /// Content Y of the top edge of [row] (or the bottom edge when
  /// [row] == [excelRowCount]), in unscaled pixels.
  double rowTop(int row) {
    final int r = row < 0 ? 0 : (row > excelRowCount ? excelRowCount : row);
    var y = r * defaultRowHeightPx;
    if (rowHeights.isEmpty) {
      return y;
    }
    for (final MapEntry<int, double> e in rowHeights.entries) {
      if (e.key >= 0 && e.key < r) {
        y += e.value - defaultRowHeightPx;
      }
    }
    return y;
  }

  /// columnAt API.
  int columnAt(double x) {
    if (x <= 0) {
      return 0;
    }
    if (columnWidths.isEmpty) {
      return (x / defaultColumnWidthPx).floor().clamp(0, excelColumnCount - 1);
    }
    var col = (x / defaultColumnWidthPx).floor().clamp(0, excelColumnCount - 1);
    var left = columnLeft(col);
    var width = columnWidth(col);
    var guard = 0;
    while (left > x && col > 0 && guard++ < excelColumnCount) {
      col--;
      width = columnWidth(col);
      left -= width;
    }
    while (left + width <= x &&
        col < excelColumnCount - 1 &&
        guard++ < excelColumnCount) {
      left += width;
      col++;
      width = columnWidth(col);
    }
    return col;
  }

  /// hasContentAt API.
  bool hasContentAt(SmlCellRef ref) {
    final SmlRow? row = rows[ref.row];
    if (row == null) {
      return false;
    }
    final SmlCell? cell = row.cells[ref.col];
    return cell != null && cell.hasContent;
  }

  /// Bottom-right content cell, or A1 when the sheet is empty.
  SmlCellRef usedExtent() {
    var maxC = 0;
    var maxR = 0;
    var any = false;
    for (final SmlCell cell in allCells) {
      if (!cell.hasContent) {
        continue;
      }
      any = true;
      if (cell.ref.col > maxC) {
        maxC = cell.ref.col;
      }
      if (cell.ref.row > maxR) {
        maxR = cell.ref.row;
      }
    }
    return any ? SmlCellRef(maxC, maxR) : const SmlCellRef(0, 0);
  }

  /// firstContentColOnRow API.
  int? firstContentColOnRow(int row) {
    final SmlRow? data = rows[row];
    if (data == null) {
      return null;
    }
    int? minC;
    for (final SmlCell cell in data.cells.values) {
      if (!cell.hasContent) {
        continue;
      }
      if (minC == null || cell.ref.col < minC) {
        minC = cell.ref.col;
      }
    }
    return minC;
  }

  /// lastContentColOnRow API.
  int? lastContentColOnRow(int row) {
    final SmlRow? data = rows[row];
    if (data == null) {
      return null;
    }
    int? maxC;
    for (final SmlCell cell in data.cells.values) {
      if (!cell.hasContent) {
        continue;
      }
      if (maxC == null || cell.ref.col > maxC) {
        maxC = cell.ref.col;
      }
    }
    return maxC;
  }

  /// firstContentRowOnCol API.
  int? firstContentRowOnCol(int col) {
    int? minR;
    for (final SmlRow row in rows.values) {
      final SmlCell? cell = row.cells[col];
      if (cell == null || !cell.hasContent) {
        continue;
      }
      if (minR == null || row.index < minR) {
        minR = row.index;
      }
    }
    return minR;
  }

  /// lastContentRowOnCol API.
  int? lastContentRowOnCol(int col) {
    int? maxR;
    for (final SmlRow row in rows.values) {
      final SmlCell? cell = row.cells[col];
      if (cell == null || !cell.hasContent) {
        continue;
      }
      if (maxR == null || row.index > maxR) {
        maxR = row.index;
      }
    }
    return maxR;
  }

  /// Last cell in [dc]/[dr] that has the same filled or empty state as [from].
  ///
  /// Horizontal moves look only at [from]'s row; vertical moves look only at
  /// [from]'s column. Filled cells on other rows or columns are ignored.
  /// Already at the edge of a run, the opposite run is skipped so the caret
  /// lands on the last cell of the next same-occupancy block, or stays put.
  SmlCellRef sameOccupancy(SmlCellRef from, int dc, int dr) {
    final int stepC = dc == 0 ? 0 : (dc > 0 ? 1 : -1);
    final int stepR = dr == 0 ? 0 : (dr > 0 ? 1 : -1);
    if (stepC == 0 && stepR == 0) {
      return from;
    }
    if (stepC != 0) {
      return _sameOnLine(
        start: from.col,
        step: stepC,
        maxIndex: excelColumnCount - 1,
        firstContent: firstContentColOnRow(from.row),
        lastContent: lastContentColOnRow(from.row),
        filledAt: (int col) => hasContentAt(SmlCellRef(col, from.row)),
        makeRef: (int col) => SmlCellRef(col, from.row),
      );
    }
    return _sameOnLine(
      start: from.row,
      step: stepR,
      maxIndex: excelRowCount - 1,
      firstContent: firstContentRowOnCol(from.col),
      lastContent: lastContentRowOnCol(from.col),
      filledAt: (int row) => hasContentAt(SmlCellRef(from.col, row)),
      makeRef: (int row) => SmlCellRef(from.col, row),
    );
  }

  SmlCellRef _sameOnLine({
    required int start,
    required int step,
    required int maxIndex,
    required int? firstContent,
    required int? lastContent,
    required bool Function(int index) filledAt,
    required SmlCellRef Function(int index) makeRef,
  }) {
    if (firstContent == null || lastContent == null) {
      return makeRef(start);
    }
    final bool startFilled = filledAt(start);
    bool inScan(int index) {
      if (index < 0 || index > maxIndex) {
        return false;
      }
      if (startFilled) {
        return index >= firstContent && index <= lastContent;
      }
      return index <= lastContent;
    }

    var index = start + step;
    if (!inScan(index)) {
      return makeRef(start);
    }
    if (filledAt(index) == startFilled) {
      while (inScan(index + step) && filledAt(index + step) == startFilled) {
        index += step;
      }
      return makeRef(index);
    }
    while (inScan(index + step) && filledAt(index) != startFilled) {
      index += step;
    }
    if (filledAt(index) != startFilled) {
      return makeRef(start);
    }
    while (inScan(index + step) && filledAt(index + step) == startFilled) {
      index += step;
    }
    return makeRef(index);
  }

  /// rowAt API.
  int rowAt(double y) {
    if (y <= 0) {
      return 0;
    }
    if (rowHeights.isEmpty) {
      return (y / defaultRowHeightPx).floor().clamp(0, excelRowCount - 1);
    }
    var row = (y / defaultRowHeightPx).floor().clamp(0, excelRowCount - 1);
    var top = rowTop(row);
    var height = rowHeightAt(row);
    var guard = 0;
    while (top > y && row > 0 && guard++ < excelRowCount) {
      row--;
      height = rowHeightAt(row);
      top -= height;
    }
    while (top + height <= y &&
        row < excelRowCount - 1 &&
        guard++ < excelRowCount) {
      top += height;
      row++;
      height = rowHeightAt(row);
    }
    return row;
  }

  /// Inserts [count] empty rows starting at [index], shifting existing cells down.
  void insertRows(int index, [int count = 1]) {
    if (count <= 0 || index < 0) {
      return;
    }
    final Map<int, SmlRow> next = <int, SmlRow>{};
    for (final MapEntry<int, SmlRow> e in rows.entries) {
      if (e.key >= index) {
        next[e.key + count] = _moveRow(e.value, e.key + count);
      } else {
        next[e.key] = e.value;
      }
    }
    rows
      ..clear()
      ..addAll(next);
    _shiftKeyedMap(rowHeights, index, count, remove: false);
  }

  /// Inserts [count] empty columns starting at [index], shifting existing cells right.
  void insertCols(int index, [int count = 1]) {
    if (count <= 0 || index < 0) {
      return;
    }
    for (final SmlRow row in rows.values) {
      _shiftRowCells(row, index, count, remove: false);
    }
    _shiftKeyedMap(columnWidths, index, count, remove: false);
  }

  /// Deletes [count] rows starting at [index], shifting remaining cells up.
  void deleteRows(int index, [int count = 1]) {
    if (count <= 0 || index < 0) {
      return;
    }
    final int last = index + count;
    final Map<int, SmlRow> next = <int, SmlRow>{};
    for (final MapEntry<int, SmlRow> e in rows.entries) {
      if (e.key >= index && e.key < last) {
        continue;
      }
      if (e.key >= last) {
        next[e.key - count] = _moveRow(e.value, e.key - count);
      } else {
        next[e.key] = e.value;
      }
    }
    rows
      ..clear()
      ..addAll(next);
    _shiftKeyedMap(rowHeights, index, count, remove: true);
  }

  /// Deletes [count] columns starting at [index], shifting remaining cells left.
  void deleteCols(int index, [int count = 1]) {
    if (count <= 0 || index < 0) {
      return;
    }
    for (final SmlRow row in rows.values) {
      _shiftRowCells(row, index, -count, remove: true);
    }
    _shiftKeyedMap(columnWidths, index, count, remove: true);
  }

  static SmlRow _moveRow(SmlRow source, int newIndex) {
    final SmlRow moved = SmlRow(newIndex);
    for (final MapEntry<int, SmlCell> e in source.cells.entries) {
      e.value.ref = SmlCellRef(e.key, newIndex);
      moved.cells[e.key] = e.value;
    }
    return moved;
  }

  static void _shiftRowCells(
    SmlRow row,
    int index,
    int delta, {
    required bool remove,
  }) {
    final int removedLast = remove ? index - delta : -1;
    final Map<int, SmlCell> next = <int, SmlCell>{};
    for (final MapEntry<int, SmlCell> e in row.cells.entries) {
      if (remove && e.key >= index && e.key < removedLast) {
        continue;
      }
      if (e.key >= index) {
        final int col = e.key + delta;
        e.value.ref = SmlCellRef(col, row.index);
        next[col] = e.value;
      } else {
        next[e.key] = e.value;
      }
    }
    row.cells
      ..clear()
      ..addAll(next);
  }

  static void _shiftKeyedMap(
    Map<int, double> map,
    int index,
    int count, {
    required bool remove,
  }) {
    final int last = index + count;
    final Map<int, double> next = <int, double>{};
    for (final MapEntry<int, double> e in map.entries) {
      if (remove && e.key >= index && e.key < last) {
        continue;
      }
      if (e.key >= (remove ? last : index)) {
        next[e.key + (remove ? -count : count)] = e.value;
      } else {
        next[e.key] = e.value;
      }
    }
    map
      ..clear()
      ..addAll(next);
  }
}

/// Class SmlWorkbook.
class SmlWorkbook {
  /// SmlWorkbook API.
  SmlWorkbook({
    List<SmlWorksheet>? sheets,
    List<String>? sharedStrings,
    this.package,
    this.styles,
  }) : sheets =
           sheets ?? <SmlWorksheet>[SmlWorksheet(name: 'Sheet1', sheetId: 1)],
       sharedStrings = sharedStrings ?? <String>[];

  /// sheets API.
  List<SmlWorksheet> sheets;

  /// sharedStrings API.
  List<String> sharedStrings;

  /// package API.
  OpcPackage? package;

  /// styles API.
  SmlStyleSheet? styles;

  /// firstSheet API.
  SmlWorksheet get firstSheet => sheets.first;

  /// sheetByName API.
  SmlWorksheet? sheetByName(String name) {
    for (final SmlWorksheet s in sheets) {
      if (s.name == name) {
        return s;
      }
    }
    return null;
  }
}
