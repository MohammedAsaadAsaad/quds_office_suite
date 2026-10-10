/// Chart data model and vector rendering for report charts.
///
/// The renderer emits ordinary layout primitives (rectangles, lines, paths,
/// shaped text), so PDF export and the Flutter preview draw charts with no
/// chart-specific code, and Arabic labels shape like any other report text.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../builders/drawingml_charts.dart';
import '../builders/office_markup.dart';
import '../visual/office_visual.dart';
import 'report_fonts.dart';
import 'report_format.dart';
import 'report_layout.dart';
import 'report_template.dart';
import 'report_units.dart';
import 'report_value.dart';

/// One resolved series: a value per category.
class ReportChartSeriesData {
  /// ReportChartSeriesData API.
  const ReportChartSeriesData({
    required this.name,
    required this.color,
    required this.values,
  });

  /// Legend label (may be empty for single-series charts).
  final String name;

  /// color API.
  final ReportColor color;

  /// Same length as [ReportChartData.categories].
  final List<double> values;
}

/// Aggregated chart content ready to draw or export.
class ReportChartData {
  /// ReportChartData API.
  const ReportChartData({
    required this.type,
    required this.title,
    required this.categories,
    required this.series,
    required this.pointColors,
    required this.rtl,
    this.varyColors = false,
    this.showLegend = true,
    this.showValues = false,
    this.showGrid = true,
    this.showAxes = true,
    this.valueFormat,
  });

  /// type API.
  final ReportChartType type;

  /// Evaluated title.
  final String title;

  /// Category labels in plot order.
  final List<String> categories;

  /// series API.
  final List<ReportChartSeriesData> series;

  /// Per-category colors (pie slices; bars when [varyColors]).
  final List<ReportColor> pointColors;

  /// Mirror the plot (first category on the right, value axis on the right).
  final bool rtl;

  /// Color single-series bars per category.
  final bool varyColors;

  /// showLegend API.
  final bool showLegend;

  /// showValues API.
  final bool showValues;

  /// showGrid API.
  final bool showGrid;

  /// showAxes API.
  final bool showAxes;

  /// Format spec for value labels.
  final String? valueFormat;

  /// Pie or donut.
  bool get isRadial =>
      type == ReportChartType.pie || type == ReportChartType.donut;

  /// True when there is nothing to plot.
  bool get isEmpty => categories.isEmpty || series.isEmpty;

  /// Legend entries exist (radial categories or named / multiple series).
  bool get hasLegendEntries =>
      isRadial || series.length > 1 || series.first.name.isNotEmpty;

  /// Native DrawingML `c:chartSpace` part with literal data (Word, Excel).
  String toDrawingml() {
    final ChartDisplay display = ChartDisplay(
      showLegend: showLegend && !isEmpty && hasLegendEntries,
      showDataLabels: showValues,
      showAxes: showAxes,
      showGridlines: showGrid,
      showTitle: title.isNotEmpty,
      rtl: rtl,
    );
    String label(int i) =>
        categories[i].trim().isEmpty ? '${i + 1}' : categories[i];
    final bool horizontal = type == ReportChartType.horizontalBar;
    if (isEmpty) {
      return DrawingmlCharts.multiSeries(
        title: title,
        series: const <ChartSeries>[],
        rtl: rtl,
        kind: ChartKind.bar,
        display: display,
      );
    }
    if (isRadial || (varyColors && series.length == 1)) {
      final ReportChartSeriesData s = series.first;
      return DrawingmlCharts.singleSeries(
        title: title,
        points: <ChartPoint>[
          for (int i = 0; i < categories.length; i++)
            ChartPoint(
              label: label(i),
              value: s.values[i],
              color: pointColors[i % pointColors.length].hex,
            ),
        ],
        rtl: rtl,
        kind: switch (type) {
          ReportChartType.pie => ChartKind.pie,
          ReportChartType.donut => ChartKind.donut,
          ReportChartType.line => ChartKind.line,
          ReportChartType.area => ChartKind.area,
          ReportChartType.stackedBar => ChartKind.stackedBar,
          ReportChartType.bar || ReportChartType.horizontalBar => ChartKind.bar,
        },
        horizontal: horizontal,
        titleColor: '404040',
        display: display,
      );
    }
    return DrawingmlCharts.multiSeries(
      title: title,
      series: <ChartSeries>[
        for (final ReportChartSeriesData s in series)
          ChartSeries(
            name: s.name,
            color: s.color.hex,
            points: <ChartPoint>[
              for (int i = 0; i < categories.length; i++)
                ChartPoint(label: label(i), value: s.values[i]),
            ],
          ),
      ],
      rtl: rtl,
      kind: switch (type) {
        ReportChartType.line => ChartKind.line,
        ReportChartType.area => ChartKind.area,
        ReportChartType.stackedBar => ChartKind.stackedBar,
        ReportChartType.pie => ChartKind.pie,
        ReportChartType.donut => ChartKind.donut,
        ReportChartType.bar || ReportChartType.horizontalBar => ChartKind.bar,
      },
      horizontal: horizontal,
      markers: type == ReportChartType.line,
      titleColor: '404040',
      display: display,
    );
  }
}

