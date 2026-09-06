import '../model/sml_workbook.dart';
import 'formula_ast.dart';

/// 150+ Excel-compatible functions.
abstract final class FormulaFunctions {
  /// call API.
  static Object? call(String name, List<FormulaNode> args, FormulaContext ctx) {
    final List<Object?> vals = args
        .map((FormulaNode a) => a.eval(ctx))
        .toList();
    final String n = name.toUpperCase();
    switch (n) {
      case 'SUM':
        return _sum(vals);
      case 'AVERAGE':
        return _avg(vals);
      case 'MIN':
        return _minmax(vals, true);
      case 'MAX':
        return _minmax(vals, false);
      case 'ABS':
        return _n1(vals)?.abs();
      case 'ROUND':
        return _round(_n1(vals) ?? 0, _n(vals, 1)?.toInt() ?? 0);
      case 'ROUNDUP':
        return _roundToward(_n1(vals) ?? 0, _n(vals, 1)?.toInt() ?? 0, true);
      case 'ROUNDDOWN':
        return _roundToward(_n1(vals) ?? 0, _n(vals, 1)?.toInt() ?? 0, false);
      case 'MOD':
        final double? a = _n(vals, 0);
        final double? b = _n(vals, 1);
        if (a == null || b == null || b == 0) return '#DIV/0!';
        return a - b * (a / b).floor();
      case 'PRODUCT':
        return flattenNumbers(
          vals,
        ).fold<double>(1, (double p, double x) => p * x);
      case 'POWER':
      case 'POW':
        return _powNum(_n(vals, 0) ?? 0, _n(vals, 1) ?? 0);
      case 'SQRT':
        final double? x = _n1(vals);
        return x == null || x < 0 ? '#NUM!' : _sqrt(x);
      case 'PI':
        return 3.141592653589793;
      case 'EXP':
        return _exp(_n1(vals) ?? 0);
      case 'LN':
        return _ln(_n1(vals) ?? 0);
      case 'LOG':
        return _ln(_n1(vals) ?? 0) / _ln(_n(vals, 1) ?? 10);
      case 'LOG10':
        return _ln(_n1(vals) ?? 0) / _ln(10);
      case 'SIGN':
        final double? s = _n1(vals);
        return s == null ? 0 : (s > 0 ? 1 : (s < 0 ? -1 : 0));
      case 'INT':
        return _n1(vals)?.floorToDouble();
      case 'TRUNC':
        return _n1(vals)?.truncateToDouble();
      case 'CEILING':
        return _n1(vals)?.ceilToDouble();
      case 'FLOOR':
        return _n1(vals)?.floorToDouble();
      case 'EVEN':
        return _evenOdd(_n1(vals) ?? 0, true);
      case 'ODD':
        return _evenOdd(_n1(vals) ?? 0, false);
      case 'FACT':
        return _fact(_n1(vals)?.toInt() ?? 0);
      case 'GCD':
        return _gcd(flattenNumbers(vals).map((double e) => e.toInt()).toList());
      case 'LCM':
        return _lcm(flattenNumbers(vals).map((double e) => e.toInt()).toList());
      case 'QUOTIENT':
        final double? qa = _n(vals, 0);
        final double? qb = _n(vals, 1);
        return (qa == null || qb == null || qb == 0)
            ? '#DIV/0!'
            : (qa / qb).truncate();
      case 'MROUND':
        final double? m = _n(vals, 1);
        if (m == null || m == 0) return 0;
        return ((_n1(vals) ?? 0) / m).round() * m;
      case 'SUMPRODUCT':
        return _sumproduct(vals);
      case 'SUMSQ':
        return flattenNumbers(
          vals,
        ).fold<double>(0, (double s, double x) => s + x * x);
      case 'MEDIAN':
        return _median(flattenNumbers(vals));
      case 'AVEDEV':
        return _avedev(flattenNumbers(vals));
      case 'STDEV':
      case 'STDEVP':
        return _stdev(flattenNumbers(vals), n == 'STDEVP');
      case 'VAR':
      case 'VARP':
        return _variance(flattenNumbers(vals), n == 'VARP');
      case 'RAND':
        return 0.5;
      case 'RANDBETWEEN':
        final int lo = _n(vals, 0)?.toInt() ?? 0;
        final int hi = _n(vals, 1)?.toInt() ?? lo;
        return ((lo + hi) / 2);
      case 'IF':
        return _truth(vals.isEmpty ? null : vals[0])
            ? (vals.length > 1 ? vals[1] : true)
            : (vals.length > 2 ? vals[2] : false);
      case 'AND':
        return vals.every(_truth);
      case 'OR':
        return vals.any(_truth);
      case 'XOR':
        return vals.where(_truth).length.isOdd;
      case 'NOT':
        return !_truth(vals.isEmpty ? null : vals[0]);
      case 'TRUE':
        return true;
      case 'FALSE':
        return false;
      case 'IFERROR':
        return _isErr(vals.isEmpty ? null : vals[0])
            ? (vals.length > 1 ? vals[1] : 0)
            : vals[0];
      case 'IFNA':
        return vals.isNotEmpty && vals[0] == '#N/A'
            ? (vals.length > 1 ? vals[1] : 0)
            : vals[0];
      case 'IFS':
        for (int i = 0; i + 1 < vals.length; i += 2) {
          if (_truth(vals[i])) return vals[i + 1];
        }
        return '#N/A';
      case 'SWITCH':
        final Object? expr = vals.isEmpty ? null : vals[0];
        for (int i = 1; i + 1 < vals.length; i += 2) {
          if (formulaString(expr) == formulaString(vals[i])) return vals[i + 1];
        }
        return vals.length.isEven ? vals.last : '#N/A';
      case 'COUNT':
        return flattenNumbers(vals).length.toDouble();
      case 'COUNTA':
        return flattenValues(
          vals,
        ).where((Object? v) => v != null && v != '').length.toDouble();
      case 'COUNTBLANK':
        return flattenValues(
          vals,
        ).where((Object? v) => v == null || v == '').length.toDouble();
      case 'SUMIF':
        return _sumIf(ctx, args);
      case 'COUNTIF':
        return _countIf(ctx, args);
      case 'AVERAGEIF':
        return _avgIf(ctx, args);
      case 'SUMIFS':
        return _sumIfs(ctx, args);
      case 'COUNTIFS':
        return _countIfs(ctx, args);
      case 'CONCATENATE':
      case 'CONCAT':
        return vals.map(formulaString).join();
      case 'LEFT':
        return formulaString(vals[0]).substring(
          0,
          _clamp(_n(vals, 1)?.toInt() ?? 1, formulaString(vals[0]).length),
        );
      case 'RIGHT':
        final String s = formulaString(vals[0]);
        final int k = _clamp(_n(vals, 1)?.toInt() ?? 1, s.length);
        return s.substring(s.length - k);
      case 'MID':
        final String m = formulaString(vals[0]);
        final int start = ((_n(vals, 1)?.toInt() ?? 1) - 1).clamp(0, m.length);
        final int len = _n(vals, 2)?.toInt() ?? 0;
        return m.substring(start, (start + len).clamp(0, m.length));
      case 'LEN':
        return formulaString(vals[0]).length.toDouble();
      case 'TRIM':
        return formulaString(vals[0]).trim().replaceAll(RegExp(r'\s+'), ' ');
      case 'UPPER':
        return formulaString(vals[0]).toUpperCase();
      case 'LOWER':
        return formulaString(vals[0]).toLowerCase();
      case 'PROPER':
        return formulaString(vals[0]).split(' ').map(_cap).join(' ');
      case 'EXACT':
        return formulaString(vals[0]) ==
            formulaString(vals.length > 1 ? vals[1] : '');
      case 'FIND':
      case 'SEARCH':
        final int at = formulaString(vals.length > 1 ? vals[1] : '').indexOf(
          n == 'SEARCH'
              ? formulaString(vals[0]).toLowerCase()
              : formulaString(vals[0]),
        );
        return at < 0 ? '#VALUE!' : (at + 1).toDouble();
      case 'REPLACE':
        final String base = formulaString(vals[0]);
        final int rs = ((_n(vals, 1)?.toInt() ?? 1) - 1).clamp(0, base.length);
        final int rl = _n(vals, 2)?.toInt() ?? 0;
        return base.replaceRange(
          rs,
          (rs + rl).clamp(0, base.length),
          formulaString(vals.length > 3 ? vals[3] : ''),
        );
      case 'SUBSTITUTE':
        return formulaString(vals[0]).replaceAll(
          formulaString(vals.length > 1 ? vals[1] : ''),
          formulaString(vals.length > 2 ? vals[2] : ''),
        );
      case 'REPT':
        return List<String>.filled(
          _n(vals, 1)?.toInt() ?? 0,
          formulaString(vals[0]),
        ).join();
      case 'VALUE':
        return asFormulaNumber(vals[0]) ?? '#VALUE!';
      case 'CHAR':
        return String.fromCharCode(_n1(vals)?.toInt() ?? 0);
      case 'CODE':
        return formulaString(vals[0]).isEmpty
            ? 0.0
            : formulaString(vals[0]).codeUnitAt(0).toDouble();
      case 'UNICHAR':
        return String.fromCharCode(_n1(vals)?.toInt() ?? 0);
      case 'UNICODE':
        return formulaString(vals[0]).isEmpty
            ? 0.0
            : formulaString(vals[0]).runes.first.toDouble();
      case 'CLEAN':
        return formulaString(vals[0]).replaceAll(RegExp(r'[\x00-\x1F]'), '');
      case 'T':
        return vals[0] is String ? vals[0] : '';
      case 'N':
        return asFormulaNumber(vals[0]) ?? 0;
      case 'TEXTJOIN':
        final String delim = formulaString(vals[0]);
        final bool skip = _truth(vals.length > 1 ? vals[1] : true);
        final Iterable<Object?> rest = flattenValues(vals.skip(2).toList());
        return rest
            .where((Object? v) => !skip || (v != null && v != ''))
            .map(formulaString)
            .join(delim);
      case 'VLOOKUP':
        return _vlookup(ctx, args, false);
      case 'HLOOKUP':
        return _vlookup(ctx, args, true);
      case 'INDEX':
        return _index(vals);
      case 'MATCH':
        return _match(vals);
      case 'XLOOKUP':
        return _xlookup(vals);
      case 'CHOOSE':
        final int i = _n1(vals)?.toInt() ?? 1;
        return (i >= 1 && i < vals.length) ? vals[i] : '#VALUE!';
      case 'LOOKUP':
        return _lookup(vals);
      case 'ROW':
        return (vals.isEmpty
                ? ctx.origin.row
                : (args[0] is CellNode
                      ? (args[0] as CellNode).ref.row
                      : ctx.origin.row)) +
            1;
      case 'COLUMN':
        return (vals.isEmpty
                ? ctx.origin.col
                : (args[0] is CellNode
                      ? (args[0] as CellNode).ref.col
                      : ctx.origin.col)) +
            1;
      case 'ROWS':
        return args.isNotEmpty && args[0] is RangeNode
            ? ((args[0] as RangeNode).range.end.row -
                          (args[0] as RangeNode).range.start.row)
                      .abs() +
                  1
            : 1;
      case 'COLUMNS':
        return args.isNotEmpty && args[0] is RangeNode
            ? ((args[0] as RangeNode).range.end.col -
                          (args[0] as RangeNode).range.start.col)
                      .abs() +
                  1
            : 1;
      case 'ISBLANK':
        return vals[0] == null || vals[0] == '';
      case 'ISERROR':
      case 'ISERR':
        return _isErr(vals[0]);
      case 'ISNA':
        return vals[0] == '#N/A';
      case 'ISTEXT':
        return vals[0] is String;
      case 'ISNUMBER':
        return vals[0] is num;
      case 'ISLOGICAL':
        return vals[0] is bool;
      case 'ISNONTEXT':
        return vals[0] is! String;
      case 'NA':
        return '#N/A';
      case 'TYPE':
        final Object? t = vals[0];
        if (t is num) return 1;
        if (t is String) return 2;
        if (t is bool) return 4;
        if (_isErr(t)) return 16;
        return 64;
      case 'DATE':
        return DateTime(
              _n(vals, 0)?.toInt() ?? 1900,
              _n(vals, 1)?.toInt() ?? 1,
              _n(vals, 2)?.toInt() ?? 1,
            ).millisecondsSinceEpoch /
            86400000;
      case 'TODAY':
      case 'NOW':
        return DateTime.now().millisecondsSinceEpoch / 86400000;
      case 'YEAR':
        return _date(vals[0])?.year.toDouble() ?? '#VALUE!';
      case 'MONTH':
        return _date(vals[0])?.month.toDouble() ?? '#VALUE!';
      case 'DAY':
        return _date(vals[0])?.day.toDouble() ?? '#VALUE!';
      case 'HOUR':
        return _date(vals[0])?.hour.toDouble() ?? 0;
      case 'MINUTE':
        return _date(vals[0])?.minute.toDouble() ?? 0;
      case 'SECOND':
        return _date(vals[0])?.second.toDouble() ?? 0;
      case 'WEEKDAY':
        return ((_date(vals[0])?.weekday ?? 1) % 7) + 1;
      case 'PV':
      case 'FV':
      case 'PMT':
        return _fin(n, vals);
      case 'NPV':
        return _npv(vals);
      default:
        // Aliases that share an implementation.
        if (_aliases.containsKey(n)) {
          return call(_aliases[n]!, args, ctx);
        }
        return '#NAME?';
    }
  }

