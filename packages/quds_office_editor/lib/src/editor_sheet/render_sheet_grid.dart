import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:quds_office_engine/quds_office_engine.dart';

import '../core/virtual_viewport.dart';
import '../embed/office_context_menu.dart';
import '../embed/office_theme.dart';
import '../editor_word/paint_run_text.dart';
import '../editor_slide/transform_handles.dart';
import '../ui_components/office_chrome.dart';
import '../visual/paint_office_visual.dart';
import 'formula_ref_style.dart';
import 'selection_matrix.dart';
import 'sheet_scroll_extent.dart';

enum _HeaderDrag { none, rows, columns }

/// Class SheetGrid.
class SheetGrid extends LeafRenderObjectWidget {
  /// SheetGrid API.
  const SheetGrid({
    super.key,
    required this.sheet,
    required this.selection,
    this.rowHeight = 20,
    this.colWidth = 64,
    this.frozenRows = 0,
    this.frozenCols = 0,
    this.formulaBar = '',
    this.config = const OfficeSurfaceConfig(),
    this.hasFocus = false,
    this.semanticsLabel = '',
    this.semanticsValue = '',
    this.viewport,
    this.selectedDrawingIndex,
    this.editing = false,
    this.editText = '',
    this.editCaret = 0,
    this.editBase = 0,
    this.cellLabel,
    this.onChanged,
    this.onActivate,
    this.onSelectDrawing,
    this.onActivateDrawing,
    this.onPlaceEditCaret,
    this.onCommitEdit,
    this.onPointRef,
    this.functionSuggestions = const <FormulaFnDoc>[],
    this.functionSuggestionIndex = 0,
    this.functionTooltipArabic = false,
    this.onHighlightFunction,
    this.onApplyFunction,
    this.onResizeColumn,
    this.onResizeRow,
    this.onCommitResize,
    this.onBeginDrawingTransform,
    this.onMoveDrawing,
    this.onResizeDrawing,
    this.onCommitDrawingTransform,
    this.onContextMenu,
    this.onInsertRowAt,
    this.onInsertColAt,
  });

  /// sheet API.
  final SmlWorksheet sheet;

  /// selection API.
  final SelectionMatrix selection;

  /// rowHeight API.
  final double rowHeight;

  /// colWidth API.
  final double colWidth;

  /// frozenRows API.
  final int frozenRows;

  /// frozenCols API.
  final int frozenCols;

  /// formulaBar API.
  final String formulaBar;

  /// config API.
  final OfficeSurfaceConfig config;

  /// hasFocus API.
  final bool hasFocus;

  /// semanticsLabel API.
  final String semanticsLabel;

  /// semanticsValue API.
  final String semanticsValue;

  /// viewport API.
  final VirtualViewport? viewport;

  /// selectedDrawingIndex API.
  final int? selectedDrawingIndex;

  /// editing API.
  final bool editing;

  /// editText API.
  final String editText;

  /// editCaret API.
  final int editCaret;

  /// editBase API.
  final int editBase;

  /// Function API.
  final String Function(SmlCell cell)? cellLabel;

  /// onChanged API.
  final VoidCallback? onChanged;

  /// onActivate API.
  final VoidCallback? onActivate;

  /// onSelectDrawing API.
  final ValueChanged<int?>? onSelectDrawing;

  /// onActivateDrawing API.
  final VoidCallback? onActivateDrawing;

  /// onPlaceEditCaret API.
  final ValueChanged<int>? onPlaceEditCaret;

  /// onCommitEdit API.
  final VoidCallback? onCommitEdit;

  /// Function API.
  final void Function(SmlCellRef ref, {required bool extend})? onPointRef;

  /// functionSuggestions API.
  final List<FormulaFnDoc> functionSuggestions;

  /// functionSuggestionIndex API.
  final int functionSuggestionIndex;

  /// functionTooltipArabic API.
  final bool functionTooltipArabic;

  /// onHighlightFunction API.
  final ValueChanged<int>? onHighlightFunction;

  /// onApplyFunction API.
  final ValueChanged<int>? onApplyFunction;

  /// Function API.
  final void Function(int col, double width)? onResizeColumn;

  /// Function API.
  final void Function(int row, double height)? onResizeRow;

  /// onCommitResize API.
  final VoidCallback? onCommitResize;

  /// onBeginDrawingTransform API.
  final VoidCallback? onBeginDrawingTransform;

  /// Function API.
  final void Function(double dx, double dy)? onMoveDrawing;

  /// Function API.
  final void Function({
    required double left,
    required double top,
    required double width,
    required double height,
  })?
  /// onResizeDrawing API.
  onResizeDrawing;

  /// onCommitDrawingTransform API.
  final VoidCallback? onCommitDrawingTransform;

  /// onContextMenu API.
  final ValueChanged<OfficeContextHit>? onContextMenu;

  /// onInsertRowAt API.
  final ValueChanged<int>? onInsertRowAt;

  /// onInsertColAt API.
  final ValueChanged<int>? onInsertColAt;

  @override
  /// createRenderObject API.
  RenderSheetGrid createRenderObject(BuildContext context) {
    return RenderSheetGrid(
      sheet: sheet,
      selection: selection,
      rowHeight: rowHeight,
      colWidth: colWidth,
      frozenRows: frozenRows,
      frozenCols: frozenCols,
      formulaBar: formulaBar,
      config: config,
      hasFocus: hasFocus,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
      viewport: viewport ?? VirtualViewport(),
      selectedDrawingIndex: selectedDrawingIndex,
      editing: editing,
      editText: editText,
      editCaret: editCaret,
      editBase: editBase,
      cellLabel: cellLabel,
      onChanged: onChanged,
      onActivate: onActivate,
      onSelectDrawing: onSelectDrawing,
      onActivateDrawing: onActivateDrawing,
      onPlaceEditCaret: onPlaceEditCaret,
      onCommitEdit: onCommitEdit,
      onPointRef: onPointRef,
      functionSuggestions: functionSuggestions,
      functionSuggestionIndex: functionSuggestionIndex,
      functionTooltipArabic: functionTooltipArabic,
      onHighlightFunction: onHighlightFunction,
      onApplyFunction: onApplyFunction,
      onResizeColumn: onResizeColumn,
      onResizeRow: onResizeRow,
      onCommitResize: onCommitResize,
      onBeginDrawingTransform: onBeginDrawingTransform,
      onMoveDrawing: onMoveDrawing,
      onResizeDrawing: onResizeDrawing,
      onCommitDrawingTransform: onCommitDrawingTransform,
      onContextMenu: onContextMenu,
      onInsertRowAt: onInsertRowAt,
      onInsertColAt: onInsertColAt,
    );
  }