/// Turns [ReportChartData] into page primitives inside a box.
class ReportChartRenderer {
  /// ReportChartRenderer API.
  ReportChartRenderer({required this.shaper, required this.formatter});

  /// shaper API.
  final ReportTextShaper shaper;

  /// Formats value labels and axis ticks (digits, separators).
  final ReportFormatter formatter;

  static const ReportColor _gridColor = ReportColor(0xFFE3E6EA);
  static const ReportColor _axisColor = ReportColor(0xFF9AA0A6);
  static const ReportColor _tickColor = ReportColor(0xFF6B7280);
  static const double _pad = 4;

  late List<ReportPrimitive> _out;
  late ReportFontSpec _font;
  late ReportColor _textColor;
  String? _elementId;
  ReportBandKind? _band;

  /// Primitives drawing [data] inside [box].
  List<ReportPrimitive> render(
    ReportChartData data,
    ReportRect box, {
    required ReportFontSpec font,
    required ReportColor textColor,
    String? elementId,
    ReportBandKind? band,
  }) {
    _out = <ReportPrimitive>[];
    _font = font;
    _textColor = textColor;
    _elementId = elementId;
    _band = band;
    var area = ReportRect(
      box.left + _pad,
      box.top + _pad,
      box.width - 2 * _pad,
      box.height - 2 * _pad,
    );
    if (area.width <= 4 || area.height <= 4) {
      return _out;
    }
    if (data.title.isNotEmpty) {
      final ReportFontSpec tf = ReportFontSpec(
        family: font.family,
        size: font.size * 1.3,
        bold: true,
      );
      final double h = shaper.lineHeight(tf);
      _label(
        data.title,
        tf,
        ReportRect(area.left, area.top, area.width, h),
        ReportTextAlign.center,
        textColor,
      );
      area = ReportRect(
        area.left,
        area.top + h + 3,
        area.width,
        area.height - h - 3,
      );
    }
    if (!data.isEmpty && area.height > 8) {
      area = _legend(data, area);
      if (data.isRadial) {
        _radial(data, area);
      } else if (data.type == ReportChartType.horizontalBar) {
        _horizontal(data, area);
      } else {
        _vertical(data, area);
      }
    }
    if (!data.rtl) {
      return _out;
    }
    final double axis = box.left + box.right;
    return <ReportPrimitive>[
      for (final ReportPrimitive p in _out) _mirror(p, axis),
    ];
  }

  // ------------------------------------------------------------ legend