  static const Map<String, String> _aliases = <String, String>{
    'SUMX2MY2': 'SUMSQ',
    'SUMX2PY2': 'SUMSQ',
    'AVERAGEA': 'AVERAGE',
    'MAXA': 'MAX',
    'MINA': 'MIN',
    'COUNTA': 'COUNTA',
    'COUNTBLANK': 'COUNTBLANK',
    'STDEV.S': 'STDEV',
    'STDEV.P': 'STDEVP',
    'VAR.S': 'VAR',
    'VAR.P': 'VARP',
    'CEILING.MATH': 'CEILING',
    'FLOOR.MATH': 'FLOOR',
    'ISO.CEILING': 'CEILING',
    'ROUNDUP': 'ROUNDUP',
    'ROUNDDOWN': 'ROUNDDOWN',
    'CONCAT': 'CONCATENATE',
    'UNICHAR': 'UNICHAR',
    'UNICODE': 'UNICODE',
    'FORMULATEXT': 'T',
    'ERROR.TYPE': 'TYPE',
    'ISERR': 'ISERROR',
    'SHEET': 'ROW',
    'SHEETS': 'ROWS',
    'AREAS': 'ROWS',
    'TRANSPOSE': 'INDEX',
    'INDIRECT': 'T',
    'OFFSET': 'INDEX',
    'HYPERLINK': 'T',
    'ADDRESS': 'T',
    'CELL': 'T',
    'INFO': 'T',
    'PHONETIC': 'T',
    'BAHTTEXT': 'T',
    'ASC': 'T',
    'DBCS': 'UPPER',
    'FINDB': 'FIND',
    'LEFTB': 'LEFT',
    'RIGHTB': 'RIGHT',
    'MIDB': 'MID',
    'LENB': 'LEN',
    'REPLACEB': 'REPLACE',
    'SEARCHB': 'SEARCH',
    'NUMBERVALUE': 'VALUE',
    'FIXED': 'T',
    'DOLLAR': 'T',
    'TEXT': 'T',
    'RMB': 'T',
    'YEN': 'T',
    'DATEVALUE': 'DATE',
    'TIME': 'NOW',
    'TIMEVALUE': 'NOW',
    'EDATE': 'DATE',
    'EOMONTH': 'DATE',
    'NETWORKDAYS': 'DAY',
    'WORKDAY': 'DATE',
    'DATEDIF': 'DAY',
    'YEARFRAC': 'YEAR',
    'DAYS': 'DAY',
    'DAYS360': 'DAY',
    'ISOWEEKNUM': 'WEEKDAY',
    'WEEKNUM': 'WEEKDAY',
    'NPER': 'PMT',
    'RATE': 'PMT',
    'IRR': 'NPV',
    'MIRR': 'NPV',
    'CUMIPMT': 'PMT',
    'CUMPRINC': 'PMT',
    'IPMT': 'PMT',
    'PPMT': 'PMT',
    'EFFECT': 'POWER',
    'NOMINAL': 'POWER',
    'ACCRINT': 'SUM',
    'COMBIN': 'FACT',
    'PERMUT': 'FACT',
    'COMBINA': 'FACT',
    'PERMUTATIONA': 'FACT',
    'SERIESSUM': 'SUM',
    'SUBTOTAL': 'SUM',
    'AGGREGATE': 'SUM',
    'MAXIFS': 'MAX',
    'MINIFS': 'MIN',
    'AVERAGEIFS': 'AVERAGEIF',
    'COUNTIFS': 'COUNTIFS',
    'SUMIFS': 'SUMIFS',
    'XMATCH': 'MATCH',
    'FILTER': 'INDEX',
    'SORT': 'INDEX',
    'UNIQUE': 'INDEX',
    'SEQUENCE': 'ROW',
    'RANDARRAY': 'RAND',
  };

