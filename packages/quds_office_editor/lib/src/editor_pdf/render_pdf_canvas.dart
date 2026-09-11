import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:quds_office_engine/pdf_file.dart';

import '../core/virtual_viewport.dart';
import '../embed/office_theme.dart';
import 'paint_pdf_display_list.dart';
import 'pdf_font_faces.dart';
import 'pdf_page_layout.dart';
import 'pdf_raster.dart';
import 'pdf_text_selection.dart';

/// Leaf canvas for PDF pages.
class PdfCanvasView extends LeafRenderObjectWidget {
  /// PdfCanvasView API.
  const PdfCanvasView({
    super.key,
    required this.lists,
    required this.viewport,
    required this.scale,
    required this.config,
    this.selection,
    this.findHits = const <PdfTextRun>[],
    this.annots = const <List<PdfAnnot>>[],
    this.editing = false,
    this.onChanged,
    this.onZoomBy,
    this.onFollowLink,
    this.onSelectText,
    this.onAnnotTap,
  });

  /// lists API.
  final List<PdfDisplayList> lists;

  /// viewport API.
  final VirtualViewport viewport;

  /// Logical zoom (1 = 100%). Passed explicitly so the RenderBox dirties.
  final double scale;

  /// config API.
  final OfficeSurfaceConfig config;

  /// selection API.
  final PdfTextSelection? selection;

  /// findHits API.
  final List<PdfTextRun> findHits;

  /// annots API.
  final List<List<PdfAnnot>> annots;

  /// editing API.
  final bool editing;

  /// onChanged API.
  final VoidCallback? onChanged;

  /// Ctrl/meta+wheel zoom — [factor] and content-space [focal].
  /// Pass [animate]: false for continuous pinch updates.
  final void Function(double factor, Offset focal, {bool animate})? onZoomBy;

  /// onFollowLink API.
  final void Function(PdfLinkAction action)? onFollowLink;

  /// onSelectText API.
  final void Function(PdfTextSelection? range)? onSelectText;

  /// onAnnotTap API.
  final void Function(int page, PdfAnnot annot)? onAnnotTap;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderPdfCanvas(
      lists: lists,
      viewport: viewport,
      scale: scale,
      config: config,
      selection: selection,
      findHits: findHits,
      annots: annots,
      editing: editing,
      onChanged: onChanged,
      onZoomBy: onZoomBy,
      onFollowLink: onFollowLink,
      onSelectText: onSelectText,
      onAnnotTap: onAnnotTap,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderPdfCanvas renderObject) {
    renderObject
      ..lists = lists
      ..viewport = viewport
      ..scale = scale
      ..config = config
      ..selection = selection
      ..findHits = findHits
      ..annots = annots
      ..editing = editing
      ..onChanged = onChanged
      ..onZoomBy = onZoomBy
      ..onFollowLink = onFollowLink
      ..onSelectText = onSelectText
      ..onAnnotTap = onAnnotTap;
    renderObject.markNeedsPaint();
  }
}

/// Class RenderPdfCanvas.
class RenderPdfCanvas extends RenderBox implements MouseTrackerAnnotation {
  /// RenderPdfCanvas API.
  RenderPdfCanvas({
    required List<PdfDisplayList> lists,
    required VirtualViewport viewport,
    required double scale,
    required OfficeSurfaceConfig config,
    this.selection,
    this.findHits = const <PdfTextRun>[],
    this.annots = const <List<PdfAnnot>>[],
    this.editing = false,
    this.onChanged,
    this.onZoomBy,
    this.onFollowLink,
    this.onSelectText,
    this.onAnnotTap,
  }) : _lists = lists,
       _viewport = viewport,
       _scale = scale,
       _config = config;

  List<PdfDisplayList> _lists;
  VirtualViewport _viewport;
  double _scale;
  OfficeSurfaceConfig _config;

  /// selection API.
  PdfTextSelection? selection;

  /// findHits API.
  List<PdfTextRun> findHits;

  /// annots API.
  List<List<PdfAnnot>> annots;

  /// editing API.
  bool editing;

  /// onChanged API.
  VoidCallback? onChanged;

  /// Ctrl/meta+wheel zoom — [factor] and content-space [focal].
  /// Pass [animate]: false for continuous pinch updates.
  void Function(double factor, Offset focal, {bool animate})? onZoomBy;