  ReportRect _legend(ReportChartData d, ReportRect area) {
    final List<(String, ReportColor)> entries = <(String, ReportColor)>[
      if (d.isRadial)
        for (int i = 0; i < d.categories.length; i++)
          (d.categories[i], d.pointColors[i % d.pointColors.length])
      else if (d.series.length > 1 || d.series.first.name.isNotEmpty)
        for (final ReportChartSeriesData s in d.series) (s.name, s.color),
    ];
    if (!d.showLegend || entries.isEmpty) {
      return area;
    }
    final double lh = shaper.lineHeight(_font);
    final double sw = _font.size * 0.8;
    final List<double> widths = <double>[
      for (final (String, ReportColor) e in entries)
        sw + 3 + _width(e.$1, _font),
    ];
    if (d.isRadial) {
      var maxW = 0.0;
      for (final double w in widths) {
        maxW = math.max(maxW, w);
      }
      final double legendW = math.min(maxW, area.width * 0.42);
      final int fit = math.max(1, (area.height / (lh + 1)).floor());
      final int count = math.min(fit, entries.length);
      final double total = count * (lh + 1);
      var y = area.top + (area.height - total) / 2;
      final double x = area.right - legendW;
      for (int i = 0; i < count; i++) {
        _swatch(x, y + (lh - sw) / 2, sw, entries[i].$2);
        _label(
          entries[i].$1,
          _font,
          ReportRect(x + sw + 3, y, legendW - sw - 3, lh),
          ReportTextAlign.left,
          _textColor,
        );
        y += lh + 1;
      }
      return ReportRect(
        area.left,
        area.top,
        area.width - legendW - 6,
        area.height,
      );
    }
    final List<List<int>> rows = <List<int>>[<int>[]];
    var rowW = 0.0;
    for (int i = 0; i < entries.length; i++) {
      final double w = math.min(widths[i], area.width);
      if (rows.last.isNotEmpty && rowW + 10 + w > area.width) {
        rows.add(<int>[]);
        rowW = 0;
      }
      rowW += (rows.last.isEmpty ? 0 : 10) + w;
      rows.last.add(i);
    }
    final double legendH = rows.length * lh;
    if (legendH > area.height * 0.4) {
      return area;
    }
    var y = area.bottom - legendH;
    for (final List<int> row in rows) {
      var total = 0.0;
      for (final int i in row) {
        total += math.min(widths[i], area.width);
      }
      total += (row.length - 1) * 10;
      var x = area.left + (area.width - total) / 2;
      for (final int i in row) {
        final double w = math.min(widths[i], area.width);
        _swatch(x, y + (lh - sw) / 2, sw, entries[i].$2);
        _label(
          entries[i].$1,
          _font,
          ReportRect(x + sw + 3, y, w - sw - 3, lh),
          ReportTextAlign.left,
          _textColor,
        );
        x += w + 10;
      }
      y += lh;
    }
    return ReportRect(
      area.left,
      area.top,
      area.width,
      area.height - legendH - 3,
    );
  }

  void _swatch(double x, double y, double size, ReportColor color) {
    _out.add(
      ReportRectPrimitive(
        bounds: ReportRect(x, y, size, size),
        elementId: _elementId,
        band: _band,
        fill: color,
        radius: size * 0.2,
      ),
    );
  }

  // ------------------------------------------------------------ cartesian

  ({double lo, double hi}) _range(ReportChartData d) {
    var lo = 0.0;
    var hi = 0.0;
    if (d.type == ReportChartType.stackedBar) {
      for (int i = 0; i < d.categories.length; i++) {
        var pos = 0.0;
        var neg = 0.0;
        for (final ReportChartSeriesData s in d.series) {
          final double v = s.values[i];
          if (v >= 0) {
            pos += v;
          } else {
            neg += v;
          }
        }
        hi = math.max(hi, pos);
        lo = math.min(lo, neg);
      }
    } else {
      for (final ReportChartSeriesData s in d.series) {
        for (final double v in s.values) {
          hi = math.max(hi, v);
          lo = math.min(lo, v);
        }
      }
    }
    if (hi - lo < 1e-9) {
      hi = lo + 1;
    }
    return (lo: lo, hi: hi);
  }

  /// Rounded axis bounds and tick step for about [ticks] intervals.
  static ({double lo, double hi, double step}) niceScale(
    double min,
    double max,
    int ticks,
  ) {
    final double rough = (max - min) / ticks;
    final double mag = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    final double norm = rough / mag;
    final double unit = norm <= 1
        ? 1
        : norm <= 2
        ? 2
        : norm <= 2.5
        ? 2.5
        : norm <= 5
        ? 5
        : 10;
    final double step = unit * mag;
    final double lo = (min / step).floor() * step;
    final double hi = (max / step).ceil() * step;
    return (lo: lo, hi: hi <= lo ? lo + step : hi, step: step);
  }

