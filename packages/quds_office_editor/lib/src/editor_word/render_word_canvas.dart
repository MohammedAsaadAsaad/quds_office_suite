import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:quds_office_engine/quds_office_engine.dart';

import '../core/virtual_viewport.dart';
import '../embed/office_context_menu.dart';
import '../embed/office_theme.dart';
import '../ui_components/office_chrome.dart';
import '../visual/paint_office_visual.dart';
import '../editor_slide/transform_handles.dart';
import 'caret_engine.dart';
import 'paint_equation.dart';
import 'paint_run_text.dart';

/// Class WordCanvas.
class WordCanvas extends LeafRenderObjectWidget {
  /// WordCanvas API.
  const WordCanvas({
    super.key,
    required this.document,
    required this.laidOut,
    required this.caret,
    this.viewport,
    this.config = const OfficeSurfaceConfig(),
    this.hasFocus = false,
    this.semanticsLabel = '',
    this.semanticsValue = '',
    this.selectedVisual,
    this.selectedEquation,
    this.equationSlot = 0,
    this.equationCaret = 0,
    this.pictureCropMode = false,
    this.onChanged,
    this.onSelectVisual,
    this.onSelectEquation,
    this.onBeginVisualTransform,
    this.onPreviewVisualMove,
    this.onPreviewVisualResize,
    this.onPreviewVisualCrop,
    this.onPreviewVisualRotate,
    this.onCommitVisualTransform,
    this.onActivateVisual,
    this.onExtendThroughVisual,
    this.isVisualInSelection,
    this.onJumpParagraph,
    this.onFollowLink,
    this.selectedCommentId,
    this.onSelectComment,
    this.onContextMenu,
    this.onInsertTableRowAt,
    this.onInsertTableColumnAt,
    this.onBeginTableResize,
    this.onPreviewTableColumnWidth,
    this.onPreviewTableRowHeight,
    this.onCommitTableResize,
    this.selectedTable,
    this.onSelectTable,
    this.selectedTableBand,
    this.onSelectTableBand,
    this.storyParagraphs,
    this.editingHeader = false,
    this.editingFooter = false,
    this.onBeginHeaderFooterEdit,
    this.onEndHeaderFooterEdit,
    this.compact = false,
  });

  /// document API.
  final WmlDocument document;

  /// laidOut API.
  final LaidOutDocument laidOut;

  /// caret API.
  final CaretEngine caret;

  /// viewport API.
  final VirtualViewport? viewport;

  /// config API.
  final OfficeSurfaceConfig config;

  /// hasFocus API.
  final bool hasFocus;

  /// semanticsLabel API.
  final String semanticsLabel;

  /// semanticsValue API.
  final String semanticsValue;

  /// selectedVisual API.
  final WmlVisual? selectedVisual;

  /// selectedEquation API.
  final WmlEquation? selectedEquation;

  /// equationSlot API.
  final int equationSlot;

  /// equationCaret API.
  final int equationCaret;

  /// pictureCropMode API.
  final bool pictureCropMode;

  /// onBeginVisualTransform API.
  final VoidCallback? onBeginVisualTransform;

  /// Function API.
  final void Function(double dx, double dy)? onPreviewVisualMove;

  /// Function API.
  final void Function({required double width, required double height})?
  /// onPreviewVisualResize API.
  onPreviewVisualResize;

  /// Function API.
  final void Function({
    required double left,
    required double top,
    required double right,
    required double bottom,
  })?
  /// onPreviewVisualCrop API.
  onPreviewVisualCrop;

  /// onPreviewVisualRotate API.
  final ValueChanged<double>? onPreviewVisualRotate;

  /// onCommitVisualTransform API.
  final VoidCallback? onCommitVisualTransform;

  /// onChanged API.
  final VoidCallback? onChanged;

  /// onSelectVisual API.
  final ValueChanged<OfficeVisual?>? onSelectVisual;

  /// Function API.
  final void Function(WmlEquation? equation, int? slot, int? caret)?
  /// onSelectEquation API.
  onSelectEquation;

  /// onActivateVisual API.
  final ValueChanged<OfficeVisual>? onActivateVisual;

  /// onExtendThroughVisual API.
  final ValueChanged<OfficeVisual>? onExtendThroughVisual;

  /// Function API.
  final bool Function(OfficeVisual visual)? isVisualInSelection;

  /// onJumpParagraph API.
  final ValueChanged<int>? onJumpParagraph;

  /// onFollowLink API.
  final ValueChanged<WmlHyperlink>? onFollowLink;

  /// selectedCommentId API.
  final int? selectedCommentId;

  /// onSelectComment API.
  final ValueChanged<int?>? onSelectComment;

  /// onContextMenu API.
  final ValueChanged<OfficeContextHit>? onContextMenu;

  /// Function API.
  final void Function(WmlTable table, int index)? onInsertTableRowAt;

  /// Function API.
  final void Function(WmlTable table, int index)? onInsertTableColumnAt;

  /// onBeginTableResize API.
  final ValueChanged<WmlTable>? onBeginTableResize;

  /// Function API.
  final void Function(WmlTable table, int col, double width)?
  /// onPreviewTableColumnWidth API.
  onPreviewTableColumnWidth;

  /// Function API.
  final void Function(WmlTable table, int row, double height)?
  /// onPreviewTableRowHeight API.
  onPreviewTableRowHeight;

  /// onCommitTableResize API.
  final ValueChanged<WmlTable>? onCommitTableResize;

  /// selectedTable API.
  final WmlTable? selectedTable;

  /// onSelectTable API.
  final ValueChanged<WmlTable?>? onSelectTable;
  final ({WmlTable table, bool column, int from, int to})? selectedTableBand;

  /// Function API.
  final void Function(
    WmlTable table, {
    required bool column,
    required int from,
    required int to,
  })?
  /// onSelectTableBand API.
  onSelectTableBand;

  /// storyParagraphs API.
  final List<WmlParagraph>? storyParagraphs;

  /// editingHeader API.
  final bool editingHeader;

  /// editingFooter API.
  final bool editingFooter;

  /// Function API.
  final void Function(int pageIndex, {required bool footer})?
  /// onBeginHeaderFooterEdit API.
  onBeginHeaderFooterEdit;

  /// onEndHeaderFooterEdit API.
  final VoidCallback? onEndHeaderFooterEdit;

  /// compact API.
  final bool compact;

  @override
  /// createRenderObject API.
  RenderWordCanvas createRenderObject(BuildContext context) {
    return RenderWordCanvas(
      document: document,
      laidOut: laidOut,
      caret: caret,
      viewport: viewport ?? VirtualViewport(),
      config: config,
      hasFocus: hasFocus,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
      selectedVisual: selectedVisual,
      selectedEquation: selectedEquation,
      equationSlot: equationSlot,
      equationCaret: equationCaret,
      pictureCropMode: pictureCropMode,
      onChanged: onChanged,
      onSelectVisual: onSelectVisual,
      onSelectEquation: onSelectEquation,
      onBeginVisualTransform: onBeginVisualTransform,
      onPreviewVisualMove: onPreviewVisualMove,
      onPreviewVisualResize: onPreviewVisualResize,
      onPreviewVisualCrop: onPreviewVisualCrop,
      onPreviewVisualRotate: onPreviewVisualRotate,
      onCommitVisualTransform: onCommitVisualTransform,
      onActivateVisual: onActivateVisual,
      onExtendThroughVisual: onExtendThroughVisual,
      isVisualInSelection: isVisualInSelection,
      onJumpParagraph: onJumpParagraph,
      onFollowLink: onFollowLink,
      selectedCommentId: selectedCommentId,
      onSelectComment: onSelectComment,
      onContextMenu: onContextMenu,
      onInsertTableRowAt: onInsertTableRowAt,
      onInsertTableColumnAt: onInsertTableColumnAt,
      onBeginTableResize: onBeginTableResize,
      onPreviewTableColumnWidth: onPreviewTableColumnWidth,
      onPreviewTableRowHeight: onPreviewTableRowHeight,
      onCommitTableResize: onCommitTableResize,
      selectedTable: selectedTable,
      onSelectTable: onSelectTable,
      selectedTableBand: selectedTableBand,
      onSelectTableBand: onSelectTableBand,
      storyParagraphs: storyParagraphs,
      editingHeader: editingHeader,
      editingFooter: editingFooter,
      onBeginHeaderFooterEdit: onBeginHeaderFooterEdit,
      onEndHeaderFooterEdit: onEndHeaderFooterEdit,
      compact: compact,
    );
  }

  @override
  /// updateRenderObject API.
  void updateRenderObject(BuildContext context, RenderWordCanvas renderObject) {
    renderObject
      ..document = document
      ..laidOut = laidOut
      ..caret = caret
      ..config = config
      ..hasFocus = hasFocus
      ..semanticsLabel = semanticsLabel
      ..semanticsValue = semanticsValue
      ..selectedVisual = selectedVisual
      ..selectedEquation = selectedEquation
      ..equationSlot = equationSlot
      ..equationCaret = equationCaret
      ..pictureCropMode = pictureCropMode
      ..onChanged = onChanged
      ..onSelectVisual = onSelectVisual
      ..onSelectEquation = onSelectEquation
      ..onBeginVisualTransform = onBeginVisualTransform
      ..onPreviewVisualMove = onPreviewVisualMove
      ..onPreviewVisualResize = onPreviewVisualResize
      ..onPreviewVisualCrop = onPreviewVisualCrop
      ..onPreviewVisualRotate = onPreviewVisualRotate
      ..onCommitVisualTransform = onCommitVisualTransform
      ..onActivateVisual = onActivateVisual
      ..onExtendThroughVisual = onExtendThroughVisual
      ..isVisualInSelection = isVisualInSelection
      ..onJumpParagraph = onJumpParagraph
      ..onFollowLink = onFollowLink
      ..selectedCommentId = selectedCommentId
      ..onSelectComment = onSelectComment
      ..onContextMenu = onContextMenu
      ..onInsertTableRowAt = onInsertTableRowAt
      ..onInsertTableColumnAt = onInsertTableColumnAt
      ..onBeginTableResize = onBeginTableResize
      ..onPreviewTableColumnWidth = onPreviewTableColumnWidth
      ..onPreviewTableRowHeight = onPreviewTableRowHeight
      ..onCommitTableResize = onCommitTableResize
      ..selectedTable = selectedTable
      ..onSelectTable = onSelectTable
      ..selectedTableBand = selectedTableBand
      ..onSelectTableBand = onSelectTableBand
      ..storyParagraphs = storyParagraphs
      ..editingHeader = editingHeader
      ..editingFooter = editingFooter
      ..onBeginHeaderFooterEdit = onBeginHeaderFooterEdit
      ..onEndHeaderFooterEdit = onEndHeaderFooterEdit
      ..compact = compact;
    if (viewport != null) {
      renderObject.viewport = viewport!;
    }
    renderObject.markNeedsPaint();
  }
}