  /// onFollowLink API.
  void Function(PdfLinkAction action)? onFollowLink;

  /// onSelectText API.
  void Function(PdfTextSelection? range)? onSelectText;

  /// onAnnotTap API.
  void Function(int page, PdfAnnot annot)? onAnnotTap;

  final Map<int, ui.Image> _images = <int, ui.Image>{};
  final Set<int> _decoding = <int>{};
  final Map<int, _PageTile> _tiles = <int, _PageTile>{};
  final Set<int> _rasterizing = <int>{};
  Timer? _zoomSettle;
  var _previewZoom = false;
  var _tileEpoch = 0;
  PanGestureRecognizer? _pan;
  var _scrollDrag = false;
  int? _scrollPageTip;
  Offset? _hoverLocal;
  var _selecting = false;
  PdfTextSelection? _live;
  PdfTextHit? _anchor;
  Offset? _downLocal;
  DateTime? _downAt;
  var _clickCount = 0;
  PdfLinkAction? _pendingLink;
  var _panZoomScale = 1.0;

  double get _viewScale => PdfPageLayout.viewScale(_viewport.scale);

  Size get _contentSize =>
      PdfPageLayout.contentSize(_lists, _viewport.scale);

  double get _maxScrollY =>
      math.max(0, _contentSize.height - size.height);

  Rect get _vTrack => Rect.fromLTWH(
    size.width - PdfPageLayout.scrollBar,
    0,
    PdfPageLayout.scrollBar,
    size.height,
  );

  /// lists API.
  set lists(List<PdfDisplayList> value) {
    if (identical(_lists, value)) {
      return;
    }
    _lists = value;
    _images.clear();
    _decoding.clear();
    _clearTiles();
    markNeedsLayout();
    markNeedsPaint();
  }

  /// viewport API.
  set viewport(VirtualViewport value) {
    final bool scaleChanged = !identical(_viewport, value) ||
        _scale != value.scale ||
        _viewport.scale != value.scale;
    _viewport = value;
    _scale = value.scale;
    if (scaleChanged) {
      _noteZoomInteraction();
      markNeedsLayout();
    }
    markNeedsPaint();
  }

  /// scale API.
  set scale(double value) {
    if (_scale == value && _viewport.scale == value) {
      return;
    }
    final bool zoomed = (_scale - value).abs() > 1e-9;
    _scale = value;
    if (_viewport.scale != value) {
      _viewport.setScale(value);
    }
    if (zoomed) {
      _noteZoomInteraction();
    }
    markNeedsLayout();
    markNeedsPaint();
  }

  /// config API.
  set config(OfficeSurfaceConfig value) {
    _config = value;
    markNeedsPaint();
  }

  @override
  bool hitTestSelf(Offset position) {
    _hoverLocal = position;
    return true;
  }

  @override
  MouseCursor get cursor => _cursorFor(_hoverLocal);

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => (_) {
    _hoverLocal = null;
  };

  @override
  bool get validForMouseTracker => attached;

  bool get _canSelect =>
      _config.allowsSelection ||
      _config.mode == OfficeInteractionMode.viewing;

  MouseCursor _cursorFor(Offset? local) {
    if (local == null) {
      return SystemMouseCursors.basic;
    }
    if (_vTrack.contains(local) && _maxScrollY > 0) {
      return SystemMouseCursors.grab;
    }
    if (_selecting) {
      return SystemMouseCursors.text;
    }
    final _PageHit? page = _pageHit(local);
    if (page == null) {
      return SystemMouseCursors.basic;
    }
    if (_hotspotAt(page) != null) {
      return SystemMouseCursors.click;
    }
    if (_canSelect && _textHit(page) != null) {
      return SystemMouseCursors.text;
    }
    return SystemMouseCursors.basic;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _ensureRecognizers();
  }

  @override
  void detach() {
    _zoomSettle?.cancel();
    _zoomSettle = null;
    _pan?.dispose();
    _pan = null;
    super.detach();
  }

  @override
  void performLayout() {
    size = constraints.hasBoundedWidth && constraints.hasBoundedHeight
        ? constraints.biggest
        : constraints.constrain(_contentSize);
    if (!size.width.isFinite || !size.height.isFinite) {
      size = constraints.constrain(const Size(800, 600));
    }
    _viewport.extent = size;
    _viewport.clampTo(content: _contentSize, view: size);
  }

