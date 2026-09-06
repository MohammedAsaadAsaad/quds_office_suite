import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quds_office_engine/quds_office_engine.dart';

import '../core/command_pipeline.dart';
import '../core/input_bridge.dart';
import '../core/virtual_viewport.dart';
import '../editor_sheet/inline_cell_editor.dart';
import '../editor_sheet/selection_matrix.dart';
import '../editor_sheet/sheet_scroll_extent.dart';
import '../editor_word/caret_engine.dart';
import '../editor_word/paint_run_text.dart';
import 'office_clipboard.dart';
import 'office_theme.dart';

/// Shared undo, dirty-state, and interaction mode for every embedded editor.
abstract class OfficeController extends ChangeNotifier {
  OfficeController({OfficeSurfaceConfig? config})
    : _config = config ?? const OfficeSurfaceConfig() {
    commands.addListener(_onCommands);
  }

  final CommandPipeline commands = CommandPipeline();
  final VirtualViewport viewport = VirtualViewport();
  OfficeSurfaceConfig _config;
  var _dirty = false;
  var _disposed = false;

  OfficeSurfaceConfig get config => _config;
  OfficeInteractionMode get mode => _config.mode;
  OfficeTheme get theme => _config.theme;
  bool get isDirty => _dirty;
  bool get canUndo => commands.canUndo;
  bool get canRedo => commands.canRedo;
  OpcPackageKind get kind;

  set config(OfficeSurfaceConfig value) {
    if (identical(_config, value)) {
      return;
    }
    _config = value;
    notifyListeners();
  }

  /// Assigns [value] without notifying listeners (safe during widget build).
  void syncConfig(OfficeSurfaceConfig value) {
    _config = value;
  }

  void setMode(OfficeInteractionMode mode) {
    _config = _config.copyWith(mode: mode);
    if (!config.allowsMutation) {
      detachInput();
    }
    notifyListeners();
  }

  void markClean() {
    _dirty = false;
    notifyListeners();
  }

  /// Hosts and surfaces call this after pointer-driven state changes.
  void refresh() {
    notifyListeners();
  }

  void undo() {
    if (!config.enableUndo || !config.allowsMutation || !commands.canUndo) {
      return;
    }
    beforeHistoryChange();
    commands.undo();
    afterHistoryChange();
  }

  void redo() {
    if (!config.enableUndo || !config.allowsMutation || !commands.canRedo) {
      return;
    }
    beforeHistoryChange();
    commands.redo();
    afterHistoryChange();
  }

  /// Snapshot state that IME must not echo back after undo/redo.
  void beforeHistoryChange() {}

  /// Relayout / refresh after undo/redo.
  void afterHistoryChange() {}

  Uint8List saveBytes({String? password});

  /// Encodes the package, using a worker isolate when the file is large.
  ///
  /// Unlike [saveBytes], this does not mark the controller clean — the host
  /// should call [markClean] after the bytes are written to disk.
  Future<Uint8List> saveBytesAsync({String? password}) async {
    return saveBytes(password: password);
  }

  void detachInput();

  bool get canCopy => false;

  bool get canCut => canCopy && config.allowsMutation;

  bool get canPaste => config.allowsMutation;

  void selectAll() {}

  Future<void> copyToClipboard() async {}

  Future<void> cutToClipboard() async {
    await copyToClipboard();
  }

  Future<void> pasteFromClipboard({
    OfficePasteMode mode = OfficePasteMode.keepSource,
  }) async {}

  String get semanticsLabel;
  String get semanticsValue;

  void _onCommands() {
    _dirty = true;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    commands.removeListener(_onCommands);
    detachInput();
    super.dispose();
  }
}

/// Word document controller: IME, caret, layout, load/save.
class WordEditorController extends OfficeController {
  WordEditorController({WmlDocument? document, super.config, this.layoutEngine})
    : document = document ?? WmlDocument.empty() {
    relayout();
    input = OfficeInputBridge(
      onValue: _onIme,
      onAction: _onImeAction,
      onSelector: _onImeSelector,
    );
  }

  factory WordEditorController.fromBytes(
    Uint8List bytes, {
    String? password,
    OfficeSurfaceConfig? config,
  }) {
    final WordEditorController controller = WordEditorController(
      config: config,
    );
    controller.loadBytes(bytes, password: password);
    return controller;
  }

  WmlDocument document;
  late LaidOutDocument documentLaidOut;
  LaidOutDocument? commentLaidOut;
  final WordLayoutEngine? layoutEngine;
  final CaretEngine documentCaret = CaretEngine();
  final CaretEngine commentCaret = CaretEngine();
  final CaretEngine headerFooterCaret = CaretEngine();
  var _editingComment = false;
  var _editingHeaderFooter = false;
  var _editingFooter = false;
  var _editingSectionIndex = 0;
  double commentSurfaceWidth = 288;
  late final OfficeInputBridge input;
  var _applyingIme = false;
  var _localEditAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _textBeforeLocalEdit;
  double? _stickyCaretX;

  @override
  OpcPackageKind get kind => OpcPackageKind.word;

  WmlVisual? selectedVisual;
  WmlEquation? selectedEquation;
  int? selectedCommentId;
  var equationSlot = 0;
  var equationCaret = 0;
  VoidCallback? onRequestFocus;
  var pictureCropMode = false;
  ({
    double width,
    double height,
    double offsetX,
    double offsetY,
    double rotationDeg,
    double cropLeft,
    double cropTop,
    double cropRight,
    double cropBottom,
  })? _visualSnap;

  CaretEngine get caret {
    if (isEditingComment) {
      return commentCaret;
    }
    if (isEditingHeaderFooter) {
      return headerFooterCaret;
    }
    return documentCaret;
  }

  LaidOutDocument get laidOut =>
      isEditingComment && commentLaidOut != null
          ? commentLaidOut!
          : documentLaidOut;

  bool get isEditingComment =>
      _editingComment && selectedComment != null;

  bool get isEditingHeaderFooter => _editingHeaderFooter;

  bool get isEditingFooter => _editingHeaderFooter && _editingFooter;

  bool get isEditingHeader => _editingHeaderFooter && !_editingFooter;

  int get editingSectionIndex => _editingSectionIndex;

  List<WmlParagraph> get headerFooterParagraphs =>
      _ensureHeaderFooterParagraphs();

  /// Modern comments: Home character format only — no font/size/styles/paragraph.
  bool get commentFormatLimited => isEditingComment;

  List<WmlParagraph> get _paragraphs {
    if (isEditingComment) {
      return _ensureCommentParagraphs(selectedComment!);
    }
    if (isEditingHeaderFooter) {
      return _ensureHeaderFooterParagraphs();
    }
    return document.paragraphs.toList();
  }

  List<WmlVisual> get visuals => document.visuals.toList();

  WmlParagraph get _activeParagraph {
    final List<WmlParagraph> paras = _paragraphs;
    if (paras.isEmpty) {
      final WmlParagraph created = WmlParagraph();
      if (isEditingComment) {
        selectedComment!.paragraphs.add(created);
        return created;
      }
      if (isEditingHeaderFooter) {
        _ensureHeaderFooterParagraphs().add(created);
        return created;
      }
      sectionAtCaret.blocks.add(created);
      return created;
    }
    return paras[caret.paragraphIndex.clamp(0, paras.length - 1)];
  }

  List<WmlParagraph> _ensureCommentParagraphs(WmlComment comment) {
    if (comment.paragraphs.isEmpty) {
      comment.paragraphs.add(
        WmlParagraph(
          inlines: <WmlInline>[
            WmlRun(properties: WmlRunProps(fontSizeHalfPoints: 20)),
          ],
        ),
      );
    }
    return comment.paragraphs;
  }

