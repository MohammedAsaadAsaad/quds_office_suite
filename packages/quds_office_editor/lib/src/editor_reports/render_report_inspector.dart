import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:quds_office_engine/quds_office_engine.dart';

import '../embed/office_theme.dart';
import 'render_report_toolbar.dart';
import 'report_completion_popup.dart';
import 'report_designer_controller.dart';
import 'report_inspector_glyphs.dart';

/// Choice-property click: hosts show the options and call
/// [ReportDesignerController.setProperty].
@immutable
class ReportInspectorChoice {
  /// ReportInspectorChoice API.
  const ReportInspectorChoice({
    required this.property,
    required this.globalPosition,
    this.options,
    this.details = const <String, String>{},
  });

  /// property API.
  final ReportProperty property;

  /// Where to anchor the options menu.
  final Offset globalPosition;

  /// Values to offer instead of [ReportProperty.options] (the presets of a
  /// combo field).
  final List<String>? options;

  /// Secondary text per option (format samples such as `1,234.50`).
  final Map<String, String> details;

  /// Values to show.
  List<String> get choices => options ?? property.options;
}

/// Property inspector of the report designer.
class ReportInspector extends LeafRenderObjectWidget {
  /// ReportInspector API.
  const ReportInspector({
    super.key,
    required this.controller,
    this.theme = OfficeTheme.light,
    this.onChoose,
    this.onActivate,
  });

  /// controller API.
  final ReportDesignerController controller;

  /// theme API.
  final OfficeTheme theme;

  /// Choice-property click.
  final ValueChanged<ReportInspectorChoice>? onChoose;

  /// Pointer down (hosts request keyboard focus).
  final VoidCallback? onActivate;

  @override
  RenderReportInspector createRenderObject(BuildContext context) =>
      RenderReportInspector(
        controller: controller,
        theme: theme,
        onChoose: onChoose,
        onActivate: onActivate,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderReportInspector renderObject,
  ) {
    renderObject
      ..controller = controller
      ..theme = theme
      ..onChoose = onChoose
      ..onActivate = onActivate;
  }
}

enum _RowKind { title, tabs, group, property, pair, glyphs, note }

class _Row {
  _Row(
    this.kind,
    this.rect, {
    this.props = const <ReportProperty>[],
    this.text = '',
    this.severity = 0,
  });

  final _RowKind kind;
  final Rect rect;
  final List<ReportProperty> props;
  final String text;
  final int severity;

  ReportProperty? get property => props.isEmpty ? null : props.first;
}

enum _HitKind {
  group,
  edit,
  toggle,
  menu,
  segment,
  stepUp,
  stepDown,
  presets,
  palette,
  action,
  glyph,
  tab,
}

class _Hit {
  const _Hit(this.kind, this.rect, {this.property, this.value = ''});

  final _HitKind kind;
  final Rect rect;
  final ReportProperty? property;
  final String value;
}

/// Anatomy of a text field: box, editable text area, and adornments.
class _Field {
  _Field(this.box, this.text, {this.swatch, this.stepper, this.drop});

  final Rect box;
  final Rect text;
  final Rect? swatch;
  final Rect? stepper;
  final Rect? drop;
}

class _Swatch {
  const _Swatch(this.rect, this.value, this.color, this.label);

  final Rect rect;
  final String value;
  final Color? color;
  final String label;
}