  double _pageLeft(PdfDisplayList list) {
    final double pageW = list.page.width * _viewScale;
    final double viewW = math.max(0, size.width - PdfPageLayout.scrollBar);
    if (viewW > pageW + PdfPageLayout.gutter * 2) {
      return (viewW - pageW) / 2;
    }
    return PdfPageLayout.gutter;
  }

  Rect get _vThumb {
    final double maxY = _maxScrollY;
    final double trackH = _vTrack.height;
    final double thumbH =
        (_contentSize.height <= 0
                ? 22.0
                : trackH * (size.height / math.max(size.height, _contentSize.height)))
            .clamp(22.0, trackH);
    final double y = maxY <= 0
        ? 0
        : (trackH - thumbH) * (_viewport.origin.dy / maxY);
    return Rect.fromLTWH(_vTrack.left + 2, y, _vTrack.width - 4, thumbH);
  }

  void _ensureRecognizers() {
    _pan ??= PanGestureRecognizer(debugOwner: this)
      ..onUpdate = (DragUpdateDetails details) {
        if (_scrollDrag) {
          _dragScroll(details.delta);
          return;
        }
        if (_selecting) {
          _extendSelection(details.localPosition);
          return;
        }
        _viewport.pan(-details.delta);
        _finishScroll();
      }
      ..onEnd = (DragEndDetails details) {
        if (_selecting) {
          _finishSelect();
        }
        _scrollDrag = false;
        _scrollPageTip = null;
        markNeedsPaint();
        onChanged?.call();
      };
  }

  void _zoomBy(double factor, Offset local) {
    final double old = _viewport.scale;
    if (old <= 0 || factor <= 0) {
      return;
    }
    _viewport.setScale(old * factor);
    final double next = _viewport.scale;
    if ((next - old).abs() < 1e-9) {
      return;
    }
    _scale = next;
    _viewport.origin = PdfPageLayout.originAfterScale(
      lists: _lists,
      origin: _viewport.origin,
      focal: _viewport.origin + local,
      oldScale: old,
      nextScale: next,
    );
    _noteZoomInteraction();
  }

  /// Stretch the last page rasters while zooming; rebuild after the gesture settles.
  void _noteZoomInteraction() {
    _previewZoom = true;
    _zoomSettle?.cancel();
    _zoomSettle = Timer(const Duration(milliseconds: 220), () {
      if (!attached) {
        return;
      }
      _previewZoom = false;
      _tileEpoch++;
      markNeedsPaint();
    });
  }

  void _clearTiles() {
    _zoomSettle?.cancel();
    _zoomSettle = null;
    _previewZoom = false;
    _tileEpoch++;
    for (final _PageTile tile in _tiles.values) {
      tile.image?.dispose();
    }
    _tiles.clear();
    _rasterizing.clear();
  }

  bool _tileMatchesScale(_PageTile tile, double scale) {
    if (tile.image == null || tile.scale <= 0 || scale <= 0) {
      return false;
    }
    return (tile.scale - scale).abs() / scale < 0.03;
  }

  void _scheduleRaster(int pageIndex, double targetScale) {
    if (_previewZoom || pageIndex < 0 || pageIndex >= _lists.length) {
      return;
    }
    final _PageTile tile = _tiles.putIfAbsent(pageIndex, _PageTile.new);
    if (_tileMatchesScale(tile, targetScale) || _rasterizing.contains(pageIndex)) {
      return;
    }
    _rasterizing.add(pageIndex);
    final int epoch = _tileEpoch;
    final PdfDisplayList list = _lists[pageIndex];
    _warmImages(list);
    _warmFonts(list);
    final double dpr = _devicePixelRatio;
    () async {
      final ui.Image? image = await _rasterPage(list, targetScale, dpr);
      if (!attached || epoch != _tileEpoch || _previewZoom) {
        image?.dispose();
        _rasterizing.remove(pageIndex);
        return;
      }
      if ((_viewScale - targetScale).abs() / math.max(targetScale, 1e-6) > 0.05) {
        image?.dispose();
        _rasterizing.remove(pageIndex);
        return;
      }
      final _PageTile next = _tiles.putIfAbsent(pageIndex, _PageTile.new);
      next.image?.dispose();
      next.image = image;
      next.scale = targetScale;
      _rasterizing.remove(pageIndex);
      markNeedsPaint();
    }();
  }