  WmlDocument get commentDocument {
    final WmlComment comment = selectedComment!;
    return WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          pageSize: WmlPageSize(width: commentSurfaceWidth, height: 2000),
          margins: const WmlPageMargins(
            top: 4,
            bottom: 4,
            left: 4,
            right: 4,
          ),
          blocks: <WmlBlock>[
            ..._ensureCommentParagraphs(comment),
            ...comment.visuals,
          ],
        ),
      ],
    );
  }

  double get commentSurfaceHeight {
    final LaidOutDocument? laid = commentLaidOut;
    if (laid == null || laid.pages.isEmpty) {
      return 72;
    }
    var bottom = 20.0;
    for (final LaidOutLine line in laid.pages.first.lines) {
      final double edge = line.y + line.height;
      if (edge > bottom) {
        bottom = edge;
      }
    }
    for (final LaidOutBox box in laid.pages.first.frames) {
      final double edge = box.y + box.height;
      if (edge > bottom) {
        bottom = edge;
      }
    }
    return (bottom + 10).clamp(56.0, 320.0);
  }

  List<WmlParagraph> _ensureHeaderFooterParagraphs() {
    final WmlSection section = document.sections.isEmpty
        ? WmlSection()
        : document.sections[_editingSectionIndex.clamp(
            0,
            document.sections.length - 1,
          )];
    final List<WmlParagraph> story =
        _editingFooter ? section.footer : section.header;
    if (story.isEmpty) {
      story.add(WmlParagraph(inlines: <WmlInline>[WmlRun(text: '')]));
    }
    return story;
  }

  void beginHeaderFooterEdit(
    int pageIndex, {
    required bool footer,
  }) {
    if (!config.allowsMutation && !config.allowsSelection) {
      return;
    }
    endCommentEdit();
    final int sectionIndex = pageIndex >= 0 &&
            pageIndex < documentLaidOut.pages.length
        ? documentLaidOut.pages[pageIndex].sectionIndex
        : sectionIndexAtCaret;
    _editingSectionIndex = sectionIndex.clamp(
      0,
      document.sections.isEmpty ? 0 : document.sections.length - 1,
    );
    _editingFooter = footer;
    _editingHeaderFooter = true;
    selectedVisual = null;
    selectedEquation = null;
    selectedTable = null;
    selectedTableBand = null;
    final List<WmlParagraph> paras = _ensureHeaderFooterParagraphs();
    headerFooterCaret
      ..paragraphIndex = 0
      ..logicalIndex = 0
      ..selectionAnchorParagraph = 0
      ..selectionAnchor = 0;
    headerFooterCaret.paragraphIndex =
        headerFooterCaret.paragraphIndex.clamp(0, paras.length - 1);
    relayout();
    onRequestFocus?.call();
    attachInput();
    notifyListeners();
  }

  void endHeaderFooterEdit() {
    if (!_editingHeaderFooter) {
      return;
    }
    _editingHeaderFooter = false;
    notifyListeners();
  }

  void beginCommentEdit(int id) {
    selectedCommentId = id;
    if (selectedComment == null) {
      return;
    }
    endHeaderFooterEdit();
    _editingComment = true;
    selectedVisual = null;
    selectedEquation = null;
    final List<WmlParagraph> paras = _ensureCommentParagraphs(selectedComment!);
    commentCaret.paragraphIndex =
        commentCaret.paragraphIndex.clamp(0, paras.length - 1);
    final int max = paras[commentCaret.paragraphIndex].text.length;
    commentCaret.logicalIndex = commentCaret.logicalIndex.clamp(0, max);
    commentCaret.selectionAnchorParagraph =
        commentCaret.selectionAnchorParagraph.clamp(0, paras.length - 1);
    commentCaret.selectionAnchor = commentCaret.selectionAnchor.clamp(
      0,
      paras[commentCaret.selectionAnchorParagraph].text.length,
    );
    _layoutComment();
    onRequestFocus?.call();
    attachInput();
    notifyListeners();
  }

  void endCommentEdit() {
    if (!_editingComment) {
      return;
    }
    _editingComment = false;
    notifyListeners();
  }

  void setCommentSurfaceWidth(double width) {
    final double next = width.clamp(160.0, 480.0);
    if ((commentSurfaceWidth - next).abs() < 0.5) {
      return;
    }
    commentSurfaceWidth = next;
    if (selectedComment != null) {
      _layoutComment();
      notifyListeners();
    }
  }

  void _layoutComment() {
    if (selectedComment == null) {
      commentLaidOut = null;
      return;
    }
    commentLaidOut = (layoutEngine ?? WordLayoutEngine(font: null))
        .layout(commentDocument);
  }

  void loadBytes(Uint8List bytes, {String? password}) {
    _acceptOpenedWord(
      WordDeserializer().read(
        OfficeRepair.open(bytes, password: password),
      ),
    );
  }

  Future<void> loadBytesAsync(
    Uint8List bytes, {
    String? password,
    void Function(OfficeOpenProgress progress)? onProgress,
  }) async {
    final WordOpenPayload opened = await OfficeIsolateOpen.word(
      bytes,
      password: password,
      onProgress: onProgress,
    );
    _acceptOpenedWord(opened.document, laidOut: opened.laidOut);
  }

  void _acceptOpenedWord(WmlDocument opened, {LaidOutDocument? laidOut}) {
    document = opened;
    _editingComment = false;
    documentCaret.paragraphIndex = 0;
    documentCaret.logicalIndex = 0;
    documentCaret.collapseSelection();
    commentCaret.paragraphIndex = 0;
    commentCaret.logicalIndex = 0;
    commentCaret.collapseSelection();
    selectedVisual = null;
    selectedEquation = null;
    equationSlot = 0;
    equationCaret = 0;
    pictureCropMode = false;
    if (laidOut != null && layoutEngine == null) {
      documentLaidOut = laidOut;
      _layoutComment();
    } else {
      relayout();
    }
    _dirty = false;
    notifyListeners();
  }

  @override
  Uint8List saveBytes({String? password}) {
    final Uint8List bytes = WordSerializer().writeBytes(
      document,
      password: password,
    );
    markClean();
    return bytes;
  }

  @override
  Future<Uint8List> saveBytesAsync({String? password}) {
    return OfficeIsolateSave.word(document, password: password);
  }

  /// Host opens web / file targets. Internal anchors stay in the editor.
  void Function(WmlHyperlink link)? onFollowExternalLink;

  void relayout() {
    WordLink.ensureHeadingBookmarks(document);
    WordToc.refreshEmpty(document);
    WordToc.rebindHeadings(document);
    final WordLayoutEngine engine = layoutEngine ?? WordLayoutEngine(font: null);
    documentLaidOut = engine.layout(document);
    if (WordToc.syncPageNumbers(document, documentLaidOut)) {
      documentLaidOut = engine.layout(document);
    }
    _layoutComment();
  }

  int get activeHeadingLevel =>
      WordToc.headingLevelOf(_activeParagraph) ?? 0;

  void applyHeading(int level) {
    if (!config.allowsMutation || isEditingComment) {
      return;
    }
    final List<WmlParagraph> paras = _paragraphs;
    if (paras.isEmpty) {
      return;
    }
    final int startPara;
    final int endPara;
    if (caret.isCollapsed) {
      startPara = caret.paragraphIndex.clamp(0, paras.length - 1);
      endPara = startPara;
    } else {
      final ({
        int startPara,
        int startIdx,
        int endPara,
        int endIdx,
      }) range = caret.normalizedRange;
      startPara = range.startPara;
      endPara = range.endPara;
    }
    final List<int> targets = <int>[
      for (int p = startPara; p <= endPara; p++)
        if (!WordToc.isFieldParagraph(paras[p])) p,
    ];
    if (targets.isEmpty) {
      return;
    }
    final Map<int, _HeadingSnap> before = <int, _HeadingSnap>{
      for (final int p in targets) p: _HeadingSnap.capture(paras[p]),
    };
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          for (final int p in targets) {
            before[p]!.restore(paras[p]);
            WordToc.applyHeading(paras[p], level);
          }
        },
        undoFn: () {
          for (final int p in targets) {
            before[p]!.restore(paras[p]);
          }
        },
      ),
    );
    fitPaintMetrics(themeFamily: config.theme.fontFamily);
    _syncImeSelection();
    notifyListeners();
  }

  void insertHeading({int level = 1, String text = ''}) {
    if (!config.allowsMutation) {
      return;
    }
    final WmlParagraph created = WmlParagraph(
      inlines: <WmlInline>[WmlRun(text: text)],
    );
    WordToc.applyHeading(created, level);
    final ({List<WmlBlock> parent, int index})? slot =
        _hostSlotOf(_activeParagraph);
    final List<WmlBlock> parent =
        slot?.parent ?? document.sections.first.blocks;
    final int at = slot == null
        ? parent.length
        : (slot.index + 1).clamp(0, parent.length);
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          if (!parent.contains(created)) {
            parent.insert(at.clamp(0, parent.length), created);
          }
        },
        undoFn: () => parent.remove(created),
      ),
    );
    final List<WmlParagraph> paras = _paragraphs;
    caret.paragraphIndex = paras.indexOf(created).clamp(0, paras.length - 1);
    caret.logicalIndex = created.text.length;
    caret.collapseSelection();
    fitPaintMetrics(themeFamily: config.theme.fontFamily);
    _syncImeSelection();
    notifyListeners();
  }

  void insertTableOfContents({
    int minLevel = 1,
    int maxLevel = 3,
    String title = 'Table of Contents',
  }) {
    if (!config.allowsMutation) {
      return;
    }
    final WmlToc toc = WmlToc(
      minLevel: minLevel,
      maxLevel: maxLevel,
      title: title,
    );
    final ({List<WmlBlock> parent, int index})? slot = _topLevelInsertSlot();
    final List<WmlBlock> parent = slot?.parent ?? document.sections.first.blocks;
    final int index = slot == null ? 0 : (slot.index + 1).clamp(0, parent.length);
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          if (!parent.contains(toc)) {
            parent.insert(index.clamp(0, parent.length), toc);
          }
        },
        undoFn: () => parent.remove(toc),
      ),
    );
    WordLink.ensureHeadingBookmarks(document);
    WordToc.refresh(toc, document);
    _relayoutTocPages();
    fitPaintMetrics(themeFamily: config.theme.fontFamily);
    notifyListeners();
  }

  /// Rebuilds TOC entries from headings, or only refreshes printed page numbers.
  void updateTableOfContents({bool pageNumbersOnly = false}) {
    if (!pageNumbersOnly) {
      WordLink.ensureHeadingBookmarks(document);
      WordToc.refreshAll(document);
    }
    _relayoutTocPages();
    fitPaintMetrics(themeFamily: config.theme.fontFamily);
    notifyListeners();
  }

  void _relayoutTocPages() {
    documentLaidOut =
        (layoutEngine ?? WordLayoutEngine(font: null)).layout(document);
    if (WordToc.syncPageNumbers(document, documentLaidOut)) {
      documentLaidOut =
          (layoutEngine ?? WordLayoutEngine(font: null)).layout(document);
    }
    _layoutComment();
  }

  void followLink(WmlHyperlink link) {
    if (link.isInternal) {
      final int? index = WordLink.paragraphIndexForAnchor(
        document,
        link.anchor!,
      );
      if (index != null) {
        jumpToParagraph(index);
      }
      return;
    }
    onFollowExternalLink?.call(link);
  }

  void insertHyperlink({
    required String text,
    WmlHyperlink? link,
    String? target,
  }) {
    if (!config.allowsMutation) {
      return;
    }
    final WmlHyperlink? resolved = link ?? WmlHyperlink.fromTarget(target ?? '');
    if (resolved == null) {
      return;
    }
    final WmlParagraph para = _activeParagraph;
    if (caret.isCollapsed) {
      insertText(text);
      final int end = caret.logicalIndex;
      final int start = (end - text.length).clamp(0, end);
      WordLink.applyRange(para, start, end, resolved);
    } else {
      final ({
        int startPara,
        int startIdx,
        int endPara,
        int endIdx,
      }) range = caret.normalizedRange;
      if (range.startPara == range.endPara) {
        WordLink.applyRange(
          para,
          range.startIdx,
          range.endIdx,
          resolved,
        );
      } else {
        insertText(text);
        final int end = caret.logicalIndex;
        final int start = (end - text.length).clamp(0, end);
        WordLink.applyRange(_activeParagraph, start, end, resolved);
      }
    }
    fitPaintMetrics(themeFamily: config.theme.fontFamily);
    notifyListeners();
  }

  WmlComment? get selectedComment =>
      selectedCommentId == null
          ? null
          : WordComment.byId(document, selectedCommentId!);

  List<WmlComment> commentsAtCaret() {
    final List<WmlParagraph> paras = document.paragraphs.toList();
    if (paras.isEmpty) {
      return const <WmlComment>[];
    }
    final WmlParagraph para =
        paras[documentCaret.paragraphIndex.clamp(0, paras.length - 1)];
    final List<int> ids = WordComment.idsAt(
      para,
      documentCaret.logicalIndex,
    );
    return <WmlComment>[
      for (final int id in ids)
        if (WordComment.byId(document, id) != null) WordComment.byId(document, id)!,
    ];
  }

  void selectComment(int? id, {bool jump = false}) {
    if (id == null || (isEditingComment && selectedCommentId != id)) {
      _editingComment = false;
    }
    selectedCommentId = id;
    _layoutComment();
    if (jump && id != null) {
      jumpToComment(id);
      return;
    }
    notifyListeners();
  }

  void jumpToComment(int id) {
    _editingComment = false;
    selectedCommentId = id;
    final ({int paragraphIndex, int start, int end})? range =
        WordComment.rangeOf(document, WordComment.threadRootId(document, id));
    if (range != null) {
      documentCaret.paragraphIndex = range.paragraphIndex;
      documentCaret.logicalIndex = range.end;
      documentCaret.selectionAnchorParagraph = range.paragraphIndex;
      documentCaret.selectionAnchor = range.start;
      _revealParagraph(range.paragraphIndex);
    }
    _layoutComment();
    notifyListeners();
  }

  void insertComment({
    String text = '',
    String author = 'Quds Office',
    String initials = 'QO',
    int? parentId,
    List<WmlParagraph>? paragraphs,
    List<WmlVisual>? visuals,
  }) {
    if (!config.allowsMutation) {
      return;
    }
    _editingComment = false;
    final String body = text.trim();
    if (body.isEmpty &&
        (paragraphs == null || paragraphs.isEmpty) &&
        parentId == null) {
      // Anchor still needs a body so the pane can edit it.
    }
    final List<WmlParagraph> paras = document.paragraphs.toList();
    if (paras.isEmpty) {
      return;
    }
    int startPara;
    int startIdx;
    int endPara;
    int endIdx;
    if (parentId != null) {
      startPara = caret.paragraphIndex.clamp(0, paras.length - 1);
      startIdx = 0;
      endPara = startPara;
      endIdx = 0;
    } else if (caret.isCollapsed) {
      startPara = caret.paragraphIndex.clamp(0, paras.length - 1);
      startIdx = 0;
      endPara = startPara;
      endIdx = paras[startPara].text.length;
    } else {
      final ({
        int startPara,
        int startIdx,
        int endPara,
        int endIdx,
      }) range = caret.normalizedRange;
      startPara = range.startPara;
      startIdx = range.startIdx;
      endPara = range.endPara;
      endIdx = range.endIdx;
    }
    final Map<int, List<WmlInline>> snapshots = <int, List<WmlInline>>{
      for (int p = startPara; p <= endPara; p++) p: _cloneInlines(paras[p]),
    };
    final List<WmlComment> previous = <WmlComment>[
      for (final WmlComment comment in document.comments) comment.copy(),
    ];
    final int id = WordComment.nextId(document);
    final WmlComment created = WmlComment(
      id: id,
      author: author,
      initials: initials,
      dateIso: DateTime.now().toUtc().toIso8601String(),
      text: body.isEmpty ? (parentId == null ? '' : '') : body,
      paragraphs: paragraphs,
      visuals: visuals,
      parentId: parentId,
    );
    if (created.text.isEmpty && created.visuals.isEmpty) {
      created.text = parentId == null ? ' ' : ' ';
      created.paragraphs.first.inlines.whereType<WmlRun>().first.text = '';
    }
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          document.comments
            ..clear()
            ..addAll(<WmlComment>[
              for (final WmlComment comment in previous) comment.copy(),
              created.copy(),
            ]);
          for (final MapEntry<int, List<WmlInline>> entry in snapshots.entries) {
            paras[entry.key].inlines
              ..clear()
              ..addAll(_cloneInlinesFrom(entry.value));
          }
          if (parentId == null) {
            WordComment.applyDocumentRange(
              document,
              startPara: startPara,
              startIdx: startIdx,
              endPara: endPara,
              endIdx: endIdx,
              id: id,
            );
          }
          selectedCommentId = id;
        },
        undoFn: () {
          document.comments
            ..clear()
            ..addAll(<WmlComment>[
              for (final WmlComment comment in previous) comment.copy(),
            ]);
          for (final MapEntry<int, List<WmlInline>> entry in snapshots.entries) {
            paras[entry.key].inlines
              ..clear()
              ..addAll(_cloneInlinesFrom(entry.value));
          }
          if (selectedCommentId == id) {
            selectedCommentId = parentId;
          }
        },
      ),
    );
    fitPaintMetrics(themeFamily: config.theme.fontFamily);
    if (parentId == null) {
      beginCommentEdit(id);
      commentCaret
        ..paragraphIndex = 0
        ..logicalIndex = selectedComment!.paragraphs.first.text.length
        ..collapseSelection();
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  void replyToComment(
    int parentId, {
    required String text,
    String author = 'Quds Office',
    String initials = 'QO',
  }) {
    final String body = text.trim();
    if (body.isEmpty) {
      return;
    }
    insertComment(
      text: body,
      author: author,
      initials: initials,
      parentId: WordComment.threadRootId(document, parentId),
    );
  }

  void setCommentResolved(int id, bool resolved) {
    final int root = WordComment.threadRootId(document, id);
    final WmlComment? comment = WordComment.byId(document, root);
    if (comment == null || !config.allowsMutation) {
      return;
    }
    final bool before = comment.resolved;
    commands.commit(
      _CallbackCommand(
        executeFn: () => comment.resolved = resolved,
        undoFn: () => comment.resolved = before,
      ),
    );
    selectedCommentId = root;
    notifyListeners();
  }

  void applyCommentRunFormat(int id, void Function(WmlRunProps props) update) {
    if (WordComment.byId(document, id) == null || !config.allowsMutation) {
      return;
    }
    beginCommentEdit(id);
    applyRunFormat(update);
  }

  void insertCommentVisual(int id, OfficeVisual visual) {
    final WmlComment? comment = WordComment.byId(document, id);
    if (comment == null || !config.allowsMutation) {
      return;
    }
    final WmlVisual block = WmlVisual(visual: visual.copy());
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          if (!comment.visuals.contains(block)) {
            comment.visuals.add(block);
          }
        },
        undoFn: () => comment.visuals.remove(block),
      ),
    );
    selectedCommentId = id;
    _layoutComment();
    notifyListeners();
  }

  void removeCommentVisual(int id, WmlVisual visual) {
    final WmlComment? comment = WordComment.byId(document, id);
    if (comment == null || !config.allowsMutation) {
      return;
    }
    final int index = comment.visuals.indexOf(visual);
    if (index < 0) {
      return;
    }
    commands.commit(
      _CallbackCommand(
        executeFn: () => comment.visuals.remove(visual),
        undoFn: () {
          if (!comment.visuals.contains(visual)) {
            comment.visuals.insert(index.clamp(0, comment.visuals.length), visual);
          }
        },
      ),
    );
    _layoutComment();
    notifyListeners();
  }

  void updateComment(
    int id, {
    String? text,
    String? author,
    String? initials,
    List<WmlParagraph>? paragraphs,
  }) {
    final WmlComment? comment = WordComment.byId(document, id);
    if (comment == null || !config.allowsMutation) {
      return;
    }
    final WmlComment before = comment.copy();
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          if (paragraphs != null) {
            comment.paragraphs
              ..clear()
              ..addAll(paragraphs);
          } else if (text != null) {
            comment.text = text;
          }
          if (author != null) {
            comment.author = author;
          }
          if (initials != null) {
            comment.initials = initials;
          }
        },
        undoFn: () {
          comment.paragraphs
            ..clear()
            ..addAll(before.copy().paragraphs);
          comment.visuals
            ..clear()
            ..addAll(before.copy().visuals);
          comment
            ..author = before.author
            ..initials = before.initials
            ..dateIso = before.dateIso
            ..parentId = before.parentId
            ..resolved = before.resolved;
        },
      ),
    );
    selectedCommentId = id;
    notifyListeners();
  }

  void deleteComment(int id) {
    if (!config.allowsMutation) {
      return;
    }
    final Map<int, List<WmlInline>> snapshots = <int, List<WmlInline>>{
      for (int i = 0; i < _paragraphs.length; i++)
        i: _cloneInlines(_paragraphs[i]),
    };
    final List<WmlComment> previous = <WmlComment>[
      for (final WmlComment comment in document.comments) comment.copy(),
    ];
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          WordComment.removeId(document, id);
          if (selectedCommentId == id) {
            selectedCommentId = null;
          }
        },
        undoFn: () {
          document.comments
            ..clear()
            ..addAll(<WmlComment>[
              for (final WmlComment comment in previous) comment.copy(),
            ]);
          final List<WmlParagraph> paras = _paragraphs;
          for (final MapEntry<int, List<WmlInline>> entry in snapshots.entries) {
            if (entry.key < paras.length) {
              paras[entry.key].inlines
                ..clear()
                ..addAll(_cloneInlinesFrom(entry.value));
            }
          }
          selectedCommentId = id;
        },
      ),
    );
    fitPaintMetrics(themeFamily: config.theme.fontFamily);
    notifyListeners();
  }

  void stepComment(int delta) {
    if (document.comments.isEmpty) {
      return;
    }
    final List<WmlComment> comments = WordComment.roots(document);
    if (comments.isEmpty) {
      return;
    }
    final int selectedRoot = selectedCommentId == null
        ? comments.first.id
        : WordComment.threadRootId(document, selectedCommentId!);
    if (selectedCommentId == null) {
      jumpToComment(delta >= 0 ? comments.first.id : comments.last.id);
      return;
    }
    var index = 0;
    for (int i = 0; i < comments.length; i++) {
      if (comments[i].id == selectedRoot) {
        index = i;
        break;
      }
    }
    final int next = (index + delta) % comments.length;
    jumpToComment(comments[next < 0 ? next + comments.length : next].id);
  }

  void jumpToParagraph(int index) {
    _editingComment = false;
    selectedVisual = null;
    selectedEquation = null;
    final List<WmlParagraph> paras = document.paragraphs.toList();
    if (paras.isEmpty) {
      return;
    }
    documentCaret.paragraphIndex = index.clamp(0, paras.length - 1);
    documentCaret.logicalIndex = 0;
    documentCaret.collapseSelection();
    _revealParagraph(documentCaret.paragraphIndex);
    notifyListeners();
  }

  ({List<WmlBlock> parent, int index})? _hostSlotOf(WmlParagraph para) {
    for (final WmlSection section in document.sections) {
      for (int i = 0; i < section.blocks.length; i++) {
        final WmlBlock block = section.blocks[i];
        if (identical(block, para)) {
          return (parent: section.blocks, index: i);
        }
        if (block is WmlToc && WordToc.ownsParagraph(block, para)) {
          return (parent: section.blocks, index: i);
        }
        if (block is WmlTable) {
          final ({List<WmlBlock> parent, int index})? nested =
              _tableSlotOf(block, para);
          if (nested != null) {
            return nested;
          }
        }
      }
    }
    return null;
  }

  ({List<WmlBlock> parent, int index})? _tableSlotOf(
    WmlTable table,
    WmlParagraph para,
  ) {
    for (final WmlTableRow row in table.rows) {
      for (final WmlTableCell cell in row.cells) {
        final int index = cell.blocks.indexOf(para);
        if (index >= 0) {
          return (parent: cell.blocks, index: index);
        }
        for (final WmlBlock block in cell.blocks) {
          if (block is WmlTable) {
            final ({List<WmlBlock> parent, int index})? nested =
                _tableSlotOf(block, para);
            if (nested != null) {
              return nested;
            }
          }
        }
      }
    }
    return null;
  }

  ({List<WmlBlock> parent, int index})? _topLevelInsertSlot() {
    final WmlParagraph para = _activeParagraph;
    for (final WmlSection section in document.sections) {
      for (int i = 0; i < section.blocks.length; i++) {
        final WmlBlock block = section.blocks[i];
        if (identical(block, para)) {
          return (parent: section.blocks, index: i);
        }
        if (block is WmlToc && WordToc.ownsParagraph(block, para)) {
          return (parent: section.blocks, index: i);
        }
        if (block is WmlTable && _tableContainsParagraph(block, para)) {
          return (parent: section.blocks, index: i);
        }
        if (block is WmlFrame && _frameContainsParagraph(block, para)) {
          return (parent: section.blocks, index: i);
        }
      }
    }
    return null;
  }

  static bool _frameContainsParagraph(WmlFrame frame, WmlParagraph para) {
    for (final WmlBlock block in frame.blocks) {
      if (identical(block, para)) {
        return true;
      }
      if (block is WmlTable && _tableContainsParagraph(block, para)) {
        return true;
      }
      if (block is WmlFrame && _frameContainsParagraph(block, para)) {
        return true;
      }
    }
    return false;
  }

  static bool _tableContainsParagraph(WmlTable table, WmlParagraph para) {
    for (final WmlTableRow row in table.rows) {
      for (final WmlTableCell cell in row.cells) {
        for (final WmlBlock block in cell.blocks) {
          if (identical(block, para)) {
            return true;
          }
          if (block is WmlTable && _tableContainsParagraph(block, para)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _revealParagraph(int index) {
    const double pointsToPixels = 96 / 72;
    final double scale = viewport.scale * pointsToPixels;
    for (final LaidOutPage page in laidOut.pages) {
      for (final LaidOutLine line in page.lines) {
        if (line.paragraphIndex != index) {
          continue;
        }
        final double top =
            laidOut.pageStackTop(page.index, scale) + line.y * scale;
        final double nextY = top - 48;
        viewport.origin = Offset(viewport.origin.dx, nextY < 0 ? 0 : nextY);
        return;
      }
    }
  }

  /// Re-lays out then applies the same Flutter metrics used on screen.
  void fitPaintMetrics({String? themeFamily}) {
    relayout();
    _fitLaidOut(
      documentLaidOut,
      document.paragraphs.toList(),
      themeFamily,
    );
    if (commentLaidOut != null && selectedComment != null) {
      _fitLaidOut(
        commentLaidOut!,
        selectedComment!.paragraphs,
        themeFamily,
      );
    }
  }

  void _fitLaidOut(
    LaidOutDocument laid,
    List<WmlParagraph> paras,
    String? themeFamily,
  ) {
    void fit(LaidOutLine line) {
      final String text = line.sourceText ??
          (paras.isEmpty
              ? ''
              : paras[line.paragraphIndex.clamp(0, paras.length - 1)].text);
      PaintRunText.fitLine(line, text, themeFamily: themeFamily);
    }

    for (final LaidOutPage page in laid.pages) {
      for (final LaidOutLine line in page.lines) {
        fit(line);
      }
      for (final LaidOutLine line in page.header) {
        fit(line);
      }
      for (final LaidOutLine line in page.footer) {
        fit(line);
      }
    }
  }

  void attachInput() {
    if (!config.allowsMutation) {
      return;
    }
    _writeImeValue();
    if (!input.isAttached) {
      input.attach(multiline: true);
    }
  }

  @override
  void detachInput() {
    input.detach();
  }

  void moveCaret(int delta, {bool extend = false}) {
    if (!config.allowsSelection) {
      return;
    }
    if (selectedVisual != null && !extend) {
      _leaveSelectedVisual(forward: delta > 0);
      return;
    }
    final List<WmlParagraph> paras = _paragraphs;
    if (paras.isEmpty) {
      return;
    }
    if (!extend && _selectNeighborVisual(delta, requireEdge: true)) {
      return;
    }
    var remaining = delta;
    while (remaining != 0) {
      caret.paragraphIndex = caret.paragraphIndex.clamp(0, paras.length - 1);
      final String text = paras[caret.paragraphIndex].text;
      if (remaining > 0) {
        final int room = text.length - caret.logicalIndex;
        if (remaining <= room) {
          caret.logicalIndex += remaining;
          remaining = 0;
        } else if (caret.paragraphIndex >= paras.length - 1) {
          caret.logicalIndex = text.length;
          remaining = 0;
        } else {
          remaining -= room + 1;
          caret.paragraphIndex++;
          caret.logicalIndex = 0;
        }
      } else if (caret.logicalIndex + remaining >= 0) {
        caret.logicalIndex += remaining;
        remaining = 0;
      } else if (caret.paragraphIndex <= 0) {
        caret.logicalIndex = 0;
        remaining = 0;
      } else {
        remaining += caret.logicalIndex + 1;
        caret.paragraphIndex--;
        caret.logicalIndex = paras[caret.paragraphIndex].text.length;
      }
    }
    if (!extend) {
      caret.collapseSelection();
    }
    caret.resetBlink();
    selectedVisual = null;
    _stickyCaretX = null;
    _syncImeSelection();
    notifyListeners();
  }

  /// Moves the caret one visual step (physical left/right), not logical UTF-16.
  void moveCaretVisual({required bool toRight, bool extend = false}) {
    if (!config.allowsSelection) {
      return;
    }
    if (selectedEquation != null) {
      moveEquationArrow(dx: toRight ? 1 : -1, dy: 0);
      return;
    }
    _stickyCaretX = null;
    if (selectedVisual != null && !extend) {
      _leaveSelectedVisual(forward: toRight);
      return;
    }
    final List<LaidOutLine> lines = _contentLines();
    final int index = _lineIndexOfCaret(lines);
    if (index < 0) {
      moveCaret(toRight ? 1 : -1, extend: extend);
      return;
    }
    if (!extend &&
        _selectNeighborVisual(toRight ? 1 : -1, requireEdge: true)) {
      return;
    }
    final LaidOutLine line = lines[index];
    if (line.glyphs.isEmpty) {
      _crossLaidOutLine(lines, index, toRight: toRight, extend: extend);
      return;
    }
    final double caretX = _caretXOnLine(line);
    LaidOutGlyph? next;
    var best = toRight ? double.infinity : -double.infinity;
    for (final LaidOutGlyph glyph in line.glyphs) {
      final double edge = glyph.glyph.level.isOdd
          ? glyph.x + glyph.advance
          : glyph.x;
      if (toRight && edge > caretX + 0.6 && edge < best) {
        best = edge;
        next = glyph;
      } else if (!toRight && edge < caretX - 0.6 && edge > best) {
        best = edge;
        next = glyph;
      }
    }
    if (next != null) {
      caret.paragraphIndex = line.paragraphIndex;
      caret.logicalIndex = next.glyph.logicalIndex;
    } else {
      final int end = _lineLogicalEnd(line);
      if (toRight && caret.logicalIndex < end) {
        caret.paragraphIndex = line.paragraphIndex;
        caret.logicalIndex = end;
      } else if (!toRight && caret.logicalIndex > _lineLogicalStart(line)) {
        caret.paragraphIndex = line.paragraphIndex;
        caret.logicalIndex = _lineLogicalStart(line);
      } else {
        _crossLaidOutLine(lines, index, toRight: toRight, extend: extend);
        return;
      }
    }
    if (!extend) {
      caret.collapseSelection();
    }
    caret.resetBlink();
    selectedVisual = null;
    _syncImeSelection();
    notifyListeners();
  }

  /// Moves the caret to the previous or next laid-out line.
  void moveCaretLine(int delta, {bool extend = false}) {
    if (!config.allowsSelection || delta == 0) {
      return;
    }
    if (selectedEquation != null) {
      moveEquationArrow(dx: 0, dy: delta);
      return;
    }
    if (selectedVisual != null && !extend) {
      _leaveSelectedVisual(forward: delta > 0);
      return;
    }
    final List<LaidOutLine> lines = _contentLines();
    final int index = _lineIndexOfCaret(lines);
    if (index < 0) {
      moveParagraph(delta, extend: extend);
      return;
    }
    final int nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= lines.length) {
      return;
    }
    final LaidOutLine current = lines[index];
    final LaidOutLine next = lines[nextIndex];
    if (!extend) {
      final WmlVisual? between = _visualBetweenLines(current, next);
      if (between != null) {
        selectedVisual = between;
        notifyListeners();
        return;
      }
    }
    final double x = _stickyCaretX ?? _caretXOnLine(current);
    _stickyCaretX = x;
    caret.paragraphIndex = next.paragraphIndex;
    caret.logicalIndex = _logicalAtX(next, x);
    if (!extend) {
      caret.collapseSelection();
    }
    caret.resetBlink();
    selectedVisual = null;
    _syncImeSelection();
    notifyListeners();
  }

  void moveParagraph(int delta, {bool extend = false}) {
    if (!config.allowsSelection) {
      return;
    }
    if (selectedVisual != null && !extend) {
      _leaveSelectedVisual(forward: delta > 0);
      return;
    }
    final List<WmlParagraph> paras = _paragraphs;
    if (paras.isEmpty) {
      return;
    }
    if (!extend && _selectNeighborVisual(delta, requireEdge: false)) {
      return;
    }
    selectedVisual = null;
    caret.paragraphIndex = (caret.paragraphIndex + delta).clamp(
      0,
      paras.length - 1,
    );
    caret.logicalIndex = caret.logicalIndex.clamp(
      0,
      paras[caret.paragraphIndex].text.length,
    );
    if (!extend) {
      caret.collapseSelection();
    }
    caret.resetBlink();
    _stickyCaretX = null;
    attachInput();
    notifyListeners();
  }

  void selectAll() {
    if (!config.allowsSelection) {
      return;
    }
    final List<WmlParagraph> paras = _paragraphs;
    if (paras.isEmpty) {
      return;
    }
    selectedVisual = null;
    caret
      ..selectionAnchorParagraph = 0
      ..selectionAnchor = 0
      ..paragraphIndex = paras.length - 1
      ..logicalIndex = paras.last.text.length;
    caret.resetBlink();
    _syncImeSelection();
    notifyListeners();
  }

  void selectWordAtCaret() {
    if (!config.allowsSelection) {
      return;
    }
    caret.selectWord(_activeParagraph.text, caret.logicalIndex);
    _syncImeSelection();
    notifyListeners();
  }

  void selectParagraphAtCaret() {
    if (!config.allowsSelection) {
      return;
    }
    caret.selectParagraph(_activeParagraph.text);
    _syncImeSelection();
    notifyListeners();
  }

  ({WmlTable table, int row, int col})? get tableAtCaret {
    if (isEditingComment || isEditingHeaderFooter) {
      return null;
    }
    return WordTable.locationOfIndex(document, caret.paragraphIndex);
  }

  bool get isInTable => tableAtCaret != null;

  ({WmlTable table, int r0, int g0, int r1, int g1})? get tableCellRange {
    if (isEditingComment) {
      return null;
    }
    if (caret.isCollapsed) {
      final ({WmlTable table, int row, int col})? loc = tableAtCaret;
      if (loc == null) {
        return null;
      }
      final ({int r0, int g0, int r1, int g1})? rect = WordTable.gridRect(
        loc.table,
        loc.row,
        loc.col,
        loc.row,
        loc.col,
      );
      if (rect == null) {
        return null;
      }
      return (
        table: loc.table,
        r0: rect.r0,
        g0: rect.g0,
        r1: rect.r1,
        g1: rect.g1,
      );
    }
    final ({int startPara, int startIdx, int endPara, int endIdx}) range =
        caret.normalizedRange;
    final ({WmlTable table, int row, int col})? a =
        WordTable.locationOfIndex(document, range.startPara);
    final ({WmlTable table, int row, int col})? b =
        WordTable.locationOfIndex(document, range.endPara);
    if (a == null || b == null || !identical(a.table, b.table)) {
      return null;
    }
    final ({int r0, int g0, int r1, int g1})? rect = WordTable.gridRect(
      a.table,
      a.row,
      a.col,
      b.row,
      b.col,
    );
    if (rect == null) {
      return null;
    }
    return (
      table: a.table,
      r0: rect.r0,
      g0: rect.g0,
      r1: rect.r1,
      g1: rect.g1,
    );
  }

  bool get canMergeTableCells {
    final ({WmlTable table, int r0, int g0, int r1, int g1})? range =
        tableCellRange;
    return range != null &&
        WordTable.canMerge(range.table, range.r0, range.g0, range.r1, range.g1);
  }

  bool get canUnmergeTableCells {
    final ({WmlTable table, int row, int col})? loc = tableAtCaret;
    return loc != null && WordTable.canUnmerge(loc.table, loc.row, loc.col);
  }

  void mergeTableCells() {
    final ({WmlTable table, int r0, int g0, int r1, int g1})? range =
        tableCellRange;
    if (range == null || !config.allowsMutation) {
      return;
    }
    _mutateWordTable(
      range.table,
      () => WordTable.merge(range.table, range.r0, range.g0, range.r1, range.g1),
      (WmlTable table) {
        final int col =
            WordTable.cellIndexAtGrid(table.rows[range.r0], range.g0) ?? 0;
        _placeCaretInTable(table, range.r0, col);
        selectedTable = null;
      },
    );
  }

  void unmergeTableCells() {
    final ({WmlTable table, int row, int col})? loc = tableAtCaret;
    if (loc == null || !config.allowsMutation) {
      return;
    }
    _mutateWordTable(
      loc.table,
      () => WordTable.unmerge(loc.table, loc.row, loc.col),
      (WmlTable table) {
        _placeCaretInTable(table, loc.row, loc.col);
        selectedTable = null;
      },
    );
  }

  WmlTable? _tableResizeSnap;

  void beginTableResize(WmlTable table) {
    _tableResizeSnap = WordTable.snapshot(table);
  }

  void previewTableColumnWidth(WmlTable table, int col, double width) {
    if (!config.allowsMutation) {
      return;
    }
    while (table.grid.length <= col) {
      table.grid.add(120);
    }
    table.grid[col] = width.clamp(24, 900);
    for (final WmlTableRow row in table.rows) {
      final int? i = WordTable.cellIndexAtGrid(row, col);
      if (i != null && WordTable.spanOf(row.cells[i]) == 1) {
        row.cells[i].width = table.grid[col];
      }
    }
    relayout();
    notifyListeners();
  }

  void previewTableRowHeight(WmlTable table, int row, double height) {
    if (!config.allowsMutation || row < 0 || row >= table.rows.length) {
      return;
    }
    table.rows[row].height = height.clamp(16, 480);
    relayout();
    notifyListeners();
  }

  void commitTableResize(WmlTable table) {
    final WmlTable? snap = _tableResizeSnap;
    _tableResizeSnap = null;
    if (snap == null || !config.allowsMutation) {
      return;
    }
    final WmlTable now = WordTable.snapshot(table);
    commands.commit(
      _CallbackCommand(
        executeFn: () => WordTable.restore(table, now),
        undoFn: () => WordTable.restore(table, snap),
      ),
    );
    relayout();
    notifyListeners();
  }

  void insertTableRow({
    required bool after,
    WmlTable? table,
    int? row,
  }) {
    final ({WmlTable table, int row, int col})? loc =
        table != null && row != null
            ? (table: table, row: row, col: 0)
            : tableAtCaret;
    if (loc == null) {
      return;
    }
    insertTableRowAt(loc.table, after ? loc.row + 1 : loc.row);
  }

  void insertTableRowAt(WmlTable table, int index) {
    _mutateWordTable(table, () => WordTable.insertRow(table, index), (WmlTable t) {
      _placeCaretInTable(t, index.clamp(0, t.rows.length - 1), 0);
    });
  }

  void insertTableColumn({
    required bool after,
    WmlTable? table,
    int? col,
  }) {
    final ({WmlTable table, int row, int col})? loc =
        table != null && col != null
            ? (table: table, row: 0, col: col)
            : tableAtCaret;
    if (loc == null) {
      return;
    }
    insertTableColumnAt(loc.table, after ? loc.col + 1 : loc.col);
  }

  void insertTableColumnAt(WmlTable table, int index) {
    _mutateWordTable(
      table,
      () {
        WordTable.insertColumn(table, index);
        WordTable.constrainToWidth(table, _tableContentWidth);
      },
      (WmlTable t) {
        final ({WmlTable table, int row, int col})? loc = tableAtCaret;
        _placeCaretInTable(
          t,
          loc?.row ?? 0,
          index.clamp(0, WordTable.columnCount(t) - 1),
        );
      },
    );
  }

  double get _tableContentWidth {
    if (document.sections.isEmpty) {
      return 451;
    }
    return document.sections.first.contentWidth;
  }

  WmlTable? selectedTable;
  ({WmlTable table, bool column, int from, int to})? selectedTableBand;

  void selectTable(WmlTable? table) {
    selectedTable = table;
    selectedTableBand = null;
    if (table != null) {
      selectedVisual = null;
      selectedEquation = null;
      _selectTableRange(table);
    }
    notifyListeners();
  }

  void autoFitTable(
    WordTableAutoFit mode, {
    WmlTable? table,
  }) {
    final WmlTable? target = table ?? selectedTable ?? tableAtCaret?.table;
    if (target == null) {
      return;
    }
    _mutateWordTable(
      target,
      () => WordTable.autoFit(target, mode, contentWidth: _tableContentWidth),
      (_) {},
    );
  }

  void deleteTable({WmlTable? table}) {
    final WmlTable? target = table ?? selectedTable ?? tableAtCaret?.table;
    if (target == null || !config.allowsMutation) {
      return;
    }
    final List<WmlBlock>? parent = _parentBlocksOfBlock(target);
    if (parent == null) {
      return;
    }
    final int at = parent.indexOf(target);
    if (at < 0) {
      return;
    }
    final List<WmlBlock> host = parent;
    final WmlTable snap = WordTable.snapshot(target);
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          host.remove(target);
          selectedTable = null;
          _ensureBodyHasParagraph();
        },
        undoFn: () {
          if (!host.contains(target)) {
            host.insert(at.clamp(0, host.length), target);
            WordTable.restore(target, snap);
          }
        },
      ),
    );
    _placeCaretAfterBlockRemoval(host, at);
    fitPaintMetrics(themeFamily: config.theme.fontFamily);
    _syncImeSelection();
    notifyListeners();
  }

  void _placeCaretAfterBlockRemoval(List<WmlBlock> host, int wasAt) {
    WmlParagraph? findPara(WmlBlock block) {
      final List<WmlParagraph> owned = WmlClone.paragraphsOf(block);
      return owned.isEmpty ? null : owned.first;
    }

    WmlParagraph? para;
    var atStart = true;
    if (wasAt < host.length) {
      para = findPara(host[wasAt]);
    }
    if (para == null && wasAt > 0) {
      final List<WmlParagraph> owned = WmlClone.paragraphsOf(host[wasAt - 1]);
      if (owned.isNotEmpty) {
        para = owned.last;
        atStart = false;
      }
    }
    final List<WmlParagraph> paras = document.paragraphs.toList();
    if (para == null) {
      if (paras.isEmpty) {
        caret.paragraphIndex = 0;
        caret.logicalIndex = 0;
        caret.collapseSelection();
        return;
      }
      para = paras.first;
    }
    final int index = paras.indexOf(para);
    caret.paragraphIndex = index < 0 ? 0 : index;
    caret.logicalIndex = atStart ? 0 : para.text.length;
    caret.collapseSelection();
  }

  void _selectTableRange(WmlTable table) {
    WmlParagraph? first;
    WmlParagraph? last;
    void walk(List<WmlBlock> blocks) {
      for (final WmlBlock block in blocks) {
        if (block is WmlParagraph) {
          first ??= block;
          last = block;
        } else if (block is WmlTable) {
          for (final WmlTableRow row in block.rows) {
            for (final WmlTableCell cell in row.cells) {
              walk(cell.blocks);
            }
          }
        }
      }
    }

    for (final WmlTableRow row in table.rows) {
      for (final WmlTableCell cell in row.cells) {
        walk(cell.blocks);
      }
    }
    if (first == null || last == null) {
      return;
    }
    final List<WmlParagraph> paras = document.paragraphs.toList();
    final int start = paras.indexOf(first!);
    final int end = paras.indexOf(last!);
    if (start < 0 || end < 0) {
      return;
    }
    caret
      ..selectionAnchorParagraph = start
      ..selectionAnchor = 0
      ..paragraphIndex = end
      ..logicalIndex = last!.text.length;
  }

  void selectTableBand(
    WmlTable table, {
    required bool column,
    required int from,
    required int to,
  }) {
    if (!config.allowsSelection) {
      return;
    }
    final int a = from < to ? from : to;
    final int b = from > to ? from : to;
    WmlParagraph? first;
    WmlParagraph? last;
    void take(WmlTableCell cell) {
      void walk(List<WmlBlock> blocks) {
        for (final WmlBlock block in blocks) {
          if (block is WmlParagraph) {
            first ??= block;
            last = block;
          } else if (block is WmlTable) {
            for (final WmlTableRow nestedRow in block.rows) {
              for (final WmlTableCell nested in nestedRow.cells) {
                walk(nested.blocks);
              }
            }
          }
        }
      }

      walk(cell.blocks);
    }

    if (column) {
      for (final WmlTableRow row in table.rows) {
        var grid = 0;
        for (final WmlTableCell cell in row.cells) {
          final int span = WordTable.spanOf(cell);
          if (grid <= b && grid + span - 1 >= a) {
            take(cell);
          }
          grid += span;
        }
      }
    } else {
      for (int r = a; r <= b && r < table.rows.length; r++) {
        for (final WmlTableCell cell in table.rows[r].cells) {
          take(cell);
        }
      }
    }
    if (first == null || last == null) {
      return;
    }
    final List<WmlParagraph> paras = document.paragraphs.toList();
    final int start = paras.indexOf(first!);
    final int end = paras.indexOf(last!);
    if (start < 0 || end < 0) {
      return;
    }
    selectedTable = null;
    selectedTableBand = (table: table, column: column, from: a, to: b);
    selectedVisual = null;
    selectedEquation = null;
    caret
      ..selectionAnchorParagraph = start
      ..selectionAnchor = 0
      ..paragraphIndex = end
      ..logicalIndex = last!.text.length;
    notifyListeners();
  }

  void deleteTableRow({WmlTable? table, int? row}) {
    final ({WmlTable table, int row, int col})? loc =
        table != null && row != null
            ? (table: table, row: row, col: 0)
            : tableAtCaret;
    if (loc == null || loc.table.rows.length <= 1) {
      return;
    }
    _mutateWordTable(
      loc.table,
      () => WordTable.deleteRow(loc.table, loc.row),
      (WmlTable t) {
        _placeCaretInTable(
          t,
          loc.row.clamp(0, t.rows.length - 1),
          loc.col,
        );
      },
    );
  }

  void deleteTableColumn({WmlTable? table, int? col}) {
    final ({WmlTable table, int row, int col})? loc =
        table != null && col != null
            ? (table: table, row: 0, col: col)
            : tableAtCaret;
    if (loc == null || WordTable.columnCount(loc.table) <= 1) {
      return;
    }
    _mutateWordTable(
      loc.table,
      () => WordTable.deleteColumn(loc.table, loc.col),
      (WmlTable t) {
        _placeCaretInTable(
          t,
          loc.row,
          loc.col.clamp(0, WordTable.columnCount(t) - 1),
        );
      },
    );
  }

  void _mutateWordTable(
    WmlTable table,
    void Function() mutate,
    void Function(WmlTable table) place,
  ) {
    if (!config.allowsMutation) {
      return;
    }
    final WmlTable snap = WordTable.snapshot(table);
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          mutate();
          place(table);
        },
        undoFn: () {
          WordTable.restore(table, snap);
        },
      ),
    );
    fitPaintMetrics(themeFamily: config.theme.fontFamily);
    _syncImeSelection();
    notifyListeners();
  }

  /// Moves the caret to the next (`forward`) or previous table cell.
  ///
  /// Traverses left-to-right within a row, then the next row. At the last
  /// cell, inserts a new row when mutation is allowed. Returns `false` when
  /// the caret is not inside a table.
  bool moveTableCell({required bool forward}) {
    final ({WmlTable table, int row, int col})? loc = tableAtCaret;
    if (loc == null) {
      return false;
    }
    final ({int row, int col})? next = _stepTableCell(
      loc.table,
      loc.row,
      loc.col,
      forward ? 1 : -1,
    );
    if (next == null) {
      if (forward && config.allowsMutation) {
        insertTableRowAt(loc.table, loc.table.rows.length);
        return true;
      }
      return true;
    }
    _placeCaretInTable(loc.table, next.row, next.col);
    selectedTable = null;
    selectedTableBand = null;
    notifyListeners();
    return true;
  }

  static ({int row, int col})? _stepTableCell(
    WmlTable table,
    int row,
    int col,
    int direction,
  ) {
    var r = row;
    var c = col;
    while (true) {
      c += direction;
      if (r < 0 || r >= table.rows.length) {
        return null;
      }
      if (c >= table.rows[r].cells.length) {
        r++;
        c = 0;
        if (r >= table.rows.length) {
          return null;
        }
      } else if (c < 0) {
        r--;
        if (r < 0) {
          return null;
        }
        c = table.rows[r].cells.length - 1;
      }
      if (table.rows[r].cells[c].vMerge != WmlVMerge.cont) {
        return (row: r, col: c);
      }
    }
  }

  void _placeCaretInTable(WmlTable table, int row, int col) {
    if (table.rows.isEmpty) {
      return;
    }
    final int r = row.clamp(0, table.rows.length - 1);
    final List<WmlTableCell> cells = table.rows[r].cells;
    if (cells.isEmpty) {
      return;
    }
    final int c = col.clamp(0, cells.length - 1);
    WmlParagraph? paragraph;
    for (final WmlBlock block in cells[c].blocks) {
      if (block is WmlParagraph) {
        paragraph = block;
        break;
      }
    }
    if (paragraph == null) {
      return;
    }
    final List<WmlParagraph> paras = document.paragraphs.toList();
    final int index = paras.indexOf(paragraph);
    if (index < 0) {
      return;
    }
    caret.paragraphIndex = index;
    caret.logicalIndex = 0;
    caret.collapseSelection();
  }

  @override
  bool get canCopy =>
      selectedVisual != null || selectedTable != null || !caret.isCollapsed;

  @override
  Future<void> copyToClipboard() async {
    final OfficeClipboardPayload payload = _captureWordClipboard();
    if (payload.isEmpty) {
      return;
    }
    await OfficeClipboard.instance.write(payload);
  }

  @override
  Future<void> cutToClipboard() async {
    if (!canCut) {
      return;
    }
    await copyToClipboard();
    if (selectedVisual != null) {
      deleteSelectedVisual();
      return;
    }
    deleteSelectionOr(backward: true);
  }

  @override
  Future<void> pasteFromClipboard({
    OfficePasteMode mode = OfficePasteMode.keepSource,
  }) async {
    if (!canPaste) {
      return;
    }
    final OfficeClipboardPayload payload = await OfficeClipboard.instance.read();
    if (payload.isEmpty) {
      return;
    }
    if (payload.visual != null && selectedVisual == null && caret.isCollapsed) {
      _pasteWordVisual(payload.visual!);
      return;
    }
    if (mode == OfficePasteMode.keepSource && payload.hasWordBlocks) {
      _pasteWordBlocks(payload.wordBlocks);
      return;
    }
    if (mode == OfficePasteMode.keepSource && payload.hasRichText) {
      _pasteWordRich(payload.paragraphs);
      return;
    }
    _pasteWordPlain(payload.plain);
  }

  OfficeClipboardPayload _captureWordClipboard() {
    final WmlVisual? visual = selectedVisual;
    if (visual != null) {
      return OfficeClipboardPayload(
        kind: OfficeClipboardKind.visual,
        plain: visual.visual.title,
        visual: visual.visual.copy(),
      );
    }
    if (selectedTable != null) {
      final WmlTable clone = WmlClone.table(selectedTable!);
      return OfficeClipboardPayload(
        kind: OfficeClipboardKind.richText,
        plain: WmlClone.plainTextOf(<WmlBlock>[clone]),
        wordBlocks: <WmlBlock>[clone],
        paragraphs: _spansFromBlocks(<WmlBlock>[clone]),
      );
    }
    if (caret.isCollapsed) {
      return OfficeClipboardPayload.empty();
    }
    final List<WmlBlock> fragment = _captureWordFragment();
    if (fragment.isEmpty) {
      return OfficeClipboardPayload.empty();
    }
    return OfficeClipboardPayload(
      kind: OfficeClipboardKind.richText,
      plain: WmlClone.plainTextOf(fragment),
      wordBlocks: fragment,
      paragraphs: _spansFromBlocks(fragment),
    );
  }

  List<List<OfficeClipboardSpan>> _spansFromBlocks(List<WmlBlock> blocks) {
    return <List<OfficeClipboardSpan>>[
      for (final WmlBlock block in blocks)
        for (final WmlParagraph para in WmlClone.paragraphsOf(block))
          <OfficeClipboardSpan>[
            for (final WmlInline inline in para.inlines)
              if (inline is WmlRun)
                OfficeClipboardSpan(
                  text: inline.text,
                  props: inline.properties.copy(),
                ),
          ],
    ];
  }

  List<WmlBlock> _captureWordFragment() {
    if (isEditingComment) {
      return _captureSlicedCommentParagraphs();
    }
    if (_isEntireDocumentSelected()) {
      return <WmlBlock>[
        for (final WmlSection section in document.sections)
          for (final WmlBlock block in section.blocks) WmlClone.block(block),
      ];
    }
    return _captureStructuredFragment();
  }

  List<WmlBlock> _captureSlicedCommentParagraphs() {
    final List<WmlParagraph> paras = _paragraphs;
    final (:int startPara, :int startIdx, :int endPara, :int endIdx) =
        caret.normalizedRange;
    if (startPara < 0 || endPara >= paras.length) {
      return <WmlBlock>[];
    }
    return <WmlBlock>[
      for (int p = startPara; p <= endPara; p++)
        WmlClone.slicedParagraph(
          paras[p],
          p == startPara ? startIdx : 0,
          p == endPara ? endIdx : paras[p].text.length,
        ),
    ];
  }

  List<WmlBlock> _captureStructuredFragment() {
    final List<WmlParagraph> paras = document.paragraphs.toList();
    final (:int startPara, :int startIdx, :int endPara, :int endIdx) =
        caret.normalizedRange;
    if (startPara < 0 || endPara >= paras.length) {
      return <WmlBlock>[];
    }
    final List<WmlBlock> out = <WmlBlock>[];
    for (final WmlSection section in document.sections) {
      for (final WmlBlock block in section.blocks) {
        switch (_coverageOf(block, paras, startPara, startIdx, endPara, endIdx)) {
          case _WordBlockCover.none:
            break;
          case _WordBlockCover.full:
            out.add(WmlClone.block(block));
          case _WordBlockCover.partial:
            if (block is WmlParagraph) {
              final int index = paras.indexOf(block);
              out.add(
                WmlClone.slicedParagraph(
                  block,
                  index == startPara ? startIdx : 0,
                  index == endPara ? endIdx : block.text.length,
                ),
              );
            } else if (block is WmlTable) {
              if (_selectionInsideTableOnly(block, startPara, endPara, paras)) {
                out.addAll(
                  _slicedParagraphsInRange(paras, startPara, startIdx, endPara, endIdx),
                );
              } else {
                out.add(WmlClone.table(block));
              }
            } else if (block is WmlToc) {
              out.add(WmlClone.toc(block));
            }
        }
      }
    }
    return out;
  }

  List<WmlBlock> _slicedParagraphsInRange(
    List<WmlParagraph> paras,
    int startPara,
    int startIdx,
    int endPara,
    int endIdx,
  ) {
    return <WmlBlock>[
      for (int p = startPara; p <= endPara; p++)
        WmlClone.slicedParagraph(
          paras[p],
          p == startPara ? startIdx : 0,
          p == endPara ? endIdx : paras[p].text.length,
        ),
    ];
  }

  bool _selectionInsideTableOnly(
    WmlTable table,
    int startPara,
    int endPara,
    List<WmlParagraph> paras,
  ) {
    for (int p = startPara; p <= endPara; p++) {
      final ({WmlTable table, int row, int col})? loc =
          WordTable.locationOfParagraph(document, paras[p]);
      if (loc == null || !identical(loc.table, table)) {
        return false;
      }
    }
    return true;
  }

  _WordBlockCover _coverageOf(
    WmlBlock block,
    List<WmlParagraph> paras,
    int startPara,
    int startIdx,
    int endPara,
    int endIdx,
  ) {
    if (block is WmlVisual || block is WmlEquation) {
      return _isObjectBetweenParagraphs(block, startPara, endPara)
          ? _WordBlockCover.full
          : _WordBlockCover.none;
    }
    final List<WmlParagraph> owned = WmlClone.paragraphsOf(block);
    if (owned.isEmpty) {
      return _WordBlockCover.none;
    }
    final int first = paras.indexOf(owned.first);
    final int last = paras.indexOf(owned.last);
    if (first < 0 || last < 0 || last < startPara || first > endPara) {
      return _WordBlockCover.none;
    }
    final bool fromStart =
        startPara < first || (startPara == first && startIdx <= 0);
    final bool toEnd =
        endPara > last || (endPara == last && endIdx >= owned.last.text.length);
    if (fromStart && toEnd) {
      return _WordBlockCover.full;
    }
    return _WordBlockCover.partial;
  }

  bool _isEntireDocumentSelected() {
    if (isEditingComment) {
      return false;
    }
    final List<WmlParagraph> paras = document.paragraphs.toList();
    if (paras.isEmpty || caret.isCollapsed) {
      return false;
    }
    final (:int startPara, :int startIdx, :int endPara, :int endIdx) =
        caret.normalizedRange;
    return startPara == 0 &&
        startIdx <= 0 &&
        endPara == paras.length - 1 &&
        endIdx >= paras.last.text.length;
  }

  bool _isObjectBetweenParagraphs(WmlBlock block, int startPara, int endPara) {
    if (endPara <= startPara) {
      return false;
    }
    final int? after = _paragraphIndexBeforeBlock(block);
    if (after == null) {
      return false;
    }
    return after >= startPara && after < endPara;
  }

  int? _paragraphIndexBeforeBlock(WmlBlock block) {
    final List<WmlBlock>? parent = _parentBlocksOfBlock(block);
    if (parent == null) {
      return null;
    }
    final int index = parent.indexOf(block);
    final List<WmlParagraph> paras = document.paragraphs.toList();
    for (int i = index - 1; i >= 0; i--) {
      final List<WmlParagraph> owned = WmlClone.paragraphsOf(parent[i]);
      if (owned.isEmpty) {
        continue;
      }
      final int at = paras.indexOf(owned.last);
      return at >= 0 ? at : null;
    }
    return -1;
  }

  void _pasteWordPlain(String text) {
    final List<String> lines = OfficeClipboardPayload.splitPlainLines(text);
    if (lines.isEmpty) {
      return;
    }
    commands.beginBatch();
    if (!caret.isCollapsed) {
      _deleteNormalizedSelection();
    }
    for (int i = 0; i < lines.length; i++) {
      if (i > 0) {
        _splitActiveParagraph();
      }
      if (lines[i].isNotEmpty) {
        final WmlParagraph para = _activeParagraph;
        final int start = caret.logicalIndex.clamp(0, para.text.length);
        commands.commit(
          InsertTextDelta(
            getText: () => para.text,
            setText: (String v) => _setParagraphText(para, v),
            index: start,
            text: lines[i],
          ),
        );
        caret.logicalIndex = start + lines[i].length;
        caret.collapseSelection();
      }
    }
    commands.endBatch();
    relayout();
    _markLocalEdit();
    _syncImeSelection();
    notifyListeners();
  }

  void _pasteWordRich(List<List<OfficeClipboardSpan>> paragraphs) {
    if (paragraphs.isEmpty) {
      return;
    }
    commands.beginBatch();
    if (!caret.isCollapsed) {
      _deleteNormalizedSelection();
    }
    for (int i = 0; i < paragraphs.length; i++) {
      if (i > 0) {
        _splitActiveParagraph();
      }
      _insertSpansAtCaret(paragraphs[i]);
    }
    commands.endBatch();
    relayout();
    _markLocalEdit();
    _syncImeSelection();
    notifyListeners();
  }

  void _pasteWordBlocks(List<WmlBlock> blocks) {
    if (blocks.isEmpty) {
      return;
    }
    commands.beginBatch();
    if (!caret.isCollapsed) {
      _deleteNormalizedSelection();
    }
    final List<WmlBlock> clones = <WmlBlock>[
      for (final WmlBlock block in blocks) WmlClone.block(block),
    ];
    if (isEditingComment) {
      for (int i = 0; i < clones.length; i++) {
        if (i > 0) {
          _splitActiveParagraph();
        }
        final WmlBlock block = clones[i];
        if (block is WmlParagraph) {
          _insertSpansAtCaret(_spansOfParagraph(block));
        }
      }
    } else if (_wordBodyIsBlank()) {
      _replaceBodyWith(clones);
    } else {
      _insertWordBlocksAtCaret(clones);
    }
    commands.endBatch();
    fitPaintMetrics(themeFamily: config.theme.fontFamily);
    _markLocalEdit();
    _syncImeSelection();
    notifyListeners();
  }

  List<OfficeClipboardSpan> _spansOfParagraph(WmlParagraph para) {
    return <OfficeClipboardSpan>[
      for (final WmlInline inline in para.inlines)
        if (inline is WmlRun)
          OfficeClipboardSpan(text: inline.text, props: inline.properties.copy()),
    ];
  }

  bool _wordBodyIsBlank() {
    for (final WmlSection section in document.sections) {
      for (final WmlBlock block in section.blocks) {
        if (block is WmlParagraph) {
          if (block.text.isNotEmpty) {
            return false;
          }
        } else {
          return false;
        }
      }
    }
    return true;
  }

  void _replaceBodyWith(List<WmlBlock> blocks) {
    final List<({WmlSection section, List<WmlBlock> blocks})> before =
        <({WmlSection section, List<WmlBlock> blocks})>[
      for (final WmlSection section in document.sections)
        (section: section, blocks: List<WmlBlock>.from(section.blocks)),
    ];
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          for (final WmlSection section in document.sections) {
            section.blocks.clear();
          }
          final List<WmlBlock> host = document.sections.first.blocks;
          if (blocks.isEmpty) {
            host.add(WmlParagraph(inlines: <WmlInline>[WmlRun()]));
          } else {
            host.addAll(blocks);
          }
          selectedTable = null;
          selectedVisual = null;
          selectedEquation = null;
        },
        undoFn: () {
          for (final ({WmlSection section, List<WmlBlock> blocks}) snap
              in before) {
            snap.section.blocks
              ..clear()
              ..addAll(snap.blocks);
          }
        },
      ),
    );
    _placeCaretAtEndOf(blocks);
  }

  void _insertWordBlocksAtCaret(List<WmlBlock> blocks) {
    if (blocks.isEmpty) {
      return;
    }
    final WmlParagraph dest = _activeParagraph;
    final bool destEmpty = dest.text.isEmpty;
    final WmlParagraphProps destProps = dest.properties.copy();
    final WmlBlock first = blocks.first;
    if (first is WmlParagraph) {
      _insertSpansAtCaret(_spansOfParagraph(first));
      if (destEmpty) {
        commands.commit(
          _CallbackCommand(
            executeFn: () {
              dest.properties = first.properties.copy();
            },
            undoFn: () {
              dest.properties = destProps;
            },
          ),
        );
      }
      if (blocks.length == 1) {
        return;
      }
      _insertBlocksAfterCurrent(blocks.sublist(1));
      return;
    }
    _insertBlocksAfterCurrent(blocks);
  }

  void _insertBlocksAfterCurrent(List<WmlBlock> blocks) {
    final ({List<WmlBlock> parent, int index})? slot = _topLevelInsertSlot();
    final List<WmlBlock> parent =
        slot?.parent ?? document.sections.first.blocks;
    final int at = slot == null ? parent.length : slot.index + 1;
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          for (int i = 0; i < blocks.length; i++) {
            parent.insert((at + i).clamp(0, parent.length), blocks[i]);
          }
        },
        undoFn: () {
          for (final WmlBlock block in blocks) {
            parent.remove(block);
          }
        },
      ),
    );
    _placeCaretAtEndOf(blocks);
  }

  void _placeCaretAtEndOf(List<WmlBlock> blocks) {
    WmlParagraph? last;
    for (final WmlBlock block in blocks) {
      final List<WmlParagraph> owned = WmlClone.paragraphsOf(block);
      if (owned.isNotEmpty) {
        last = owned.last;
      }
    }
    if (last == null) {
      caret.collapseSelection();
      return;
    }
    final List<WmlParagraph> paras = document.paragraphs.toList();
    final int index = paras.indexOf(last);
    if (index < 0) {
      return;
    }
    caret.paragraphIndex = index;
    caret.logicalIndex = last.text.length;
    caret.collapseSelection();
  }

  void _insertSpansAtCaret(List<OfficeClipboardSpan> spans) {
    if (spans.isEmpty) {
      return;
    }
    final WmlParagraph para = _activeParagraph;
    final int start = caret.logicalIndex.clamp(0, para.text.length);
    final List<WmlInline> before = _cloneInlines(para);
    final List<WmlRun> runs = <WmlRun>[
      for (final OfficeClipboardSpan span in spans) span.toRun(),
    ];
    final int added = runs.fold<int>(0, (int n, WmlRun r) => n + r.text.length);
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          para.inlines
            ..clear()
            ..addAll(_cloneInlinesFrom(before));
          WmlRunEdit.insertRuns(para, start, runs);
        },
        undoFn: () {
          para.inlines
            ..clear()
            ..addAll(_cloneInlinesFrom(before));
        },
      ),
    );
    caret.logicalIndex = start + added;
    caret.collapseSelection();
  }

  void _splitActiveParagraph() {
    final WmlParagraph para = _activeParagraph;
    final int index = caret.logicalIndex.clamp(0, para.text.length);
    final List<WmlInline> before = _cloneInlines(para);
    final List<WmlRun> tail = WmlRunEdit.extractRuns(
      para,
      index,
      para.text.length,
    );
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          para.inlines
            ..clear()
            ..addAll(_cloneInlinesFrom(before));
          if (index < para.text.length) {
            WmlRunEdit.replaceRange(para, index, para.text.length, '');
          }
          final WmlParagraph next = WmlParagraph(
            properties: para.properties,
            inlines: tail.isEmpty
                ? <WmlInline>[WmlRun()]
                : <WmlInline>[
                    for (final WmlRun run in tail)
                      WmlRun(
                        text: run.text,
                        properties: run.properties.copy(),
                      ),
                  ],
          );
          _insertParagraphAfter(para, next);
        },
        undoFn: () {
          _removeParagraphAfter(para);
          para.inlines
            ..clear()
            ..addAll(_cloneInlinesFrom(before));
        },
      ),
    );
    caret.paragraphIndex++;
    caret.logicalIndex = 0;
    caret.collapseSelection();
  }

  void _pasteWordVisual(OfficeVisual visual) {
    final WmlParagraph para = _activeParagraph;
    final ({List<WmlBlock> parent, int index})? slot = _hostSlotOf(para);
    if (slot == null) {
      return;
    }
    final List<WmlBlock> parent = slot.parent;
    final int index = slot.index;
    final WmlVisual block = WmlVisual(visual: visual.copy());
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          parent.insert((index + 1).clamp(0, parent.length), block);
          selectedVisual = block;
        },
        undoFn: () {
          parent.remove(block);
          if (identical(selectedVisual, block)) {
            selectedVisual = null;
          }
        },
      ),
    );
    relayout();
    notifyListeners();
  }

  /// Applies character formatting to the current selection only.
  void applyRunFormat(void Function(WmlRunProps props) update) {
    if (!config.allowsMutation) {
      return;
    }
    final List<WmlParagraph> paras = _paragraphs;
    if (paras.isEmpty) {
      return;
    }
    final int startPara;
    final int startIdx;
    final int endPara;
    final int endIdx;
    if (caret.isCollapsed) {
      final WmlParagraph para = _activeParagraph;
      final ({int start, int end}) span = _runSpanAt(para, caret.logicalIndex);
      startPara = caret.paragraphIndex.clamp(0, paras.length - 1);
      endPara = startPara;
      startIdx = span.start;
      endIdx = span.end;
    } else {
      final ({
        int startPara,
        int startIdx,
        int endPara,
        int endIdx,
      }) range = caret.normalizedRange;
      startPara = range.startPara;
      startIdx = range.startIdx;
      endPara = range.endPara;
      endIdx = range.endIdx;
    }
    if (startPara < 0 || endPara >= paras.length) {
      return;
    }
    final Map<int, List<WmlInline>> before = <int, List<WmlInline>>{
      for (int p = startPara; p <= endPara; p++) p: _cloneInlines(paras[p]),
    };
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          for (int p = startPara; p <= endPara; p++) {
            final WmlParagraph para = paras[p];
            para.inlines
              ..clear()
              ..addAll(_cloneInlinesFrom(before[p]!));
            final int from = p == startPara ? startIdx : 0;
            final int to = p == endPara ? endIdx : para.text.length;
            WmlRunEdit.applyRange(para, from, to, update);
          }
        },
        undoFn: () {
          for (int p = startPara; p <= endPara; p++) {
            paras[p].inlines
              ..clear()
              ..addAll(_cloneInlinesFrom(before[p]!));
          }
        },
      ),
    );
    fitPaintMetrics(themeFamily: config.theme.fontFamily);
    _syncImeSelection();
    notifyListeners();
  }

  static ({int start, int end}) _runSpanAt(WmlParagraph para, int index) {
    final int length = para.text.length;
    if (length == 0) {
      return (start: 0, end: 0);
    }
    final int caret = index.clamp(0, length);
    var offset = 0;
    var lastStart = 0;
    var lastEnd = 0;
    for (final WmlInline inline in para.inlines) {
      if (inline is! WmlRun || inline.text.isEmpty) {
        continue;
      }
      final int end = offset + inline.text.length;
      if (caret < end) {
        return (start: offset, end: end);
      }
      lastStart = offset;
      lastEnd = end;
      offset = end;
    }
    return (start: lastStart, end: lastEnd == 0 ? length : lastEnd);
  }

  WmlRunProps get activeRunProps =>
      WmlRunEdit.propsAt(_activeParagraph, caret.logicalIndex);

  static List<WmlInline> _cloneInlines(WmlParagraph para) =>
      _cloneInlinesFrom(para.inlines);

  static List<WmlInline> _cloneInlinesFrom(List<WmlInline> source) {
    return <WmlInline>[
      for (final WmlInline inline in source)
        if (inline is WmlRun)
          WmlRun(
            text: inline.text,
            properties: inline.properties.copy(),
            hyperlink: inline.hyperlink,
            commentIds: List<int>.from(inline.commentIds),
          )
        else
          inline,
    ];
  }

  void insertText(String text) {
    if (!config.allowsMutation || text.isEmpty) {
      return;
    }
    if (selectedEquation != null) {
      insertEquationText(text);
      return;
    }
    if (selectedVisual != null) {
      return;
    }
    final String previous = _activeParagraph.text;
    commands.beginBatch();
    if (!caret.isCollapsed) {
      _deleteNormalizedSelection();
    }
    final WmlParagraph para = _activeParagraph;
    final int start = caret.logicalIndex.clamp(0, para.text.length);
    commands.commit(
      InsertTextDelta(
        getText: () => para.text,
        setText: (String v) => _setParagraphText(para, v),
        index: start,
        text: text,
      ),
    );
    commands.endBatch();
    caret.logicalIndex = start + text.length;
    caret.collapseSelection();
    relayout();
    _markLocalEdit(previousText: previous);
    _syncImeSelection();
    notifyListeners();
  }

  void deleteSelectionOr({required bool backward}) {
    if (!config.allowsMutation) {
      return;
    }
    if (selectedVisual != null) {
      deleteSelectedVisual();
      return;
    }
    if (selectedTable != null) {
      deleteTable(table: selectedTable);
      return;
    }
    if (selectedEquation != null) {
      deleteEquationContent(backward: backward);
      return;
    }
    final String previous = _activeParagraph.text;
    if (!caret.isCollapsed) {
      commands.beginBatch();
      _deleteNormalizedSelection();
      commands.endBatch();
      caret.collapseSelection();
      relayout();
      _markLocalEdit(previousText: previous);
      _syncImeSelection();
      notifyListeners();
      return;
    }
    final String text = _activeParagraph.text;
    final int index = caret.logicalIndex.clamp(0, text.length);
    final int start;
    final int end;
    if (backward) {
      if (index <= 0) {
        if (_joinAdjacentParagraph(backward: true)) {
          _markLocalEdit(previousText: previous);
          _syncImeSelection();
          notifyListeners();
        }
        return;
      }
      start = _clusterStartBefore(text, index);
      end = index;
    } else {
      if (index >= text.length) {
        if (_joinAdjacentParagraph(backward: false)) {
          _markLocalEdit(previousText: previous);
          _syncImeSelection();
          notifyListeners();
        }
        return;
      }
      start = index;
      end = _clusterEndAfter(text, index);
    }
    if (end <= start) {
      return;
    }
    commands.commit(
      DeleteTextDelta(
        getText: () => _activeParagraph.text,
        setText: (String v) => _setParagraphText(_activeParagraph, v),
        index: start,
        length: end - start,
      ),
    );
    caret.logicalIndex = start;
    caret.collapseSelection();
    relayout();
    _markLocalEdit(previousText: previous);
    _syncImeSelection();
    notifyListeners();
  }

  void _deleteNormalizedSelection() {
    if (isEditingComment) {
      _deleteNormalizedTextOnly();
      return;
    }
    if (_isEntireDocumentSelected()) {
      _replaceDocumentWithEmptyParagraph();
      return;
    }
    final List<WmlParagraph> paras = document.paragraphs.toList();
    final (:int startPara, :int startIdx, :int endPara, :int endIdx) =
        caret.normalizedRange;
    if (startPara < 0 || endPara >= paras.length) {
      return;
    }
    if (startPara == endPara) {
      _deleteNormalizedTextOnly();
      return;
    }
    _deleteStructuredSelection(paras, startPara, startIdx, endPara, endIdx);
  }

  void _deleteNormalizedTextOnly() {
    final List<WmlParagraph> paras = _paragraphs;
    final (:int startPara, :int startIdx, :int endPara, :int endIdx) =
        caret.normalizedRange;
    if (startPara < 0 || endPara >= paras.length) {
      return;
    }
    for (int p = endPara; p >= startPara; p--) {
      final WmlParagraph para = paras[p];
      final int from = p == startPara ? startIdx : 0;
      final int to = p == endPara ? endIdx : para.text.length;
      if (to > from) {
        commands.commit(
          DeleteTextDelta(
            getText: () => para.text,
            setText: (String v) => _setParagraphText(para, v),
            index: from,
            length: to - from,
          ),
        );
      }
    }
    _deleteVisualsInSelection(startPara, endPara);
    caret.paragraphIndex = startPara;
    caret.logicalIndex = startIdx.clamp(0, paras[startPara].text.length);
  }

  void _replaceDocumentWithEmptyParagraph() {
    final List<({WmlSection section, List<WmlBlock> blocks})> before =
        <({WmlSection section, List<WmlBlock> blocks})>[
      for (final WmlSection section in document.sections)
        (section: section, blocks: List<WmlBlock>.from(section.blocks)),
    ];
    final WmlParagraph empty = WmlParagraph(inlines: <WmlInline>[WmlRun()]);
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          for (final WmlSection section in document.sections) {
            section.blocks.clear();
          }
          document.sections.first.blocks.add(empty);
          selectedTable = null;
          selectedVisual = null;
          selectedEquation = null;
          caret.paragraphIndex = 0;
          caret.logicalIndex = 0;
        },
        undoFn: () {
          for (final ({WmlSection section, List<WmlBlock> blocks}) snap
              in before) {
            snap.section.blocks
              ..clear()
              ..addAll(snap.blocks);
          }
        },
      ),
    );
    caret.paragraphIndex = 0;
    caret.logicalIndex = 0;
  }

  void _deleteStructuredSelection(
    List<WmlParagraph> paras,
    int startPara,
    int startIdx,
    int endPara,
    int endIdx,
  ) {
    final WmlParagraph startIdentity = paras[startPara];
    final List<({WmlSection section, List<WmlBlock> blocks})> sectionSnaps =
        <({WmlSection section, List<WmlBlock> blocks})>[
      for (final WmlSection section in document.sections)
        (section: section, blocks: List<WmlBlock>.from(section.blocks)),
    ];
    final Map<WmlParagraph, List<WmlInline>> inlineSnaps =
        <WmlParagraph, List<WmlInline>>{
      for (int p = startPara; p <= endPara; p++)
        paras[p]: _cloneInlines(paras[p]),
    };
    final List<WmlBlock> remove = <WmlBlock>[];
    for (final WmlSection section in document.sections) {
      for (final WmlBlock block in section.blocks) {
        if (_coverageOf(block, paras, startPara, startIdx, endPara, endIdx) ==
            _WordBlockCover.full) {
          remove.add(block);
        }
      }
    }
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          for (final WmlBlock block in remove) {
            final List<WmlBlock>? parent = _parentBlocksOfBlock(block);
            parent?.remove(block);
          }
          final List<WmlParagraph> live = document.paragraphs.toList();
          for (int p = startPara; p <= endPara; p++) {
            final WmlParagraph para = paras[p];
            if (!live.contains(para)) {
              continue;
            }
            final int from = p == startPara ? startIdx : 0;
            final int to = p == endPara ? endIdx : para.text.length;
            if (to > from) {
              WmlRunEdit.replaceRange(para, from, to, '');
            }
          }
          _ensureBodyHasParagraph();
          selectedTable = null;
          selectedVisual = null;
          selectedEquation = null;
        },
        undoFn: () {
          for (final ({WmlSection section, List<WmlBlock> blocks}) snap
              in sectionSnaps) {
            snap.section.blocks
              ..clear()
              ..addAll(snap.blocks);
          }
          inlineSnaps.forEach((WmlParagraph para, List<WmlInline> inlines) {
            para.inlines
              ..clear()
              ..addAll(_cloneInlinesFrom(inlines));
          });
        },
      ),
    );
    final List<WmlParagraph> after = document.paragraphs.toList();
    final int stay = after.indexOf(startIdentity);
    if (stay >= 0) {
      caret.paragraphIndex = stay;
      caret.logicalIndex = startIdx.clamp(0, startIdentity.text.length);
    } else if (after.isNotEmpty) {
      caret.paragraphIndex = 0;
      caret.logicalIndex = 0;
    }
  }

  void _ensureBodyHasParagraph() {
    for (final WmlSection section in document.sections) {
      if (section.blocks.isNotEmpty) {
        return;
      }
    }
    document.sections.first.blocks.add(
      WmlParagraph(inlines: <WmlInline>[WmlRun()]),
    );
  }

  void _deleteVisualsInSelection(int startPara, int endPara) {
    if (isEditingComment || endPara <= startPara) {
      return;
    }
    final List<WmlVisual> remove = <WmlVisual>[
      for (final WmlVisual visual in visuals)
        if (_isVisualBetweenParagraphs(visual, startPara, endPara)) visual,
    ];
    for (final WmlVisual visual in remove) {
      final List<WmlBlock>? parent = _parentBlocksOfVisual(visual);
      if (parent == null) {
        continue;
      }
      final int index = parent.indexOf(visual);
      commands.commit(
        _CallbackCommand(
          executeFn: () => parent.remove(visual),
          undoFn: () {
            if (!parent.contains(visual)) {
              parent.insert(index.clamp(0, parent.length), visual);
            }
          },
        ),
      );
    }
  }

  void insertParagraphBreak() {
    if (!config.allowsMutation) {
      return;
    }
    if (selectedVisual != null) {
      cycleSelectedVisualKind();
      return;
    }
    if (selectedEquation != null) {
      moveEquationSlot(1);
      return;
    }
    final WmlParagraph para = _activeParagraph;
    final String text = para.text;
    final int i = caret.logicalIndex.clamp(0, text.length);
    final String head = text.substring(0, i);
    final String tail = text.substring(i);
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          _setParagraphText(para, head);
          final WmlParagraph next = WmlParagraph(
            properties: para.properties,
            inlines: <WmlInline>[WmlRun(text: tail)],
          );
          _insertParagraphAfter(para, next);
        },
        undoFn: () {
          _setParagraphText(para, text);
          _removeParagraphAfter(para);
        },
      ),
    );
    caret.paragraphIndex++;
    caret.logicalIndex = 0;
    caret.collapseSelection();
    relayout();
    _markLocalEdit(previousText: text);
    attachInput();
    notifyListeners();
  }

  void _onImeSelector(String selector) {
    if (!config.allowsSelection) {
      return;
    }
    final String name = selector.endsWith(':')
        ? selector.substring(0, selector.length - 1)
        : selector;
    switch (name) {
      case 'moveLeft':
        moveCaretVisual(toRight: false);
      case 'moveRight':
        moveCaretVisual(toRight: true);
      case 'moveUp':
        moveCaretLine(-1);
      case 'moveDown':
        moveCaretLine(1);
      case 'moveBackward':
        moveCaret(-1);
      case 'moveForward':
        moveCaret(1);
      case 'moveLeftAndModifySelection':
        moveCaretVisual(toRight: false, extend: true);
      case 'moveRightAndModifySelection':
        moveCaretVisual(toRight: true, extend: true);
      case 'moveUpAndModifySelection':
        moveCaretLine(-1, extend: true);
      case 'moveDownAndModifySelection':
        moveCaretLine(1, extend: true);
      case 'moveWordLeft':
      case 'moveWordBackward':
        moveCaret(-1);
      case 'moveWordRight':
      case 'moveWordForward':
        moveCaret(1);
      case 'moveToLeftEndOfLine':
      case 'moveToBeginningOfLine':
        moveCaretVisual(toRight: false);
      case 'moveToRightEndOfLine':
      case 'moveToEndOfLine':
        moveCaretVisual(toRight: true);
      case 'selectAll':
        selectAll();
      default:
        break;
    }
    if (!config.allowsMutation) {
      return;
    }
    switch (name) {
      case 'deleteBackward':
        deleteSelectionOr(backward: true);
      case 'deleteForward':
        deleteSelectionOr(backward: false);
      case 'insertNewline':
        insertParagraphBreak();
      case 'undo':
        undo();
      case 'redo':
        redo();
      case 'copy':
        copyToClipboard();
      case 'cut':
        cutToClipboard();
      case 'paste':
        pasteFromClipboard();
      default:
        break;
    }
  }

  @override
  void beforeHistoryChange() {
    _textBeforeLocalEdit = _activeParagraph.text;
  }

  @override
  void afterHistoryChange() {
    relayout();
    caret.logicalIndex = caret.logicalIndex.clamp(
      0,
      _activeParagraph.text.length,
    );
    caret.collapseSelection();
    _markLocalEdit(previousText: _textBeforeLocalEdit);
    _syncImeSelection();
    notifyListeners();
  }

  void _markLocalEdit({String? previousText}) {
    _localEditAt = DateTime.now();
    _textBeforeLocalEdit = previousText ?? _textBeforeLocalEdit;
  }

  bool _isImeEcho(String incoming) {
    return DateTime.now().difference(_localEditAt) <
            const Duration(milliseconds: 200) &&
        incoming == _textBeforeLocalEdit;
  }

  static int _clusterStartBefore(String text, int index) {
    final List<GraphemeCluster> clusters = GraphemeClusters.segment(text);
    for (int i = clusters.length - 1; i >= 0; i--) {
      if (clusters[i].start < index) {
        return clusters[i].start;
      }
    }
    return 0;
  }

  static int _clusterEndAfter(String text, int index) {
    for (final GraphemeCluster cluster in GraphemeClusters.segment(text)) {
      if (cluster.end > index) {
        return cluster.end;
      }
    }
    return text.length;
  }

  void _onIme(TextEditingValue value) {
    if (_applyingIme ||
        !config.allowsMutation ||
        selectedVisual != null ||
        selectedTable != null ||
        _isImeEcho(value.text)) {
      return;
    }
    if (selectedEquation != null) {
      _onEquationIme(value);
      return;
    }
    final WmlParagraph para = _activeParagraph;
    final String old = para.text;
    if (value.text != old) {
      _applyingIme = true;
      commands.commit(
        _CallbackCommand(
          executeFn: () => _setParagraphText(para, value.text),
          undoFn: () => _setParagraphText(para, old),
        ),
      );
      _applyingIme = false;
      relayout();
      caret.logicalIndex = value.selection.extentOffset.clamp(
        0,
        value.text.length,
      );
      caret.selectionAnchor = value.selection.baseOffset.clamp(
        0,
        value.text.length,
      );
      caret.selectionAnchorParagraph = caret.paragraphIndex;
    } else if (caret.selectionAnchorParagraph == caret.paragraphIndex) {
      caret.logicalIndex = value.selection.extentOffset.clamp(
        0,
        value.text.length,
      );
      caret.selectionAnchor = value.selection.baseOffset.clamp(
        0,
        value.text.length,
      );
      caret.selectionAnchorParagraph = caret.paragraphIndex;
    }
    caret.resetBlink();
    notifyListeners();
  }

  void _onImeAction(TextInputAction action) {
    if (action == TextInputAction.newline || action == TextInputAction.done) {
      insertParagraphBreak();
    }
  }

  void _syncImeSelection() {
    if (!input.isAttached) {
      return;
    }
    _writeImeValue();
  }

  String equationEditingText() {
    final WmlEquation? equation = selectedEquation;
    if (equation == null) {
      return '';
    }
    if (equation.math.view == OmmlView.linear) {
      return equation.math.linearText.isEmpty
          ? OmmlLinear.write(equation.math.root)
          : equation.math.linearText;
    }
    return OmmlEdit.cellPlain(
      equation.math.root,
      OmmlEdit.slotAt(equation.math.root, equationSlot),
    );
  }

  int _equationCellLength() {
    return equationEditingText().length;
  }

  void _clampEquationCaret() {
    equationCaret = equationCaret.clamp(0, _equationCellLength());
  }

  void _onEquationIme(TextEditingValue value) {
    final String old = equationEditingText();
    if (value.text == old) {
      return;
    }
    final String paragraph = _activeParagraph.text;
    if (value.text == paragraph ||
        (paragraph.isNotEmpty &&
            value.text.startsWith(paragraph) &&
            !old.startsWith(paragraph))) {
      _writeImeValue();
      return;
    }
    final int oldCaret = equationCaret.clamp(0, old.length);
    if (value.text.length > old.length &&
        oldCaret <= old.length &&
        value.text.startsWith(old.substring(0, oldCaret)) &&
        value.text.endsWith(old.substring(oldCaret))) {
      final String inserted = value.text.substring(
        oldCaret,
        value.text.length - (old.length - oldCaret),
      );
      insertEquationText(inserted);
      return;
    }
    if (value.text.length == old.length - 1 &&
        oldCaret > 0 &&
        value.text ==
            old.substring(0, oldCaret - 1) + old.substring(oldCaret)) {
      deleteEquationContent(backward: true);
      return;
    }
    if (value.text.startsWith(old)) {
      insertEquationText(value.text.substring(old.length));
      return;
    }
    if (old.startsWith(value.text) && value.text.length == old.length - 1) {
      deleteEquationContent(backward: true);
      return;
    }
    _setEquationSlotText(value.text);
  }

  void _setEquationSlotText(String text) {
    _mutateEquation((OmmlEquation math) {
      if (math.view == OmmlView.linear) {
        math.linearText = text;
        return;
      }
      final OmmlSeq slot = OmmlEdit.slotAt(math.root, equationSlot);
      slot.children
        ..clear()
        ..addAll(OmmlLinear.parse(text).children);
    });
    equationCaret = text.length;
    _clampEquationCaret();
  }

  @visibleForTesting
  void applyImeText(String text) {
    _onIme(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
  }

  void _writeImeValue() {
    if (selectedEquation != null) {
      final String text = equationEditingText();
      _applyingIme = true;
      input.setValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(
            offset: equationCaret.clamp(0, text.length),
          ),
        ),
      );
      _applyingIme = false;
      return;
    }
    final String text = _activeParagraph.text;
    final bool samePara =
        caret.selectionAnchorParagraph == caret.paragraphIndex;
    _applyingIme = true;
    input.setValue(
      TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: (samePara ? caret.selectionAnchor : caret.logicalIndex)
              .clamp(0, text.length),
          extentOffset: caret.logicalIndex.clamp(0, text.length),
        ),
      ),
    );
    _applyingIme = false;
  }

  void _setParagraphText(WmlParagraph para, String text) {
    final String old = para.text;
    if (old == text) {
      return;
    }
    var prefix = 0;
    while (prefix < old.length &&
        prefix < text.length &&
        old.codeUnitAt(prefix) == text.codeUnitAt(prefix)) {
      prefix++;
    }
    var oldEnd = old.length;
    var newEnd = text.length;
    while (oldEnd > prefix &&
        newEnd > prefix &&
        old.codeUnitAt(oldEnd - 1) == text.codeUnitAt(newEnd - 1)) {
      oldEnd--;
      newEnd--;
    }
    WmlRunEdit.replaceRange(
      para,
      prefix,
      oldEnd,
      text.substring(prefix, newEnd),
    );
  }

  bool _joinCommentParagraph({
    required WmlParagraph keep,
    required WmlParagraph drop,
    required int dropAt,
    required int caretAfter,
    required int caretPara,
  }) {
    final List<WmlParagraph> parent = selectedComment!.paragraphs;
    if (dropAt < 0) {
      return false;
    }
    final List<WmlInline> keepInlines = _cloneInlines(keep);
    final List<WmlInline> dropInlines = _cloneInlines(drop);
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          keep.inlines
            ..clear()
            ..addAll(_cloneInlinesFrom(keepInlines));
          for (final WmlInline inline in dropInlines) {
            if (inline is WmlRun && inline.text.isEmpty) {
              continue;
            }
            keep.inlines.add(
              inline is WmlRun
                  ? WmlRun(
                      text: inline.text,
                      properties: inline.properties.copy(),
                    )
                  : inline,
            );
          }
          WmlRunEdit.coalesce(keep);
          parent.remove(drop);
        },
        undoFn: () {
          keep.inlines
            ..clear()
            ..addAll(_cloneInlinesFrom(keepInlines));
          drop.inlines
            ..clear()
            ..addAll(_cloneInlinesFrom(dropInlines));
          if (!parent.contains(drop)) {
            parent.insert(dropAt.clamp(0, parent.length), drop);
          }
        },
      ),
    );
    caret.paragraphIndex = caretPara.clamp(0, parent.length - 1);
    caret.logicalIndex = caretAfter.clamp(0, keep.text.length);
    caret.collapseSelection();
    relayout();
    return true;
  }

  /// Joins the caret paragraph with the previous (Backspace) or next (Delete).
  ///
  /// Returns `true` when the document or caret changed.
  bool _joinAdjacentParagraph({required bool backward}) {
    final List<WmlParagraph> paras = _paragraphs;
    if (paras.length < 2) {
      return false;
    }
    final int currentIndex = caret.paragraphIndex.clamp(0, paras.length - 1);
    final int otherIndex = backward ? currentIndex - 1 : currentIndex + 1;
    if (otherIndex < 0 || otherIndex >= paras.length) {
      return false;
    }
    final WmlParagraph keep = backward
        ? paras[otherIndex]
        : paras[currentIndex];
    final WmlParagraph drop = backward
        ? paras[currentIndex]
        : paras[otherIndex];
    if (isEditingComment) {
      return _joinCommentParagraph(
        keep: keep,
        drop: drop,
        dropAt: selectedComment!.paragraphs.indexOf(drop),
        caretAfter: backward ? keep.text.length : caret.logicalIndex,
        caretPara: backward ? otherIndex : currentIndex,
      );
    }
    final List<WmlBlock>? parent = _parentBlocksOf(drop);
    if (parent == null) {
      return false;
    }
    final int dropAt = parent.indexOf(drop);
    final bool canMerge = dropAt > 0 && identical(parent[dropAt - 1], keep);
    if (!canMerge) {
      if (_deleteObjectBetweenParagraphs(keep, drop, backward: backward)) {
        return true;
      }
      if (drop.text.isEmpty && parent.length > 1 && dropAt >= 0) {
        commands.commit(
          _CallbackCommand(
            executeFn: () => parent.remove(drop),
            undoFn: () {
              if (!parent.contains(drop)) {
                parent.insert(dropAt.clamp(0, parent.length), drop);
              }
            },
          ),
        );
      }
      caret.paragraphIndex = backward ? otherIndex : currentIndex;
      caret.logicalIndex = backward ? keep.text.length : caret.logicalIndex;
      caret.collapseSelection();
      relayout();
      return true;
    }
    final int join = keep.text.length;
    final List<WmlInline> keepInlines = _cloneInlines(keep);
    final List<WmlInline> dropInlines = _cloneInlines(drop);
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          keep.inlines
            ..clear()
            ..addAll(_cloneInlinesFrom(keepInlines));
          for (final WmlInline inline in dropInlines) {
            if (inline is WmlRun && inline.text.isEmpty) {
              continue;
            }
            keep.inlines.add(
              inline is WmlRun
                  ? WmlRun(
                      text: inline.text,
                      properties: inline.properties.copy(),
                    )
                  : inline,
            );
          }
          WmlRunEdit.coalesce(keep);
          parent.remove(drop);
        },
        undoFn: () {
          keep.inlines
            ..clear()
            ..addAll(_cloneInlinesFrom(keepInlines));
          drop.inlines
            ..clear()
            ..addAll(_cloneInlinesFrom(dropInlines));
          if (!parent.contains(drop)) {
            parent.insert(dropAt.clamp(0, parent.length), drop);
          }
        },
      ),
    );
    caret.paragraphIndex = backward ? otherIndex : currentIndex;
    caret.logicalIndex = join;
    caret.collapseSelection();
    relayout();
    return true;
  }

  bool _deleteObjectBetweenParagraphs(
    WmlParagraph keep,
    WmlParagraph drop, {
    required bool backward,
  }) {
    final List<WmlBlock>? keepParent = _parentBlocksOfBlock(keep);
    final List<WmlBlock>? dropParent = _parentBlocksOfBlock(drop);
    if (keepParent != null &&
        dropParent != null &&
        identical(keepParent, dropParent)) {
      final int keepAt = keepParent.indexOf(keep);
      final int dropAt = dropParent.indexOf(drop);
      if (keepAt >= 0 && dropAt >= 0) {
        final int lo = keepAt < dropAt ? keepAt : dropAt;
        final int hi = keepAt < dropAt ? dropAt : keepAt;
        for (int i = lo + 1; i < hi; i++) {
          final WmlBlock block = keepParent[i];
          if (block is WmlTable ||
              block is WmlVisual ||
              block is WmlEquation ||
              block is WmlToc) {
            _deleteDocumentBlock(block);
            return true;
          }
        }
      }
    }
    final ({WmlTable table, int row, int col})? keepLoc =
        WordTable.locationOfParagraph(document, keep);
    final ({WmlTable table, int row, int col})? dropLoc =
        WordTable.locationOfParagraph(document, drop);
    if (keepLoc != null && dropLoc == null && backward) {
      deleteTable(table: keepLoc.table);
      return true;
    }
    if (keepLoc == null && dropLoc != null && !backward) {
      deleteTable(table: dropLoc.table);
      return true;
    }
    return false;
  }

  void _deleteDocumentBlock(WmlBlock block) {
    if (block is WmlTable) {
      deleteTable(table: block);
      return;
    }
    if (block is WmlVisual) {
      selectedVisual = block;
      deleteSelectedVisual();
      return;
    }
    if (block is WmlEquation) {
      selectedEquation = block;
      deleteSelectedEquation();
      return;
    }
    final List<WmlBlock>? parent = _parentBlocksOfBlock(block);
    if (parent == null) {
      return;
    }
    final int at = parent.indexOf(block);
    if (at < 0) {
      return;
    }
    commands.commit(
      _CallbackCommand(
        executeFn: () => parent.remove(block),
        undoFn: () {
          if (!parent.contains(block)) {
            parent.insert(at.clamp(0, parent.length), block);
          }
        },
      ),
    );
    _placeCaretAfterBlockRemoval(parent, at);
    relayout();
  }

  void selectVisual(WmlVisual? visual) {
    if (!config.allowsSelection) {
      selectedVisual = null;
      selectedEquation = null;
      notifyListeners();
      return;
    }
    selectedVisual = visual;
    if (visual != null) {
      selectedEquation = null;
      caret.collapseSelection();
    } else {
      pictureCropMode = false;
    }
    notifyListeners();
  }

  void togglePictureCropMode() {
    if (selectedVisual == null || !selectedVisual!.visual.isPicture) {
      pictureCropMode = false;
      notifyListeners();
      return;
    }
    pictureCropMode = !pictureCropMode;
    notifyListeners();
  }

  void beginVisualTransform() {
    final OfficeVisual? visual = selectedVisual?.visual;
    if (visual == null) {
      return;
    }
    _visualSnap = (
      width: visual.width,
      height: visual.height,
      offsetX: visual.offsetX,
      offsetY: visual.offsetY,
      rotationDeg: visual.picture.rotationDeg,
      cropLeft: visual.picture.cropLeft,
      cropTop: visual.picture.cropTop,
      cropRight: visual.picture.cropRight,
      cropBottom: visual.picture.cropBottom,
    );
  }

  void previewVisualMove(double dx, [double dy = 0]) {
    final OfficeVisual? visual = selectedVisual?.visual;
    if (visual == null || !config.allowsMutation) {
      return;
    }
    visual.offsetX = (visual.offsetX + dx).clamp(-40, 720);
    visual.offsetY = (visual.offsetY + dy).clamp(-40, 900);
    relayout();
    notifyListeners();
  }

  WmlSection get sectionAtCaret {
    if (document.sections.isEmpty) {
      document.sections.add(WmlSection());
    }
    if (isEditingHeaderFooter) {
      return document.sections[_editingSectionIndex.clamp(
        0,
        document.sections.length - 1,
      )];
    }
    final List<WmlParagraph> paras = document.paragraphs.toList();
    if (paras.isEmpty) {
      return document.sections.first;
    }
    final int index = documentCaret.paragraphIndex.clamp(0, paras.length - 1);
    return document.sections[document.sectionIndexOf(paras[index])];
  }

  int get sectionIndexAtCaret {
    if (document.sections.isEmpty) {
      return 0;
    }
    if (isEditingHeaderFooter) {
      return _editingSectionIndex.clamp(0, document.sections.length - 1);
    }
    final List<WmlParagraph> paras = document.paragraphs.toList();
    if (paras.isEmpty) {
      return 0;
    }
    final int index = documentCaret.paragraphIndex.clamp(0, paras.length - 1);
    return document.sectionIndexOf(paras[index]);
  }

  int get sectionCount => document.sections.length;

  WmlSection sectionForPage(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < documentLaidOut.pages.length) {
      final int index = documentLaidOut.pages[pageIndex].sectionIndex;
      if (index >= 0 && index < document.sections.length) {
        return document.sections[index];
      }
    }
    return sectionAtCaret;
  }

  WmlSection get _pageSection => sectionAtCaret;

  void insertSectionBreak() {
    if (!config.allowsMutation || isEditingComment || isEditingHeaderFooter) {
      return;
    }
    final WmlSection current = sectionAtCaret;
    final ({List<WmlBlock> parent, int index})? slot = _topLevelInsertSlot();
    final int splitAt = slot != null && identical(slot.parent, current.blocks)
        ? slot.index + 1
        : current.blocks.length;
    final List<WmlBlock> moved = splitAt < current.blocks.length
        ? current.blocks.sublist(splitAt)
        : <WmlBlock>[];
    final WmlSection next = WmlSection(
      blocks: moved.isEmpty
          ? <WmlBlock>[WmlParagraph(inlines: <WmlInline>[WmlRun(text: '')])]
          : moved,
      pageSize: current.pageSize,
      margins: current.margins,
      columnCount: current.columnCount,
      columnSpace: current.columnSpace,
      columnSep: current.columnSep,
      header: <WmlParagraph>[
        for (final WmlParagraph para in current.header) WmlClone.paragraph(para),
      ],
      footer: <WmlParagraph>[
        for (final WmlParagraph para in current.footer) WmlClone.paragraph(para),
      ],
    );
    final int at = document.sections.indexOf(current) + 1;
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          if (moved.isNotEmpty) {
            current.blocks.removeRange(splitAt, current.blocks.length);
          }
          if (!document.sections.contains(next)) {
            document.sections.insert(
              at.clamp(0, document.sections.length),
              next,
            );
          }
        },
        undoFn: () {
          document.sections.remove(next);
          if (moved.isNotEmpty) {
            current.blocks.addAll(moved);
          }
        },
      ),
    );
    if (next.blocks.isNotEmpty && next.blocks.first is WmlParagraph) {
      final List<WmlParagraph> paras = document.paragraphs.toList();
      final int paraIndex = paras.indexOf(next.blocks.first as WmlParagraph);
      if (paraIndex >= 0) {
        documentCaret
          ..paragraphIndex = paraIndex
          ..logicalIndex = 0
          ..collapseSelection();
      }
    }
    relayout();
    notifyListeners();
  }

  WmlPageMargins get pageMargins => _pageSection.margins;

  WmlPageSize get pageSize => _pageSection.pageSize;

  bool get isPageLandscape => pageSize.isLandscape;

  int get pageCount => documentLaidOut.pages.length;

  int get visiblePageIndex {
    final double scale = viewport.scale * (96 / 72);
    final double viewH =
        viewport.extent.height > 0 ? viewport.extent.height : 1;
    return documentLaidOut.pageIndexAtContentY(
      viewport.origin.dy + viewH * 0.35,
      scale,
    );
  }

  void setPageMargins(WmlPageMargins margins) {
    if (!config.allowsMutation) {
      return;
    }
    final WmlSection section = _pageSection;
    final WmlPageMargins before = section.margins;
    commands.commit(
      _CallbackCommand(
        executeFn: () => section.margins = margins,
        undoFn: () => section.margins = before,
      ),
    );
    relayout();
    notifyListeners();
  }

  void setPageSize(WmlPageSize size) {
    if (!config.allowsMutation) {
      return;
    }
    final WmlSection section = _pageSection;
    final WmlPageSize before = section.pageSize;
    commands.commit(
      _CallbackCommand(
        executeFn: () => section.pageSize = size,
        undoFn: () => section.pageSize = before,
      ),
    );
    relayout();
    notifyListeners();
  }

  void setPageLandscape(bool landscape) {
    setPageSize(landscape ? pageSize.landscape : pageSize.portrait);
  }

  void applyParagraphFormat(void Function(WmlParagraphProps props) update) {
    if (!config.allowsMutation) {
      return;
    }
    final List<WmlParagraph> paras = _paragraphs;
    if (paras.isEmpty) {
      return;
    }
    final int start;
    final int end;
    if (caret.isCollapsed) {
      start = caret.paragraphIndex.clamp(0, paras.length - 1);
      end = start;
    } else {
      final ({int startPara, int startIdx, int endPara, int endIdx}) range =
          caret.normalizedRange;
      start = range.startPara.clamp(0, paras.length - 1);
      end = range.endPara.clamp(0, paras.length - 1);
    }
    final Map<int, WmlParagraphProps> before = <int, WmlParagraphProps>{
      for (int i = start; i <= end; i++) i: paras[i].properties.copy(),
    };
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          for (int i = start; i <= end; i++) {
            update(paras[i].properties);
          }
        },
        undoFn: () {
          for (final MapEntry<int, WmlParagraphProps> entry in before.entries) {
            paras[entry.key].properties = entry.value;
          }
        },
      ),
    );
    relayout();
    notifyListeners();
  }

  void setParagraphDirection({required bool rtl}) {
    applyParagraphFormat((WmlParagraphProps props) {
      props.rightToLeft = rtl;
      if (rtl) {
        if (props.justification == WmlJustification.left) {
          props.justification = WmlJustification.right;
        }
      } else if (props.justification == WmlJustification.right) {
        props.justification = WmlJustification.left;
      }
    });
  }

  void toggleList({required bool numbered}) {
    applyParagraphFormat((WmlParagraphProps props) {
      if (props.numId != null) {
        props
          ..numId = null
          ..listLabel = null
          ..ilvl = 0;
        return;
      }
      props
        ..numId = numbered ? 2 : 1
        ..ilvl = 0
        ..listLabel = numbered ? '1. ' : '• ';
    });
  }

  void setSectionColumns(int count, {double space = 36, bool sep = false}) {
    if (!config.allowsMutation) {
      return;
    }
    final WmlSection section = sectionAtCaret;
    final int before = section.columnCount;
    final double beforeSpace = section.columnSpace;
    final bool beforeSep = section.columnSep;
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          section.columnCount = count.clamp(1, 4);
          section.columnSpace = space;
          section.columnSep = sep;
        },
        undoFn: () {
          section.columnCount = before;
          section.columnSpace = beforeSpace;
          section.columnSep = beforeSep;
        },
      ),
    );
    relayout();
    notifyListeners();
  }

  void insertTextFrame({
    double x = 72,
    double y = 96,
    double width = 220,
    double height = 120,
    String? fillColor,
    String text = '',
  }) {
    if (!config.allowsMutation) {
      return;
    }
    final ({List<WmlBlock> parent, int index})? slot = _topLevelInsertSlot();
    final List<WmlBlock> parent = slot?.parent ?? document.sections.first.blocks;
    final int index = slot == null ? parent.length : slot.index + 1;
    final WmlFrame frame = WmlFrame(
      x: x,
      y: y,
      width: width,
      height: height,
      fillColor: fillColor,
      strokeColor: 'B0B0B0',
      blocks: <WmlBlock>[
        WmlParagraph(
          inlines: <WmlInline>[
            WmlRun(text: text.isEmpty ? 'Text box' : text),
          ],
        ),
      ],
    );
    commands.commit(
      _CallbackCommand(
        executeFn: () => parent.insert(index, frame),
        undoFn: () => parent.remove(frame),
      ),
    );
    relayout();
    notifyListeners();
  }

  void insertColumnBreak() {
    if (!config.allowsMutation) {
      return;
    }
    insertParagraphBreak();
    _activeParagraph.properties.columnBreakBefore = true;
    relayout();
    notifyListeners();
  }

  void previewVisualResize({required double width, required double height}) {
    final OfficeVisual? visual = selectedVisual?.visual;
    if (visual == null || !config.allowsMutation) {
      return;
    }
    visual.width = width.clamp(16, 2400);
    visual.height = height.clamp(16, 2400);
    relayout();
    notifyListeners();
  }

  void previewVisualRotate(double degrees) {
    final OfficeVisual? visual = selectedVisual?.visual;
    if (visual == null || !config.allowsMutation) {
      return;
    }
    visual.picture.rotationDeg = degrees % 360;
    notifyListeners();
  }

  void previewVisualCrop({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final OfficeVisual? visual = selectedVisual?.visual;
    if (visual == null || !config.allowsMutation) {
      return;
    }
    visual.picture
      ..cropLeft = left.clamp(0.0, 0.45)
      ..cropTop = top.clamp(0.0, 0.45)
      ..cropRight = right.clamp(0.0, 0.45)
      ..cropBottom = bottom.clamp(0.0, 0.45);
    notifyListeners();
  }

  void commitVisualTransform() {
    final OfficeVisual? visual = selectedVisual?.visual;
    final snap = _visualSnap;
    _visualSnap = null;
    if (visual == null || snap == null || !config.allowsMutation) {
      return;
    }
    final double width = visual.width;
    final double height = visual.height;
    final double offsetX = visual.offsetX;
    final double offsetY = visual.offsetY;
    final PictureAdjust crop = visual.picture.copy();
    if (width == snap.width &&
        height == snap.height &&
        offsetX == snap.offsetX &&
        offsetY == snap.offsetY &&
        crop.rotationDeg == snap.rotationDeg &&
        crop.cropLeft == snap.cropLeft &&
        crop.cropTop == snap.cropTop &&
        crop.cropRight == snap.cropRight &&
        crop.cropBottom == snap.cropBottom) {
      return;
    }
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          visual
            ..width = width
            ..height = height
            ..offsetX = offsetX
            ..offsetY = offsetY;
          visual.picture
            ..rotationDeg = crop.rotationDeg
            ..cropLeft = crop.cropLeft
            ..cropTop = crop.cropTop
            ..cropRight = crop.cropRight
            ..cropBottom = crop.cropBottom;
        },
        undoFn: () {
          visual
            ..width = snap.width
            ..height = snap.height
            ..offsetX = snap.offsetX
            ..offsetY = snap.offsetY;
          visual.picture
            ..rotationDeg = snap.rotationDeg
            ..cropLeft = snap.cropLeft
            ..cropTop = snap.cropTop
            ..cropRight = snap.cropRight
            ..cropBottom = snap.cropBottom;
        },
      ),
    );
    relayout();
    notifyListeners();
  }

  void nudgeSelectedVisual({
    double dx = 0,
    double dy = 0,
    bool resize = false,
    bool crop = false,
  }) {
    final OfficeVisual? visual = selectedVisual?.visual;
    if (visual == null || !config.allowsMutation) {
      return;
    }
    beginVisualTransform();
    if (crop) {
      previewVisualCrop(
        left: visual.picture.cropLeft + (dx < 0 ? 0.02 : (dx > 0 ? -0.02 : 0)),
        top: visual.picture.cropTop + (dy < 0 ? 0.02 : (dy > 0 ? -0.02 : 0)),
        right: visual.picture.cropRight + (dx > 0 ? 0.02 : 0),
        bottom: visual.picture.cropBottom + (dy > 0 ? 0.02 : 0),
      );
    } else if (resize) {
      previewVisualResize(
        width: visual.width + dx,
        height: visual.height + dy,
      );
    } else {
      previewVisualMove(dx, dy);
    }
    commitVisualTransform();
  }

  List<WmlEquation> get equations => document.equations.toList();

  void selectEquation(WmlEquation? equation, {int? slot, int? caret}) {
    if (!config.allowsSelection) {
      selectedEquation = null;
      notifyListeners();
      return;
    }
    selectedEquation = equation;
    if (equation != null) {
      selectedVisual = null;
      final int raw = slot ?? equationSlot;
      equationSlot = OmmlEdit.snapToCell(equation.math.root, raw);
      equationCaret = caret ?? equationCaret;
      _clampEquationCaret();
      _markLocalEdit(previousText: equationEditingText());
      attachInput();
      onRequestFocus?.call();
    } else {
      equationSlot = 0;
      equationCaret = 0;
    }
    notifyListeners();
  }

  void insertEquation(OmmlEquation math) {
    if (!config.allowsMutation) {
      return;
    }
    final WmlParagraph para = _activeParagraph;
    final ({List<WmlBlock> parent, int index})? slot = _hostSlotOf(para);
    if (slot == null) {
      return;
    }
    final List<WmlBlock> parent = slot.parent;
    final int index = slot.index;
    final WmlEquation block = WmlEquation(math: math.copy());
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          parent.insert((index + 1).clamp(0, parent.length), block);
          selectedVisual = null;
          selectedEquation = block;
          equationSlot = OmmlEdit.snapToCell(block.math.root, 0);
        },
        undoFn: () {
          parent.remove(block);
          if (identical(selectedEquation, block)) {
            selectedEquation = null;
          }
        },
      ),
    );
    relayout();
    attachInput();
    notifyListeners();
    onRequestFocus?.call();
  }

  void deleteSelectedEquation() {
    final WmlEquation? equation = selectedEquation;
    if (equation == null || !config.allowsMutation) {
      return;
    }
    final List<WmlBlock>? parent = _parentBlocksOfBlock(equation);
    if (parent == null) {
      return;
    }
    final int index = parent.indexOf(equation);
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          parent.remove(equation);
          selectedEquation = null;
        },
        undoFn: () {
          if (!parent.contains(equation)) {
            parent.insert(index.clamp(0, parent.length), equation);
          }
          selectedEquation = equation;
        },
      ),
    );
    _placeCaretAfterBlockRemoval(parent, index);
    relayout();
    _syncImeSelection();
    notifyListeners();
  }

  void insertEquationText(String text) {
    final WmlEquation? equation = selectedEquation;
    if (equation == null || !config.allowsMutation || text.isEmpty) {
      return;
    }
    _mutateEquation((OmmlEquation math) {
      if (math.view == OmmlView.linear) {
        final String current = math.linearText.isEmpty
            ? OmmlLinear.write(math.root)
            : math.linearText;
        final int i = equationCaret.clamp(0, current.length);
        math.linearText = current.substring(0, i) + text + current.substring(i);
        return;
      }
      OmmlEdit.insertAt(
        math.root,
        OmmlEdit.slotAt(math.root, equationSlot),
        equationCaret,
        text,
      );
    });
    equationCaret += text.length;
    _clampEquationCaret();
  }

  void insertEquationSymbol(String symbol) => insertEquationText(symbol);

  void applyEquationStructure(OmmlStructure kind) {
    final WmlEquation? equation = selectedEquation;
    if (equation == null || !config.allowsMutation) {
      return;
    }
    _mutateEquation((OmmlEquation math) {
      if (math.view == OmmlView.linear) {
        math.root = OmmlLinear.parse(math.linearText);
        math.view = OmmlView.professional;
        math.linearText = '';
      }
      OmmlEdit.applyStructure(OmmlEdit.slotAt(math.root, equationSlot), kind);
    });
    final WmlEquation? after = selectedEquation;
    if (after == null) {
      return;
    }
    for (final OmmlSeq cell in OmmlEdit.cells(after.math.root)) {
      if (cell.isEmpty) {
        equationSlot = OmmlEdit.slotIndexOf(after.math.root, cell);
        equationCaret = 0;
        notifyListeners();
        return;
      }
    }
  }

  void setEquationView(OmmlView view) {
    final WmlEquation? equation = selectedEquation;
    if (equation == null || !config.allowsMutation) {
      return;
    }
    _mutateEquation((OmmlEquation math) {
      if (view == OmmlView.linear) {
        math.linearText = OmmlLinear.write(math.root);
        math.view = OmmlView.linear;
      } else {
        if (math.linearText.isNotEmpty) {
          math.root = OmmlLinear.parse(math.linearText);
        }
        math.linearText = '';
        math.view = OmmlView.professional;
      }
    });
  }

  void deleteEquationContent({required bool backward}) {
    final WmlEquation? equation = selectedEquation;
    if (equation == null || !config.allowsMutation) {
      return;
    }
    if (equation.math.view == OmmlView.linear) {
      final String text = equationEditingText();
      if (text.isEmpty) {
        deleteSelectedEquation();
        return;
      }
      if (backward && equationCaret <= 0) {
        return;
      }
      if (!backward && equationCaret >= text.length) {
        return;
      }
      final int from = backward ? equationCaret - 1 : equationCaret;
      _mutateEquation((OmmlEquation math) {
        final String current = math.linearText.isEmpty
            ? OmmlLinear.write(math.root)
            : math.linearText;
        math.linearText =
            current.substring(0, from) + current.substring(from + 1);
      });
      if (backward) {
        equationCaret = from;
      }
      _clampEquationCaret();
      return;
    }
    final OmmlSeq root = equation.math.root;
    final bool atStart = equationCaret <= 0;
    if (backward &&
        atStart &&
        OmmlEdit.isFirstReadingCell(root, equationSlot) &&
        !OmmlEdit.hasUserText(root)) {
      deleteSelectedEquation();
      return;
    }
    final int len = _equationCellLength();
    if (backward && atStart) {
      final int prev = OmmlEdit.stepReading(root, equationSlot, -1);
      if (prev == equationSlot) {
        return;
      }
      equationSlot = prev;
      equationCaret = _equationCellLength();
      if (equationCaret > 0) {
        deleteEquationContent(backward: true);
      } else {
        notifyListeners();
      }
      return;
    }
    if (!backward && equationCaret >= len) {
      final int next = OmmlEdit.stepReading(
        equation.math.root,
        equationSlot,
        1,
      );
      if (next == equationSlot) {
        return;
      }
      equationSlot = next;
      equationCaret = 0;
      if (_equationCellLength() > 0) {
        deleteEquationContent(backward: false);
      } else {
        notifyListeners();
      }
      return;
    }
    final int offset = equationCaret;
    _mutateEquation((OmmlEquation math) {
      OmmlEdit.deleteAt(
        math.root,
        OmmlEdit.slotAt(math.root, equationSlot),
        offset,
        backward: backward,
      );
    });
    equationCaret = backward ? offset - 1 : offset;
    _clampEquationCaret();
  }

  void moveEquationSlot(int delta) {
    final WmlEquation? equation = selectedEquation;
    if (equation == null) {
      return;
    }
    equationSlot = delta >= 0
        ? OmmlEdit.nextSlot(equation.math.root, equationSlot)
        : OmmlEdit.prevSlot(equation.math.root, equationSlot);
    equationCaret = delta >= 0 ? 0 : _equationCellLength();
    _clampEquationCaret();
    notifyListeners();
    if (input.isAttached) {
      _writeImeValue();
    }
  }

  void moveEquationArrow({required int dx, required int dy}) {
    final WmlEquation? equation = selectedEquation;
    if (equation == null) {
      return;
    }
    if (dx != 0 && dy == 0) {
      _moveEquationChar(dx);
      return;
    }
    final LaidOutOmml? omml = _laidOmmlOf(equation);
    if (omml != null) {
      final int? next = _neighborEquationCell(
        omml,
        equation.math.root,
        dx: dx,
        dy: dy,
      );
      if (next != null) {
        equationSlot = next;
        equationCaret = dy < 0 ? _equationCellLength() : 0;
        _clampEquationCaret();
        notifyListeners();
        if (input.isAttached) {
          _writeImeValue();
        }
        return;
      }
    }
    moveEquationSlot(dy);
  }

  void _moveEquationChar(int dx) {
    final WmlEquation? equation = selectedEquation;
    if (equation == null || dx == 0) {
      return;
    }
    final int len = _equationCellLength();
    if (dx > 0) {
      if (equationCaret < len) {
        equationCaret++;
      } else {
        final int next = OmmlEdit.stepReading(
          equation.math.root,
          equationSlot,
          1,
        );
        if (next != equationSlot) {
          equationSlot = next;
          equationCaret = 0;
        }
      }
    } else if (equationCaret > 0) {
      equationCaret--;
    } else {
      final int prev = OmmlEdit.stepReading(
        equation.math.root,
        equationSlot,
        -1,
      );
      if (prev != equationSlot) {
        equationSlot = prev;
        equationCaret = _equationCellLength();
      }
    }
    _clampEquationCaret();
    caret.resetBlink();
    notifyListeners();
    if (input.isAttached) {
      _writeImeValue();
    }
  }

  LaidOutOmml? _laidOmmlOf(WmlEquation equation) {
    for (final LaidOutPage page in laidOut.pages) {
      for (final LaidOutBox box in page.frames) {
        if (identical(box.equation, equation)) {
          return box.omml;
        }
      }
    }
    return null;
  }

  int? _neighborEquationCell(
    LaidOutOmml omml,
    OmmlSeq root, {
    required int dx,
    required int dy,
  }) {
    final List<OmmlSeq> all = OmmlEdit.slots(root);
    final Set<int> cellIdx = <int>{
      for (final OmmlSeq cell in OmmlEdit.cells(root)) OmmlEdit.slotIndexOf(root, cell),
    };
    LaidOutOmmlSlot? current;
    for (final LaidOutOmmlSlot slot in omml.slots) {
      if (slot.slotIndex == equationSlot) {
        current = slot;
        break;
      }
    }
    current ??= omml.slots.cast<LaidOutOmmlSlot?>().firstWhere(
      (LaidOutOmmlSlot? slot) =>
          slot != null && cellIdx.contains(slot.slotIndex),
      orElse: () => null,
    );
    if (current == null) {
      return null;
    }
    final double cx = current.x + current.width / 2;
    final double cy = current.y + current.height / 2;
    LaidOutOmmlSlot? best;
    var bestScore = double.infinity;
    for (final LaidOutOmmlSlot slot in omml.slots) {
      if (slot.slotIndex == current.slotIndex ||
          !cellIdx.contains(slot.slotIndex) ||
          slot.slotIndex >= all.length) {
        continue;
      }
      final double sx = slot.x + slot.width / 2;
      final double sy = slot.y + slot.height / 2;
      final double ddx = sx - cx;
      final double ddy = sy - cy;
      if (dy != 0) {
        if (ddy.abs() < 2 || ddy.sign != dy) {
          continue;
        }
        final double score = ddy.abs() + ddx.abs() * 2.4;
        if (score < bestScore) {
          bestScore = score;
          best = slot;
        }
      } else if (dx != 0) {
        if (ddx.abs() < 2 || ddx.sign != dx) {
          continue;
        }
        final double score = ddx.abs() + ddy.abs() * 2.4;
        if (score < bestScore) {
          bestScore = score;
          best = slot;
        }
      }
    }
    return best?.slotIndex;
  }

  void _mutateEquation(void Function(OmmlEquation math) edit) {
    final WmlEquation? equation = selectedEquation;
    if (equation == null) {
      return;
    }
    final OmmlEquation before = equation.math.copy();
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          equation.math = before.copy();
          edit(equation.math);
        },
        undoFn: () {
          equation.math = before.copy();
        },
      ),
    );
    equationSlot = OmmlEdit.snapToCell(equation.math.root, equationSlot);
    _clampEquationCaret();
    relayout();
    attachInput();
    notifyListeners();
    onRequestFocus?.call();
  }

  List<WmlVisual> get visualsInSelection {
    if (selectedVisual != null && caret.isCollapsed) {
      return <WmlVisual>[selectedVisual!];
    }
    if (caret.isCollapsed) {
      return const <WmlVisual>[];
    }
    final range = caret.normalizedRange;
    return <WmlVisual>[
      for (final WmlVisual visual in visuals)
        if (_isVisualBetweenParagraphs(visual, range.startPara, range.endPara))
          visual,
    ];
  }

  bool isVisualInSelection(OfficeVisual visual) {
    for (final WmlVisual candidate in visualsInSelection) {
      if (identical(candidate.visual, visual)) {
        return true;
      }
    }
    return false;
  }

  void extendSelectionThroughVisual(OfficeVisual office) {
    if (!config.allowsSelection) {
      return;
    }
    WmlVisual? visual;
    for (final WmlVisual candidate in visuals) {
      if (identical(candidate.visual, office)) {
        visual = candidate;
        break;
      }
    }
    if (visual == null) {
      return;
    }
    final List<WmlParagraph> paras = _paragraphs;
    final int before = _paragraphIndexBefore(visual) ?? -1;
    final int after = before + 1;
    final int anchor = caret.selectionAnchorParagraph;
    if (anchor <= before) {
      if (after >= 0 && after < paras.length) {
        caret.paragraphIndex = after;
        caret.logicalIndex = 0;
      } else if (before >= 0 && before < paras.length) {
        caret.paragraphIndex = before;
        caret.logicalIndex = paras[before].text.length;
      }
    } else if (before >= 0 && before < paras.length) {
      caret.paragraphIndex = before;
      caret.logicalIndex = paras[before].text.length;
    }
    caret.resetBlink();
    notifyListeners();
  }

  void selectVisualFromOffice(OfficeVisual? visual) {
    if (visual == null) {
      selectVisual(null);
      return;
    }
    for (final WmlVisual candidate in visuals) {
      if (identical(candidate.visual, visual)) {
        selectVisual(candidate);
        return;
      }
    }
    selectVisual(null);
  }

  void deleteSelectedVisual() {
    final WmlVisual? visual = selectedVisual;
    if (visual == null || !config.allowsMutation) {
      return;
    }
    final List<WmlBlock>? parent = _parentBlocksOfVisual(visual);
    if (parent == null) {
      return;
    }
    final int index = parent.indexOf(visual);
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          parent.remove(visual);
          selectedVisual = null;
        },
        undoFn: () {
          if (!parent.contains(visual)) {
            parent.insert(index.clamp(0, parent.length), visual);
          }
          selectedVisual = visual;
        },
      ),
    );
    relayout();
    notifyListeners();
  }

  void updateSelectedVisual({
    String? title,
    OfficeVisualKind? kind,
    List<ChartPoint>? points,
    double? width,
    double? height,
  }) {
    final WmlVisual? visual = selectedVisual;
    if (visual == null || !config.allowsMutation) {
      return;
    }
    final OfficeVisual before = visual.visual;
    final OfficeVisualKind prevKind = before.kind;
    final String prevTitle = before.title;
    final List<ChartPoint> prevPoints = List<ChartPoint>.from(before.points);
    final double prevW = before.width;
    final double prevH = before.height;
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          if (title != null) {
            before.title = title;
          }
          if (kind != null) {
            before.kind = kind;
          }
          if (points != null) {
            before.points
              ..clear()
              ..addAll(points);
          }
          if (width != null) {
            before.width = width;
          }
          if (height != null) {
            before.height = height;
          }
        },
        undoFn: () {
          before
            ..kind = prevKind
            ..title = prevTitle
            ..width = prevW
            ..height = prevH;
          before.points
            ..clear()
            ..addAll(prevPoints);
        },
      ),
    );
    relayout();
    notifyListeners();
  }

  void mutateSelectedVisual(void Function(OfficeVisual visual) edit) {
    final WmlVisual? wrap = selectedVisual;
    if (wrap == null || !config.allowsMutation) {
      return;
    }
    final OfficeVisual visual = wrap.visual;
    final OfficeVisual before = visual.copy();
    edit(visual);
    final OfficeVisual after = visual.copy();
    commands.commit(
      _CallbackCommand(
        executeFn: () => visual.restoreFrom(after),
        undoFn: () => visual.restoreFrom(before),
      ),
    );
    relayout();
    notifyListeners();
  }

  void cycleSelectedVisualKind() {
    final WmlVisual? visual = selectedVisual;
    if (visual == null) {
      return;
    }
    updateSelectedVisual(kind: _nextVisualKind(visual.visual.kind));
  }

  bool _selectNeighborVisual(int delta, {required bool requireEdge}) {
    final WmlParagraph para = _activeParagraph;
    if (delta > 0 &&
        (!requireEdge || caret.logicalIndex >= para.text.length)) {
      final WmlBlock? next = _siblingBlock(para, after: true);
      if (next is WmlVisual) {
        selectedVisual = next;
        notifyListeners();
        return true;
      }
      if (next is WmlEquation) {
        selectEquation(next);
        return true;
      }
    }
    if (delta < 0 && (!requireEdge || caret.logicalIndex <= 0)) {
      final WmlBlock? prev = _siblingBlock(para, after: false);
      if (prev is WmlVisual) {
        selectedVisual = prev;
        notifyListeners();
        return true;
      }
      if (prev is WmlEquation) {
        selectEquation(prev);
        return true;
      }
    }
    return false;
  }

  void _leaveSelectedVisual({required bool forward}) {
    final WmlVisual? visual = selectedVisual;
    selectedVisual = null;
    if (visual == null) {
      notifyListeners();
      return;
    }
    final WmlBlock? neighbor = _siblingBlock(visual, after: forward);
    if (neighbor is WmlVisual) {
      selectedVisual = neighbor;
      notifyListeners();
      return;
    }
    final List<WmlParagraph> paras = _paragraphs;
    if (neighbor is WmlParagraph) {
      final int index = paras.indexOf(neighbor);
      if (index >= 0) {
        caret.paragraphIndex = index;
        caret.logicalIndex = forward ? 0 : neighbor.text.length;
        caret.collapseSelection();
      }
    }
    caret.resetBlink();
    notifyListeners();
  }

  WmlBlock? _siblingBlock(WmlBlock block, {required bool after}) {
    final List<WmlBlock>? parent = block is WmlParagraph
        ? _parentBlocksOf(block)
        : block is WmlVisual
        ? _parentBlocksOfVisual(block)
        : null;
    if (parent == null) {
      return null;
    }
    final int index = parent.indexOf(block);
    if (index < 0) {
      return null;
    }
    final int next = after ? index + 1 : index - 1;
    if (next < 0 || next >= parent.length) {
      return null;
    }
    return parent[next];
  }

  List<WmlBlock>? _parentBlocksOfVisual(WmlVisual visual) =>
      _parentBlocksOfBlock(visual);

  List<WmlBlock>? _parentBlocksOfBlock(WmlBlock target) {
    List<WmlBlock>? walk(List<WmlBlock> blocks) {
      if (blocks.contains(target)) {
        return blocks;
      }
      for (final WmlBlock block in blocks) {
        if (block is! WmlTable) {
          continue;
        }
        for (final WmlTableRow row in block.rows) {
          for (final WmlTableCell cell in row.cells) {
            final List<WmlBlock>? found = walk(cell.blocks);
            if (found != null) {
              return found;
            }
          }
        }
      }
      return null;
    }

    for (final WmlSection section in document.sections) {
      final List<WmlBlock>? found = walk(section.blocks);
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  List<LaidOutLine> _contentLines() {
    return <LaidOutLine>[
      for (final LaidOutPage page in laidOut.pages)
        for (final LaidOutLine line in page.lines)
          line,
    ];
  }

  int _lineIndexOfCaret(List<LaidOutLine> lines) {
    for (int i = 0; i < lines.length; i++) {
      if (caret.isOnLine(lines[i], lastOfParagraph: _isLastContentLine(lines, i))) {
        return i;
      }
    }
    var found = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].paragraphIndex == caret.paragraphIndex) {
        found = i;
      }
    }
    return found;
  }

  static bool _isLastContentLine(List<LaidOutLine> lines, int index) {
    final int paragraph = lines[index].paragraphIndex;
    for (int i = index + 1; i < lines.length; i++) {
      if (lines[i].paragraphIndex == paragraph) {
        return false;
      }
    }
    return true;
  }

  double _caretXOnLine(LaidOutLine line) {
    if (line.glyphs.isEmpty) {
      return line.x;
    }
    for (final LaidOutGlyph glyph in line.glyphs) {
      if (glyph.glyph.logicalIndex != caret.logicalIndex) {
        continue;
      }
      return glyph.glyph.level.isOdd ? glyph.x + glyph.advance : glyph.x;
    }
    final LaidOutGlyph last = line.glyphs.last;
    return last.glyph.level.isOdd ? last.x : last.x + last.advance;
  }

  static int _lineLogicalStart(LaidOutLine line) {
    if (line.glyphs.isEmpty) {
      return 0;
    }
    var min = line.glyphs.first.glyph.logicalIndex;
    for (final LaidOutGlyph glyph in line.glyphs) {
      if (glyph.glyph.logicalIndex < min) {
        min = glyph.glyph.logicalIndex;
      }
    }
    return min;
  }

  static int _lineLogicalEnd(LaidOutLine line) {
    if (line.glyphs.isEmpty) {
      return 0;
    }
    var max = 0;
    for (final LaidOutGlyph glyph in line.glyphs) {
      final int end = glyph.glyph.logicalIndex + 1;
      if (end > max) {
        max = end;
      }
    }
    return max;
  }

  static int _logicalAtX(LaidOutLine line, double x) {
    if (line.glyphs.isEmpty) {
      return 0;
    }
    for (final LaidOutGlyph glyph in line.glyphs) {
      if (x <= glyph.x + glyph.advance / 2) {
        return glyph.glyph.logicalIndex;
      }
    }
    return _lineLogicalEnd(line);
  }

  void _crossLaidOutLine(
    List<LaidOutLine> lines,
    int index, {
    required bool toRight,
    required bool extend,
  }) {
    final int nextIndex = toRight ? index + 1 : index - 1;
    if (nextIndex < 0 || nextIndex >= lines.length) {
      if (!extend) {
        _selectNeighborVisual(toRight ? 1 : -1, requireEdge: true);
      }
      return;
    }
    final LaidOutLine current = lines[index];
    final LaidOutLine next = lines[nextIndex];
    if (!extend) {
      final WmlVisual? between = _visualBetweenLines(current, next);
      if (between != null) {
        selectedVisual = between;
        notifyListeners();
        return;
      }
    }
    caret.paragraphIndex = next.paragraphIndex;
    caret.logicalIndex = _logicalAtX(
      next,
      toRight ? next.x : next.x + next.width,
    );
    if (!extend) {
      caret.collapseSelection();
    }
    caret.resetBlink();
    selectedVisual = null;
    _syncImeSelection();
    notifyListeners();
  }

  WmlVisual? _visualBetweenLines(LaidOutLine a, LaidOutLine b) {
    final int lo = a.paragraphIndex < b.paragraphIndex
        ? a.paragraphIndex
        : b.paragraphIndex;
    final int hi = a.paragraphIndex > b.paragraphIndex
        ? a.paragraphIndex
        : b.paragraphIndex;
    if (lo == hi) {
      return null;
    }
    for (final WmlVisual visual in visuals) {
      if (_isVisualBetweenParagraphs(visual, lo, hi)) {
        return visual;
      }
    }
    return null;
  }

  bool _isVisualBetweenParagraphs(WmlVisual visual, int startPara, int endPara) {
    if (endPara <= startPara) {
      return false;
    }
    final int? after = _paragraphIndexBefore(visual);
    if (after == null) {
      return false;
    }
    return after >= startPara && after < endPara;
  }

  int? _paragraphIndexBefore(WmlVisual visual) {
    final List<WmlBlock>? parent = _parentBlocksOfVisual(visual);
    if (parent == null) {
      return null;
    }
    final int index = parent.indexOf(visual);
    final List<WmlParagraph> paras = _paragraphs;
    for (int i = index - 1; i >= 0; i--) {
      final WmlBlock block = parent[i];
      if (block is WmlParagraph) {
        final int at = paras.indexOf(block);
        return at >= 0 ? at : null;
      }
      if (block is WmlTable) {
        WmlParagraph? last;
        for (final WmlTableRow row in block.rows) {
          for (final WmlTableCell cell in row.cells) {
            for (final WmlBlock inner in cell.blocks) {
              if (inner is WmlParagraph) {
                last = inner;
              }
            }
          }
        }
        if (last != null) {
          final int at = paras.indexOf(last);
          return at >= 0 ? at : null;
        }
      }
    }
    return -1;
  }

  static OfficeVisualKind _nextVisualKind(OfficeVisualKind kind) {
    return OfficeVisual.nextKind(kind);
  }

  List<WmlBlock>? _parentBlocksOf(WmlParagraph para) {
    for (final WmlSection section in document.sections) {
      if (section.blocks.contains(para)) {
        return section.blocks;
      }
      for (final WmlBlock block in section.blocks) {
        if (block is! WmlTable) {
          continue;
        }
        for (final WmlTableRow row in block.rows) {
          for (final WmlTableCell cell in row.cells) {
            if (cell.blocks.contains(para)) {
              return cell.blocks;
            }
          }
        }
      }
    }
    return null;
  }

  void _insertParagraphAfter(WmlParagraph para, WmlParagraph next) {
    if (isEditingComment) {
      final List<WmlParagraph> paras = selectedComment!.paragraphs;
      final int index = paras.indexOf(para);
      if (index >= 0) {
        paras.insert(index + 1, next);
      } else {
        paras.add(next);
      }
      return;
    }
    if (isEditingHeaderFooter) {
      final List<WmlParagraph> paras = _ensureHeaderFooterParagraphs();
      final int index = paras.indexOf(para);
      if (index >= 0) {
        paras.insert(index + 1, next);
      } else {
        paras.add(next);
      }
      return;
    }
    final ({List<WmlBlock> parent, int index})? slot = _hostSlotOf(para);
    if (slot != null) {
      slot.parent.insert((slot.index + 1).clamp(0, slot.parent.length), next);
      return;
    }
    sectionAtCaret.blocks.add(next);
  }

  void _removeParagraphAfter(WmlParagraph para) {
    if (isEditingComment) {
      final List<WmlParagraph> paras = selectedComment!.paragraphs;
      final int index = paras.indexOf(para);
      if (index >= 0 && index + 1 < paras.length) {
        paras.removeAt(index + 1);
      }
      return;
    }
    if (isEditingHeaderFooter) {
      final List<WmlParagraph> paras = _ensureHeaderFooterParagraphs();
      final int index = paras.indexOf(para);
      if (index >= 0 && index + 1 < paras.length) {
        paras.removeAt(index + 1);
      }
      return;
    }
    final ({List<WmlBlock> parent, int index})? slot = _hostSlotOf(para);
    if (slot != null && slot.index + 1 < slot.parent.length) {
      slot.parent.removeAt(slot.index + 1);
    }
  }

  @override
  String get semanticsLabel {
    final WmlVisual? visual = selectedVisual;
    if (visual != null) {
      final String title = visual.visual.title.isEmpty
          ? config.strings.pictureLabel
          : visual.visual.title;
      final String mode = pictureCropMode ? ', ${config.strings.cropMode}' : '';
      return '${config.strings.wordEditor}, $title$mode';
    }
    return config.strings.wordEditor;
  }

  @override
  String get semanticsValue {
    final WmlVisual? visual = selectedVisual;
    if (visual != null) {
      final OfficeVisual v = visual.visual;
      return '${config.strings.pictureLabel} ${v.width.round()}×${v.height.round()}. ${config.strings.pictureHint}';
    }
    final String text = _activeParagraph.text;
    final int i = caret.logicalIndex.clamp(0, text.length);
    return text.isEmpty ? '' : text.substring(0, i);
  }
}