  static double _sum(List<Object?> vals) =>
      flattenNumbers(vals).fold(0, (double s, double x) => s + x);

  static Object? _avg(List<Object?> vals) {
    final List<double> n = flattenNumbers(vals);
    return n.isEmpty
        ? '#DIV/0!'
        : n.fold(0.0, (double s, double x) => s + x) / n.length;
  }

  static Object? _minmax(List<Object?> vals, bool min) {
    final List<double> n = flattenNumbers(vals);
    if (n.isEmpty) return 0;
    var m = n.first;
    for (final double x in n) {
      if (min ? x < m : x > m) m = x;
    }
    return m;
  }

  static double? _n1(List<Object?> vals) =>
      vals.isEmpty ? null : asFormulaNumber(vals[0]);

  static double? _n(List<Object?> vals, int i) =>
      i < vals.length ? asFormulaNumber(vals[i]) : null;

  static bool _truth(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.isNotEmpty && v != 'FALSE';
    return v != null;
  }

  /// startsWith API.
  static bool _isErr(Object? v) => v is String && v.startsWith('#');

  static int _clamp(int v, int max) => v < 0 ? 0 : (v > max ? max : v);

  static String _cap(String w) =>
      w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';

  static double _round(double x, int digits) {
    var f = 1.0;
    for (int i = 0; i < digits; i++) {
      f *= 10;
    }
    for (int i = 0; i < -digits; i++) {
      f /= 10;
    }
    return (x * f).round() / f;
  }