  String _tick(double v, double step) {
    final double a = step.abs();
    if (a >= 1e6) {
      return '${_number(v / 1e6, _decimals(step / 1e6))}M';
    }
    if (a >= 1e3) {
      return '${_number(v / 1e3, _decimals(step / 1e3))}K';
    }
    return _number(v, _decimals(step));
  }

  static int _decimals(double step) {
    for (int d = 0; d < 4; d++) {
      final double scaled = step * math.pow(10, d);
      if ((scaled - scaled.roundToDouble()).abs() < 1e-6) {
        return d;
      }
    }
    return 4;
  }

  String _number(double v, int decimals) =>
      formatter.format(ReportNumber(v), 'n$decimals');

  /// Value label text.
  String formatValue(double v, String? spec) {
    if (spec != null && spec.trim().isNotEmpty) {
      return formatter.format(ReportNumber(v), spec);
    }
    return _number(v, v == v.roundToDouble() ? 0 : 2);
  }

  void _vertical(ReportChartData d, ReportRect area) {
    final ({double lo, double hi}) r = _range(d);
    final ({double lo, double hi, double step}) s = niceScale(r.lo, r.hi, 5);
    final double lh = shaper.lineHeight(_font);
    final ReportFontSpec small = _smaller(_font);
    final double slh = shaper.lineHeight(small);
    final List<double> ticks = <double>[
      for (double v = s.lo; v <= s.hi + s.step * 1e-6; v += s.step) v,
    ];
    var axisW = 0.0;
    if (d.showAxes) {
      for (final double v in ticks) {
        axisW = math.max(axisW, _width(_tick(v, s.step), small));
      }
      axisW += 4;
    }
    final double top = area.top + (d.showValues ? slh : slh / 2);
    final double bottom = area.bottom - (d.showAxes ? lh + 2 : 0);
    final ReportRect plot = ReportRect(
      area.left + axisW,
      top,
      area.width - axisW,
      bottom - top,
    );
    if (plot.width <= 4 || plot.height <= 4) {
      return;
    }
    double y(double v) =>
        plot.bottom - (v - s.lo) / (s.hi - s.lo) * plot.height;
    for (final double v in ticks) {
      final double ty = y(v);
      if (d.showGrid) {
        _line(plot.left, ty, plot.right, ty, _gridColor, 0.4);
      }
      if (d.showAxes) {
        _label(
          _tick(v, s.step),
          small,
          ReportRect(area.left, ty - slh / 2, axisW - 3, slh),
          ReportTextAlign.right,
          _tickColor,
        );
      }
    }
    final int n = d.categories.length;
    final double slot = plot.width / n;
    final double zero = y(s.lo > 0 ? s.lo : (s.hi < 0 ? s.hi : 0));
    switch (d.type) {
      case ReportChartType.line:
      case ReportChartType.area:
        _lines(d, plot, slot, y, zero, small, slh);
      case ReportChartType.stackedBar:
        _stacked(d, plot, slot, y, small, slh);
      case ReportChartType.bar:
      case ReportChartType.horizontalBar:
      case ReportChartType.pie:
      case ReportChartType.donut:
        _bars(d, plot, slot, y, zero, small, slh);
    }
    if (d.showAxes) {
      _line(plot.left, plot.top, plot.left, plot.bottom, _axisColor, 0.6);
      _line(plot.left, zero, plot.right, zero, _axisColor, 0.6);
      var widest = 0.0;
      for (final String c in d.categories) {
        widest = math.max(widest, _width(c, _font));
      }
      final int every = math.max(1, (widest / (slot * 0.95)).ceil());
      for (int i = 0; i < n; i += every) {
        _label(
          d.categories[i],
          _font,
          ReportRect(
            plot.left + i * slot - (every - 1) * slot / 2,
            plot.bottom + 2,
            slot * every,
            lh,
          ),
          ReportTextAlign.center,
          _textColor,
        );
      }
    }
  }

