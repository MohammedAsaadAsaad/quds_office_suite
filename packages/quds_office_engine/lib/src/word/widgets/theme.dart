part of 'widgets.dart';

/// Document / page theme. Same role as `pw.ThemeData`.
class ThemeData {
  /// ThemeData API.
  ThemeData({
    TextStyle? defaultTextStyle,
    TextStyle? paragraphStyle,
    TextStyle? header0,
    TextStyle? header1,
    TextStyle? header2,
    TextStyle? header3,
    TextStyle? header4,
    TextStyle? header5,
    TextStyle? bulletStyle,
    TextStyle? tableHeader,
    TextStyle? tableCell,
    this.textAlign,
    this.tableHeaderFill = '1F4E79',
    this.tableBandFill = 'F2F2F2',
    this.rule = 'BFBFBF',
    IconThemeData? iconTheme,
  }) : iconTheme = iconTheme ?? const IconThemeData.fallback(),
       defaultTextStyle = defaultTextStyle ??
           const TextStyle(fontSize: 11, color: '000000', font: 'Calibri'),
       paragraphStyle =
           paragraphStyle ??
           const TextStyle(fontSize: 11, color: '000000', lineSpacing: 5),
       header0 =
           header0 ??
           const TextStyle(
             fontSize: 22,
             fontWeight: FontWeight.bold,
             color: '2B579A',
           ),
       header1 =
           header1 ??
           const TextStyle(
             fontSize: 16,
             fontWeight: FontWeight.bold,
             color: '2B579A',
           ),
       header2 =
           header2 ??
           const TextStyle(
             fontSize: 13,
             fontWeight: FontWeight.bold,
             color: '2B579A',
           ),
       header3 =
           header3 ??
           const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
       header4 =
           header4 ??
           const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
       header5 =
           header5 ??
           const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
       bulletStyle = bulletStyle ?? const TextStyle(fontSize: 11, lineSpacing: 5),
       tableHeader =
           tableHeader ??
           const TextStyle(
             fontSize: 10,
             fontWeight: FontWeight.bold,
             color: 'FFFFFF',
           ),
       tableCell = tableCell ?? const TextStyle(fontSize: 10);

  /// withFont API.
  factory ThemeData.withFont({
    String? base,
    String? bold,
    String? italic,
    TextAlign? textAlign,
  }) {
    final String font = base ?? 'Calibri';
    final String heading = bold ?? font;
    final String face = italic ?? font;
    final TextStyle def = TextStyle(
      font: face,
      fontSize: 11,
      color: '000000',
      fontWeight: FontWeight.normal,
    );
    return ThemeData(
      defaultTextStyle: def,
      paragraphStyle: def.copyWith(lineSpacing: 5),
      bulletStyle: def.copyWith(lineSpacing: 5),
      header0: def.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: '2B579A',
        font: heading,
      ),
      header1: def.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: '2B579A',
        font: heading,
      ),
      header2: def.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: '2B579A',
        font: heading,
      ),
      header3: def.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
      header4: def.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
      header5: def.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
      tableHeader: def.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: 'FFFFFF',
      ),
      tableCell: def.copyWith(fontSize: 10),
      textAlign: textAlign,
    );
  }

  /// base API.
  factory ThemeData.base() => ThemeData.withFont();

  /// defaultTextStyle API.
  final TextStyle defaultTextStyle;

  /// paragraphStyle API.
  final TextStyle paragraphStyle;

  /// header0 API.
  final TextStyle header0;

  /// header1 API.
  final TextStyle header1;

  /// header2 API.
  final TextStyle header2;

  /// header3 API.
  final TextStyle header3;

  /// header4 API.
  final TextStyle header4;

  /// header5 API.
  final TextStyle header5;

  /// bulletStyle API.
  final TextStyle bulletStyle;

  /// tableHeader API.
  final TextStyle tableHeader;

  /// tableCell API.
  final TextStyle tableCell;

  /// textAlign API.
  final TextAlign? textAlign;

  /// Word table header fill (RRGGBB).
  final String tableHeaderFill;

  /// Word banded-row fill (RRGGBB).
  final String tableBandFill;

  /// Divider / table border color.
  final String rule;

  /// iconTheme API.
  final IconThemeData iconTheme;

  /// copyWith API.
  ThemeData copyWith({
    TextStyle? defaultTextStyle,
    TextStyle? paragraphStyle,
    TextAlign? textAlign,
    IconThemeData? iconTheme,
  }) {
    return ThemeData(
      defaultTextStyle: this.defaultTextStyle.merge(defaultTextStyle),
      paragraphStyle: this.paragraphStyle.merge(paragraphStyle),
      header0: header0,
      header1: header1,
      header2: header2,
      header3: header3,
      header4: header4,
      header5: header5,
      bulletStyle: bulletStyle,
      tableHeader: tableHeader,
      tableCell: tableCell,
      textAlign: textAlign ?? this.textAlign,
      tableHeaderFill: tableHeaderFill,
      tableBandFill: tableBandFill,
      rule: rule,
      iconTheme: iconTheme ?? this.iconTheme,
    );
  }

  /// headerStyle API.
  TextStyle headerStyle(int level) {
    return switch (level.clamp(0, 5)) {
      0 => header0,
      1 => header1,
      2 => header2,
      3 => header3,
      4 => header4,
      _ => header5,
    };
  }
}

/// Applies [data] to descendants. Same constructor as `pw.Theme`.
class Theme extends Widget {
  /// Theme API.
  const Theme({required this.data, required this.child});

  /// data API.
  final ThemeData data;

  /// child API.
  final Widget child;
}