/// Class RenderWordCanvas.
class RenderWordCanvas extends RenderBox implements MouseTrackerAnnotation {
  /// RenderWordCanvas API.
  RenderWordCanvas({
    required this.document,
    required this.laidOut,
    required this.caret,
    required this.viewport,
    required this.config,
    required this.hasFocus,
    required this.semanticsLabel,
    required this.semanticsValue,
    this.selectedVisual,
    this.selectedEquation,
    this.equationSlot = 0,
    this.equationCaret = 0,
    this.pictureCropMode = false,
    this.onChanged,
    this.onSelectVisual,
    this.onSelectEquation,
    this.onBeginVisualTransform,
    this.onPreviewVisualMove,
    this.onPreviewVisualResize,
    this.onPreviewVisualCrop,
    this.onPreviewVisualRotate,
    this.onCommitVisualTransform,
    this.onActivateVisual,
    this.onExtendThroughVisual,
    this.isVisualInSelection,
    this.onJumpParagraph,
    this.onFollowLink,
    this.selectedCommentId,
    this.onSelectComment,
    this.onContextMenu,
    this.onInsertTableRowAt,
    this.onInsertTableColumnAt,
    this.onBeginTableResize,
    this.onPreviewTableColumnWidth,
    this.onPreviewTableRowHeight,
    this.onCommitTableResize,
    this.selectedTable,
    this.onSelectTable,
    this.selectedTableBand,
    this.onSelectTableBand,
    this.storyParagraphs,
    this.editingHeader = false,
    this.editingFooter = false,
    this.onBeginHeaderFooterEdit,
    this.onEndHeaderFooterEdit,
    this.compact = false,
  });

  /// document API.
  WmlDocument document;

  /// laidOut API.
  LaidOutDocument laidOut;

  /// caret API.
  CaretEngine caret;

  /// viewport API.
  VirtualViewport viewport;

  /// config API.
  OfficeSurfaceConfig config;

  /// hasFocus API.
  bool hasFocus;

  /// semanticsLabel API.
  String semanticsLabel;

  /// semanticsValue API.
  String semanticsValue;

  /// selectedVisual API.
  WmlVisual? selectedVisual;

  /// selectedEquation API.
  WmlEquation? selectedEquation;

  /// equationSlot API.
  int equationSlot;

  /// equationCaret API.
  int equationCaret;

  /// pictureCropMode API.
  bool pictureCropMode;

  /// onBeginVisualTransform API.
  VoidCallback? onBeginVisualTransform;

  /// Function API.
  void Function(double dx, double dy)? onPreviewVisualMove;

  /// Function API.
  void Function({required double width, required double height})?
  /// onPreviewVisualResize API.
  onPreviewVisualResize;

  /// Function API.
  void Function({
    required double left,
    required double top,
    required double right,
    required double bottom,
  })?
  /// onPreviewVisualCrop API.
  onPreviewVisualCrop;

  /// onPreviewVisualRotate API.
  ValueChanged<double>? onPreviewVisualRotate;

  /// onCommitVisualTransform API.
  VoidCallback? onCommitVisualTransform;

  /// onChanged API.
  VoidCallback? onChanged;

  /// onSelectVisual API.
  ValueChanged<OfficeVisual?>? onSelectVisual;

  /// Function API.
  void Function(WmlEquation? equation, int? slot, int? caret)? onSelectEquation;

  /// onActivateVisual API.
  ValueChanged<OfficeVisual>? onActivateVisual;

  /// onExtendThroughVisual API.
  ValueChanged<OfficeVisual>? onExtendThroughVisual;

  /// Function API.
  bool Function(OfficeVisual visual)? isVisualInSelection;

  /// onJumpParagraph API.
  ValueChanged<int>? onJumpParagraph;

  /// onFollowLink API.
  ValueChanged<WmlHyperlink>? onFollowLink;

  /// selectedCommentId API.
  int? selectedCommentId;

  /// onSelectComment API.
  ValueChanged<int?>? onSelectComment;

  /// onContextMenu API.
  ValueChanged<OfficeContextHit>? onContextMenu;

  /// Function API.
  void Function(WmlTable table, int index)? onInsertTableRowAt;

  /// Function API.
  void Function(WmlTable table, int index)? onInsertTableColumnAt;

  /// onBeginTableResize API.
  ValueChanged<WmlTable>? onBeginTableResize;

  /// Function API.
  void Function(WmlTable table, int col, double width)?
  /// onPreviewTableColumnWidth API.
  onPreviewTableColumnWidth;

  /// Function API.
  void Function(WmlTable table, int row, double height)?
  /// onPreviewTableRowHeight API.
  onPreviewTableRowHeight;

  /// onCommitTableResize API.
  ValueChanged<WmlTable>? onCommitTableResize;

  /// selectedTable API.
  WmlTable? selectedTable;

  /// onSelectTable API.
  ValueChanged<WmlTable?>? onSelectTable;

  /// selectedTableBand API.
  ({WmlTable table, bool column, int from, int to})? selectedTableBand;

  /// Function API.
  void Function(
    WmlTable table, {
    required bool column,
    required int from,
    required int to,
  })?
  /// onSelectTableBand API.
  onSelectTableBand;

  /// storyParagraphs API.
  List<WmlParagraph>? storyParagraphs;

  /// editingHeader API.
  bool editingHeader;

  /// editingFooter API.
  bool editingFooter;

  /// Function API.
  void Function(int pageIndex, {required bool footer})? onBeginHeaderFooterEdit;

  /// onEndHeaderFooterEdit API.
  VoidCallback? onEndHeaderFooterEdit;

  /// compact API.
  bool compact;

  /// editingFooter API.
  bool get _editingHeaderFooter => editingHeader || editingFooter;

  TapGestureRecognizer? _tap;
  PanGestureRecognizer? _pan;
  DateTime? _lastTapAt;
  Offset? _lastTapPos;
  var _tapCount = 0;

  /// VisualImageCache API.
  final VisualImageCache _images = VisualImageCache();
  LaidOutDocument? _fittedLayout;
  int? _visualHandle;
  var _draggingVisual = false;
  ({WmlTable table, bool column, int index, double start})? _tableResize;
  ({WmlTable table, bool column, int anchor, int current})? _tableBand;
  Offset? _hoverLocal;
  var _scrollDrag = false;
  int? _scrollPageTip;

  static const double _pointsToPixels = 96 / 72;
  static const double _scrollBar = 14;

  /// theme API.
  OfficeTheme get _theme => config.theme;

  double get _viewScale => viewport.scale * _pointsToPixels;

  @override
  /// cursor API.
  MouseCursor get cursor => cursorFor(_hoverLocal);

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

  @override
  /// hitTestSelf API.
  bool hitTestSelf(Offset position) {
    _hoverLocal = position;
    return true;
  }

  /// cursorFor API.
  MouseCursor cursorFor(Offset? window) {
    if (window == null || !config.allowsSelection) {
      return SystemMouseCursors.basic;
    }
    if (_draggingVisual) {
      return _cursorForHandle(_visualHandle ?? 9);
    }
    if (_tableResize != null) {
      return _tableResize!.column
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow;
    }
    if (_tableBand != null) {
      return _tableBand!.column
          ? SystemMouseCursors.resizeDown
          : SystemMouseCursors.resizeRight;
    }
    final (int page, Offset local) = _hitPage(window);
    if (page < 0 || page >= laidOut.pages.length) {
      return SystemMouseCursors.basic;
    }
    final LaidOutPage laidPage = laidOut.pages[page];
    final LaidOutBox? selectedBox = _selectedVisualBoxOn(page);
    if (selectedBox != null && config.allowsMutation) {
      final int? handle = TransformHandles(
        Rect.fromLTWH(
          selectedBox.x,
          selectedBox.y,
          selectedBox.width,
          selectedBox.height,
        ),
      ).hit(local, radius: 12);
      if (handle != null) {
        return _cursorForHandle(handle);
      }
      if (_boxContains(selectedBox, local, pad: 2)) {
        return SystemMouseCursors.move;
      }
    }
    final WmlHyperlink? link = _linkAt(laidPage, local);
    if (link != null) {
      return _ctrlFollow ? SystemMouseCursors.click : SystemMouseCursors.text;
    }
    if (_equationAt(laidPage, local) != null) {
      return SystemMouseCursors.text;
    }
    final LaidOutBox? visualBox = _visualAt(laidPage, local);
    if (visualBox != null) {
      return config.allowsMutation
          ? SystemMouseCursors.grab
          : SystemMouseCursors.click;
    }
    if (_tableHandleAt(laidPage, local) != null ||
        _insertHoverAt(laidPage, local) != null) {
      return SystemMouseCursors.click;
    }
    final MouseCursor? table = _tableEdgeCursor(laidPage, local);
    if (table != null) {
      return table;
    }
    final _TableBandHit? band = _tableBandAt(laidPage, local);
    if (band != null) {
      return band.column
          ? SystemMouseCursors.resizeDown
          : SystemMouseCursors.resizeRight;
    }
    if (local.dx >= 0 &&
        local.dx <= laidPage.width &&
        local.dy >= 0 &&
        local.dy <= laidPage.height) {
      return SystemMouseCursors.text;
    }
    return SystemMouseCursors.basic;
  }

  static MouseCursor _cursorForHandle(int handle) {
    return switch (handle) {
      0 || 4 => SystemMouseCursors.resizeUpLeftDownRight,
      2 || 6 => SystemMouseCursors.resizeUpRightDownLeft,
      1 || 5 => SystemMouseCursors.resizeUpDown,
      3 || 7 => SystemMouseCursors.resizeLeftRight,
      8 => SystemMouseCursors.grab,
      9 => SystemMouseCursors.move,
      _ => SystemMouseCursors.basic,
    };
  }

  /// pad API.
  static bool _boxContains(LaidOutBox box, Offset local, {double pad = 0}) {
    return local.dx >= box.x - pad &&
        local.dx <= box.x + box.width + pad &&
        local.dy >= box.y - pad &&
        local.dy <= box.y + box.height + pad;
  }

  LaidOutBox? _selectedVisualBoxOn(int page) {
    final WmlVisual? selected = selectedVisual;
    if (selected == null || page < 0 || page >= laidOut.pages.length) {
      return null;
    }
    for (final LaidOutBox box in laidOut.pages[page].frames) {
      if (box.visual != null && identical(box.visual, selected.visual)) {
        return box;
      }
    }
    return null;
  }

  MouseCursor? _tableEdgeCursor(LaidOutPage page, Offset local) {
    final ({WmlTable table, bool column, int index, double start})? edge =
        _tableEdgeAt(page, local);
    if (edge == null) {
      return null;
    }
    return edge.column
        ? SystemMouseCursors.resizeColumn
        : SystemMouseCursors.resizeRow;
  }

  ({WmlTable table, bool column, int index, double start})? _tableEdgeAt(
    LaidOutPage page,
    Offset local,
  ) {
    if (!config.allowsMutation) {
      return null;
    }
    const double slop = 5;
    for (final _TableGeom table in _tablesOn(page)) {
      if (!table.bounds.inflate(slop).contains(local)) {
        continue;
      }
      for (int i = 1; i <= table.colCount; i++) {
        final double x = table.colBoundary(i);
        if ((local.dx - x).abs() <= slop) {
          final int col = i - 1;
          final double width = col < table.table.grid.length
              ? table.table.grid[col]
              : (table.colBoundary(i) - table.colBoundary(col)).clamp(24, 900);
          return (table: table.table, column: true, index: col, start: width);
        }
      }
      for (int i = 1; i <= table.rowCount; i++) {
        final double y = table.rowBoundary(i);
        if ((local.dy - y).abs() <= slop) {
          final int row = i - 1;
          final double height = row < table.table.rows.length
              ? (table.table.rows[row].height ??
                    (table.rowBoundary(i) - table.rowBoundary(row)))
              : 24;
          return (table: table.table, column: false, index: row, start: height);
        }
      }
    }
    return null;
  }

  bool _tryTableResize(Offset window) {
    final (int page, Offset local) = _hitPage(window);
    if (page < 0 || page >= laidOut.pages.length) {
      return false;
    }
    final ({WmlTable table, bool column, int index, double start})? edge =
        _tableEdgeAt(laidOut.pages[page], local);
    if (edge == null) {
      return false;
    }
    _tableResize = edge;
    onBeginTableResize?.call(edge.table);
    markNeedsPaint();
    onChanged?.call();
    return true;
  }

