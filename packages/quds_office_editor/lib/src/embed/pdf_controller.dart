import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size, lerpDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:quds_office_engine/pdf_file.dart';
import 'package:quds_office_engine/quds_office_engine.dart';

import '../core/command_pipeline.dart';
import '../core/virtual_viewport.dart';
import '../editor_pdf/pdf_page_layout.dart';
import '../editor_pdf/pdf_text_selection.dart';
import 'office_clipboard.dart';
import 'office_theme.dart';

/// View / select controller for an opened PDF.
class PdfViewerController extends ChangeNotifier {
  /// PdfViewerController API.
  PdfViewerController({
    PdfFile? file,
    List<PdfDisplayList>? lists,
    this.config = const OfficeSurfaceConfig(mode: OfficeInteractionMode.viewing),
  }) : _file = file,
       _lists = lists ?? file?.displayLists() ?? <PdfDisplayList>[];

  /// fromBytes API.
  factory PdfViewerController.fromBytes(
    Uint8List bytes, {
    String? password,
    OfficeSurfaceConfig config = const OfficeSurfaceConfig(
      mode: OfficeInteractionMode.viewing,
    ),
  }) {
    final PdfFile file = PdfFile.open(bytes, password: password);
    return PdfViewerController(
      file: file,
      lists: file.displayLists(),
      config: config,
    );
  }

  PdfFile? _file;
  List<PdfDisplayList> _lists;
  OfficeSurfaceConfig config;
  final VirtualViewport viewport = VirtualViewport();
  PdfTextSelection? selection;
  final List<PdfTextRun> findHits = <PdfTextRun>[];
  var pageIndex = 0;

  static const Duration _zoomAnimDuration = Duration(milliseconds: 200);
  var _zoomAnimating = false;
  var _zoomFrom = 1.0;
  var _zoomTo = 1.0;
  Offset _zoomOrigin0 = Offset.zero;
  Offset _zoomFocal = Offset.zero;
  Duration _zoomStart = Duration.zero;

  /// file API.
  PdfFile? get file => _file;

  /// lists API.
  List<PdfDisplayList> get lists => _lists;

  /// pageCount API.
  int get pageCount => _file?.pageCount ?? _lists.length;

  /// loadBytesAsync API.
  Future<void> loadBytesAsync(
    Uint8List bytes, {
    String? password,
    void Function(OfficeOpenProgress progress)? onProgress,
  }) async {
    final PdfOpenPayload payload = await OfficeIsolateOpen.pdf(
      bytes,
      password: password,
      onProgress: onProgress,
    );
    _file = payload.file;
    _lists = payload.lists;
    selection = null;
    findHits.clear();
    pageIndex = 0;
    viewport.origin = Offset.zero;
    notifyListeners();
  }

  /// goToPage API.
  void goToPage(int index) {
    pageIndex = index.clamp(0, mathMax(0, pageCount - 1));
    final double top = PdfPageLayout.stackTop(_lists, pageIndex, viewport.scale);
    viewport.origin = Offset(viewport.origin.dx, top);
    if (viewport.extent.width > 0 && viewport.extent.height > 0) {
      viewport.clampTo(
        content: PdfPageLayout.contentSize(_lists, viewport.scale),
        view: viewport.extent,
      );
    }
    notifyListeners();
  }

  /// Keep [pageIndex] aligned with the visible stack (wheel / scrollbar).
  void adoptVisiblePage() {
    if (_lists.isEmpty) {
      return;
    }
    final double y = viewport.origin.dy +
        (viewport.extent.height > 0 ? viewport.extent.height * 0.35 : 0);
    pageIndex = PdfPageLayout.pageAtY(_lists, y, viewport.scale);
  }

  /// Canvas pan / wheel / pinch finished — keep chrome in sync.
  void viewportChanged() {
    adoptVisiblePage();
    notifyListeners();
  }

  /// setScale API. Zooms about [focal] (content space) or the view center.
  ///
  /// When [animate] is true (default), scale and origin ease over ~200ms so the
  /// last page raster stretches like an image instead of jumping.
  void setScale(double scale, {Offset? focal, bool animate = true}) {
    final Offset focus = focal ?? _viewCenter();
    final double old = viewport.scale;
    final double clamped = scale.clamp(
      VirtualViewport.minScale,
      VirtualViewport.maxScale,
    );
    final double pending = _zoomAnimating ? _zoomTo : old;
    if ((clamped - pending).abs() < 1e-9) {
      return;
    }
    if (!animate) {
      _stopZoomAnimation();
      _commitScale(clamped, focus: focus, from: old, origin0: viewport.origin);
      return;
    }
    _beginZoomAnimation(
      from: old,
      to: clamped,
      origin0: viewport.origin,
      focal: focus,
    );
  }