enum _WordBlockCover { none, partial, full }

/// Spreadsheet controller: selection, formula bar, cell IME.
class SheetEditorController extends OfficeController {
  SheetEditorController({
    SmlWorkbook? workbook,
    super.config,
    this._activeSheet = 0,
  }) : workbook = workbook ?? SmlWorkbook() {
    cellEditor = InlineCellEditor(
      onCommit: _commitFormula,
      onChanged: _onCellEditorChanged,
      commitOnNewline: true,
    );
    recalculateWorkbook();
  }

  factory SheetEditorController.fromBytes(
    Uint8List bytes, {
    String? password,
    OfficeSurfaceConfig? config,
  }) {
    final SheetEditorController controller = SheetEditorController(
      config: config,
    );
    controller.loadBytes(bytes, password: password);
    return controller;
  }

  SmlWorkbook workbook;
  int _activeSheet;
  final SelectionMatrix selection = SelectionMatrix();
  late final InlineCellEditor cellEditor;
  int? selectedDrawingIndex;
  var _applyingPoint = false;
  int? _pointStart;
  int? _pointEnd;
  SmlCellRef? _pointAnchor;
  List<FormulaFnDoc> functionSuggestions = const <FormulaFnDoc>[];
  var functionSuggestionIndex = 0;
  var _suppressFunctionSuggestions = false;
  String? _suppressedFunctionPrefix;