  void _dragTableEdge(Offset delta) {
    final ({WmlTable table, bool column, int index, double start})? drag =
        _tableResize;
    if (drag == null) {
      return;
    }
    final Offset page = Offset(delta.dx / _viewScale, delta.dy / _viewScale);
    if (drag.column) {
      final double next = (drag.start + page.dx).clamp(24, 900);
      _tableResize = (
        table: drag.table,
        column: true,
        index: drag.index,
        start: next,
      );
      onPreviewTableColumnWidth?.call(drag.table, drag.index, next);
    } else {
      final double next = (drag.start + page.dy).clamp(16, 480);
      _tableResize = (
        table: drag.table,
        column: false,
        index: drag.index,
        start: next,
      );
      onPreviewTableRowHeight?.call(drag.table, drag.index, next);
    }
  }

  @override
  /// performLayout API.
  void performLayout() {
    final double scale = compact ? 1 : _viewScale;
    final Size content;
    if (compact) {
      var bottom = 24.0;
      if (laidOut.pages.isNotEmpty) {
        for (final LaidOutLine line in laidOut.pages.first.lines) {
          final double edge = line.y + line.height;
          if (edge > bottom) {
            bottom = edge;
          }
        }
      }
      content = Size(
        constraints.hasBoundedWidth
            ? constraints.maxWidth
            : laidOut.pageSize.width,
        bottom + 8,
      );
    } else {
      var maxW = laidOut.pageSize.width;
      var stackH = 24.0;
      for (final LaidOutPage page in laidOut.pages) {
        if (page.width > maxW) {
          maxW = page.width;
        }
        stackH += page.height * scale + 24;
      }
      if (laidOut.pages.isEmpty) {
        stackH += laidOut.pageSize.height * scale + 24;
      }
      content = Size(maxW * scale + 64, stackH);
    }
    size = compact
        ? constraints.constrain(content)
        : (constraints.hasBoundedWidth && constraints.hasBoundedHeight
              ? constraints.constrain(constraints.biggest)
              : constraints.constrain(content));
    viewport.extent = size;
    if (!compact) {
      _clampViewport();
    }
    _ensurePaintMetrics();
  }

  Size get _contentSize {
    final double scale = _viewScale;
    var maxW = laidOut.pageSize.width;
    var stackH = 24.0;
    for (final LaidOutPage page in laidOut.pages) {
      if (page.width > maxW) {
        maxW = page.width;
      }
      stackH += page.height * scale + 24;
    }
    if (laidOut.pages.isEmpty) {
      stackH += laidOut.pageSize.height * scale + 24;
    }
    return Size(maxW * scale + 64, stackH);
  }

  void _clampViewport() {
    viewport.clampTo(content: _contentSize, view: size);
  }

  Rect get _vTrack =>
      Rect.fromLTWH(size.width - _scrollBar, 0, _scrollBar, size.height);

  /// max API.
  double get _maxScrollY => math.max(0, _contentSize.height - size.height);

  Rect get _vThumb {
    final double maxY = _maxScrollY;
    final double trackH = _vTrack.height;
    final double thumbH =
        (_contentSize.height <= 0
                ? 22.0
                : trackH * (size.height / _contentSize.height))
            .clamp(22.0, trackH);
    final double y = maxY <= 0
        ? _vTrack.top
        : _vTrack.top + (trackH - thumbH) * (viewport.origin.dy / maxY);
    return Rect.fromLTWH(_vTrack.left + 2, y, _vTrack.width - 4, thumbH);
  }

  int _pageAtViewport() {
    return laidOut.pageIndexAtContentY(
      viewport.origin.dy + size.height * 0.35,
      _viewScale,
    );
  }

  void _jumpScroll(Offset local) {
    final double maxY = _maxScrollY;
    if (maxY <= 0 || _vTrack.height <= 0) {
      return;
    }
    final double t = ((local.dy - _vTrack.top) / _vTrack.height).clamp(0, 1);
    viewport.origin = Offset(viewport.origin.dx, maxY * t);
    _clampViewport();
    _scrollPageTip = _pageAtViewport();
  }

  void _dragScroll(Offset delta) {
    final double maxY = _maxScrollY;
    if (maxY <= 0 || _vTrack.height <= 0) {
      return;
    }
    viewport.origin = Offset(
      viewport.origin.dx,
      viewport.origin.dy + delta.dy * (maxY / _vTrack.height),
    );
    _clampViewport();
    _scrollPageTip = _pageAtViewport();
    markNeedsPaint();
    onChanged?.call();
  }