  void _bars(
    ReportChartData d,
    ReportRect plot,
    double slot,
    double Function(double) y,
    double zero,
    ReportFontSpec small,
    double slh,
  ) {
    final int m = d.series.length;
    final double group = slot * (m == 1 ? 0.6 : 0.78);
    final double bw = group / m;
    for (int si = 0; si < m; si++) {
      final ReportChartSeriesData s = d.series[si];
      for (int i = 0; i < d.categories.length; i++) {
        final double v = s.values[i];
        final double x = plot.left + i * slot + (slot - group) / 2 + si * bw;
        final double vy = y(v);
        final double top = math.min(vy, zero);
        final double h = (vy - zero).abs();
        final ReportColor color = d.varyColors && m == 1
            ? d.pointColors[i % d.pointColors.length]
            : s.color;
        if (h > 0.01) {
          _out.add(
            ReportRectPrimitive(
              bounds: ReportRect(x + bw * 0.06, top, bw * 0.88, h),
              elementId: _elementId,
              band: _band,
              fill: color,
            ),
          );
        }
        if (d.showValues) {
          final double lw = m == 1 ? slot : bw * 1.8;
          _label(
            formatValue(v, d.valueFormat),
            small,
            ReportRect(x + bw / 2 - lw / 2, v >= 0 ? vy - slh : vy, lw, slh),
            ReportTextAlign.center,
            _textColor,
          );
        }
      }
    }
  }

  void _stacked(
    ReportChartData d,
    ReportRect plot,
    double slot,
    double Function(double) y,
    ReportFontSpec small,
    double slh,
  ) {
    final double bw = slot * 0.6;
    for (int i = 0; i < d.categories.length; i++) {
      final double x = plot.left + i * slot + (slot - bw) / 2;
      var pos = 0.0;
      var neg = 0.0;
      for (final ReportChartSeriesData s in d.series) {
        final double v = s.values[i];
        final double from = v >= 0 ? pos : neg;
        final double to = from + v;
        if (v >= 0) {
          pos = to;
        } else {
          neg = to;
        }
        final double y1 = y(from);
        final double y2 = y(to);
        final double top = math.min(y1, y2);
        final double h = (y1 - y2).abs();
        if (h <= 0.01) {
          continue;
        }
        _out.add(
          ReportRectPrimitive(
            bounds: ReportRect(x, top, bw, h),
            elementId: _elementId,
            band: _band,
            fill: s.color,
            stroke: ReportColor.white,
            strokeWidth: 0.4,
          ),
        );
        if (d.showValues && h >= slh) {
          _label(
            formatValue(v, d.valueFormat),
            small,
            ReportRect(x, top + (h - slh) / 2, bw, slh),
            ReportTextAlign.center,
            _contrast(s.color),
          );
        }
      }
    }
  }

  void _lines(
    ReportChartData d,
    ReportRect plot,
    double slot,
    double Function(double) y,
    double zero,
    ReportFontSpec small,
    double slh,
  ) {
    final int n = d.categories.length;
    final bool area = d.type == ReportChartType.area;
    for (final ReportChartSeriesData s in d.series) {
      final Float64List line = Float64List(n * 2);
      for (int i = 0; i < n; i++) {
        line[i * 2] = plot.left + (i + 0.5) * slot;
        line[i * 2 + 1] = y(s.values[i]);
      }
      if (area && n > 1) {
        final Float64List poly = Float64List(n * 2 + 4)
          ..setRange(0, n * 2, line);
        poly[n * 2] = line[n * 2 - 2];
        poly[n * 2 + 1] = zero;
        poly[n * 2 + 2] = line[0];
        poly[n * 2 + 3] = zero;
        _out.add(
          ReportPathPrimitive.through(
            poly,
            elementId: _elementId,
            band: _band,
            closed: true,
            fill: _tint(s.color, 0.55),
          ),
        );
      }
      if (n > 1) {
        _out.add(
          ReportPathPrimitive.through(
            line,
            elementId: _elementId,
            band: _band,
            stroke: s.color,
            strokeWidth: 1.6,
          ),
        );
      }
      if (!area || n == 1) {
        final double r = math.min(2.4, slot / 4);
        for (int i = 0; i < n; i++) {
          _out.add(
            ReportRectPrimitive(
              bounds: ReportRect(
                line[i * 2] - r,
                line[i * 2 + 1] - r,
                r * 2,
                r * 2,
              ),
              elementId: _elementId,
              band: _band,
              fill: s.color,
              stroke: ReportColor.white,
              strokeWidth: 0.6,
              ellipse: true,
            ),
          );
        }
      }
      if (d.showValues) {
        for (int i = 0; i < n; i++) {
          _label(
            formatValue(s.values[i], d.valueFormat),
            small,
            ReportRect(
              line[i * 2] - slot / 2,
              line[i * 2 + 1] - slh - 2,
              slot,
              slh,
            ),
            ReportTextAlign.center,
            _textColor,
          );
        }
      }
    }
  }