  @override
  /// updateRenderObject API.
  void updateRenderObject(BuildContext context, RenderSheetGrid renderObject) {
    renderObject
      ..sheet = sheet
      ..selection = selection
      ..rowHeight = rowHeight
      ..colWidth = colWidth
      ..frozenRows = frozenRows
      ..frozenCols = frozenCols
      ..formulaBar = formulaBar
      ..config = config
      ..hasFocus = hasFocus
      ..semanticsLabel = semanticsLabel
      ..semanticsValue = semanticsValue
      ..selectedDrawingIndex = selectedDrawingIndex
      ..editing = editing
      ..editText = editText
      ..editCaret = editCaret
      ..editBase = editBase
      ..cellLabel = cellLabel
      ..onChanged = onChanged
      ..onActivate = onActivate
      ..onSelectDrawing = onSelectDrawing
      ..onActivateDrawing = onActivateDrawing
      ..onPlaceEditCaret = onPlaceEditCaret
      ..onCommitEdit = onCommitEdit
      ..onPointRef = onPointRef
      ..functionSuggestions = functionSuggestions
      ..functionSuggestionIndex = functionSuggestionIndex
      ..functionTooltipArabic = functionTooltipArabic
      ..onHighlightFunction = onHighlightFunction
      ..onApplyFunction = onApplyFunction
      ..onResizeColumn = onResizeColumn
      ..onResizeRow = onResizeRow
      ..onCommitResize = onCommitResize
      ..onBeginDrawingTransform = onBeginDrawingTransform
      ..onMoveDrawing = onMoveDrawing
      ..onResizeDrawing = onResizeDrawing
      ..onCommitDrawingTransform = onCommitDrawingTransform
      ..onContextMenu = onContextMenu
      ..onInsertRowAt = onInsertRowAt
      ..onInsertColAt = onInsertColAt;
    if (viewport != null) {
      renderObject.viewport = viewport!;
    }
    renderObject.markNeedsPaint();
  }
}

/// Class RenderSheetGrid.
class RenderSheetGrid extends RenderBox implements MouseTrackerAnnotation {
  /// RenderSheetGrid API.
  RenderSheetGrid({
    required this.sheet,
    required this.selection,
    required this.rowHeight,
    required this.colWidth,
    required this.frozenRows,
    required this.frozenCols,
    required this.formulaBar,
    required this.config,
    required this.hasFocus,
    required this.semanticsLabel,
    required this.semanticsValue,
    required this.viewport,
    this.selectedDrawingIndex,
    this.editing = false,
    this.editText = '',
    this.editCaret = 0,
    this.editBase = 0,
    this.cellLabel,
    this.onChanged,
    this.onActivate,
    this.onSelectDrawing,
    this.onActivateDrawing,
    this.onPlaceEditCaret,
    this.onCommitEdit,
    this.onPointRef,
    this.functionSuggestions = const <FormulaFnDoc>[],
    this.functionSuggestionIndex = 0,
    this.functionTooltipArabic = false,
    this.onHighlightFunction,
    this.onApplyFunction,
    this.onResizeColumn,
    this.onResizeRow,
    this.onCommitResize,
    this.onBeginDrawingTransform,
    this.onMoveDrawing,
    this.onResizeDrawing,
    this.onCommitDrawingTransform,
    this.onContextMenu,
    this.onInsertRowAt,
    this.onInsertColAt,
  });

  /// sheet API.
  SmlWorksheet sheet;

  /// selection API.
  SelectionMatrix selection;

  /// rowHeight API.
  double rowHeight;

  /// colWidth API.
  double colWidth;

  /// frozenRows API.
  int frozenRows;

  /// frozenCols API.
  int frozenCols;

  /// formulaBar API.
  String formulaBar;

  /// config API.
  OfficeSurfaceConfig config;

  /// hasFocus API.
  bool hasFocus;

  /// semanticsLabel API.
  String semanticsLabel;

  /// semanticsValue API.
  String semanticsValue;

  /// viewport API.
  VirtualViewport viewport;

  /// selectedDrawingIndex API.
  int? selectedDrawingIndex;

  /// editing API.
  bool editing;

  /// editText API.
  String editText;

  /// editCaret API.
  int editCaret;

  /// editBase API.
  int editBase;

  /// Function API.
  String Function(SmlCell cell)? cellLabel;

  /// onChanged API.
  VoidCallback? onChanged;

  /// onActivate API.
  VoidCallback? onActivate;

  /// onSelectDrawing API.
  ValueChanged<int?>? onSelectDrawing;

  /// onActivateDrawing API.
  VoidCallback? onActivateDrawing;

  /// onPlaceEditCaret API.
  ValueChanged<int>? onPlaceEditCaret;

  /// onCommitEdit API.
  VoidCallback? onCommitEdit;

  /// Function API.
  void Function(SmlCellRef ref, {required bool extend})? onPointRef;

  /// functionSuggestions API.
  List<FormulaFnDoc> functionSuggestions;

  /// functionSuggestionIndex API.
  int functionSuggestionIndex;

  /// functionTooltipArabic API.
  bool functionTooltipArabic;

  /// onHighlightFunction API.
  ValueChanged<int>? onHighlightFunction;

  /// onApplyFunction API.
  ValueChanged<int>? onApplyFunction;

  /// Function API.
  void Function(int col, double width)? onResizeColumn;

  /// Function API.
  void Function(int row, double height)? onResizeRow;

  /// onCommitResize API.
  VoidCallback? onCommitResize;

  /// onBeginDrawingTransform API.
  VoidCallback? onBeginDrawingTransform;

  /// Function API.
  void Function(double dx, double dy)? onMoveDrawing;

  /// Function API.
  void Function({
    required double left,
    required double top,
    required double width,
    required double height,
  })?
  /// onResizeDrawing API.
  onResizeDrawing;

  /// onCommitDrawingTransform API.
  VoidCallback? onCommitDrawingTransform;

  /// onContextMenu API.
  ValueChanged<OfficeContextHit>? onContextMenu;

  /// onInsertRowAt API.
  ValueChanged<int>? onInsertRowAt;

  /// onInsertColAt API.
  ValueChanged<int>? onInsertColAt;
  DateTime? _lastTap;
  Rect? _functionListRect;
  PanGestureRecognizer? _pan;
  Offset? _hoverLocal;
  int? _resizeCol;
  int? _resizeRow;
  double _resizeStart = 0;
  double _resizeAccum = 0;
  int? _drawingHandle;
  var _drawingMove = false;
  var _scrollH = false;
  var _scrollV = false;

  /// none API.
  var _headerDrag = _HeaderDrag.none;
  static const double _scrollBar = 12;

  /// VisualImageCache API.
  final VisualImageCache _images = VisualImageCache();

  /// theme API.
  OfficeTheme get _theme => config.theme;

  double get _barH => config.showFormulaBar ? 28 : 0;
  double get _headH => config.showGridHeaders ? 20 : 0;
  double get _headW => config.showGridHeaders ? 28 : 0;

  /// rightToLeft API.
  bool get _rtl => sheet.rightToLeft;
  double get _rowHeadLeft => _rtl ? size.width - _headW : 0;
  static const double _resizeSlop = 4;

  /// excelColumnCount API.
  static const int _excelCols = SmlWorksheet.excelColumnCount;

  /// excelRowCount API.
  static const int _excelRows = SmlWorksheet.excelRowCount;

  @override
  /// cursor API.
  MouseCursor get cursor => _cursorFor(_hoverLocal);

  @override
  /// onEnter API.
  PointerEnterEventListener? get onEnter => null;

  @override
  /// onExit API.
  PointerExitEventListener? get onExit => (_) {
    _hoverLocal = null;
  };

  @override
  /// validForMouseTracker API.
  bool get validForMouseTracker => attached;

