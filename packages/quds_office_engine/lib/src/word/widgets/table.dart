part of 'widgets.dart';

/// Table cell wrapping a child widget.
class TableCell {
  /// TableCell API.
  const TableCell({required this.child, this.colSpan = 1, this.fill});

  /// child API.
  final Widget child;

  /// colSpan API.
  final int colSpan;

  /// fill API.
  final String? fill;
}

/// Table row. Same role as `pw.TableRow`.
class TableRow {
  /// TableRow API.
  const TableRow({this.children = const <Widget>[], this.repeat = false});

  /// children API.
  final List<Widget> children;

  /// When true, painted as a header row (fill + header style).
  final bool repeat;
}

/// Word table. Same name and [fromTextArray] as `pw.Table`.
class Table extends Widget {
  /// Table API.
  const Table({
    this.children = const <TableRow>[],
    this.border = true,
    this.columnWidths,
  });

  /// fromTextArray API.
  factory Table.fromTextArray({
    List<String>? headers,
    required List<List<String>> data,
    bool border = true,
    List<double>? columnWidths,
    TextStyle? headerStyle,
    TextStyle? cellStyle,
    Alignment headerAlignment = Alignment.center,
    Alignment cellAlignment = Alignment.topLeft,
    EdgeInsets cellPadding = const EdgeInsets.all(5),
    String? headerDecoration,
    String? oddRowDecoration,
  }) {
    final List<TableRow> rows = <TableRow>[
      if (headers != null)
        TableRow(
          repeat: true,
          children: <Widget>[
            for (final String cell in headers)
              Align(
                alignment: headerAlignment,
                child: Padding(
                  padding: cellPadding,
                  child: Text(cell, style: headerStyle),
                ),
              ),
          ],
        ),
      for (int r = 0; r < data.length; r++)
        TableRow(
          children: <Widget>[
            for (final String cell in data[r])
              Align(
                alignment: cellAlignment,
                child: Padding(
                  padding: cellPadding,
                  child: Text(cell, style: cellStyle),
                ),
              ),
          ],
        ),
    ];
    return _TableFromArray(
      children: rows,
      border: border,
      columnWidths: columnWidths,
      headerFill: headerDecoration,
      oddFill: oddRowDecoration,
      banded: true,
    );
  }

  /// children API.
  final List<TableRow> children;

  /// border API.
  final bool border;

  /// columnWidths API.
  final List<double>? columnWidths;
}

class _TableFromArray extends Table {
  const _TableFromArray({
    super.children,
    super.border,
    super.columnWidths,
    this.headerFill,
    this.oddFill,
    this.banded = true,
  });

  final String? headerFill;
  final String? oddFill;
  final bool banded;
}