  void _horizontal(ReportChartData d, ReportRect area) {
    final ({double lo, double hi}) r = _range(d);
    final ({double lo, double hi, double step}) s = niceScale(r.lo, r.hi, 4);
    final double lh = shaper.lineHeight(_font);
    final ReportFontSpec small = _smaller(_font);
    final double slh = shaper.lineHeight(small);
    var catW = 0.0;
    if (d.showAxes) {
      for (final String c in d.categories) {
        catW = math.max(catW, _width(c, _font));
      }
      catW = math.min(catW + 4, area.width * 0.35);
    }
    var valueW = 0.0;
    if (d.showValues) {
      for (final ReportChartSeriesData sd in d.series) {
        for (final double v in sd.values) {
          valueW = math.max(
            valueW,
            _width(formatValue(v, d.valueFormat), small),
          );
        }
      }
      valueW += 3;
    }
    final double bottom = area.bottom - (d.showAxes ? slh + 2 : 0);
    final ReportRect plot = ReportRect(
      area.left + catW,
      area.top + 2,
      area.width - catW - valueW - 4,
      bottom - area.top - 2,
    );
    if (plot.width <= 4 || plot.height <= 4) {
      return;
    }
    double x(double v) => plot.left + (v - s.lo) / (s.hi - s.lo) * plot.width;
    for (double v = s.lo; v <= s.hi + s.step * 1e-6; v += s.step) {
      final double tx = x(v);
      if (d.showGrid) {
        _line(tx, plot.top, tx, plot.bottom, _gridColor, 0.4);
      }
      if (d.showAxes) {
        final double tw = plot.width / 4;
        _label(
          _tick(v, s.step),
          small,
          ReportRect(tx - tw / 2, plot.bottom + 2, tw, slh),
          ReportTextAlign.center,
          _tickColor,
        );
      }
    }
    final int n = d.categories.length;
    final int m = d.series.length;
    final double slot = plot.height / n;
    final double group = slot * (m == 1 ? 0.62 : 0.8);
    final double bh = group / m;
    final double zero = x(s.lo > 0 ? s.lo : (s.hi < 0 ? s.hi : 0));
    for (int i = 0; i < n; i++) {
      final double rowTop = plot.top + i * slot;
      if (d.showAxes) {
        _label(
          d.categories[i],
          _font,
          ReportRect(area.left, rowTop + (slot - lh) / 2, catW - 4, lh),
          ReportTextAlign.right,
          _textColor,
        );
      }
      for (int si = 0; si < m; si++) {
        final double v = d.series[si].values[i];
        final double vx = x(v);
        final double top = rowTop + (slot - group) / 2 + si * bh;
        final ReportColor color = d.varyColors && m == 1
            ? d.pointColors[i % d.pointColors.length]
            : d.series[si].color;
        final double left = math.min(vx, zero);
        final double w = (vx - zero).abs();
        if (w > 0.01) {
          _out.add(
            ReportRectPrimitive(
              bounds: ReportRect(left, top + bh * 0.06, w, bh * 0.88),
              elementId: _elementId,
              band: _band,
              fill: color,
            ),
          );
        }
        if (d.showValues) {
          _label(
            formatValue(v, d.valueFormat),
            small,
            ReportRect(
              v >= 0 ? vx + 2 : vx - valueW - 2,
              top + (bh - slh) / 2,
              valueW,
              slh,
            ),
            v >= 0 ? ReportTextAlign.left : ReportTextAlign.right,
            _textColor,
          );
        }
      }
    }
    if (d.showAxes) {
      _line(zero, plot.top, zero, plot.bottom, _axisColor, 0.6);
      _line(plot.left, plot.bottom, plot.right, plot.bottom, _axisColor, 0.6);
    }
  }