  double get _devicePixelRatio {
    final ui.FlutterView? view = ui.PlatformDispatcher.instance.implicitView;
    if (view != null && view.devicePixelRatio > 0) {
      return view.devicePixelRatio.clamp(1.0, 3.0);
    }
    return 1.0;
  }

  Future<ui.Image?> _rasterPage(
    PdfDisplayList list,
    double viewScale,
    double dpr,
  ) async {
    if (viewScale <= 0 || list.page.width <= 0 || list.page.height <= 0) {
      return null;
    }
    var pixelScale = viewScale * dpr;
    var w = (list.page.width * pixelScale).ceil();
    var h = (list.page.height * pixelScale).ceil();
    const int maxEdge = 4096;
    if (w > maxEdge || h > maxEdge) {
      final double fit = maxEdge / math.max(w, h);
      pixelScale *= fit;
      w = (list.page.width * pixelScale).ceil();
      h = (list.page.height * pixelScale).ceil();
    }
    w = w.clamp(1, maxEdge);
    h = h.clamp(1, maxEdge);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.scale(pixelScale);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, list.page.width, list.page.height),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.clipRect(Rect.fromLTWH(0, 0, list.page.width, list.page.height));
    PaintPdfDisplayList.paint(
      canvas,
      list,
      decodeImage: (Uint8List bytes, bool _) =>
          _images[identityHashCode(bytes)],
    );
    final ui.Picture picture = recorder.endRecording();
    try {
      return await picture.toImage(w, h);
    } finally {
      picture.dispose();
    }
  }

  void _finishScroll() {
    _viewport.clampTo(content: _contentSize, view: size);
    _scrollPageTip = PdfPageLayout.pageAtY(
      _lists,
      _viewport.origin.dy + size.height * 0.35,
      _viewport.scale,
    );
    markNeedsPaint();
    onChanged?.call();
  }

  void _dragScroll(Offset delta) {
    final double maxY = _maxScrollY;
    if (maxY <= 0 || _vTrack.height <= 0) {
      return;
    }
    _viewport.origin = Offset(
      _viewport.origin.dx,
      _viewport.origin.dy + delta.dy * (maxY / _vTrack.height),
    );
    _finishScroll();
  }

  void _jumpScroll(Offset local) {
    final double maxY = _maxScrollY;
    if (maxY <= 0 || _vTrack.height <= 0) {
      return;
    }
    final double t = (local.dy / _vTrack.height).clamp(0, 1);
    _viewport.origin = Offset(_viewport.origin.dx, maxY * t);
    _finishScroll();
  }

  void _paintScrollBar(Canvas canvas, Offset offset) {
    if (_maxScrollY <= 0) {
      return;
    }
    final Rect track = _vTrack.shift(offset);
    canvas.drawRect(track, Paint()..color = _config.theme.headerFill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        _vThumb.shift(offset),
        const Radius.circular(4),
      ),
      Paint()..color = _config.theme.headerText.withValues(alpha: 0.45),
    );
    final int? tip = _scrollPageTip;
    if (tip == null || _lists.isEmpty) {
      return;
    }
    final String label = '${tip + 1} / ${_lists.length}';
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
    final double tipX = (track.left - tipW - 8).clamp(8, size.width - tipW - 8);
    final double tipY = (_vThumb.shift(offset).center.dy - tipH / 2).clamp(
      8,
      size.height - tipH - 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(offset.dx + tipX, offset.dy + tipY, tipW, tipH),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xE62B2B2B),
    );
    painter.paint(canvas, Offset(offset.dx + tipX + 8, offset.dy + tipY + 5));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    canvas.drawRect(offset & size, Paint()..color = _config.theme.canvasBackground);
    canvas.save();
    canvas.clipRect(offset & size);
    canvas.translate(offset.dx - _viewport.origin.dx, offset.dy - _viewport.origin.dy);
    final Rect view = Rect.fromLTWH(
      _viewport.origin.dx,
      _viewport.origin.dy,
      size.width,
      size.height,
    ).inflate(96);
    var top = PdfPageLayout.gap;
    final double scale = _viewScale;
    for (int i = 0; i < _lists.length; i++) {
      final PdfDisplayList list = _lists[i];
      final double left = _pageLeft(list);
      final double w = list.page.width * scale;
      final double h = list.page.height * scale;
      final Rect paper = Rect.fromLTWH(left, top, w, h);
      if (!view.overlaps(paper)) {
        top += h + PdfPageLayout.gap;
        continue;
      }
      _warmImages(list);
      _warmFonts(list);
      canvas.drawShadow(Path()..addRect(paper.inflate(1)), const Color(0x44000000), 8, false);
      canvas.drawRect(paper, Paint()..color = _config.theme.pageBackground);
      canvas.drawRect(
        paper,
        Paint()
          ..color = _config.theme.pageBorder
          ..style = PaintingStyle.stroke,
      );
      canvas.save();
      canvas.translate(left, top);
      canvas.scale(scale);
      canvas.clipRect(Rect.fromLTWH(0, 0, list.page.width, list.page.height));
      final _PageTile? tile = _tiles[i];
      final ui.Image? cached = tile?.image;
      final bool scaleMatch =
          tile != null && _tileMatchesScale(tile, scale);
      if (cached != null) {
        // Blit last raster (stretch while zooming); rebuild after settle.
        paintImage(
          canvas: canvas,
          rect: Rect.fromLTWH(0, 0, list.page.width, list.page.height),
          image: cached,
          // Default BoxFit.scaleDown refuses to upscale small zoom-out
          // tiles, so content shrinks twice inside the paper frame.
          fit: BoxFit.fill,
          filterQuality:
              _previewZoom ? FilterQuality.medium : FilterQuality.high,
        );
      } else {
        PaintPdfDisplayList.paint(
          canvas,
          list,
          decodeImage: (Uint8List bytes, bool _) =>
              _images[identityHashCode(bytes)],
        );
      }
      if (!_previewZoom && !scaleMatch) {
        _scheduleRaster(i, scale);
      }
      final PdfTextSelection? sel = _live ?? selection;
      if (sel != null && !sel.isCollapsed) {
        final Paint fill = Paint()..color = _config.theme.selectionFill;
        for (final ({int page, Rect rect}) box in sel.boxes(_lists)) {
          if (box.page == i) {
            canvas.drawRect(box.rect, fill);
          }
        }
      }
      for (final PdfTextRun hit in findHits) {
        canvas.drawRect(
          Rect.fromLTWH(hit.x, hit.y, hit.width, hit.height),
          Paint()..color = const Color(0x66C9A227),
        );
      }
      if (i < annots.length) {
        for (final PdfAnnot annot in annots[i]) {
          // Link annots carry a default yellow `/C` in many PDFs; Evince and
          // Acrobat do not fill them permanently — only markup types do.
          if (!_paintAnnotFill(annot.subtype)) {
            continue;
          }
          final double h = annot.rect.height;
          final double top = h < 0 ? annot.rect.y + h : annot.rect.y;
          canvas.drawRect(
            Rect.fromLTWH(
              annot.rect.x,
              top,
              annot.rect.width.abs(),
              h.abs(),
            ),
            Paint()..color = Color(annot.color).withValues(alpha: 0.28),
          );
        }
      }
      canvas.restore();
      top += h + PdfPageLayout.gap;
    }
    canvas.restore();
    _paintScrollBar(canvas, offset);
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, (
        PointerSignalEvent signal,
      ) {
        if (signal is PointerScrollEvent) {
          if (HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed) {
            final double factor =
                signal.scrollDelta.dy > 0 ? 0.9 : 1.1;
            final Offset focal =
                _viewport.origin + signal.localPosition;
            if (onZoomBy != null) {
              onZoomBy!(factor, focal);
            } else {
              _zoomBy(factor, signal.localPosition);
            }
          } else {
            Offset delta = signal.scrollDelta;
            if (HardwareKeyboard.instance.isShiftPressed &&
                delta.dx.abs() < delta.dy.abs()) {
              delta = Offset(delta.dy, 0);
            }
            _viewport.pan(delta);
          }
          _finishScroll();
        }
      });
      return;
    }
    if (event is PointerPanZoomStartEvent) {
      _panZoomScale = 1;
      return;
    }
    if (event is PointerPanZoomUpdateEvent) {
      final bool zooming = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed ||
          (event.scale - _panZoomScale).abs() > 0.02;
      if (zooming && _panZoomScale != 0) {
        final double factor = event.scale / _panZoomScale;
        final Offset focal = _viewport.origin + event.localPosition;
        if (onZoomBy != null) {
          onZoomBy!(factor, focal, animate: false);
        } else {
          _zoomBy(factor, event.localPosition);
        }
        _panZoomScale = event.scale == 0 ? _panZoomScale : event.scale;
      } else {
        _viewport.pan(-event.localPanDelta);
      }
      _finishScroll();
      return;
    }
    if (event is PointerHoverEvent || event is PointerMoveEvent) {
      _hoverLocal = event.localPosition;
    }
    if (event is PointerDownEvent) {
      _ensureRecognizers();
      if (_vTrack.contains(event.localPosition) && _maxScrollY > 0) {
        _scrollDrag = true;
        if (!_vThumb.contains(event.localPosition)) {
          _jumpScroll(event.localPosition);
        }
        _pan?.addPointer(event);
        return;
      }
      if (event.buttons == kSecondaryMouseButton) {
        return;
      }
      final _PageHit? page = _pageHit(event.localPosition);
      if (page != null) {
        for (final PdfAnnot annot in page.index < annots.length
            ? annots[page.index]
            : const <PdfAnnot>[]) {
          if (annot.rect.contains(page.x, page.y)) {
            onAnnotTap?.call(page.index, annot);
            _pan?.addPointer(event);
            return;
          }
        }
        _pendingLink = _hotspotAt(page);
        if (_canSelect) {
          final PdfTextHit? text = _textHit(page);
          if (text != null) {
            _beginSelect(event, page, text);
            _pan?.addPointer(event);
            return;
          }
        }
        if (_pendingLink != null) {
          onFollowLink?.call(_pendingLink!);
          _pendingLink = null;
          return;
        }
      }
      _clearLive();
      _pan?.addPointer(event);
    }
  }

  void _beginSelect(PointerDownEvent event, _PageHit page, PdfTextHit text) {
    final DateTime now = DateTime.now();
    final bool again = _downAt != null &&
        _downLocal != null &&
        now.difference(_downAt!) < const Duration(milliseconds: 400) &&
        (event.localPosition - _downLocal!).distance < 6;
    _clickCount = again ? _clickCount + 1 : 1;
    _downAt = now;
    _downLocal = event.localPosition;
    _selecting = true;
    _anchor = text;
    final PdfTextRun run = _lists[page.index].runs[text.run];
    if (_clickCount >= 3) {
      _live = PdfTextSelection.run(page.index, text.run, run);
    } else if (_clickCount == 2) {
      _live = PdfTextSelection.word(text, run);
    } else {
      _live = PdfTextSelection.collapsed(text);
    }
    _anchor = _live!.anchor;
    markNeedsPaint();
    onSelectText?.call(_live);
  }

  void _extendSelection(Offset local) {
    final PdfTextHit? hit = _hitOrNearest(local);
    if (hit == null || _anchor == null) {
      return;
    }
    _live = PdfTextSelection(anchor: _anchor!, extent: hit);
    markNeedsPaint();
    onSelectText?.call(_live);
  }

  void _finishSelect() {
    _selecting = false;
    if (_live != null && _live!.isCollapsed && _pendingLink != null) {
      onFollowLink?.call(_pendingLink!);
    }
    _pendingLink = null;
    onSelectText?.call(_live);
  }

  void _clearLive() {
    _selecting = false;
    _live = null;
    _anchor = null;
    _pendingLink = null;
    onSelectText?.call(null);
    markNeedsPaint();
  }

  _PageHit? _pageHit(Offset window) {
    var top = PdfPageLayout.gap;
    final double scale = _viewScale;
    for (int i = 0; i < _lists.length; i++) {
      final PdfDisplayList list = _lists[i];
      final double left = _pageLeft(list);
      final double x = (window.dx + _viewport.origin.dx - left) / scale;
      final double y = (window.dy + _viewport.origin.dy - top) / scale;
      if (x >= -8 &&
          x <= list.page.width + 8 &&
          y >= 0 &&
          y <= list.page.height) {
        return _PageHit(i, x, y);
      }
      top += list.page.height * scale + PdfPageLayout.gap;
    }
    return null;
  }

  PdfTextHit? _textHit(_PageHit page) {
    final List<PdfTextRun> runs = _lists[page.index].runs;
    for (int r = runs.length - 1; r >= 0; r--) {
      if (PdfTextSelection.containsPadded(runs[r], page.x, page.y)) {
        return PdfTextHit(
          page: page.index,
          run: r,
          offset: PdfTextSelection.offsetAt(runs[r], page.x),
        );
      }
    }
    return null;
  }

  PdfTextHit? _hitOrNearest(Offset window) {
    final _PageHit? page = _pageHit(window) ?? _nearestPage(window);
    if (page == null) {
      return null;
    }
    final PdfTextHit? exact = _textHit(page);
    if (exact != null) {
      return exact;
    }
    final List<PdfTextRun> runs = _lists[page.index].runs;
    if (runs.isEmpty) {
      return PdfTextHit(page: page.index, run: 0, offset: 0);
    }
    var best = 0;
    var bestDist = double.infinity;
    for (int r = 0; r < runs.length; r++) {
      final PdfTextRun run = runs[r];
      final double cx = run.x + run.width / 2;
      final double cy = run.y + run.height / 2;
      final double d = (page.x - cx) * (page.x - cx) + (page.y - cy) * (page.y - cy);
      if (d < bestDist) {
        bestDist = d;
        best = r;
      }
    }
    return PdfTextHit(
      page: page.index,
      run: best,
      offset: PdfTextSelection.offsetAt(runs[best], page.x),
    );
  }

  _PageHit? _nearestPage(Offset window) {
    if (_lists.isEmpty) {
      return null;
    }
    var top = PdfPageLayout.gap;
    final double scale = _viewScale;
    final double contentY = window.dy + _viewport.origin.dy;
    if (contentY < top) {
      return _PageHit(0, 0, 0);
    }
    for (int i = 0; i < _lists.length; i++) {
      final PdfDisplayList list = _lists[i];
      final double left = _pageLeft(list);
      final double h = list.page.height * scale;
      if (contentY <= top + h || i == _lists.length - 1) {
        return _PageHit(
          i,
          (window.dx + _viewport.origin.dx - left) / scale,
          (contentY - top) / scale,
        );
      }
      top += h + PdfPageLayout.gap;
    }
    return _PageHit(_lists.length - 1, 0, _lists.last.page.height);
  }

  PdfLinkAction? _hotspotAt(_PageHit page) {
    for (final PdfHotspot spot in _lists[page.index].hotspots) {
      if (spot.rect.contains(page.x, page.y)) {
        return spot.action;
      }
    }
    return null;
  }

  void _warmFonts(PdfDisplayList list) {
    for (final PdfPaintOp op in list.ops) {
      if (op is PdfDrawText && op.fontBytes != null) {
        PdfFontFaces.ensure(op.fontBytes!, markNeedsPaint);
      }
    }
  }

  void _warmImages(PdfDisplayList list) {
    for (final PdfPaintOp op in list.ops) {
      if (op is! PdfDrawImage || op.placeholder || op.bytes.isEmpty) {
        continue;
      }
      final int key = identityHashCode(op.bytes);
      if (_images.containsKey(key) || !_decoding.add(key)) {
        continue;
      }
      PdfRaster.decode(op, (ui.Image image) {
        _images[key] = image;
        _decoding.remove(key);
        markNeedsPaint();
      });
    }
  }

  @override
  void dispose() {
    _zoomSettle?.cancel();
    _zoomSettle = null;
    for (final _PageTile tile in _tiles.values) {
      tile.image?.dispose();
    }
    _tiles.clear();
    _rasterizing.clear();
    for (final ui.Image image in _images.values) {
      image.dispose();
    }
    _images.clear();
    super.dispose();
  }
}

class _PageTile {
  ui.Image? image;
  double scale = 0;
}

/// Markup that Adobe/Evince paint as a tint; not navigation `/Link`.
bool _paintAnnotFill(String subtype) {
  switch (subtype) {
    case 'Highlight':
    case 'Underline':
    case 'Squiggly':
    case 'StrikeOut':
    case 'Caret':
    case 'Stamp':
    case 'Ink':
    case 'FreeText':
    case 'Text':
    case 'Square':
    case 'Circle':
    case 'Polygon':
    case 'PolyLine':
    case 'Redact':
      return true;
    default:
      return false;
  }
}

class _PageHit {
  _PageHit(this.index, this.x, this.y);
  final int index;
  final double x;
  final double y;
}