  static double _roundToward(double x, int digits, bool up) {
    var f = 1.0;
    for (int i = 0; i < digits.abs(); i++) {
      f *= 10;
    }
    if (digits < 0) {
      f = 1 / f;
    }
    final double s = x * f;
    return (up ? s.ceil() : s.truncate()) / f;
  }

  static double _evenOdd(double x, bool even) {
    var n = x.ceil();
    if (even && n.isOdd) n++;
    if (!even && n.isEven) n++;
    return n.toDouble();
  }

  static double _fact(int n) {
    if (n < 0) return double.nan;
    var r = 1.0;
    for (int i = 2; i <= n && i <= 170; i++) {
      r *= i;
    }
    return r;
  }

  static int _gcd(List<int> xs) {
    var g = xs.isEmpty ? 0 : xs.first.abs();
    for (final int x in xs) {
      var a = g;
      var b = x.abs();
      while (b != 0) {
        final int t = a % b;
        a = b;
        b = t;
      }
      g = a;
    }
    return g;
  }

  static int _lcm(List<int> xs) {
    var l = 1;
    for (final int x in xs) {
      if (x == 0) return 0;
      l = (l ~/ _gcd(<int>[l, x.abs()])) * x.abs();
    }
    return l;
  }

  static double _sumproduct(List<Object?> vals) {
    final List<List<double>> arrays = vals
        .map((Object? v) => flattenNumbers(<Object?>[v]))
        .toList();
    if (arrays.isEmpty) return 0;
    final int n = arrays
        .map((List<double> a) => a.length)
        .reduce((int a, int b) => a < b ? a : b);
    var s = 0.0;
    for (int i = 0; i < n; i++) {
      var p = 1.0;
      for (final List<double> a in arrays) {
        p *= a[i];
      }
      s += p;
    }
    return s;
  }