  // ------------------------------------------------------------ radial

  void _radial(ReportChartData d, ReportRect area) {
    final List<double> values = d.series.first.values;
    var total = 0.0;
    for (final double v in values) {
      if (v > 0) {
        total += v;
      }
    }
    final double radius = math.min(area.width, area.height) / 2 - 1;
    if (total <= 0 || radius <= 4) {
      return;
    }
    final double cx = area.left + area.width / 2;
    final double cy = area.top + area.height / 2;
    final bool donut = d.type == ReportChartType.donut;
    final double inner = donut ? radius * 0.56 : 0;
    final ReportFontSpec bold = ReportFontSpec(
      family: _font.family,
      size: _font.size,
      bold: true,
    );
    final double lh = shaper.lineHeight(bold);
    var start = -math.pi / 2;
    final int positive = values.where((double v) => v > 0).length;
    for (int i = 0; i < values.length; i++) {
      final double v = values[i];
      if (v <= 0) {
        continue;
      }
      final double sweep = v / total * 2 * math.pi;
      final ReportColor color = d.pointColors[i % d.pointColors.length];
      _out.add(
        ReportPathPrimitive.through(
          wedge(cx, cy, radius, inner, start, sweep),
          elementId: _elementId,
          band: _band,
          closed: true,
          fill: color,
          stroke: positive > 1 ? ReportColor.white : null,
          strokeWidth: positive > 1 ? 0.8 : 0,
        ),
      );
      if (d.showValues && sweep >= 0.32) {
        final double mid = start + sweep / 2;
        final double lr = donut ? (radius + inner) / 2 : radius * 0.64;
        final double lx = cx + math.cos(mid) * lr;
        final double ly = cy + math.sin(mid) * lr;
        final String text = d.valueFormat == null
            ? formatter.format(ReportNumber(v / total), 'percent')
            : formatValue(v, d.valueFormat);
        final double w = radius * 0.9;
        _label(
          text,
          bold,
          ReportRect(lx - w / 2, ly - lh / 2, w, lh),
          ReportTextAlign.center,
          _contrast(color),
        );
      }
      start += sweep;
    }
    if (donut) {
      final ReportFontSpec big = ReportFontSpec(
        family: _font.family,
        size: _font.size * 1.35,
        bold: true,
      );
      final String text = formatValue(total, d.valueFormat);
      if (_width(text, big) < inner * 1.7) {
        final double h = shaper.lineHeight(big);
        _label(
          text,
          big,
          ReportRect(cx - inner, cy - h / 2, inner * 2, h),
          ReportTextAlign.center,
          _textColor,
        );
      }
    }
  }

  /// Polygon of a pie wedge (or a ring segment when [inner] > 0), with
  /// arcs flattened to segments of at most 3°.
  static Float64List wedge(
    double cx,
    double cy,
    double radius,
    double inner,
    double start,
    double sweep,
  ) {
    final int steps = math.max(2, (sweep / (math.pi / 60)).ceil());
    final bool ring = inner > 0;
    final int count = steps + 1 + (ring ? steps + 1 : 1);
    final Float64List pts = Float64List(count * 2);
    var k = 0;
    for (int i = 0; i <= steps; i++) {
      final double a = start + sweep * i / steps;
      pts[k++] = cx + math.cos(a) * radius;
      pts[k++] = cy + math.sin(a) * radius;
    }
    if (ring) {
      for (int i = steps; i >= 0; i--) {
        final double a = start + sweep * i / steps;
        pts[k++] = cx + math.cos(a) * inner;
        pts[k++] = cy + math.sin(a) * inner;
      }
    } else {
      pts[k++] = cx;
      pts[k++] = cy;
    }
    return pts;
  }

  // ------------------------------------------------------------ helpers

  static ReportFontSpec _smaller(ReportFontSpec f) => ReportFontSpec(
    family: f.family,
    size: f.size * 0.88,
    bold: f.bold,
    italic: f.italic,
  );

  /// Opaque mix of [c] toward white by [amount] (PDF paints alpha opaque).
  static ReportColor _tint(ReportColor c, double amount) {
    int mix(int v) => (v + (255 - v) * amount).round().clamp(0, 255);
    return ReportColor.rgb(mix(c.red), mix(c.green), mix(c.blue));
  }