  MouseCursor _cursorFor(Offset? local) {
    if (local == null || !config.allowsMutation) {
      return SystemMouseCursors.basic;
    }
    if (_sheetInsertHit(local) != null) {
      return SystemMouseCursors.click;
    }
    if (_hitColResize(local) != null) {
      return SystemMouseCursors.resizeColumn;
    }
    if (_hitRowResize(local) != null) {
      return SystemMouseCursors.resizeRow;
    }
    if (_hitScrollBar(local) != null) {
      return SystemMouseCursors.grab;
    }
    final int? handle = _hitDrawingHandle(local);
    if (handle != null) {
      return _cursorForHandle(handle);
    }
    if (selectedDrawingIndex != null &&
        _hitDrawing(local) == selectedDrawingIndex) {
      return SystemMouseCursors.move;
    }
    return SystemMouseCursors.basic;
  }

  static MouseCursor _cursorForHandle(int handle) {
    return switch (handle) {
      0 || 4 => SystemMouseCursors.resizeUpLeftDownRight,
      2 || 6 => SystemMouseCursors.resizeUpRightDownLeft,
      1 || 5 => SystemMouseCursors.resizeUpDown,
      _ => SystemMouseCursors.resizeLeftRight,
    };
  }

  /// columnWidth API.
  double _colWAt(int col) => sheet.columnWidth(col) * viewport.scale;

  /// rowHeightAt API.
  double _rowHAt(int row) => sheet.rowHeightAt(row) * viewport.scale;

  int get _fr {
    final int n = frozenRows > 0 ? frozenRows : sheet.freezeRows;
    return n.clamp(0, _excelRows);
  }

  int get _fc {
    final int n = frozenCols > 0 ? frozenCols : sheet.freezeCols;
    return n.clamp(0, _excelCols);
  }

  /// columnLeft API.
  double get _frozenW => sheet.columnLeft(_fc) * viewport.scale;

  /// rowTop API.
  double get _frozenH => sheet.rowTop(_fr) * viewport.scale;

  Rect get _unfrozenRect {
    if (_rtl) {
      return Rect.fromLTRB(
        0,
        _barH + _headH + _frozenH,
        size.width - _headW - _frozenW,
        size.height,
      );
    }
    return Rect.fromLTRB(
      _headW + _frozenW,
      _barH + _headH + _frozenH,
      size.width,
      size.height,
    );
  }

  Rect get _frozenRowBand {
    return Rect.fromLTWH(0, _barH + _headH, size.width, _frozenH);
  }

  Rect get _frozenColBand {
    if (_rtl) {
      return Rect.fromLTWH(
        size.width - _headW - _frozenW,
        _barH + _headH + _frozenH,
        _frozenW,
        size.height - _barH - _headH - _frozenH,
      );
    }
    return Rect.fromLTWH(
      _headW,
      _barH + _headH + _frozenH,
      _frozenW,
      size.height - _barH - _headH - _frozenH,
    );
  }

  void _paintCellRange(
    Canvas canvas, {
    required int r0,
    required int r1,
    required int c0,
    required int c1,
    required List<(FormulaRefSpan, Color)> formulaRefs,
    bool frozen = false,
  }) {
    if (r1 <= r0 || c1 <= c0) {
      return;
    }
    for (int r = r0; r < r1; r++) {
      for (int c = c0; c < c1; c++) {
        final ui.Rect cell = _cellRect(c, r);
        if (frozen) {
          canvas.drawRect(cell, ui.Paint()..color = _theme.frozenFill);
        }
        final bool focusCell =
            selection.focus.col == c && selection.focus.row == r;
        final bool isEdit = editing && focusCell;
        if (isEdit) {
          canvas.drawRect(cell, ui.Paint()..color = _theme.pageBackground);
        } else if (config.allowsSelection &&
            selection.contains(SmlCellRef(c, r))) {
          canvas.drawRect(cell, ui.Paint()..color = _theme.selectionFill);
        }
        if (config.showGridlines) {
          canvas.drawRect(
            cell,
            ui.Paint()
              ..color = isEdit ? _theme.focusRing : _theme.gridLine
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = isEdit ? 1.6 : 1,
          );
        }
      }
    }
    if (formulaRefs.isNotEmpty) {
      _paintFormulaRefs(canvas, refs: formulaRefs, borders: false);
      if (editing) {
        final ui.Rect editCell = _cellRect(
          selection.focus.col,
          selection.focus.row,
        );
        canvas.drawRect(editCell, ui.Paint()..color = _theme.pageBackground);
        if (config.showGridlines) {
          canvas.drawRect(
            editCell,
            ui.Paint()
              ..color = _theme.focusRing
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = 1.6,
          );
        }
      }
    }
    for (int r = r0; r < r1; r++) {
      for (int c = c0; c < c1; c++) {
        final ui.Rect cell = _cellRect(c, r);
        final bool isEdit =
            editing && selection.focus.col == c && selection.focus.row == r;
        final SmlCell data = sheet.cell(SmlCellRef(c, r));
        final String label = isEdit
            ? editText
            : (cellLabel?.call(data) ?? data.asString);
        if (label.isNotEmpty || isEdit) {
          _paintCellText(canvas, cell, label, isEdit: isEdit);
        }
      }
    }
    if (formulaRefs.isNotEmpty) {
      _paintFormulaRefs(canvas, refs: formulaRefs, borders: true);
    }
  }

  Size get _sheetContentSize {
    return SheetScrollExtent.contentSize(
      sheet: sheet,
      selection: selection,
      scale: viewport.scale,
      headW: _headW,
      headH: _headH,
      barH: _barH,
      scrollBar: _scrollBar,
    );
  }

  void _clampViewport() {
    viewport.clampTo(content: _sheetContentSize, view: size);
  }

  int _lastVisibleCol(int firstCol) {
    final double limit = viewport.origin.dx + size.width + 8;
    var col = firstCol;
    while (col < _excelCols && sheet.columnLeft(col) * viewport.scale < limit) {
      col++;
      if (col - firstCol > 80) {
        break;
      }
    }
    return col.clamp(firstCol + 1, _excelCols);
  }

  int _lastVisibleRow(int firstRow) {
    final double limit = viewport.origin.dy + size.height + 8;
    var row = firstRow;
    while (row < _excelRows && sheet.rowTop(row) * viewport.scale < limit) {
      row++;
      if (row - firstRow > 120) {
        break;
      }
    }
    return row.clamp(firstRow + 1, _excelRows);
  }

  int? _hitFunctionAssist(Offset local) {
    final Rect? box = _functionListRect;
    if (box == null || functionSuggestions.isEmpty || !box.contains(local)) {
      return null;
    }
    const double rowH = 22;
    final int index = ((local.dy - box.top) / rowH).floor();
    if (index < 0 || index >= functionSuggestions.length) {
      return null;
    }
    return index;
  }