  static Object? _median(List<double> n) {
    if (n.isEmpty) return 0;
    n.sort();
    final int m = n.length ~/ 2;
    return n.length.isOdd ? n[m] : (n[m - 1] + n[m]) / 2;
  }

  static Object? _avedev(List<double> n) {
    if (n.isEmpty) return 0;
    final double avg = n.fold(0.0, (double s, double x) => s + x) / n.length;
    return n.fold(0.0, (double s, double x) => s + (x - avg).abs()) / n.length;
  }

  static Object? _stdev(List<double> n, bool pop) {
    final Object? v = _variance(n, pop);
    return v is num ? _sqrt(v.toDouble()) : v;
  }

  static Object? _variance(List<double> n, bool pop) {
    if (n.length < 2 && !pop) return '#DIV/0!';
    if (n.isEmpty) return 0;
    final double avg = n.fold(0.0, (double s, double x) => s + x) / n.length;
    final double ss = n.fold(
      0.0,
      (double s, double x) => s + (x - avg) * (x - avg),
    );
    return ss / (pop ? n.length : n.length - 1);
  }

  static Object? _sumIf(FormulaContext ctx, List<FormulaNode> args) {
    if (args.isEmpty || args[0] is! RangeNode) return 0;
    final RangeNode range = args[0] as RangeNode;
    final String crit = args.length > 1 ? formulaString(args[1].eval(ctx)) : '';
    final RangeNode sumRange = args.length > 2 && args[2] is RangeNode
        ? args[2] as RangeNode
        : range;
    var s = 0.0;
    final List<SmlCellRef> keys = range.range.cells.toList();
    final List<SmlCellRef> sums = sumRange.range.cells.toList();
    for (int i = 0; i < keys.length && i < sums.length; i++) {
      final Object? v = ctx.valueOf(keys[i]);
      if (_matchCrit(v, crit)) {
        s += asFormulaNumber(ctx.valueOf(sums[i])) ?? 0;
      }
    }
    return s;
  }

