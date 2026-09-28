import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

/// Host-only helper: open a PDF path into a [PdfViewerController].
///
/// The engine stays on [Uint8List]; this reads the file in the example app.
Future<void> loadPdfFromFilePath(
  PdfViewerController controller,
  String path, {
  String? password,
  void Function(Object error)? onError,
}) async {
  final Uint8List bytes = await File(path).readAsBytes();
  await controller.loadBytesAsync(
    bytes,
    password: password,
    onLoadError: onError,
  );
}

/// Default studio options — swipe, fling, and snap enabled for demos.
PdfViewerOptions studioPdfViewerOptions({
  bool nightMode = false,
  bool swipeHorizontal = false,
  bool pageSnap = true,
  bool pageFling = true,
  bool enableSwipe = true,
  bool showScrollIndicators = true,
  bool preventLinkNavigation = false,
  PdfFitPolicy fitPolicy = PdfFitPolicy.width,
  Color? backgroundColor,
}) {
  return PdfViewerOptions(
    defaultPage: 0,
    fitPolicy: fitPolicy,
    minZoom: 0.25,
    maxZoom: 4,
    enableSwipe: enableSwipe,
    swipeHorizontal: swipeHorizontal,
    pageFling: pageFling,
    pageSnap: pageSnap,
    preventLinkNavigation: preventLinkNavigation,
    nightMode: nightMode,
    showScrollIndicators: showScrollIndicators,
    backgroundColor: backgroundColor,
  );
}

/// Lightweight event sink used by the studio status line / toasts.
class StudioPdfViewerEvents {
  /// StudioPdfViewerEvents API.
  StudioPdfViewerEvents({this.onChanged});

  /// Called after each event so the host can rebuild chrome.
  VoidCallback? onChanged;

  String last = '';
  int? lastPage;
  int pageCount = 0;
  int renderCount = 0;

  void _mark(String message) {
    last = message;
    onChanged?.call();
  }

  void viewCreated(PdfViewerController _) {
    _mark('viewCreated');
  }

  void loadComplete(int count) {
    pageCount = count;
    _mark('loadComplete($count)');
  }

  void pageChanged(int page, int total) {
    lastPage = page;
    pageCount = total;
    _mark('pageChanged(${page + 1}/$total)');
  }

  void render(int page) {
    renderCount++;
    last = 'onRender(${page + 1})';
    // Avoid a setState storm while tiles decode; pageChanged still refreshes.
  }

  void error(Object error) {
    _mark('onError: $error');
  }

  void pageError(int page, Object error) {
    _mark('onPageError(${page + 1}): $error');
  }

  void link(PdfLinkAction action) {
    final String target = action.uri ??
        (action.pageIndex != null ? 'page ${action.pageIndex! + 1}' : '?');
    _mark('onLinkHandle($target)');
  }

  /// Optional page chrome: thin accent rule under the paper for demos.
  void draw(Canvas canvas, Size size, int page) {
    // Intentionally light — proves onDraw is wired without cluttering pages.
    if (page != 0) {
      return;
    }
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 2, size.width, 2),
      Paint()..color = const Color(0x662B579A),
    );
  }
}