  /// Multiply the current scale (ribbon / shortcuts / ctrl+wheel).
  void zoomBy(double factor, {Offset? focal, bool animate = true}) {
    final double base = _zoomAnimating ? _zoomTo : viewport.scale;
    setScale(base * factor, focal: focal, animate: animate);
  }

  Offset _viewCenter() {
    final Size extent = viewport.extent;
    if (extent.width <= 0 || extent.height <= 0) {
      return viewport.origin;
    }
    return viewport.origin + Offset(extent.width / 2, extent.height / 2);
  }

  void _clampViewport() {
    final Size extent = viewport.extent;
    if (extent.width <= 0 || extent.height <= 0) {
      return;
    }
    viewport.clampTo(
      content: PdfPageLayout.contentSize(_lists, viewport.scale),
      view: extent,
    );
  }

  void _commitScale(
    double next, {
    required Offset focus,
    required double from,
    required Offset origin0,
  }) {
    viewport.setScale(next);
    viewport.origin = PdfPageLayout.originAfterScale(
      lists: _lists,
      origin: origin0,
      focal: focus,
      oldScale: from,
      nextScale: viewport.scale,
    );
    _clampViewport();
    notifyListeners();
  }

  void _beginZoomAnimation({
    required double from,
    required double to,
    required Offset origin0,
    required Offset focal,
  }) {
    if ((to - from).abs() < 1e-9) {
      return;
    }
    _zoomFrom = from;
    _zoomTo = to;
    _zoomOrigin0 = origin0;
    _zoomFocal = focal;
    _zoomStart = SchedulerBinding.instance.currentFrameTimeStamp;
    if (_zoomAnimating) {
      return;
    }
    _zoomAnimating = true;
    SchedulerBinding.instance.scheduleFrameCallback(_onZoomFrame);
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _onZoomFrame(Duration timestamp) {
    if (!_zoomAnimating) {
      return;
    }
    final int elapsedMs =
        (timestamp - _zoomStart).inMilliseconds.clamp(0, 1 << 30);
    final double t = (elapsedMs / _zoomAnimDuration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    final double eased = Curves.easeOutCubic.transform(t);
    final double next = lerpDouble(_zoomFrom, _zoomTo, eased)!;
    viewport.scale = next;
    viewport.origin = PdfPageLayout.originAfterScale(
      lists: _lists,
      origin: _zoomOrigin0,
      focal: _zoomFocal,
      oldScale: _zoomFrom,
      nextScale: next,
    );
    _clampViewport();
    notifyListeners();
    if (t < 1) {
      SchedulerBinding.instance.scheduleFrameCallback(_onZoomFrame);
      return;
    }
    _zoomAnimating = false;
    viewport.setScale(_zoomTo);
    viewport.origin = PdfPageLayout.originAfterScale(
      lists: _lists,
      origin: _zoomOrigin0,
      focal: _zoomFocal,
      oldScale: _zoomFrom,
      nextScale: viewport.scale,
    );
    _clampViewport();
    notifyListeners();
  }

  void _stopZoomAnimation() {
    _zoomAnimating = false;
  }

  @override
  void dispose() {
    _stopZoomAnimation();
    super.dispose();
  }

  /// copySelection API.
  String copySelection() => selection?.plainText(_lists) ?? '';

  /// copyToClipboard API.
  Future<void> copyToClipboard() async {
    final String text = copySelection();
    if (text.isEmpty) {
      return;
    }
    await OfficeClipboard.instance.write(
      OfficeClipboardPayload.fromPlain(text),
    );
  }

  /// find API.
  List<OfficeFindHit> find(String query) {
    findHits.clear();
    final PdfFile? file = _file;
    if (file == null || query.isEmpty) {
      notifyListeners();
      return const <OfficeFindHit>[];
    }
    final List<OfficeFindHit> hits = OfficeFind.inPdf(
      file,
      OfficeFindOptions(query: query),
    );
    for (final OfficeFindHit hit in hits) {
      final int page = hit.pageIndex ?? 0;
      if (page < 0 || page >= _lists.length) {
        continue;
      }
      findHits.addAll(_lists[page].runs.where((PdfTextRun run) => run.text.contains(query)));
    }
    notifyListeners();
    return hits;
  }

  /// selectRun API.
  void selectRun(int page, PdfTextRun run) {
    final int index = page < 0 || page >= _lists.length
        ? 0
        : _runIndex(_lists[page], run);
    setSelection(PdfTextSelection.run(page, index, run));
  }

  /// setSelection API.
  void setSelection(PdfTextSelection? range) {
    selection = range;
    if (range != null) {
      pageIndex = range.normalized.extent.page.clamp(0, mathMax(0, pageCount - 1));
    }
    notifyListeners();
  }

  static int _runIndex(PdfDisplayList list, PdfTextRun run) {
    for (int i = 0; i < list.runs.length; i++) {
      final PdfTextRun item = list.runs[i];
      if (identical(item, run) ||
          (item.x == run.x && item.y == run.y && item.text == run.text)) {
        return i;
      }
    }
    return 0;
  }

  /// followLink API.
  void followLink(PdfLinkAction action) {
    if (action.pageIndex != null) {
      goToPage(action.pageIndex!);
    }
  }

  /// stats API.
  OfficeTextStats stats() {
    final PdfFile? file = _file;
    if (file == null) {
      return const OfficeTextStats();
    }
    return OfficeTextStats.ofPdf(file);
  }

  /// fitWidth API.
  void fitWidth(double viewportWidth) {
    final PdfFile? file = _file;
    if (file == null || file.pageCount == 0 || viewportWidth <= 0) {
      return;
    }
    final double usable =
        viewportWidth - PdfPageLayout.gutter * 2 - PdfPageLayout.scrollBar;
    if (usable <= 0) {
      return;
    }
    setScale(usable / file.pageAt(pageIndex).width / PdfPageLayout.pointsToPixels);
  }

  /// Fit the current page to the live canvas width.
  void fitVisibleWidth() {
    final double width = viewport.extent.width;
    fitWidth(width > 0 ? width : 720);
  }

  /// fitPage API.
  void fitPage(double viewportWidth, double viewportHeight) {
    final PdfFile? file = _file;
    if (file == null || file.pageCount == 0) {
      return;
    }
    final PdfPageInfo page = file.pageAt(pageIndex);
    final double sx = viewportWidth / page.width;
    final double sy = viewportHeight / page.height;
    setScale(
      (sx < sy ? sx : sy) / PdfPageLayout.pointsToPixels,
    );
  }

  /// isDirty API.
  bool get isDirty => _file?.isDirty ?? false;

  int mathMax(int a, int b) => a > b ? a : b;
}

/// Editing controller: annotations, forms, incremental save.
class PdfEditorController extends PdfViewerController {
  /// PdfEditorController API.
  PdfEditorController({
    super.file,
    super.lists,
    super.config = const OfficeSurfaceConfig(),
  });

  /// fromBytes API.
  factory PdfEditorController.fromBytes(
    Uint8List bytes, {
    String? password,
    OfficeSurfaceConfig config = const OfficeSurfaceConfig(),
  }) {
    final PdfFile file = PdfFile.open(bytes, password: password);
    return PdfEditorController(
      file: file,
      lists: file.displayLists(),
      config: config,
    );
  }

  final CommandPipeline commands = CommandPipeline();

  /// canUndo API.
  bool get canUndo => commands.canUndo;

  /// canRedo API.
  bool get canRedo => commands.canRedo;

  /// highlightSelection API.
  void highlightSelection({int color = 0x66FFE066}) {
    final PdfFile? file = _file;
    final PdfTextSelection? range = selection;
    if (file == null || range == null || range.isCollapsed || !config.allowsMutation) {
      return;
    }
    if (file.permissions != null && !file.permissions!.canAnnotate) {
      return;
    }
    final List<({int page, Rect rect})> boxes = range.boxes(_lists);
    if (boxes.isEmpty) {
      return;
    }
    for (final ({int page, Rect rect}) item in boxes) {
      final Rect box = item.rect;
      commands.commit(
        _PdfAnnotCommand(
          file,
          item.page,
          PdfAnnot(
            id: 0,
            subtype: 'Highlight',
            rect: PdfRect(
              x: box.left,
              y: box.top,
              width: box.width,
              height: box.height,
            ),
            quads: <PdfQuad>[
              PdfQuad(
                x1: box.left,
                y1: box.top,
                x2: box.right,
                y2: box.top,
                x3: box.right,
                y3: box.bottom,
                x4: box.left,
                y4: box.bottom,
              ),
            ],
            color: color,
          ),
        ),
      );
    }
    notifyListeners();
  }

  /// addNote API.
  void addNote(PdfRect rect, String text) {
    final PdfFile? file = _file;
    if (file == null || !config.allowsMutation) {
      return;
    }
    commands.commit(
      _PdfAnnotCommand(
        file,
        pageIndex,
        PdfAnnot(id: 0, subtype: 'Text', rect: rect, contents: text),
      ),
    );
    notifyListeners();
  }

  /// addInk API.
  void addInk(List<PdfPoint> points) {
    final PdfFile? file = _file;
    if (file == null || points.length < 2 || !config.allowsMutation) {
      return;
    }
    var minX = points.first.x, minY = points.first.y, maxX = minX, maxY = minY;
    for (final PdfPoint p in points) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
    commands.commit(
      _PdfAnnotCommand(
        file,
        pageIndex,
        PdfAnnot(
          id: 0,
          subtype: 'Ink',
          rect: PdfRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY,
          ),
          ink: <List<PdfPoint>>[points],
        ),
      ),
    );
    notifyListeners();
  }

  /// Toggle an optional-content group and rebuild display lists.
  void setLayerVisible(int objectId, bool visible) {
    _file?.setLayerVisible(objectId, visible);
    _lists = _file?.displayLists() ?? _lists;
    notifyListeners();
  }

  /// setFieldValue API.
  void setFieldValue(String name, String value) {
    final PdfFormField? field = _file?.form.field(name);
    if (field == null || field.readOnly || !config.allowsMutation) {
      return;
    }
    field.value = value;
    _file?.form.needAppearances = true;
    _file?.markDirty(field.pageIndex);
    notifyListeners();
  }

  /// deletePage API.
  void deletePageAt(int index) {
    _file?.deletePage(index);
    _lists = _file?.displayLists() ?? _lists;
    notifyListeners();
  }

  /// insertBlankPage API.
  void insertBlankPage(int index) {
    _file?.insertBlankPage(index);
    _lists = _file?.displayLists() ?? _lists;
    notifyListeners();
  }

  /// rotatePage API.
  void rotateCurrentPage(int degrees) {
    _file?.rotatePage(pageIndex, degrees);
    _lists = _file?.displayLists() ?? _lists;
    notifyListeners();
  }

  /// mergeFrom API.
  void mergeFrom(PdfFile other) {
    _file?.appendPages(other);
    _lists = _file?.displayLists() ?? _lists;
    notifyListeners();
  }

  /// extractPages API.
  Uint8List? extractPages(List<int> indices) => _file?.extractPages(indices);

  /// exportXfdf API.
  String exportXfdf() {
    final PdfFile? file = _file;
    if (file == null) {
      return '';
    }
    return PdfXfdf.exportXml(file);
  }

  /// importXfdf API.
  void importXfdf(String xml) {
    final PdfFile? file = _file;
    if (file == null || !config.allowsMutation) {
      return;
    }
    PdfXfdf.importXml(file, xml);
    _lists = file.displayLists();
    notifyListeners();
  }

  /// redactSelection API.
  void redactSelection({PdfRedactMode mode = PdfRedactMode.visual}) {
    final PdfFile? file = _file;
    final PdfTextSelection? range = selection;
    if (file == null || range == null || range.isCollapsed || !config.allowsMutation) {
      return;
    }
    for (final ({int page, Rect rect}) item in range.boxes(_lists)) {
      file.redactRect(
        item.page,
        PdfRect(
          x: item.rect.left,
          y: item.rect.top,
          width: item.rect.width,
          height: item.rect.height,
        ),
        mode: mode,
      );
    }
    notifyListeners();
  }

  /// saveBytes API.
  Uint8List saveBytes() {
    final PdfFile? file = _file;
    if (file == null) {
      return Uint8List(0);
    }
    return PdfIncrementalSave.write(
      originalBytes: file.originalBytes,
      file: file,
    );
  }

  /// undo API.
  void undo() {
    if (commands.canUndo) {
      commands.undo();
      notifyListeners();
    }
  }

  /// redo API.
  void redo() {
    if (commands.canRedo) {
      commands.redo();
      notifyListeners();
    }
  }
}

class _PdfAnnotCommand implements OfficeCommand {
  _PdfAnnotCommand(this.file, this.page, this.annot);

  final PdfFile file;
  final int page;
  final PdfAnnot annot;
  int? _id;

  @override
  void execute() {
    final PdfAnnot created = file.addAnnot(page, annot);
    _id = created.id;
  }

  @override
  void undo() {
    final int? id = _id;
    if (id != null) {
      file.removeAnnot(page, id);
    }
  }

  @override
  OfficeCommand invert() => this;
}
