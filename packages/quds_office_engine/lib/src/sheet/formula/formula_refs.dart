import '../model/sml_workbook.dart';
import 'formula_ast.dart';
import 'formula_eval.dart';

/// A cell or range reference inside a formula, with source offsets.
class FormulaRefSpan {
  const FormulaRefSpan({
    required this.start,
    required this.end,
    required this.lexeme,
    required this.range,
    this.sheetName,
  });

  final int start;
  final int end;
  final String lexeme;
  final SmlRange range;
  final String? sheetName;

  bool onSheet(String name) {
    if (sheetName == null || sheetName!.isEmpty) {
      return true;
    }
    return sheetName!.toLowerCase() == name.toLowerCase();
  }

  /// Stable key so `A1` and `$A$1` share a highlight color.
  String get colorKey {
    final int c0 = range.start.col < range.end.col ? range.start.col : range.end.col;
    final int c1 = range.start.col > range.end.col ? range.start.col : range.end.col;
    final int r0 = range.start.row < range.end.row ? range.start.row : range.end.row;
    final int r1 = range.start.row > range.end.row ? range.start.row : range.end.row;
    final String sheet = (sheetName ?? '').toLowerCase();
    return '$sheet!$c0,$r0:$c1,$r1';
  }
}

/// Finds A1 / range tokens in a formula while it is being typed.
abstract final class FormulaRefScanner {
  static List<FormulaRefSpan> scan(String formula) {
    final String trimmed = formula.trimLeft();
    if (!trimmed.startsWith('=')) {
      return const <FormulaRefSpan>[];
    }
    final List<FormulaRefSpan> spans = <FormulaRefSpan>[];
    for (final FormulaToken token in FormulaLexer(formula).tokenize()) {
      if (token.kind != FormulaTokenKind.cell &&
          token.kind != FormulaTokenKind.range) {
        continue;
      }
      try {
        spans.add(
          FormulaRefSpan(
            start: token.start,
            end: token.end > token.start ? token.end : token.start + token.lexeme.length,
            lexeme: token.lexeme,
            range: _rangeOf(token.lexeme),
            sheetName: _sheetName(token.lexeme),
          ),
        );
      } on FormatException {
        continue;
      }
    }
    return spans;
  }

  static SmlRange _rangeOf(String lexeme) {
    final int bang = lexeme.lastIndexOf('!');
    return SmlRange.parse(bang >= 0 ? lexeme.substring(bang + 1) : lexeme);
  }

  static String? _sheetName(String lexeme) {
    final int bang = lexeme.lastIndexOf('!');
    if (bang < 0) {
      return null;
    }
    final String raw = lexeme.substring(0, bang);
    if (raw.length >= 2 && raw.startsWith("'") && raw.endsWith("'")) {
      return raw.substring(1, raw.length - 1).replaceAll("''", "'");
    }
    return raw;
  }
}