/// RenderBox behind [ReportInspector]: collapsible sections with switches,
/// segmented buttons, steppers, preset combos, a color palette, paired
/// position/size fields, and inline text editing.
class RenderReportInspector extends RenderBox
    implements MouseTrackerAnnotation {
  /// RenderReportInspector API.
  RenderReportInspector({
    required this._controller,
    required this._theme,
    this.onChoose,
    this.onActivate,
  });

  ReportDesignerController _controller;
  OfficeTheme _theme;

  /// onChoose API.
  ValueChanged<ReportInspectorChoice>? onChoose;

  /// onActivate API.
  VoidCallback? onActivate;

  /// Title row height.
  static const double titleHeight = 54;

  /// Page tabs height (Properties / Variables / Images).
  static const double tabsHeight = 34;

  /// Section heading height.
  static const double groupHeight = 30;

  /// Property row height.
  static const double rowHeight = 30;

  static const double _pad = 12;
  static const double _font = 11.5;
  static const double _sectionGap = 6;

  double _scroll = 0;
  Offset? _hover;
  double _editScrollX = 0;
  final ReportCompletionPopup _popup = ReportCompletionPopup();
  Rect? _popupRect;
  (Offset, Offset)? _editCaret;
  final Map<String, TextPainter> _cache = <String, TextPainter>{};
  List<_Row> _rows = <_Row>[];
  double _contentHeight = 0;
  int _diagRevision = -1;
  List<ReportDiagnostic> _diagnostics = const <ReportDiagnostic>[];
  final Set<String> _collapsed = <String>{};

  String? _paletteKey;
  Rect? _paletteAnchor;
  Rect? _paletteRect;
  List<_Swatch> _swatches = <_Swatch>[];

  /// controller API.
  ReportDesignerController get controller => _controller;

  set controller(ReportDesignerController value) {
    if (identical(value, _controller)) {
      return;
    }
    if (attached) {
      _controller.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _controller = value;
    markNeedsPaint();
  }

  /// theme API.
  OfficeTheme get theme => _theme;

  set theme(OfficeTheme value) {
    if (identical(value, _theme)) {
      return;
    }
    _theme = value;
    _clearCache();
    markNeedsPaint();
  }

  /// Whether section [group] is collapsed.
  bool isCollapsed(String group) => _collapsed.contains(group);

  /// Collapses or expands section [group].
  void setCollapsed(String group, bool collapsed) {
    if (collapsed ? _collapsed.add(group) : _collapsed.remove(group)) {
      markNeedsPaint();
    }
  }

  /// Key of the property whose color palette is open, if any.
  String? get paletteKey => _paletteKey;

  /// Opens the color palette of color property [key] (null closes it).
  void openPalette(String? key) {
    _paletteKey = key;
    _paletteAnchor = null;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _controller.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _popup.dispose();
    _clearCache();
    super.dispose();
  }

  void _clearCache() {
    for (final TextPainter tp in _cache.values) {
      tp.dispose();
    }
    _cache.clear();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final Size s = constraints.biggest;
    return s.isFinite ? s : constraints.constrain(const Size(300, 600));
  }

  @override
  bool hitTestSelf(Offset position) {
    _hover = position;
    return true;
  }

  // ------------------------------------------------------------ colors

  Color get _ink => _theme.chromeText;

  Color get _muted => _theme.chromeText.withValues(alpha: 0.55);

  Color get _accent => _theme.selectionStroke;

  Color get _line => _theme.gridLine;

  Color get _fieldFill => _theme.pageBackground;

  // ------------------------------------------------------------ geometry

  double get _labelWidth => math.max(88, size.width * 0.38);

  Rect _valueRect(Rect row) => Rect.fromLTRB(
    _labelWidth,
    row.top + 3,
    size.width - _pad,
    row.bottom - 3,
  );

  (Rect, Rect) _pairRects(Rect row) {
    final double w = (size.width - 2 * _pad - 8) / 2;
    return (
      Rect.fromLTWH(_pad, row.top + 3, w, row.height - 6),
      Rect.fromLTWH(_pad + w + 8, row.top + 3, w, row.height - 6),
    );
  }

  _Field _field(ReportProperty p, Rect f, {String prefix = ''}) {
    var left = f.left + 6;
    var right = f.right - 5;
    Rect? stepper;
    Rect? drop;
    Rect? swatch;
    if (p.isSteppable) {
      stepper = Rect.fromLTRB(
        f.right - 16,
        f.top + 1,
        f.right - 1,
        f.bottom - 1,
      );
      right = stepper.left - 3;
    }
    if (p.presets.isNotEmpty || p.kind == ReportPropertyKind.color) {
      drop = Rect.fromLTRB(right - 16, f.top + 1, right + 2, f.bottom - 1);
      right = drop.left - 1;
    }
    if (p.kind == ReportPropertyKind.color) {
      swatch = Rect.fromLTWH(f.left + 4, f.center.dy - 7, 14, 14);
      left = swatch.right + 6;
    }
    if (prefix.isNotEmpty) {
      left += _text(prefix, 10.5, _muted, 80, bold: true).width + 6;
    }
    return _Field(
      f,
      Rect.fromLTRB(left, f.top, math.max(left + 8, right), f.bottom),
      swatch: swatch,
      stepper: stepper,
      drop: drop,
    );
  }

  /// `ReportHeader` → `Report header`.
  static String _spaced(String name) {
    final String s = name.replaceAllMapped(
      RegExp('([a-z])([A-Z])'),
      (Match m) => '${m[1]} ${m[2]!.toLowerCase()}',
    );
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  static String _optionLabel(String option) {
    if (option.isEmpty) {
      return 'None';
    }
    switch (option) {
      case 'rtl' || 'ltr' || 'qr' || 'pt' || 'mm' || 'cm' || 'px':
        return option.toUpperCase();
      case 'inch':
        return 'IN';
    }
    final String spaced = option.replaceAllMapped(
      RegExp('([a-z])([A-Z0-9])'),
      (Match m) => '${m[1]} ${m[2]!.toLowerCase()}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  List<(String, Rect)>? _segments(ReportProperty p, Rect v) {
    final List<String> options = p.options;
    if (options.length < 2 || options.length > 6) {
      return null;
    }
    final List<(String, Rect)> out = <(String, Rect)>[];
    if (options.every(ReportInspectorGlyphs.has)) {
      final double w = math.min(32, v.width / options.length);
      var x = v.left;
      for (final String o in options) {
        out.add((o, Rect.fromLTWH(x, v.top, w, v.height)));
        x += w;
      }
      return out;
    }
    if (options.length > 5) {
      return null;
    }
    final List<double> widths = <double>[
      for (final String o in options)
        _text(_optionLabel(o), 10.5, _ink, 200).width + 14,
    ];
    final double total = widths.fold(0, (double a, double b) => a + b);
    if (total > v.width) {
      return null;
    }
    final double extra = (v.width - total) / options.length;
    var x = v.left;
    for (int i = 0; i < options.length; i++) {
      final double w = widths[i] + extra;
      out.add((options[i], Rect.fromLTWH(x, v.top, w, v.height)));
      x += w;
    }
    return out;
  }

  Rect _switchRect(Rect v) => Rect.fromLTWH(v.left, v.center.dy - 8, 30, 16);

  bool _wideAction(ReportProperty p) => p.label.isEmpty || p.key.endsWith('+');

  Rect _actionRect(ReportProperty p, Rect row) {
    if (_wideAction(p)) {
      return Rect.fromLTRB(
        _pad,
        row.top + 3,
        size.width - _pad,
        row.bottom - 3,
      );
    }
    final Rect v = _valueRect(row);
    final double w = _text(p.value, _font, _accent, v.width).width + 28;
    return Rect.fromLTWH(
      v.left,
      v.top,
      math.min(v.width, math.max(64, w)),
      v.height,
    );
  }

  List<Rect> _glyphRects(Rect row, int count) {
    final Rect v = _valueRect(row);
    return <Rect>[
      for (int i = 0; i < count; i++)
        Rect.fromLTWH(v.left + i * 34, v.top, 30, v.height),
    ];
  }

  // ------------------------------------------------------------ rows

  List<ReportDiagnostic> get _diag {
    if (_diagRevision != _controller.revision) {
      _diagRevision = _controller.revision;
      try {
        _diagnostics = _controller.validate();
      } on Object catch (e) {
        _diagnostics = <ReportDiagnostic>[
          ReportDiagnostic(ReportDiagnosticSeverity.error, 'template', '$e'),
        ];
      }
    }
    return _diagnostics;
  }

  void _buildRows() {
    final List<_Row> rows = <_Row>[];
    var y = -_scroll;
    rows.add(
      _Row(
        _RowKind.title,
        Rect.fromLTWH(0, y, size.width, titleHeight),
        text: _controller.inspectorTitle,
      ),
    );
    y += titleHeight;
    rows.add(_Row(_RowKind.tabs, Rect.fromLTWH(0, y, size.width, tabsHeight)));
    y += tabsHeight + 4;
    final List<ReportProperty> props = _controller.properties;
    final ReportInspectorPage page = _controller.inspectorPage;
    if (props.isEmpty && page != ReportInspectorPage.properties) {
      final String note = page == ReportInspectorPage.images
          ? 'No embedded images. The host app has not enabled image import.'
          : 'No template variables.';
      rows.add(
        _Row(_RowKind.note, Rect.fromLTWH(0, y, size.width, 30), text: note),
      );
      y += 30;
    }
    String? group;
    var i = 0;
    while (i < props.length) {
      final ReportProperty p = props[i];
      if (p.group != group) {
        if (group != null) {
          y += _sectionGap;
        }
        group = p.group;
        rows.add(
          _Row(
            _RowKind.group,
            Rect.fromLTWH(0, y, size.width, groupHeight),
            text: group,
          ),
        );
        y += groupHeight;
      }
      if (_collapsed.contains(group)) {
        i++;
        continue;
      }
      if (p.pair &&
          i + 1 < props.length &&
          props[i + 1].pair &&
          props[i + 1].group == group) {
        rows.add(
          _Row(
            _RowKind.pair,
            Rect.fromLTWH(0, y, size.width, rowHeight),
            props: <ReportProperty>[p, props[i + 1]],
          ),
        );
        y += rowHeight;
        i += 2;
        continue;
      }
      if (p.glyph != null) {
        final List<ReportProperty> run = <ReportProperty>[p];
        while (i + run.length < props.length &&
            props[i + run.length].glyph != null &&
            props[i + run.length].group == group) {
          run.add(props[i + run.length]);
        }
        rows.add(
          _Row(
            _RowKind.glyphs,
            Rect.fromLTWH(0, y, size.width, rowHeight),
            props: run,
            text: 'Style',
          ),
        );
        y += rowHeight;
        i += run.length;
        continue;
      }
      final double h = _rowHeightFor(p);
      rows.add(
        _Row(
          _RowKind.property,
          Rect.fromLTWH(0, y, size.width, h),
          props: <ReportProperty>[p],
        ),
      );
      y += h;
      i++;
    }
    if (page == ReportInspectorPage.properties &&
        _controller.selection.isEmpty &&
        _controller.selectedBand == null) {
      const String title = 'Diagnostics';
      y += _sectionGap;
      rows.add(
        _Row(
          _RowKind.group,
          Rect.fromLTWH(0, y, size.width, groupHeight),
          text: title,
        ),
      );
      y += groupHeight;
      if (!_collapsed.contains(title)) {
        final List<ReportDiagnostic> diag = _diag;
        final List<(int, String)> notes = diag.isEmpty
            ? const <(int, String)>[(0, 'No problems found.')]
            : <(int, String)>[
                for (final ReportDiagnostic d in diag)
                  (d.isError ? 2 : 1, '${d.message}\n${d.path}'),
              ];
        for (final (int severity, String note) in notes) {
          final TextPainter tp = _text(
            note,
            _font - 0.5,
            _ink,
            size.width - 2 * _pad - 22,
            lines: 5,
          );
          final double h = math.max(26, tp.height + 10);
          rows.add(
            _Row(
              _RowKind.note,
              Rect.fromLTWH(0, y, size.width, h),
              text: note,
              severity: severity,
            ),
          );
          y += h;
        }
      }
    }
    y += 12;
    _rows = rows;
    _contentHeight = y + _scroll;
  }

  TextPainter _wideNote(ReportProperty p) => _text(
    p.value,
    _font - 0.5,
    _muted,
    size.width - 2 * _pad,
    italic: true,
    lines: 4,
  );

  double _rowHeightFor(ReportProperty p) {
    if (p.kind == ReportPropertyKind.note && p.label.isEmpty) {
      return math.max(rowHeight, _wideNote(p).height + 12);
    }
    if (_controller.editingProperty != p.key ||
        p.kind != ReportPropertyKind.multiline) {
      return rowHeight;
    }
    final TextPainter tp = _editPainter(p, _multilineWidth);
    final double h = math.max(
      rowHeight,
      math.min(tp.height, 8 * tp.preferredLineHeight) + 12,
    );
    tp.dispose();
    return h;
  }

  double get _multilineWidth => size.width - _pad - _labelWidth - 14;

  TextPainter _text(
    String text,
    double fontSize,
    Color color,
    double maxWidth, {
    bool bold = false,
    bool italic = false,
    int lines = 1,
  }) {
    final String key =
        '$text|$fontSize|${color.toARGB32()}|$maxWidth|$bold|$italic|$lines';
    final TextPainter? hit = _cache[key];
    if (hit != null) {
      return hit;
    }
    if (_cache.length > 800) {
      _clearCache();
    }
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: _theme.fontFamily ?? 'Liberation Sans',
          fontFamilyFallback: const <String>['Noto Naskh Arabic'],
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth < 10 ? 10 : maxWidth);
    _cache[key] = tp;
    return tp;
  }

  TextPainter _editPainter(ReportProperty p, double width) {
    final bool multi = p.kind == ReportPropertyKind.multiline;
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: _controller.propertyEditor.formulaBar,
        style: TextStyle(
          fontFamily: _theme.fontFamily ?? 'Liberation Sans',
          fontFamilyFallback: const <String>['Noto Naskh Arabic'],
          fontSize: _font,
          color: const Color(0xFF111111),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    if (multi) {
      tp.layout(maxWidth: width < 10 ? 10 : width);
    } else {
      tp.layout();
    }
    return tp;
  }

  _Row? _rowAt(Offset local) {
    for (final _Row r in _rows) {
      if (r.rect.contains(local)) {
        return r;
      }
    }
    return null;
  }

  // ------------------------------------------------------------ hits

  List<_Hit> _hitsFor(_Row row) {
    switch (row.kind) {
      case _RowKind.group:
        return <_Hit>[_Hit(_HitKind.group, row.rect)];
      case _RowKind.property:
        final ReportProperty p = row.property!;
        if (p.kind == ReportPropertyKind.action) {
          return <_Hit>[
            _Hit(_HitKind.action, _actionRect(p, row.rect), property: p),
          ];
        }
        return _fieldHits(p, _valueRect(row.rect));
      case _RowKind.pair:
        final (Rect a, Rect b) = _pairRects(row.rect);
        return <_Hit>[
          ..._fieldHits(row.props[0], a, prefix: row.props[0].label),
          ..._fieldHits(row.props[1], b, prefix: row.props[1].label),
        ];
      case _RowKind.glyphs:
        final List<Rect> rects = _glyphRects(row.rect, row.props.length);
        return <_Hit>[
          for (int i = 0; i < rects.length; i++)
            _Hit(_HitKind.glyph, rects[i], property: row.props[i]),
        ];
      case _RowKind.tabs:
        return <_Hit>[
          for (final (ReportInspectorPage page, Rect r) in _tabRects(row.rect))
            _Hit(_HitKind.tab, r, value: page.name),
        ];
      case _RowKind.title:
      case _RowKind.note:
        return const <_Hit>[];
    }
  }

  List<_Hit> _fieldHits(ReportProperty p, Rect v, {String prefix = ''}) {
    switch (p.kind) {
      case ReportPropertyKind.toggle:
        return <_Hit>[_Hit(_HitKind.toggle, _switchRect(v), property: p)];
      case ReportPropertyKind.choice:
        final List<(String, Rect)>? segments = _segments(p, v);
        if (segments != null) {
          return <_Hit>[
            for (final (String option, Rect r) in segments)
              _Hit(_HitKind.segment, r, property: p, value: option),
          ];
        }
        return <_Hit>[_Hit(_HitKind.menu, v, property: p)];
      case ReportPropertyKind.action:
        return <_Hit>[_Hit(_HitKind.action, v, property: p)];
      case ReportPropertyKind.note:
        return const <_Hit>[];
      case ReportPropertyKind.text:
      case ReportPropertyKind.multiline:
      case ReportPropertyKind.length:
      case ReportPropertyKind.number:
      case ReportPropertyKind.color:
      case ReportPropertyKind.expression:
        final _Field f = _field(p, v, prefix: prefix);
        final Rect? stepper = f.stepper;
        final Rect? drop = f.drop;
        final Rect? swatch = f.swatch;
        final bool color = p.kind == ReportPropertyKind.color;
        return <_Hit>[
          if (stepper != null) ...<_Hit>[
            _Hit(
              _HitKind.stepUp,
              Rect.fromLTRB(
                stepper.left,
                stepper.top,
                stepper.right,
                stepper.center.dy,
              ),
              property: p,
            ),
            _Hit(
              _HitKind.stepDown,
              Rect.fromLTRB(
                stepper.left,
                stepper.center.dy,
                stepper.right,
                stepper.bottom,
              ),
              property: p,
            ),
          ],
          if (drop != null)
            _Hit(
              color ? _HitKind.palette : _HitKind.presets,
              drop,
              property: p,
            ),
          if (swatch != null)
            _Hit(_HitKind.palette, swatch.inflate(3), property: p),
          _Hit(_HitKind.edit, v, property: p),
        ];
    }
  }

  _Hit? _hitAt(Offset local) {
    final _Row? row = _rowAt(local);
    if (row == null) {
      return null;
    }
    for (final _Hit h in _hitsFor(row)) {
      if (h.rect.contains(local)) {
        return h;
      }
    }
    return null;
  }

  /// Text area of the field editing [key], in local coordinates.
  Rect? _textRectFor(String key) {
    for (final _Row row in _rows) {
      switch (row.kind) {
        case _RowKind.property:
          final ReportProperty p = row.property!;
          if (p.key == key) {
            return _field(p, _valueRect(row.rect)).text;
          }
        case _RowKind.pair:
          final (Rect a, Rect b) = _pairRects(row.rect);
          if (row.props[0].key == key) {
            return _field(row.props[0], a, prefix: row.props[0].label).text;
          }
          if (row.props[1].key == key) {
            return _field(row.props[1], b, prefix: row.props[1].label).text;
          }
        case _RowKind.title:
        case _RowKind.tabs:
        case _RowKind.group:
        case _RowKind.glyphs:
        case _RowKind.note:
          break;
      }
    }
    return null;
  }

  // ------------------------------------------------------------ events

  @override
  MouseCursor get cursor {
    final Offset? local = _hover;
    if (local == null) {
      return SystemMouseCursors.basic;
    }
    final Rect? palette = _paletteRect;
    if (palette != null && palette.contains(local)) {
      return _swatches.any((_Swatch s) => s.rect.contains(local))
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic;
    }
    final _Hit? hit = _hitAt(local);
    if (hit == null) {
      return SystemMouseCursors.basic;
    }
    return hit.kind == _HitKind.edit
        ? SystemMouseCursors.text
        : SystemMouseCursors.click;
  }

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => (_) {
    _hover = null;
    markNeedsPaint();
  };

  @override
  bool get validForMouseTracker => attached;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerHoverEvent) {
      _hover = event.localPosition;
      markNeedsPaint();
      return;
    }
    if (event is PointerSignalEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, (
        PointerSignalEvent e,
      ) {
        if (e is PointerScrollEvent) {
          _scrollBy(e.scrollDelta.dy);
        }
      });
      return;
    }
    if (event is PointerPanZoomUpdateEvent) {
      _scrollBy(-event.localPanDelta.dy);
      return;
    }
    if (event is PointerDownEvent && event.buttons == kPrimaryButton) {
      onActivate?.call();
      _onTap(event.localPosition);
    }
  }

  void _scrollBy(double dy) {
    _closePalette();
    final double max = math.max(0, _contentHeight - size.height);
    _scroll = (_scroll + dy).clamp(0, max).toDouble();
    markNeedsPaint();
  }

  void _closePalette() {
    if (_paletteKey != null) {
      _paletteKey = null;
      _paletteAnchor = null;
      markNeedsPaint();
    }
  }

  void _onTap(Offset local) {
    _buildRows();
    final Rect? popup = _popupRect;
    final ReportCompletionResult? suggestions = _controller.completion;
    if (popup != null && suggestions != null && popup.contains(local)) {
      final int? i = ReportCompletionPopup.hitIndex(
        popup,
        local,
        suggestions.items.length,
        _controller.completionIndex,
      );
      if (i != null) {
        _controller.acceptCompletion(i);
      }
      return;
    }
    final String? paletteKey = _paletteKey;
    if (paletteKey != null) {
      final Rect? rect = _paletteRect;
      if (rect != null && rect.contains(local)) {
        for (final _Swatch s in _swatches) {
          if (s.rect.contains(local)) {
            _closePalette();
            _controller.setProperty(paletteKey, s.value);
            return;
          }
        }
        return;
      }
      _closePalette();
      return;
    }
    final _Hit? hit = _hitAt(local);
    final String? editing = _controller.editingProperty;
    final ReportProperty? p = hit?.property;
    if (hit == null) {
      if (editing != null) {
        _controller.commitPropertyEdit();
      }
      return;
    }
    if (hit.kind == _HitKind.edit && p != null && editing == p.key) {
      final Rect? text = _textRectFor(p.key);
      if (text != null) {
        final TextPainter tp = _editPainter(p, _multilineWidth);
        final bool multi = p.kind == ReportPropertyKind.multiline;
        final Offset inBox =
            local -
            Offset(
              text.left + 2 - _editScrollX,
              multi ? text.top + 4 : text.center.dy - tp.height / 2,
            );
        _controller.propertyEditor.setCaret(
          tp.getPositionForOffset(inBox).offset,
          extend: HardwareKeyboard.instance.isShiftPressed,
        );
        tp.dispose();
      }
      return;
    }
    if (editing != null) {
      _controller.commitPropertyEdit();
    }
    final bool shift = HardwareKeyboard.instance.isShiftPressed;
    switch (hit.kind) {
      case _HitKind.group:
        final _Row? row = _rowAt(local);
        if (row != null) {
          setCollapsed(row.text, !_collapsed.contains(row.text));
        }
      case _HitKind.edit:
        _controller.beginPropertyEdit(p!.key);
      case _HitKind.toggle:
      case _HitKind.glyph:
        _controller.setProperty(p!.key, p.value == 'true' ? 'false' : 'true');
      case _HitKind.menu:
        onChoose?.call(
          ReportInspectorChoice(
            property: p!,
            globalPosition: localToGlobal(hit.rect.bottomLeft),
          ),
        );
      case _HitKind.segment:
        _controller.setProperty(p!.key, hit.value);
      case _HitKind.stepUp:
        _controller.stepProperty(p!.key, 1, large: shift);
      case _HitKind.stepDown:
        _controller.stepProperty(p!.key, -1, large: shift);
      case _HitKind.presets:
        final Rect? text = _textRectFor(p!.key);
        onChoose?.call(
          ReportInspectorChoice(
            property: p,
            globalPosition: localToGlobal(
              Offset((text ?? hit.rect).left - 6, hit.rect.bottom + 2),
            ),
            options: p.presets,
            details: _presetDetails(p),
          ),
        );
      case _HitKind.palette:
        _paletteKey = p!.key;
        final Rect? text = _textRectFor(p.key);
        _paletteAnchor = text == null
            ? hit.rect
            : Rect.fromLTRB(text.left - 24, text.top, text.right, text.bottom);
        markNeedsPaint();
      case _HitKind.action:
        _controller.setProperty(p!.key, p.value);
      case _HitKind.tab:
        final ReportInspectorPage page = ReportInspectorPage.values.byName(
          hit.value,
        );
        if (page != _controller.inspectorPage) {
          _scroll = 0;
          _controller.inspectorPage = page;
        }
    }
  }

  static Map<String, String> _presetDetails(ReportProperty p) {
    final String leaf = p.key.split('.').last;
    if (leaf != 'format' && leaf != 'valueFormat') {
      return const <String, String>{};
    }
    return <String, String>{
      for (final (String spec, String sample) in ReportCompleter.formats)
        spec: sample,
    };
  }

  /// Starts editing the textual property after the one being edited.
  void editNext({bool backwards = false}) {
    _buildRows();
    final List<ReportProperty> props = <ReportProperty>[
      for (final _Row r in _rows)
        for (final ReportProperty p in r.props)
          if (p.isTextual) p,
    ];
    if (props.isEmpty) {
      return;
    }
    final String? current = _controller.editingProperty;
    var i = props.indexWhere((ReportProperty p) => p.key == current);
    _controller.commitPropertyEdit();
    i = backwards ? i - 1 : i + 1;
    if (i < 0) {
      i = props.length - 1;
    }
    if (i >= props.length) {
      i = 0;
    }
    _controller.beginPropertyEdit(props[i].key);
  }

  // ------------------------------------------------------------ paint

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = _theme.chromeFill);
    _buildRows();
    final double max = math.max(0, _contentHeight - size.height);
    if (_scroll > max) {
      _scroll = max.toDouble();
      _buildRows();
    }
    _editCaret = null;
    final _Hit? hot = _hover == null ? null : _hitAt(_hover!);
    for (final _Row row in _rows) {
      if (row.rect.bottom < 0 || row.rect.top > size.height) {
        continue;
      }
      switch (row.kind) {
        case _RowKind.title:
          _paintTitle(canvas, row);
        case _RowKind.tabs:
          _paintTabs(canvas, row, hot);
        case _RowKind.group:
          _paintGroup(canvas, row, hot);
        case _RowKind.note:
          ReportInspectorGlyphs.status(
            canvas,
            Offset(_pad + 6, row.rect.top + 12),
            row.severity,
          );
          _text(
            row.text,
            _font - 0.5,
            _ink,
            size.width - 2 * _pad - 22,
            lines: 5,
          ).paint(canvas, Offset(_pad + 20, row.rect.top + 5));
        case _RowKind.property:
          _paintProperty(canvas, row, hot);
        case _RowKind.pair:
          final (Rect a, Rect b) = _pairRects(row.rect);
          _paintControl(
            canvas,
            row.props[0],
            a,
            hot,
            prefix: row.props[0].label,
          );
          _paintControl(
            canvas,
            row.props[1],
            b,
            hot,
            prefix: row.props[1].label,
          );
        case _RowKind.glyphs:
          _paintLabel(canvas, row.text, row.rect);
          final List<Rect> rects = _glyphRects(row.rect, row.props.length);
          for (int i = 0; i < rects.length; i++) {
            _paintGlyphButton(canvas, row.props[i], rects[i], hot);
          }
      }
    }
    if (_contentHeight > size.height) {
      final double frac = size.height / _contentHeight;
      final double h = math.max(24, size.height * frac);
      final double top = (size.height - h) * (_scroll / math.max(1, max));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width - 5, top, 3, h),
          const Radius.circular(2),
        ),
        Paint()..color = _ink.withValues(alpha: 0.25),
      );
    }
    canvas.drawLine(
      Offset.zero,
      Offset(0, size.height),
      Paint()..color = _theme.pageBorder,
    );
    _paintPalette(canvas);
    _popupRect = null;
    final (Offset, Offset)? caret = _editCaret;
    final ReportCompletionResult? r = caret == null
        ? null
        : _controller.completion;
    if (caret != null && r != null) {
      final Rect rect = ReportCompletionPopup.place(
        caret.$1,
        caret.$2,
        size,
        r.items.length,
      );
      _popupRect = rect;
      _popup.paint(canvas, rect, r, _controller.completionIndex, _theme);
    }
    canvas.restore();
  }

  (ReportToolbarIcon, String) get _titleBadge {
    switch (_controller.inspectorPage) {
      case ReportInspectorPage.variables:
        final int n = _controller.template.variables.length;
        return (
          ReportToolbarIcon.variables,
          '$n template ${n == 1 ? 'variable' : 'variables'} · '
              '{{Variables.name}}',
        );
      case ReportInspectorPage.images:
        final int n = _controller.images.length;
        return (
          ReportToolbarIcon.image,
          '$n embedded ${n == 1 ? 'image' : 'images'} · saved in the .qrep',
        );
      case ReportInspectorPage.fonts:
        final int n = _controller.embeddedFonts.length;
        return (
          ReportToolbarIcon.font,
          '$n embedded ${n == 1 ? 'family' : 'families'} · saved in the .qrep',
        );
      case ReportInspectorPage.properties:
        break;
    }
    final List<ReportElement> sel = _controller.selectedElements;
    if (sel.length > 1) {
      return (
        ReportToolbarIcon.duplicate,
        'Shared properties of the selection',
      );
    }
    if (sel.length == 1) {
      final ReportElement e = sel.first;
      final String band = _spaced(
        _controller.template.findElement(e.id)?.$1.kind.xmlName ?? '',
      );
      final (ReportToolbarIcon icon, String kind) = switch (e) {
        ReportTextElement() => (ReportToolbarIcon.text, 'Text'),
        ReportImageElement() => (ReportToolbarIcon.image, 'Image'),
        ReportTableElement() => (ReportToolbarIcon.table, 'Table'),
        ReportBarcodeElement(:final ReportBarcodeType symbology) =>
          symbology == ReportBarcodeType.qr
              ? (ReportToolbarIcon.qr, 'QR code')
              : (ReportToolbarIcon.barcode, 'Barcode'),
        ReportShapeElement(:final ReportShapeKind kind) => switch (kind) {
          ReportShapeKind.line => (ReportToolbarIcon.line, 'Line'),
          ReportShapeKind.ellipse => (ReportToolbarIcon.ellipse, 'Ellipse'),
          ReportShapeKind.rectangle || ReportShapeKind.roundedRectangle => (
            ReportToolbarIcon.rectangle,
            'Rectangle',
          ),
        },
        ReportChartElement() => (ReportToolbarIcon.chart, 'Chart'),
      };
      return (icon, band.isEmpty ? kind : '$kind · ${band.toLowerCase()} band');
    }
    final ReportBandKind? band = _controller.selectedBand;
    if (band != null && _controller.template.band(band) != null) {
      final int n = _controller.template.band(band)!.elements.length;
      return (
        ReportToolbarIcon.sameHeight,
        '${_spaced(band.xmlName)} band · $n elements',
      );
    }
    final ReportTemplate t = _controller.template;
    return (
      ReportToolbarIcon.templates,
      'Report settings · ${t.pageSize.name} ${t.orientation.name}',
    );
  }

  void _paintTitle(Canvas canvas, _Row row) {
    final Rect r = row.rect;
    canvas.drawRect(r, Paint()..color = _theme.headerFill);
    final (ReportToolbarIcon icon, String subtitle) = _titleBadge;
    final Rect badge = Rect.fromLTWH(_pad, r.center.dy - 16, 32, 32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badge, const Radius.circular(8)),
      Paint()..color = _accent,
    );
    RenderReportToolbar.paintIcon(
      canvas,
      icon,
      Rect.fromCenter(center: badge.center, width: 16, height: 16),
      const Color(0xFFFFFFFF),
    );
    final double textLeft = badge.right + 10;
    final double width = size.width - textLeft - _pad;
    final TextPainter title = _text(row.text, 13.5, _ink, width, bold: true);
    final TextPainter sub = _text(subtitle, 11, _muted, width);
    final double top = r.center.dy - (title.height + sub.height + 2) / 2;
    title.paint(canvas, Offset(textLeft, top));
    sub.paint(canvas, Offset(textLeft, top + title.height + 2));
    canvas.drawLine(
      r.bottomLeft,
      r.bottomRight,
      Paint()..color = _theme.pageBorder,
    );
  }

  static const List<(ReportInspectorPage, ReportToolbarIcon, String)>
  _tabs = <(ReportInspectorPage, ReportToolbarIcon, String)>[
    (ReportInspectorPage.properties, ReportToolbarIcon.select, 'Properties'),
    (ReportInspectorPage.variables, ReportToolbarIcon.variables, 'Variables'),
    (ReportInspectorPage.images, ReportToolbarIcon.image, 'Images'),
    (ReportInspectorPage.fonts, ReportToolbarIcon.font, 'Fonts'),
  ];

  List<(ReportInspectorPage, Rect)> _tabRects(Rect row) {
    final double w = (size.width - 2 * _pad) / _tabs.length;
    return <(ReportInspectorPage, Rect)>[
      for (int i = 0; i < _tabs.length; i++)
        (
          _tabs[i].$1,
          Rect.fromLTWH(_pad + i * w, row.top + 4, w, row.height - 4),
        ),
    ];
  }

  int? _tabCount(ReportInspectorPage page) => switch (page) {
    ReportInspectorPage.properties => null,
    ReportInspectorPage.variables => _controller.template.variables.length,
    ReportInspectorPage.images => _controller.images.length,
    ReportInspectorPage.fonts => _controller.embeddedFonts.length,
  };

  void _paintTabs(Canvas canvas, _Row row, _Hit? hot) {
    final Rect r = row.rect;
    canvas.drawRect(r, Paint()..color = _theme.headerFill);
    canvas.drawLine(
      r.bottomLeft,
      r.bottomRight,
      Paint()..color = _theme.pageBorder,
    );
    final List<(ReportInspectorPage, Rect)> rects = _tabRects(r);
    const double icon = 13;
    var showIcon = true;
    var showLabel = true;
    for (int i = 0; i < rects.length; i++) {
      final int? count = _tabCount(rects[i].$1);
      final double badge = count == null || count == 0
          ? 0
          : math.max(16, _text('$count', 9.5, _ink, 40, bold: true).width + 8) +
                4;
      final double widest = _text(
        _tabs[i].$3,
        11,
        _ink,
        rects[i].$2.width,
        bold: true,
      ).width;
      if (icon + 5 + widest + badge > rects[i].$2.width - 6) {
        showIcon = false;
      }
      if (widest + badge > rects[i].$2.width - 6) {
        showLabel = false;
      }
    }
    if (!showLabel) {
      showIcon = true;
    }
    for (int i = 0; i < rects.length; i++) {
      final (ReportInspectorPage page, Rect t) = rects[i];
      final bool active = page == _controller.inspectorPage;
      final bool h =
          hot != null && hot.kind == _HitKind.tab && hot.value == page.name;
      if (h && !active) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            t.deflate(1),
            topLeft: const Radius.circular(5),
            topRight: const Radius.circular(5),
          ),
          Paint()..color = _accent.withValues(alpha: 0.08),
        );
      }
      final Color ink = active ? _accent : _muted;
      final TextPainter label = _text(
        _tabs[i].$3,
        11,
        active ? _ink : _muted,
        t.width,
        bold: active,
      );
      final int? count = _tabCount(page);
      final TextPainter? badge = count == null || count == 0
          ? null
          : _text(
              '$count',
              9.5,
              active ? const Color(0xFFFFFFFF) : _ink,
              40,
              bold: true,
            );
      final double badgeW = badge == null ? 0 : math.max(16, badge.width + 8);
      final double contentW =
          (showIcon ? icon + (showLabel ? 5 : 0) : 0) +
          (showLabel ? label.width : 0) +
          (badge == null ? 0 : badgeW + 4);
      var x = t.center.dx - contentW / 2;
      final double cy = t.center.dy - 1;
      if (showIcon) {
        RenderReportToolbar.paintIcon(
          canvas,
          _tabs[i].$2,
          Rect.fromLTWH(x, cy - icon / 2, icon, icon),
          ink,
        );
        x += icon + (showLabel ? 5 : 4);
      }
      if (showLabel) {
        label.paint(canvas, Offset(x, cy - label.height / 2));
        x += label.width + 4;
      }
      if (badge != null) {
        final Rect b = Rect.fromLTWH(x, cy - 8, badgeW, 16);
        canvas.drawRRect(
          RRect.fromRectAndRadius(b, const Radius.circular(8)),
          Paint()..color = active ? _accent : _ink.withValues(alpha: 0.1),
        );
        badge.paint(
          canvas,
          Offset(b.center.dx - badge.width / 2, b.center.dy - badge.height / 2),
        );
      }
      if (active) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(t.left + 6, t.bottom - 2.5, t.width - 12, 2.5),
            const Radius.circular(1.5),
          ),
          Paint()..color = _accent,
        );
      }
    }
  }

  void _paintGroup(Canvas canvas, _Row row, _Hit? hot) {
    final Rect r = row.rect;
    final bool hover = hot?.kind == _HitKind.group && hot!.rect == r;
    canvas.drawRect(
      r,
      Paint()..color = _ink.withValues(alpha: hover ? 0.07 : 0.035),
    );
    canvas.drawLine(
      r.topLeft,
      r.topRight,
      Paint()..color = _theme.pageBorder.withValues(alpha: 0.6),
    );
    final bool open = !_collapsed.contains(row.text);
    ReportInspectorGlyphs.chevron(
      canvas,
      Offset(_pad + 4, r.center.dy),
      _muted,
      open: open,
    );
    final TextPainter tp = _text(
      row.text,
      11.5,
      _ink,
      size.width - 2 * _pad - 16,
      bold: true,
    );
    tp.paint(canvas, Offset(_pad + 16, r.center.dy - tp.height / 2));
  }

  void _paintLabel(Canvas canvas, String label, Rect row) {
    final TextPainter tp = _text(label, _font, _ink, _labelWidth - _pad - 6);
    tp.paint(canvas, Offset(_pad, row.top + (rowHeight - tp.height) / 2));
  }

  void _paintProperty(Canvas canvas, _Row row, _Hit? hot) {
    final ReportProperty p = row.property!;
    final Rect r = row.rect;
    final Offset? hover = _hover;
    if (hover != null && r.contains(hover) && _paletteKey == null) {
      canvas.drawRect(r, Paint()..color = _accent.withValues(alpha: 0.05));
    }
    if (p.kind == ReportPropertyKind.action) {
      _paintAction(canvas, p, _actionRect(p, r), hot);
      if (!_wideAction(p)) {
        _paintLabel(canvas, p.label, r);
      }
      return;
    }
    if (p.kind == ReportPropertyKind.note && p.label.isEmpty) {
      _wideNote(p).paint(canvas, Offset(_pad, r.top + 6));
      return;
    }
    _paintLabel(canvas, p.label, r);
    _paintControl(canvas, p, _valueRect(r), hot);
  }

  bool _isHot(_Hit? hot, _HitKind kind, ReportProperty p, [String? value]) =>
      hot != null &&
      hot.kind == kind &&
      hot.property?.key == p.key &&
      (value == null || hot.value == value);

  void _paintControl(
    Canvas canvas,
    ReportProperty p,
    Rect v,
    _Hit? hot, {
    String prefix = '',
  }) {
    switch (p.kind) {
      case ReportPropertyKind.action:
        _paintAction(canvas, p, v, hot);
      case ReportPropertyKind.note:
        final TextPainter tp = _text(p.value, _font, _muted, v.width);
        tp.paint(canvas, Offset(v.left, v.center.dy - tp.height / 2));
      case ReportPropertyKind.toggle:
        _paintSwitch(
          canvas,
          _switchRect(v),
          p.value == 'true',
          _isHot(hot, _HitKind.toggle, p),
        );
      case ReportPropertyKind.choice:
        final List<(String, Rect)>? segments = _segments(p, v);
        if (segments != null) {
          _paintSegments(canvas, p, v, segments, hot);
        } else {
          _paintBox(canvas, v, hover: _isHot(hot, _HitKind.menu, p));
          final TextPainter tp = _text(
            _optionLabel(p.value),
            _font,
            _ink,
            v.width - 30,
          );
          tp.paint(canvas, Offset(v.left + 8, v.center.dy - tp.height / 2));
          ReportInspectorGlyphs.chevron(
            canvas,
            Offset(v.right - 11, v.center.dy),
            _muted,
          );
        }
      case ReportPropertyKind.text:
      case ReportPropertyKind.multiline:
      case ReportPropertyKind.length:
      case ReportPropertyKind.number:
      case ReportPropertyKind.color:
      case ReportPropertyKind.expression:
        _paintField(canvas, p, v, hot, prefix: prefix);
    }
  }

  void _paintBox(
    Canvas canvas,
    Rect v, {
    bool hover = false,
    bool focus = false,
  }) {
    final RRect rr = RRect.fromRectAndRadius(v, const Radius.circular(4));
    canvas.drawRRect(
      rr,
      Paint()..color = focus ? const Color(0xFFFFFFFF) : _fieldFill,
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = focus
            ? _theme.focusRing
            : hover
            ? _accent.withValues(alpha: 0.7)
            : _line
        ..style = PaintingStyle.stroke
        ..strokeWidth = focus ? 1.5 : 1,
    );
  }

  void _paintField(
    Canvas canvas,
    ReportProperty p,
    Rect v,
    _Hit? hot, {
    String prefix = '',
  }) {
    final _Field f = _field(p, v, prefix: prefix);
    final bool editing = _controller.editingProperty == p.key;
    final bool hover =
        hot != null &&
        hot.property?.key == p.key &&
        v.contains(hot.rect.center);
    _paintBox(canvas, v, hover: hover, focus: editing);
    if (prefix.isNotEmpty) {
      final TextPainter tp = _text(prefix, 10.5, _muted, 80, bold: true);
      tp.paint(canvas, Offset(v.left + 6, v.center.dy - tp.height / 2));
    }
    final Rect? swatch = f.swatch;
    if (swatch != null) {
      final ReportColor c = _controller.template.resolveColor(
        p.value,
        ReportColor.transparent,
      );
      final RRect rr = RRect.fromRectAndRadius(
        swatch,
        const Radius.circular(3),
      );
      if (c.alpha == 0) {
        canvas.save();
        canvas.clipRRect(rr);
        ReportInspectorGlyphs.noColor(canvas, swatch);
        canvas.restore();
      } else {
        canvas.drawRRect(rr, Paint()..color = Color(c.argb));
      }
      canvas.drawRRect(
        rr,
        Paint()
          ..color = _ink.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke,
      );
    }
    final Rect? stepper = f.stepper;
    if (stepper != null) {
      canvas.drawLine(
        Offset(stepper.left, stepper.top + 3),
        Offset(stepper.left, stepper.bottom - 3),
        Paint()..color = _line,
      );
      final Rect up = Rect.fromLTRB(
        stepper.left,
        stepper.top,
        stepper.right,
        stepper.center.dy,
      );
      final Rect down = Rect.fromLTRB(
        stepper.left,
        stepper.center.dy,
        stepper.right,
        stepper.bottom,
      );
      for (final (Rect r, bool isUp, _HitKind kind) in <(Rect, bool, _HitKind)>[
        (up, true, _HitKind.stepUp),
        (down, false, _HitKind.stepDown),
      ]) {
        final bool h = _isHot(hot, kind, p);
        if (h) {
          canvas.drawRect(
            r.deflate(1),
            Paint()..color = _accent.withValues(alpha: 0.15),
          );
        }
        ReportInspectorGlyphs.stepArrow(
          canvas,
          r.center.translate(0, isUp ? 0.5 : -0.5),
          h ? _accent : _muted,
          up: isUp,
        );
      }
    }
    final Rect? drop = f.drop;
    if (drop != null) {
      final bool h =
          _isHot(hot, _HitKind.presets, p) ||
          (_isHot(hot, _HitKind.palette, p) && hot!.rect == drop);
      if (h) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(drop.deflate(2), const Radius.circular(3)),
          Paint()..color = _accent.withValues(alpha: 0.15),
        );
      }
      ReportInspectorGlyphs.chevron(canvas, drop.center, h ? _accent : _muted);
    }
    if (editing) {
      _paintEditing(canvas, p, f.text);
      return;
    }
    final String raw = p.kind == ReportPropertyKind.multiline
        ? p.value.replaceAll('\n', ' ⏎ ')
        : p.value.trim();
    final bool empty = raw.isEmpty;
    if (empty && p.hint.isEmpty) {
      return;
    }
    final TextPainter tp = _text(
      empty ? p.hint : raw,
      _font,
      empty ? _muted : _ink,
      f.text.width - 2,
      italic: empty,
    );
    tp.paint(canvas, Offset(f.text.left, f.text.center.dy - tp.height / 2));
  }

  void _paintSwitch(Canvas canvas, Rect r, bool on, bool hover) {
    final RRect track = RRect.fromRectAndRadius(
      r,
      Radius.circular(r.height / 2),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..color = on ? _accent : _ink.withValues(alpha: hover ? 0.32 : 0.22),
    );
    final double knob = r.height - 4;
    final Offset c = Offset(
      on ? r.right - 2 - knob / 2 : r.left + 2 + knob / 2,
      r.center.dy,
    );
    canvas.drawCircle(
      c.translate(0, 0.6),
      knob / 2,
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawCircle(c, knob / 2, Paint()..color = const Color(0xFFFFFFFF));
  }

  void _paintSegments(
    Canvas canvas,
    ReportProperty p,
    Rect v,
    List<(String, Rect)> segments,
    _Hit? hot,
  ) {
    final Rect outer = Rect.fromLTRB(
      v.left,
      v.top,
      segments.last.$2.right,
      v.bottom,
    );
    final RRect rr = RRect.fromRectAndRadius(outer, const Radius.circular(4));
    canvas.drawRRect(rr, Paint()..color = _fieldFill);
    canvas.save();
    canvas.clipRRect(rr);
    for (int i = 0; i < segments.length; i++) {
      final (String option, Rect r) = segments[i];
      final bool selected = option == p.value;
      final bool h = _isHot(hot, _HitKind.segment, p, option);
      if (selected) {
        canvas.drawRect(r, Paint()..color = _accent);
      } else if (h) {
        canvas.drawRect(r, Paint()..color = _accent.withValues(alpha: 0.12));
      }
      if (i > 0 && !selected && segments[i - 1].$1 != p.value) {
        canvas.drawLine(
          Offset(r.left, r.top + 4),
          Offset(r.left, r.bottom - 4),
          Paint()..color = _line,
        );
      }
      final Color ink = selected ? const Color(0xFFFFFFFF) : _ink;
      if (ReportInspectorGlyphs.has(option)) {
        ReportInspectorGlyphs.paint(canvas, option, r, ink);
      } else {
        final TextPainter tp = _text(
          _optionLabel(option),
          10.5,
          ink,
          r.width - 4,
          bold: selected,
        );
        tp.paint(
          canvas,
          Offset(r.center.dx - tp.width / 2, r.center.dy - tp.height / 2),
        );
      }
    }
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..color = _line
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintGlyphButton(Canvas canvas, ReportProperty p, Rect r, _Hit? hot) {
    final bool on = p.value == 'true';
    final bool h = _isHot(hot, _HitKind.glyph, p);
    final RRect rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = on
            ? _accent.withValues(alpha: 0.16)
            : h
            ? _accent.withValues(alpha: 0.08)
            : _fieldFill,
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = on ? _accent : _line
        ..style = PaintingStyle.stroke,
    );
    ReportInspectorGlyphs.paint(canvas, p.glyph ?? '', r, on ? _accent : _ink);
  }

  void _paintAction(Canvas canvas, ReportProperty p, Rect button, _Hit? hot) {
    final bool danger = p.key.endsWith('.remove');
    final bool add = p.key.endsWith('+');
    final Color tone = danger ? const Color(0xFFC62828) : _accent;
    final bool h = _isHot(hot, _HitKind.action, p);
    final RRect rr = RRect.fromRectAndRadius(button, const Radius.circular(4));
    canvas.drawRRect(
      rr,
      Paint()..color = tone.withValues(alpha: h ? 0.16 : (add ? 0.08 : 0.04)),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = tone.withValues(alpha: h ? 0.8 : 0.45)
        ..style = PaintingStyle.stroke,
    );
    final TextPainter tp = _text(
      p.value,
      _font,
      tone,
      button.width - (_wideAction(p) ? 30 : 24),
      bold: add,
    );
    final double contentWidth = tp.width + (add ? 16 : 0);
    final double left = _wideAction(p)
        ? button.center.dx - contentWidth / 2
        : button.left + 12;
    if (add) {
      ReportInspectorGlyphs.plus(
        canvas,
        Offset(left + 5, button.center.dy),
        tone,
      );
    }
    tp.paint(
      canvas,
      Offset(left + (add ? 16 : 0), button.center.dy - tp.height / 2),
    );
  }

  void _paintEditing(Canvas canvas, ReportProperty p, Rect text) {
    final bool multi = p.kind == ReportPropertyKind.multiline;
    final TextPainter tp = _editPainter(p, _multilineWidth);
    final int caretIndex = _controller.propertyEditor.caretIndex;
    final Offset caret = tp.getOffsetForCaret(
      TextPosition(offset: caretIndex),
      Rect.zero,
    );
    final double inner = text.width - 4;
    if (!multi) {
      if (caret.dx - _editScrollX > inner) {
        _editScrollX = caret.dx - inner + 2;
      } else if (caret.dx < _editScrollX) {
        _editScrollX = caret.dx;
      }
    } else {
      _editScrollX = 0;
    }
    final Offset origin = Offset(
      text.left + 2 - _editScrollX,
      multi ? text.top + 4 : text.center.dy - tp.height / 2,
    );
    canvas.save();
    canvas.clipRect(text.deflate(1));
    final int start = _controller.propertyEditor.selectionStart;
    final int end = _controller.propertyEditor.selectionEnd;
    if (end > start) {
      for (final TextBox b in tp.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      )) {
        canvas.drawRect(
          b.toRect().shift(origin),
          Paint()..color = _accent.withValues(alpha: 0.28),
        );
      }
    }
    tp.paint(canvas, origin);
    final Rect caretRect = Rect.fromLTWH(
      origin.dx + caret.dx,
      origin.dy + caret.dy,
      1.2,
      tp.preferredLineHeight,
    );
    canvas.drawRect(caretRect, Paint()..color = const Color(0xFF111111));
    _editCaret = (
      Offset(math.max(text.left, caretRect.left - 24), caretRect.top),
      Offset(math.max(text.left, caretRect.left - 24), text.bottom + 3),
    );
    canvas.restore();
    tp.dispose();
  }

  // ------------------------------------------------------------ palette

  static const List<int> _themeColors = <int>[
    0xFFFFFF, 0x000000, 0xE7E6E6, 0x44546A, 0x4472C4, //
    0xED7D31, 0xA5A5A5, 0xFFC000, 0x5B9BD5, 0x70AD47,
  ];

  static const List<int> _standardColors = <int>[
    0xC00000, 0xFF0000, 0xFFC000, 0xFFFF00, 0x92D050, //
    0x00B050, 0x00B0F0, 0x0070C0, 0x002060, 0x7030A0,
  ];

  static int _shade(int rgb, int row) {
    if (row == 0) {
      return rgb;
    }
    final List<double> f;
    final bool lighten;
    if (rgb == 0xFFFFFF) {
      f = const <double>[0.05, 0.15, 0.25, 0.35, 0.5];
      lighten = false;
    } else if (rgb == 0x000000) {
      f = const <double>[0.5, 0.35, 0.25, 0.15, 0.05];
      lighten = true;
    } else {
      final double k = const <double>[0.8, 0.6, 0.4, 0.25, 0.5][row - 1];
      final bool up = row <= 3;
      return _mix(rgb, k, lighten: up);
    }
    return _mix(rgb, f[row - 1], lighten: lighten);
  }

  static int _mix(int rgb, double k, {required bool lighten}) {
    int ch(int c) => lighten
        ? (c + (255 - c) * k).round().clamp(0, 255)
        : (c * (1 - k)).round().clamp(0, 255);
    final int r = ch((rgb >> 16) & 0xFF);
    final int g = ch((rgb >> 8) & 0xFF);
    final int b = ch(rgb & 0xFF);
    return (r << 16) | (g << 8) | b;
  }

  static String _hex(int rgb) =>
      '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _layoutPalette() {
    _swatches = <_Swatch>[];
    _paletteRect = null;
    final String? key = _paletteKey;
    final Rect? text = key == null ? null : _textRectFor(key);
    final Rect? anchor =
        _paletteAnchor ??
        (text == null
            ? null
            : Rect.fromLTRB(text.left - 24, text.top, text.right, text.bottom));
    if (key == null || anchor == null) {
      return;
    }
    const double cell = 18;
    const double gap = 3;
    const double pad = 10;
    const double caption = 18;
    const int cols = 10;
    const double w = pad * 2 + cols * cell + (cols - 1) * gap;
    final List<MapEntry<String, String>> named = _controller
        .template
        .colors
        .entries
        .take(20)
        .toList();
    final int namedRows = (named.length / cols).ceil();
    final double h =
        pad +
        24 +
        8 +
        (named.isEmpty ? 0 : caption + namedRows * (cell + gap)) +
        caption +
        6 * (cell + gap) +
        caption +
        (cell + gap) +
        22;
    var x = anchor.left;
    x = x.clamp(4, math.max(4, size.width - w - 4)).toDouble();
    var y = anchor.bottom + 4;
    if (y + h > size.height - 4) {
      y = math.max(4, anchor.top - h - 4);
    }
    final Rect rect = Rect.fromLTWH(x, y, w, h);
    _paletteRect = rect;
    var top = rect.top + pad;
    _swatches.add(
      _Swatch(
        Rect.fromLTWH(rect.left + pad, top, w - 2 * pad, 24),
        '',
        null,
        'No color',
      ),
    );
    top += 24 + 8;
    Rect at(int i, double rowTop) => Rect.fromLTWH(
      rect.left + pad + (i % cols) * (cell + gap),
      rowTop + (i ~/ cols) * (cell + gap),
      cell,
      cell,
    );
    if (named.isNotEmpty) {
      top += caption;
      for (int i = 0; i < named.length; i++) {
        final ReportColor c = _controller.template.resolveColor(
          named[i].value,
          ReportColor.transparent,
        );
        _swatches.add(
          _Swatch(
            at(i, top),
            named[i].key,
            Color(c.argb),
            '${named[i].key} · ${named[i].value}',
          ),
        );
      }
      top += namedRows * (cell + gap);
    }
    top += caption;
    for (int row = 0; row < 6; row++) {
      for (int col = 0; col < cols; col++) {
        final int rgb = _shade(_themeColors[col], row);
        _swatches.add(
          _Swatch(
            at(col, top + row * (cell + gap)),
            _hex(rgb),
            Color(0xFF000000 | rgb),
            _hex(rgb),
          ),
        );
      }
    }
    top += 6 * (cell + gap) + caption;
    for (int col = 0; col < cols; col++) {
      final int rgb = _standardColors[col];
      _swatches.add(
        _Swatch(at(col, top), _hex(rgb), Color(0xFF000000 | rgb), _hex(rgb)),
      );
    }
  }

  void _paintPalette(Canvas canvas) {
    _layoutPalette();
    final Rect? rect = _paletteRect;
    final String? key = _paletteKey;
    if (rect == null || key == null) {
      return;
    }
    String current = '';
    for (final ReportProperty p in _controller.properties) {
      if (p.key == key) {
        current = p.value.trim().toLowerCase();
      }
    }
    final RRect rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(
      rr.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = _theme.pageBorder
        ..style = PaintingStyle.stroke,
    );
    const Color ink = Color(0xFF1F2937);
    const Color soft = Color(0xFF6B7280);
    final Offset? hover = _hover;
    String footer = current.isEmpty ? 'No color' : current;
    void caption(String text, double y) {
      _text(
        text,
        10,
        soft,
        rect.width - 20,
        bold: true,
      ).paint(canvas, Offset(rect.left + 10, y));
    }

    final List<_Swatch> swatches = _swatches;
    final _Swatch none = swatches.first;
    final bool namedPresent = _controller.template.colors.isNotEmpty;
    if (namedPresent) {
      caption('TEMPLATE PALETTE', none.rect.bottom + 10);
    }
    final int namedCount = math.min(20, _controller.template.colors.length);
    final _Swatch firstTheme = swatches[1 + namedCount];
    caption('THEME COLORS', firstTheme.rect.top - 15);
    final _Swatch firstStandard = swatches[1 + namedCount + 60];
    caption('STANDARD COLORS', firstStandard.rect.top - 15);
    for (final _Swatch s in swatches) {
      final bool hot = hover != null && s.rect.contains(hover);
      if (hot) {
        footer = s.label;
      }
      final bool selected =
          s.value.toLowerCase() == current &&
          (s.value.isNotEmpty || current.isEmpty);
      final Color? color = s.color;
      if (color == null) {
        final RRect b = RRect.fromRectAndRadius(
          s.rect,
          const Radius.circular(4),
        );
        canvas.drawRRect(
          b,
          Paint()
            ..color = hot ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
        );
        canvas.drawRRect(
          b,
          Paint()
            ..color = selected ? _accent : const Color(0xFFD1D5DB)
            ..style = PaintingStyle.stroke,
        );
        final Rect icon = Rect.fromLTWH(
          s.rect.left + 6,
          s.rect.center.dy - 7,
          14,
          14,
        );
        ReportInspectorGlyphs.noColor(canvas, icon);
        canvas.drawRect(
          icon,
          Paint()
            ..color = const Color(0xFF9CA3AF)
            ..style = PaintingStyle.stroke,
        );
        final TextPainter tp = _text('No color', _font, ink, 120);
        tp.paint(
          canvas,
          Offset(icon.right + 8, s.rect.center.dy - tp.height / 2),
        );
        continue;
      }
      canvas.drawRect(s.rect, Paint()..color = color);
      canvas.drawRect(
        s.rect,
        Paint()
          ..color = const Color(0x22000000)
          ..style = PaintingStyle.stroke,
      );
      if (hot || selected) {
        canvas.drawRect(
          s.rect.inflate(1.5),
          Paint()
            ..color = selected ? _accent : const Color(0xFF374151)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }
    _text(
      footer,
      10.5,
      soft,
      rect.width - 20,
    ).paint(canvas, Offset(rect.left + 10, rect.bottom - 18));
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..textDirection = TextDirection.ltr
      ..label = 'Report properties'
      ..value = _controller.inspectorTitle;
  }
}