  int get activeSheetIndex => _activeSheet;

  SmlWorksheet get sheet {
    if (workbook.sheets.isEmpty) {
      workbook.sheets.add(SmlWorksheet(name: 'Sheet1', sheetId: 1));
    }
    return workbook.sheets[_activeSheet.clamp(0, workbook.sheets.length - 1)];
  }

  @override
  OpcPackageKind get kind => OpcPackageKind.sheet;

  String get formulaBarText {
    if (cellEditor.editing) {
      return cellEditor.formulaBar;
    }
    final SmlCell cell = sheet.cell(selection.focus);
    return cell.formula ?? cell.asString;
  }

  String cellDisplayText(SmlCell cell) {
    if (cellEditor.editing &&
        cell.ref.col == selection.focus.col &&
        cell.ref.row == selection.focus.row) {
      return cellEditor.formulaBar;
    }
    if (cell.formula != null && cell.formula!.isNotEmpty) {
      return _formatCellValue(
        FormulaEvaluator.evaluateCell(workbook, sheet, cell),
      );
    }
    return _formatCellValue(cell.value);
  }

  void recalculateWorkbook() {
    FormulaEvaluator.recalculate(workbook);
    SheetChartData.refreshWorkbook(workbook);
  }

  static String _formatCellValue(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is num) {
      if (value == value.roundToDouble()) {
        return value.round().toString();
      }
      return value.toString();
    }
    return value.toString();
  }

  void loadBytes(Uint8List bytes, {String? password}) {
    _acceptOpenedWorkbook(
      SheetDeserializer().read(
        OfficeRepair.open(bytes, password: password),
      ),
      recalculate: true,
    );
  }

  Future<void> loadBytesAsync(
    Uint8List bytes, {
    String? password,
    void Function(OfficeOpenProgress progress)? onProgress,
  }) async {
    final SmlWorkbook opened = await OfficeIsolateOpen.workbook(
      bytes,
      password: password,
      onProgress: onProgress,
    );
    _acceptOpenedWorkbook(opened, recalculate: false);
  }

  void _acceptOpenedWorkbook(SmlWorkbook opened, {required bool recalculate}) {
    workbook = opened;
    _activeSheet = 0;
    selectedDrawingIndex = null;
    selection.selectCell(const SmlCellRef(0, 0));
    viewport.origin = Offset.zero;
    if (recalculate) {
      recalculateWorkbook();
    }
    _dirty = false;
    notifyListeners();
  }

  @override
  void afterHistoryChange() {
    recalculateWorkbook();
  }

  @override
  Uint8List saveBytes({String? password}) {
    final Uint8List bytes = SheetSerializer().writeBytes(
      workbook,
      password: password,
    );
    markClean();
    return bytes;
  }

  @override
  Future<Uint8List> saveBytesAsync({String? password}) {
    return OfficeIsolateSave.workbook(workbook, password: password);
  }

  void setActiveSheet(int index) {
    _activeSheet = index.clamp(0, workbook.sheets.length - 1);
    selectedDrawingIndex = null;
    selection.selectCell(const SmlCellRef(0, 0));
    viewport.origin = Offset.zero;
    notifyListeners();
  }

  void setSheetRightToLeft(bool value) {
    if (sheet.rightToLeft == value) {
      return;
    }
    sheet.rightToLeft = value;
    notifyListeners();
  }

  void toggleSheetRightToLeft() {
    setSheetRightToLeft(!sheet.rightToLeft);
  }

  bool get hasFrozenPanes => sheet.freezeRows > 0 || sheet.freezeCols > 0;

  void unfreezePanes() {
    if (!hasFrozenPanes) {
      return;
    }
    sheet.freezeRows = 0;
    sheet.freezeCols = 0;
    clampSheetViewport();
    notifyListeners();
  }

  /// Excel Freeze Panes: lock rows above and columns left of the selection.
  ///
  /// A full row freezes from that row (no columns). A full column freezes
  /// from that column (no rows). A cell freezes from its row and column.
  void freezePanesFromSelection() {
    var rows = 0;
    var cols = 0;
    if (selection.isFullRowSelection && selection.isFullColumnSelection) {
      unfreezePanes();
      return;
    }
    if (selection.isFullRowSelection) {
      rows = selection.anchor.row < selection.focus.row
          ? selection.anchor.row
          : selection.focus.row;
    } else if (selection.isFullColumnSelection) {
      cols = selection.anchor.col < selection.focus.col
          ? selection.anchor.col
          : selection.focus.col;
    } else {
      rows = selection.focus.row;
      cols = selection.focus.col;
    }
    if (rows <= 0 && cols <= 0) {
      unfreezePanes();
      return;
    }
    sheet.freezeRows = rows.clamp(0, SmlWorksheet.excelRowCount - 1);
    sheet.freezeCols = cols.clamp(0, SmlWorksheet.excelColumnCount - 1);
    clampSheetViewport();
    notifyListeners();
  }

  void toggleFreezePanes() {
    if (hasFrozenPanes) {
      unfreezePanes();
    } else {
      freezePanesFromSelection();
    }
  }

  void freezeTopRow() {
    sheet.freezeRows = 1;
    sheet.freezeCols = 0;
    clampSheetViewport();
    notifyListeners();
  }

  void freezeFirstColumn() {
    sheet.freezeRows = 0;
    sheet.freezeCols = 1;
    clampSheetViewport();
    notifyListeners();
  }

  SmlDrawing? get selectedDrawing {
    final int? index = selectedDrawingIndex;
    if (index == null || index < 0 || index >= sheet.drawings.length) {
      return null;
    }
    return sheet.drawings[index];
  }

  void selectDrawing(int? index) {
    if (!config.allowsSelection) {
      selectedDrawingIndex = null;
      notifyListeners();
      return;
    }
    selectedDrawingIndex = index;
    notifyListeners();
  }

  void deleteSelectedDrawing() {
    final int? index = selectedDrawingIndex;
    if (index == null || !config.allowsMutation) {
      return;
    }
    if (index < 0 || index >= sheet.drawings.length) {
      return;
    }
    final SmlDrawing drawing = sheet.drawings[index];
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          sheet.drawings.remove(drawing);
          selectedDrawingIndex = null;
        },
        undoFn: () {
          if (!sheet.drawings.contains(drawing)) {
            sheet.drawings.insert(index.clamp(0, sheet.drawings.length), drawing);
          }
          selectedDrawingIndex = sheet.drawings.indexOf(drawing);
        },
      ),
    );
    notifyListeners();
  }

  void nudgeSelectedDrawing(int dc, int dr) {
    final SmlDrawing? drawing = selectedDrawing;
    if (drawing == null || !config.allowsMutation) {
      return;
    }
    if (dc == 0 && dr == 0) {
      return;
    }
    final int prevCol = drawing.col;
    final int prevRow = drawing.row;
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          drawing.col = (drawing.col + dc).clamp(0, 16383);
          drawing.row = (drawing.row + dr).clamp(0, 1048575);
        },
        undoFn: () {
          drawing.col = prevCol;
          drawing.row = prevRow;
        },
      ),
    );
    notifyListeners();
  }

  ({int col, int row, double ox, double oy, double w, double h})? _drawingSnap;

  void beginDrawingTransform() {
    final SmlDrawing? drawing = selectedDrawing;
    if (drawing == null) {
      return;
    }
    _drawingSnap = (
      col: drawing.col,
      row: drawing.row,
      ox: drawing.offsetX,
      oy: drawing.offsetY,
      w: drawing.visual.width,
      h: drawing.visual.height,
    );
  }

  void previewDrawingMove(double dx, double dy) {
    final SmlDrawing? drawing = selectedDrawing;
    if (drawing == null || !config.allowsMutation) {
      return;
    }
    _placeDrawing(
      drawing,
      sheet.columnLeft(drawing.col) + drawing.offsetX + dx,
      sheet.rowTop(drawing.row) + drawing.offsetY + dy,
    );
    notifyListeners();
  }

  void previewDrawingResize({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final SmlDrawing? drawing = selectedDrawing;
    if (drawing == null || !config.allowsMutation) {
      return;
    }
    drawing.visual.width = width.clamp(40, 1200);
    drawing.visual.height = height.clamp(40, 800);
    _placeDrawing(drawing, left, top);
    notifyListeners();
  }

  void commitDrawingTransform() {
    final SmlDrawing? drawing = selectedDrawing;
    final snap = _drawingSnap;
    _drawingSnap = null;
    if (drawing == null || snap == null || !config.allowsMutation) {
      return;
    }
    final int col = drawing.col;
    final int row = drawing.row;
    final double ox = drawing.offsetX;
    final double oy = drawing.offsetY;
    final double w = drawing.visual.width;
    final double h = drawing.visual.height;
    if (col == snap.col &&
        row == snap.row &&
        ox == snap.ox &&
        oy == snap.oy &&
        w == snap.w &&
        h == snap.h) {
      return;
    }
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          drawing
            ..col = col
            ..row = row
            ..offsetX = ox
            ..offsetY = oy;
          drawing.visual
            ..width = w
            ..height = h;
        },
        undoFn: () {
          drawing
            ..col = snap.col
            ..row = snap.row
            ..offsetX = snap.ox
            ..offsetY = snap.oy;
          drawing.visual
            ..width = snap.w
            ..height = snap.h;
        },
      ),
    );
    notifyListeners();
  }

  void _placeDrawing(SmlDrawing drawing, double x, double y) {
    final double px = x.clamp(0, sheet.columnLeft(SmlWorksheet.excelColumnCount - 1));
    final double py = y.clamp(0, sheet.rowTop(SmlWorksheet.excelRowCount - 1));
    drawing.col = sheet.columnAt(px);
    drawing.row = sheet.rowAt(py);
    drawing.offsetX = px - sheet.columnLeft(drawing.col);
    drawing.offsetY = py - sheet.rowTop(drawing.row);
  }

  void updateSelectedDrawing({
    String? title,
    OfficeVisualKind? kind,
    List<ChartPoint>? points,
    double? width,
    double? height,
  }) {
    final SmlDrawing? drawing = selectedDrawing;
    if (drawing == null || !config.allowsMutation) {
      return;
    }
    final OfficeVisual visual = drawing.visual;
    final OfficeVisualKind prevKind = visual.kind;
    final String prevTitle = visual.title;
    final List<ChartPoint> prevPoints = List<ChartPoint>.from(visual.points);
    final double prevW = visual.width;
    final double prevH = visual.height;
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          if (title != null) {
            visual.title = title;
          }
          if (kind != null) {
            visual.kind = kind;
          }
          if (points != null) {
            visual.points
              ..clear()
              ..addAll(points);
          }
          if (width != null) {
            visual.width = width;
          }
          if (height != null) {
            visual.height = height;
          }
        },
        undoFn: () {
          visual
            ..kind = prevKind
            ..title = prevTitle
            ..width = prevW
            ..height = prevH;
          visual.points
            ..clear()
            ..addAll(prevPoints);
        },
      ),
    );
    notifyListeners();
  }

  void mutateSelectedDrawing(void Function(OfficeVisual visual) edit) {
    final SmlDrawing? drawing = selectedDrawing;
    if (drawing == null || !config.allowsMutation) {
      return;
    }
    final OfficeVisual visual = drawing.visual;
    final OfficeVisual before = visual.copy();
    edit(visual);
    final OfficeVisual after = visual.copy();
    commands.commit(
      _CallbackCommand(
        executeFn: () => visual.restoreFrom(after),
        undoFn: () => visual.restoreFrom(before),
      ),
    );
    notifyListeners();
  }

  void cycleSelectedDrawingKind() {
    final SmlDrawing? drawing = selectedDrawing;
    if (drawing == null) {
      return;
    }
    updateSelectedDrawing(kind: WordEditorController._nextVisualKind(drawing.visual.kind));
  }

  @override
  void selectAll() {
    if (!config.allowsSelection) {
      return;
    }
    if (cellEditor.editing) {
      cellEditor.selectAll();
      notifyListeners();
      return;
    }
    selectedDrawingIndex = null;
    var maxCol = 0;
    var maxRow = 0;
    var any = false;
    for (final SmlCell cell in sheet.allCells) {
      if ((cell.value == null || cell.asString.isEmpty) &&
          (cell.formula == null || cell.formula!.isEmpty)) {
        continue;
      }
      any = true;
      if (cell.ref.col > maxCol) {
        maxCol = cell.ref.col;
      }
      if (cell.ref.row > maxRow) {
        maxRow = cell.ref.row;
      }
    }
    for (final SmlDrawing drawing in sheet.drawings) {
      any = true;
      if (drawing.col > maxCol) {
        maxCol = drawing.col;
      }
      if (drawing.row > maxRow) {
        maxRow = drawing.row;
      }
    }
    if (!any) {
      selection.selectCell(const SmlCellRef(0, 0));
    } else {
      selection.anchor = const SmlCellRef(0, 0);
      selection.focus = SmlCellRef(maxCol, maxRow);
    }
    notifyListeners();
  }

  void moveSelection(int dc, int dr, {bool extend = false}) {
    if (!config.allowsSelection) {
      return;
    }
    if (selectedDrawingIndex != null && !extend) {
      nudgeSelectedDrawing(dc, dr);
      return;
    }
    selectedDrawingIndex = null;
    moveSelectionTo(
      SmlCellRef(selection.focus.col + dc, selection.focus.row + dr),
      extend: extend,
    );
  }

  void jumpSelectionByOccupancy(int dc, int dr, {bool extend = false}) {
    if (!config.allowsSelection) {
      return;
    }
    selectedDrawingIndex = null;
    moveSelectionTo(
      sheet.sameOccupancy(selection.focus, dc, dr),
      extend: extend,
    );
  }

  void moveSelectionTo(SmlCellRef ref, {bool extend = false}) {
    if (!config.allowsSelection) {
      return;
    }
    selectedDrawingIndex = null;
    final SmlCellRef next = SmlCellRef(
      ref.col.clamp(0, SmlWorksheet.excelColumnCount - 1),
      ref.row.clamp(0, SmlWorksheet.excelRowCount - 1),
    );
    if (extend) {
      selection.extendTo(next);
    } else {
      selection.selectCell(next);
    }
    ensureCellVisible();
    notifyListeners();
  }

  void panSheet(Offset delta, {bool zoom = false}) {
    if (zoom) {
      viewport.setScale(
        viewport.scale * (delta.dy > 0 ? 0.9 : 1.1),
      );
    } else {
      viewport.pan(delta);
    }
    clampSheetViewport();
    notifyListeners();
  }

  int get visibleRowPage {
    final double inner = viewport.extent.height - 48;
    final double h = sheet.rowHeightAt(selection.focus.row) * viewport.scale;
    if (inner <= 0 || h <= 0) {
      return 10;
    }
    return (inner / h).floor().clamp(1, 200);
  }

  int get visibleColPage {
    final double inner = viewport.extent.width - 28;
    final double w = sheet.columnWidth(selection.focus.col) * viewport.scale;
    if (inner <= 0 || w <= 0) {
      return 8;
    }
    return (inner / w).floor().clamp(1, 64);
  }

  SmlCellRef scrollTarget([SmlCellRef? ref]) {
    final SmlCellRef cell = ref ?? selection.focus;
    if (selection.isFullRowSelection) {
      return SmlCellRef(lastUsedCell().col, cell.row);
    }
    if (selection.isFullColumnSelection) {
      return SmlCellRef(cell.col, lastUsedCell().row);
    }
    return cell;
  }

  SmlCellRef lastUsedCell() {
    var maxC = 0;
    var maxR = 0;
    var any = false;
    for (final SmlCell cell in sheet.allCells) {
      if ((cell.value == null || cell.asString.isEmpty) &&
          (cell.formula == null || cell.formula!.isEmpty)) {
        continue;
      }
      any = true;
      if (cell.ref.col > maxC) {
        maxC = cell.ref.col;
      }
      if (cell.ref.row > maxR) {
        maxR = cell.ref.row;
      }
    }
    return any ? SmlCellRef(maxC, maxR) : const SmlCellRef(0, 0);
  }

  int lastUsedColOnRow(int row) {
    final SmlRow? data = sheet.rows[row];
    if (data == null || data.cells.isEmpty) {
      return 0;
    }
    var maxC = 0;
    for (final SmlCell cell in data.cells.values) {
      if ((cell.value == null || cell.asString.isEmpty) &&
          (cell.formula == null || cell.formula!.isEmpty)) {
        continue;
      }
      if (cell.ref.col > maxC) {
        maxC = cell.ref.col;
      }
    }
    return maxC;
  }

  void ensureCellVisible([SmlCellRef? ref]) {
    final SmlCellRef cell = ref ?? scrollTarget();
    final double scale = viewport.scale <= 0 ? 1 : viewport.scale;
    final double headW = config.showGridHeaders ? 28 : 0;
    final double headH = config.showGridHeaders ? 20 : 0;
    final double barH = config.showFormulaBar ? 28 : 0;
    final Size view = viewport.extent;
    final double frozenW = sheet.columnLeft(sheet.freezeCols) * scale;
    final double frozenH = sheet.rowTop(sheet.freezeRows) * scale;
    final double viewW =
        view.width > headW + 1 ? view.width - headW : 1;
    final double viewH =
        view.height > barH + headH + 1 ? view.height - barH - headH : 1;
    final double left = sheet.columnLeft(cell.col) * scale;
    final double right = left + sheet.columnWidth(cell.col) * scale;
    final double top = sheet.rowTop(cell.row) * scale;
    final double bottom = top + sheet.rowHeightAt(cell.row) * scale;
    var ox = viewport.origin.dx;
    var oy = viewport.origin.dy;
    if (cell.col >= sheet.freezeCols) {
      if (left - ox < frozenW) {
        ox = left - frozenW;
      } else if (right > ox + viewW) {
        ox = right - viewW;
      }
    }
    if (cell.row >= sheet.freezeRows) {
      if (top - oy < frozenH) {
        oy = top - frozenH;
      } else if (bottom > oy + viewH) {
        oy = bottom - viewH;
      }
    }
    viewport.origin = Offset(ox, oy);
    clampSheetViewport();
  }

  void clampSheetViewport() {
    final double scale = viewport.scale <= 0 ? 1 : viewport.scale;
    final double headW = config.showGridHeaders ? 28 : 0;
    final double headH = config.showGridHeaders ? 20 : 0;
    final double barH = config.showFormulaBar ? 28 : 0;
    final Size view = viewport.extent.width <= 0 || viewport.extent.height <= 0
        ? const Size(800, 600)
        : viewport.extent;
    viewport.clampTo(
      content: SheetScrollExtent.contentSize(
        sheet: sheet,
        selection: selection,
        scale: scale,
        headW: headW,
        headH: headH,
        barH: barH,
      ),
      view: view,
    );
  }

  List<int> _columnsForResize(int col) {
    if (selection.isFullColumnSelection &&
        selection.contains(SmlCellRef(col, 0))) {
      final int c0 = selection.anchor.col < selection.focus.col
          ? selection.anchor.col
          : selection.focus.col;
      final int c1 = selection.anchor.col > selection.focus.col
          ? selection.anchor.col
          : selection.focus.col;
      return <int>[for (int c = c0; c <= c1; c++) c];
    }
    return <int>[col];
  }

  List<int> _rowsForResize(int row) {
    if (selection.isFullRowSelection &&
        selection.contains(SmlCellRef(0, row))) {
      final int r0 = selection.anchor.row < selection.focus.row
          ? selection.anchor.row
          : selection.focus.row;
      final int r1 = selection.anchor.row > selection.focus.row
          ? selection.anchor.row
          : selection.focus.row;
      return <int>[for (int r = r0; r <= r1; r++) r];
    }
    return <int>[row];
  }

  Map<int, double>? _resizeFromCols;
  Map<int, double>? _resizeFromRows;

  void previewColumnWidth(int col, double px) {
    if (!config.allowsMutation) {
      return;
    }
    final List<int> cols = _columnsForResize(col);
    _resizeFromCols ??= <int, double>{
      for (final int c in cols) c: sheet.columnWidth(c),
    };
    for (final int c in cols) {
      sheet.setColumnWidth(c, px);
    }
    notifyListeners();
  }

  void previewRowHeight(int row, double px) {
    if (!config.allowsMutation) {
      return;
    }
    final List<int> rows = _rowsForResize(row);
    _resizeFromRows ??= <int, double>{
      for (final int r in rows) r: sheet.rowHeightAt(r),
    };
    for (final int r in rows) {
      sheet.setRowHeight(r, px);
    }
    notifyListeners();
  }

  void commitResize() {
    if (_resizeFromCols != null) {
      final Map<int, double> from = _resizeFromCols!;
      final Map<int, double> to = <int, double>{
        for (final int c in from.keys) c: sheet.columnWidth(c),
      };
      _resizeFromCols = null;
      var changed = false;
      for (final int c in from.keys) {
        if ((to[c]! - from[c]!).abs() >= 0.5) {
          changed = true;
          break;
        }
      }
      if (!changed) {
        return;
      }
      for (final MapEntry<int, double> e in from.entries) {
        sheet.setColumnWidth(e.key, e.value);
      }
      commands.commit(
        _CallbackCommand(
          executeFn: () {
            for (final MapEntry<int, double> e in to.entries) {
              sheet.setColumnWidth(e.key, e.value);
            }
          },
          undoFn: () {
            for (final MapEntry<int, double> e in from.entries) {
              sheet.setColumnWidth(e.key, e.value);
            }
          },
        ),
      );
      return;
    }
    if (_resizeFromRows != null) {
      final Map<int, double> from = _resizeFromRows!;
      final Map<int, double> to = <int, double>{
        for (final int r in from.keys) r: sheet.rowHeightAt(r),
      };
      _resizeFromRows = null;
      var changed = false;
      for (final int r in from.keys) {
        if ((to[r]! - from[r]!).abs() >= 0.5) {
          changed = true;
          break;
        }
      }
      if (!changed) {
        return;
      }
      for (final MapEntry<int, double> e in from.entries) {
        sheet.setRowHeight(e.key, e.value);
      }
      commands.commit(
        _CallbackCommand(
          executeFn: () {
            for (final MapEntry<int, double> e in to.entries) {
              sheet.setRowHeight(e.key, e.value);
            }
          },
          undoFn: () {
            for (final MapEntry<int, double> e in from.entries) {
              sheet.setRowHeight(e.key, e.value);
            }
          },
        ),
      );
    }
  }

  void nudgeColumnWidth(double delta) {
    if (!config.allowsMutation) {
      return;
    }
    final int col = selection.focus.col;
    previewColumnWidth(col, sheet.columnWidth(col) + delta);
    commitResize();
  }

  void nudgeRowHeight(double delta) {
    if (!config.allowsMutation) {
      return;
    }
    final int row = selection.focus.row;
    previewRowHeight(row, sheet.rowHeightAt(row) + delta);
    commitResize();
  }

  @override
  bool get canCopy => true;

  @override
  Future<void> copyToClipboard() async {
    await OfficeClipboard.instance.write(_captureSheetClipboard());
  }

  @override
  Future<void> cutToClipboard() async {
    if (!canCut) {
      return;
    }
    await copyToClipboard();
    if (cellEditor.editing) {
      _replaceCellEditorSelection('');
      return;
    }
    clearSelectedCells();
  }

  @override
  Future<void> pasteFromClipboard({
    OfficePasteMode mode = OfficePasteMode.keepSource,
  }) async {
    if (!canPaste) {
      return;
    }
    final OfficeClipboardPayload payload = await OfficeClipboard.instance.read();
    if (payload.isEmpty) {
      return;
    }
    if (cellEditor.editing) {
      _replaceCellEditorSelection(payload.plain);
      return;
    }
    if (mode != OfficePasteMode.keepTextOnly && payload.hasCells) {
      _pasteSheetCells(payload.cells, formulas: mode == OfficePasteMode.keepSource);
      return;
    }
    _pasteSheetTsv(payload.plain, formulas: mode == OfficePasteMode.keepSource);
  }

  OfficeClipboardPayload _captureSheetClipboard() {
    if (cellEditor.editing) {
      final String text = cellEditor.hasSelection
          ? cellEditor.formulaBar.substring(
              cellEditor.selectionStart,
              cellEditor.selectionEnd,
            )
          : cellEditor.formulaBar;
      return OfficeClipboardPayload.fromPlain(text);
    }
    final SmlRange range = selection.range;
    var r0 = range.start.row < range.end.row ? range.start.row : range.end.row;
    var r1 = range.start.row > range.end.row ? range.start.row : range.end.row;
    var c0 = range.start.col < range.end.col ? range.start.col : range.end.col;
    var c1 = range.start.col > range.end.col ? range.start.col : range.end.col;
    if (r1 - r0 > 1000 || c1 - c0 > 256) {
      var usedR = selection.focus.row;
      var usedC = selection.focus.col;
      for (final int row in sheet.rows.keys) {
        if (row > usedR) {
          usedR = row;
        }
        for (final int col in sheet.rows[row]!.cells.keys) {
          if (col > usedC) {
            usedC = col;
          }
        }
      }
      if (r1 > usedR) {
        r1 = usedR;
      }
      if (c1 > usedC) {
        c1 = usedC;
      }
    }
    final List<List<OfficeClipboardCell>> rows = <List<OfficeClipboardCell>>[];
    final StringBuffer tsv = StringBuffer();
    for (int r = r0; r <= r1; r++) {
      final List<OfficeClipboardCell> row = <OfficeClipboardCell>[];
      for (int c = c0; c <= c1; c++) {
        final SmlCell cell = sheet.cell(SmlCellRef(c, r));
        final String text = cell.formula ?? cell.asString;
        row.add(
          OfficeClipboardCell(
            value: cell.value,
            formula: cell.formula,
            type: cell.type,
            text: text,
          ),
        );
      }
      rows.add(row);
      if (r > r0) {
        tsv.write('\n');
      }
      tsv.write(row.map((OfficeClipboardCell cell) => cell.text).join('\t'));
    }
    return OfficeClipboardPayload(
      kind: OfficeClipboardKind.cells,
      plain: tsv.toString(),
      cells: rows,
    );
  }

  void _replaceCellEditorSelection(String insert) {
    final String text = cellEditor.formulaBar;
    final int start = cellEditor.selectionStart;
    final int end = cellEditor.selectionEnd;
    final String next = text.replaceRange(start, end, insert);
    cellEditor.formulaBar = next;
    cellEditor.caretIndex = start + insert.length;
    cellEditor.selectionBase = cellEditor.caretIndex;
    cellEditor.bridge.setValue(
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: cellEditor.caretIndex),
      ),
    );
    notifyListeners();
  }

  void _pasteSheetCells(
    List<List<OfficeClipboardCell>> rows, {
    required bool formulas,
  }) {
    if (rows.isEmpty) {
      return;
    }
    final int originC = selection.range.start.col < selection.range.end.col
        ? selection.range.start.col
        : selection.range.end.col;
    final int originR = selection.range.start.row < selection.range.end.row
        ? selection.range.start.row
        : selection.range.end.row;
    commands.beginBatch();
    for (int r = 0; r < rows.length; r++) {
      for (int c = 0; c < rows[r].length; c++) {
        final OfficeClipboardCell snap = rows[r][c];
        final SmlCell cell = sheet.cell(SmlCellRef(originC + c, originR + r));
        final Object? prevValue = cell.value;
        final String? prevFormula = cell.formula;
        final SmlCellType prevType = cell.type;
        commands.commit(
          _CallbackCommand(
            executeFn: () {
              if (formulas && snap.formula != null) {
                cell.formula = snap.formula;
                cell.type = snap.type;
                cell.value = snap.value;
              } else {
                _applyCellText(cell, snap.text);
              }
            },
            undoFn: () {
              cell.value = prevValue;
              cell.formula = prevFormula;
              cell.type = prevType;
            },
          ),
        );
      }
    }
    commands.endBatch();
    recalculateWorkbook();
    notifyListeners();
  }

  void _pasteSheetTsv(String text, {required bool formulas}) {
    final List<List<String>> rows = OfficeClipboardPayload.parseTsv(text);
    if (rows.isEmpty) {
      return;
    }
    _pasteSheetCells(
      <List<OfficeClipboardCell>>[
        for (final List<String> row in rows)
          <OfficeClipboardCell>[
            for (final String cell in row)
              OfficeClipboardCell(
                text: cell,
                value: cell,
                type: SmlCellType.string,
              ),
          ],
      ],
      formulas: formulas,
    );
  }

  void clearSelectedCells() {
    if (!config.allowsMutation || cellEditor.editing) {
      return;
    }
    if (selectedDrawingIndex != null) {
      deleteSelectedDrawing();
      return;
    }
    commands.beginBatch();
    for (final SmlRow row in sheet.rows.values) {
      for (final SmlCell cell in row.cells.values) {
        if (selection.contains(cell.ref) &&
            (cell.value != null || cell.formula != null)) {
          _clearCell(cell);
        }
      }
    }
    final SmlCell focus = sheet.cell(selection.focus);
    if (focus.value != null || focus.formula != null) {
      _clearCell(focus);
    }
    commands.endBatch();
    recalculateWorkbook();
    notifyListeners();
  }

  void insertSheetRows({required bool after, int? index, int count = 1}) {
    if (!config.allowsMutation || count <= 0) {
      return;
    }
    final SmlRange range = selection.range;
    final int minRow =
        range.start.row < range.end.row ? range.start.row : range.end.row;
    final int maxRow =
        range.start.row > range.end.row ? range.start.row : range.end.row;
    final int at = index ?? (after ? maxRow + 1 : minRow);
    _mutateSheetGrid(() => sheet.insertRows(at, count));
    selection.selectCell(SmlCellRef(selection.focus.col, at.clamp(0, 1048575)));
    notifyListeners();
  }

  void insertSheetCols({required bool after, int? index, int count = 1}) {
    if (!config.allowsMutation || count <= 0) {
      return;
    }
    final SmlRange range = selection.range;
    final int minCol =
        range.start.col < range.end.col ? range.start.col : range.end.col;
    final int maxCol =
        range.start.col > range.end.col ? range.start.col : range.end.col;
    final int at = index ?? (after ? maxCol + 1 : minCol);
    _mutateSheetGrid(() => sheet.insertCols(at, count));
    selection.selectCell(SmlCellRef(at.clamp(0, 16383), selection.focus.row));
    notifyListeners();
  }

  void deleteSheetRows({int? index, int count = 1}) {
    if (!config.allowsMutation || count <= 0) {
      return;
    }
    final SmlRange range = selection.range;
    final int minRow =
        range.start.row < range.end.row ? range.start.row : range.end.row;
    final int at = index ?? minRow;
    _mutateSheetGrid(() => sheet.deleteRows(at, count));
    selection.selectCell(
      SmlCellRef(selection.focus.col, at.clamp(0, 1048575)),
    );
    notifyListeners();
  }

  void deleteSheetCols({int? index, int count = 1}) {
    if (!config.allowsMutation || count <= 0) {
      return;
    }
    final SmlRange range = selection.range;
    final int minCol =
        range.start.col < range.end.col ? range.start.col : range.end.col;
    final int at = index ?? minCol;
    _mutateSheetGrid(() => sheet.deleteCols(at, count));
    selection.selectCell(
      SmlCellRef(at.clamp(0, 16383), selection.focus.row),
    );
    notifyListeners();
  }

  void _mutateSheetGrid(void Function() mutate) {
    final _SheetGridSnap snap = _SheetGridSnap.capture(sheet);
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          mutate();
          recalculateWorkbook();
        },
        undoFn: () {
          snap.restore(sheet);
          recalculateWorkbook();
        },
      ),
    );
  }

  void _clearCell(SmlCell cell) {
    final Object? prevValue = cell.value;
    final String? prevFormula = cell.formula;
    final SmlCellType prevType = cell.type;
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          cell.value = null;
          cell.formula = null;
          cell.type = SmlCellType.string;
        },
        undoFn: () {
          cell.value = prevValue;
          cell.formula = prevFormula;
          cell.type = prevType;
        },
      ),
    );
  }

  void beginCellEdit({String? initial, bool replace = false, int? caret}) {
    if (!config.allowsMutation) {
      return;
    }
    if (selectedDrawingIndex != null && initial == null) {
      cycleSelectedDrawingKind();
      return;
    }
    selectedDrawingIndex = null;
    _clearPoint();
    final SmlCell cell = sheet.cell(selection.focus);
    final String seed =
        initial ?? (replace ? '' : (cell.formula ?? cell.asString));
    cellEditor.begin(seed, caret: caret);
    _refreshFunctionSuggestions();
    notifyListeners();
  }

  bool get canPointEditRefs {
    if (!cellEditor.editing) {
      return false;
    }
    final String text = cellEditor.formulaBar.trimLeft();
    return text.isEmpty || text.startsWith('=');
  }

  /// Inserts or replaces a cell/range reference while the formula is open.
  void pointEditRef(SmlCellRef ref, {bool extend = false}) {
    if (!canPointEditRefs) {
      return;
    }
    final String lexeme = extend && _pointAnchor != null
        ? _refLexeme(_pointAnchor!, ref)
        : ref.a1;
    if (!extend) {
      _pointAnchor = ref;
    }
    final bool prefixEquals = cellEditor.formulaBar.isEmpty;
    final (int start, int end) = _pointReplaceRange();
    final String insert = prefixEquals ? '=$lexeme' : lexeme;
    _applyingPoint = true;
    cellEditor.replaceRange(start, end, insert);
    _applyingPoint = false;
    _pointStart = prefixEquals ? 1 : start;
    _pointEnd = _pointStart! + lexeme.length;
    notifyListeners();
  }

  void _onCellEditorChanged() {
    if (!_applyingPoint) {
      _clearPoint();
      _suppressFunctionSuggestions = false;
    }
    _refreshFunctionSuggestions();
    notifyListeners();
  }

  FormulaFnDoc? get highlightedFunction {
    if (functionSuggestions.isEmpty) {
      return null;
    }
    return functionSuggestions[
        functionSuggestionIndex.clamp(0, functionSuggestions.length - 1)];
  }

  void highlightFunctionSuggestion(int index) {
    if (functionSuggestions.isEmpty) {
      return;
    }
    functionSuggestionIndex =
        index.clamp(0, functionSuggestions.length - 1);
    notifyListeners();
  }

  void moveFunctionSuggestion(int delta) {
    if (functionSuggestions.isEmpty) {
      return;
    }
    highlightFunctionSuggestion(functionSuggestionIndex + delta);
  }

  void dismissFunctionSuggestions() {
    _suppressedFunctionPrefix = FormulaFunctionGuide.queryAt(
      cellEditor.formulaBar,
      cellEditor.caretIndex,
    )?.prefix;
    _suppressFunctionSuggestions = true;
    functionSuggestions = const <FormulaFnDoc>[];
    functionSuggestionIndex = 0;
    notifyListeners();
  }

  bool applyFunctionSuggestion([int? index]) {
    if (functionSuggestions.isEmpty) {
      return false;
    }
    final FormulaNameQuery? query = FormulaFunctionGuide.queryAt(
      cellEditor.formulaBar,
      cellEditor.caretIndex,
    );
    if (query == null) {
      return false;
    }
    final FormulaFnDoc doc = functionSuggestions[
        (index ?? functionSuggestionIndex)
            .clamp(0, functionSuggestions.length - 1)];
    cellEditor.replaceRange(query.start, query.end, '${doc.name}(');
    return true;
  }

  void deleteEditBackward() {
    if (cellEditor.editing) {
      cellEditor.deleteBackward();
    }
  }

  void deleteEditForward() {
    if (cellEditor.editing) {
      cellEditor.deleteForward();
    }
  }

  void _refreshFunctionSuggestions() {
    if (!cellEditor.editing) {
      functionSuggestions = const <FormulaFnDoc>[];
      functionSuggestionIndex = 0;
      return;
    }
    final FormulaNameQuery? query = FormulaFunctionGuide.queryAt(
      cellEditor.formulaBar,
      cellEditor.caretIndex,
    );
    if (query == null) {
      functionSuggestions = const <FormulaFnDoc>[];
      functionSuggestionIndex = 0;
      _suppressFunctionSuggestions = false;
      return;
    }
    if (_suppressFunctionSuggestions &&
        query.prefix == _suppressedFunctionPrefix) {
      functionSuggestions = const <FormulaFnDoc>[];
      return;
    }
    if (!_suppressFunctionSuggestions &&
        query.prefix != _suppressedFunctionPrefix) {
      functionSuggestionIndex = 0;
    }
    _suppressFunctionSuggestions = false;
    functionSuggestions = FormulaFunctionGuide.search(query.prefix);
    functionSuggestionIndex = functionSuggestionIndex.clamp(
      0,
      functionSuggestions.isEmpty ? 0 : functionSuggestions.length - 1,
    );
  }

  void _clearPoint() {
    _pointStart = null;
    _pointEnd = null;
    _pointAnchor = null;
  }

  (int, int) _pointReplaceRange() {
    if (cellEditor.hasSelection) {
      return (cellEditor.selectionStart, cellEditor.selectionEnd);
    }
    if (_pointStart != null && _pointEnd != null) {
      return (_pointStart!, _pointEnd!);
    }
    final String text = cellEditor.formulaBar;
    final int caret = cellEditor.caretIndex;
    for (final FormulaRefSpan span in FormulaRefScanner.scan(text)) {
      if (caret >= span.start && caret <= span.end) {
        return (span.start, span.end);
      }
    }
    return (caret, caret);
  }

  static String _refLexeme(SmlCellRef a, SmlCellRef b) {
    if (a.col == b.col && a.row == b.row) {
      return a.a1;
    }
    return '${a.a1}:${b.a1}';
  }

  void placeEditCaret(int index, {bool extend = false}) {
    if (!cellEditor.editing) {
      return;
    }
    cellEditor.setCaret(index, extend: extend);
  }

  void moveEditCaret(int delta, {bool extend = false}) {
    if (!cellEditor.editing) {
      return;
    }
    cellEditor.moveCaret(delta, extend: extend);
  }

  void commitCellEdit() {
    _clearPoint();
    functionSuggestions = const <FormulaFnDoc>[];
    cellEditor.end();
  }

  void cancelCellEdit() {
    if (!cellEditor.editing) {
      return;
    }
    _clearPoint();
    functionSuggestions = const <FormulaFnDoc>[];
    cellEditor.editing = false;
    cellEditor.bridge.detach();
    notifyListeners();
  }

  @override
  void detachInput() {
    if (cellEditor.editing) {
      cancelCellEdit();
    }
  }

  void _commitFormula(String text) {
    final SmlCell cell = sheet.cell(selection.focus);
    final Object? prevValue = cell.value;
    final String? prevFormula = cell.formula;
    final SmlCellType prevType = cell.type;
    commands.commit(
      _CallbackCommand(
        executeFn: () => _applyCellText(cell, text),
        undoFn: () {
          cell.value = prevValue;
          cell.formula = prevFormula;
          cell.type = prevType;
        },
      ),
    );
    recalculateWorkbook();
    notifyListeners();
  }

  void _applyCellText(SmlCell cell, String text) {
    FormulaEvaluator.applyInput(workbook, sheet, cell, text);
  }

  @override
  String get semanticsLabel {
    final SmlDrawing? drawing = selectedDrawing;
    if (drawing != null) {
      final String title = drawing.visual.title.isEmpty
          ? config.strings.pictureLabel
          : drawing.visual.title;
      return '${config.strings.sheetEditor}, $title';
    }
    return config.strings.sheetEditor;
  }

  @override
  String get semanticsValue {
    final SmlDrawing? drawing = selectedDrawing;
    if (drawing != null) {
      final OfficeVisual v = drawing.visual;
      return '${v.kind.name} ${v.width.round()}×${v.height.round()}. ${config.strings.pictureHint}';
    }
    return '${config.strings.cellLabel} ${selection.focus.a1} $formulaBarText';
  }
}