  static ReportColor _contrast(ReportColor c) {
    final double lum = 0.299 * c.red + 0.587 * c.green + 0.114 * c.blue;
    return lum > 160 ? const ReportColor(0xFF202124) : ReportColor.white;
  }

  /// True when [text] holds right-to-left letters.
  static bool hasRtl(String text) {
    for (final int cp in text.runes) {
      if ((cp >= 0x0590 && cp <= 0x08FF) || (cp >= 0xFB1D && cp <= 0xFEFC)) {
        return true;
      }
    }
    return false;
  }

  double _width(String text, ReportFontSpec f) => text.isEmpty
      ? 0
      : shaper
            .shape(text, f, maxWidth: 1e6, rtl: hasRtl(text), wrap: false)
            .maxLineWidth;

  void _line(
    double x1,
    double y1,
    double x2,
    double y2,
    ReportColor color,
    double width,
  ) {
    _out.add(
      ReportLinePrimitive(
        bounds: ReportRect(
          math.min(x1, x2),
          math.min(y1, y2),
          (x2 - x1).abs(),
          (y2 - y1).abs(),
        ),
        elementId: _elementId,
        band: _band,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        color: color,
        width: width,
      ),
    );
  }

  void _label(
    String text,
    ReportFontSpec font,
    ReportRect r,
    ReportTextAlign align,
    ReportColor color,
  ) {
    if (text.isEmpty || r.width <= 0) {
      return;
    }
    final bool rtl = hasRtl(text);
    _out.add(
      ReportTextPrimitive(
        bounds: r,
        elementId: _elementId,
        band: _band,
        text: text,
        shaped: shaper.shape(
          text,
          font,
          maxWidth: r.width,
          rtl: rtl,
          wrap: false,
        ),
        contentRect: r,
        font: font,
        color: color,
        align: align,
        verticalAlign: ReportVerticalAlign.middle,
        rtl: rtl,
      ),
    );
  }

  static ReportRect _flip(ReportRect r, double axis) =>
      ReportRect(axis - r.right, r.top, r.width, r.height);

  static ReportPrimitive _mirror(ReportPrimitive p, double axis) {
    return switch (p) {
      ReportTextPrimitive() => ReportTextPrimitive(
        bounds: _flip(p.bounds, axis),
        elementId: p.elementId,
        band: p.band,
        text: p.text,
        shaped: p.shaped,
        contentRect: _flip(p.contentRect, axis),
        font: p.font,
        color: p.color,
        align: switch (p.align) {
          ReportTextAlign.left => ReportTextAlign.right,
          ReportTextAlign.right => ReportTextAlign.left,
          _ => p.align,
        },
        verticalAlign: p.verticalAlign,
        rtl: p.rtl,
        underline: p.underline,
      ),
      ReportRectPrimitive() => ReportRectPrimitive(
        bounds: _flip(p.bounds, axis),
        elementId: p.elementId,
        band: p.band,
        fill: p.fill,
        stroke: p.stroke,
        strokeWidth: p.strokeWidth,
        radius: p.radius,
        ellipse: p.ellipse,
        lineStyle: p.lineStyle,
      ),
      ReportLinePrimitive() => ReportLinePrimitive(
        bounds: _flip(p.bounds, axis),
        elementId: p.elementId,
        band: p.band,
        x1: axis - p.x1,
        y1: p.y1,
        x2: axis - p.x2,
        y2: p.y2,
        color: p.color,
        width: p.width,
        lineStyle: p.lineStyle,
      ),
      ReportPathPrimitive() => ReportPathPrimitive(
        bounds: _flip(p.bounds, axis),
        elementId: p.elementId,
        band: p.band,
        points: Float64List.fromList(<double>[
          for (int i = 0; i < p.points.length; i++)
            i.isEven ? axis - p.points[i] : p.points[i],
        ]),
        closed: p.closed,
        fill: p.fill,
        stroke: p.stroke,
        strokeWidth: p.strokeWidth,
        lineStyle: p.lineStyle,
      ),
      ReportImagePrimitive() || ReportBarcodePrimitive() => p,
    };
  }
}
