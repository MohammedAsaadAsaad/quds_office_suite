import '../model/sml_workbook.dart';
import 'formula_eval.dart';
import 'formula_functions.dart';

enum FormulaTokenKind {
  number,
  string,
  boolTrue,
  boolFalse,
  name,
  cell,
  range,
  op,
  comma,
  lparen,
  rparen,
  eof,
}

class FormulaToken {
  const FormulaToken(
    this.kind,
    this.lexeme, {
    this.number,
    this.start = 0,
    this.end = 0,
  });

  final FormulaTokenKind kind;
  final String lexeme;
  final double? number;

  /// Offsets into the original formula string, including a leading `=`.
  final int start;
  final int end;
}

sealed class FormulaNode {
  Object? eval(FormulaContext ctx);
}

class FormulaContext {
  FormulaContext({
    required this.workbook,
    required this.sheet,
    required this.origin,
    this.onCircular,
  });

  final SmlWorkbook workbook;
  final SmlWorksheet sheet;
  final SmlCellRef origin;
  final void Function(SmlCellRef ref)? onCircular;
  final Set<String> _stack = <String>{};

  Object? valueOf(SmlCellRef ref, {SmlWorksheet? onSheet}) {
    final SmlWorksheet target = onSheet ?? sheet;
    final String key = '${target.name}!${ref.a1}';
    if (!_stack.add(key)) {
      onCircular?.call(ref);
      return '#CIRC!';
    }
    try {
      final SmlCell cell = target.cell(ref);
      if (cell.formula != null &&
          cell.formula!.isNotEmpty &&
          (cell.value == null || cell.value == cell.formula)) {
        return evaluateFormula(cell.formula!, this);
      }
      return cell.value;
    } finally {
      _stack.remove(key);
    }
  }
}

class LiteralNode extends FormulaNode {
  LiteralNode(this.value);

  final Object? value;

  @override
  Object? eval(FormulaContext ctx) => value;
}

class CellNode extends FormulaNode {
  CellNode(this.ref, {this.sheetName});

  final SmlCellRef ref;
  final String? sheetName;

  @override
  Object? eval(FormulaContext ctx) {
    final SmlWorksheet? sheet =
        sheetName == null ? ctx.sheet : ctx.workbook.sheetByName(sheetName!);
    return ctx.valueOf(ref, onSheet: sheet);
  }
}

class RangeNode extends FormulaNode {
  RangeNode(this.range, {this.sheetName});

  final SmlRange range;
  final String? sheetName;

  @override
  Object? eval(FormulaContext ctx) {
    final SmlWorksheet? sheet =
        sheetName == null ? ctx.sheet : ctx.workbook.sheetByName(sheetName!);
    final List<Object?> values = <Object?>[];
    for (final SmlCellRef ref in range.cells) {
      values.add(ctx.valueOf(ref, onSheet: sheet));
    }
    return values;
  }
}

class BinaryNode extends FormulaNode {
  BinaryNode(this.op, this.left, this.right);

  final String op;
  final FormulaNode left;
  final FormulaNode right;

  @override
  Object? eval(FormulaContext ctx) {
    final Object? a = left.eval(ctx);
    final Object? b = right.eval(ctx);
    if (op == '&') {
      return '${_str(a)}${_str(b)}';
    }
    final double? na = _num(a);
    final double? nb = _num(b);
    if (na == null || nb == null) {
      if (op == '=' || op == '<>') {
        final bool eq = _str(a) == _str(b);
        return op == '=' ? eq : !eq;
      }
      return '#VALUE!';
    }
    return switch (op) {
      '+' => na + nb,
      '-' => na - nb,
      '*' => na * nb,
      '/' => nb == 0 ? '#DIV/0!' : na / nb,
      '^' => _pow(na, nb),
      '=' => na == nb,
      '<>' => na != nb,
      '<' => na < nb,
      '<=' => na <= nb,
      '>' => na > nb,
      '>=' => na >= nb,
      _ => '#VALUE!',
    };
  }
}

class UnaryNode extends FormulaNode {
  UnaryNode(this.op, this.expr);

  final String op;
  final FormulaNode expr;

  @override
  Object? eval(FormulaContext ctx) {
    final double? n = _num(expr.eval(ctx));
    if (n == null) {
      return '#VALUE!';
    }
    return op == '-' ? -n : n;
  }
}

class CallNode extends FormulaNode {
  CallNode(this.name, this.args);

  final String name;
  final List<FormulaNode> args;

  @override
  Object? eval(FormulaContext ctx) => FormulaFunctions.call(name, args, ctx);
}

double? asFormulaNumber(Object? v) => _num(v);

List<double> flattenNumbers(Object? v) {
  final List<double> out = <double>[];
  void walk(Object? x) {
    if (x is List) {
      for (final Object? i in x) {
        walk(i);
      }
      return;
    }
    final double? n = _num(x);
    if (n != null) {
      out.add(n);
    }
  }

  walk(v);
  return out;
}

List<Object?> flattenValues(Object? v) {
  final List<Object?> out = <Object?>[];
  void walk(Object? x) {
    if (x is List) {
      for (final Object? item in x) {
        walk(item);
      }
      return;
    }
    out.add(x);
  }

  walk(v);
  return out;
}

double? _num(Object? v) {
  if (v is num) {
    return v.toDouble();
  }
  if (v is bool) {
    return v ? 1 : 0;
  }
  if (v is String) {
    return double.tryParse(v);
  }
  if (v is List) {
    for (final Object? item in v) {
      final double? n = _num(item);
      if (n != null) {
        return n;
      }
    }
  }
  return null;
}

String _str(Object? v) => v == null ? '' : v.toString();

double _pow(double a, double b) {
  var r = 1.0;
  final int exp = b.round();
  if (exp.toDouble() == b && exp >= 0 && exp < 40) {
    for (int i = 0; i < exp; i++) {
      r *= a;
    }
    return r;
  }
  // exp via exp(b*ln(a)) for positive a
  if (a <= 0) {
    return double.nan;
  }
  return _exp(b * _ln(a));
}

double _ln(double x) {
  if (x <= 0) {
    return double.nan;
  }
  var y = x;
  var k = 0;
  while (y > 1.5) {
    y /= 2.718281828459045;
    k++;
  }
  while (y < 0.7) {
    y *= 2.718281828459045;
    k--;
  }
  final double z = (y - 1) / (y + 1);
  final double z2 = z * z;
  var term = z;
  var sum = 0.0;
  for (int n = 0; n < 12; n++) {
    sum += term / (2 * n + 1);
    term *= z2;
  }
  return 2 * sum + k;
}

double _exp(double x) {
  var sum = 1.0;
  var term = 1.0;
  for (int n = 1; n < 20; n++) {
    term *= x / n;
    sum += term;
  }
  return sum;
}

String formulaString(Object? v) => _str(v);