/// Presentation controller: slide index, shape selection, transforms.
class SlideEditorController extends OfficeController {
  SlideEditorController({
    PmlPresentation? presentation,
    super.config,
    this._activeSlide = 0,
  }) : presentation = presentation ?? PmlPresentation();

  factory SlideEditorController.fromBytes(
    Uint8List bytes, {
    String? password,
    OfficeSurfaceConfig? config,
  }) {
    final SlideEditorController controller = SlideEditorController(
      config: config,
    );
    controller.loadBytes(bytes, password: password);
    return controller;
  }

  PmlPresentation presentation;
  int _activeSlide;
  PmlShape? selected;
  int selectedTableRow = 0;
  int selectedTableCol = 0;
  int? _selectedAnimationIndex;
  PmlSlideShow? _show;
  String? _textBeforeEdit;
  late final InlineCellEditor textEditor = InlineCellEditor(
    onCommit: _commitShapeText,
    onChanged: _onShapeTextChanged,
    commitOnNewline: false,
  );

  int get activeSlideIndex => _activeSlide;

  String get speakerNotes => slide.notes;

  PmlSlide get slide {
    if (presentation.slides.isEmpty) {
      presentation.slides.add(PmlSlide(id: 256));
    }
    return presentation.slides[_activeSlide.clamp(
      0,
      presentation.slides.length - 1,
    )];
  }