  void _paintScrollBar(Canvas canvas) {
    if (compact) {
      return;
    }
    canvas.drawRect(_vTrack, Paint()..color = const Color(0xFFE8E8E8));
    canvas.drawRRect(
      RRect.fromRectAndRadius(_vThumb, const Radius.circular(4)),
      Paint()..color = const Color(0xFF7A7A7A),
    );
    final int? tip = _scrollPageTip;
    if (tip == null) {
      return;
    }
    final String label = '${tip + 1} / ${laidOut.pages.length}';
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double tipW = painter.width + 16;
    final double tipH = painter.height + 10;
    final double tipX = (_vTrack.left - tipW - 8).clamp(
      8,
      size.width - tipW - 8,
    );
    final double tipY = (_vThumb.center.dy - tipH / 2).clamp(
      8,
      size.height - tipH - 8,
    );
    final RRect bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(tipX, tipY, tipW, tipH),
      const Radius.circular(4),
    );
    canvas.drawRRect(bubble, Paint()..color = const Color(0xE62B2B2B));
    painter.paint(canvas, Offset(tipX + 8, tipY + 5));
  }

  @override
  /// detach API.
  void detach() {
    _tap?.dispose();
    _pan?.dispose();
    _tap = null;
    _pan = null;
    super.detach();
  }

  void _ensureRecognizers() {
    _tap ??= TapGestureRecognizer(debugOwner: this);
    _pan ??= PanGestureRecognizer(debugOwner: this)
      ..onUpdate = (DragUpdateDetails details) {
        if (_scrollDrag) {
          _dragScroll(details.delta);
          return;
        }
        if (_draggingVisual) {
          _dragVisual(details.delta);
          return;
        }
        if (_tableResize != null) {
          _dragTableEdge(details.delta);
          return;
        }
        if (_tableBand != null) {
          _extendTableBand(details.localPosition);
          return;
        }
        if (_selectEquationAt(details.localPosition)) {
          return;
        }
        _placeCaret(details.localPosition, extend: true);
      }
      ..onEnd = (DragEndDetails details) {
        if (_scrollDrag) {
          _scrollDrag = false;
          _scrollPageTip = null;
          markNeedsPaint();
          onChanged?.call();
          return;
        }
        if (_draggingVisual) {
          onCommitVisualTransform?.call();
          _draggingVisual = false;
          _visualHandle = null;
        }
        if (_tableResize != null) {
          onCommitTableResize?.call(_tableResize!.table);
          _tableResize = null;
        }
        _tableBand = null;
      };
  }

  @override
  /// handleEvent API.
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (compact && event is PointerScrollEvent) {
      return;
    }
    if (event is PointerScrollEvent) {
      final bool zoom =
          HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      if (zoom) {
        final double factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
        viewport.setScale(viewport.scale * factor);
      } else {
        viewport.pan(event.scrollDelta);
      }
      _clampViewport();
      _scrollPageTip = _pageAtViewport();
      markNeedsPaint();
      onChanged?.call();
      return;
    }
    if (event is PointerHoverEvent || event is PointerMoveEvent) {
      _hoverLocal = event.localPosition;
      if (!compact && _vTrack.contains(event.localPosition)) {
        _scrollPageTip = _pageAtViewport();
      } else if (!_scrollDrag) {
        _scrollPageTip = null;
      }
      markNeedsPaint();
    }
    if (event is PointerDownEvent &&
        !compact &&
        _vTrack.contains(event.localPosition)) {
      _scrollDrag = true;
      _jumpScroll(event.localPosition);
      _ensureRecognizers();
      _pan!.addPointer(event);
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
      if (_tryTableHandle(event.localPosition)) {
        return;
      }
      if (_tryTableResize(event.localPosition)) {
        _ensureRecognizers();
        _pan!.addPointer(event);
        return;
      }
      if (_tryInsertHandle(event.localPosition)) {
        return;
      }
      if (_tryTableBand(event.localPosition)) {
        _ensureRecognizers();
        _pan!.addPointer(event);
        return;
      }
      _ensureRecognizers();
      _tap!.addPointer(event);
      _pan!.addPointer(event);
      _handleClick(event.localPosition);
    }
  }

  double _pageLeftPx() {
    if (compact) {
      return 0;
    }
    final double pageW = laidOut.pageSize.width * _viewScale;
    if (size.width > pageW + 64) {
      return (size.width - pageW) / 2;
    }
    return 32;
  }

  (int, Offset) _hitPage(Offset window) {
    if (compact) {
      return (0, window);
    }
    final double scale = _viewScale;
    final double x = (window.dx + viewport.origin.dx - _pageLeftPx()) / scale;
    var top = 24.0;
    for (int i = 0; i < laidOut.pages.length; i++) {
      final LaidOutPage page = laidOut.pages[i];
      final double y = (window.dy + viewport.origin.dy - top) / scale;
      if (y >= -8 && y <= page.height + 8) {
        return (i, Offset(x, y));
      }
      top += page.height * scale + 24;
    }
    return (0, Offset(x, (window.dy + viewport.origin.dy - 24) / scale));
  }

  void _handleClick(Offset window) {
    final bool extend = HardwareKeyboard.instance.isShiftPressed;
    final int taps = extend ? 1 : _countTap(window);
    _ensurePaintMetrics();
    final (int page, Offset local) = _hitPage(window);
    if (page >= 0 && page < laidOut.pages.length) {
      final bool? chromeFooter = _chromeHit(laidOut.pages[page], local);
      if (taps >= 2 && chromeFooter != null && config.allowsMutation) {
        onBeginHeaderFooterEdit?.call(page, footer: chromeFooter);
        markNeedsPaint();
        onChanged?.call();
        return;
      }
      if (_editingHeaderFooter) {
        if (chromeFooter != null &&
            ((chromeFooter && editingFooter) ||
                (!chromeFooter && editingHeader))) {
          _placeChromeCaret(laidOut.pages[page], local, extend: extend);
          markNeedsPaint();
          onChanged?.call();
          return;
        }
        onEndHeaderFooterEdit?.call();
      }
      if (_tryTableHandle(window)) {
        return;
      }
      if (_selectEquationAt(window)) {
        return;
      }
      final WmlHyperlink? link = _linkAt(laidOut.pages[page], local);
      if (link != null && _ctrlFollow) {
        onFollowLink?.call(link);
        markNeedsPaint();
        onChanged?.call();
        return;
      }
      final int? commentId = _commentIdAt(laidOut.pages[page], local);
      onSelectComment?.call(commentId);
      if (_trySelectedVisualHandle(page, local)) {
        return;
      }
      final LaidOutBox? visualBox = _visualAt(laidOut.pages[page], local);
      final OfficeVisual? visual = visualBox?.visual;
      if (visual != null) {
        if (extend) {
          onExtendThroughVisual?.call(visual);
        } else {
          onSelectVisual?.call(visual);
        }
        if (config.allowsMutation && !extend) {
          final int? handle = visualBox == null
              ? null
              : TransformHandles(
                  Rect.fromLTWH(
                    visualBox.x,
                    visualBox.y,
                    visualBox.width,
                    visualBox.height,
                  ),
                ).hit(local, radius: 14);
          _visualHandle = handle ?? 9;
          _draggingVisual = true;
          onBeginVisualTransform?.call();
        }
        markNeedsPaint();
        onChanged?.call();
        return;
      }
    }
    onSelectVisual?.call(null);
    onSelectEquation?.call(null, null, null);
    onSelectTable?.call(null);
    _placeCaret(window, extend: extend, notify: false);
    if (!extend) {
      final String text = _paragraphText();
      if (taps >= 3) {
        caret.selectParagraph(text);
      } else if (taps == 2) {
        caret.selectWord(text, caret.logicalIndex);
      }
    }
    markNeedsPaint();
    onChanged?.call();
  }

  int _countTap(Offset window) {
    final DateTime now = DateTime.now();
    final bool chained =
        _lastTapAt != null &&
        now.difference(_lastTapAt!) <= kDoubleTapTimeout &&
        _lastTapPos != null &&
        (window - _lastTapPos!).distance <= kDoubleTapSlop;
    _tapCount = chained ? _tapCount + 1 : 1;
    if (_tapCount > 3) {
      _tapCount = 1;
    }
    _lastTapAt = now;
    _lastTapPos = window;
    return _tapCount;
  }

  String _paragraphText() {
    final List<WmlParagraph> paras =
        storyParagraphs ?? document.paragraphs.toList();
    if (paras.isEmpty) {
      return '';
    }
    return paras[caret.paragraphIndex.clamp(0, paras.length - 1)].text;
  }

  bool? _chromeHit(LaidOutPage page, Offset local) {
    if (page.footerBand.contains(local.dx, local.dy)) {
      return true;
    }
    if (page.headerBand.contains(local.dx, local.dy)) {
      return false;
    }
    return null;
  }

  void _placeChromeCaret(
    LaidOutPage page,
    Offset local, {
    required bool extend,
  }) {
    final List<LaidOutLine> story = editingFooter ? page.footer : page.header;
    LaidOutLine? line = _nearestChromeLine(story, local);
    if (line == null && story.isNotEmpty) {
      line = story.last;
    }
    if (line != null) {
      caret.paragraphIndex = line.paragraphIndex;
      caret.logicalIndex = _hitOffsetOnLine(line, local);
    } else {
      caret.paragraphIndex = 0;
      caret.logicalIndex = 0;
    }
    if (!extend) {
      caret.collapseSelection();
    }
    caret.resetBlink();
  }

  LaidOutLine? _nearestChromeLine(List<LaidOutLine> lines, Offset local) {
    LaidOutLine? best;
    var bestScore = double.infinity;
    for (final LaidOutLine line in lines) {
      final bool inY = local.dy >= line.y && local.dy <= line.y + line.height;
      final double lineW = line.width < 8 ? 8 : line.width;
      if (inY && local.dx >= line.x && local.dx <= line.x + lineW) {
        return line;
      }
      final double xDist = local.dx < line.x
          ? line.x - local.dx
          : (local.dx > line.x + lineW ? local.dx - (line.x + lineW) : 0);
      final double yDist = inY
          ? 0
          : (local.dy < line.y
                ? line.y - local.dy
                : local.dy - (line.y + line.height));
      final double score = yDist * 10000 + xDist;
      if (score < bestScore) {
        bestScore = score;
        best = line;
      }
    }
    return best;
  }

  /// notify API.
  void _placeCaret(Offset window, {required bool extend, bool notify = true}) {
    _ensurePaintMetrics();
    final (int page, Offset local) = _hitPage(window);
    if (page < 0 || page >= laidOut.pages.length) {
      return;
    }
    final LaidOutPage laidPage = laidOut.pages[page];
    if (extend) {
      final OfficeVisual? visual = _visualAt(laidPage, local)?.visual;
      if (visual != null) {
        onExtendThroughVisual?.call(visual);
        if (notify) {
          markNeedsPaint();
          onChanged?.call();
        }
        return;
      }
    }
    if (_editingHeaderFooter) {
      _placeChromeCaret(laidPage, local, extend: extend);
      if (notify) {
        markNeedsPaint();
        onChanged?.call();
      }
      return;
    }
    final LaidOutBox? cell = _cellAt(laidPage, local);
    final LaidOutLine? line = _lineAt(laidPage, local);
    if (line != null && line.paragraphIndex < 0) {
      return;
    }
    if (line != null) {
      caret.paragraphIndex = line.paragraphIndex;
      caret.logicalIndex = _hitOffsetOnLine(line, local);
    } else if (cell?.paragraphIndex != null) {
      caret.paragraphIndex = cell!.paragraphIndex!;
      caret.logicalIndex = 0;
    } else {
      caret.logicalIndex = 0;
    }
    if (!extend) {
      caret.collapseSelection();
    }
    caret.resetBlink();
    if (notify) {
      markNeedsPaint();
      onChanged?.call();
    }
  }

  LaidOutLine? _lineAt(LaidOutPage page, Offset local) {
    final LaidOutBox? cell = _cellAt(page, local);
    LaidOutLine? best;
    var bestScore = double.infinity;
    for (final LaidOutLine line in page.lines) {
      if (cell != null && !_lineInCell(line, cell)) {
        continue;
      }
      final bool inY = local.dy >= line.y && local.dy <= line.y + line.height;
      if (!inY && cell == null) {
        continue;
      }
      final double lineW = line.width < 8 ? 8 : line.width;
      if (inY && local.dx >= line.x && local.dx <= line.x + lineW) {
        return line;
      }
      final double xDist = local.dx < line.x
          ? line.x - local.dx
          : (local.dx > line.x + lineW ? local.dx - (line.x + lineW) : 0);
      final double yDist = inY
          ? 0
          : (local.dy < line.y
                ? line.y - local.dy
                : local.dy - (line.y + line.height));
      final double score = yDist * 10000 + xDist;
      if (score < bestScore) {
        bestScore = score;
        best = line;
      }
    }
    if (best != null) {
      return best;
    }
    if (cell != null) {
      return null;
    }
    return page.lines.isEmpty ? null : page.lines.last;
  }

  void _dragVisual(Offset delta) {
    final int? handle = _visualHandle;
    final OfficeVisual? visual = selectedVisual?.visual;
    if (handle == null || visual == null) {
      return;
    }
    final Offset pageDelta = Offset(
      delta.dx / _viewScale,
      delta.dy / _viewScale,
    );
    if (pictureCropMode && handle < 8) {
      _cropFromHandle(handle, pageDelta, visual);
      return;
    }
    if (handle == 9) {
      onPreviewVisualMove?.call(pageDelta.dx, pageDelta.dy);
      return;
    }
    if (handle == 8) {
      _rotateFromPointer(visual);
      return;
    }
    _resizeFromHandle(handle, pageDelta, visual);
  }

  void _rotateFromPointer(OfficeVisual visual) {
    final LaidOutBox? box = _selectedVisualBox();
    if (box == null) {
      return;
    }
    final Offset window = _hoverLocal ?? Offset.zero;
    final (int page, Offset local) = _hitPage(window);
    if (page < 0) {
      return;
    }
    final Offset center = Offset(box.x + box.width / 2, box.y + box.height / 2);
    final double deg =
        math.atan2(local.dx - center.dx, center.dy - local.dy) * 180 / math.pi;
    onPreviewVisualRotate?.call(deg);
  }

  bool _trySelectedVisualHandle(int page, Offset local) {
    if (!config.allowsMutation) {
      return false;
    }
    final LaidOutBox? selectedBox = _selectedVisualBoxOn(page);
    if (selectedBox == null) {
      return false;
    }
    final int? handle = TransformHandles(
      Rect.fromLTWH(
        selectedBox.x,
        selectedBox.y,
        selectedBox.width,
        selectedBox.height,
      ),
    ).hit(local, radius: 14);
    if (handle == null) {
      return false;
    }
    _visualHandle = handle;
    _draggingVisual = true;
    onBeginVisualTransform?.call();
    markNeedsPaint();
    onChanged?.call();
    return true;
  }

  void _resizeFromHandle(int handle, Offset d, OfficeVisual visual) {
    var width = visual.width;
    var height = visual.height;
    var shift = 0.0;
    switch (handle) {
      case 0:
        shift = d.dx;
        width -= d.dx;
        height -= d.dy;
      case 1:
        height -= d.dy;
      case 2:
        width += d.dx;
        height -= d.dy;
      case 3:
        width += d.dx;
      case 4:
        width += d.dx;
        height += d.dy;
      case 5:
        height += d.dy;
      case 6:
        shift = d.dx;
        width -= d.dx;
        height += d.dy;
      case 7:
        shift = d.dx;
        width -= d.dx;
    }
    onPreviewVisualResize?.call(width: width, height: height);
    if (shift != 0) {
      onPreviewVisualMove?.call(shift, 0);
    }
  }

  void _cropFromHandle(int handle, Offset d, OfficeVisual visual) {
    final LaidOutBox? box = _selectedVisualBox();
    if (box == null || box.width <= 1 || box.height <= 1) {
      return;
    }
    final double dl = d.dx / box.width;
    final double dt = d.dy / box.height;
    var left = visual.picture.cropLeft;
    var top = visual.picture.cropTop;
    var right = visual.picture.cropRight;
    var bottom = visual.picture.cropBottom;
    switch (handle) {
      case 0:
        left += dl;
        top += dt;
      case 1:
        top += dt;
      case 2:
        right -= dl;
        top += dt;
      case 3:
        right -= dl;
      case 4:
        right -= dl;
        bottom -= dt;
      case 5:
        bottom -= dt;
      case 6:
        left += dl;
        bottom -= dt;
      case 7:
        left += dl;
    }
    onPreviewVisualCrop?.call(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  LaidOutBox? _selectedVisualBox() {
    final WmlVisual? selected = selectedVisual;
    if (selected == null) {
      return null;
    }
    for (final LaidOutPage page in laidOut.pages) {
      for (final LaidOutBox box in page.frames) {
        if (box.visual != null && identical(box.visual, selected.visual)) {
          return box;
        }
      }
    }
    return null;
  }

  bool _selectEquationAt(Offset window) {
    final (int page, Offset local) = _hitPage(window);
    if (page < 0 || page >= laidOut.pages.length) {
      return false;
    }
    final LaidOutBox? equationBox = _equationAt(laidOut.pages[page], local);
    final WmlEquation? equation = equationBox?.equation;
    if (equation == null) {
      return false;
    }
    final LaidOutOmml? omml = equationBox!.omml;
    final Offset inside = Offset(
      local.dx - equationBox.x,
      local.dy - equationBox.y,
    );
    final int? slot = omml == null
        ? null
        : PaintEquation.hitSlot(omml, inside, root: equation.math.root);
    final int? caret = omml == null || slot == null
        ? null
        : PaintEquation.hitCaret(
            omml,
            inside,
            slotIndex: slot,
            root: equation.math.root,
          );
    onSelectEquation?.call(equation, slot, caret);
    markNeedsPaint();
    onChanged?.call();
    return true;
  }

  LaidOutBox? _equationAt(LaidOutPage page, Offset local) {
    for (final LaidOutBox box in page.frames) {
      if (box.kind != LaidOutBoxKind.equation || box.equation == null) {
        continue;
      }
      if (local.dx >= box.x - 4 &&
          local.dx <= box.x + box.width + 4 &&
          local.dy >= box.y - 4 &&
          local.dy <= box.y + box.height + 4) {
        return box;
      }
    }
    return null;
  }

  LaidOutBox? _visualAt(LaidOutPage page, Offset local) {
    LaidOutBox? best;
    var bestArea = double.infinity;
    for (final LaidOutBox box in page.frames) {
      if (box.kind == LaidOutBoxKind.tableCell || box.visual == null) {
        continue;
      }
      if (local.dx >= box.x &&
          local.dx <= box.x + box.width &&
          local.dy >= box.y &&
          local.dy <= box.y + box.height) {
        final double area = box.width * box.height;
        if (area < bestArea) {
          bestArea = area;
          best = box;
        }
      }
    }
    return best;
  }

  void _handleContext(PointerDownEvent event) {
    final (int pageHint, Offset localHint) = _hitPage(event.localPosition);
    final _TableGeom? handle = pageHint >= 0 && pageHint < laidOut.pages.length
        ? _tableHandleAt(laidOut.pages[pageHint], localHint)
        : null;
    final ValueChanged<OfficeContextHit>? callback = onContextMenu;
    if (callback == null) {
      return;
    }
    final (int page, Offset local) = _hitPage(event.localPosition);
    if (page < 0 || page >= laidOut.pages.length) {
      callback(
        OfficeContextHit(
          kind: compact
              ? OfficeContextKind.comment
              : OfficeContextKind.document,
          globalPosition: event.position,
          commentId: selectedCommentId,
        ),
      );
      return;
    }
    final LaidOutPage laidPage = laidOut.pages[page];
    final LaidOutBox? visual = _visualAt(laidPage, local);
    final LaidOutBox? equation = _equationAt(laidPage, local);
    final LaidOutBox? cell = _cellAt(laidPage, local);
    final int? commentId = _commentIdAt(laidPage, local) ?? selectedCommentId;
    final WmlHyperlink? link = _linkAt(laidPage, local);
    final OfficeContextKind kind;
    if (handle != null) {
      kind = OfficeContextKind.tableHandle;
    } else if (visual != null) {
      kind = OfficeContextKind.picture;
    } else if (equation != null) {
      kind = OfficeContextKind.equation;
    } else if (cell != null) {
      kind = OfficeContextKind.table;
    } else if (commentId != null) {
      kind = OfficeContextKind.comment;
    } else if (link != null) {
      kind = OfficeContextKind.hyperlink;
    } else {
      kind = OfficeContextKind.document;
    }
    callback(
      OfficeContextHit(
        kind: kind,
        globalPosition: event.position,
        table: handle?.table ?? cell?.table,
        tableRow: cell?.tableRow,
        tableCol: cell?.tableCol,
        visual: visual?.visual,
        commentId: commentId,
        link: link,
        equation: equation?.equation,
      ),
    );
  }

  bool _tryInsertHandle(Offset window) {
    if (compact || !config.allowsMutation) {
      return false;
    }
    final (int page, Offset local) = _hitPage(window);
    if (page < 0 || page >= laidOut.pages.length) {
      return false;
    }
    final _TableInsertHit? hit = _insertHitAt(laidOut.pages[page], local);
    if (hit == null) {
      return false;
    }
    if (hit.column) {
      onInsertTableColumnAt?.call(hit.table, hit.index);
    } else {
      onInsertTableRowAt?.call(hit.table, hit.index);
    }
    markNeedsPaint();
    onChanged?.call();
    return true;
  }

  _TableInsertHit? _insertHitAt(LaidOutPage page, Offset local) {
    if (compact || !config.allowsMutation) {
      return null;
    }
    for (final _TableGeom table in _tablesOn(page)) {
      final _TableInsertHit? hit = _nearestInsertHit(table, local);
      if (hit != null && hit.button.inflate(6).contains(local)) {
        return hit;
      }
    }
    return null;
  }

  _TableInsertHit? _insertHoverAt(LaidOutPage page, Offset local) {
    if (compact || !config.allowsMutation) {
      return null;
    }
    for (final _TableGeom table in _tablesOn(page)) {
      final _TableInsertHit? hit = _nearestInsertHit(table, local);
      if (hit != null) {
        return hit;
      }
    }
    return null;
  }

  bool _tryTableBand(Offset window) {
    if (compact || !config.allowsSelection) {
      return false;
    }
    final (int page, Offset local) = _hitPage(window);
    if (page < 0 || page >= laidOut.pages.length) {
      return false;
    }
    final _TableBandHit? hit = _tableBandAt(laidOut.pages[page], local);
    if (hit == null) {
      return false;
    }
    _tableBand = (
      table: hit.table,
      column: hit.column,
      anchor: hit.index,
      current: hit.index,
    );
    onSelectTableBand?.call(
      hit.table,
      column: hit.column,
      from: hit.index,
      to: hit.index,
    );
    markNeedsPaint();
    onChanged?.call();
    return true;
  }

  void _extendTableBand(Offset window) {
    final ({WmlTable table, bool column, int anchor, int current})? drag =
        _tableBand;
    if (drag == null) {
      return;
    }
    final (int page, Offset local) = _hitPage(window);
    if (page < 0 || page >= laidOut.pages.length) {
      return;
    }
    for (final _TableGeom table in _tablesOn(laidOut.pages[page])) {
      if (!identical(table.table, drag.table)) {
        continue;
      }
      final int index = drag.column
          ? table.colIndexAt(local.dx, clamp: true)
          : table.rowIndexAt(local.dy, clamp: true);
      if (index < 0 || index == drag.current) {
        return;
      }
      _tableBand = (
        table: drag.table,
        column: drag.column,
        anchor: drag.anchor,
        current: index,
      );
      onSelectTableBand?.call(
        drag.table,
        column: drag.column,
        from: drag.anchor,
        to: index,
      );
      markNeedsPaint();
      onChanged?.call();
      return;
    }
  }

  _TableBandHit? _tableBandAt(LaidOutPage page, Offset local) {
    if (compact) {
      return null;
    }
    const double gutter = 22;
    const double insertSlop = 5;
    for (final _TableGeom table in _tablesOn(page)) {
      if (table.handleRect.inflate(4).contains(local)) {
        continue;
      }
      for (final _TableInsertHit hit in _tableInsertHitsFor(table)) {
        if (hit.button.inflate(3).contains(local)) {
          return null;
        }
      }
      if (local.dx >= table.bounds.left - gutter &&
          local.dx < table.bounds.left - 1 &&
          local.dy >= table.bounds.top &&
          local.dy <= table.bounds.bottom) {
        if (!_nearAxisBoundary(
          table,
          local.dy,
          column: false,
          slop: insertSlop,
        )) {
          final int row = table.rowIndexAt(local.dy);
          if (row >= 0) {
            return _TableBandHit(
              table: table.table,
              column: false,
              index: row,
              highlight: table.rowBand(row, row),
            );
          }
        }
      }
      if (local.dy >= table.bounds.top - gutter &&
          local.dy < table.bounds.top - 1 &&
          local.dx >= table.bounds.left &&
          local.dx <= table.bounds.right) {
        if (!_nearAxisBoundary(
          table,
          local.dx,
          column: true,
          slop: insertSlop,
        )) {
          final int col = table.colIndexAt(local.dx);
          if (col >= 0) {
            return _TableBandHit(
              table: table.table,
              column: true,
              index: col,
              highlight: table.colBand(col, col),
            );
          }
        }
      }
    }
    return null;
  }

  bool _nearAxisBoundary(
    _TableGeom table,
    double value, {
    required bool column,
    required double slop,
  }) {
    final int count = column ? table.colCount : table.rowCount;
    for (int i = 0; i <= count; i++) {
      final double edge = column ? table.colBoundary(i) : table.rowBoundary(i);
      if ((value - edge).abs() <= slop) {
        return true;
      }
    }
    return false;
  }

  _TableGeom? _tableHandleAt(LaidOutPage page, Offset local) {
    if (compact) {
      return null;
    }
    for (final _TableGeom table in _tablesOn(page)) {
      if (table.handleRect.inflate(8).contains(local)) {
        return table;
      }
    }
    return null;
  }

  bool _tryTableHandle(Offset window) {
    final (int page, Offset local) = _hitPage(window);
    if (page < 0 || page >= laidOut.pages.length) {
      return false;
    }
    final _TableGeom? handle = _tableHandleAt(laidOut.pages[page], local);
    if (handle == null) {
      return false;
    }
    onSelectTable?.call(handle.table);
    markNeedsPaint();
    onChanged?.call();
    return true;
  }

  _TableInsertHit? _nearestInsertHit(_TableGeom table, Offset local) {
    if (!table.bounds.inflate(28).contains(local)) {
      return null;
    }
    if (table.handleRect.inflate(2).contains(local)) {
      return null;
    }
    _TableInsertHit? best;
    var bestDist = 8.0;
    for (final _TableInsertHit hit in _tableInsertHitsFor(table)) {
      if (hit.button.inflate(4).contains(local)) {
        return hit;
      }
      final bool onAxis;
      final double dist;
      if (hit.column) {
        final bool inTopGutter =
            local.dy >= table.bounds.top - 26 &&
            local.dy <= table.bounds.top + 4;
        onAxis = inTopGutter && (local.dx - hit.axis).abs() <= 6;
        dist = (local.dx - hit.axis).abs();
      } else {
        final bool inLeftGutter =
            local.dx >= table.bounds.left - 26 &&
            local.dx <= table.bounds.left + 4;
        onAxis = inLeftGutter && (local.dy - hit.axis).abs() <= 6;
        dist = (local.dy - hit.axis).abs();
      }
      if (!onAxis) {
        continue;
      }
      if (dist < bestDist) {
        bestDist = dist;
        best = hit;
      }
    }
    return best;
  }

  List<_TableGeom> _tablesOn(LaidOutPage page) {
    final Map<WmlTable, _TableGeom> groups = <WmlTable, _TableGeom>{};
    for (final LaidOutBox box in page.frames) {
      if (box.kind != LaidOutBoxKind.tableCell || box.table == null) {
        continue;
      }
      final WmlTable table = box.table!;
      final _TableGeom geom = groups.putIfAbsent(
        table,
        () => _TableGeom(table),
      );
      geom.add(box);
    }
    return groups.values.toList();
  }

  void _paintSelectedTables(Canvas canvas, LaidOutPage page) {
    if (selectedTable == null) {
      return;
    }
    for (final _TableGeom table in _tablesOn(page)) {
      if (!identical(selectedTable, table.table)) {
        continue;
      }
      canvas.drawRect(
        table.bounds,
        Paint()
          ..color = _theme.selectionStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      _paintTableHandle(canvas, table);
    }
  }

  void _paintTableBandChrome(Canvas canvas, LaidOutPage page) {
    final ({WmlTable table, bool column, int anchor, int current})? drag =
        _tableBand;
    if (drag != null) {
      for (final _TableGeom table in _tablesOn(page)) {
        if (!identical(table.table, drag.table)) {
          continue;
        }
        _paintTableBand(
          canvas,
          drag.column
              ? table.colBand(drag.anchor, drag.current)
              : table.rowBand(drag.anchor, drag.current),
          active: true,
        );
      }
      return;
    }
    if (!config.allowsSelection || compact) {
      return;
    }
    final Offset? hover = _hoverLocal;
    if (hover == null) {
      return;
    }
    final (int hoverPage, Offset local) = _hitPage(hover);
    if (hoverPage < 0 ||
        hoverPage >= laidOut.pages.length ||
        !identical(laidOut.pages[hoverPage], page)) {
      return;
    }
    final _TableBandHit? band = _tableBandAt(page, local);
    if (band != null) {
      _paintTableBand(canvas, band.highlight, active: false);
    }
  }

  void _paintTableInsertHandles(Canvas canvas, LaidOutPage page) {
    if (compact || !config.allowsMutation) {
      return;
    }
    final Offset? hover = _hoverLocal;
    Offset? local;
    if (hover != null) {
      final (int hoverPage, Offset pageLocal) = _hitPage(hover);
      if (hoverPage >= 0 &&
          hoverPage < laidOut.pages.length &&
          identical(laidOut.pages[hoverPage], page)) {
        local = pageLocal;
      }
    }
    if (local == null) {
      return;
    }
    for (final _TableGeom table in _tablesOn(page)) {
      if (!table.bounds.inflate(32).contains(local)) {
        continue;
      }
      if (selectedTable == null || !identical(selectedTable, table.table)) {
        _paintTableHandle(canvas, table);
      }
      final _TableInsertHit? hot = _nearestInsertHit(table, local);
      if (hot == null) {
        continue;
      }
      _paintInsertGuide(canvas, hot);
      _paintPlusButton(canvas, hot.button, active: true);
    }
  }

  void _paintInsertGuide(Canvas canvas, _TableInsertHit hot) {
    canvas.drawLine(
      hot.lineStart,
      hot.lineEnd,
      Paint()
        ..color = const Color(0x662E75B6)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      hot.lineStart,
      hot.lineEnd,
      Paint()
        ..color = const Color(0xFF2E75B6)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintTableBand(Canvas canvas, Rect highlight, {required bool active}) {
    canvas.drawRect(
      highlight,
      Paint()
        ..color = active ? const Color(0x552E75B6) : const Color(0x332E75B6),
    );
  }

  void _paintTableHandle(Canvas canvas, _TableGeom table) {
    final Rect handle = table.handleRect;
    final bool selected =
        selectedTable != null && identical(selectedTable, table.table);
    canvas.drawRRect(
      RRect.fromRectAndRadius(handle, const Radius.circular(2)),
      Paint()
        ..color = selected ? const Color(0xFF2E75B6) : const Color(0xFFFFFFFF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(handle, const Radius.circular(2)),
      Paint()
        ..color = const Color(0xFF2E75B6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final Paint dots = Paint()
      ..color = selected ? const Color(0xFFFFFFFF) : const Color(0xFF2E75B6);
    for (int r = 0; r < 2; r++) {
      for (int c = 0; c < 2; c++) {
        canvas.drawCircle(
          Offset(handle.left + 3.5 + c * 5, handle.top + 3.5 + r * 5),
          1.05,
          dots,
        );
      }
    }
  }

  List<_TableInsertHit> _tableInsertHitsFor(_TableGeom table) {
    final List<_TableInsertHit> hits = <_TableInsertHit>[];
    for (int i = 0; i <= table.rowCount; i++) {
      final double y = table.rowBoundary(i);
      hits.add(
        _TableInsertHit(
          table: table.table,
          column: false,
          index: i,
          button: Rect.fromCircle(
            center: Offset(table.bounds.left - 12, y),
            radius: 7,
          ),
          lineStart: Offset(table.bounds.left - 12, y),
          lineEnd: Offset(table.bounds.right, y),
        ),
      );
    }
    for (int i = 0; i <= table.colCount; i++) {
      final double x = table.colBoundary(i);
      hits.add(
        _TableInsertHit(
          table: table.table,
          column: true,
          index: i,
          button: Rect.fromCircle(
            center: Offset(x, table.bounds.top - 12),
            radius: 7,
          ),
          lineStart: Offset(x, table.bounds.top - 12),
          lineEnd: Offset(x, table.bounds.bottom),
        ),
      );
    }
    return hits;
  }

  void _paintPlusButton(Canvas canvas, Rect button, {required bool active}) {
    canvas.drawCircle(
      button.center,
      button.width / 2,
      Paint()
        ..color = active ? const Color(0xFF2E75B6) : const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(
      button.center,
      button.width / 2,
      Paint()
        ..color = const Color(0xFF2E75B6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final Paint plus = Paint()
      ..color = active ? const Color(0xFFFFFFFF) : const Color(0xFF2E75B6)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(button.center.dx - 3.2, button.center.dy),
      Offset(button.center.dx + 3.2, button.center.dy),
      plus,
    );
    canvas.drawLine(
      Offset(button.center.dx, button.center.dy - 3.2),
      Offset(button.center.dx, button.center.dy + 3.2),
      plus,
    );
  }

  LaidOutBox? _cellAt(LaidOutPage page, Offset local) {
    LaidOutBox? best;
    var bestArea = double.infinity;
    for (final LaidOutBox box in page.frames) {
      if (box.kind != LaidOutBoxKind.tableCell) {
        continue;
      }
      if (local.dx >= box.x &&
          local.dx <= box.x + box.width &&
          local.dy >= box.y &&
          local.dy <= box.y + box.height) {
        final double area = box.width * box.height;
        if (area < bestArea) {
          bestArea = area;
          best = box;
        }
      }
    }
    return best;
  }

  bool _lineInCell(LaidOutLine line, LaidOutBox cell) {
    if (cell.paragraphIndex != null) {
      final int start = cell.paragraphIndex!;
      final int end = cell.paragraphEnd ?? start;
      return line.paragraphIndex >= start && line.paragraphIndex <= end;
    }
    return line.x >= cell.x - 1 && line.x <= cell.x + cell.width;
  }

  int _hitOffsetOnLine(LaidOutLine line, Offset local) {
    if (line.glyphs.isEmpty) {
      final String text = line.overlayText ?? '';
      if (text.isEmpty || line.width <= 0) {
        return 0;
      }
      final double t = ((local.dx - line.x) / line.width).clamp(0.0, 1.0);
      return (t * text.length).round();
    }
    for (final LaidOutGlyph g in line.glyphs) {
      if (local.dx <= g.x + g.advance / 2) {
        return g.glyph.logicalIndex;
      }
    }
    return line.glyphs.last.glyph.logicalIndex + 1;
  }

  void _ensurePaintMetrics() {
    if (identical(_fittedLayout, laidOut)) {
      return;
    }
    for (final LaidOutPage page in laidOut.pages) {
      for (final LaidOutLine line in page.lines) {
        PaintRunText.fitLine(
          line,
          _paragraphTextAt(line.paragraphIndex),
          themeFamily: _theme.fontFamily,
        );
      }
    }
    _fittedLayout = laidOut;
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
      ..isTextField = this.config.allowsMutation && selectedVisual == null
      ..textDirection = this.config.textDirection;
  }

  @override
  /// paint API.
  void paint(PaintingContext context, Offset offset) {
    _ensurePaintMetrics();
    final Canvas canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = compact ? _theme.pageBackground : _theme.canvasBackground,
    );
    if (compact) {
      if (laidOut.pages.isNotEmpty) {
        _paintFrames(canvas, laidOut.pages.first);
        for (final LaidOutLine line in laidOut.pages.first.lines) {
          if (_paintsLineSelection(line, laidOut.pages.first)) {
            final BrokenLine broken = _broken(line);
            for (final Rect r in caret.selectionRects(
              broken,
              line.y,
              line.height,
              paragraph: line.paragraphIndex,
            )) {
              canvas.drawRect(
                r.shift(Offset(line.x, 0)),
                Paint()..color = _theme.selectionFill,
              );
            }
          }
          _drawLine(canvas, line);
          if (config.showsCaret &&
              hasFocus &&
              caret.visible &&
              line.paragraphIndex >= 0 &&
              caret.isOnLine(
                line,
                lastOfParagraph: _isLastParagraphLine(
                  laidOut.pages.first,
                  line,
                ),
              )) {
            canvas.drawRect(
              _caretPaintRect(line),
              Paint()..color = _theme.caret,
            );
          }
        }
      }
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
      return;
    }

    final double scale = _viewScale;
    final double pageLeft = _pageLeftPx();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-viewport.origin.dx, -viewport.origin.dy);

    var stackTop = 24.0;
    for (int i = 0; i < laidOut.pages.length; i++) {
      final LaidOutPage page = laidOut.pages[i];
      final double top = stackTop;
      stackTop += page.height * scale + 24;
      final Rect pageRect = Rect.fromLTWH(
        pageLeft,
        top,
        page.width * scale,
        page.height * scale,
      );
      if (!viewport.intersects(pageRect)) {
        continue;
      }
      canvas.drawShadow(
        Path()..addRect(pageRect.inflate(1)),
        const Color(0x66000000),
        8,
        false,
      );
      canvas.drawRect(pageRect, Paint()..color = _theme.pageBackground);
      canvas.drawRect(
        pageRect,
        Paint()
          ..color = _theme.pageBorder
          ..style = PaintingStyle.stroke,
      );

      canvas.save();
      canvas.translate(pageLeft, top);
      canvas.scale(scale);
      canvas.clipRect(Rect.fromLTWH(0, 0, page.width, page.height));
      _paintFrames(canvas, page, paintHandles: false);
      _paintSelectedTables(canvas, page);
      _paintTableBandChrome(canvas, page);
      for (final LaidOutLine line in page.header) {
        _drawOverlay(canvas, line, pageWidth: page.width);
      }
      if (_editingHeaderFooter) {
        canvas.drawRect(
          Rect.fromLTWH(
            0,
            page.headerBand.height,
            page.width,
            page.height - page.headerBand.height - page.footerBand.height,
          ),
          Paint()..color = const Color(0x55F3F3F3),
        );
      }
      for (final LaidOutLine line in page.lines) {
        if (!_editingHeaderFooter && _paintsLineSelection(line, page)) {
          final BrokenLine broken = _broken(line);
          for (final Rect r in caret.selectionRects(
            broken,
            line.y,
            line.height,
            paragraph: line.paragraphIndex,
          )) {
            canvas.drawRect(
              r.shift(Offset(line.x, 0)),
              Paint()..color = _theme.selectionFill,
            );
          }
        }
        _drawLine(canvas, line);
        if (!_editingHeaderFooter &&
            config.showsCaret &&
            hasFocus &&
            caret.visible &&
            line.paragraphIndex >= 0 &&
            caret.isOnLine(
              line,
              lastOfParagraph: _isLastParagraphLine(page, line),
            )) {
          canvas.drawRect(_caretPaintRect(line), Paint()..color = _theme.caret);
        }
      }
      for (final LaidOutLine line in page.footer) {
        _drawOverlay(canvas, line, pageWidth: page.width);
      }
      if (_editingHeaderFooter) {
        _paintHeaderFooterChrome(canvas, page);
      }
      canvas.restore();
      canvas.save();
      canvas.translate(pageLeft, top);
      canvas.scale(scale);
      _paintTableInsertHandles(canvas, page);
      _paintVisualHandles(canvas, page);
      canvas.restore();
    }
    canvas.restore();

    _paintScrollBar(canvas);
    _paintLinkHint(canvas);
    if (config.showRulers) {
      OfficeChrome.paintRuler(canvas, size, vertical: false, theme: _theme);
      OfficeChrome.paintRuler(canvas, size, vertical: true, theme: _theme);
    }
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

  bool _cellSelected(LaidOutBox box) {
    if (selectedTable != null &&
        box.table != null &&
        identical(selectedTable, box.table)) {
      return true;
    }
    final ({WmlTable table, bool column, int from, int to})? band =
        selectedTableBand;
    if (band != null && box.table != null && identical(band.table, box.table)) {
      return _boxInTableBand(box, band);
    }
    final int? start = box.paragraphIndex;
    if (start == null) {
      return false;
    }
    final int end = box.paragraphEnd ?? start;
    for (int p = start; p <= end; p++) {
      if (caret.coversParagraph(p)) {
        return true;
      }
    }
    return false;
  }

  bool _boxInTableBand(
    LaidOutBox box,
    ({WmlTable table, bool column, int from, int to}) band,
  ) {
    final int a = band.from < band.to ? band.from : band.to;
    final int b = band.from > band.to ? band.from : band.to;
    if (band.column) {
      final int col = box.tableGridCol ?? box.tableCol ?? 0;
      final int span = _cellGridSpan(box);
      return col <= b && col + span - 1 >= a;
    }
    final int row = box.tableRow ?? 0;
    return row >= a && row <= b;
  }

  int _cellGridSpan(LaidOutBox box) {
    final WmlTable? table = box.table;
    final int? rowIndex = box.tableRow;
    if (table == null || rowIndex == null || rowIndex >= table.rows.length) {
      return 1;
    }
    final int start = box.tableGridCol ?? box.tableCol ?? 0;
    var grid = 0;
    for (final WmlTableCell cell in table.rows[rowIndex].cells) {
      final int span = WordTable.spanOf(cell);
      if (grid == start) {
        return span;
      }
      grid += span;
    }
    return 1;
  }

  bool _paintsLineSelection(LaidOutLine line, LaidOutPage page) {
    if (!config.allowsSelection || line.paragraphIndex < 0) {
      return false;
    }
    if (!caret.coversParagraph(line.paragraphIndex)) {
      return false;
    }
    final ({WmlTable table, bool column, int from, int to})? band =
        selectedTableBand;
    if (band == null) {
      return true;
    }
    for (final LaidOutBox box in page.frames) {
      if (box.kind != LaidOutBoxKind.tableCell || box.table == null) {
        continue;
      }
      if (!identical(box.table, band.table)) {
        continue;
      }
      final int start = box.paragraphIndex ?? -1;
      final int end = box.paragraphEnd ?? start;
      if (line.paragraphIndex >= start && line.paragraphIndex <= end) {
        return false;
      }
    }
    return true;
  }

  bool get _ctrlFollow =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;

  String _commentHint(WmlComment comment) {
    final String body = comment.text.trim();
    final String preview = body.isEmpty
        ? comment.author
        : '${comment.author}: ${body.split('\n').first}';
    if (comment.resolved) {
      return '$preview  ✓';
    }
    return preview;
  }

  int? _commentIdAt(LaidOutPage page, Offset local) {
    for (final LaidOutLine line in <LaidOutLine>[
      ...page.header,
      ...page.lines,
      ...page.footer,
    ]) {
      if (local.dy < line.y - 2 || local.dy > line.y + line.height + 2) {
        continue;
      }
      for (final LaidOutGlyph glyph in line.glyphs) {
        if (glyph.commentIds.isEmpty) {
          continue;
        }
        if (local.dx >= glyph.x - 2 &&
            local.dx <= glyph.x + glyph.advance + 2) {
          return glyph.commentIds.last;
        }
      }
    }
    return null;
  }

  WmlHyperlink? _linkAt(LaidOutPage page, Offset local) {
    final int? toc = _tocTargetAt(page, local);
    if (toc != null) {
      final List<WmlParagraph> paras = document.paragraphs.toList();
      if (toc >= 0 && toc < paras.length) {
        final WmlParagraph para = paras[toc];
        return WmlHyperlink(
          anchor: para.properties.bookmarkName ?? para.text.trim(),
        );
      }
    }
    for (final LaidOutLine line in <LaidOutLine>[
      ...page.header,
      ...page.lines,
      ...page.footer,
    ]) {
      if (line.hyperlink != null &&
          local.dy >= line.y - 2 &&
          local.dy <= line.y + line.height + 2 &&
          local.dx >= line.x - 4 &&
          local.dx <= line.x + line.width + 4) {
        return line.hyperlink;
      }
      if (local.dy < line.y - 2 || local.dy > line.y + line.height + 2) {
        continue;
      }
      for (final LaidOutGlyph glyph in line.glyphs) {
        if (glyph.hyperlink == null) {
          continue;
        }
        if (local.dx >= glyph.x && local.dx <= glyph.x + glyph.advance) {
          return glyph.hyperlink;
        }
      }
    }
    return null;
  }

  void _paintLinkHint(Canvas canvas) {
    final Offset? hover = _hoverLocal;
    if (hover == null) {
      return;
    }
    final (int page, Offset local) = _hitPage(hover);
    if (page < 0 || page >= laidOut.pages.length) {
      return;
    }
    final int? commentId = _commentIdAt(laidOut.pages[page], local);
    final WmlComment? comment = commentId == null
        ? null
        : WordComment.byId(document, commentId);
    final WmlHyperlink? link = _linkAt(laidOut.pages[page], local);
    if (comment == null && link == null) {
      return;
    }
    final String hint = comment != null
        ? _commentHint(comment)
        : (_ctrlFollow
              ? link!.displayTarget
              : '${config.strings.followLinkHint}\n${link!.displayTarget}');
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: hint,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF222222),
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 260);
    final double x = (hover.dx + 16).clamp(8, size.width - painter.width - 8);
    final double y = (hover.dy + 18).clamp(8, size.height - painter.height - 8);
    final Rect box = Rect.fromLTWH(
      x - 6,
      y - 4,
      painter.width + 12,
      painter.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()..color = const Color(0xFFF7F7F7),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()
        ..color = const Color(0xFFB0B0B0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    painter.paint(canvas, Offset(x, y));
  }

  int? _tocTargetAt(LaidOutPage page, Offset local) {
    for (final LaidOutBox box in page.frames.reversed) {
      if (box.kind != LaidOutBoxKind.tocEntry || box.paragraphIndex == null) {
        continue;
      }
      if (_boxContains(box, local, pad: 3)) {
        return box.paragraphIndex;
      }
    }
    return null;
  }

  void _paintVisualHandles(Canvas canvas, LaidOutPage page) {
    for (final LaidOutBox box in page.frames) {
      final OfficeVisual? visual = box.visual;
      if (visual == null || box.kind == LaidOutBoxKind.tableCell) {
        continue;
      }
      final bool selected =
          selectedVisual != null && identical(visual, selectedVisual!.visual);
      final bool inRange =
          selected || (isVisualInSelection?.call(visual) ?? false);
      if (!inRange) {
        continue;
      }
      TransformHandles(
        Rect.fromLTWH(box.x, box.y, box.width, box.height),
      ).paint(
        canvas,
        strokeColor: pictureCropMode
            ? const Color(0xFFC45911)
            : _theme.focusRing,
        fillColor: _theme.pageBackground,
        showKnobs: true,
        showRotate: !pictureCropMode,
        knobSize: 9,
      );
    }
  }

  void _paintFrames(
    Canvas canvas,
    LaidOutPage page, {
    bool paintHandles = true,
  }) {
    for (final LaidOutBox box in page.frames) {
      if (box.kind == LaidOutBoxKind.tocEntry) {
        continue;
      }
      final Rect rect = Rect.fromLTWH(box.x, box.y, box.width, box.height);
      if (box.kind == LaidOutBoxKind.frame ||
          box.kind == LaidOutBoxKind.columnSep) {
        if (box.fillColor != null && box.fillColor!.isNotEmpty) {
          canvas.drawRect(rect, Paint()..color = _colorFromHex(box.fillColor!));
        }
        if (box.strokeColor.isNotEmpty && box.strokeColor != '00000000') {
          canvas.drawRect(
            rect,
            Paint()
              ..color = _colorFromHex(box.strokeColor)
              ..style = PaintingStyle.stroke
              ..strokeWidth = box.kind == LaidOutBoxKind.columnSep ? 0.7 : 0.8,
          );
        }
        continue;
      }
      if (box.kind == LaidOutBoxKind.equation && box.omml != null) {
        final bool selected =
            selectedEquation != null &&
            identical(box.equation, selectedEquation);
        PaintEquation.paint(
          canvas,
          rect,
          box.omml!,
          focusedSlot: selected ? equationSlot : null,
          selected: selected,
          caretVisible: selected && hasFocus && caret.visible,
          caretIndex: equationCaret,
          root: box.equation?.math.root,
        );
        continue;
      }
      final OfficeVisual? visual = box.visual;
      if (visual != null && box.kind != LaidOutBoxKind.tableCell) {
        PaintOfficeVisual.paint(
          canvas,
          rect,
          visual,
          fontFamily: _theme.fontFamily ?? PaintRunText.fontFallbacks.first,
          images: _images,
          onImageReady: markNeedsPaint,
        );
        if (paintHandles) {
          final bool selected =
              selectedVisual != null &&
              identical(visual, selectedVisual!.visual);
          final bool inRange =
              selected || (isVisualInSelection?.call(visual) ?? false);
          if (inRange) {
            TransformHandles(rect).paint(
              canvas,
              strokeColor: pictureCropMode
                  ? const Color(0xFFC45911)
                  : _theme.focusRing,
              fillColor: _theme.pageBackground,
              showKnobs: true,
              showRotate: !pictureCropMode,
              knobSize: 9,
            );
          }
        }
        continue;
      }
      if (box.height <= 0.5) {
        continue;
      }
      if (box.fillColor != null) {
        canvas.drawRect(rect, Paint()..color = _colorFromHex(box.fillColor!));
      }
      if (config.allowsSelection && _cellSelected(box)) {
        canvas.drawRect(rect, Paint()..color = _theme.selectionFill);
      }
      canvas.drawRect(
        rect,
        Paint()
          ..color = _colorFromHex(box.strokeColor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
  }

  void _paintHeaderFooterChrome(Canvas canvas, LaidOutPage page) {
    final LaidOutBand band = editingFooter ? page.footerBand : page.headerBand;
    final Rect rect = Rect.fromLTWH(
      band.left,
      band.top,
      band.width,
      band.height,
    );
    canvas.drawRect(rect, Paint()..color = const Color(0x142E75B6));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF2E75B6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final Path dash = Path();
    const double step = 5;
    for (double x = rect.left; x < rect.right; x += step * 2) {
      dash
        ..moveTo(x, rect.top)
        ..lineTo(math.min(x + step, rect.right), rect.top)
        ..moveTo(x, rect.bottom)
        ..lineTo(math.min(x + step, rect.right), rect.bottom);
    }
    canvas.drawPath(
      dash,
      Paint()
        ..color = const Color(0xFF2E75B6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final List<LaidOutLine> story = editingFooter ? page.footer : page.header;
    for (final LaidOutLine line in story) {
      if (config.showsCaret &&
          hasFocus &&
          caret.visible &&
          caret.isOnLine(line, lastOfParagraph: identical(line, story.last))) {
        canvas.drawRect(_caretPaintRect(line), Paint()..color = _theme.caret);
      }
    }
    final TextPainter label = TextPainter(
      text: TextSpan(
        text: editingFooter ? 'Footer' : 'Header',
        style: const TextStyle(
          fontSize: 9,
          color: Color(0xFF2E75B6),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(band.left + 8, band.top + 4));
  }

  void _drawOverlay(Canvas canvas, LaidOutLine line, {double? pageWidth}) {
    final String? text = line.overlayText;
    if (text == null || text.isEmpty) {
      return;
    }
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: line.overlaySize,
          fontWeight: line.overlayBold ? FontWeight.w700 : FontWeight.w400,
          fontFamily: PaintRunText.familyFor(
            text: text,
            themeFamily: _theme.fontFamily,
          ),
          fontFamilyFallback: PaintRunText.fallbacksFor(text),
          color: line.hyperlink != null
              ? const Color(0xFF0563C1)
              : _colorFromHex(
                  line.overlayColor == null || line.overlayColor!.isEmpty
                      ? '444444'
                      : line.overlayColor!,
                ),
          decoration: line.hyperlink != null
              ? TextDecoration.underline
              : TextDecoration.none,
          height: 1.0,
        ),
      ),
      textDirection: PaintRunText.directionFor(bidiLevel: 0, text: text),
      maxLines: 1,
    )..layout();
    var x = line.x;
    final double width = pageWidth ?? laidOut.pageSize.width;
    if (line.tocLeader || line.justification == WmlJustification.right) {
      x = width - 72 - painter.width;
    } else if (line.justification == WmlJustification.center) {
      x = (width - painter.width) / 2;
    }
    painter.paint(canvas, Offset(x, line.y));
  }

  void _drawLine(Canvas canvas, LaidOutLine line) {
    if (line.isParagraphStart &&
        line.listLabel != null &&
        line.listLabel!.isNotEmpty) {
      final TextPainter marker = TextPainter(
        text: TextSpan(
          text: line.listLabel,
          style: TextStyle(
            fontSize: line.glyphs.isEmpty ? 11 : line.glyphs.first.fontSize,
            fontFamily: PaintRunText.latinFallbacks.first,
            fontFamilyFallback: PaintRunText.latinFallbacks,
            color: const Color(0xFF222222),
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      marker.paint(canvas, Offset(line.x - marker.width - 4, line.y));
    }
    if (line.glyphs.isEmpty) {
      _drawOverlay(canvas, line);
      return;
    }
    final String paragraph =
        line.sourceText ?? _paragraphTextAt(line.paragraphIndex);
    var start = 0;
    while (start < line.glyphs.length) {
      final LaidOutGlyph first = line.glyphs[start];
      var end = start + 1;
      while (end < line.glyphs.length &&
          PaintRunText.samePaintRun(first, line.glyphs[end])) {
        end++;
      }
      final List<LaidOutGlyph> run = line.glyphs.sublist(start, end);
      if (first.commentIds.isNotEmpty) {
        final double x0 = first.x;
        final double x1 = run.last.x + run.last.advance;
        final bool active =
            selectedCommentId != null &&
            first.commentIds.contains(selectedCommentId);
        canvas.drawRect(
          Rect.fromLTWH(x0, line.y, x1 - x0, line.height),
          Paint()
            ..color = Color(
              active ? 0xFFF4B183 : 0xFFFFF2CC,
            ).withValues(alpha: 0.88),
        );
      }
      if (first.highlight != null) {
        final double x0 = first.x;
        final double x1 = run.last.x + run.last.advance;
        canvas.drawRect(
          Rect.fromLTWH(x0, line.y, x1 - x0, line.height),
          Paint()
            ..color = _colorFromHex(first.highlight!).withValues(alpha: 0.45),
        );
      }
      final String text = PaintRunText.runText(paragraph, run);
      if (text.isEmpty) {
        start = end;
        continue;
      }
      final TextPainter painter = PaintRunText.painterFor(
        text: text,
        first: first,
        themeFamily: _theme.fontFamily,
        color: _colorFromHex(first.color),
        decoration: first.underline == WmlUnderline.none
            ? TextDecoration.none
            : TextDecoration.underline,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          first.x,
          first.vertAlign.paintTop(
            lineY: line.y,
            lineHeight: line.height,
            fontSize: first.fontSize,
          ),
        ),
      );
      start = end;
    }
    if (line.overlayText != null && line.overlayText!.isNotEmpty) {
      _drawTocLeader(canvas, line);
      _drawOverlay(canvas, line);
    }
  }

  void _drawTocLeader(Canvas canvas, LaidOutLine line) {
    if (!line.tocLeader || line.glyphs.isEmpty) {
      return;
    }
    final LaidOutGlyph last = line.glyphs.last;
    final double from = last.x + last.advance + 6;
    final double to = laidOut.pageSize.width - 72 - 18;
    if (to <= from + 8) {
      return;
    }
    final Paint dots = Paint()
      ..color = const Color(0xFF8A8A8A)
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;
    final double y = line.y + line.height * 0.72;
    for (double x = from; x < to; x += 4) {
      canvas.drawCircle(Offset(x, y), 0.55, dots);
    }
  }

  String _paragraphTextAt(int index) {
    final List<WmlParagraph> paras = document.paragraphs.toList();
    if (paras.isEmpty) {
      return '';
    }
    return paras[index.clamp(0, paras.length - 1)].text;
  }

  Color _colorFromHex(String hex) {
    final String resolved =
        WmlHighlight.toRgb(hex) ?? hex.replaceFirst('#', '');
    final String clean = resolved.replaceFirst('#', '');
    if (clean.length != 6) {
      return const Color(0xFF000000);
    }
    final int rgb = int.tryParse(clean, radix: 16) ?? 0;
    return Color(0xFF000000 | rgb);
  }

  bool _isLastParagraphLine(LaidOutPage page, LaidOutLine line) {
    for (final LaidOutLine other in page.lines) {
      if (other.paragraphIndex == line.paragraphIndex &&
          other.y > line.y + 0.01) {
        return false;
      }
    }
    for (final LaidOutPage later in laidOut.pages) {
      if (later.index <= page.index) {
        continue;
      }
      for (final LaidOutLine other in later.lines) {
        if (other.paragraphIndex == line.paragraphIndex) {
          return false;
        }
      }
    }
    return true;
  }

  Rect _caretPaintRect(LaidOutLine line) {
    if (line.glyphs.isEmpty) {
      final String text = line.overlayText ?? '';
      final double t = text.isEmpty
          ? 0
          : (caret.logicalIndex / text.length).clamp(0.0, 1.0);
      return Rect.fromLTWH(line.x + line.width * t, line.y, 1.5, line.height);
    }
    for (final LaidOutGlyph glyph in line.glyphs) {
      if (glyph.glyph.logicalIndex != caret.logicalIndex) {
        continue;
      }
      final double x = glyph.glyph.level.isOdd
          ? glyph.x + glyph.advance
          : glyph.x;
      return Rect.fromLTWH(x, line.y, 1.5, line.height);
    }
    final LaidOutGlyph last = line.glyphs.last;
    final double x = last.glyph.level.isOdd ? last.x : last.x + last.advance;
    return Rect.fromLTWH(x, line.y, 1.5, line.height);
  }

  BrokenLine _broken(LaidOutLine line) {
    return BrokenLine(
      glyphs: <ShapedGlyph>[
        for (final LaidOutGlyph g in line.glyphs)
          ShapedGlyph(
            codePoint: g.glyph.codePoint,
            glyphId: g.glyph.glyphId,
            advance: g.advance,
            logicalIndex: g.glyph.logicalIndex,
            level: g.glyph.level,
            isSpace: g.glyph.isSpace,
          ),
      ],
      width: line.width,
      logicalStart: line.glyphs.isEmpty
          ? 0
          : line.glyphs.first.glyph.logicalIndex,
      logicalEnd: line.glyphs.isEmpty
          ? 0
          : line.glyphs.last.glyph.logicalIndex + 1,
      justificationRatio: 0,
    );
  }
}

class _TableInsertHit {
  const _TableInsertHit({
    required this.table,
    required this.column,
    required this.index,
    required this.button,
    required this.lineStart,
    required this.lineEnd,
  });

  /// table API.
  final WmlTable table;

  /// column API.
  final bool column;

  /// index API.
  final int index;

  /// button API.
  final Rect button;

  /// lineStart API.
  final Offset lineStart;

  /// lineEnd API.
  final Offset lineEnd;

  /// axis API.
  double get axis => column ? lineStart.dx : lineStart.dy;
}

class _TableBandHit {
  const _TableBandHit({
    required this.table,
    required this.column,
    required this.index,
    required this.highlight,
  });

  /// table API.
  final WmlTable table;

  /// column API.
  final bool column;

  /// index API.
  final int index;

  /// highlight API.
  final Rect highlight;
}

class _TableGeom {
  _TableGeom(this.table);

  /// table API.
  final WmlTable table;

  /// bounds API.
  Rect bounds = Rect.zero;
  final Map<int, double> _rowTop = <int, double>{};
  final Map<int, double> _rowBottom = <int, double>{};
  final Map<int, double> _colLeft = <int, double>{};
  final Map<int, double> _colRight = <int, double>{};

  /// handleRect API.
  Rect get handleRect =>
      Rect.fromLTWH(bounds.left - 15, bounds.top - 15, 12, 12);

  /// add API.
  void add(LaidOutBox box) {
    final Rect rect = Rect.fromLTWH(box.x, box.y, box.width, box.height);
    bounds = bounds == Rect.zero ? rect : bounds.expandToInclude(rect);
    final int row = box.tableRow ?? 0;
    final int col = box.tableGridCol ?? box.tableCol ?? 0;
    _rowTop[row] = _minOr(_rowTop[row], rect.top);
    _rowBottom[row] = _maxOr(_rowBottom[row], rect.bottom);
    _colLeft[col] = _minOr(_colLeft[col], rect.left);
    _colRight[col] = _maxOr(_colRight[col], rect.right);
  }

  /// rowCount API.
  int get rowCount {
    var max = table.rows.length;
    for (final int key in _rowTop.keys) {
      if (key + 1 > max) {
        max = key + 1;
      }
    }
    return max;
  }

  /// colCount API.
  int get colCount {
    var max = WordTable.columnCount(table);
    for (final int key in _colLeft.keys) {
      if (key + 1 > max) {
        max = key + 1;
      }
    }
    return max;
  }

  /// rowBoundary API.
  double rowBoundary(int index) {
    if (index <= 0) {
      return bounds.top;
    }
    if (index >= rowCount) {
      return bounds.bottom;
    }
    return _rowTop[index] ?? _rowBottom[index - 1] ?? bounds.top;
  }

  /// colBoundary API.
  double colBoundary(int index) {
    if (index <= 0) {
      return bounds.left;
    }
    if (index >= colCount) {
      return bounds.right;
    }
    return _colLeft[index] ?? _colRight[index - 1] ?? bounds.left;
  }

  /// rowIndexAt API.
  int rowIndexAt(double y, {bool clamp = false}) {
    if (rowCount <= 0) {
      return -1;
    }
    if (y < rowBoundary(0)) {
      return clamp ? 0 : -1;
    }
    for (int i = 0; i < rowCount; i++) {
      if (y < rowBoundary(i + 1)) {
        return i;
      }
    }
    return clamp
        ? rowCount - 1
        : (y <= rowBoundary(rowCount) ? rowCount - 1 : -1);
  }

  /// colIndexAt API.
  int colIndexAt(double x, {bool clamp = false}) {
    if (colCount <= 0) {
      return -1;
    }
    if (x < colBoundary(0)) {
      return clamp ? 0 : -1;
    }
    for (int i = 0; i < colCount; i++) {
      if (x < colBoundary(i + 1)) {
        return i;
      }
    }
    return clamp
        ? colCount - 1
        : (x <= colBoundary(colCount) ? colCount - 1 : -1);
  }

  /// rowBand API.
  Rect rowBand(int from, int to) {
    final int a = from < to ? from : to;
    final int b = from > to ? from : to;
    return Rect.fromLTRB(
      bounds.left,
      rowBoundary(a),
      bounds.right,
      rowBoundary(b + 1),
    );
  }

  /// colBand API.
  Rect colBand(int from, int to) {
    final int a = from < to ? from : to;
    final int b = from > to ? from : to;
    return Rect.fromLTRB(
      colBoundary(a),
      bounds.top,
      colBoundary(b + 1),
      bounds.bottom,
    );
  }

  static double _minOr(double? current, double next) {
    return current == null || next < current ? next : current;
  }

  static double _maxOr(double? current, double next) {
    return current == null || next > current ? next : current;
  }
}