  void _paintFunctionAssist(Canvas canvas) {
    _functionListRect = null;
    if (!editing || functionSuggestions.isEmpty) {
      return;
    }
    const double rowH = 22;
    const double listW = 188;
    const double tipW = 248;
    final int visible = functionSuggestions.length < 8
        ? functionSuggestions.length
        : 8;
    final double listH = visible * rowH;
    final Rect edit = _cellRect(selection.focus.col, selection.focus.row);
    var left = edit.left;
    var top = edit.bottom + 2;
    if (top + listH > size.height - 4) {
      top = edit.top - listH - 2;
    }
    if (top < _barH + 2) {
      top = _barH + 2;
    }
    if (left + listW + 8 + tipW > size.width) {
      left = size.width - listW - tipW - 12;
    }
    if (left < 4) {
      left = 4;
    }
    final Rect list = Rect.fromLTWH(left, top, listW, listH);
    _functionListRect = list;
    canvas.drawRect(list, Paint()..color = _theme.pageBackground);
    canvas.drawRect(
      list,
      Paint()
        ..color = _theme.pageBorder
        ..style = PaintingStyle.stroke,
    );
    for (int i = 0; i < visible; i++) {
      final Rect row = Rect.fromLTWH(
        list.left,
        list.top + i * rowH,
        listW,
        rowH,
      );
      if (i == functionSuggestionIndex) {
        canvas.drawRect(row, Paint()..color = _theme.selectionFill);
      }
      final TextPainter name = PaintRunText.plain(
        text: functionSuggestions[i].name,
        fontSize: 11,
        color: i == functionSuggestionIndex
            ? _theme.focusRing
            : _theme.chromeText,
        themeFamily: _theme.fontFamily,
      )..layout(maxWidth: listW - 12);
      name.paint(
        canvas,
        Offset(row.left + 6, row.top + (rowH - name.height) / 2),
      );
    }
    final FormulaFnDoc tip =
        functionSuggestions[functionSuggestionIndex.clamp(
          0,
          functionSuggestions.length - 1,
        )];
    final Rect tipBox = Rect.fromLTWH(
      list.right + 6,
      list.top,
      tipW,
      listH < 88 ? 88 : listH,
    );
    canvas.drawRect(tipBox, Paint()..color = _theme.chromeFill);
    canvas.drawRect(
      tipBox,
      Paint()
        ..color = _theme.focusRing
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final String body =
        '${tip.syntax}\n${tip.summary(functionTooltipArabic)}'
        '${tip.example.isEmpty ? '' : '\n${tip.example}'}';
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: body,
        style: TextStyle(
          color: _theme.chromeText,
          fontSize: 11,
          height: 1.25,
          fontFamily: _theme.fontFamily,
        ),
      ),
      textDirection: functionTooltipArabic
          ? TextDirection.rtl
          : TextDirection.ltr,
      maxLines: 8,
    )..layout(maxWidth: tipW - 12);
    painter.paint(canvas, Offset(tipBox.left + 6, tipBox.top + 6));
  }

  bool get _canPointRefs {
    if (!editing || onPointRef == null) {
      return false;
    }
    final String text = editText.trimLeft();
    return text.isEmpty || text.startsWith('=');
  }

  @override
  /// hitTestSelf API.
  bool hitTestSelf(Offset position) {
    _hoverLocal = position;
    return true;
  }

  @override
  /// performLayout API.
  void performLayout() {
    size = constraints.hasBoundedWidth && constraints.hasBoundedHeight
        ? constraints.constrain(constraints.biggest)
        : constraints.constrain(
            Size(colWidth * 16 + _headW, rowHeight * 40 + _headH + _barH),
          );
    viewport.extent = size;
  }

  @override
  /// detach API.
  void detach() {
    _pan?.dispose();
    _pan = null;
    super.detach();
  }

  @override
  /// handleEvent API.
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerHoverEvent) {
      _hoverLocal = event.localPosition;
      return;
    }
    if (event is PointerScrollEvent) {
      if (HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed) {
        viewport.setScale(
          viewport.scale * (event.scrollDelta.dy > 0 ? 0.9 : 1.1),
        );
      } else if (HardwareKeyboard.instance.isShiftPressed) {
        viewport.pan(Offset(event.scrollDelta.dy, event.scrollDelta.dx));
      } else {
        viewport.pan(Offset(event.scrollDelta.dx, event.scrollDelta.dy));
      }
      _clampViewport();
      markNeedsPaint();
      onChanged?.call();
      return;
    }
    if (!config.allowsSelection) {
      return;
    }
    if (event is PointerDownEvent) {
      if (event.buttons == kSecondaryMouseButton) {
        _handleContext(event);
        return;
      }
      final _SheetInsertHit? insert = _sheetInsertHit(event.localPosition);
      if (insert != null && config.allowsMutation) {
        if (insert.column) {
          onInsertColAt?.call(insert.index);
        } else {
          onInsertRowAt?.call(insert.index);
        }
        markNeedsPaint();
        onChanged?.call();
        return;
      }
      final int? functionHit = _hitFunctionAssist(event.localPosition);
      if (functionHit != null) {
        final DateTime now = DateTime.now();
        final bool doubleTap =
            _lastTap != null && now.difference(_lastTap!).inMilliseconds < 400;
        _lastTap = now;
        onHighlightFunction?.call(functionHit);
        if (doubleTap) {
          onApplyFunction?.call(functionHit);
        }
        markNeedsPaint();
        onChanged?.call();
        return;
      }
      _ensurePan();
      _pan!.addPointer(event);
      final String? bar = _hitScrollBar(event.localPosition);
      if (bar != null) {
        _scrollH = bar == 'h';
        _scrollV = bar == 'v';
        _jumpScroll(event.localPosition);
        return;
      }
      if (config.allowsMutation) {
        final int? resizeCol = _hitColResize(event.localPosition);
        if (resizeCol != null) {
          _resizeCol = resizeCol;
          _resizeRow = null;
          _resizeStart = sheet.columnWidth(resizeCol);
          _resizeAccum = 0;
          return;
        }
        final int? resizeRow = _hitRowResize(event.localPosition);
        if (resizeRow != null) {
          _resizeRow = resizeRow;
          _resizeCol = null;
          _resizeStart = sheet.rowHeightAt(resizeRow);
          _resizeAccum = 0;
          return;
        }
      }
      final int? handleHit = _hitDrawingHandle(event.localPosition);
      final int? drawingIndex =
          _hitDrawing(event.localPosition) ??
          (handleHit != null ? selectedDrawingIndex : null);
      if (drawingIndex != null) {
        if (editing) {
          onCommitEdit?.call();
        }
        final DateTime now = DateTime.now();
        final bool doubleTap =
            _lastTap != null && now.difference(_lastTap!).inMilliseconds < 400;
        _lastTap = now;
        selectedDrawingIndex = drawingIndex;
        onSelectDrawing?.call(drawingIndex);
        if (doubleTap && config.allowsMutation) {
          onActivateDrawing?.call();
        } else if (config.allowsMutation) {
          _drawingHandle = _hitDrawingHandle(event.localPosition);
          _drawingMove = _drawingHandle == null;
          onBeginDrawingTransform?.call();
        }
        markNeedsPaint();
        onChanged?.call();
        return;
      }
      onSelectDrawing?.call(null);
      final SmlCellRef? ref = _hitCell(event.localPosition);
      if (ref == null) {
        return;
      }
      if (_isRowHeader(event.localPosition)) {
        if (_canPointRefs) {
          onPointRef?.call(
            ref,
            extend: HardwareKeyboard.instance.isShiftPressed,
          );
        } else {
          if (editing) {
            onCommitEdit?.call();
          }
          _headerDrag = _HeaderDrag.rows;
          if (HardwareKeyboard.instance.isShiftPressed) {
            selection.extendRowsTo(ref.row);
          } else {
            selection.selectRow(ref.row);
          }
        }
      } else if (event.localPosition.dy < _barH + _headH &&
          event.localPosition.dy >= _barH &&
          config.showGridHeaders) {
        if (_canPointRefs) {
          onPointRef?.call(
            ref,
            extend: HardwareKeyboard.instance.isShiftPressed,
          );
        } else {
          if (editing) {
            onCommitEdit?.call();
          }
          _headerDrag = _HeaderDrag.columns;
          if (HardwareKeyboard.instance.isShiftPressed) {
            selection.extendColumnsTo(ref.col);
          } else {
            selection.selectColumn(ref.col);
          }
        }
      } else if (HardwareKeyboard.instance.isShiftPressed) {
        if (_canPointRefs) {
          onPointRef?.call(ref, extend: true);
        } else {
          if (editing) {
            onCommitEdit?.call();
          }
          selection.extendTo(ref);
        }
      } else {
        final DateTime now = DateTime.now();
        final bool doubleTap =
            _lastTap != null && now.difference(_lastTap!).inMilliseconds < 400;
        _lastTap = now;
        if (editing &&
            ref.col == selection.focus.col &&
            ref.row == selection.focus.row) {
          onPlaceEditCaret?.call(_hitEditIndex(event.localPosition, ref));
        } else if (_canPointRefs) {
          onPointRef?.call(ref, extend: false);
        } else {
          if (editing) {
            onCommitEdit?.call();
          }
          _headerDrag = _HeaderDrag.none;
          selection.selectCell(ref);
          if (doubleTap && config.allowsMutation) {
            onActivate?.call();
          }
        }
      }
      markNeedsPaint();
      onChanged?.call();
    }
  }

  void _ensurePan() {
    _pan ??= PanGestureRecognizer(debugOwner: this)
      ..onUpdate = (DragUpdateDetails details) {
        if (_resizeCol != null) {
          final double dx = _rtl ? -details.delta.dx : details.delta.dx;
          _resizeAccum += dx;
          onResizeColumn?.call(
            _resizeCol!,
            _resizeStart + _resizeAccum / viewport.scale,
          );
          markNeedsPaint();
          onChanged?.call();
          return;
        }
        if (_resizeRow != null) {
          _resizeAccum += details.delta.dy;
          onResizeRow?.call(
            _resizeRow!,
            _resizeStart + _resizeAccum / viewport.scale,
          );
          markNeedsPaint();
          onChanged?.call();
          return;
        }
        if (_scrollH || _scrollV) {
          _dragScroll(details.delta);
          markNeedsPaint();
          onChanged?.call();
          return;
        }
        if (_drawingHandle != null && selectedDrawingIndex != null) {
          _resizeDrawing(details.delta);
          markNeedsPaint();
          onChanged?.call();
          return;
        }
        if (_drawingMove && selectedDrawingIndex != null) {
          onMoveDrawing?.call(
            details.delta.dx / viewport.scale,
            details.delta.dy / viewport.scale,
          );
          markNeedsPaint();
          onChanged?.call();
          return;
        }
        final SmlCellRef? ref = _hitCell(details.localPosition);
        if (ref == null) {
          return;
        }
        if (_canPointRefs) {
          onPointRef?.call(ref, extend: true);
          markNeedsPaint();
          onChanged?.call();
          return;
        }
        if (editing) {
          return;
        }
        switch (_headerDrag) {
          case _HeaderDrag.rows:
            selection.extendRowsTo(ref.row);
          case _HeaderDrag.columns:
            selection.extendColumnsTo(ref.col);
          case _HeaderDrag.none:
            if (selection.isFullRowSelection) {
              selection.extendRowsTo(ref.row);
            } else if (selection.isFullColumnSelection) {
              selection.extendColumnsTo(ref.col);
            } else {
              selection.extendTo(ref);
            }
        }
        markNeedsPaint();
        onChanged?.call();
      }
      ..onEnd = (DragEndDetails details) {
        _finishResize();
      }
      ..onCancel = () {
        _finishResize();
      };
  }

  void _finishResize() {
    if (_drawingHandle != null || _drawingMove) {
      _drawingHandle = null;
      _drawingMove = false;
      onCommitDrawingTransform?.call();
    }
    _scrollH = false;
    _scrollV = false;
    _headerDrag = _HeaderDrag.none;
    if (_resizeCol == null && _resizeRow == null) {
      return;
    }
    _resizeCol = null;
    _resizeRow = null;
    _resizeAccum = 0;
    onCommitResize?.call();
    markNeedsPaint();
    onChanged?.call();
  }

  double _colLeft(int col) {
    if (_rtl) {
      final double base =
          size.width - _headW - sheet.columnLeft(col + 1) * viewport.scale;
      return col < _fc ? base : base + viewport.origin.dx;
    }
    final double base = _headW + sheet.columnLeft(col) * viewport.scale;
    return col < _fc ? base : base - viewport.origin.dx;
  }

  double _rowTopY(int row) {
    final double base = _barH + _headH + sheet.rowTop(row) * viewport.scale;
    return row < _fr ? base : base - viewport.origin.dy;
  }

  bool _isRowHeader(Offset local) {
    return config.showGridHeaders &&
        (_rtl ? local.dx >= size.width - _headW : local.dx < _headW);
  }

  bool _isColHeader(Offset local) {
    return config.showGridHeaders &&
        local.dy >= _barH &&
        local.dy < _barH + _headH &&
        !_isRowHeader(local);
  }

  int? _hitColResize(Offset local) {
    if (!_isColHeader(local)) {
      return null;
    }
    final SmlCellRef? ref = _hitCell(local);
    if (ref == null) {
      return null;
    }
    final Rect cell = _cellRect(ref.col, 0);
    final double trailing = _rtl ? cell.left : cell.right;
    if ((local.dx - trailing).abs() <= _resizeSlop) {
      return ref.col;
    }
    final double leading = _rtl ? cell.right : cell.left;
    if ((local.dx - leading).abs() <= _resizeSlop && ref.col > 0) {
      return ref.col - 1;
    }
    return null;
  }

  int? _hitRowResize(Offset local) {
    if (!_isRowHeader(local) || local.dy < _barH + _headH) {
      return null;
    }
    final SmlCellRef? ref = _hitCell(local);
    if (ref == null) {
      return null;
    }
    final Rect cell = _cellRect(0, ref.row);
    if ((local.dy - cell.bottom).abs() <= _resizeSlop) {
      return ref.row;
    }
    if ((local.dy - cell.top).abs() <= _resizeSlop && ref.row > 0) {
      return ref.row - 1;
    }
    return null;
  }

  void _handleContext(PointerDownEvent event) {
    final SmlCellRef? ref = _hitCell(event.localPosition);
    OfficeContextKind kind = OfficeContextKind.sheetCell;
    if (ref != null) {
      if (_isRowHeader(event.localPosition)) {
        kind = OfficeContextKind.sheetRowHeader;
      } else if (_isColHeader(event.localPosition)) {
        kind = OfficeContextKind.sheetColHeader;
      }
    }
    onContextMenu?.call(
      OfficeContextHit(
        kind: kind,
        globalPosition: event.position,
        cell: ref ?? selection.focus,
      ),
    );
  }

  _SheetInsertHit? _sheetInsertHit(Offset local) {
    for (final _SheetInsertHit hit in _sheetInsertHits()) {
      if (hit.button.inflate(2).contains(local)) {
        return hit;
      }
    }
    return null;
  }

  List<_SheetInsertHit> _sheetInsertHits() {
    if (!config.showGridHeaders || !config.allowsMutation) {
      return const <_SheetInsertHit>[];
    }
    final int firstCol = sheet
        .columnAt(viewport.origin.dx / viewport.scale)
        .clamp(0, _excelCols - 1);
    final int firstRow = sheet
        .rowAt(viewport.origin.dy / viewport.scale)
        .clamp(0, _excelRows - 1);
    final int lastCol = _lastVisibleCol(firstCol);
    final int lastRow = _lastVisibleRow(firstRow);
    final List<_SheetInsertHit> hits = <_SheetInsertHit>[];
    for (int c = firstCol; c <= lastCol; c++) {
      final Rect cell = _cellRect(c, 0);
      final double x = _rtl ? cell.left : cell.right;
      hits.add(
        _SheetInsertHit(
          column: true,
          index: c + 1,
          button: Rect.fromCircle(center: Offset(x, _barH + 2), radius: 6),
        ),
      );
    }
    for (int r = firstRow; r <= lastRow; r++) {
      final Rect cell = _cellRect(0, r);
      final double x = _rtl ? _rowHeadLeft + _headW + 8 : _rowHeadLeft - 2;
      hits.add(
        _SheetInsertHit(
          column: false,
          index: r + 1,
          button: Rect.fromCircle(center: Offset(x, cell.bottom), radius: 6),
        ),
      );
    }
    return hits;
  }

  void _paintSheetInsertHandles(Canvas canvas) {
    final Offset? hover = _hoverLocal;
    if (hover == null) {
      return;
    }
    final _SheetInsertHit? hot = _sheetInsertHit(hover);
    final bool showCols = _isColHeader(hover) || (hot != null && hot.column);
    final bool showRows = _isRowHeader(hover) || (hot != null && !hot.column);
    if (!showCols && !showRows) {
      return;
    }
    for (final _SheetInsertHit hit in _sheetInsertHits()) {
      if (hit.column && !showCols) {
        continue;
      }
      if (!hit.column && !showRows) {
        continue;
      }
      final bool active =
          hot != null && hot.column == hit.column && hot.index == hit.index;
      canvas.drawCircle(
        hit.button.center,
        hit.button.width / 2,
        Paint()
          ..color = active ? const Color(0xFF2E75B6) : const Color(0xFFFFFFFF),
      );
      canvas.drawCircle(
        hit.button.center,
        hit.button.width / 2,
        Paint()
          ..color = const Color(0xFF2E75B6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
      final Paint plus = Paint()
        ..color = active ? const Color(0xFFFFFFFF) : const Color(0xFF2E75B6)
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(hit.button.center.dx - 2.8, hit.button.center.dy),
        Offset(hit.button.center.dx + 2.8, hit.button.center.dy),
        plus,
      );
      canvas.drawLine(
        Offset(hit.button.center.dx, hit.button.center.dy - 2.8),
        Offset(hit.button.center.dx, hit.button.center.dy + 2.8),
        plus,
      );
    }
  }

  Rect _cellRect(int col, int row) {
    return Rect.fromLTWH(
      _colLeft(col),
      _rowTopY(row),
      _colWAt(col),
      _rowHAt(row),
    );
  }

  int _hitEditIndex(Offset local, SmlCellRef ref) {
    final Rect cell = _cellRect(ref.col, ref.row);
    final TextPainter painter = _textPainter(editText, colored: true)
      ..layout(maxWidth: _colWAt(ref.col) > 12 ? _colWAt(ref.col) - 4 : 8);
    return PaintRunText.hitIndex(
      painter,
      Offset(local.dx - cell.left - 2, 0),
      editText.length,
    );
  }

  TextPainter _textPainter(String text, {required bool colored}) {
    final bool rtl = _rtl || PaintRunText.looksRtl(text);
    final TextAlign align = rtl ? TextAlign.right : TextAlign.left;
    if (colored && FormulaRefScanner.scan(text).isNotEmpty) {
      return TextPainter(
        text: FormulaRefStyle.textSpan(
          text,
          baseColor: _theme.chromeText,
          fontSize: 11,
          fontFamily: PaintRunText.familyFor(
            text: text,
            themeFamily: _theme.fontFamily,
          ),
          fontFamilyFallback: PaintRunText.fallbacksFor(text),
        ),
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        textAlign: align,
        maxLines: 1,
      );
    }
    return PaintRunText.plain(
      text: text,
      fontSize: 11,
      color: _theme.chromeText,
      themeFamily: _theme.fontFamily,
      align: align,
    );
  }

  Rect _rangeRect(SmlRange range) {
    final int c0 = range.start.col < range.end.col
        ? range.start.col
        : range.end.col;
    final int c1 = range.start.col > range.end.col
        ? range.start.col
        : range.end.col;
    final int r0 = range.start.row < range.end.row
        ? range.start.row
        : range.end.row;
    final int r1 = range.start.row > range.end.row
        ? range.start.row
        : range.end.row;
    return _cellRect(c0, r0).expandToInclude(_cellRect(c1, r1));
  }

  void _paintFormulaRefs(
    Canvas canvas, {
    required List<(FormulaRefSpan, Color)> refs,
    required bool borders,
  }) {
    for (final (FormulaRefSpan span, Color color) in refs) {
      if (!span.onSheet(sheet.name)) {
        continue;
      }
      final Rect box = _rangeRect(span.range);
      if (borders) {
        canvas.drawRect(
          box.deflate(0.6),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawRect(box, Paint()..color = color.withValues(alpha: 0.16));
      }
    }
  }

  void _paintCellText(
    Canvas canvas,
    Rect cell,
    String label, {
    required bool isEdit,
  }) {
    canvas.save();
    canvas.clipRect(cell);
    final double maxW = cell.width - 4;
    if (maxW <= 0) {
      canvas.restore();
      return;
    }
    final TextPainter painter = _textPainter(label, colored: isEdit)
      ..layout(maxWidth: maxW);
    final double textY = cell.top + (cell.height - painter.height) / 2;
    if (isEdit) {
      final int start = editBase < editCaret ? editBase : editCaret;
      final int end = editBase > editCaret ? editBase : editCaret;
      if (start != end) {
        final double x0 = cell.left + 2 + PaintRunText.caretDx(painter, start);
        final double x1 = cell.left + 2 + PaintRunText.caretDx(painter, end);
        canvas.drawRect(
          Rect.fromLTRB(
            x0 < x1 ? x0 : x1,
            cell.top + 1,
            x0 < x1 ? x1 : x0,
            cell.bottom - 1,
          ),
          Paint()..color = _theme.selectionFill,
        );
      }
    }
    painter.paint(canvas, Offset(cell.left + 2, textY));
    if (isEdit && config.showsCaret && hasFocus) {
      final double caretX =
          cell.left + 2 + PaintRunText.caretDx(painter, editCaret);
      canvas.drawRect(
        Rect.fromLTWH(caretX, cell.top + 2, 1.2, cell.height - 4),
        Paint()..color = _theme.caret,
      );
    }
    canvas.restore();
  }

  Rect _drawingRect(SmlDrawing drawing) {
    return Rect.fromLTWH(
      _colLeft(drawing.col) + drawing.offsetX * viewport.scale,
      _rowTopY(drawing.row) + drawing.offsetY * viewport.scale,
      drawing.visual.width * viewport.scale,
      drawing.visual.height * viewport.scale,
    );
  }

  int? _hitDrawingHandle(Offset local) {
    final int? index = selectedDrawingIndex;
    if (index == null || index < 0 || index >= sheet.drawings.length) {
      return null;
    }
    final int? handle = TransformHandles(
      _drawingRect(sheet.drawings[index]),
    ).hit(local, radius: 12);
    return handle == 8 ? null : handle;
  }

  void _resizeDrawing(Offset delta) {
    final int? index = selectedDrawingIndex;
    final int? handle = _drawingHandle;
    if (index == null || handle == null || index >= sheet.drawings.length) {
      return;
    }
    Rect r = _drawingRect(sheet.drawings[index]);
    switch (handle) {
      case 0:
        r = Rect.fromLTRB(
          r.left + delta.dx,
          r.top + delta.dy,
          r.right,
          r.bottom,
        );
      case 1:
        r = Rect.fromLTRB(r.left, r.top + delta.dy, r.right, r.bottom);
      case 2:
        r = Rect.fromLTRB(
          r.left,
          r.top + delta.dy,
          r.right + delta.dx,
          r.bottom,
        );
      case 3:
        r = Rect.fromLTRB(r.left, r.top, r.right + delta.dx, r.bottom);
      case 4:
        r = Rect.fromLTRB(
          r.left,
          r.top,
          r.right + delta.dx,
          r.bottom + delta.dy,
        );
      case 5:
        r = Rect.fromLTRB(r.left, r.top, r.right, r.bottom + delta.dy);
      case 6:
        r = Rect.fromLTRB(
          r.left + delta.dx,
          r.top,
          r.right,
          r.bottom + delta.dy,
        );
      case 7:
        r = Rect.fromLTRB(r.left + delta.dx, r.top, r.right, r.bottom);
    }
    if (r.width < 40 || r.height < 40) {
      return;
    }
    onResizeDrawing?.call(
      left: (_contentX(r.left)),
      top: (_contentY(r.top)),
      width: r.width / viewport.scale,
      height: r.height / viewport.scale,
    );
  }

  double _contentX(double screenX) {
    if (_rtl) {
      return (size.width - _headW - screenX + viewport.origin.dx) /
          viewport.scale;
    }
    return (screenX - _headW + viewport.origin.dx) / viewport.scale;
  }

  double _contentY(double screenY) {
    return (screenY - _barH - _headH + viewport.origin.dy) / viewport.scale;
  }

  Rect get _vTrack {
    return Rect.fromLTWH(
      size.width - _scrollBar,
      _barH + _headH,
      _scrollBar,
      size.height - _barH - _headH - _scrollBar,
    );
  }

  Rect get _hTrack {
    return Rect.fromLTWH(
      _rtl ? _scrollBar : 0,
      size.height - _scrollBar,
      size.width - _scrollBar,
      _scrollBar,
    );
  }

  String? _hitScrollBar(Offset local) {
    if (_vTrack.contains(local)) {
      return 'v';
    }
    if (_hTrack.contains(local)) {
      return 'h';
    }
    return null;
  }

  void _jumpScroll(Offset local) {
    final Size content = _sheetContentSize;
    if (_scrollV) {
      final double maxY = math.max(0, content.height - size.height);
      final double t = ((local.dy - _vTrack.top) / _vTrack.height).clamp(0, 1);
      viewport.origin = Offset(viewport.origin.dx, maxY * t);
    }
    if (_scrollH) {
      final double maxX = math.max(0, content.width - size.width);
      final double t = ((local.dx - _hTrack.left) / _hTrack.width).clamp(0, 1);
      viewport.origin = Offset(maxX * t, viewport.origin.dy);
    }
    _clampViewport();
  }

  void _dragScroll(Offset delta) {
    final Size content = _sheetContentSize;
    if (_scrollV && _vTrack.height > 0) {
      final double maxY = math.max(0, content.height - size.height);
      viewport.origin = Offset(
        viewport.origin.dx,
        viewport.origin.dy + delta.dy * (maxY / _vTrack.height),
      );
    }
    if (_scrollH && _hTrack.width > 0) {
      final double maxX = math.max(0, content.width - size.width);
      viewport.origin = Offset(
        viewport.origin.dx + delta.dx * (maxX / _hTrack.width),
        viewport.origin.dy,
      );
    }
    _clampViewport();
  }

  void _paintScrollBars(Canvas canvas) {
    final Size content = _sheetContentSize;
    final Paint track = Paint()..color = const Color(0xFFD8D8D8);
    final Paint thumb = Paint()..color = const Color(0xFF7A7A7A);
    canvas.drawRect(_vTrack, track);
    canvas.drawRect(_hTrack, track);
    final double maxY = math.max(0, content.height - size.height);
    final double maxX = math.max(0, content.width - size.width);
    final double vThumbH = (_vTrack.height * (size.height / content.height))
        .clamp(22.0, _vTrack.height);
    final double hThumbW = (_hTrack.width * (size.width / content.width)).clamp(
      22.0,
      _hTrack.width,
    );
    final double vY = maxY <= 0
        ? _vTrack.top
        : _vTrack.top +
              (_vTrack.height - vThumbH) * (viewport.origin.dy / maxY);
    final double hX = maxX <= 0
        ? _hTrack.left
        : _hTrack.left +
              (_hTrack.width - hThumbW) * (viewport.origin.dx / maxX);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_vTrack.left + 2, vY, _vTrack.width - 4, vThumbH),
        const Radius.circular(4),
      ),
      thumb,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(hX, _hTrack.top + 2, hThumbW, _hTrack.height - 4),
        const Radius.circular(4),
      ),
      thumb,
    );
  }

  int? _hitDrawing(Offset local) {
    for (int i = sheet.drawings.length - 1; i >= 0; i--) {
      if (_drawingRect(sheet.drawings[i]).contains(local)) {
        return i;
      }
    }
    return null;
  }

  SmlCellRef? _hitCell(Offset local) {
    final bool inFrozenCol =
        _fc > 0 &&
        (_rtl
            ? local.dx >= size.width - _headW - _frozenW &&
                  local.dx < size.width - _headW
            : local.dx >= _headW && local.dx < _headW + _frozenW);
    final bool inFrozenRow =
        _fr > 0 &&
        local.dy >= _barH + _headH &&
        local.dy < _barH + _headH + _frozenH;
    final double x = _rtl
        ? (size.width - _headW) -
              local.dx +
              (inFrozenCol ? 0 : viewport.origin.dx)
        : local.dx - _headW + (inFrozenCol ? 0 : viewport.origin.dx);
    final double y =
        local.dy - _barH - _headH + (inFrozenRow ? 0 : viewport.origin.dy);
    if (x < 0 && y < 0) {
      return const SmlCellRef(0, 0);
    }
    final int col = sheet.columnAt(x / viewport.scale).clamp(0, _excelCols - 1);
    final int row = sheet.rowAt(y / viewport.scale).clamp(0, _excelRows - 1);
    return SmlCellRef(col, row);
  }

  @override
  /// describeSemanticsConfiguration API.
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..label = semanticsLabel
      ..value = semanticsValue
      ..isReadOnly = !this.config.allowsMutation
      ..textDirection = sheet.rightToLeft
          ? TextDirection.rtl
          : this.config.textDirection;
  }

  @override
  /// paint API.
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.drawRect(Offset.zero & size, Paint()..color = _theme.pageBackground);
    final List<(FormulaRefSpan, Color)> formulaRefs = editing
        ? FormulaRefStyle.colored(editText)
        : const <(FormulaRefSpan, Color)>[];
    if (config.showFormulaBar) {
      OfficeChrome.paintFormulaBar(
        canvas,
        size,
        formulaBar,
        theme: _theme,
        fontFamily: _theme.fontFamily,
        rtl: _rtl,
        highlights: <(int, int, Color)>[
          for (final (FormulaRefSpan span, Color color) in formulaRefs)
            (span.start, span.end, color),
        ],
      );
    }
    final int firstCol = sheet
        .columnAt(viewport.origin.dx / viewport.scale)
        .clamp(0, _excelCols - 1);
    final int firstRow = sheet
        .rowAt(viewport.origin.dy / viewport.scale)
        .clamp(0, _excelRows - 1);
    final int lastCol = _lastVisibleCol(firstCol);
    final int lastRow = _lastVisibleRow(firstRow);
    final int scrollCol0 = firstCol < _fc ? _fc : firstCol;
    final int scrollRow0 = firstRow < _fr ? _fr : firstRow;
    final int selC0 = selection.anchor.col < selection.focus.col
        ? selection.anchor.col
        : selection.focus.col;
    final int selC1 = selection.anchor.col > selection.focus.col
        ? selection.anchor.col
        : selection.focus.col;
    final int selR0 = selection.anchor.row < selection.focus.row
        ? selection.anchor.row
        : selection.focus.row;
    final int selR1 = selection.anchor.row > selection.focus.row
        ? selection.anchor.row
        : selection.focus.row;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, _barH, size.width, size.height - _barH));
    canvas.save();
    canvas.clipRect(_unfrozenRect);
    _paintCellRange(
      canvas,
      r0: scrollRow0,
      r1: lastRow,
      c0: scrollCol0,
      c1: lastCol,
      formulaRefs: formulaRefs,
    );
    canvas.restore();
    if (_fr > 0) {
      canvas.save();
      canvas.clipRect(_frozenRowBand);
      _paintCellRange(
        canvas,
        r0: 0,
        r1: _fr,
        c0: 0,
        c1: _fc,
        formulaRefs: formulaRefs,
        frozen: true,
      );
      _paintCellRange(
        canvas,
        r0: 0,
        r1: _fr,
        c0: scrollCol0,
        c1: lastCol,
        formulaRefs: formulaRefs,
        frozen: true,
      );
      canvas.restore();
    }
    if (_fc > 0) {
      canvas.save();
      canvas.clipRect(_frozenColBand);
      _paintCellRange(
        canvas,
        r0: scrollRow0,
        r1: lastRow,
        c0: 0,
        c1: _fc,
        formulaRefs: formulaRefs,
        frozen: true,
      );
      canvas.restore();
    }
    for (int i = 0; i < sheet.drawings.length; i++) {
      final SmlDrawing drawing = sheet.drawings[i];
      final Rect box = _drawingRect(drawing);
      PaintOfficeVisual.paint(
        canvas,
        box,
        drawing.visual,
        fontFamily: _theme.fontFamily ?? PaintRunText.fontFallbacks.first,
        images: _images,
        onImageReady: markNeedsPaint,
      );
      if (config.allowsSelection && selectedDrawingIndex == i) {
        TransformHandles(box).paint(
          canvas,
          strokeColor: _theme.focusRing,
          fillColor: _theme.handleFill,
          showRotate: false,
        );
      }
    }
    if (config.showGridHeaders) {
      void paintColHeader(int c) {
        OfficeChrome.paintSheetHeader(
          canvas,
          rect: Rect.fromLTWH(_colLeft(c), _barH, _colWAt(c), _headH),
          label: SmlCellRef(c, 0).a1.replaceAll(RegExp(r'\d'), ''),
          theme: _theme,
          fontFamily: _theme.fontFamily,
          selected: config.allowsSelection && c >= selC0 && c <= selC1,
        );
      }

      void paintRowHeader(int r) {
        OfficeChrome.paintSheetHeader(
          canvas,
          rect: Rect.fromLTWH(_rowHeadLeft, _rowTopY(r), _headW, _rowHAt(r)),
          label: '${r + 1}',
          theme: _theme,
          fontFamily: _theme.fontFamily,
          selected: config.allowsSelection && r >= selR0 && r <= selR1,
        );
      }

      canvas.save();
      canvas.clipRect(
        _rtl
            ? Rect.fromLTWH(0, _barH, size.width - _headW - _frozenW, _headH)
            : Rect.fromLTWH(_headW + _frozenW, _barH, size.width, _headH),
      );
      for (int c = scrollCol0; c < lastCol; c++) {
        paintColHeader(c);
      }
      canvas.restore();
      for (int c = 0; c < _fc; c++) {
        paintColHeader(c);
      }
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          _rowHeadLeft,
          _barH + _headH + _frozenH,
          _headW,
          size.height,
        ),
      );
      for (int r = scrollRow0; r < lastRow; r++) {
        paintRowHeader(r);
      }
      canvas.restore();
      for (int r = 0; r < _fr; r++) {
        paintRowHeader(r);
      }
      canvas.drawRect(
        Rect.fromLTWH(_rowHeadLeft, _barH, _headW, _headH),
        Paint()..color = _theme.headerFill,
      );
    }
    if (_fr > 0 || _fc > 0) {
      final Paint freezeLine = Paint()
        ..color = _theme.gridLine
        ..strokeWidth = 2;
      if (_fr > 0) {
        final double y = _barH + _headH + _frozenH;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), freezeLine);
      }
      if (_fc > 0) {
        final double x = _rtl
            ? size.width - _headW - _frozenW
            : _headW + _frozenW;
        canvas.drawLine(Offset(x, _barH), Offset(x, size.height), freezeLine);
      }
    }
    canvas.restore();
    _paintSheetInsertHandles(canvas);
    _paintFunctionAssist(canvas);
    _paintScrollBars(canvas);
    if (hasFocus) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = _theme.focusRing
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }
}

class _SheetInsertHit {
  const _SheetInsertHit({
    required this.column,
    required this.index,
    required this.button,
  });

  /// column API.
  final bool column;

  /// index API.
  final int index;

  /// button API.
  final Rect button;
}