  @override
  OpcPackageKind get kind => OpcPackageKind.slide;

  void loadBytes(Uint8List bytes, {String? password}) {
    _acceptOpenedPresentation(
      SlideDeserializer().read(
        OfficeRepair.open(bytes, password: password),
      ),
    );
  }

  Future<void> loadBytesAsync(
    Uint8List bytes, {
    String? password,
    void Function(OfficeOpenProgress progress)? onProgress,
  }) async {
    final PmlPresentation opened = await OfficeIsolateOpen.presentation(
      bytes,
      password: password,
      onProgress: onProgress,
    );
    _acceptOpenedPresentation(opened);
  }

  void _acceptOpenedPresentation(PmlPresentation opened) {
    presentation = opened;
    _activeSlide = 0;
    selected = null;
    selectedTableRow = 0;
    selectedTableCol = 0;
    _selectedAnimationIndex = null;
    endShow();
    _cancelTextEditSilent();
    _dirty = false;
    notifyListeners();
  }

  @override
  Uint8List saveBytes({String? password}) {
    final Uint8List bytes = SlideSerializer().writeBytes(
      presentation,
      password: password,
    );
    markClean();
    return bytes;
  }

  @override
  Future<Uint8List> saveBytesAsync({String? password}) {
    return OfficeIsolateSave.presentation(
      presentation,
      password: password,
    );
  }