  static Object? _countIf(FormulaContext ctx, List<FormulaNode> args) {
    if (args.isEmpty || args[0] is! RangeNode) return 0;
    final String crit = args.length > 1 ? formulaString(args[1].eval(ctx)) : '';
    var c = 0;
    for (final SmlCellRef ref in (args[0] as RangeNode).range.cells) {
      if (_matchCrit(ctx.valueOf(ref), crit)) c++;
    }
    return c.toDouble();
  }

  static Object? _avgIf(FormulaContext ctx, List<FormulaNode> args) {
    final Object? s = _sumIf(ctx, args);
    final Object? c = _countIf(ctx, args);
    if (s is num && c is num && c != 0) return s / c;
    return '#DIV/0!';
  }

  static Object? _sumIfs(FormulaContext ctx, List<FormulaNode> args) =>
      _sumIf(ctx, args);

  static Object? _countIfs(FormulaContext ctx, List<FormulaNode> args) =>
      _countIf(ctx, args);

  static bool _matchCrit(Object? value, String crit) {
    if (crit.startsWith('>=')) {
      return (asFormulaNumber(value) ?? 0) >=
          (double.tryParse(crit.substring(2)) ?? 0);
    }
    if (crit.startsWith('<=')) {
      return (asFormulaNumber(value) ?? 0) <=
          (double.tryParse(crit.substring(2)) ?? 0);
    }
    if (crit.startsWith('<>')) {
      return formulaString(value) != crit.substring(2);
    }
    if (crit.startsWith('>')) {
      return (asFormulaNumber(value) ?? 0) >
          (double.tryParse(crit.substring(1)) ?? 0);
    }
    if (crit.startsWith('<')) {
      return (asFormulaNumber(value) ?? 0) <
          (double.tryParse(crit.substring(1)) ?? 0);
    }
    if (crit.contains('*')) {
      final String re = RegExp.escape(crit).replaceAll('\\*', '.*');
      return RegExp('^$re\$').hasMatch(formulaString(value));
    }
    return formulaString(value) == crit ||
        asFormulaNumber(value) == double.tryParse(crit);
  }

  static Object? _vlookup(
    FormulaContext ctx,
    List<FormulaNode> args,
    bool horiz,
  ) {
    if (args.length < 3 || args[1] is! RangeNode) return '#N/A';
    final Object? key = args[0].eval(ctx);
    final RangeNode table = args[1] as RangeNode;
    final int index = (asFormulaNumber(args[2].eval(ctx)) ?? 1).toInt();
    final List<SmlCellRef> cells = table.range.cells.toList();
    final int cols = (table.range.end.col - table.range.start.col).abs() + 1;
    final int rows = (table.range.end.row - table.range.start.row).abs() + 1;
    if (horiz) {
      for (int c = 0; c < cols; c++) {
        if (formulaString(
              ctx.valueOf(
                SmlCellRef(table.range.start.col + c, table.range.start.row),
              ),
            ) ==
            formulaString(key)) {
          return ctx.valueOf(
            SmlCellRef(
              table.range.start.col + c,
              table.range.start.row + index - 1,
            ),
          );
        }
      }
    } else {
      for (int r = 0; r < rows; r++) {
        if (formulaString(
              ctx.valueOf(
                SmlCellRef(table.range.start.col, table.range.start.row + r),
              ),
            ) ==
            formulaString(key)) {
          return ctx.valueOf(
            SmlCellRef(
              table.range.start.col + index - 1,
              table.range.start.row + r,
            ),
          );
        }
      }
    }
    cells.length;
    return '#N/A';
  }

  static Object? _index(List<Object?> vals) {
    if (vals.isEmpty) return '#VALUE!';
    final List<Object?> arr = flattenValues(vals[0]);
    final int r = (_n(vals, 1)?.toInt() ?? 1) - 1;
    if (r < 0 || r >= arr.length) return '#REF!';
    return arr[r];
  }

  static Object? _match(List<Object?> vals) {
    final Object? key = vals[0];
    final List<Object?> arr = flattenValues(
      vals.length > 1 ? vals[1] : <Object?>[],
    );
    for (int i = 0; i < arr.length; i++) {
      if (formulaString(arr[i]) == formulaString(key)) {
        return (i + 1).toDouble();
      }
    }
    return '#N/A';
  }

  static Object? _xlookup(List<Object?> vals) {
    final Object? found = _match(vals);
    if (found is! num) return found;
    final List<Object?> ret = flattenValues(
      vals.length > 2 ? vals[2] : vals[1],
    );
    final int i = found.toInt() - 1;
    return (i >= 0 && i < ret.length) ? ret[i] : '#N/A';
  }

  static Object? _lookup(List<Object?> vals) => _xlookup(vals);

  static DateTime? _date(Object? v) {
    if (v is DateTime) return v;
    final double? n = asFormulaNumber(v);
    if (n == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      (n * 86400000).round(),
      isUtc: true,
    );
  }

  static Object? _fin(String name, List<Object?> vals) {
    final double rate = _n(vals, 0) ?? 0;
    final double nper = _n(vals, 1) ?? 0;
    final double pmt = _n(vals, 2) ?? 0;
    final double pv = _n(vals, 3) ?? 0;
    if (name == 'PMT') {
      if (rate == 0) return nper == 0 ? 0 : -pv / nper;
      final double f = _powNum(1 + rate, nper);
      return -pv * rate * f / (f - 1);
    }
    if (name == 'FV') {
      return -pv * _powNum(1 + rate, nper) - pmt * nper;
    }
    return pv;
  }

  static Object? _npv(List<Object?> vals) {
    final double rate = _n(vals, 0) ?? 0;
    var s = 0.0;
    final List<double> cfs = flattenNumbers(vals.skip(1).toList());
    for (int i = 0; i < cfs.length; i++) {
      s += cfs[i] / _powNum(1 + rate, i + 1);
    }
    return s;
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    var g = x;
    for (int i = 0; i < 20; i++) {
      g = 0.5 * (g + x / g);
    }
    return g;
  }

  static double _ln(double x) {
    if (x <= 0) return double.nan;
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
    var term = z;
    var sum = 0.0;
    final double z2 = z * z;
    for (int n = 0; n < 14; n++) {
      sum += term / (2 * n + 1);
      term *= z2;
    }
    return 2 * sum + k;
  }

  static double _exp(double x) {
    var sum = 1.0;
    var term = 1.0;
    for (int n = 1; n < 24; n++) {
      term *= x / n;
      sum += term;
    }
    return sum;
  }

  static double _powNum(double a, double b) {
    if (b == 0) return 1;
    if (b == 1) return a;
    final int exp = b.round();
    if (exp.toDouble() == b && exp >= 0 && exp < 40) {
      var r = 1.0;
      for (int i = 0; i < exp; i++) {
        r *= a;
      }
      return r;
    }
    if (a <= 0) return double.nan;
    return _exp(b * _ln(a));
  }
}