  void setActiveSlide(int index) {
    if (textEditor.editing) {
      commitTextEdit();
    }
    _activeSlide = index.clamp(0, presentation.slides.length - 1);
    selected = null;
    _selectedAnimationIndex = null;
    notifyListeners();
  }

  void reorderSlide(int from, int to) {
    if (!config.allowsMutation) {
      return;
    }
    final List<PmlSlide> slides = presentation.slides;
    if (from < 0 ||
        to < 0 ||
        from >= slides.length ||
        to >= slides.length ||
        from == to) {
      return;
    }
    final int active = _activeSlide;
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          final PmlSlide slide = slides.removeAt(from);
          slides.insert(to, slide);
          _activeSlide = _indexAfterReorder(active, from, to);
        },
        undoFn: () {
          final PmlSlide slide = slides.removeAt(to);
          slides.insert(from, slide);
          _activeSlide = active.clamp(0, slides.length - 1);
        },
      ),
    );
    selected = null;
    _selectedAnimationIndex = null;
    notifyListeners();
  }

  void setSlideHidden(int index, bool hidden) {
    if (!config.allowsMutation) {
      return;
    }
    if (index < 0 || index >= presentation.slides.length) {
      return;
    }
    final PmlSlide target = presentation.slides[index];
    if (target.hidden == hidden) {
      return;
    }
    commands.commit(
      _CallbackCommand(
        executeFn: () => target.hidden = hidden,
        undoFn: () => target.hidden = !hidden,
      ),
    );
    notifyListeners();
  }

  void toggleSlideHidden(int index) {
    if (index < 0 || index >= presentation.slides.length) {
      return;
    }
    setSlideHidden(index, !presentation.slides[index].hidden);
  }

  static int _indexAfterReorder(int active, int from, int to) {
    if (active == from) {
      return to;
    }
    if (from < to && active > from && active <= to) {
      return active - 1;
    }
    if (from > to && active >= to && active < from) {
      return active + 1;
    }
    return active;
  }

  bool get isPlayingMotion => _show?.presenting == true;

  bool get isPreviewing =>
      _show?.presenting == true && (_show?.isPreview ?? false);

  bool get isPresenting =>
      _show?.presenting == true && !(_show?.isPreview ?? false);

  PmlSlideShow? get slideShow => _show;

  PmlShape? _restoreSelected;
  int? _restoreAnimationIndex;
  final ValueNotifier<int> motionFrame = ValueNotifier<int>(0);

  Map<int, PmlAnimSample> get showSamples {
    final PmlSlideShow? show = _show;
    if (show == null || !show.presenting) {
      return const <int, PmlAnimSample>{};
    }
    return <int, PmlAnimSample>{
      for (final PmlShape shape in show.currentSlide.shapes)
        shape.id: show.sample(shape.id),
    };
  }

  int? get selectedAnimationIndex {
    final int? index = _selectedAnimationIndex;
    if (index == null || index < 0 || index >= slide.animations.length) {
      return null;
    }
    return index;
  }

  PmlShapeAnimation? get selectedAnimation {
    final int? index = selectedAnimationIndex;
    if (index == null) {
      return null;
    }
    return slide.animations[index];
  }

  void startShow({int? from, bool withTransition = false}) {
    _beginShow(
      from: from,
      withTransition: withTransition,
    );
  }

  void previewTransition() {
    if (slide.transition.isNone) {
      return;
    }
    _beginShow(
      from: _activeSlide,
      withTransition: true,
      previewOnly: true,
      endAfterTransition: true,
    );
  }

  void previewAnimations() {
    if (slide.animations.isEmpty) {
      return;
    }
    _beginShow(
      from: _activeSlide,
      withTransition: false,
      previewOnly: true,
      autoPlayClicks: true,
    );
  }

  void previewAnimationAt(int index) {
    if (index < 0 || index >= slide.animations.length) {
      return;
    }
    _beginShow(
      from: _activeSlide,
      withTransition: false,
      previewOnly: true,
      autoPlayClicks: true,
      onlyAnimationIndex: index,
    );
  }

  void _beginShow({
    int? from,
    bool withTransition = false,
    bool previewOnly = false,
    bool endAfterTransition = false,
    bool autoPlayClicks = false,
    int? onlyAnimationIndex,
  }) {
    if (textEditor.editing) {
      commitTextEdit();
    }
    _show?.stop();
    _show = null;
    if (previewOnly) {
      _restoreSelected = selected;
      _restoreAnimationIndex = _selectedAnimationIndex;
    } else {
      _restoreSelected = null;
      _restoreAnimationIndex = null;
    }
    final int last = presentation.slides.isEmpty
        ? 0
        : presentation.slides.length - 1;
    final int index = (from ?? _activeSlide).clamp(0, last);
    _show = PmlSlideShow(presentation)
      ..start(
        from: index,
        withTransition: withTransition,
        previewOnly: previewOnly,
        endAfterTransition: endAfterTransition,
        autoPlayClicks: autoPlayClicks,
        onlyAnimationIndex: onlyAnimationIndex,
      );
    _activeSlide = _show!.slideIndex;
    if (!previewOnly) {
      selected = null;
    }
    notifyListeners();
  }

  void endShow() {
    if (_show == null) {
      return;
    }
    if (_show!.presenting || _show!.finished) {
      _activeSlide = _show!.slideIndex;
    }
    _show!.stop();
    _show = null;
    if (_restoreSelected != null) {
      selected = _restoreSelected;
      _selectedAnimationIndex = _restoreAnimationIndex;
    }
    _restoreSelected = null;
    _restoreAnimationIndex = null;
    notifyListeners();
  }

  void showNext() {
    final PmlSlideShow? show = _show;
    if (show == null) {
      return;
    }
    show.next();
    _activeSlide = show.slideIndex;
    if (show.finished) {
      endShow();
      return;
    }
    notifyListeners();
  }

  void showPrevious() {
    final PmlSlideShow? show = _show;
    if (show == null) {
      return;
    }
    show.previous();
    _activeSlide = show.slideIndex;
    notifyListeners();
  }

  void tickShow(int milliseconds) {
    final PmlSlideShow? show = _show;
    if (show == null || !show.presenting) {
      return;
    }
    final int slideBefore = show.slideIndex;
    show.elapse(milliseconds);
    _activeSlide = show.slideIndex;
    if (show.finished) {
      endShow();
      return;
    }
    if (show.slideIndex != slideBefore) {
      notifyListeners();
      return;
    }
    motionFrame.value++;
  }

  void setSlideTransition(
    PmlSlideTransition transition, {
    bool applyToAll = false,
    bool preview = true,
  }) {
    if (applyToAll) {
      for (final PmlSlide s in presentation.slides) {
        s.transition = transition;
      }
    } else {
      slide.transition = transition;
    }
    if (preview && !transition.isNone) {
      previewTransition();
      return;
    }
    notifyListeners();
  }

  void addShapeAnimation(
    PmlAnimPreset preset, {
    PmlAnimTrigger trigger = PmlAnimTrigger.onClick,
    PmlTransitionDir direction = PmlTransitionDir.left,
    int durationMs = 500,
  }) {
    final PmlShape? shape = selected;
    if (shape == null) {
      return;
    }
    slide.animations.add(
      PmlShapeAnimation(
        shapeId: shape.id,
        preset: preset,
        trigger: trigger,
        direction: direction,
        durationMs: durationMs,
        order: slide.animations.length,
      ),
    );
    _selectedAnimationIndex = slide.animations.length - 1;
    previewAnimationAt(_selectedAnimationIndex!);
  }

  void selectAnimation(int? index) {
    if (index == null || index < 0 || index >= slide.animations.length) {
      _selectedAnimationIndex = null;
      notifyListeners();
      return;
    }
    _selectedAnimationIndex = index;
    final int shapeId = slide.animations[index].shapeId;
    for (final PmlShape shape in slide.shapes) {
      if (shape.id == shapeId) {
        selected = shape;
        break;
      }
    }
    notifyListeners();
    previewAnimationAt(index);
  }

  void updateShapeAnimation(
    int index, {
    PmlAnimTrigger? trigger,
    PmlTransitionDir? direction,
    int? durationMs,
    int? delayMs,
  }) {
    if (index < 0 || index >= slide.animations.length) {
      return;
    }
    final PmlShapeAnimation anim = slide.animations[index];
    if (trigger != null) {
      anim.trigger = trigger;
    }
    if (direction != null) {
      anim.direction = direction;
    }
    if (durationMs != null) {
      anim.durationMs = durationMs;
    }
    if (delayMs != null) {
      anim.delayMs = delayMs;
    }
    notifyListeners();
  }

  void removeShapeAnimation(int index) {
    if (index < 0 || index >= slide.animations.length) {
      return;
    }
    slide.animations.removeAt(index);
    for (int i = 0; i < slide.animations.length; i++) {
      slide.animations[i].order = i;
    }
    if (_selectedAnimationIndex != null) {
      if (_selectedAnimationIndex == index) {
        _selectedAnimationIndex = slide.animations.isEmpty ? null : index.clamp(0, slide.animations.length - 1);
      } else if (_selectedAnimationIndex! > index) {
        _selectedAnimationIndex = _selectedAnimationIndex! - 1;
      }
    }
    notifyListeners();
  }

  void moveShapeAnimation(int index, int delta) {
    final int next = (index + delta).clamp(0, slide.animations.length - 1);
    if (next == index) {
      return;
    }
    final PmlShapeAnimation item = slide.animations.removeAt(index);
    slide.animations.insert(next, item);
    for (int i = 0; i < slide.animations.length; i++) {
      slide.animations[i].order = i;
    }
    notifyListeners();
  }

  void setAnimationTrigger(int index, PmlAnimTrigger trigger) {
    if (index < 0 || index >= slide.animations.length) {
      return;
    }
    slide.animations[index].trigger = trigger;
    notifyListeners();
  }

  void selectShape(PmlShape? shape) {
    if (!config.allowsSelection) {
      selected = null;
      notifyListeners();
      return;
    }
    if (textEditor.editing && !identical(selected, shape)) {
      commitTextEdit();
    }
    if (!identical(selected, shape)) {
      selectedTableRow = 0;
      selectedTableCol = 0;
    }
    selected = shape;
    notifyListeners();
  }

  void selectTableCell(PmlShape shape, int row, int col) {
    if (!config.allowsSelection) {
      return;
    }
    if (textEditor.editing && !identical(selected, shape)) {
      commitTextEdit();
    }
    selected = shape;
    final PmlTable? table = shape.table;
    if (table != null && table.rowCount > 0 && table.colCount > 0) {
      selectedTableRow = row.clamp(0, table.rowCount - 1);
      selectedTableCol = col.clamp(0, table.colCount - 1);
    }
    notifyListeners();
  }

  PmlTable? get selectedTable => selected?.table;

  int _nextSlideShapeId() {
    return slide.shapes.fold<int>(
          2,
          (int max, PmlShape s) => s.id > max ? s.id : max,
        ) +
        1;
  }

  void insertTable({int rows = 3, int cols = 3, bool arabic = false}) {
    if (!config.allowsMutation) {
      return;
    }
    final PmlShape shape = PmlShape(
      id: _nextSlideShapeId(),
      name: 'Table',
      fillColor: '',
      table: PmlTable.grid(
        rows: rows,
        cols: cols,
        header: true,
        arabic: arabic,
      ),
      transform: const PmlTransform(
        x: 600000,
        y: 1100000,
        cx: 7900000,
        cy: 2800000,
      ),
    );
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          slide.shapes.add(shape);
          selected = shape;
          selectedTableRow = 0;
          selectedTableCol = 0;
        },
        undoFn: () {
          slide.shapes.remove(shape);
          if (identical(selected, shape)) {
            selected = null;
          }
        },
      ),
    );
    notifyListeners();
  }

  void insertSelectedTableRow({required bool after}) {
    final PmlTable? table = selectedTable;
    if (table == null || !config.allowsMutation) {
      return;
    }
    final int index = (after ? selectedTableRow + 1 : selectedTableRow)
        .clamp(0, table.rowCount);
    final int cols = table.colCount < 1 ? 1 : table.colCount;
    final List<PmlTableCell> row = <PmlTableCell>[
      for (int c = 0; c < cols; c++)
        PmlTableCell(fillColor: 'FFFFFF', textColor: '1A1A1A'),
    ];
    final int prevRow = selectedTableRow;
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          table.rows.insert(index, row);
          selectedTableRow = index.clamp(0, table.rowCount - 1);
        },
        undoFn: () {
          table.rows.remove(row);
          selectedTableRow = prevRow.clamp(0, table.rowCount - 1);
        },
      ),
    );
    notifyListeners();
  }

  void insertSelectedTableColumn({required bool after}) {
    final PmlTable? table = selectedTable;
    if (table == null || !config.allowsMutation) {
      return;
    }
    final int index = (after ? selectedTableCol + 1 : selectedTableCol)
        .clamp(0, table.colCount);
    final int prevCol = selectedTableCol;
    final List<PmlTableCell> added = <PmlTableCell>[];
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          added.clear();
          for (final List<PmlTableCell> row in table.rows) {
            final PmlTableCell cell = PmlTableCell(
              fillColor: 'FFFFFF',
              textColor: '1A1A1A',
            );
            final int at = index.clamp(0, row.length);
            row.insert(at, cell);
            added.add(cell);
          }
          selectedTableCol = index;
        },
        undoFn: () {
          for (int i = 0; i < table.rows.length && i < added.length; i++) {
            table.rows[i].remove(added[i]);
          }
          selectedTableCol = prevCol.clamp(0, table.colCount - 1);
        },
      ),
    );
    notifyListeners();
  }

  void deleteSelectedTableRow() {
    final PmlTable? table = selectedTable;
    if (table == null || table.rowCount <= 1 || !config.allowsMutation) {
      return;
    }
    final int index = selectedTableRow.clamp(0, table.rowCount - 1);
    final List<PmlTableCell> row = table.rows[index];
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          table.rows.remove(row);
          selectedTableRow = index.clamp(0, table.rowCount - 1);
        },
        undoFn: () {
          table.rows.insert(index.clamp(0, table.rows.length), row);
          selectedTableRow = index;
        },
      ),
    );
    notifyListeners();
  }

  void deleteSelectedTableColumn() {
    final PmlTable? table = selectedTable;
    if (table == null || table.colCount <= 1 || !config.allowsMutation) {
      return;
    }
    final int index = selectedTableCol.clamp(0, table.colCount - 1);
    final List<PmlTableCell?> removed = <PmlTableCell?>[
      for (final List<PmlTableCell> row in table.rows)
        index < row.length ? row[index] : null,
    ];
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          for (final List<PmlTableCell> row in table.rows) {
            if (index < row.length) {
              row.removeAt(index);
            }
          }
          selectedTableCol = index.clamp(0, table.colCount - 1);
        },
        undoFn: () {
          for (int i = 0; i < table.rows.length; i++) {
            final PmlTableCell? cell = i < removed.length ? removed[i] : null;
            if (cell != null) {
              table.rows[i].insert(index.clamp(0, table.rows[i].length), cell);
            }
          }
          selectedTableCol = index;
        },
      ),
    );
    notifyListeners();
  }

  void moveSelectedTableCell({required bool forward}) {
    final PmlTable? table = selectedTable;
    if (table == null || table.rowCount == 0 || table.colCount == 0) {
      return;
    }
    if (textEditor.editing) {
      commitTextEdit();
    }
    var row = selectedTableRow;
    var col = selectedTableCol;
    if (forward) {
      col++;
      if (col >= table.colCount) {
        col = 0;
        row++;
        if (row >= table.rowCount) {
          insertSelectedTableRow(after: true);
          row = table.rowCount - 1;
        }
      }
    } else {
      col--;
      if (col < 0) {
        col = table.colCount - 1;
        row--;
        if (row < 0) {
          row = 0;
          col = 0;
        }
      }
    }
    selectedTableRow = row.clamp(0, table.rowCount - 1);
    selectedTableCol = col.clamp(0, table.colCount - 1);
    beginTextEdit();
  }

  bool get editingText => textEditor.editing;

  void beginTextEdit({String? initial, bool replace = false, int? caret}) {
    final PmlShape? shape = selected;
    if (shape == null || shape.visual != null || !config.allowsMutation) {
      return;
    }
    if (shape.table != null) {
      final PmlTableCell cell = shape.table!.cellAt(
        selectedTableRow,
        selectedTableCol,
      );
      _textBeforeEdit = cell.text;
      final String seed = initial ?? (replace ? '' : cell.text);
      cell.text = seed;
      textEditor.begin(seed, caret: caret, multiline: true);
      notifyListeners();
      return;
    }
    _textBeforeEdit = shape.text;
    final String seed = initial ?? (replace ? '' : shape.text);
    shape.text = seed;
    textEditor.begin(seed, caret: caret, multiline: true);
    notifyListeners();
  }

  @override
  void selectAll() {
    if (!config.allowsSelection) {
      return;
    }
    if (textEditor.editing) {
      textEditor.selectAll();
      notifyListeners();
      return;
    }
    if (slide.shapes.isEmpty) {
      selected = null;
    } else {
      selected = slide.shapes.last;
    }
    notifyListeners();
  }

  @override
  bool get canCopy => selected != null || textEditor.editing;

  @override
  Future<void> copyToClipboard() async {
    final OfficeClipboardPayload payload = _captureSlideClipboard();
    if (payload.isEmpty) {
      return;
    }
    await OfficeClipboard.instance.write(payload);
  }

  @override
  Future<void> cutToClipboard() async {
    if (!canCut) {
      return;
    }
    await copyToClipboard();
    if (textEditor.editing) {
      _replaceSlideEditorSelection('');
      return;
    }
    deleteSelectedShape();
  }

  @override
  Future<void> pasteFromClipboard({
    OfficePasteMode mode = OfficePasteMode.keepSource,
  }) async {
    if (!canPaste) {
      return;
    }
    final OfficeClipboardPayload payload = await OfficeClipboard.instance.read();
    if (payload.isEmpty) {
      return;
    }
    if (textEditor.editing) {
      _replaceSlideEditorSelection(payload.plain);
      return;
    }
    if (mode != OfficePasteMode.keepTextOnly && payload.shape != null) {
      _pasteSlideShape(payload.shape!);
      return;
    }
    if (mode != OfficePasteMode.keepTextOnly && payload.visual != null) {
      _pasteSlideVisual(payload.visual!);
      return;
    }
    if (selected != null && selected!.visual == null) {
      final PmlShape shape = selected!;
      if (mode == OfficePasteMode.keepTextOnly || !payload.plain.contains('\n')) {
        updateSelected(text: payload.plain);
        return;
      }
      shape.text = payload.plain;
      notifyListeners();
      return;
    }
    if (payload.plain.isEmpty) {
      return;
    }
    _pasteSlideTextBox(payload.plain);
  }

  OfficeClipboardPayload _captureSlideClipboard() {
    if (textEditor.editing) {
      final String text = textEditor.hasSelection
          ? textEditor.formulaBar.substring(
              textEditor.selectionStart,
              textEditor.selectionEnd,
            )
          : textEditor.formulaBar;
      return OfficeClipboardPayload.fromPlain(text);
    }
    final PmlShape? shape = selected;
    if (shape == null) {
      return OfficeClipboardPayload.empty();
    }
    return OfficeClipboardPayload(
      kind: OfficeClipboardKind.shape,
      plain: shape.text,
      shape: cloneClipboardShape(shape, nudgeEmu: 0),
      visual: shape.visual?.copy(),
    );
  }

  void _replaceSlideEditorSelection(String insert) {
    final String text = textEditor.formulaBar;
    final int start = textEditor.selectionStart;
    final int end = textEditor.selectionEnd;
    final String next = text.replaceRange(start, end, insert);
    textEditor.formulaBar = next;
    textEditor.caretIndex = start + insert.length;
    textEditor.selectionBase = textEditor.caretIndex;
    if (selected != null) {
      selected!.text = next;
    }
    textEditor.bridge.setValue(
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: textEditor.caretIndex),
      ),
    );
    notifyListeners();
  }

  void _pasteSlideShape(PmlShape source) {
    final int nextId = slide.shapes.fold<int>(
      2,
      (int max, PmlShape s) => s.id > max ? s.id : max,
    ) + 1;
    final PmlShape clone = cloneClipboardShape(source, id: nextId);
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          slide.shapes.add(clone);
          selected = clone;
        },
        undoFn: () {
          slide.shapes.remove(clone);
          if (identical(selected, clone)) {
            selected = source;
          }
        },
      ),
    );
    notifyListeners();
  }

  void _pasteSlideVisual(OfficeVisual visual) {
    final int nextId = slide.shapes.fold<int>(
      2,
      (int max, PmlShape s) => s.id > max ? s.id : max,
    ) + 1;
    final PmlShape shape = PmlShape(
      id: nextId,
      name: visual.title,
      transform: const PmlTransform(x: 1270000, y: 762000, cx: 4572000, cy: 2286000),
      visual: visual.copy(),
    );
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          slide.shapes.add(shape);
          selected = shape;
        },
        undoFn: () {
          slide.shapes.remove(shape);
          if (identical(selected, shape)) {
            selected = null;
          }
        },
      ),
    );
    notifyListeners();
  }

  void _pasteSlideTextBox(String text) {
    final int nextId = slide.shapes.fold<int>(
      2,
      (int max, PmlShape s) => s.id > max ? s.id : max,
    ) + 1;
    final PmlShape shape = PmlShape(
      id: nextId,
      name: 'Text',
      transform: const PmlTransform(x: 1270000, y: 1270000, cx: 4572000, cy: 1270000),
      text: text,
      fillColor: '4472C4',
    );
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          slide.shapes.add(shape);
          selected = shape;
        },
        undoFn: () {
          slide.shapes.remove(shape);
          if (identical(selected, shape)) {
            selected = null;
          }
        },
      ),
    );
    notifyListeners();
  }

  void commitTextEdit() {
    if (!textEditor.editing) {
      return;
    }
    textEditor.end();
  }

  void cancelTextEdit() {
    if (!textEditor.editing) {
      return;
    }
    final PmlShape? shape = selected;
    if (shape != null && _textBeforeEdit != null) {
      shape.text = _textBeforeEdit!;
    }
    _cancelTextEditSilent();
    notifyListeners();
  }

  void placeTextCaret(int index, {bool extend = false}) {
    if (!textEditor.editing) {
      return;
    }
    textEditor.setCaret(index, extend: extend);
    notifyListeners();
  }

  void selectTextWordAt(int index) {
    if (!textEditor.editing) {
      return;
    }
    textEditor.selectWord(index);
    notifyListeners();
  }

  void selectTextParagraphAt(int index) {
    if (!textEditor.editing) {
      return;
    }
    textEditor.selectParagraph(index);
    notifyListeners();
  }

  void moveTextCaret(int delta, {bool extend = false}) {
    if (!textEditor.editing) {
      return;
    }
    textEditor.moveCaret(delta, extend: extend);
  }

  void deleteSelectedShape() {
    if (textEditor.editing) {
      return;
    }
    final PmlShape? shape = selected;
    if (shape == null || !config.allowsMutation) {
      return;
    }
    final List<PmlShape> shapes = slide.shapes;
    final int index = shapes.indexOf(shape);
    if (index < 0) {
      return;
    }
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          shapes.remove(shape);
          slide.animations.removeWhere(
            (PmlShapeAnimation a) => a.shapeId == shape.id,
          );
          selected = null;
          _selectedAnimationIndex = null;
        },
        undoFn: () {
          if (!shapes.contains(shape)) {
            shapes.insert(index.clamp(0, shapes.length), shape);
          }
          selected = shape;
        },
      ),
    );
    notifyListeners();
  }

  void _onShapeTextChanged() {
    final PmlShape? shape = selected;
    if (shape != null && textEditor.editing) {
      if (shape.table != null) {
        shape.table!.cellAt(selectedTableRow, selectedTableCol).text =
            textEditor.formulaBar;
      } else {
        shape.text = textEditor.formulaBar;
      }
    }
    notifyListeners();
  }

  void _commitShapeText(String text) {
    final PmlShape? shape = selected;
    final String prev = _textBeforeEdit ?? text;
    _textBeforeEdit = null;
    textEditor.editing = false;
    if (shape == null) {
      return;
    }
    if (shape.table != null) {
      final PmlTableCell cell = shape.table!.cellAt(
        selectedTableRow,
        selectedTableCol,
      );
      cell.text = text;
      if (prev == text) {
        notifyListeners();
        return;
      }
      commands.commit(
        _CallbackCommand(
          executeFn: () => cell.text = text,
          undoFn: () => cell.text = prev,
        ),
      );
      notifyListeners();
      return;
    }
    shape.text = text;
    if (prev == text) {
      notifyListeners();
      return;
    }
    commands.commit(
      _CallbackCommand(
        executeFn: () => shape.text = text,
        undoFn: () => shape.text = prev,
      ),
    );
    notifyListeners();
  }

  void _cancelTextEditSilent() {
    if (textEditor.editing) {
      textEditor.editing = false;
      textEditor.bridge.detach();
    }
    _textBeforeEdit = null;
  }

  void nudgeSelected(int dxEmu, int dyEmu) {
    final PmlShape? shape = selected;
    if (shape == null || !config.allowsMutation) {
      return;
    }
    applyTransform(
      shape,
      PmlTransform(
        x: shape.transform.x + dxEmu,
        y: shape.transform.y + dyEmu,
        cx: shape.transform.cx,
        cy: shape.transform.cy,
        rot: shape.transform.rot,
      ),
    );
  }

  void updateSelected({String? text, String? fillColor, double? fontSizePt}) {
    final PmlShape? shape = selected;
    if (shape == null || !config.allowsMutation) {
      return;
    }
    final String prevText = shape.text;
    final String prevFill = shape.fillColor;
    final double prevSize = shape.fontSizePt;
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          if (text != null) {
            shape.text = text;
          }
          if (fillColor != null) {
            shape.fillColor = fillColor;
          }
          if (fontSizePt != null) {
            shape.fontSizePt = fontSizePt;
          }
        },
        undoFn: () {
          shape.text = prevText;
          shape.fillColor = prevFill;
          shape.fontSizePt = prevSize;
        },
      ),
    );
    notifyListeners();
  }

  void setSelectedTextDirection({required bool rtl}) {
    final PmlShape? shape = selected;
    if (shape == null || shape.visual != null || !config.allowsMutation) {
      return;
    }
    final bool? prevRtl = shape.rightToLeft;
    final PmlTextAlign prevAlign = shape.textAlign;
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          shape.rightToLeft = rtl;
          shape.textAlign = rtl ? PmlTextAlign.right : PmlTextAlign.left;
        },
        undoFn: () {
          shape.rightToLeft = prevRtl;
          shape.textAlign = prevAlign;
        },
      ),
    );
    notifyListeners();
  }

  void setSelectedTextAlign(PmlTextAlign align) {
    final PmlShape? shape = selected;
    if (shape == null || shape.visual != null || !config.allowsMutation) {
      return;
    }
    final PmlTextAlign prev = shape.textAlign;
    commands.commit(
      _CallbackCommand(
        executeFn: () => shape.textAlign = align,
        undoFn: () => shape.textAlign = prev,
      ),
    );
    notifyListeners();
  }

  void mutateSelectedShapeVisual(void Function(OfficeVisual visual) edit) {
    final OfficeVisual? visual = selected?.visual;
    if (visual == null || !config.allowsMutation) {
      return;
    }
    final OfficeVisual before = visual.copy();
    edit(visual);
    final OfficeVisual after = visual.copy();
    commands.commit(
      _CallbackCommand(
        executeFn: () => visual.restoreFrom(after),
        undoFn: () => visual.restoreFrom(before),
      ),
    );
    notifyListeners();
  }

  void reorderSelected({required bool forward}) {
    final PmlShape? shape = selected;
    if (shape == null || !config.allowsMutation) {
      return;
    }
    final List<PmlShape> shapes = slide.shapes;
    final int index = shapes.indexOf(shape);
    if (index < 0) {
      return;
    }
    final int next = forward ? index + 1 : index - 1;
    if (next < 0 || next >= shapes.length) {
      return;
    }
    commands.commit(
      _CallbackCommand(
        executeFn: () {
          shapes.removeAt(index);
          shapes.insert(next, shape);
        },
        undoFn: () {
          final int now = shapes.indexOf(shape);
          if (now >= 0) {
            shapes.removeAt(now);
            shapes.insert(index, shape);
          }
        },
      ),
    );
    notifyListeners();
  }

  void applyTransform(PmlShape shape, PmlTransform next) {
    if (!config.allowsMutation) {
      return;
    }
    final PmlTransform prev = shape.transform;
    commands.commit(
      _CallbackCommand(
        executeFn: () => shape.transform = next,
        undoFn: () => shape.transform = prev,
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    motionFrame.dispose();
    super.dispose();
  }

  @override
  void detachInput() {
    if (textEditor.editing) {
      cancelTextEdit();
    }
  }

  @override
  String get semanticsLabel => config.strings.slideEditor;

  @override
  String get semanticsValue {
    final PmlShape? shape = selected;
    if (shape == null) {
      return '${config.strings.pageLabel} ${_activeSlide + 1}';
    }
    return '${config.strings.shapeLabel} ${shape.name} ${shape.text}';
  }
}

class _HeadingSnap {
  _HeadingSnap({
    required this.headingLevel,
    required this.styleId,
    required this.spacingBefore,
    required this.spacingAfter,
    required this.keepTogether,
    required this.inlines,
  });

  factory _HeadingSnap.capture(WmlParagraph paragraph) {
    return _HeadingSnap(
      headingLevel: paragraph.properties.headingLevel,
      styleId: paragraph.properties.styleId,
      spacingBefore: paragraph.properties.spacingBefore,
      spacingAfter: paragraph.properties.spacingAfter,
      keepTogether: paragraph.properties.keepTogether,
      inlines: WordEditorController._cloneInlines(paragraph),
    );
  }

  final int? headingLevel;
  final String? styleId;
  final double spacingBefore;
  final double spacingAfter;
  final bool keepTogether;
  final List<WmlInline> inlines;

  void restore(WmlParagraph paragraph) {
    paragraph.properties
      ..headingLevel = headingLevel
      ..styleId = styleId
      ..spacingBefore = spacingBefore
      ..spacingAfter = spacingAfter
      ..keepTogether = keepTogether;
    paragraph.inlines
      ..clear()
      ..addAll(WordEditorController._cloneInlinesFrom(inlines));
  }
}

class _SheetGridSnap {
  _SheetGridSnap._({
    required this.cells,
    required this.widths,
    required this.heights,
  });

  factory _SheetGridSnap.capture(SmlWorksheet sheet) {
    return _SheetGridSnap._(
      cells: <SmlCell>[
        for (final SmlCell cell in sheet.allCells)
          SmlCell(
            ref: cell.ref,
            type: cell.type,
            value: cell.value,
            formula: cell.formula,
            styleIndex: cell.styleIndex,
          ),
      ],
      widths: Map<int, double>.from(sheet.columnWidths),
      heights: Map<int, double>.from(sheet.rowHeights),
    );
  }

  final List<SmlCell> cells;
  final Map<int, double> widths;
  final Map<int, double> heights;

  void restore(SmlWorksheet sheet) {
    sheet.rows.clear();
    for (final SmlCell cell in cells) {
      final SmlCell target = sheet.cell(cell.ref);
      target
        ..type = cell.type
        ..value = cell.value
        ..formula = cell.formula
        ..styleIndex = cell.styleIndex;
    }
    sheet.columnWidths
      ..clear()
      ..addAll(widths);
    sheet.rowHeights
      ..clear()
      ..addAll(heights);
  }
}

class _CallbackCommand implements OfficeCommand {
  _CallbackCommand({required this.executeFn, required this.undoFn});

  final void Function() executeFn;
  final void Function() undoFn;

  @override
  void execute() => executeFn();

  @override
  void undo() => undoFn();

  @override
  OfficeCommand invert() =>
      _CallbackCommand(executeFn: undoFn, undoFn: executeFn);
}
