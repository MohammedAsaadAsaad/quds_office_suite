import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

import 'sample_library.dart';
import 'studio_chrome.dart';
import 'studio_files.dart';
import 'studio_find_pane.dart';
import 'studio_pdf_gallery.dart';
import 'studio_pdf_gallery_dialog.dart';
import 'studio_pdf_tools.dart';
import 'studio_pdf_surface.dart';
import 'studio_window.dart';

enum SuiteApp { word, excel, powerpoint, pdf }

enum SuiteLook { light, dark, highContrast }

enum _SavePhase { idle, picking, saving }

enum _WordLinkKind { web, bookmark, file }

enum _RibbonTab {
  file,
  home,
  insert,
  layout,
  review,
  formulas,
  data,
  design,
  transitions,
  animations,
  view,
}

class SuiteWorkspace extends StatefulWidget {
  const SuiteWorkspace({super.key});

  @override
  State<SuiteWorkspace> createState() => _SuiteWorkspaceState();
}

class _SuiteWorkspaceState extends State<SuiteWorkspace> {
  SuiteApp _app = SuiteApp.word;
  SuiteLook _look = SuiteLook.light;
  OfficeInteractionMode _mode = OfficeInteractionMode.editing;
  _RibbonTab _tab = _RibbonTab.home;
  var _arabic = true;
  var _wordRulers = true;
  var _sheetGridlines = true;
  var _sheetHeaders = true;
  var _slideHandles = true;
  var _showNotes = true;
  var _showComments = true;
  var _showAnimPane = true;
  var _showPasteOptions = false;
  final GlobalKey _settingsButtonKey = GlobalKey();
  final GlobalKey _accountButtonKey = GlobalKey();
  final FocusNode _wordFocus = FocusNode(debugLabel: 'studio-word');
  final FocusNode _sheetFocus = FocusNode(debugLabel: 'studio-sheet');
  final FocusNode _slideFocus = FocusNode(debugLabel: 'studio-slide');

  late final WordEditorController _word;
  late final SheetEditorController _sheet;
  late final SlideEditorController _slides;
  late final PdfEditorController _pdf;
  final TextEditingController _commentReply = TextEditingController();
  final TextEditingController _pdfFind = TextEditingController();
  Timer? _pdfFindDebounce;
  final TextEditingController _slideNotesEdit = TextEditingController();
  int _notesSlideIndex = -1;
  final VirtualViewport _commentViewport = VirtualViewport();
  OverlayEntry? _commentContextMenu;
  OverlayEntry? _slideSorterMenu;
  var _savePhase = _SavePhase.idle;
  var _saveHeavy = false;
  var _saveProgress = 0.0;
  Timer? _saveTicker;
  var _opening = false;
  var _openHeavy = false;
  var _openProgress = 0.0;
  var _openStage = 'archive';
  String _openName = '';
  Timer? _openTicker;
  String? _wordPath;
  String? _sheetPath;
  String? _slidePath;
  String _wordName = 'Al Tahreer Neighbourhood Profile.docx';
  String _sheetName = 'Budget.xlsx';
  String _slideName = 'Studio deck.pptx';
  String? _pdfPath;
  String _pdfName = 'Studio.pdf';
  late final StudioPdfViewerEvents _pdfEvents;
  var _pdfNightMode = false;
  var _pdfSwipeHorizontal = false;
  var _pdfPageSnap = true;
  var _pdfPageFling = true;
  var _pdfEnableSwipe = true;
  var _pdfShowScroll = true;
  var _pdfPreventLinks = false;
  PdfFitPolicy _pdfFitPolicy = PdfFitPolicy.width;
  StudioPdfSampleKind _galleryKind = StudioPdfSampleKind.templates;
  String _galleryGroup = StudioPdfGallery.templateGroups.first;
  String? _gallerySampleId;

  OfficeSurfaceConfig? _cachedConfig;
  Object? _configKey;
  var _rebuildScheduled = false;
  var _slideshowFullscreen = false;
  var _findOpen = false;
  var _pdfSideTab = 0; // 0 thumbs, 1 outline
  final ScrollController _pdfThumbScroll = ScrollController();
  int _pdfThumbSyncedPage = -1;
  final Set<String> _pdfOutlineExpanded = <String>{};
  var _findReplace = false;
  var _printPreview = false;

  @override
  void initState() {
    super.initState();
    _pdfEvents = StudioPdfViewerEvents(
      onChanged: () {
        if (!mounted) {
          return;
        }
        scheduleMicrotask(() {
          if (mounted) {
            setState(() {});
          }
        });
      },
    );
    _word = WordEditorController(document: SampleLibrary.wordBriefing());
    _word.onFollowExternalLink = _openExternalLink;
    _sheet = SheetEditorController(workbook: SampleLibrary.excelBudget());
    _slides = SlideEditorController(presentation: SampleLibrary.slideDeck());
    _pdf = PdfEditorController.fromBytes(studioSamplePdf());
    _bindHostActions(_word);
    _bindHostActions(_sheet);
    _bindHostActions(_slides);
    _slides.onPlayMedia = (PmlShape shape) {
      _toast(
        _arabic ? 'تشغيل ${shape.mediaName}' : 'Playing ${shape.mediaName}',
      );
    };
    _word.addListener(_rebuild);
    _sheet.addListener(_rebuild);
    _slides.addListener(_rebuild);
    _pdf.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StudioWindow.setTitle('$_chromeTitle — Quds Office Studio');
    });
  }

  void _rebuild() {
    if (!mounted || _rebuildScheduled) {
      return;
    }
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) {
        setState(() {
          if (_app == SuiteApp.word &&
              _tab == _RibbonTab.design &&
              _word.selectedEquation == null) {
            _tab = _RibbonTab.insert;
          }
        });
        StudioWindow.setTitle('$_chromeTitle — Quds Office Studio');
        _syncSlideshowFullscreen();
      }
    });
  }

  void _syncSlideshowFullscreen() {
    final bool want = _app == SuiteApp.powerpoint && _slides.isPresenting;
    if (want == _slideshowFullscreen) {
      return;
    }
    _slideshowFullscreen = want;
    StudioWindow.setFullScreen(want);
  }

  OfficeController get _active => switch (_app) {
    SuiteApp.word => _word,
    SuiteApp.excel => _sheet,
    SuiteApp.powerpoint => _slides,
    SuiteApp.pdf => _word,
  };

  Color get _accent => switch (_app) {
    SuiteApp.word => const Color(0xFF2B579A),
    SuiteApp.excel => const Color(0xFF217346),
    SuiteApp.powerpoint => const Color(0xFFB7472A),
    SuiteApp.pdf => const Color(0xFFC0392B),
  };

  OfficeTheme get _officeTheme {
    const String arabicBody = 'Tajawal';
    return switch (_look) {
      SuiteLook.light => OfficeTheme.light.copyWith(
        focusRing: _accent,
        fontFamily: arabicBody,
      ),
      SuiteLook.dark => OfficeTheme.dark.copyWith(
        focusRing: _accent,
        fontFamily: arabicBody,
      ),
      SuiteLook.highContrast => OfficeTheme.highContrast.copyWith(
        fontFamily: arabicBody,
      ),
    };
  }

  OfficeSurfaceConfig get _config {
    final Object key = (
      _app,
      _look,
      _mode,
      _arabic,
      _wordRulers,
      _sheetGridlines,
      _sheetHeaders,
      _slideHandles,
    );
    if (_cachedConfig != null && _configKey == key) {
      return _cachedConfig!;
    }
    _configKey = key;
    _cachedConfig = OfficeSurfaceConfig(
      mode: _mode,
      theme: _officeTheme,
      showRulers: _app == SuiteApp.word && _wordRulers,
      showFormulaBar: false,
      showGridHeaders: _sheetHeaders,
      showGridlines: _sheetGridlines,
      showSlideHandles: _slideHandles,
      textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
      strings: _arabic ? OfficeStrings.arabic : OfficeStrings.english,
      formFactor: OfficeFormFactor.automatic,
      density: OfficeDensity.comfortable,
      adaptiveChrome: true,
      interactiveRulers: _wordRulers,
      showNotesPane: _app == SuiteApp.word,
    );
    return _cachedConfig!;
  }

  bool get _canMutate => _mode == OfficeInteractionMode.editing && !_opening;

  @override
  void dispose() {
    _word
      ..removeListener(_rebuild)
      ..dispose();
    _sheet
      ..removeListener(_rebuild)
      ..dispose();
    _slides
      ..removeListener(_rebuild)
      ..dispose();
    _pdf
      ..removeListener(_rebuild)
      ..dispose();
    _commentReply.dispose();
    _pdfFindDebounce?.cancel();
    _pdfFind.dispose();
    _pdfThumbScroll.dispose();
    _slideNotesEdit.dispose();
    _wordFocus.dispose();
    _sheetFocus.dispose();
    _slideFocus.dispose();
    _saveTicker?.cancel();
    _openTicker?.cancel();
    OfficeContextMenu.dismiss(_commentContextMenu);
    _commentContextMenu = null;
    OfficeContextMenu.dismiss(_slideSorterMenu);
    _slideSorterMenu = null;
    if (_slideshowFullscreen) {
      StudioWindow.setFullScreen(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = _look != SuiteLook.light;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyY, meta: true): _redo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _redo,
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            _selectAll,
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true): _selectAll,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): _copy,
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true): _copy,
        const SingleActivator(LogicalKeyboardKey.keyX, control: true): _cut,
        const SingleActivator(LogicalKeyboardKey.keyX, meta: true): _cut,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _paste,
        const SingleActivator(
          LogicalKeyboardKey.keyV,
          control: true,
          shift: true,
        ): () =>
            _pasteMode(OfficePasteMode.keepTextOnly),
        const SingleActivator(
          LogicalKeyboardKey.keyV,
          meta: true,
          shift: true,
        ): () =>
            _pasteMode(OfficePasteMode.keepTextOnly),
        const SingleActivator(LogicalKeyboardKey.f5): _slideShowFromStart,
        const SingleActivator(LogicalKeyboardKey.f5, shift: true):
            _slideShowFromCurrent,
        const SingleActivator(LogicalKeyboardKey.escape): _workspaceEscape,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _openFind,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _openFind,
        const SingleActivator(LogicalKeyboardKey.keyH, control: true):
            _openReplace,
        const SingleActivator(LogicalKeyboardKey.keyH, meta: true):
            _openReplace,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
            _exportPdf,
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true): _exportPdf,
        const SingleActivator(LogicalKeyboardKey.f3): _findNext,
        const SingleActivator(LogicalKeyboardKey.f3, shift: true):
            _findPrevious,
        const SingleActivator(LogicalKeyboardKey.f1): _openPdfSampleGallery,
        const SingleActivator(LogicalKeyboardKey.f7): _showSpelling,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            _toggleBold,
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): _toggleBold,
        const SingleActivator(LogicalKeyboardKey.keyI, control: true):
            _toggleItalic,
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
            _toggleItalic,
        const SingleActivator(LogicalKeyboardKey.keyU, control: true):
            _toggleUnderline,
        const SingleActivator(LogicalKeyboardKey.keyU, meta: true):
            _toggleUnderline,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _saveFile,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _saveFile,
        const SingleActivator(LogicalKeyboardKey.equal, control: true):
            _shortcutZoomIn,
        const SingleActivator(LogicalKeyboardKey.equal, meta: true):
            _shortcutZoomIn,
        const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true):
            _shortcutZoomIn,
        const SingleActivator(LogicalKeyboardKey.add, control: true):
            _shortcutZoomIn,
        const SingleActivator(LogicalKeyboardKey.minus, control: true):
            _shortcutZoomOut,
        const SingleActivator(LogicalKeyboardKey.minus, meta: true):
            _shortcutZoomOut,
        const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true):
            _shortcutZoomOut,
        const SingleActivator(LogicalKeyboardKey.digit0, control: true):
            _shortcutZoomReset,
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
            _shortcutZoomReset,
      },
      child: StudioWindowScope(
        onChanged: () {
          if (mounted) {
            setState(() {});
          }
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: _onWorkspaceDirectionKey,
          child: Directionality(
            textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
            child: _app == SuiteApp.powerpoint && _slides.isPresenting
                ? ColoredBox(
                    color: const Color(0xFF000000),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: QudsSlideEditor(
                            controller: _slides,
                            focusNode: _slideFocus,
                            config: _config,
                          ),
                        ),
                        SizedBox(width: 260, child: _presenterPane()),
                      ],
                    ),
                  )
                : Scaffold(
                    backgroundColor: dark
                        ? const Color(0xFF1B1B1B)
                        : const Color(0xFFE8E8E8),
                    body: Column(
                      children: <Widget>[
                        _titleBar(),
                        _tabStrip(dark),
                        _ribbon(dark),
                        if (_showPasteOptions) _pasteOptionsBar(dark),
                        Expanded(child: _body(dark)),
                        _statusBar(),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _slideShowFromStart() {
    if (_app != SuiteApp.powerpoint) {
      return;
    }
    if (_slides.isPresenting) {
      _slides.endShow();
      return;
    }
    if (_slides.isPreviewing) {
      _slides.endShow();
    }
    _slides.startShow(from: 0);
    _slides.startPresenter();
  }

  void _slideShowFromCurrent() {
    if (_app != SuiteApp.powerpoint) {
      return;
    }
    if (_slides.isPresenting) {
      _slides.endShow();
      return;
    }
    if (_slides.isPreviewing) {
      _slides.endShow();
    }
    _slides.startShow(from: _slides.activeSlideIndex);
    _slides.startPresenter();
  }

  void _slideShowEscape() {
    if (_app == SuiteApp.powerpoint &&
        (_slides.isPresenting || _slides.isPreviewing)) {
      _slides.endShow();
    }
  }

  void _toggleBold() {
    if (!_canMutate || _app != SuiteApp.word) {
      return;
    }
    _word.applyRunFormat((WmlRunProps p) => p.bold = !p.bold);
  }

  void _toggleItalic() {
    if (!_canMutate || _app != SuiteApp.word) {
      return;
    }
    _word.applyRunFormat((WmlRunProps p) => p.italic = !p.italic);
  }

  void _toggleUnderline() {
    if (!_canMutate || _app != SuiteApp.word) {
      return;
    }
    _word.applyRunFormat((WmlRunProps p) {
      p.underline = p.underline == WmlUnderline.none
          ? WmlUnderline.single
          : WmlUnderline.none;
    });
  }

  void _undo() => _active.undo();

  void _redo() => _active.redo();

  void _selectAll() {
    if (_app == SuiteApp.pdf) {
      _pdf.selectAll();
      return;
    }
    _active.selectAll();
  }

  void _copy() {
    _active.copyToClipboard();
  }

  void _cut() {
    if (!_canMutate) {
      return;
    }
    _active.cutToClipboard();
  }

  void _paste() => _pasteMode(OfficePasteMode.keepSource);

  Future<void> _pasteMode(OfficePasteMode mode) async {
    if (!_canMutate) {
      return;
    }
    await _active.pasteFromClipboard(mode: mode);
    if (mounted) {
      setState(() => _showPasteOptions = true);
    }
  }

  Widget _titleBar() {
    return Material(
      color: _accent,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 36,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              StudioDragRegion(
                onDoubleTap: StudioWindow.toggleMaximize,
                child: const SizedBox.expand(),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(left: 10, right: 4),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.auto_awesome_mosaic,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Quds Office Studio',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _titleQuickAccess(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: <Widget>[
                        StudioAppSwitcher(
                          label: 'Word',
                          icon: Icons.description_outlined,
                          selected: _app == SuiteApp.word,
                          onTap: () => _switchApp(SuiteApp.word),
                        ),
                        StudioAppSwitcher(
                          label: 'Excel',
                          icon: Icons.grid_on_outlined,
                          selected: _app == SuiteApp.excel,
                          onTap: () => _switchApp(SuiteApp.excel),
                        ),
                        StudioAppSwitcher(
                          label: 'PowerPoint',
                          icon: Icons.slideshow_outlined,
                          selected: _app == SuiteApp.powerpoint,
                          onTap: () => _switchApp(SuiteApp.powerpoint),
                        ),
                        StudioAppSwitcher(
                          label: 'PDF',
                          icon: Icons.picture_as_pdf_outlined,
                          selected: _app == SuiteApp.pdf,
                          onTap: () => _switchApp(SuiteApp.pdf),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: IgnorePointer(
                      child: Align(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            _documentLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.94),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: _settingsButtonKey,
                    tooltip: _arabic ? 'الإعدادات' : 'Settings',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 36,
                    ),
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    onPressed: _openSettings,
                  ),
                  IconButton(
                    key: _accountButtonKey,
                    tooltip: _arabic ? 'الحساب' : 'Account',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 36,
                    ),
                    icon: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                    onPressed: _openAccount,
                  ),
                  if (StudioWindow.supported) const SizedBox(width: 138),
                ],
              ),
              if (StudioWindow.supported)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      StudioCaptionButton(
                        icon: Icons.minimize,
                        tooltip: _arabic ? 'تصغير' : 'Minimize',
                        onPressed: StudioWindow.minimize,
                      ),
                      StudioCaptionButton(
                        icon: StudioWindow.maximized
                            ? Icons.filter_none
                            : Icons.crop_square,
                        tooltip: StudioWindow.maximized
                            ? (_arabic ? 'استعادة' : 'Restore')
                            : (_arabic ? 'تكبير' : 'Maximize'),
                        onPressed: StudioWindow.toggleMaximize,
                      ),
                      StudioCaptionButton(
                        icon: Icons.close,
                        tooltip: _arabic ? 'إغلاق' : 'Close',
                        onPressed: StudioWindow.close,
                        close: true,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleQuickAccess() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _titleQat(
          Icons.save_outlined,
          _arabic ? 'حفظ' : 'Save',
          _isSaving || _opening ? null : _saveFile,
        ),
        _titleQat(
          Icons.undo,
          _arabic ? 'تراجع' : 'Undo',
          _canMutate && _active.canUndo ? _undo : null,
        ),
        _titleQat(
          Icons.redo,
          _arabic ? 'إعادة' : 'Redo',
          _canMutate && _active.canRedo ? _redo : null,
        ),
      ],
    );
  }

  Widget _titleQat(IconData icon, String tooltip, VoidCallback? onPressed) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      icon: Icon(
        icon,
        size: 15,
        color: onPressed == null ? Colors.white54 : Colors.white,
      ),
      onPressed: onPressed,
    );
  }

  String get _chromeTitle {
    final String app = switch (_app) {
      SuiteApp.word => 'Word',
      SuiteApp.excel => 'Excel',
      SuiteApp.powerpoint => 'PowerPoint',
      SuiteApp.pdf => 'PDF',
    };
    return '$_documentLabel — $app';
  }

  String get _documentLabel {
    final String name = switch (_app) {
      SuiteApp.word => _wordName,
      SuiteApp.excel => _sheetName,
      SuiteApp.powerpoint => _slideName,
      SuiteApp.pdf => _pdfName,
    };
    final String clean = name.trim().isEmpty ? _untitledName : name.trim();
    final bool dirty = _app == SuiteApp.pdf ? _pdf.isDirty : _active.isDirty;
    return dirty ? '$clean*' : clean;
  }

  String get _untitledName => switch (_app) {
    SuiteApp.word => 'Document1.docx',
    SuiteApp.excel => 'Book1.xlsx',
    SuiteApp.powerpoint => 'Presentation1.pptx',
    SuiteApp.pdf => 'Document.pdf',
  };

  String get _activeName => switch (_app) {
    SuiteApp.word => _wordName,
    SuiteApp.excel => _sheetName,
    SuiteApp.powerpoint => _slideName,
    SuiteApp.pdf => _pdfName,
  };

  set _activeName(String value) {
    switch (_app) {
      case SuiteApp.word:
        _wordName = value;
      case SuiteApp.excel:
        _sheetName = value;
      case SuiteApp.powerpoint:
        _slideName = value;
      case SuiteApp.pdf:
        _pdfName = value;
    }
  }

  String _nameFromPicked(PickedOfficeFile picked) {
    if (picked.name.trim().isNotEmpty) {
      return picked.name.trim();
    }
    final String? path = picked.path;
    if (path != null && path.isNotEmpty) {
      return StudioFiles.nameOf(path);
    }
    return _untitledName;
  }

  void _switchApp(SuiteApp app) {
    setState(() {
      _app = app;
      _tab = app == SuiteApp.pdf ? _RibbonTab.view : _RibbonTab.home;
    });
    StudioWindow.setTitle('$_chromeTitle — Quds Office Studio');
  }

  RelativeRect _menuRectFor(GlobalKey key) {
    final BuildContext? buttonContext = key.currentContext;
    final RenderBox? button = buttonContext?.findRenderObject() as RenderBox?;
    final RenderBox? overlay =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (button == null || !button.hasSize || overlay == null) {
      return RelativeRect.fromLTRB(
        MediaQuery.sizeOf(context).width - 220,
        36,
        8,
        8,
      );
    }
    final Offset topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    return RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    );
  }

  void _openSettings() {
    showMenu<String>(
      context: context,
      position: _menuRectFor(_settingsButtonKey),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'mode',
          child: Text('${_arabic ? 'الوضع' : 'Mode'}: $_modeLabel'),
        ),
        PopupMenuItem<String>(
          value: 'look',
          child: Text('${_arabic ? 'المظهر' : 'Look'}: $_lookLabel'),
        ),
        PopupMenuItem<String>(
          value: 'lang',
          child: Text(_arabic ? 'English' : 'العربية'),
        ),
      ],
    ).then((String? value) {
      if (value == 'mode') {
        _cycleMode();
      } else if (value == 'look') {
        setState(() {
          _look = SuiteLook.values[(_look.index + 1) % SuiteLook.values.length];
        });
      } else if (value == 'lang') {
        _toggleArabic();
      }
    });
  }

  void _toggleArabic() {
    setState(() => _arabic = !_arabic);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // syncConfig runs in editor didUpdateWidget; re-focus so IME / caret return.
      if (_app == SuiteApp.word) {
        _wordFocus.requestFocus();
        if (_canMutate) {
          _word.attachInput();
        }
      } else if (_app == SuiteApp.excel) {
        _sheetFocus.requestFocus();
      } else {
        _slideFocus.requestFocus();
      }
    });
  }

  void _openAccount() {
    showMenu<String>(
      context: context,
      position: _menuRectFor(_accountButtonKey),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Text(_arabic ? 'حساب محلي' : 'Local account'),
        ),
      ],
    );
  }

  String get _modeLabel => switch (_mode) {
    OfficeInteractionMode.editing => _arabic ? 'تحرير' : 'Editing',
    OfficeInteractionMode.selecting => _arabic ? 'تحديد' : 'Selecting',
    OfficeInteractionMode.viewing => _arabic ? 'عرض' : 'Viewing',
  };

  String get _lookLabel => switch (_look) {
    SuiteLook.light => _arabic ? 'فاتح' : 'Light',
    SuiteLook.dark => _arabic ? 'داكن' : 'Dark',
    SuiteLook.highContrast => _arabic ? 'تباين' : 'Contrast',
  };

  void _cycleMode() {
    setState(() {
      _mode = switch (_mode) {
        OfficeInteractionMode.editing => OfficeInteractionMode.selecting,
        OfficeInteractionMode.selecting => OfficeInteractionMode.viewing,
        OfficeInteractionMode.viewing => OfficeInteractionMode.editing,
      };
    });
  }

  List<_RibbonTab> get _tabsForApp => switch (_app) {
    SuiteApp.word => <_RibbonTab>[
      _RibbonTab.file,
      _RibbonTab.home,
      _RibbonTab.insert,
      if (_word.selectedEquation != null) _RibbonTab.design,
      _RibbonTab.layout,
      _RibbonTab.review,
      _RibbonTab.view,
    ],
    SuiteApp.excel => const <_RibbonTab>[
      _RibbonTab.file,
      _RibbonTab.home,
      _RibbonTab.insert,
      _RibbonTab.formulas,
      _RibbonTab.data,
      _RibbonTab.view,
    ],
    SuiteApp.powerpoint => const <_RibbonTab>[
      _RibbonTab.file,
      _RibbonTab.home,
      _RibbonTab.insert,
      _RibbonTab.design,
      _RibbonTab.transitions,
      _RibbonTab.animations,
      _RibbonTab.view,
    ],
    SuiteApp.pdf => const <_RibbonTab>[
      _RibbonTab.file,
      _RibbonTab.view,
      _RibbonTab.review,
      _RibbonTab.insert,
    ],
  };

  String _tabLabel(_RibbonTab tab) => switch (tab) {
    _RibbonTab.file => _arabic ? 'ملف' : 'File',
    _RibbonTab.home => _arabic ? 'الرئيسية' : 'Home',
    _RibbonTab.insert =>
      _app == SuiteApp.pdf
          ? (_arabic ? 'نموذج' : 'Form')
          : (_arabic ? 'إدراج' : 'Insert'),
    _RibbonTab.layout => _arabic ? 'تخطيط' : 'Layout',
    _RibbonTab.review =>
      _app == SuiteApp.pdf
          ? (_arabic ? 'تعليق' : 'Annotate')
          : (_arabic ? 'مراجعة' : 'Review'),
    _RibbonTab.formulas => _arabic ? 'صيغ' : 'Formulas',
    _RibbonTab.data => _arabic ? 'بيانات' : 'Data',
    _RibbonTab.design =>
      _app == SuiteApp.word
          ? (_arabic ? 'معادلة' : 'Equation')
          : (_arabic ? 'تصميم' : 'Design'),
    _RibbonTab.transitions => _arabic ? 'انتقالات' : 'Transitions',
    _RibbonTab.animations => _arabic ? 'حركات' : 'Animations',
    _RibbonTab.view => _arabic ? 'عرض' : 'View',
  };

  Widget _tabStrip(bool dark) {
    return Material(
      color: dark ? const Color(0xFF2A2A2A) : Colors.white,
      child: SizedBox(
        height: 36,
        child: Row(
          children: <Widget>[
            const SizedBox(width: 4),
            for (final _RibbonTab tab in _tabsForApp)
              StudioTabChip(
                label: _tabLabel(tab),
                selected: _tab == tab,
                accent: _accent,
                onTap: () => setState(() => _tab = tab),
              ),
            const Spacer(),
            StudioIconCmd(
              icon: Icons.undo,
              tooltip: _arabic ? 'تراجع' : 'Undo',
              accent: _accent,
              foreground: _officeTheme.chromeText,
              onPressed:
                  _canMutate &&
                      (_app == SuiteApp.pdf ? _pdf.canUndo : _active.canUndo)
                  ? (_app == SuiteApp.pdf ? _pdf.undo : _active.undo)
                  : null,
            ),
            StudioIconCmd(
              icon: Icons.redo,
              tooltip: _arabic ? 'إعادة' : 'Redo',
              accent: _accent,
              foreground: _officeTheme.chromeText,
              onPressed:
                  _canMutate &&
                      (_app == SuiteApp.pdf ? _pdf.canRedo : _active.canRedo)
                  ? (_app == SuiteApp.pdf ? _pdf.redo : _active.redo)
                  : null,
            ),
            StudioIconCmd(
              icon: Icons.translate,
              tooltip: _arabic ? 'English' : 'العربية',
              accent: _accent,
              foreground: _officeTheme.chromeText,
              onPressed: _toggleArabic,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _ribbon(bool dark) {
    return Material(
      color: dark ? const Color(0xFF2A2A2A) : Colors.white,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _accent.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
        ),
        child: SizedBox(
          height: 72,
          child: StudioRibbonStrip(groups: _ribbonGroups()),
        ),
      ),
    );
  }

  List<StudioRibbonGroup> _ribbonGroups() {
    return switch ((_app, _tab)) {
      (SuiteApp.word, _RibbonTab.file) => _fileGroups(_resetWord, _newWord),
      (SuiteApp.word, _RibbonTab.home) => _wordHome(),
      (SuiteApp.word, _RibbonTab.insert) => _wordInsert(),
      (SuiteApp.word, _RibbonTab.design) => _wordEquationTools(),
      (SuiteApp.word, _RibbonTab.layout) => _wordLayout(),
      (SuiteApp.word, _RibbonTab.review) => _wordReview(),
      (SuiteApp.word, _RibbonTab.view) => _wordView(),
      (SuiteApp.excel, _RibbonTab.file) => _fileGroups(_resetSheet, _newSheet),
      (SuiteApp.excel, _RibbonTab.home) => _sheetHome(),
      (SuiteApp.excel, _RibbonTab.insert) => _sheetInsert(),
      (SuiteApp.excel, _RibbonTab.formulas) => _sheetFormulas(),
      (SuiteApp.excel, _RibbonTab.data) => _sheetData(),
      (SuiteApp.excel, _RibbonTab.view) => _sheetView(),
      (SuiteApp.powerpoint, _RibbonTab.file) => _fileGroups(
        _resetSlides,
        _newSlides,
      ),
      (SuiteApp.powerpoint, _RibbonTab.home) => _slideHome(),
      (SuiteApp.powerpoint, _RibbonTab.insert) => _slideInsert(),
      (SuiteApp.powerpoint, _RibbonTab.design) => _slideDesign(),
      (SuiteApp.powerpoint, _RibbonTab.transitions) => _slideTransitions(),
      (SuiteApp.powerpoint, _RibbonTab.animations) => _slideAnimations(),
      (SuiteApp.powerpoint, _RibbonTab.view) => _slideView(),
      (SuiteApp.pdf, _RibbonTab.file) => _pdfFileGroups(),
      (SuiteApp.pdf, _RibbonTab.review) => _pdfAnnotate(),
      (SuiteApp.pdf, _RibbonTab.insert) => _pdfForm(),
      (SuiteApp.pdf, _) => _pdfView(),
      _ => _fileGroups(_resetWord, _newWord),
    };
  }

  void _resetPdf() {
    _pdf.loadBytesAsync(studioSamplePdf());
    _pdfPath = null;
    _pdfName = 'Studio.pdf';
  }

  void _newPdf() {
    _pdf.loadBytesAsync(studioSamplePdf());
    _pdfPath = null;
    _pdfName = 'Document.pdf';
  }

  List<StudioRibbonGroup> _pdfFileGroups() {
    return <StudioRibbonGroup>[
      ..._fileGroups(_resetPdf, _newPdf),
      StudioRibbonGroup(
        title: _arabic ? 'عينات تجريبية' : 'Sample lab',
        children: <Widget>[
          _cmd(
            Icons.auto_awesome,
            _arabic ? 'معرض PDF (F1)' : 'PDF gallery (F1)',
            _opening || _isSaving ? null : _openPdfSampleGallery,
          ),
          _cmd(
            Icons.build_circle_outlined,
            _arabic ? 'أدوات PDF' : 'PDF tools',
            _opening || _isSaving ? null : _openPdfTools,
          ),
        ],
      ),
    ];
  }

  Future<void> _openPdfSampleGallery() async {
    if (_opening || _isSaving) {
      return;
    }
    final StudioPdfSample? sample = await showDialog<StudioPdfSample>(
      context: context,
      builder: (BuildContext context) {
        return PdfSampleGalleryDialog(
          arabic: _arabic,
          accent: _accent,
          initialKind: _galleryKind,
          initialGroup: _galleryGroup,
          initialSampleId: _gallerySampleId,
        );
      },
    );
    if (sample == null || !mounted) {
      return;
    }
    await _loadPdfSample(sample);
  }

  Future<void> _openPdfTools() async {
    final Uint8List current = _pdf.saveBytes();
    final PdfToolOutput? output = await showDialog<PdfToolOutput>(
      context: context,
      builder: (BuildContext context) {
        return PdfToolsLabDialog(
          arabic: _arabic,
          accent: _accent,
          currentBytes: current.isEmpty ? null : current,
          currentName: _pdfName,
        );
      },
    );
    if (output == null || !mounted) {
      return;
    }
    _switchApp(SuiteApp.pdf);
    await _pdf.loadBytesAsync(output.bytes);
    if (!mounted) {
      return;
    }
    setState(() {
      _pdfPath = null;
      _pdfName = output.name;
      _pdfThumbSyncedPage = -1;
    });
  }

  Future<void> _loadPdfSample(StudioPdfSample sample) async {
    setState(() {
      _opening = true;
      _openHeavy = true;
      _openProgress = 0.08;
      _openStage = 'sample';
      _openName = sample.fileName;
    });
    _openTicker?.cancel();
    _openTicker = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted || !_opening) {
        return;
      }
      setState(() {
        _openProgress = (_openProgress + 0.04).clamp(0.0, 0.92);
      });
    });
    try {
      await SampleLibrary.preload();
      final OfficeFontSet fontSet = sample.id == 'office-tahreer-word'
          ? StudioFiles.exportFontSetForWord(SampleLibrary.wordBriefing())
          : StudioFiles.exportFontSetCovering(<String>[
              sample.titleEn,
              sample.blurbEn,
              'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz',
              'حي التحرير التعافي',
            ]);
      final SfntFont? font = fontSet.primary ?? StudioFiles.latinExportFont();
      final Uint8List bytes = await Future<Uint8List>(() {
        return sample.build(font: font, fonts: fontSet);
      });
      final Directory dir = Directory(
        '${Directory.systemTemp.path}/quds_pdf_samples',
      )..createSync(recursive: true);
      final File file = File('${dir.path}/${sample.fileName}');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) {
        return;
      }
      _switchApp(SuiteApp.pdf);
      await _pdf.loadBytesAsync(bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _pdfPath = file.path;
        _pdfName = sample.fileName;
        _pdfThumbSyncedPage = -1;
        _openProgress = 1;
        _galleryKind = sample.kind;
        if (sample.group.isNotEmpty) {
          _galleryGroup = sample.group;
        }
        _gallerySampleId = sample.id;
      });
    } catch (error, stack) {
      debugPrint('PDF sample failed: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _arabic ? 'تعذّر إنشاء العينة: $error' : 'Sample failed: $error',
            ),
          ),
        );
      }
    } finally {
      _openTicker?.cancel();
      _openTicker = null;
      if (mounted) {
        setState(() {
          _opening = false;
          _openHeavy = false;
          _openProgress = 0;
          _openStage = 'archive';
          _openName = '';
        });
      }
    }
  }

  PdfViewerOptions get _pdfViewerOptions => studioPdfViewerOptions(
    nightMode: _pdfNightMode,
    swipeHorizontal: _pdfSwipeHorizontal,
    pageSnap: _pdfPageSnap,
    pageFling: _pdfPageFling,
    enableSwipe: _pdfEnableSwipe,
    showScrollIndicators: _pdfShowScroll,
    preventLinkNavigation: _pdfPreventLinks,
    fitPolicy: _pdfFitPolicy,
    backgroundColor: _pdfNightMode ? const Color(0xFF121212) : null,
  );

  void _togglePdfOption(void Function() mutate, {String? toast}) {
    setState(mutate);
    if (toast != null) {
      _toast(toast);
    }
  }

  List<StudioRibbonGroup> _pdfView() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'عرض' : 'View',
        children: <Widget>[
          _cmd(Icons.zoom_in, _arabic ? 'تكبير' : 'Zoom in', () {
            _pdf.zoomBy(1.1);
          }),
          _cmd(Icons.zoom_out, _arabic ? 'تصغير' : 'Zoom out', () {
            _pdf.zoomBy(1 / 1.1);
          }),
          _cmd(Icons.fit_screen_outlined, _arabic ? 'عرض' : 'Fit width', () {
            _togglePdfOption(() {
              _pdfFitPolicy = PdfFitPolicy.width;
              _pdf.fitVisibleWidth();
            });
          }, selected: _pdfFitPolicy == PdfFitPolicy.width),
          _cmd(Icons.aspect_ratio, _arabic ? 'صفحة' : 'Fit page', () {
            _togglePdfOption(() {
              _pdfFitPolicy = PdfFitPolicy.page;
              final Size e = _pdf.viewport.extent;
              _pdf.fitPage(
                e.width > 0 ? e.width : 720,
                e.height > 0 ? e.height : 900,
              );
            });
          }, selected: _pdfFitPolicy == PdfFitPolicy.page),
          _cmd(Icons.height, _arabic ? 'ارتفاع' : 'Fit height', () {
            _togglePdfOption(() {
              _pdfFitPolicy = PdfFitPolicy.height;
              final double h = _pdf.viewport.extent.height;
              _pdf.fitHeight(h > 0 ? h : 900);
            });
          }, selected: _pdfFitPolicy == PdfFitPolicy.height),
          _cmd(Icons.search, _arabic ? 'بحث' : 'Find', _openFind),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'خيارات العارض' : 'Viewer options',
        children: <Widget>[
          _cmd(
            Icons.dark_mode_outlined,
            _arabic ? 'ليلي' : 'Night',
            () => _togglePdfOption(
              () => _pdfNightMode = !_pdfNightMode,
              toast: _pdfNightMode
                  ? (_arabic ? 'الوضع الليلي مغلق' : 'Night mode off')
                  : (_arabic ? 'الوضع الليلي مفعّل' : 'Night mode on'),
            ),
            selected: _pdfNightMode,
          ),
          _cmd(
            Icons.swap_horiz,
            _arabic ? 'أفقي' : 'Horizontal',
            () => _togglePdfOption(
              () => _pdfSwipeHorizontal = !_pdfSwipeHorizontal,
              toast: _pdfSwipeHorizontal
                  ? (_arabic ? 'تمرير عمودي' : 'Vertical swipe')
                  : (_arabic ? 'تمرير أفقي' : 'Horizontal swipe'),
            ),
            selected: _pdfSwipeHorizontal,
          ),
          _cmd(
            Icons.align_vertical_top,
            _arabic ? 'محاذاة' : 'Page snap',
            () => _togglePdfOption(() => _pdfPageSnap = !_pdfPageSnap),
            selected: _pdfPageSnap,
          ),
          _cmd(
            Icons.speed,
            _arabic ? 'زخم' : 'Fling',
            () => _togglePdfOption(() => _pdfPageFling = !_pdfPageFling),
            selected: _pdfPageFling,
          ),
          _cmd(
            Icons.pan_tool_alt,
            _arabic ? 'سحب' : 'Swipe',
            () => _togglePdfOption(() => _pdfEnableSwipe = !_pdfEnableSwipe),
            selected: _pdfEnableSwipe,
          ),
          _cmd(
            Icons.linear_scale,
            _arabic ? 'شريط' : 'Scrollbar',
            () => _togglePdfOption(() => _pdfShowScroll = !_pdfShowScroll),
            selected: _pdfShowScroll,
          ),
          _cmd(
            Icons.link_off,
            _arabic ? 'منع رابط' : 'Block links',
            () => _togglePdfOption(
              () => _pdfPreventLinks = !_pdfPreventLinks,
              toast: _pdfPreventLinks
                  ? (_arabic ? 'فتح الروابط مسموح' : 'Link open allowed')
                  : (_arabic
                        ? 'الروابط تُبلَّغ فقط دون فتح'
                        : 'Links reported only'),
            ),
            selected: _pdfPreventLinks,
          ),
        ],
      ),
    ];
  }

  Widget _pdfFindBar(bool dark) {
    final int total = _pdf.findMarks.length;
    final int current = total == 0 || _pdf.findIndex < 0
        ? 0
        : _pdf.findIndex + 1;
    final String status = _pdfFind.text.isEmpty
        ? ''
        : total == 0
        ? (_arabic ? 'لا نتائج' : 'No matches')
        : (_arabic ? '$current من $total' : '$current of $total');
    return Material(
      elevation: 4,
      color: dark ? const Color(0xFF2A2A2A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _pdfFind,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _arabic ? 'بحث في PDF' : 'Find in PDF',
                  border: const OutlineInputBorder(),
                ),
                onChanged: _schedulePdfFind,
                onSubmitted: (_) => _pdfFindNext(),
              ),
            ),
            if (status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(status),
              ),
            IconButton(
              tooltip: _arabic ? 'السابق' : 'Previous',
              onPressed: total == 0 ? null : _pdfFindPrevious,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: _arabic ? 'التالي' : 'Next',
              onPressed: total == 0 ? null : _pdfFindNext,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(onPressed: _closeFind, icon: const Icon(Icons.close)),
          ],
        ),
      ),
    );
  }

  void _schedulePdfFind(String query) {
    _pdfFindDebounce?.cancel();
    _pdfFindDebounce = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) {
        return;
      }
      _pdf.find(query);
      setState(() {});
    });
  }

  void _pdfFindNext() {
    if (_pdf.findMarks.isEmpty) {
      _pdf.find(_pdfFind.text);
    } else {
      _pdf.findNext();
    }
    setState(() {});
  }

  void _pdfFindPrevious() {
    if (_pdf.findMarks.isEmpty) {
      _pdf.find(_pdfFind.text);
    } else {
      _pdf.findPrevious();
    }
    setState(() {});
  }

  List<StudioRibbonGroup> _pdfAnnotate() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'تعليق' : 'Annotate',
        children: <Widget>[
          _cmd(Icons.highlight_outlined, _arabic ? 'تمييز' : 'Highlight', () {
            _pdf.highlightSelection();
          }),
          _cmd(Icons.sticky_note_2_outlined, _arabic ? 'ملاحظة' : 'Note', () {
            _pdf.addNote(
              const PdfRect(x: 72, y: 72, width: 24, height: 24),
              _arabic ? 'ملاحظة' : 'Note',
            );
          }),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _pdfForm() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'صفحات' : 'Pages',
        children: <Widget>[
          _cmd(Icons.note_add_outlined, _arabic ? 'صفحة' : 'Blank page', () {
            _pdf.insertBlankPage(_pdf.pageIndex + 1);
          }),
          _cmd(Icons.rotate_right, _arabic ? 'تدوير' : 'Rotate', () {
            _pdf.rotateCurrentPage(90);
          }),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _fileGroups(
    VoidCallback reset,
    VoidCallback createNew,
  ) {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'ملف' : 'File',
        children: <Widget>[
          _cmd(Icons.note_add_outlined, _arabic ? 'جديد' : 'New', createNew),
          _cmd(
            Icons.folder_open,
            _arabic ? 'فتح' : 'Open',
            _opening || _isSaving ? null : _openFile,
          ),
          _cmd(
            Icons.save_outlined,
            _arabic ? 'حفظ' : 'Save',
            _isSaving || _opening ? null : _saveFile,
          ),
          _cmd(
            Icons.picture_as_pdf_outlined,
            _arabic ? 'تصدير PDF' : 'Export PDF',
            _exportPdf,
          ),
          _cmd(
            Icons.refresh,
            _arabic ? 'إعادة العينة' : 'Reload sample',
            reset,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'وضع العمل' : 'Mode',
        children: <Widget>[
          _cmd(
            Icons.edit,
            _arabic ? 'تحرير' : 'Edit',
            () {
              setState(() => _mode = OfficeInteractionMode.editing);
            },
            selected: _mode == OfficeInteractionMode.editing,
          ),
          _cmd(
            Icons.select_all,
            _arabic ? 'تحديد' : 'Select',
            () {
              setState(() => _mode = OfficeInteractionMode.selecting);
            },
            selected: _mode == OfficeInteractionMode.selecting,
          ),
          _cmd(
            Icons.visibility,
            _arabic ? 'عرض' : 'View',
            () {
              setState(() => _mode = OfficeInteractionMode.viewing);
            },
            selected: _mode == OfficeInteractionMode.viewing,
          ),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _wordHome() {
    return <StudioRibbonGroup>[
      _clipboardGroup(),
      StudioRibbonGroup(
        title: _arabic ? 'خط' : 'Font',
        children: <Widget>[
          StudioCombo<String>(
            value: _activeFontFamily,
            items: _fontFamilies,
            labelOf: (String name) => name,
            previewFamily: (String name) => name,
            width: 148,
            enabled: _wordFullFormat,
            tooltip: _arabic ? 'الخط' : 'Font',
            onSelected: _wordFullFormat ? _setFontFamily : null,
          ),
          const SizedBox(width: 4),
          StudioCombo<int>(
            value: _activeFontSizePt,
            items: OfficeTypeface.sizesPt,
            labelOf: (int pt) => '$pt',
            width: 52,
            enabled: _wordFullFormat,
            tooltip: _arabic ? 'الحجم' : 'Size',
            onSelected: _wordFullFormat ? _setFontSizePt : null,
          ),
          const SizedBox(width: 4),
          StudioCombo<StudioFaceStyle>(
            value: _activeFaceStyle,
            items: StudioFaceStyle.values,
            labelOf: _faceStyleLabel,
            width: 88,
            enabled: _canMutate,
            tooltip: _arabic ? 'النوع' : 'Style',
            onSelected: _canMutate ? _setFaceStyle : null,
          ),
          const SizedBox(width: 6),
          _icon(
            Icons.format_bold,
            _arabic ? 'عريض' : 'Bold',
            _canMutate
                ? () =>
                      _word.applyRunFormat((WmlRunProps p) => p.bold = !p.bold)
                : null,
            selected: _word.activeRunProps.bold,
          ),
          _icon(
            Icons.format_italic,
            _arabic ? 'مائل' : 'Italic',
            _canMutate
                ? () => _word.applyRunFormat(
                    (WmlRunProps p) => p.italic = !p.italic,
                  )
                : null,
            selected: _word.activeRunProps.italic,
          ),
          _icon(
            Icons.format_underline,
            _arabic ? 'تسطير' : 'Underline',
            _canMutate
                ? () => _word.applyRunFormat((WmlRunProps p) {
                    p.underline = p.underline == WmlUnderline.none
                        ? WmlUnderline.single
                        : WmlUnderline.none;
                  })
                : null,
            selected: _word.activeRunProps.underline == WmlUnderline.single,
          ),
          _icon(
            Icons.format_strikethrough,
            _arabic ? 'يتوسطه خط' : 'Strike',
            _canMutate
                ? () => _word.applyRunFormat(
                    (WmlRunProps p) => p.strike = !p.strike,
                  )
                : null,
            selected: _word.activeRunProps.strike,
          ),
          _icon(
            Icons.superscript,
            _arabic ? 'مرتفع' : 'Superscript',
            _wordFullFormat
                ? () => _toggleVertAlign(WmlVertAlign.superscript)
                : null,
            selected:
                _word.activeRunProps.vertAlign == WmlVertAlign.superscript,
          ),
          _icon(
            Icons.subscript,
            _arabic ? 'منخفض' : 'Subscript',
            _wordFullFormat
                ? () => _toggleVertAlign(WmlVertAlign.subscript)
                : null,
            selected: _word.activeRunProps.vertAlign == WmlVertAlign.subscript,
          ),
          _icon(
            Icons.format_color_text,
            _arabic ? 'لون النص' : 'Text color',
            _canMutate ? _cycleTextColor : null,
          ),
          _icon(
            Icons.border_color,
            _arabic ? 'تمييز' : 'Highlight',
            _canMutate ? _cycleHighlight : null,
          ),
          _icon(
            Icons.text_increase,
            _arabic ? 'تكبير' : 'Grow',
            _wordFullFormat ? () => _nudgeFontSize(2) : null,
          ),
          _icon(
            Icons.text_decrease,
            _arabic ? 'تصغير' : 'Shrink',
            _wordFullFormat ? () => _nudgeFontSize(-2) : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'أنماط' : 'Styles',
        children: <Widget>[
          StudioCombo<int>(
            value: _word.activeHeadingLevel,
            items: const <int>[0, 1, 2, 3, 4],
            labelOf: _headingStyleLabel,
            width: 118,
            enabled: _wordFullFormat,
            tooltip: _arabic ? 'نمط الفقرة' : 'Paragraph style',
            onSelected: _wordFullFormat ? _word.applyHeading : null,
          ),
          const SizedBox(width: 4),
          StudioCombo<String>(
            value: WordStyles.ofParagraph(_activeParagraph).id,
            items: <String>[
              for (final WmlStyle style in WordStyles.catalog) style.id,
            ],
            labelOf: (String id) =>
                WordStyles.byId(id)?.label(arabic: _arabic) ?? id,
            width: 132,
            enabled: _wordFullFormat,
            tooltip: _arabic ? 'معرض الأنماط' : 'Style gallery',
            onSelected: _wordFullFormat ? _word.applyStyle : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'فقرة' : 'Paragraph',
        children: <Widget>[
          _icon(
            Icons.format_align_left,
            _arabic ? 'يسار' : 'Left',
            _wordFullFormat ? () => _setAlign(WmlJustification.left) : null,
            selected:
                _activeParagraph.properties.justification ==
                WmlJustification.left,
          ),
          _icon(
            Icons.format_align_center,
            _arabic ? 'وسط' : 'Center',
            _wordFullFormat ? () => _setAlign(WmlJustification.center) : null,
            selected:
                _activeParagraph.properties.justification ==
                WmlJustification.center,
          ),
          _icon(
            Icons.format_align_right,
            _arabic ? 'يمين' : 'Right',
            _wordFullFormat ? () => _setAlign(WmlJustification.right) : null,
            selected:
                _activeParagraph.properties.justification ==
                WmlJustification.right,
          ),
          _icon(
            Icons.format_align_justify,
            _arabic ? 'ضبط' : 'Justify',
            _wordFullFormat ? () => _setAlign(WmlJustification.justify) : null,
            selected:
                _activeParagraph.properties.justification ==
                WmlJustification.justify,
          ),
          _icon(
            Icons.format_textdirection_r_to_l,
            _arabic ? 'من اليمين' : 'RTL',
            _wordFullFormat ? () => _setWordDirection(rtl: true) : null,
            selected: _activeParagraph.properties.rightToLeft == true,
          ),
          _icon(
            Icons.format_textdirection_l_to_r,
            _arabic ? 'من اليسار' : 'LTR',
            _wordFullFormat ? () => _setWordDirection(rtl: false) : null,
            selected: _activeParagraph.properties.rightToLeft != true,
          ),
          _icon(
            Icons.format_list_bulleted,
            _arabic ? 'تعداد' : 'Bullets',
            _wordFullFormat ? () => _word.toggleList(numbered: false) : null,
            selected: _activeParagraph.properties.numId == 1,
          ),
          _icon(
            Icons.format_list_numbered,
            _arabic ? 'ترقيم' : 'Numbering',
            _wordFullFormat ? () => _word.toggleList(numbered: true) : null,
            selected: _activeParagraph.properties.numId == 2,
          ),
          _icon(
            Icons.format_indent_increase,
            _arabic ? 'زيادة المسافة' : 'Indent',
            _wordFullFormat ? () => _nudgeIndent(18) : null,
          ),
          _icon(
            Icons.format_indent_decrease,
            _arabic ? 'إنقاص المسافة' : 'Outdent',
            _wordFullFormat ? () => _nudgeIndent(-18) : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'إدراج سريع' : 'Quick insert',
        children: <Widget>[
          _icon(
            Icons.image_outlined,
            _arabic ? 'صورة' : 'Picture',
            _canMutate ? () => _insertWordPicture(fromFile: true) : null,
          ),
          _icon(
            Icons.bar_chart,
            _arabic ? 'مخطط' : 'Chart',
            _canMutate
                ? () => _insertWordVisual(OfficeVisualKind.chartColumn)
                : null,
          ),
          _icon(
            Icons.account_tree,
            _arabic ? 'عملية' : 'Process',
            _canMutate
                ? () => _insertWordVisual(OfficeVisualKind.diagramProcess)
                : null,
          ),
          _icon(
            Icons.grid_on,
            _arabic ? 'جدول' : 'Table',
            _canMutate ? () => _insertWordTable(3, 3) : null,
          ),
          _icon(
            Icons.functions,
            _arabic ? 'معادلة' : 'Equation',
            _canMutate ? () => _insertWordEquation() : null,
          ),
        ],
      ),
      if (_word.selectedVisual != null) ..._visualRibbon(),
      if (_word.selectedEquation != null) ..._wordEquationTools(),
      if (_word.isInTable) ..._wordTableTools(),
    ];
  }

  List<StudioRibbonGroup> _wordTableTools() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'جدول' : 'Table',
        children: <Widget>[
          _cmd(
            Icons.keyboard_arrow_up,
            _arabic ? 'صف أعلى' : 'Row above',
            _canMutate ? () => _word.insertTableRow(after: false) : null,
          ),
          _cmd(
            Icons.keyboard_arrow_down,
            _arabic ? 'صف أسفل' : 'Row below',
            _canMutate ? () => _word.insertTableRow(after: true) : null,
          ),
          _cmd(
            Icons.keyboard_arrow_left,
            _arabic ? 'عمود يسار' : 'Column left',
            _canMutate ? () => _word.insertTableColumn(after: false) : null,
          ),
          _cmd(
            Icons.keyboard_arrow_right,
            _arabic ? 'عمود يمين' : 'Column right',
            _canMutate ? () => _word.insertTableColumn(after: true) : null,
          ),
          _cmd(
            Icons.table_rows,
            _arabic ? 'حذف صف' : 'Delete row',
            _canMutate ? () => _word.deleteTableRow() : null,
          ),
          _cmd(
            Icons.view_column,
            _arabic ? 'حذف عمود' : 'Delete column',
            _canMutate ? () => _word.deleteTableColumn() : null,
          ),
          _cmd(
            Icons.call_merge,
            _arabic ? 'دمج' : 'Merge',
            _canMutate && _word.canMergeTableCells
                ? () => _word.mergeTableCells()
                : null,
          ),
          _cmd(
            Icons.call_split,
            _arabic ? 'إلغاء الدمج' : 'Split',
            _canMutate && _word.canUnmergeTableCells
                ? () => _word.unmergeTableCells()
                : null,
          ),
          _cmd(
            Icons.fit_screen,
            _arabic ? 'محتوى' : 'Contents',
            _canMutate
                ? () => _word.autoFitTable(WordTableAutoFit.contents)
                : null,
          ),
          _cmd(
            Icons.width_full,
            _arabic ? 'نافذة' : 'Window',
            _canMutate
                ? () => _word.autoFitTable(WordTableAutoFit.window)
                : null,
          ),
          _cmd(
            Icons.view_week_outlined,
            _arabic ? 'ثابت' : 'Fixed',
            _canMutate
                ? () => _word.autoFitTable(WordTableAutoFit.fixed)
                : null,
          ),
          _cmd(
            Icons.delete_outline,
            _arabic ? 'حذف الجدول' : 'Delete table',
            _canMutate ? _word.deleteTable : null,
          ),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _wordInsert() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'صفحات' : 'Pages',
        children: <Widget>[
          _cmd(
            Icons.insert_page_break,
            _arabic ? 'فاصل صفحة' : 'Page break',
            _canMutate ? _insertPageBreak : null,
          ),
          _cmd(
            Icons.note_add_outlined,
            _arabic ? 'صفحة فارغة' : 'Blank page',
            _canMutate ? _insertPageBreak : null,
          ),
          _cmd(
            Icons.view_week,
            _arabic ? 'فاصل عمود' : 'Column break',
            _canMutate
                ? () {
                    _word.insertColumnBreak();
                    _word.refresh();
                  }
                : null,
          ),
          _cmd(
            Icons.vertical_split_outlined,
            _arabic ? 'فاصل قسم' : 'Section break',
            _canMutate
                ? () {
                    _word.insertSectionBreak();
                    _word.refresh();
                  }
                : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'نص' : 'Text',
        children: <Widget>[
          _cmd(
            Icons.title,
            _arabic ? 'عنوان ١' : 'Heading 1',
            _canMutate
                ? () => _word.insertHeading(
                    level: 1,
                    text: _arabic ? 'عنوان جديد' : 'New heading',
                  )
                : null,
          ),
          _cmd(
            Icons.text_fields,
            _arabic ? 'عنوان ٢' : 'Heading 2',
            _canMutate
                ? () => _word.insertHeading(
                    level: 2,
                    text: _arabic ? 'عنوان فرعي' : 'New subheading',
                  )
                : null,
          ),
          _cmd(
            Icons.list_alt,
            _arabic ? 'المحتويات' : 'Contents',
            _canMutate
                ? () => _word.insertTableOfContents(
                    title: _arabic ? 'جدول المحتويات' : 'Table of Contents',
                  )
                : null,
          ),
          _cmd(
            Icons.sync,
            _arabic ? 'تحديث الكل' : 'Update all',
            _canMutate && WordToc.tocs(_word.document).isNotEmpty
                ? () => _word.updateTableOfContents()
                : null,
          ),
          _cmd(
            Icons.filter_9,
            _arabic ? 'أرقام الصفحات' : 'Page numbers',
            _canMutate && WordToc.tocs(_word.document).isNotEmpty
                ? () => _word.updateTableOfContents(pageNumbersOnly: true)
                : null,
          ),
          _cmd(
            Icons.link,
            _arabic ? 'رابط ويب' : 'Web link',
            _canMutate ? () => _insertWordLink(kind: _WordLinkKind.web) : null,
          ),
          _cmd(
            Icons.insert_link,
            _arabic ? 'مرجع داخلي' : 'Cross-ref',
            _canMutate
                ? () => _insertWordLink(kind: _WordLinkKind.bookmark)
                : null,
          ),
          _cmd(
            Icons.folder_open,
            _arabic ? 'ملف محلي' : 'File link',
            _canMutate ? () => _insertWordLink(kind: _WordLinkKind.file) : null,
          ),
          _cmd(
            Icons.superscript,
            _arabic ? 'حاشية' : 'Footnote',
            _canMutate ? () => _word.insertFootnote() : null,
          ),
          _cmd(
            Icons.subscript,
            _arabic ? 'نهاية حاشية' : 'Endnote',
            _canMutate ? () => _word.insertFootnote(endnote: true) : null,
          ),
          _cmd(
            Icons.subtitles_outlined,
            _arabic ? 'تسمية' : 'Caption',
            _canMutate ? () => _word.insertCaption() : null,
          ),
          _cmd(
            Icons.collections_bookmark_outlined,
            _arabic ? 'جدول أشكال' : 'Figures',
            _canMutate ? () => _word.insertTableOfFigures() : null,
          ),
          _cmd(
            Icons.pin,
            _arabic ? 'رقم صفحة' : 'Page #',
            _canMutate ? () => _word.insertField(WmlFieldKind.page) : null,
          ),
          _cmd(
            Icons.calendar_today,
            _arabic ? 'تاريخ' : 'Date',
            _canMutate ? () => _word.insertField(WmlFieldKind.date) : null,
          ),
          _cmd(
            Icons.branding_watermark,
            _arabic ? 'علامة مائية' : 'Watermark',
            _canMutate
                ? () => _word.setWatermark(_arabic ? 'مسودة' : 'DRAFT')
                : null,
          ),
          _cmd(
            Icons.short_text,
            _arabic ? 'فقرة' : 'Paragraph',
            _canMutate
                ? () {
                    _word.insertParagraphBreak();
                    _word.insertText(
                      _arabic
                          ? 'فقرة يمكن تحريرها مباشرة من لوحة المفاتيح.'
                          : 'A paragraph you can type into immediately.',
                    );
                  }
                : null,
          ),
          _cmd(
            Icons.format_quote,
            _arabic ? 'اقتباس' : 'Quote',
            _canMutate ? _insertQuote : null,
          ),
          _cmd(
            Icons.crop_square,
            _arabic ? 'إطار نص' : 'Text box',
            _canMutate
                ? () {
                    _word.insertTextFrame(
                      text: _arabic ? 'إطار نص' : 'Text box',
                    );
                    _word.refresh();
                  }
                : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'جدول' : 'Table',
        children: <Widget>[
          _cmd(
            Icons.table_chart,
            _arabic ? '٢×٢' : '2×2',
            _canMutate ? () => _insertWordTable(2, 2) : null,
          ),
          _cmd(
            Icons.grid_on,
            _arabic ? '٣×٣' : '3×3',
            _canMutate ? () => _insertWordTable(3, 3) : null,
          ),
          _cmd(
            Icons.table_view,
            _arabic ? '٤×٤' : '4×4',
            _canMutate ? () => _insertWordTable(4, 4) : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'رسوم' : 'Illustrations',
        children: <Widget>[
          _cmd(
            Icons.image_outlined,
            _arabic ? 'صورة' : 'Picture',
            _canMutate ? () => _insertWordPicture(fromFile: true) : null,
          ),
          _cmd(
            Icons.bar_chart,
            _arabic ? 'أعمدة' : 'Column',
            _canMutate
                ? () => _insertWordVisual(OfficeVisualKind.chartColumn)
                : null,
          ),
          _cmd(
            Icons.stacked_bar_chart,
            _arabic ? 'شريطي' : 'Bar',
            _canMutate
                ? () => _insertWordVisual(OfficeVisualKind.chartBar)
                : null,
          ),
          _cmd(
            Icons.pie_chart,
            _arabic ? 'دائري' : 'Pie',
            _canMutate
                ? () => _insertWordVisual(OfficeVisualKind.chartPie)
                : null,
          ),
          _cmd(
            Icons.show_chart,
            _arabic ? 'خطي' : 'Line',
            _canMutate
                ? () => _insertWordVisual(OfficeVisualKind.chartLine)
                : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'مخطط' : 'Diagram',
        children: <Widget>[
          _cmd(
            Icons.linear_scale,
            _arabic ? 'عملية' : 'Process',
            _canMutate
                ? () => _insertWordVisual(OfficeVisualKind.diagramProcess)
                : null,
          ),
          _cmd(
            Icons.sync,
            _arabic ? 'دورة' : 'Cycle',
            _canMutate
                ? () => _insertWordVisual(OfficeVisualKind.diagramCycle)
                : null,
          ),
          _cmd(
            Icons.account_tree,
            _arabic ? 'هرمي' : 'Tree',
            _canMutate
                ? () => _insertWordVisual(OfficeVisualKind.diagramHierarchy)
                : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'مراجع' : 'References',
        children: <Widget>[
          _cmd(
            Icons.format_quote,
            _arabic ? 'استشهاد' : 'Citation',
            _canMutate ? _insertStudioCitation : null,
          ),
          _cmd(
            Icons.menu_book_outlined,
            _arabic ? 'مراجع' : 'Bibliography',
            _canMutate ? _word.insertBibliography : null,
          ),
          _cmd(
            Icons.bookmark_add_outlined,
            _arabic ? 'فهرس' : 'Mark index',
            _canMutate
                ? () => _word.markIndexTerm(_arabic ? 'مصطلح' : 'Term')
                : null,
          ),
          _cmd(
            Icons.list_alt_outlined,
            _arabic ? 'إدراج الفهرس' : 'Index',
            _canMutate ? _word.insertIndex : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'مراسلات' : 'Mailings',
        children: <Widget>[
          _cmd(
            Icons.mark_email_read_outlined,
            _arabic ? 'دمج' : 'Merge',
            _canMutate ? _studioMergeMail : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'معادلات' : 'Equations',
        children: <Widget>[
          _cmd(
            Icons.functions,
            _arabic ? 'معادلة' : 'Equation',
            _canMutate ? () => _insertWordEquation() : null,
          ),
          _cmd(
            Icons.calculate_outlined,
            _arabic ? 'تربيعي' : 'Quadratic',
            _canMutate ? () => _insertWordEquation(id: 'quadratic') : null,
          ),
          _cmd(
            Icons.integration_instructions_outlined,
            _arabic ? 'تكامل' : 'Integral',
            _canMutate ? () => _insertWordEquation(id: 'integral') : null,
          ),
          StudioCombo<String>(
            value: 'gallery',
            width: 132,
            enabled: _canMutate,
            tooltip: _arabic ? 'معرض المعادلات' : 'Equation gallery',
            items: <String>[
              'gallery',
              for (final OmmlGalleryItem item in OmmlGallery.items)
                if (item.id != 'blank') item.id,
            ],
            labelOf: (String id) {
              if (id == 'gallery') {
                return _arabic ? 'المعرض' : 'Gallery';
              }
              return OmmlGallery.byId(id).title(arabic: _arabic);
            },
            onSelected: _canMutate
                ? (String id) {
                    if (id != 'gallery') {
                      _insertWordEquation(id: id);
                    }
                  }
                : null,
          ),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _wordLayout() {
    final WmlParagraphProps para = _activeParagraph.properties;
    final WmlPageMargins margins = _word.pageMargins;
    final WmlPageSize size = _word.pageSize;
    final int columns = _word.sectionAtCaret.columnCount;
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'الهوامش' : 'Margins',
        children: <Widget>[
          StudioCombo<String>(
            value: _marginPresetId(margins),
            items: const <String>['normal', 'narrow', 'moderate', 'wide'],
            labelOf: _marginPresetLabel,
            width: 118,
            enabled: _canMutate,
            tooltip: _arabic ? 'هوامش الصفحة' : 'Page margins',
            onSelected: _canMutate ? _applyMarginPreset : null,
          ),
          _cmd(
            Icons.border_outer,
            _arabic ? 'عادي' : 'Normal',
            _canMutate
                ? () => _word.setPageMargins(WmlPageMargins.normal)
                : null,
            selected: margins.matches(WmlPageMargins.normal),
          ),
          _cmd(
            Icons.border_clear,
            _arabic ? 'ضيق' : 'Narrow',
            _canMutate
                ? () => _word.setPageMargins(WmlPageMargins.narrow)
                : null,
            selected: margins.matches(WmlPageMargins.narrow),
          ),
          _cmd(
            Icons.border_style,
            _arabic ? 'متوسط' : 'Moderate',
            _canMutate
                ? () => _word.setPageMargins(WmlPageMargins.moderate)
                : null,
            selected: margins.matches(WmlPageMargins.moderate),
          ),
          _cmd(
            Icons.border_all,
            _arabic ? 'واسع' : 'Wide',
            _canMutate ? () => _word.setPageMargins(WmlPageMargins.wide) : null,
            selected: margins.matches(WmlPageMargins.wide),
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'الاتجاه' : 'Orientation',
        children: <Widget>[
          _cmd(
            Icons.crop_portrait,
            _arabic ? 'عمودي' : 'Portrait',
            _canMutate ? () => _word.setPageLandscape(false) : null,
            selected: !size.isLandscape,
          ),
          _cmd(
            Icons.crop_landscape,
            _arabic ? 'أفقي' : 'Landscape',
            _canMutate ? () => _word.setPageLandscape(true) : null,
            selected: size.isLandscape,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'الحجم' : 'Size',
        children: <Widget>[
          _cmd(
            Icons.crop_din,
            'A4',
            _canMutate
                ? () => _word.setPageSize(
                    size.isLandscape
                        ? WmlPageSize.a4().landscape
                        : WmlPageSize.a4(),
                  )
                : null,
            selected: size.portrait.matches(WmlPageSize.a4()),
          ),
          _cmd(
            Icons.crop_5_4,
            'Letter',
            _canMutate
                ? () => _word.setPageSize(
                    size.isLandscape
                        ? WmlPageSize.letter().landscape
                        : WmlPageSize.letter(),
                  )
                : null,
            selected: size.portrait.matches(WmlPageSize.letter()),
          ),
          _cmd(
            Icons.crop_16_9,
            'Legal',
            _canMutate
                ? () => _word.setPageSize(
                    size.isLandscape
                        ? WmlPageSize.legal().landscape
                        : WmlPageSize.legal(),
                  )
                : null,
            selected: size.portrait.matches(WmlPageSize.legal()),
          ),
          _cmd(
            Icons.crop_3_2,
            'A3',
            _canMutate
                ? () => _word.setPageSize(
                    size.isLandscape
                        ? WmlPageSize.a3().landscape
                        : WmlPageSize.a3(),
                  )
                : null,
            selected: size.portrait.matches(WmlPageSize.a3()),
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'أعمدة' : 'Columns',
        children: <Widget>[
          _cmd(
            Icons.view_agenda,
            _arabic ? 'واحد' : 'One',
            _canMutate ? () => _word.setSectionColumns(1) : null,
            selected: columns == 1,
          ),
          _cmd(
            Icons.view_column,
            _arabic ? 'اثنان' : 'Two',
            _canMutate ? () => _word.setSectionColumns(2, sep: true) : null,
            selected: columns == 2,
          ),
          _cmd(
            Icons.view_week,
            _arabic ? 'ثلاثة' : 'Three',
            _canMutate ? () => _word.setSectionColumns(3, sep: true) : null,
            selected: columns == 3,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'فواصل' : 'Breaks',
        children: <Widget>[
          _cmd(
            Icons.insert_page_break,
            _arabic ? 'صفحة' : 'Page',
            _canMutate ? _insertPageBreak : null,
          ),
          _cmd(
            Icons.view_week_outlined,
            _arabic ? 'عمود' : 'Column',
            _canMutate
                ? () {
                    _word.insertColumnBreak();
                    _word.refresh();
                  }
                : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'فقرة' : 'Paragraph',
        children: <Widget>[
          _cmd(
            Icons.format_line_spacing,
            '1.0',
            _canMutate ? () => _setLineSpacing(1.0) : null,
            selected: para.lineSpacing == 1.0,
          ),
          _cmd(
            Icons.format_line_spacing,
            '1.15',
            _canMutate ? () => _setLineSpacing(1.15) : null,
            selected: para.lineSpacing == 1.15,
          ),
          _cmd(
            Icons.format_line_spacing,
            '1.5',
            _canMutate ? () => _setLineSpacing(1.5) : null,
            selected: para.lineSpacing == 1.5,
          ),
          _cmd(
            Icons.format_line_spacing,
            '2.0',
            _canMutate ? () => _setLineSpacing(2.0) : null,
            selected: para.lineSpacing == 2.0,
          ),
          _cmd(
            Icons.vertical_align_top,
            _arabic ? 'قبل+' : 'Before+',
            _canMutate ? () => _nudgeParagraphSpacing(before: 6) : null,
          ),
          _cmd(
            Icons.vertical_align_bottom,
            _arabic ? 'بعد+' : 'After+',
            _canMutate ? () => _nudgeParagraphSpacing(after: 6) : null,
          ),
          _cmd(
            Icons.format_indent_increase,
            _arabic ? 'مسافة' : 'Indent',
            _canMutate ? () => _nudgeIndent(18) : null,
          ),
          _cmd(
            Icons.format_indent_decrease,
            _arabic ? 'إنقاص' : 'Outdent',
            _canMutate ? () => _nudgeIndent(-18) : null,
          ),
          _cmd(
            Icons.subdirectory_arrow_right,
            _arabic ? 'سطر أول' : 'First line',
            _canMutate ? _toggleFirstLineIndent : null,
            selected: para.indent.firstLine > 0,
          ),
          _cmd(
            Icons.subdirectory_arrow_left,
            _arabic ? 'معلّق' : 'Hanging',
            _canMutate ? _toggleHangingIndent : null,
            selected: para.indent.hanging > 0,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'ترويسة' : 'Header',
        children: <Widget>[
          _cmd(
            Icons.web_asset,
            _arabic ? 'ترويسة' : 'Header',
            _canMutate
                ? () {
                    if (_word.isEditingHeader) {
                      _word.endHeaderFooterEdit();
                    } else {
                      _word.beginHeaderFooterEdit(
                        _word.visiblePageIndex,
                        footer: false,
                      );
                    }
                    setState(() {});
                  }
                : null,
            selected: _word.isEditingHeader,
          ),
          _cmd(
            Icons.web_asset_outlined,
            _arabic ? 'تذييل' : 'Footer',
            _canMutate
                ? () {
                    if (_word.isEditingFooter) {
                      _word.endHeaderFooterEdit();
                    } else {
                      _word.beginHeaderFooterEdit(
                        _word.visiblePageIndex,
                        footer: true,
                      );
                    }
                    setState(() {});
                  }
                : null,
            selected: _word.isEditingFooter,
          ),
          _cmd(
            Icons.done,
            _arabic ? 'إغلاق' : 'Close',
            _word.isEditingHeaderFooter ? _word.endHeaderFooterEdit : null,
          ),
          _cmd(
            Icons.filter_1,
            _arabic ? 'أول صفحة' : 'First page',
            _canMutate
                ? () => _word.setDifferentFirstPage(
                    !_word.sectionAtCaret.differentFirstPage,
                  )
                : null,
            selected: _word.sectionAtCaret.differentFirstPage,
          ),
          _cmd(
            Icons.swap_vert,
            _arabic ? 'فردي/زوجي' : 'Odd/even',
            _canMutate
                ? () => _word.setDifferentOddEven(
                    !_word.sectionAtCaret.differentOddEven,
                  )
                : null,
            selected: _word.sectionAtCaret.differentOddEven,
          ),
          _cmd(
            Icons.link,
            _arabic ? 'ربط بالسابق' : 'Link prev',
            _canMutate
                ? () => _word.setLinkToPrevious(
                    !_word.sectionAtCaret.linkToPrevious,
                  )
                : null,
            selected: _word.sectionAtCaret.linkToPrevious,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'مظهر الفقرة' : 'Paragraph look',
        children: <Widget>[
          _cmd(
            Icons.format_size,
            _arabic ? 'حرف استهلالي' : 'Drop cap',
            _canMutate
                ? () => _word.setDropCap(para.dropCapLines > 0 ? 0 : 3)
                : null,
            selected: para.dropCapLines > 0,
          ),
          _cmd(
            Icons.format_list_numbered,
            _arabic ? 'ترقيم أسطر' : 'Line numbers',
            _canMutate
                ? () => _word.setLineNumbers(!_word.sectionAtCaret.lineNumbers)
                : null,
            selected: _word.sectionAtCaret.lineNumbers,
          ),
          _cmd(
            Icons.format_color_fill,
            _arabic ? 'تظليل' : 'Shading',
            _canMutate
                ? () => _word.setParagraphShading(
                    para.shadingFill == null ? 'FFF2CC' : null,
                  )
                : null,
            selected: para.shadingFill != null,
          ),
          _cmd(
            Icons.border_outer,
            _arabic ? 'حدود' : 'Border',
            _canMutate
                ? () => _word.setParagraphBorder(
                    para.borderColor == null ? '2E75B6' : null,
                  )
                : null,
            selected: para.borderColor != null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'واجهة' : 'Interface',
        children: <Widget>[
          _cmd(Icons.format_textdirection_r_to_l, 'RTL', () {
            setState(() => _arabic = true);
          }, selected: _arabic),
          _cmd(Icons.format_textdirection_l_to_r, 'LTR', () {
            setState(() => _arabic = false);
          }, selected: !_arabic),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _wordReview() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'تحديد' : 'Select',
        children: <Widget>[
          _cmd(Icons.select_all, _arabic ? 'الكل' : 'All', _selectAllDocument),
          _cmd(
            Icons.text_fields,
            _arabic ? 'كلمة' : 'Word',
            _word.selectWordAtCaret,
          ),
          _cmd(
            Icons.notes,
            _arabic ? 'فقرة' : 'Paragraph',
            _word.selectParagraphAtCaret,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'تحرير' : 'Edit',
        children: <Widget>[
          _cmd(
            Icons.undo,
            _arabic ? 'تراجع' : 'Undo',
            _canMutate && _word.canUndo ? _word.undo : null,
          ),
          _cmd(
            Icons.redo,
            _arabic ? 'إعادة' : 'Redo',
            _canMutate && _word.canRedo ? _word.redo : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'تعليقات' : 'Comments',
        children: <Widget>[
          _cmd(
            Icons.view_sidebar_outlined,
            _arabic ? 'اللوحة' : 'Pane',
            () => setState(() => _showComments = !_showComments),
            selected: _showComments,
          ),
          _cmd(
            Icons.add_comment_outlined,
            _arabic ? 'جديد' : 'New',
            _canMutate ? _newWordComment : null,
          ),
          _cmd(
            Icons.reply,
            _arabic ? 'رد' : 'Reply',
            _canMutate && _word.selectedComment != null
                ? () => _replyWordComment(_word.selectedCommentId!)
                : null,
          ),
          _cmd(
            _selectedThreadResolved ? Icons.replay : Icons.task_alt,
            _selectedThreadResolved
                ? (_arabic ? 'إعادة فتح' : 'Reopen')
                : (_arabic ? 'حل' : 'Resolve'),
            _canMutate && _word.selectedComment != null
                ? () => _word.setCommentResolved(
                    _word.selectedCommentId!,
                    !_selectedThreadResolved,
                  )
                : null,
          ),
          _cmd(
            Icons.delete_outline,
            _arabic ? 'حذف' : 'Delete',
            _canMutate && _word.selectedCommentId != null
                ? () => _word.deleteComment(_word.selectedCommentId!)
                : null,
          ),
          _cmd(
            Icons.keyboard_arrow_up,
            _arabic ? 'السابق' : 'Previous',
            WordComment.roots(_word.document).isNotEmpty
                ? () => _word.stepComment(-1)
                : null,
          ),
          _cmd(
            Icons.keyboard_arrow_down,
            _arabic ? 'التالي' : 'Next',
            WordComment.roots(_word.document).isNotEmpty
                ? () => _word.stepComment(1)
                : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'تحرير المستند' : 'Proofing',
        children: <Widget>[
          _cmd(Icons.search, _arabic ? 'بحث' : 'Find', _openFind),
          _cmd(
            Icons.find_replace,
            _arabic ? 'استبدال' : 'Replace',
            _canMutate ? _openReplace : null,
          ),
          _cmd(Icons.spellcheck, _arabic ? 'تدقيق' : 'Spelling', _showSpelling),
          _cmd(
            Icons.info_outline,
            _arabic ? 'خصائص' : 'Properties',
            _showProperties,
          ),
          _cmd(
            Icons.track_changes,
            _arabic ? 'تعقب' : 'Track',
            () => _word.setTrackRevisions(!_word.document.trackRevisions),
            selected: _word.document.trackRevisions,
          ),
          _cmd(
            Icons.done_all,
            _arabic ? 'قبول' : 'Accept',
            _word.selectedRevision == null
                ? null
                : () => _word.acceptRevision(_word.selectedRevision!),
          ),
          _cmd(
            Icons.remove_done,
            _arabic ? 'رفض' : 'Reject',
            _word.selectedRevision == null
                ? null
                : () => _word.rejectRevision(_word.selectedRevision!),
          ),
          _cmd(
            Icons.keyboard_arrow_up,
            _arabic ? 'تغيير سابق' : 'Prev change',
            _word.document.revisions.isEmpty
                ? null
                : () => _word.stepRevision(-1),
          ),
          _cmd(
            Icons.keyboard_arrow_down,
            _arabic ? 'تغيير تالٍ' : 'Next change',
            _word.document.revisions.isEmpty
                ? null
                : () => _word.stepRevision(1),
          ),
          _cmd(
            Icons.done_outline,
            _arabic ? 'قبول الكل' : 'Accept all',
            _word.document.revisions.isEmpty ? null : _word.acceptAllRevisions,
          ),
          _cmd(
            Icons.remove_circle_outline,
            _arabic ? 'رفض الكل' : 'Reject all',
            _word.document.revisions.isEmpty ? null : _word.rejectAllRevisions,
          ),
          _cmd(
            Icons.sync,
            _arabic ? 'تحديث حقول' : 'Update fields',
            _canMutate ? _word.updateFields : null,
          ),
          _cmd(
            Icons.lock_outline,
            _arabic ? 'تقييد' : 'Restrict',
            () => _word.setRestrictEditing(!_word.document.restrictEditing),
            selected: _word.document.restrictEditing,
          ),
          _cmd(
            Icons.compare_arrows,
            _arabic ? 'مقارنة' : 'Compare',
            _canMutate ? _studioCompareDocument : null,
          ),
          _cmd(
            Icons.print,
            _arabic ? 'معاينة طباعة' : 'Print preview',
            () => setState(() => _printPreview = !_printPreview),
            selected: _printPreview,
          ),
          _cmd(
            Icons.preview,
            _arabic ? 'سجل دمج' : 'Merge record',
            _canMutate ? _studioMergePreview : null,
          ),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _wordView() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'عرض الصفحة' : 'Page',
        children: <Widget>[
          _cmd(
            _wordRulers ? Icons.straighten : Icons.straighten_outlined,
            _arabic ? 'مساطر' : 'Rulers',
            () => setState(() => _wordRulers = !_wordRulers),
            selected: _wordRulers,
          ),
          _cmd(
            Icons.keyboard_arrow_up,
            _arabic ? 'الصفحة السابقة' : 'Previous page',
            _word.visiblePageIndex > 0
                ? () => _jumpWordPage(_word.visiblePageIndex - 1)
                : null,
          ),
          _cmd(
            Icons.keyboard_arrow_down,
            _arabic ? 'الصفحة التالية' : 'Next page',
            _word.visiblePageIndex < _word.pageCount - 1
                ? () => _jumpWordPage(_word.visiblePageIndex + 1)
                : null,
          ),
          ..._zoomCmds(),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _sheetHome() {
    return <StudioRibbonGroup>[
      _clipboardGroup(),
      StudioRibbonGroup(
        title: _arabic ? 'سجل' : 'History',
        children: <Widget>[
          _cmd(
            Icons.undo,
            _arabic ? 'تراجع' : 'Undo',
            _canMutate && _sheet.canUndo ? _sheet.undo : null,
          ),
          _cmd(
            Icons.redo,
            _arabic ? 'إعادة' : 'Redo',
            _canMutate && _sheet.canRedo ? _sheet.redo : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'خلايا' : 'Cells',
        children: <Widget>[
          _cmd(
            Icons.edit_outlined,
            _arabic ? 'تحرير F2' : 'Edit F2',
            _canMutate ? _sheet.beginCellEdit : null,
          ),
          _cmd(
            Icons.clear,
            _arabic ? 'مسح' : 'Clear',
            _canMutate ? _sheet.clearSelectedCells : null,
          ),
          _cmd(
            Icons.backspace_outlined,
            _arabic ? 'مسح البؤرة' : 'Clear cell',
            _canMutate ? _clearActiveCell : null,
          ),
          _cmd(
            Icons.table_rows,
            _arabic ? 'إدراج صف' : 'Insert row',
            _canMutate ? () => _sheet.insertSheetRows(after: false) : null,
          ),
          _cmd(
            Icons.view_column,
            _arabic ? 'إدراج عمود' : 'Insert column',
            _canMutate ? () => _sheet.insertSheetCols(after: false) : null,
          ),
          _cmd(
            Icons.delete_sweep_outlined,
            _arabic ? 'حذف صف' : 'Delete row',
            _canMutate ? () => _sheet.deleteSheetRows() : null,
          ),
          _cmd(
            Icons.delete_outline,
            _arabic ? 'حذف عمود' : 'Delete column',
            _canMutate ? () => _sheet.deleteSheetCols() : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'تحديد' : 'Select',
        children: <Widget>[
          _cmd(Icons.table_rows, _arabic ? 'صف' : 'Row', () {
            _sheet.selection.selectRow(_sheet.selection.focus.row);
            _sheet.refresh();
          }),
          _cmd(Icons.view_column, _arabic ? 'عمود' : 'Column', () {
            _sheet.selection.selectColumn(_sheet.selection.focus.col);
            _sheet.refresh();
          }),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'محاذاة' : 'Alignment',
        children: <Widget>[
          _cmd(
            Icons.call_merge,
            _arabic ? 'دمج وتوسيط' : 'Merge & Center',
            _canMutate && _sheet.canMergeAndCenter
                ? _sheet.toggleMergeAndCenter
                : null,
            selected: _sheet.hasMergedSelection,
          ),
          _cmd(
            Icons.call_split,
            _arabic ? 'إلغاء الدمج' : 'Unmerge',
            _canMutate && _sheet.canUnmergeCells ? _sheet.unmergeCells : null,
          ),
          _cmd(
            Icons.format_color_fill,
            _arabic ? 'تعبئة' : 'Fill',
            _canMutate ? _sheet.cycleSelectionFillRgb : null,
          ),
          _cmd(
            Icons.format_color_text,
            _arabic ? 'لون النص' : 'Font color',
            _canMutate ? _sheet.cycleSelectionFontRgb : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'تحجيم' : 'Size',
        children: <Widget>[
          _cmd(
            Icons.unfold_more,
            _arabic ? 'أوسع' : 'Wider',
            _canMutate ? () => _sheet.nudgeColumnWidth(16) : null,
          ),
          _cmd(
            Icons.unfold_less,
            _arabic ? 'أضيق' : 'Narrower',
            _canMutate ? () => _sheet.nudgeColumnWidth(-16) : null,
          ),
          _cmd(
            Icons.height,
            _arabic ? 'أطول' : 'Taller',
            _canMutate ? () => _sheet.nudgeRowHeight(8) : null,
          ),
          _cmd(
            Icons.compress,
            _arabic ? 'أقصر' : 'Shorter',
            _canMutate ? () => _sheet.nudgeRowHeight(-8) : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'إدراج سريع' : 'Quick insert',
        children: <Widget>[
          _cmd(
            Icons.image_outlined,
            _arabic ? 'صورة' : 'Picture',
            _canMutate ? () => _insertSheetPicture(fromFile: true) : null,
          ),
          _cmd(
            Icons.bar_chart,
            _arabic ? 'أعمدة' : 'Column',
            _canMutate
                ? () => _insertSheetChart(OfficeVisualKind.chartColumn)
                : null,
          ),
          _cmd(
            Icons.pie_chart,
            _arabic ? 'دائري' : 'Pie',
            _canMutate
                ? () => _insertSheetChart(OfficeVisualKind.chartPie)
                : null,
          ),
        ],
      ),
      if (_sheet.selectedDrawing != null) ..._visualRibbon(),
    ];
  }

  List<StudioRibbonGroup> _sheetInsert() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'رسوم' : 'Illustrations',
        children: <Widget>[
          _cmd(
            Icons.image_outlined,
            _arabic ? 'صورة' : 'Picture',
            _canMutate ? () => _insertSheetPicture(fromFile: true) : null,
          ),
          _cmd(
            Icons.bar_chart,
            _arabic ? 'أعمدة' : 'Column',
            _canMutate
                ? () => _insertSheetChart(OfficeVisualKind.chartColumn)
                : null,
          ),
          _cmd(
            Icons.stacked_bar_chart,
            _arabic ? 'شريطي' : 'Bar',
            _canMutate
                ? () => _insertSheetChart(OfficeVisualKind.chartBar)
                : null,
          ),
          _cmd(
            Icons.pie_chart,
            _arabic ? 'دائري' : 'Pie',
            _canMutate
                ? () => _insertSheetChart(OfficeVisualKind.chartPie)
                : null,
          ),
          _cmd(
            Icons.show_chart,
            _arabic ? 'خطي' : 'Line',
            _canMutate
                ? () => _insertSheetChart(OfficeVisualKind.chartLine)
                : null,
          ),
          _cmd(
            Icons.account_tree,
            _arabic ? 'عملية' : 'Process',
            _canMutate
                ? () => _insertSheetChart(OfficeVisualKind.diagramProcess)
                : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'خلايا' : 'Cells',
        children: <Widget>[
          _cmd(
            Icons.table_rows,
            _arabic ? 'صف' : 'Row',
            _canMutate ? () => _sheet.insertSheetRows(after: false) : null,
          ),
          _cmd(
            Icons.view_column,
            _arabic ? 'عمود' : 'Column',
            _canMutate ? () => _sheet.insertSheetCols(after: false) : null,
          ),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _sheetFormulas() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'دالة' : 'Function',
        children: <Widget>[
          _cmd(
            Icons.functions,
            'SUM',
            _canMutate ? () => _insertFormula('SUM') : null,
          ),
          _cmd(
            Icons.functions,
            'AVERAGE',
            _canMutate ? () => _insertFormula('AVERAGE') : null,
          ),
          _cmd(
            Icons.functions,
            'MIN',
            _canMutate ? () => _insertFormula('MIN') : null,
          ),
          _cmd(
            Icons.functions,
            'MAX',
            _canMutate ? () => _insertFormula('MAX') : null,
          ),
          _cmd(
            Icons.functions,
            'COUNT',
            _canMutate ? () => _insertFormula('COUNT') : null,
          ),
          _cmd(
            Icons.functions,
            'COUNTA',
            _canMutate ? () => _insertFormula('COUNTA') : null,
          ),
          _cmd(Icons.functions, 'IF', _canMutate ? _insertIfFormula : null),
          _cmd(
            Icons.functions,
            'SUMIF',
            _canMutate ? () => _insertFormula('SUMIF') : null,
          ),
          _cmd(
            Icons.functions,
            'COUNTIF',
            _canMutate ? () => _insertFormula('COUNTIF') : null,
          ),
          _cmd(
            Icons.functions,
            'IFERROR',
            _canMutate ? () => _insertFormula('IFERROR') : null,
          ),
          _cmd(
            Icons.functions,
            'ROUND',
            _canMutate ? () => _insertFormula('ROUND') : null,
          ),
          _cmd(
            Icons.functions,
            'CONCAT',
            _canMutate ? () => _insertFormula('CONCAT') : null,
          ),
          _cmd(
            Icons.functions,
            'VLOOKUP',
            _canMutate ? () => _insertFormula('VLOOKUP') : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'مرجع' : 'Reference',
        children: <Widget>[
          _cmd(
            Icons.menu_book_outlined,
            _arabic ? 'دليل الدوال' : 'Function guide',
            _openFunctionGuide,
          ),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _sheetData() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'أوراق' : 'Sheets',
        children: <Widget>[
          _cmd(
            Icons.post_add,
            _arabic ? 'ورقة' : 'Insert',
            _canMutate ? _addSheet : null,
          ),
          _cmd(
            Icons.delete_outline,
            _arabic ? 'حذف' : 'Delete',
            _canMutate && _sheet.workbook.sheets.length > 1
                ? _deleteSheet
                : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'رسوم' : 'Charts',
        children: <Widget>[
          _cmd(
            Icons.bar_chart,
            _arabic ? 'أعمدة' : 'Column',
            _canMutate
                ? () => _insertSheetChart(OfficeVisualKind.chartColumn)
                : null,
          ),
          _cmd(
            Icons.pie_chart,
            _arabic ? 'دائري' : 'Pie',
            _canMutate
                ? () => _insertSheetChart(OfficeVisualKind.chartPie)
                : null,
          ),
          _cmd(
            Icons.show_chart,
            _arabic ? 'خطي' : 'Line',
            _canMutate
                ? () => _insertSheetChart(OfficeVisualKind.chartLine)
                : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'بيانات' : 'Data',
        children: <Widget>[
          _cmd(
            Icons.sort_by_alpha,
            _arabic ? 'فرز' : 'Sort',
            _canMutate ? () => _sheet.sortSelection() : null,
          ),
          _cmd(
            Icons.filter_alt,
            _arabic ? 'تصفية' : 'Filter',
            _canMutate ? () => _sheet.filterSelection() : null,
            selected: _sheet.sheet.autoFilter != null,
          ),
          _cmd(
            Icons.filter_alt_off,
            _arabic ? 'إلغاء التصفية' : 'Clear',
            _canMutate && _sheet.sheet.autoFilter != null
                ? _sheet.clearFilter
                : null,
          ),
          _cmd(
            Icons.bookmark_border,
            _arabic ? 'اسم' : 'Name',
            _canMutate
                ? () => _sheet.defineName(
                    'Range${_sheet.workbook.namedRanges.length + 1}',
                  )
                : null,
          ),
          _cmd(
            Icons.print_outlined,
            _arabic ? 'منطقة طباعة' : 'Print area',
            _canMutate ? () => _sheet.setPrintArea(null) : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'أدوات' : 'Tools',
        children: <Widget>[
          _cmd(
            Icons.comment_outlined,
            _arabic ? 'تعليق' : 'Comment',
            _canMutate
                ? () => _sheet.setCellComment(
                    _arabic ? 'تعليق خلية' : 'Cell comment',
                  )
                : null,
          ),
          _cmd(
            Icons.lock_outline,
            _arabic ? 'حماية' : 'Protect',
            _canMutate
                ? () => _sheet.protectSheet(
                    enabled: !(_sheet.sheet.protection?.enabled ?? false),
                  )
                : null,
            selected: _sheet.sheet.protection?.enabled ?? false,
          ),
          _cmd(
            Icons.table_chart_outlined,
            _arabic ? 'جدول' : 'Table',
            _canMutate
                ? () => _sheet.addTable(
                    name: 'Table${_sheet.sheet.tables.length + 1}',
                  )
                : null,
          ),
          _cmd(
            Icons.checklist,
            _arabic ? 'تحقق' : 'Validate',
            _canMutate ? _studioSheetValidation : null,
          ),
          _cmd(
            Icons.pivot_table_chart,
            _arabic ? 'محور' : 'Pivot',
            _canMutate ? _studioInsertPivot : null,
          ),
          _cmd(
            Icons.south,
            _arabic ? 'تعبئة' : 'Fill',
            _canMutate ? () => _sheet.fillSeries() : null,
          ),
          _cmd(
            Icons.show_chart,
            _arabic ? 'شرارة' : 'Sparkline',
            _canMutate ? () => _sheet.addSparkline() : null,
          ),
          _cmd(
            Icons.adjust,
            _arabic ? 'هدف' : 'Goal seek',
            _canMutate ? _studioGoalSeek : null,
          ),
          _cmd(
            Icons.table_view,
            _arabic ? 'CSV' : 'CSV',
            _canMutate ? _studioImportCsv : null,
          ),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _sheetView() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'عرض الشبكة' : 'Grid',
        children: <Widget>[
          _cmd(
            Icons.border_all,
            _arabic ? 'خطوط' : 'Gridlines',
            () => setState(() => _sheetGridlines = !_sheetGridlines),
            selected: _sheetGridlines,
          ),
          _cmd(
            Icons.view_headline,
            _arabic ? 'رؤوس' : 'Headers',
            () => setState(() => _sheetHeaders = !_sheetHeaders),
            selected: _sheetHeaders,
          ),
          _cmd(
            Icons.ac_unit,
            _arabic
                ? (_sheet.hasFrozenPanes ? 'إلغاء التجميد' : 'تجميد')
                : (_sheet.hasFrozenPanes ? 'Unfreeze' : 'Freeze'),
            _sheet.toggleFreezePanes,
            selected: _sheet.hasFrozenPanes,
          ),
          _cmd(
            Icons.table_rows,
            _arabic ? 'تجميد صف' : 'Freeze row',
            _canMutate ? _sheet.freezeTopRow : null,
            selected:
                _sheet.sheet.freezeRows == 1 && _sheet.sheet.freezeCols == 0,
          ),
          _cmd(
            Icons.view_column,
            _arabic ? 'تجميد عمود' : 'Freeze column',
            _canMutate ? _sheet.freezeFirstColumn : null,
            selected:
                _sheet.sheet.freezeCols == 1 && _sheet.sheet.freezeRows == 0,
          ),
          ..._zoomCmds(),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'اتجاه الورقة' : 'Sheet direction',
        children: <Widget>[
          _cmd(
            Icons.format_textdirection_r_to_l,
            _arabic ? 'من اليمين' : 'RTL',
            _canMutate ? () => _sheet.setSheetRightToLeft(true) : null,
            selected: _sheet.sheet.rightToLeft,
          ),
          _cmd(
            Icons.format_textdirection_l_to_r,
            _arabic ? 'من اليسار' : 'LTR',
            _canMutate ? () => _sheet.setSheetRightToLeft(false) : null,
            selected: !_sheet.sheet.rightToLeft,
          ),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _slideHome() {
    return <StudioRibbonGroup>[
      _clipboardGroup(),
      StudioRibbonGroup(
        title: _arabic ? 'الشرائح' : 'Slides',
        children: <Widget>[
          _cmd(
            Icons.add_box_outlined,
            _arabic ? 'جديد' : 'New',
            _canMutate ? _addSlide : null,
          ),
          _cmd(
            Icons.copy_outlined,
            _arabic ? 'نسخ' : 'Duplicate',
            _canMutate ? _duplicateSlide : null,
          ),
          _cmd(
            Icons.delete_outline,
            _arabic ? 'حذف' : 'Delete',
            _canMutate && _slides.presentation.slides.length > 1
                ? _deleteSlide
                : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'تنقل' : 'Navigate',
        children: <Widget>[
          _cmd(Icons.navigate_before, _arabic ? 'السابق' : 'Prev', () {
            _slides.setActiveSlide(_slides.activeSlideIndex - 1);
          }),
          _cmd(Icons.navigate_next, _arabic ? 'التالي' : 'Next', () {
            _slides.setActiveSlide(_slides.activeSlideIndex + 1);
          }),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'ترتيب' : 'Arrange',
        children: <Widget>[
          _cmd(
            Icons.align_horizontal_left,
            _arabic ? 'يسار' : 'Left',
            _canMutate ? () => _slides.alignShapes(PmlAlignAxis.left) : null,
          ),
          _cmd(
            Icons.align_horizontal_center,
            _arabic ? 'وسط' : 'Center',
            _canMutate ? () => _slides.alignShapes(PmlAlignAxis.center) : null,
          ),
          _cmd(
            Icons.align_vertical_top,
            _arabic ? 'أعلى' : 'Top',
            _canMutate ? () => _slides.alignShapes(PmlAlignAxis.top) : null,
          ),
          _cmd(
            Icons.view_agenda_outlined,
            _arabic ? 'قسم' : 'Section',
            _canMutate
                ? () => _slides.addSlideSection(
                    _arabic ? 'قسم جديد' : 'New section',
                  )
                : null,
          ),
          _cmd(
            Icons.group_work_outlined,
            _arabic ? 'تجميع' : 'Group',
            _canMutate && _slides.slide.shapes.length >= 2
                ? () => _slides.groupShapes()
                : null,
          ),
          _cmd(
            Icons.group_off_outlined,
            _arabic ? 'فك' : 'Ungroup',
            _canMutate ? () => _slides.ungroupShapes() : null,
          ),
          _cmd(
            Icons.title,
            _arabic ? 'عنصر نائب' : 'Placeholder',
            _canMutate
                ? () => _slides.setLayoutPlaceholder(
                    layoutName: _slides.slide.layoutName.isEmpty
                        ? 'Title Slide'
                        : _slides.slide.layoutName,
                    text: _arabic ? 'انقر للعنوان' : 'Click to add title',
                  )
                : null,
          ),
          _cmd(
            Icons.videocam_outlined,
            _arabic ? 'وسائط' : 'Media',
            _canMutate && _slides.selected != null
                ? () => _slides.setShapeMedia(
                    _slides.selected!,
                    name: 'clip.mp4',
                    bytes: <int>[0, 0, 0, 0],
                  )
                : null,
          ),
          _cmd(
            Icons.play_circle_outline,
            _arabic ? 'تشغيل' : 'Play',
            _slides.selected?.hasMedia == true
                ? () => _slides.playShapeMedia(_slides.selected!)
                : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'خط النص' : 'Text font',
        children: <Widget>[
          StudioCombo<int>(
            value: _slideFontSizePt,
            items: OfficeTypeface.sizesPt,
            labelOf: (int pt) => '$pt',
            width: 52,
            enabled:
                _canMutate &&
                _slides.selected != null &&
                _slides.selected!.visual == null,
            tooltip: _arabic ? 'حجم النص' : 'Text size',
            onSelected:
                _canMutate &&
                    _slides.selected != null &&
                    _slides.selected!.visual == null
                ? (int pt) => _slides.updateSelected(fontSizePt: pt.toDouble())
                : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'فقرة' : 'Paragraph',
        children: <Widget>[
          _icon(
            Icons.format_align_left,
            _arabic ? 'يسار' : 'Left',
            _canEditSlideText
                ? () => _slides.setSelectedTextAlign(PmlTextAlign.left)
                : null,
            selected: _slides.selected?.textAlign == PmlTextAlign.left,
          ),
          _icon(
            Icons.format_align_center,
            _arabic ? 'وسط' : 'Center',
            _canEditSlideText
                ? () => _slides.setSelectedTextAlign(PmlTextAlign.center)
                : null,
            selected: _slides.selected?.textAlign == PmlTextAlign.center,
          ),
          _icon(
            Icons.format_align_right,
            _arabic ? 'يمين' : 'Right',
            _canEditSlideText
                ? () => _slides.setSelectedTextAlign(PmlTextAlign.right)
                : null,
            selected: _slides.selected?.textAlign == PmlTextAlign.right,
          ),
          _icon(
            Icons.format_align_justify,
            _arabic ? 'ضبط' : 'Justify',
            _canEditSlideText
                ? () => _slides.setSelectedTextAlign(PmlTextAlign.justify)
                : null,
            selected: _slides.selected?.textAlign == PmlTextAlign.justify,
          ),
          _icon(
            Icons.format_textdirection_r_to_l,
            _arabic ? 'من اليمين' : 'RTL',
            _canEditSlideText
                ? () => _slides.setSelectedTextDirection(rtl: true)
                : null,
            selected: _slides.selected?.rightToLeft == true,
          ),
          _icon(
            Icons.format_textdirection_l_to_r,
            _arabic ? 'من اليسار' : 'LTR',
            _canEditSlideText
                ? () => _slides.setSelectedTextDirection(rtl: false)
                : null,
            selected: _slides.selected?.rightToLeft == false,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'ترتيب' : 'Arrange',
        children: <Widget>[
          _cmd(
            Icons.arrow_back,
            '',
            _canMutate ? () => _slides.nudgeSelected(-127000, 0) : null,
          ),
          _cmd(
            Icons.arrow_forward,
            '',
            _canMutate ? () => _slides.nudgeSelected(127000, 0) : null,
          ),
          _cmd(
            Icons.arrow_upward,
            '',
            _canMutate ? () => _slides.nudgeSelected(0, -127000) : null,
          ),
          _cmd(
            Icons.arrow_downward,
            '',
            _canMutate ? () => _slides.nudgeSelected(0, 127000) : null,
          ),
          _cmd(
            Icons.flip_to_front,
            _arabic ? 'أمام' : 'Forward',
            _canMutate ? () => _slides.reorderSelected(forward: true) : null,
          ),
          _cmd(
            Icons.flip_to_back,
            _arabic ? 'خلف' : 'Back',
            _canMutate ? () => _slides.reorderSelected(forward: false) : null,
          ),
          _cmd(
            Icons.align_horizontal_left,
            _arabic ? 'يسار' : 'Left',
            _canMutate && _slides.selected != null
                ? () => _alignSelectedShape(x: 0)
                : null,
          ),
          _cmd(
            Icons.align_horizontal_center,
            _arabic ? 'وسط' : 'Center',
            _canMutate && _slides.selected != null
                ? _centerSelectedShape
                : null,
          ),
          _cmd(
            Icons.align_horizontal_right,
            _arabic ? 'يمين' : 'Right',
            _canMutate && _slides.selected != null
                ? () => _alignSelectedShape(x: 1)
                : null,
          ),
          _cmd(
            Icons.align_vertical_top,
            _arabic ? 'أعلى' : 'Top',
            _canMutate && _slides.selected != null
                ? () => _alignSelectedShape(y: 0)
                : null,
          ),
          _cmd(
            Icons.align_vertical_bottom,
            _arabic ? 'أسفل' : 'Bottom',
            _canMutate && _slides.selected != null
                ? () => _alignSelectedShape(y: 1)
                : null,
          ),
          _cmd(
            Icons.text_fields,
            _arabic ? 'تحرير النص' : 'Edit text',
            _canMutate &&
                    _slides.selected != null &&
                    _slides.selected!.visual == null
                ? _slides.beginTextEdit
                : null,
          ),
          _cmd(
            Icons.delete_outline,
            _arabic ? 'حذف' : 'Delete',
            _canMutate && _slides.selected != null
                ? _slides.deleteSelectedShape
                : null,
          ),
        ],
      ),
      if (_slides.selectedTable != null)
        StudioRibbonGroup(
          title: _arabic ? 'جدول' : 'Table',
          children: <Widget>[
            _cmd(
              Icons.table_rows,
              _arabic ? 'صف أعلى' : 'Row above',
              _canEditSlideTable
                  ? () => _slides.insertSelectedTableRow(after: false)
                  : null,
            ),
            _cmd(
              Icons.table_rows_outlined,
              _arabic ? 'صف أسفل' : 'Row below',
              _canEditSlideTable
                  ? () => _slides.insertSelectedTableRow(after: true)
                  : null,
            ),
            _cmd(
              Icons.view_column,
              _arabic ? 'عمود يسار' : 'Column left',
              _canEditSlideTable
                  ? () => _slides.insertSelectedTableColumn(after: false)
                  : null,
            ),
            _cmd(
              Icons.view_week,
              _arabic ? 'عمود يمين' : 'Column right',
              _canEditSlideTable
                  ? () => _slides.insertSelectedTableColumn(after: true)
                  : null,
            ),
            _cmd(
              Icons.delete_sweep,
              _arabic ? 'حذف صف' : 'Delete row',
              _canEditSlideTable && (_slides.selectedTable?.rowCount ?? 0) > 1
                  ? _slides.deleteSelectedTableRow
                  : null,
            ),
            _cmd(
              Icons.view_column_outlined,
              _arabic ? 'حذف عمود' : 'Delete column',
              _canEditSlideTable && (_slides.selectedTable?.colCount ?? 0) > 1
                  ? _slides.deleteSelectedTableColumn
                  : null,
            ),
          ],
        ),
    ];
  }

  List<StudioRibbonGroup> _slideInsert() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'أشكال' : 'Shapes',
        children: <Widget>[
          _cmd(
            Icons.crop_square,
            _arabic ? 'بطاقة' : 'Card',
            _canMutate ? _addCardShape : null,
          ),
          _cmd(
            Icons.title,
            _arabic ? 'عنوان' : 'Title',
            _canMutate ? _addTitleShape : null,
          ),
          _cmd(
            Icons.rounded_corner,
            _arabic ? 'تمييز' : 'Accent',
            _canMutate ? _addAccentShape : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'رسوم' : 'Illustrations',
        children: <Widget>[
          _cmd(
            Icons.image_outlined,
            _arabic ? 'صورة' : 'Picture',
            _canMutate ? () => _insertSlidePicture(fromFile: true) : null,
          ),
          _cmd(
            Icons.bar_chart,
            _arabic ? 'أعمدة' : 'Column',
            _canMutate
                ? () => _insertSlideVisual(OfficeVisualKind.chartColumn)
                : null,
          ),
          _cmd(
            Icons.pie_chart,
            _arabic ? 'دائري' : 'Pie',
            _canMutate
                ? () => _insertSlideVisual(OfficeVisualKind.chartPie)
                : null,
          ),
          _cmd(
            Icons.account_tree,
            _arabic ? 'عملية' : 'Process',
            _canMutate
                ? () => _insertSlideVisual(OfficeVisualKind.diagramProcess)
                : null,
          ),
          _cmd(
            Icons.stacked_bar_chart,
            _arabic ? 'شريطي' : 'Bar',
            _canMutate
                ? () => _insertSlideVisual(OfficeVisualKind.chartBar)
                : null,
          ),
          _cmd(
            Icons.show_chart,
            _arabic ? 'خطي' : 'Line',
            _canMutate
                ? () => _insertSlideVisual(OfficeVisualKind.chartLine)
                : null,
          ),
          _cmd(
            Icons.sync,
            _arabic ? 'دورة' : 'Cycle',
            _canMutate
                ? () => _insertSlideVisual(OfficeVisualKind.diagramCycle)
                : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'جدول' : 'Table',
        children: <Widget>[
          _cmd(
            Icons.table_chart,
            _arabic ? '٢×٢' : '2×2',
            _canMutate
                ? () => _slides.insertTable(rows: 2, cols: 2, arabic: _arabic)
                : null,
          ),
          _cmd(
            Icons.grid_on,
            _arabic ? '٣×٣' : '3×3',
            _canMutate
                ? () => _slides.insertTable(rows: 3, cols: 3, arabic: _arabic)
                : null,
          ),
          _cmd(
            Icons.table_view,
            _arabic ? '٤×٤' : '4×4',
            _canMutate
                ? () => _slides.insertTable(rows: 4, cols: 4, arabic: _arabic)
                : null,
          ),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _slideDesign() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'شكل' : 'Shape',
        children: <Widget>[
          _cmd(
            Icons.format_color_fill,
            _arabic ? 'تعبئة' : 'Fill',
            _canMutate && _slides.selected != null ? _cycleShapeFill : null,
          ),
          _cmd(
            Icons.filter_center_focus,
            _arabic ? 'توسيط' : 'Center',
            _canMutate && _slides.selected != null
                ? _centerSelectedShape
                : null,
          ),
          _cmd(
            Icons.title,
            _arabic ? 'نص' : 'Text',
            _canMutate &&
                    _slides.selected != null &&
                    _slides.selected!.visual == null
                ? _slides.beginTextEdit
                : null,
          ),
        ],
      ),
      if (_slides.selected?.visual != null) ..._visualRibbon(),
    ];
  }

  List<StudioRibbonGroup> _slideTransitions() {
    final PmlSlideTransition current = _slides.slide.transition;
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'معاينة' : 'Preview',
        children: <Widget>[
          _cmd(
            Icons.play_circle_outline,
            _arabic ? 'معاينة' : 'Preview',
            _slides.previewTransition,
          ),
          _cmd(
            Icons.slideshow,
            _arabic ? 'عرض' : 'From here',
            () => _slides.startShow(
              from: _slides.activeSlideIndex,
              withTransition: _slides.activeSlideIndex > 0,
            ),
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'التأثير' : 'Effect',
        children: <Widget>[
          for (final PmlTransitionKind kind in PmlMotionCatalog.transitions)
            _cmd(
              _transitionIcon(kind),
              PmlMotionCatalog.transitionLabel(kind, arabic: _arabic),
              () => _slides.setSlideTransition(current.copyWith(kind: kind)),
              selected: current.kind == kind,
            ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'خيارات' : 'Options',
        children: <Widget>[
          _cmd(
            Icons.swap_horiz,
            _dirLabel(current.direction),
            PmlMotionCatalog.usesDirection(current.kind)
                ? () => _slides.setSlideTransition(
                    current.copyWith(direction: _nextDir(current.direction)),
                  )
                : null,
          ),
          _cmd(
            Icons.timer,
            _durationLabel(current.durationMs),
            () => _slides.setSlideTransition(
              current.copyWith(durationMs: _nextDuration(current.durationMs)),
              preview: false,
            ),
          ),
          _cmd(
            Icons.touch_app,
            current.advanceOnClick
                ? (_arabic ? 'بالنقر' : 'On click')
                : (_arabic ? 'بدون نقر' : 'No click'),
            () => _slides.setSlideTransition(
              current.copyWith(advanceOnClick: !current.advanceOnClick),
              preview: false,
            ),
            selected: current.advanceOnClick,
          ),
          _cmd(
            Icons.more_time,
            _advanceLabel(current),
            () => _slides.setSlideTransition(
              _cycleAdvance(current),
              preview: false,
            ),
          ),
          _cmd(
            Icons.copy_all,
            _arabic ? 'الكل' : 'Apply all',
            () => _slides.setSlideTransition(
              current,
              applyToAll: true,
              preview: false,
            ),
          ),
        ],
      ),
    ];
  }

  List<StudioRibbonGroup> _slideAnimations() {
    final bool hasShape = _slides.selected != null;
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'دخول' : 'Entrance',
        children: <Widget>[
          for (final PmlAnimPreset preset in PmlMotionCatalog.entrance)
            _cmd(
              Icons.login,
              PmlMotionCatalog.animLabel(preset, arabic: _arabic),
              hasShape ? () => _slides.addShapeAnimation(preset) : null,
            ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'تأكيد' : 'Emphasis',
        children: <Widget>[
          for (final PmlAnimPreset preset in PmlMotionCatalog.emphasis)
            _cmd(
              Icons.highlight,
              PmlMotionCatalog.animLabel(preset, arabic: _arabic),
              hasShape ? () => _slides.addShapeAnimation(preset) : null,
            ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'خروج' : 'Exit',
        children: <Widget>[
          for (final PmlAnimPreset preset in PmlMotionCatalog.exit)
            _cmd(
              Icons.logout,
              PmlMotionCatalog.animLabel(preset, arabic: _arabic),
              hasShape ? () => _slides.addShapeAnimation(preset) : null,
            ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'مسار' : 'Motion',
        children: <Widget>[
          for (final PmlAnimPreset preset in PmlMotionCatalog.motion)
            _cmd(
              Icons.timeline,
              PmlMotionCatalog.animLabel(preset, arabic: _arabic),
              hasShape ? () => _slides.addShapeAnimation(preset) : null,
            ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'توقيت' : 'Timing',
        children: <Widget>[
          _cmd(
            Icons.play_arrow,
            _arabic ? 'معاينة' : 'Preview',
            _slides.previewAnimations,
          ),
          _cmd(
            Icons.view_sidebar_outlined,
            _arabic ? 'الجزء' : 'Pane',
            () => setState(() => _showAnimPane = !_showAnimPane),
            selected: _showAnimPane,
          ),
          _cmd(
            Icons.touch_app,
            _triggerLabel(_activeAnim?.trigger ?? PmlAnimTrigger.onClick),
            _activeAnimIndex == null
                ? null
                : () => _slides.updateShapeAnimation(
                    _activeAnimIndex!,
                    trigger: _nextTrigger(_activeAnim!.trigger),
                  ),
          ),
          _cmd(
            Icons.swap_horiz,
            _dirLabel(_activeAnim?.direction ?? PmlTransitionDir.left),
            _activeAnimIndex == null ||
                    !PmlMotionCatalog.animUsesDirection(_activeAnim!.preset)
                ? null
                : () => _slides.updateShapeAnimation(
                    _activeAnimIndex!,
                    direction: _nextDir(_activeAnim!.direction),
                  ),
          ),
          _cmd(
            Icons.timer,
            _durationLabel(_activeAnim?.durationMs ?? 500),
            _activeAnimIndex == null
                ? null
                : () => _slides.updateShapeAnimation(
                    _activeAnimIndex!,
                    durationMs: _nextDuration(_activeAnim!.durationMs),
                  ),
          ),
          _cmd(
            Icons.more_time,
            _delayLabel(_activeAnim?.delayMs ?? 0),
            _activeAnimIndex == null
                ? null
                : () => _slides.updateShapeAnimation(
                    _activeAnimIndex!,
                    delayMs: _nextDelay(_activeAnim!.delayMs),
                  ),
          ),
        ],
      ),
    ];
  }

  int? get _activeAnimIndex =>
      _slides.selectedAnimationIndex ??
      (_slides.slide.animations.isEmpty
          ? null
          : _slides.slide.animations.length - 1);

  PmlShapeAnimation? get _activeAnim {
    final int? index = _activeAnimIndex;
    if (index == null) {
      return null;
    }
    return _slides.slide.animations[index];
  }

  String _triggerLabel(PmlAnimTrigger trigger) {
    return switch (trigger) {
      PmlAnimTrigger.onClick => _arabic ? 'عند النقر' : 'On click',
      PmlAnimTrigger.withPrevious => _arabic ? 'مع السابق' : 'With previous',
      PmlAnimTrigger.afterPrevious => _arabic ? 'بعد السابق' : 'After previous',
    };
  }

  PmlAnimTrigger _nextTrigger(PmlAnimTrigger trigger) {
    return switch (trigger) {
      PmlAnimTrigger.onClick => PmlAnimTrigger.withPrevious,
      PmlAnimTrigger.withPrevious => PmlAnimTrigger.afterPrevious,
      PmlAnimTrigger.afterPrevious => PmlAnimTrigger.onClick,
    };
  }

  PmlTransitionDir _nextDir(PmlTransitionDir dir) {
    const List<PmlTransitionDir> cycle = <PmlTransitionDir>[
      PmlTransitionDir.left,
      PmlTransitionDir.right,
      PmlTransitionDir.up,
      PmlTransitionDir.down,
    ];
    return cycle[(cycle.indexOf(dir) + 1) % cycle.length];
  }

  int _nextDuration(int ms) {
    if (ms <= 400) {
      return 700;
    }
    if (ms < 1000) {
      return 1200;
    }
    return 350;
  }

  int _nextDelay(int ms) {
    if (ms <= 0) {
      return 250;
    }
    if (ms < 500) {
      return 750;
    }
    if (ms < 1000) {
      return 1500;
    }
    return 0;
  }

  String _durationLabel(int ms) {
    if (ms <= 400) {
      return _arabic ? 'سريع' : 'Fast';
    }
    if (ms >= 1000) {
      return _arabic ? 'بطيء' : 'Slow';
    }
    return _arabic ? 'متوسط' : 'Medium';
  }

  String _delayLabel(int ms) {
    if (ms <= 0) {
      return _arabic ? 'بدون تأخير' : 'No delay';
    }
    return _arabic ? 'تأخير ${ms}ms' : 'Delay ${ms}ms';
  }

  String _dirLabel(PmlTransitionDir dir) {
    return switch (dir) {
      PmlTransitionDir.left => _arabic ? 'يسار' : 'Left',
      PmlTransitionDir.right => _arabic ? 'يمين' : 'Right',
      PmlTransitionDir.up => _arabic ? 'أعلى' : 'Up',
      PmlTransitionDir.down => _arabic ? 'أسفل' : 'Down',
      PmlTransitionDir.horizontal => _arabic ? 'أفقي' : 'Horizontal',
      PmlTransitionDir.vertical => _arabic ? 'عمودي' : 'Vertical',
      PmlTransitionDir.inward => _arabic ? 'للداخل' : 'Inward',
      PmlTransitionDir.outward => _arabic ? 'للخارج' : 'Outward',
    };
  }

  String _advanceLabel(PmlSlideTransition t) {
    final int? ms = t.advanceAfterMs;
    if (ms == null || ms <= 0) {
      return _arabic ? 'تقديم يدوي' : 'Manually';
    }
    final int sec = (ms / 1000).round();
    return _arabic ? 'بعد $sec ث' : 'After ${sec}s';
  }

  PmlSlideTransition _cycleAdvance(PmlSlideTransition current) {
    final int? next = switch (current.advanceAfterMs) {
      null => 2000,
      <= 2000 => 5000,
      <= 5000 => 10000,
      _ => null,
    };
    return current.copyWith(
      advanceAfterMs: next,
      clearAdvanceAfter: next == null,
    );
  }

  IconData _transitionIcon(PmlTransitionKind kind) {
    return switch (kind) {
      PmlTransitionKind.none => Icons.block,
      PmlTransitionKind.morph => Icons.transform,
      PmlTransitionKind.fade ||
      PmlTransitionKind.fadeThroughBlack => Icons.blur_on,
      PmlTransitionKind.cut => Icons.content_cut,
      PmlTransitionKind.push => Icons.keyboard_double_arrow_left,
      PmlTransitionKind.wipe => Icons.cleaning_services_outlined,
      PmlTransitionKind.split ||
      PmlTransitionKind.doors => Icons.vertical_split,
      PmlTransitionKind.uncover || PmlTransitionKind.reveal => Icons.visibility,
      PmlTransitionKind.cover => Icons.layers,
      PmlTransitionKind.dissolve => Icons.grain,
      PmlTransitionKind.checkerboard => Icons.grid_on,
      PmlTransitionKind.blinds || PmlTransitionKind.comb => Icons.view_week,
      PmlTransitionKind.clock => Icons.schedule,
      PmlTransitionKind.shapeCircle => Icons.circle_outlined,
      PmlTransitionKind.shapeDiamond => Icons.diamond_outlined,
      PmlTransitionKind.shapePlus => Icons.add_box_outlined,
      PmlTransitionKind.newsflash => Icons.flash_on,
      PmlTransitionKind.zoom => Icons.zoom_in,
      PmlTransitionKind.flash => Icons.wb_sunny_outlined,
      PmlTransitionKind.strips ||
      PmlTransitionKind.randomBars => Icons.view_stream,
      PmlTransitionKind.gallery => Icons.view_carousel,
    };
  }

  List<StudioRibbonGroup> _slideView() {
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'عرض الشرائح' : 'Slide show',
        children: <Widget>[
          _cmd(
            Icons.slideshow,
            _arabic ? 'من البداية' : 'From start',
            _slides.isPresenting
                ? _slides.endShow
                : () => _slides.startShow(from: 0),
            selected: _slides.isPresenting,
          ),
          _cmd(
            Icons.play_arrow,
            _arabic ? 'من الحالية' : 'From current',
            () => _slides.startShow(from: _slides.activeSlideIndex),
          ),
          _cmd(
            Icons.view_sidebar_outlined,
            _arabic ? 'جزء الحركة' : 'Animation pane',
            () => setState(() => _showAnimPane = !_showAnimPane),
            selected: _showAnimPane,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'مسرح' : 'Stage',
        children: <Widget>[
          _cmd(
            Icons.highlight_alt,
            _arabic ? 'مقابض' : 'Handles',
            () => setState(() => _slideHandles = !_slideHandles),
            selected: _slideHandles,
          ),
          _cmd(
            Icons.notes,
            _arabic ? 'ملاحظات' : 'Notes',
            () => setState(() => _showNotes = !_showNotes),
            selected: _showNotes,
          ),
          _cmd(
            Icons.view_compact_alt,
            _arabic ? 'تخطيط' : 'Layout',
            _canMutate
                ? () => _slides.setStageKind(
                    _slides.stageKind == SlideStageKind.layout
                        ? SlideStageKind.slide
                        : SlideStageKind.layout,
                  )
                : null,
            selected: _slides.stageKind == SlideStageKind.layout,
          ),
          _cmd(
            Icons.layers_outlined,
            _arabic ? 'رئيس' : 'Master',
            _canMutate
                ? () => _slides.setStageKind(
                    _slides.stageKind == SlideStageKind.master
                        ? SlideStageKind.slide
                        : SlideStageKind.master,
                  )
                : null,
            selected: _slides.stageKind == SlideStageKind.master,
          ),
          ..._zoomCmds(),
        ],
      ),
    ];
  }

  List<Widget> _zoomCmds() {
    return <Widget>[
      _cmd(Icons.zoom_out, _arabic ? 'تصغير' : 'Zoom out', () {
        _setZoom(_viewScale - 0.1);
      }),
      _cmd(Icons.search, '$_zoomPercent%', () => _setZoom(1)),
      _cmd(Icons.zoom_in, _arabic ? 'تكبير' : 'Zoom in', () {
        _setZoom(_viewScale + 0.1);
      }),
    ];
  }

  double get _viewScale =>
      _app == SuiteApp.pdf ? _pdf.viewport.scale : _active.viewport.scale;

  int get _zoomPercent => (_viewScale * 100).round();

  void _setZoom(double value) {
    if (_app == SuiteApp.pdf) {
      _pdf.setScale(value);
      setState(() {});
      return;
    }
    _active.viewport.setScale(value);
    _active.refresh();
  }

  void _shortcutZoomIn() {
    if (_app == SuiteApp.pdf) {
      _pdf.zoomBy(1.1);
      return;
    }
    _setZoom(_viewScale + 0.1);
  }

  void _shortcutZoomOut() {
    if (_app == SuiteApp.pdf) {
      _pdf.zoomBy(1 / 1.1);
      return;
    }
    _setZoom(_viewScale - 0.1);
  }

  void _shortcutZoomReset() {
    _setZoom(1);
  }

  Future<void> _openFile() async {
    if (_opening || _isSaving) {
      return;
    }
    try {
      final PickedOfficeFile? picked = await StudioFiles.open();
      if (picked == null || !mounted) {
        return;
      }
      if (picked.name.toLowerCase().endsWith('.pdf')) {
        _switchApp(SuiteApp.pdf);
        if (picked.path != null && picked.path!.isNotEmpty) {
          await loadPdfFromFilePath(
            _pdf,
            picked.path!,
            onError: (Object error) {
              _toast(_arabic ? 'فشل فتح PDF: $error' : 'PDF open failed: $error');
            },
          );
        } else {
          final Uint8List pdfBytes = await StudioFiles.ensureBytes(picked);
          if (!mounted) {
            return;
          }
          await _pdf.loadBytesAsync(pdfBytes);
        }
        if (!mounted) {
          return;
        }
        _pdfPath = picked.path;
        _pdfName = _nameFromPicked(picked);
        return;
      }
      if (picked.kind == OpcPackageKind.unknown) {
        _toast(_arabic ? 'صيغة الملف غير معروفة.' : 'Unknown file format.');
        return;
      }
      setState(() {
        _opening = true;
        _openHeavy = _pickedFileIsHeavy(picked);
        _openProgress = 0.04;
        _openStage = 'archive';
        _openName = picked.name;
      });
      _startOpenTicker();
      await WidgetsBinding.instance.endOfFrame;
      final Uint8List bytes = await StudioFiles.ensureBytes(picked);
      if (!mounted) {
        return;
      }
      setState(() {
        _openHeavy = OfficeIsolateOpen.isHeavyBytes(bytes);
      });
      void onProgress(OfficeOpenProgress progress) {
        if (!mounted || !_opening) {
          return;
        }
        setState(() {
          _openStage = progress.stage;
          if (progress.value > _openProgress) {
            _openProgress = progress.value;
          }
        });
      }

      switch (picked.kind) {
        case OpcPackageKind.word:
          _switchApp(SuiteApp.word);
          await _word.loadBytesAsync(bytes, onProgress: onProgress);
          _wordPath = picked.path;
          _wordName = _nameFromPicked(picked);
        case OpcPackageKind.sheet:
          _switchApp(SuiteApp.excel);
          await _sheet.loadBytesAsync(bytes, onProgress: onProgress);
          _sheetPath = picked.path;
          _sheetName = _nameFromPicked(picked);
        case OpcPackageKind.slide:
          _switchApp(SuiteApp.powerpoint);
          await _slides.loadBytesAsync(bytes, onProgress: onProgress);
          _slidePath = picked.path;
          _slideName = _nameFromPicked(picked);
        case OpcPackageKind.unknown:
          break;
      }
      if (mounted) {
        setState(() => _openProgress = 1);
      }
    } catch (error) {
      _toast(_openFailureMessage(error));
    } finally {
      _stopOpenTicker();
      if (mounted) {
        setState(() {
          _opening = false;
          _openProgress = 0;
        });
      }
    }
  }

  String _openFailureMessage(Object error) {
    final Object root = error is StateError ? error.message : error;
    final PdfOpenError? kind = root is PdfOpenException
        ? root.error
        : _pdfOpenErrorFromText('$error');
    if (kind != null) {
      return switch (kind) {
        PdfOpenError.encrypted || PdfOpenError.wrongPassword =>
          _arabic
              ? 'الملف محمي بكلمة مرور.'
              : 'This PDF is password-protected.',
        PdfOpenError.unsupportedFilter =>
          _arabic
              ? 'المحرّك لا يفكّ هذا النوع من ضغط مجاري PDF بعد.'
              : 'This PDF uses a stream filter that is not decoded yet.',
        PdfOpenError.unsupportedHandler =>
          _arabic
              ? 'معالج حماية PDF غير مدعوم.'
              : 'This PDF uses an unsupported security handler.',
        PdfOpenError.limit =>
          _arabic
              ? 'الملف أكبر من حد الأمان.'
              : 'The file exceeds the safety limit.',
        PdfOpenError.badHeader || PdfOpenError.badXref =>
          _arabic
              ? 'ملف PDF تالف أو جدول الإسناد غير صالح.'
              : 'The PDF is damaged or its cross-reference table is invalid.',
      };
    }
    if ('$error'.contains('ZipDeflate') || '$error'.contains('Flate')) {
      return _arabic
          ? 'تعذر فك ضغط مجرى في ملف PDF.'
          : 'Could not inflate a stream inside the PDF.';
    }
    return _arabic
        ? 'تعذر فتح الملف. قد يكون الأرشيف تالفاً أو مضغوطاً بطريقة غير مدعومة بعد.'
        : 'Could not open the file. The archive may be damaged or use an unsupported compression stream.';
  }

  PdfOpenError? _pdfOpenErrorFromText(String text) {
    for (final PdfOpenError value in PdfOpenError.values) {
      if (text.contains('PdfOpenException.$value') ||
          text.contains('PdfOpenError.$value')) {
        return value;
      }
    }
    return null;
  }

  bool _pickedFileIsHeavy(PickedOfficeFile picked) {
    if (OfficeIsolateOpen.isHeavyBytes(picked.bytes)) {
      return true;
    }
    final String? path = picked.path;
    if (path == null || kIsWeb) {
      return false;
    }
    try {
      return File(path).lengthSync() >= OfficeSaveCost.isolateThresholdBytes;
    } on FileSystemException {
      return false;
    }
  }

  void _startOpenTicker() {
    _openTicker?.cancel();
    _openTicker = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted || !_opening) {
        return;
      }
      setState(() {
        final double cap = _openHeavy ? 0.82 : 0.90;
        final double step = _openHeavy ? 0.005 : 0.016;
        if (_openProgress < cap) {
          _openProgress += step;
        }
      });
    });
  }

  void _stopOpenTicker() {
    _openTicker?.cancel();
    _openTicker = null;
  }

  String get _openStatusLabel {
    final int percent = (_openProgress * 100).round().clamp(0, 100);
    final String name = _openName;
    final String action = name.isEmpty
        ? (_arabic ? 'جاري الفتح' : 'Opening')
        : (_arabic ? 'جاري فتح $name' : 'Opening $name');
    final String stage = switch (_openStage) {
      'archive' => _arabic ? 'الأرشيف' : 'archive',
      'document' => _arabic ? 'المستند' : 'document',
      'layout' => _arabic ? 'التخطيط' : 'layout',
      'formulas' => _arabic ? 'الصيغ' : 'formulas',
      'apply' => _arabic ? 'العرض' : 'display',
      _ => _openStage,
    };
    final String heavy = _openHeavy
        ? (_arabic ? ' · ملف كبير' : ' · large file')
        : '';
    return '$action$heavy · $stage · $percent%';
  }

  bool get _isSaving => _savePhase != _SavePhase.idle;

  String? get _activePath => switch (_app) {
    SuiteApp.word => _wordPath,
    SuiteApp.excel => _sheetPath,
    SuiteApp.powerpoint => _slidePath,
    SuiteApp.pdf => _pdfPath,
  };

  set _activePath(String? value) {
    switch (_app) {
      case SuiteApp.word:
        _wordPath = value;
      case SuiteApp.excel:
        _sheetPath = value;
      case SuiteApp.powerpoint:
        _slidePath = value;
      case SuiteApp.pdf:
        _pdfPath = value;
    }
  }

  String get _defaultSaveName {
    final String name = _activeName.trim();
    if (name.isNotEmpty) {
      return name;
    }
    return _untitledName;
  }

  OpcPackageKind get _activeKind => switch (_app) {
    SuiteApp.word => OpcPackageKind.word,
    SuiteApp.excel => OpcPackageKind.sheet,
    SuiteApp.powerpoint => OpcPackageKind.slide,
    SuiteApp.pdf => OpcPackageKind.unknown,
  };

  bool get _activeSaveIsHeavy => switch (_app) {
    SuiteApp.word => OfficeSaveCost.isHeavyWord(_word.document),
    SuiteApp.excel => OfficeSaveCost.isHeavyWorkbook(_sheet.workbook),
    SuiteApp.powerpoint => OfficeSaveCost.isHeavyPresentation(
      _slides.presentation,
    ),
    SuiteApp.pdf => false,
  };

  String get _saveStatusLabel {
    if (_savePhase == _SavePhase.picking) {
      return _arabic ? 'اختر مكان الحفظ' : 'Choose save location';
    }
    final int percent = (_saveProgress * 100).round();
    final String? path = _activePath;
    final String name = path == null ? '' : StudioFiles.nameOf(path);
    final String action = name.isEmpty
        ? (_arabic ? 'جاري الحفظ' : 'Saving')
        : (_arabic ? 'جاري حفظ $name' : 'Saving $name');
    final String heavy = _saveHeavy
        ? (_arabic ? ' · ملف كبير' : ' · large file')
        : '';
    return '$action$heavy · $percent%';
  }

  void _startSaveTicker() {
    _saveTicker?.cancel();
    _saveTicker = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted || _savePhase != _SavePhase.saving) {
        return;
      }
      setState(() {
        final double cap = _saveHeavy ? 0.78 : 0.88;
        final double step = _saveHeavy ? 0.006 : 0.018;
        if (_saveProgress < cap) {
          _saveProgress += step;
        }
      });
    });
  }

  void _stopSaveTicker() {
    _saveTicker?.cancel();
    _saveTicker = null;
  }

  Future<void> _saveFile() async {
    if (_isSaving) {
      return;
    }
    if (_app == SuiteApp.pdf) {
      await StudioFiles.save(
        bytes: _pdf.saveBytes(),
        fileName: _defaultSaveName,
      );
      return;
    }
    try {
      final String name = _defaultSaveName;
      if (kIsWeb) {
        setState(() {
          _saveHeavy = _activeSaveIsHeavy;
          _savePhase = _SavePhase.saving;
          _saveProgress = 0.04;
        });
        _startSaveTicker();
        await WidgetsBinding.instance.endOfFrame;
        final Uint8List bytes = await _active.saveBytesAsync();
        if (!mounted) {
          return;
        }
        await StudioFiles.save(bytes: bytes, fileName: name);
        _active.markClean();
        return;
      }

      String? path = _activePath;
      if (path == null) {
        setState(() => _savePhase = _SavePhase.picking);
        path = await StudioFiles.pickSavePath(fileName: name);
        if (path == null || !mounted) {
          return;
        }
        path = StudioFiles.withExtension(path, name);
        _activePath = path;
        _activeName = StudioFiles.nameOf(path);
      }

      setState(() {
        _saveHeavy = _activeSaveIsHeavy;
        _savePhase = _SavePhase.saving;
        _saveProgress = 0.04;
      });
      _startSaveTicker();
      await WidgetsBinding.instance.endOfFrame;
      await StudioFiles.saveOfficeToPath(
        path: path,
        kind: _activeKind,
        word: _app == SuiteApp.word ? _word.document : null,
        workbook: _app == SuiteApp.excel ? _sheet.workbook : null,
        presentation: _app == SuiteApp.powerpoint ? _slides.presentation : null,
      );
      if (!mounted) {
        return;
      }
      _active.markClean();
      setState(() => _saveProgress = 1);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    } catch (error) {
      _toast(_arabic ? 'تعذر حفظ الملف.' : 'Could not save the file.');
    } finally {
      _stopSaveTicker();
      if (mounted) {
        setState(() {
          _savePhase = _SavePhase.idle;
          _saveHeavy = false;
          _saveProgress = 0;
        });
      }
    }
  }

  Future<void> _exportPdf() async {
    try {
      if (_app == SuiteApp.pdf) {
        await StudioFiles.save(bytes: _pdf.saveBytes(), fileName: _pdfName);
        return;
      }
      final String stem = switch (_app) {
        SuiteApp.word => 'document',
        SuiteApp.excel => 'workbook',
        SuiteApp.powerpoint => 'presentation',
        SuiteApp.pdf => 'document',
      };
      final OfficeFontSet fonts = switch (_app) {
        SuiteApp.word => StudioFiles.exportFontSetForWord(
          _word.document,
          themeFamily: _officeTheme.fontFamily,
        ),
        SuiteApp.excel => StudioFiles.exportFontSetCovering(<String>[
          'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
          for (final SmlWorksheet sheet in _sheet.workbook.sheets) ...<String>[
            sheet.name,
            for (final SmlCell cell in sheet.allCells) cell.asString,
            for (final SmlDrawing drawing in sheet.drawings) ...<String>[
              drawing.visual.title,
              for (final ChartPoint point in drawing.visual.points) point.label,
            ],
          ],
        ]),
        SuiteApp.powerpoint => StudioFiles.exportFontSetCovering(<String>[
          for (final PmlSlide slide in _slides.presentation.slides) ...<String>[
            slide.notes,
            for (final PmlShape shape in slide.shapes) ...<String>[
              _slides.presentation.resolveText(shape, slide),
              if (shape.visual != null) shape.visual!.title,
              if (shape.visual != null)
                for (final ChartPoint point in shape.visual!.points)
                  point.label,
            ],
          ],
        ]),
        SuiteApp.pdf => const OfficeFontSet(),
      };
      final Uint8List bytes = _active.exportPdf(
        settings: OfficePrintSettings(title: stem),
        font: fonts.primary,
        fonts: fonts.isEmpty ? null : fonts,
      );
      await StudioFiles.save(bytes: bytes, fileName: '$stem.pdf');
    } catch (error) {
      _toast(_arabic ? 'تعذر تصدير PDF.' : 'Could not export PDF.');
    }
  }

  void _bindHostActions(OfficeController controller) {
    controller.onFindRequested = () {
      if (!mounted) {
        return;
      }
      setState(() {
        _findOpen = true;
        _findReplace = false;
      });
    };
    controller.onReplaceRequested = () {
      if (!mounted) {
        return;
      }
      setState(() {
        _findOpen = true;
        _findReplace = true;
      });
    };
    controller.onPrintRequested = () {
      _exportPdf();
    };
    controller.onSpellCheckRequested = _showSpelling;
  }

  void _openFind() {
    if (_app == SuiteApp.pdf) {
      setState(() => _findOpen = true);
      return;
    }
    _active.requestFind();
  }

  void _openReplace() => _active.requestReplace();

  void _closeFind() {
    _pdfFindDebounce?.cancel();
    if (_app == SuiteApp.pdf) {
      _pdf.find('');
    } else {
      _active.closeFind();
    }
    setState(() => _findOpen = false);
  }

  void _findNext() {
    if (!_findOpen) {
      _openFind();
      return;
    }
    if (_app == SuiteApp.pdf) {
      _pdfFindNext();
      return;
    }
    _active.findNext();
    setState(() {});
  }

  void _findPrevious() {
    if (!_findOpen) {
      _openFind();
      return;
    }
    if (_app == SuiteApp.pdf) {
      _pdfFindPrevious();
      return;
    }
    _active.findPrevious();
    setState(() {});
  }

  void _workspaceEscape() {
    if (_findOpen) {
      _closeFind();
      return;
    }
    _slideShowEscape();
  }

  void _showSpelling() {
    if (_active is WordEditorController) {
      final List<OfficeSpellIssue> issues = _word.checkSpelling();
      _toast(
        issues.isEmpty
            ? (_arabic ? 'لا أخطاء ظاهرة' : 'No issues (host dictionary)')
            : '${issues.length}',
      );
      return;
    }
    _toast(_arabic ? 'التدقيق للمستندات' : 'Spelling is available in Word');
  }

  Future<void> _showProperties() async {
    final OfficeDocumentProperties props = _active.documentProperties.copy();
    final TextEditingController title = TextEditingController(
      text: props.title,
    );
    final TextEditingController author = TextEditingController(
      text: props.creator,
    );
    try {
      final bool? save = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(_arabic ? 'خصائص المستند' : 'Document properties'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: _arabic ? 'العنوان' : 'Title',
                  ),
                ),
                TextField(
                  controller: author,
                  decoration: InputDecoration(
                    labelText: _arabic ? 'المؤلف' : 'Author',
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_arabic ? 'إلغاء' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_arabic ? 'حفظ' : 'Save'),
              ),
            ],
          );
        },
      );
      if (save == true) {
        _active.documentProperties
          ..title = title.text
          ..creator = author.text;
        _active.refresh();
      }
    } finally {
      title.dispose();
      author.dispose();
    }
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  StudioRibbonGroup _clipboardGroup() {
    final OfficeStrings strings = _arabic
        ? OfficeStrings.arabic
        : OfficeStrings.english;
    return StudioRibbonGroup(
      title: _arabic ? 'الحافظة' : 'Clipboard',
      children: <Widget>[
        StudioPasteCmd(
          accent: _accent,
          foreground: _officeTheme.chromeText,
          pasteLabel: strings.paste,
          keepSourceLabel: strings.pasteKeepSource,
          mergeLabel: strings.pasteMerge,
          textOnlyLabel: strings.pasteTextOnly,
          onPaste: _canMutate ? _paste : null,
          onKeepSource: _canMutate
              ? () => _pasteMode(OfficePasteMode.keepSource)
              : null,
          onMerge: _canMutate
              ? () => _pasteMode(OfficePasteMode.mergeFormatting)
              : null,
          onTextOnly: _canMutate
              ? () => _pasteMode(OfficePasteMode.keepTextOnly)
              : null,
        ),
        _cmd(
          Icons.content_cut,
          strings.cut,
          _canMutate && _active.canCut ? _cut : null,
        ),
        _cmd(Icons.content_copy, strings.copy, _active.canCopy ? _copy : null),
      ],
    );
  }

  Widget _pasteOptionsBar(bool dark) {
    final OfficeStrings strings = _arabic
        ? OfficeStrings.arabic
        : OfficeStrings.english;
    return Material(
      color: dark ? const Color(0xFF333333) : const Color(0xFFF3F3F3),
      child: SizedBox(
        height: 36,
        child: Row(
          children: <Widget>[
            const SizedBox(width: 12),
            Icon(Icons.content_paste, size: 16, color: _accent),
            const SizedBox(width: 8),
            Text(
              strings.paste,
              style: TextStyle(fontSize: 12, color: _officeTheme.chromeText),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => _pasteMode(OfficePasteMode.keepSource),
              child: Text(strings.pasteKeepSource),
            ),
            TextButton(
              onPressed: () => _pasteMode(OfficePasteMode.mergeFormatting),
              child: Text(strings.pasteMerge),
            ),
            TextButton(
              onPressed: () => _pasteMode(OfficePasteMode.keepTextOnly),
              child: Text(strings.pasteTextOnly),
            ),
            const Spacer(),
            IconButton(
              tooltip: _arabic ? 'إغلاق' : 'Close',
              onPressed: () => setState(() => _showPasteOptions = false),
              icon: const Icon(Icons.close, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  StudioCmd _cmd(
    IconData icon,
    String label,
    VoidCallback? onPressed, {
    bool selected = false,
  }) {
    return StudioCmd(
      icon: icon,
      label: label,
      accent: _accent,
      foreground: _officeTheme.chromeText,
      onPressed: onPressed,
      selected: selected,
    );
  }

  StudioIconCmd _icon(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed, {
    bool selected = false,
  }) {
    return StudioIconCmd(
      icon: icon,
      tooltip: tooltip,
      accent: _accent,
      foreground: _officeTheme.chromeText,
      onPressed: onPressed,
      selected: selected,
    );
  }

  WmlParagraph get _activeParagraph {
    final List<WmlParagraph> paras = _word.document.paragraphs.toList();
    if (paras.isEmpty) {
      return WmlParagraph();
    }
    return paras[_word.documentCaret.paragraphIndex.clamp(0, paras.length - 1)];
  }

  bool get _wordFullFormat => _canMutate && !_word.commentFormatLimited;

  bool get _canEditSlideText =>
      _canMutate &&
      _slides.selected != null &&
      _slides.selected!.visual == null &&
      _slides.selected!.table == null;

  bool get _canEditSlideTable => _canMutate && _slides.selectedTable != null;

  void _setAlign(WmlJustification justification) {
    if (!_wordFullFormat) {
      return;
    }
    _word.applyParagraphFormat((WmlParagraphProps props) {
      props.justification = justification;
    });
  }

  void _setWordDirection({required bool rtl}) {
    if (!_wordFullFormat) {
      return;
    }
    _word.setParagraphDirection(rtl: rtl);
  }

  KeyEventResult _onWorkspaceDirectionKey(FocusNode node, KeyEvent event) {
    final bool? rtl = officeDirectionFromKeyEvent(event);
    if (rtl == null || !_canMutate) {
      return KeyEventResult.ignored;
    }
    switch (_app) {
      case SuiteApp.word:
        if (!_wordFullFormat) {
          return KeyEventResult.ignored;
        }
        _word.setParagraphDirection(rtl: rtl);
        return KeyEventResult.handled;
      case SuiteApp.excel:
        _sheet.setSheetRightToLeft(rtl);
        return KeyEventResult.handled;
      case SuiteApp.powerpoint:
        if (!_canEditSlideText) {
          return KeyEventResult.ignored;
        }
        _slides.setSelectedTextDirection(rtl: rtl);
        return KeyEventResult.handled;
      case SuiteApp.pdf:
        return KeyEventResult.ignored;
    }
  }

  static const List<String> _textColors = <String>[
    '000000',
    '1F4E79',
    'C00000',
    '217346',
    'B7472A',
  ];

  static const List<String?> _highlights = <String?>[
    null,
    'FFFF00',
    '00B0F0',
    '92D050',
  ];

  void _cycleTextColor() {
    _word.applyRunFormat((WmlRunProps p) {
      final int i = _textColors.indexOf(p.color);
      p.color = _textColors[(i + 1) % _textColors.length];
    });
  }

  void _cycleHighlight() {
    _word.applyRunFormat((WmlRunProps p) {
      final int i = _highlights.indexOf(p.highlight);
      p.highlight = _highlights[(i + 1) % _highlights.length];
    });
  }

  void _nudgeFontSize(int deltaHalfPoints) {
    _word.applyRunFormat((WmlRunProps p) {
      p.fontSizeHalfPoints = (p.fontSizeHalfPoints + deltaHalfPoints)
          .clamp(16, 144)
          .toInt();
    });
  }

  List<String> get _fontFamilies {
    final String current = _activeFontFamily;
    if (OfficeTypeface.families.contains(current)) {
      return OfficeTypeface.families;
    }
    return <String>[current, ...OfficeTypeface.families];
  }

  String get _activeFontFamily {
    final WmlRunProps props = _word.activeRunProps;
    final List<WmlParagraph> paras = _word.document.paragraphs.toList();
    final String paraText = paras.isEmpty
        ? ''
        : paras[_word.documentCaret.paragraphIndex.clamp(0, paras.length - 1)]
              .text;
    final bool rtl = PaintRunText.looksRtl(paraText);
    final String face = rtl
        ? (props.csFont.isNotEmpty ? props.csFont : props.asciiFont)
        : (props.asciiFont.isNotEmpty ? props.asciiFont : props.csFont);
    if (OfficeTypeface.families.contains(face)) {
      return face;
    }
    if (face.isNotEmpty) {
      return face;
    }
    return _officeTheme.fontFamily ?? OfficeTypeface.arabicTheme;
  }

  int get _activeFontSizePt {
    final int pt = _word.activeRunProps.fontSizeHalfPoints ~/ 2;
    if (OfficeTypeface.sizesPt.contains(pt)) {
      return pt;
    }
    return pt.clamp(OfficeTypeface.sizesPt.first, OfficeTypeface.sizesPt.last);
  }

  StudioFaceStyle get _activeFaceStyle {
    final WmlRunProps props = _word.activeRunProps;
    if (props.bold && props.italic) {
      return StudioFaceStyle.boldItalic;
    }
    if (props.bold) {
      return StudioFaceStyle.bold;
    }
    if (props.italic) {
      return StudioFaceStyle.italic;
    }
    return StudioFaceStyle.regular;
  }

  int get _slideFontSizePt {
    final double size = _slides.selected?.fontSizePt ?? 18;
    final int pt = size > 0 ? size.round() : 18;
    if (OfficeTypeface.sizesPt.contains(pt)) {
      return pt;
    }
    return pt.clamp(OfficeTypeface.sizesPt.first, OfficeTypeface.sizesPt.last);
  }

  String _faceStyleLabel(StudioFaceStyle style) {
    return switch (style) {
      StudioFaceStyle.regular => _arabic ? 'عادي' : 'Regular',
      StudioFaceStyle.bold => _arabic ? 'عريض' : 'Bold',
      StudioFaceStyle.italic => _arabic ? 'مائل' : 'Italic',
      StudioFaceStyle.boldItalic => _arabic ? 'عريض مائل' : 'Bold Italic',
    };
  }

  void _setFontFamily(String family) {
    _word.applyRunFormat((WmlRunProps p) {
      p.asciiFont = family;
      p.csFont = family;
    });
  }

  void _setFontSizePt(int pt) {
    _word.applyRunFormat((WmlRunProps p) {
      p.fontSizeHalfPoints = (pt * 2).clamp(16, 144);
    });
  }

  void _setFaceStyle(StudioFaceStyle style) {
    _word.applyRunFormat((WmlRunProps p) {
      p.bold =
          style == StudioFaceStyle.bold || style == StudioFaceStyle.boldItalic;
      p.italic =
          style == StudioFaceStyle.italic ||
          style == StudioFaceStyle.boldItalic;
    });
  }

  void _toggleVertAlign(WmlVertAlign align) {
    _word.applyRunFormat((WmlRunProps p) {
      p.vertAlign = p.vertAlign == align ? WmlVertAlign.baseline : align;
    });
  }

  void _nudgeIndent(double delta) {
    _word.applyParagraphFormat((WmlParagraphProps p) {
      final WmlIndent current = p.indent;
      p.indent = WmlIndent(
        left: (current.left + delta).clamp(0, 144),
        right: current.right,
        firstLine: current.firstLine,
        hanging: current.hanging,
      );
    });
  }

  void _insertStudioCitation() {
    _word.insertCitation(
      WmlCitation(
        tag: 'Quds',
        author: _arabic ? 'مكتب القدس' : 'Quds Office',
        title: _arabic ? 'دليل المكتب' : 'Office Guide',
        year: '2026',
      ),
    );
  }

  void _studioMergeMail() {
    if (WordMailMerge.fieldsOf(_word.document).isEmpty) {
      _word.insertText(_arabic ? 'عزيزي «الاسم»،' : 'Dear «Name»,');
    }
    _word.mergeMail(<String, String>{'Name': 'Mohammed', 'الاسم': 'محمد'});
  }

  void _studioCompareDocument() {
    _word.compareWith(
      WmlDocument.empty(text: _arabic ? 'نسخة للمقارنة' : 'Comparison copy'),
    );
  }

  void _studioSheetValidation() {
    _sheet.addValidation(
      SmlDataValidation(
        range: _sheet.selection.range,
        kind: SmlValidationKind.list,
        formula1: _arabic ? 'نعم,لا' : 'Yes,No',
      ),
    );
  }

  void _studioMergePreview() {
    final List<Map<String, String>> records = <Map<String, String>>[
      <String, String>{'Name': 'Ada', 'الاسم': 'آدا'},
      <String, String>{'Name': 'Omar', 'الاسم': 'عمر'},
    ];
    final int next = (_word.document.mailMergePreview + 1) % records.length;
    _word.previewMailMerge(records, index: next);
  }

  void _studioGoalSeek() {
    final SmlRange range = _sheet.selection.range;
    _sheet.goalSeek(
      target: SmlCellRef(range.maxCol, range.maxRow),
      changing: SmlCellRef(range.minCol, range.minRow),
      goal: 10,
    );
  }

  void _studioImportCsv() {
    _sheet.importCsv('Name,Amt\nAda,4\nOmar,6');
  }

  void _studioInsertPivot() {
    final SmlRange range = _sheet.selection.range;
    _sheet.insertPivot(
      source: range,
      rowField: 0,
      dataField: range.maxCol > range.minCol ? 1 : 0,
    );
  }

  void _insertWordTable(int rows, int cols) {
    final double width = cols == 2 ? 180 : 120;
    _insertBlockAfterActive(
      WmlTable(
        grid: <double>[for (int c = 0; c < cols; c++) width],
        rows: <WmlTableRow>[
          for (int r = 0; r < rows; r++)
            WmlTableRow(
              cells: <WmlTableCell>[
                for (int c = 0; c < cols; c++)
                  WmlTableCell(
                    blocks: <WmlBlock>[
                      WmlParagraph(
                        inlines: <WmlInline>[
                          WmlRun(
                            text: _arabic
                                ? 'خلية ${r + 1}×${c + 1}'
                                : 'Cell ${r + 1}×${c + 1}',
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<Uint8List> _pictureBytes({required bool fromFile}) async {
    if (fromFile) {
      final Uint8List? picked = await StudioFiles.pickImage();
      if (picked != null) {
        return picked;
      }
    }
    return PngBytes.studioCard();
  }

  Future<void> _insertWordPicture({bool fromFile = false}) async {
    if (_word.isEditingComment) {
      await _insertCommentPicture();
      return;
    }
    final Uint8List bytes = await _pictureBytes(fromFile: fromFile);
    _insertBlockAfterActive(
      WmlVisual(
        visual: OfficeVisual(
          kind: OfficeVisualKind.picture,
          title: _arabic ? 'صورة' : 'Picture',
          imageBytes: bytes,
          width: 280,
          height: 160,
        ),
      ),
    );
  }

  void _insertWordEquation({String id = 'blank'}) {
    final OmmlEquation math = OmmlGallery.byId(id).build();
    _word.insertEquation(math);
    setState(() => _tab = _RibbonTab.design);
  }

  List<StudioRibbonGroup> _wordEquationTools() {
    final bool active = _word.selectedEquation != null && _canMutate;
    final OmmlView view =
        _word.selectedEquation?.math.view ?? OmmlView.professional;
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'أدوات' : 'Tools',
        children: <Widget>[
          _cmd(
            Icons.auto_awesome,
            _arabic ? 'احترافي' : 'Professional',
            active ? () => _word.setEquationView(OmmlView.professional) : null,
            selected: view == OmmlView.professional,
          ),
          _cmd(
            Icons.short_text,
            _arabic ? 'خطي' : 'Linear',
            active ? () => _word.setEquationView(OmmlView.linear) : null,
            selected: view == OmmlView.linear,
          ),
          _cmd(
            Icons.delete_outline,
            _arabic ? 'حذف' : 'Delete',
            active ? _word.deleteSelectedEquation : null,
          ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'رموز' : 'Symbols',
        children: <Widget>[
          for (final String symbol in const <String>[
            'π',
            'θ',
            'α',
            'β',
            'λ',
            '∞',
            '±',
            '×',
            '÷',
            '≠',
            '≤',
            '≥',
            '→',
          ])
            _cmd(
              Icons.functions,
              symbol,
              active ? () => _word.insertEquationSymbol(symbol) : null,
            ),
        ],
      ),
      StudioRibbonGroup(
        title: _arabic ? 'تراكيب' : 'Structures',
        children: <Widget>[
          _cmd(
            Icons.horizontal_split,
            _arabic ? 'كسر' : 'Fraction',
            active
                ? () => _word.applyEquationStructure(OmmlStructure.fractionBar)
                : null,
          ),
          _cmd(
            Icons.superscript,
            _arabic ? 'أس' : 'Script',
            active
                ? () => _word.applyEquationStructure(OmmlStructure.superscript)
                : null,
          ),
          _cmd(
            Icons.square_foot,
            _arabic ? 'جذر' : 'Radical',
            active
                ? () => _word.applyEquationStructure(OmmlStructure.squareRoot)
                : null,
          ),
          _cmd(
            Icons.integration_instructions,
            '∫',
            active
                ? () => _word.applyEquationStructure(
                    OmmlStructure.integralDefinite,
                  )
                : null,
          ),
          _cmd(
            Icons.functions,
            '∑',
            active
                ? () => _word.applyEquationStructure(OmmlStructure.sum)
                : null,
          ),
          _cmd(
            Icons.data_array,
            _arabic ? 'قوس' : 'Bracket',
            active
                ? () => _word.applyEquationStructure(OmmlStructure.paren)
                : null,
          ),
          _cmd(
            Icons.grid_on,
            _arabic ? 'مصفوفة' : 'Matrix',
            active
                ? () => _word.applyEquationStructure(OmmlStructure.matrix2x2)
                : null,
          ),
          _cmd(
            Icons.architecture,
            _arabic ? 'sin' : 'sin',
            active
                ? () => _word.applyEquationStructure(OmmlStructure.sin)
                : null,
          ),
          _cmd(
            Icons.trending_flat,
            _arabic ? 'نهاية' : 'Limit',
            active
                ? () => _word.applyEquationStructure(OmmlStructure.lim)
                : null,
          ),
          _cmd(
            Icons.change_history,
            _arabic ? 'قبعة' : 'Accent',
            active
                ? () => _word.applyEquationStructure(OmmlStructure.accentHat)
                : null,
          ),
        ],
      ),
    ];
  }

  void _insertWordVisual(OfficeVisualKind kind) {
    final bool diagram =
        kind == OfficeVisualKind.diagramProcess ||
        kind == OfficeVisualKind.diagramCycle ||
        kind == OfficeVisualKind.diagramHierarchy;
    _insertBlockAfterActive(
      WmlVisual(
        visual: OfficeVisual(
          kind: kind,
          title: _visualTitle(kind),
          points: diagram
              ? OfficeVisual.sampleSteps(arabic: _arabic)
              : OfficeVisual.sampleSeries(arabic: _arabic),
          width: 400,
          height: diagram ? 130 : 180,
        ),
      ),
    );
  }

  String _visualTitle(OfficeVisualKind kind) {
    return switch (kind) {
      OfficeVisualKind.picture => _arabic ? 'صورة' : 'Picture',
      OfficeVisualKind.chartColumn => _arabic ? 'أعمدة' : 'Column chart',
      OfficeVisualKind.chartBar => _arabic ? 'شريطي' : 'Bar chart',
      OfficeVisualKind.chartPie => _arabic ? 'دائري' : 'Pie chart',
      OfficeVisualKind.chartLine => _arabic ? 'خطي' : 'Line chart',
      OfficeVisualKind.diagramProcess => _arabic ? 'عملية' : 'Process',
      OfficeVisualKind.diagramCycle => _arabic ? 'دورة' : 'Cycle',
      OfficeVisualKind.diagramHierarchy => _arabic ? 'هرمي' : 'Hierarchy',
    };
  }

  List<ChartPoint> _chartPointsFromSheet() {
    final SmlRange range = _sheet.selection.range;
    if (range.start.col == range.end.col && range.start.row == range.end.row) {
      return OfficeVisual.sampleSeries(arabic: _arabic);
    }
    final List<ChartPoint> points = SheetChartData.fromRange(
      book: _sheet.workbook,
      sheet: _sheet.sheet,
      from: range.start,
      to: range.end,
    );
    return points.isEmpty ? OfficeVisual.sampleSeries(arabic: _arabic) : points;
  }

  Future<void> _insertSheetPicture({bool fromFile = false}) async {
    final Uint8List bytes = await _pictureBytes(fromFile: fromFile);
    _sheet.sheet.drawings.add(
      SmlDrawing(
        visual: OfficeVisual(
          kind: OfficeVisualKind.picture,
          title: _arabic ? 'صورة' : 'Picture',
          imageBytes: bytes,
          width: 240,
          height: 140,
        ),
        col: (_sheet.selection.focus.col + 2).clamp(0, 20),
        row: _sheet.selection.focus.row,
      ),
    );
    _sheet.selectDrawing(_sheet.sheet.drawings.length - 1);
  }

  void _insertSheetChart(OfficeVisualKind kind) {
    final SmlRange range = _sheet.selection.range;
    final bool linked =
        range.start.col != range.end.col || range.start.row != range.end.row;
    _sheet.sheet.drawings.add(
      SmlDrawing(
        visual: OfficeVisual(
          kind: kind,
          title: _visualTitle(kind),
          points: _chartPointsFromSheet(),
          width: 280,
          height: 160,
        ),
        col: (_sheet.selection.focus.col + 2).clamp(0, 20),
        row: _sheet.selection.focus.row,
        sourceFromA1: linked ? range.start.a1 : null,
        sourceToA1: linked ? range.end.a1 : null,
      ),
    );
    _sheet.selectDrawing(_sheet.sheet.drawings.length - 1);
  }

  Future<void> _insertSlidePicture({bool fromFile = false}) async {
    final Uint8List bytes = await _pictureBytes(fromFile: fromFile);
    final PmlSlide slide = _slides.slide;
    final PmlShape shape = PmlShape(
      id: _nextShapeId(slide),
      name: 'Picture',
      fillColor: 'FFFFFF',
      transform: const PmlTransform(
        x: 2200000,
        y: 1200000,
        cx: 4700000,
        cy: 2600000,
      ),
      visual: OfficeVisual(
        kind: OfficeVisualKind.picture,
        title: _arabic ? 'صورة' : 'Picture',
        imageBytes: bytes,
      ),
    );
    slide.shapes.add(shape);
    _slides.selectShape(shape);
  }

  void _insertSlideVisual(OfficeVisualKind kind) {
    final PmlSlide slide = _slides.slide;
    final bool diagram =
        kind == OfficeVisualKind.diagramProcess ||
        kind == OfficeVisualKind.diagramCycle ||
        kind == OfficeVisualKind.diagramHierarchy;
    final PmlShape shape = PmlShape(
      id: _nextShapeId(slide),
      name: kind.name,
      fillColor: 'FFFFFF',
      transform: const PmlTransform(
        x: 1600000,
        y: 1100000,
        cx: 5900000,
        cy: 2800000,
      ),
      visual: OfficeVisual(
        kind: kind,
        title: _visualTitle(kind),
        points: diagram
            ? OfficeVisual.sampleSteps(arabic: _arabic)
            : OfficeVisual.sampleSeries(arabic: _arabic),
      ),
    );
    slide.shapes.add(shape);
    _slides.selectShape(shape);
  }

  void _openExternalLink(WmlHyperlink link) {
    final String? target = link.url ?? link.file;
    if (target == null || target.isEmpty) {
      return;
    }
    if (Platform.isWindows) {
      Process.start('cmd', <String>['/c', 'start', '', target]);
    } else if (Platform.isMacOS) {
      Process.start('open', <String>[target]);
    } else {
      Process.start('xdg-open', <String>[target]);
    }
  }

  bool get _selectedThreadResolved {
    final int? id = _word.selectedCommentId;
    if (id == null) {
      return false;
    }
    return WordComment.byId(
          _word.document,
          WordComment.threadRootId(_word.document, id),
        )?.resolved ??
        false;
  }

  void _newWordComment() {
    if (!_canMutate) {
      return;
    }
    setState(() => _showComments = true);
    _word.insertComment(author: 'Quds Office', initials: 'QO');
  }

  Future<void> _replyWordComment(int parentId) async {
    if (!_canMutate) {
      return;
    }
    setState(() => _showComments = true);
    _word.selectComment(parentId);
    if (_commentReply.text.trim().isNotEmpty) {
      _sendCommentReply(parentId);
      return;
    }
    final TextEditingController reply = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_arabic ? 'رد على التعليق' : 'Reply to comment'),
          content: TextField(
            controller: reply,
            minLines: 2,
            maxLines: 5,
            autofocus: true,
            decoration: InputDecoration(labelText: _arabic ? 'الرد' : 'Reply'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_arabic ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_arabic ? 'إرسال' : 'Reply'),
            ),
          ],
        );
      },
    );
    final String text = reply.text.trim();
    reply.dispose();
    if (ok == true && text.isNotEmpty) {
      _word.replyToComment(parentId, text: text);
    }
  }

  void _sendCommentReply(int parentId) {
    final String text = _commentReply.text.trim();
    if (text.isEmpty || !_canMutate) {
      return;
    }
    _word.replyToComment(parentId, text: text);
    _commentReply.clear();
  }

  Future<void> _insertCommentPicture() async {
    final int? id = _word.selectedCommentId;
    if (id == null || !_canMutate) {
      return;
    }
    final Uint8List bytes = await _pictureBytes(fromFile: true);
    _word.insertCommentVisual(
      id,
      OfficeVisual(
        kind: OfficeVisualKind.picture,
        title: _arabic ? 'صورة' : 'Picture',
        imageBytes: bytes,
        width: 180,
        height: 100,
      ),
    );
  }

  String _commentDateLabel(WmlComment comment) {
    if (comment.dateIso.isEmpty) {
      return '';
    }
    final DateTime? parsed = DateTime.tryParse(comment.dateIso);
    if (parsed == null) {
      return comment.dateIso;
    }
    final DateTime local = parsed.toLocal();
    final String mm = local.month.toString().padLeft(2, '0');
    final String dd = local.day.toString().padLeft(2, '0');
    final String hh = local.hour.toString().padLeft(2, '0');
    final String min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  Color _hexColor(String hex) {
    final int value = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0;
    return Color(0xFF000000 | value);
  }

  TextStyle _commentRunStyle(WmlRunProps props) {
    return TextStyle(
      fontSize: 12,
      height: 1.35,
      fontWeight: props.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: props.italic ? FontStyle.italic : FontStyle.normal,
      decoration: props.strike
          ? TextDecoration.lineThrough
          : props.underline == WmlUnderline.none
          ? TextDecoration.none
          : TextDecoration.underline,
      color: _hexColor(props.color),
      backgroundColor: props.highlight == null
          ? null
          : _hexColor(props.highlight!),
    );
  }

  List<InlineSpan> _commentSpans(WmlComment comment) {
    final List<InlineSpan> spans = <InlineSpan>[];
    for (int i = 0; i < comment.paragraphs.length; i++) {
      if (i > 0) {
        spans.add(const TextSpan(text: '\n'));
      }
      for (final WmlInline inline in comment.paragraphs[i].inlines) {
        if (inline is WmlRun && inline.text.isNotEmpty) {
          spans.add(
            TextSpan(
              text: inline.text,
              style: _commentRunStyle(inline.properties),
            ),
          );
        }
      }
    }
    if (spans.isEmpty && comment.text.isNotEmpty) {
      spans.add(TextSpan(text: comment.text));
    }
    return spans;
  }

  Widget _wordCommentsPane(bool dark) {
    final Color bg = dark ? const Color(0xFF242424) : const Color(0xFFF3F3F3);
    final List<WmlComment> roots = WordComment.roots(_word.document);
    return Material(
      color: bg,
      child: SizedBox(
        width: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StudioPaneTitle(
              text: _arabic ? 'تعليقات' : 'Comments',
              accent: _accent,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      roots.isEmpty
                          ? (_arabic ? 'لا تعليقات' : 'No comments')
                          : (_arabic
                                ? '${roots.length} محادثة'
                                : '${roots.length} threads'),
                      style: TextStyle(
                        fontSize: 11,
                        color: _officeTheme.chromeText,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _arabic ? 'إخفاء' : 'Hide',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _showComments = false),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                children: <Widget>[
                  if (roots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _arabic
                            ? 'حدّد فقرة أو جزءاً من النص ثم اضغط جديداً لإدراج تعليق.'
                            : 'Select a paragraph or range, then insert a comment.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _officeTheme.chromeText.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  for (final WmlComment root in roots) ...<Widget>[
                    _commentCard(root, root: root, dark: dark),
                    for (final WmlComment reply in WordComment.repliesOf(
                      _word.document,
                      root.id,
                    ))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 18),
                        child: _commentCard(reply, root: root, dark: dark),
                      ),
                    if (_word.selectedCommentId != null &&
                        WordComment.threadRootId(
                              _word.document,
                              _word.selectedCommentId!,
                            ) ==
                            root.id &&
                        _canMutate)
                      _commentReplyBox(root.id, dark),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commentReplyBox(int rootId, bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _commentReply,
              minLines: 1,
              maxLines: 3,
              style: TextStyle(fontSize: 12, color: _officeTheme.chromeText),
              decoration: InputDecoration(
                isDense: true,
                hintText: _arabic ? 'كتابة رد…' : 'Write a reply…',
                filled: true,
                fillColor: dark ? const Color(0xFF1E1E1E) : Colors.white,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _sendCommentReply(rootId),
            ),
          ),
          IconButton(
            tooltip: _arabic ? 'إرسال' : 'Send',
            onPressed: () => _sendCommentReply(rootId),
            icon: Icon(Icons.send, size: 16, color: _accent),
          ),
        ],
      ),
    );
  }

  Widget _commentCard(
    WmlComment comment, {
    required WmlComment root,
    required bool dark,
  }) {
    final bool selected = _word.selectedCommentId == comment.id;
    final bool dimmed = root.resolved;
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: selected
              ? _accent.withValues(alpha: dark ? 0.22 : 0.12)
              : (dark ? const Color(0xFF2A2A2A) : Colors.white),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: selected ? _accent : const Color(0x33000000),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                InkWell(
                  onTap: () => _word.jumpToComment(comment.id),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: _accent,
                        child: Text(
                          (comment.initials.isEmpty
                                  ? comment.author
                                  : comment.initials)
                              .substring(
                                0,
                                ((comment.initials.isEmpty
                                            ? comment.author
                                            : comment.initials)
                                        .length)
                                    .clamp(0, 2),
                              )
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              comment.author,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _officeTheme.chromeText,
                              ),
                            ),
                            if (_commentDateLabel(comment).isNotEmpty)
                              Text(
                                _commentDateLabel(comment),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _officeTheme.chromeText.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (root.resolved)
                        Text(
                          _arabic ? 'تم الحل' : 'Resolved',
                          style: TextStyle(
                            fontSize: 9,
                            color: _accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                if (selected && _canMutate)
                  _commentBodySurface(comment)
                else
                  Text.rich(
                    TextSpan(
                      children: _commentSpans(comment).isEmpty
                          ? <InlineSpan>[
                              TextSpan(
                                text: _arabic ? '(فارغ)' : '(empty)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: _officeTheme.chromeText.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ]
                          : _commentSpans(comment),
                    ),
                  ),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 0,
                      children: <Widget>[
                        IconButton(
                          tooltip: root.resolved
                              ? (_arabic ? 'إعادة فتح' : 'Reopen')
                              : (_arabic ? 'حل' : 'Resolve'),
                          visualDensity: VisualDensity.compact,
                          onPressed: _canMutate
                              ? () => _word.setCommentResolved(
                                  root.id,
                                  !root.resolved,
                                )
                              : null,
                          icon: Icon(
                            root.resolved ? Icons.replay : Icons.task_alt,
                            size: 16,
                          ),
                        ),
                        IconButton(
                          tooltip: _arabic ? 'حذف' : 'Delete',
                          visualDensity: VisualDensity.compact,
                          onPressed: _canMutate
                              ? () => _word.deleteComment(comment.id)
                              : null,
                          icon: const Icon(Icons.delete_outline, size: 16),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _commentBodySurface(WmlComment comment) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _word.setCommentSurfaceWidth(width);
          }
        });
        final LaidOutDocument? laid = _word.commentLaidOut;
        if (laid == null) {
          return const SizedBox(height: 56);
        }
        return SizedBox(
          height: _word.commentSurfaceHeight,
          child: WordCanvas(
            compact: true,
            document: _word.commentDocument,
            laidOut: laid,
            caret: _word.commentCaret,
            viewport: _commentViewport,
            hasFocus:
                _word.isEditingComment && _word.selectedCommentId == comment.id,
            config: _config.copyWith(showRulers: false),
            selectedCommentId: comment.id,
            onContextMenu: (OfficeContextHit hit) {
              OfficeContextMenu.dismiss(_commentContextMenu);
              _commentContextMenu = OfficeContextMenu.show(
                context: context,
                globalPosition: hit.globalPosition,
                actions: OfficeContextMenu.word(
                  hit: OfficeContextHit(
                    kind: OfficeContextKind.comment,
                    globalPosition: hit.globalPosition,
                    commentId: comment.id,
                  ),
                  controller: _word,
                ),
                onSelect: (String id) {
                  _commentContextMenu = null;
                  switch (id) {
                    case 'cut':
                      _word.cutToClipboard();
                    case 'copy':
                      _word.copyToClipboard();
                    case 'paste':
                      _word.pasteFromClipboard();
                    case 'selectAll':
                      _word.selectAll();
                    case 'replyComment':
                      _word.insertComment(parentId: comment.id);
                    case 'resolveComment':
                      _word.setCommentResolved(comment.id, true);
                    case 'reopenComment':
                      _word.setCommentResolved(comment.id, false);
                    case 'deleteComment':
                      _word.deleteComment(comment.id);
                  }
                },
              );
            },
            onChanged: () {
              if (!_word.isEditingComment ||
                  _word.selectedCommentId != comment.id) {
                _word.beginCommentEdit(comment.id);
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _insertWordLink({required _WordLinkKind kind}) async {
    if (!_canMutate) {
      return;
    }
    final List<WmlHeadingRef> headings = WordToc.headings(_word.document);
    final TextEditingController label = TextEditingController(
      text: !_word.documentCaret.isCollapsed
          ? _activeParagraph.text.substring(
              _word.documentCaret.normalizedRange.startIdx,
              _word.documentCaret.normalizedRange.endIdx,
            )
          : (kind == _WordLinkKind.bookmark && headings.isNotEmpty
                ? headings.first.text
                : kind == _WordLinkKind.file
                ? (_arabic ? 'ملف محلي' : 'Local file')
                : 'ECMA-376'),
    );
    final TextEditingController target = TextEditingController(
      text: switch (kind) {
        _WordLinkKind.web => 'https://www.ecma-international.org/',
        _WordLinkKind.file => '/etc/os-release',
        _WordLinkKind.bookmark =>
          headings.isEmpty
              ? ''
              : WordLink.headingBookmark(
                  headings.first.text,
                  headings.first.level,
                ),
      },
    );
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(switch (kind) {
            _WordLinkKind.web => _arabic ? 'رابط ويب' : 'Web link',
            _WordLinkKind.file => _arabic ? 'رابط ملف' : 'File link',
            _WordLinkKind.bookmark =>
              _arabic ? 'مرجع داخل المستند' : 'Document reference',
          }),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: label,
                  decoration: InputDecoration(
                    labelText: _arabic ? 'النص' : 'Text',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: target,
                  decoration: InputDecoration(
                    labelText: switch (kind) {
                      _WordLinkKind.web => _arabic ? 'العنوان' : 'URL',
                      _WordLinkKind.file => _arabic ? 'المسار' : 'Path',
                      _WordLinkKind.bookmark =>
                        _arabic ? 'إشارة مرجعية / عنوان' : 'Bookmark / heading',
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_arabic ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_arabic ? 'إدراج' : 'Insert'),
            ),
          ],
        );
      },
    );
    if (ok != true) {
      label.dispose();
      target.dispose();
      return;
    }
    final WmlHyperlink? link = switch (kind) {
      _WordLinkKind.web => WmlHyperlink(url: target.text.trim()),
      _WordLinkKind.file => WmlHyperlink(file: target.text.trim()),
      _WordLinkKind.bookmark => WmlHyperlink.fromTarget(target.text.trim()),
    };
    if (link != null) {
      _word.insertHyperlink(text: label.text.trim(), link: link);
    }
    label.dispose();
    target.dispose();
  }

  void _insertQuote() {
    _word.insertParagraphBreak();
    _word.insertText(
      _arabic
          ? 'اقتباس: حدد النص ثم طبّق تنسيق التحديد فقط.'
          : 'Quote: select a range, then apply formatting to that range only.',
    );
    final WmlParagraph para = _activeParagraph;
    para.properties.indent = const WmlIndent(left: 36);
    para.properties.justification = WmlJustification.left;
    for (final WmlInline inline in para.inlines) {
      if (inline is WmlRun) {
        inline.properties.italic = true;
        inline.properties.color = '595959';
      }
    }
    _word.relayout();
    _word.refresh();
  }

  void _insertPageBreak() {
    _word.insertParagraphBreak();
    _activeParagraph.properties.pageBreakBefore = true;
    _word.insertText(_arabic ? 'صفحة جديدة' : 'New page');
    _word.relayout();
    _word.refresh();
  }

  void _setLineSpacing(double value) {
    _word.applyParagraphFormat((WmlParagraphProps p) => p.lineSpacing = value);
  }

  void _nudgeParagraphSpacing({double before = 0, double after = 0}) {
    _word.applyParagraphFormat((WmlParagraphProps p) {
      p.spacingBefore = (p.spacingBefore + before).clamp(0, 72);
      p.spacingAfter = (p.spacingAfter + after).clamp(0, 72);
    });
  }

  void _toggleFirstLineIndent() {
    _word.applyParagraphFormat((WmlParagraphProps p) {
      final WmlIndent cur = p.indent;
      p.indent = WmlIndent(
        left: cur.left,
        right: cur.right,
        firstLine: cur.firstLine > 0 ? 0 : 36,
        hanging: 0,
      );
    });
  }

  void _toggleHangingIndent() {
    _word.applyParagraphFormat((WmlParagraphProps p) {
      final WmlIndent cur = p.indent;
      p.indent = WmlIndent(
        left: cur.left,
        right: cur.right,
        firstLine: 0,
        hanging: cur.hanging > 0 ? 0 : 36,
      );
    });
  }

  String _marginPresetId(WmlPageMargins margins) {
    if (margins.matches(WmlPageMargins.narrow)) {
      return 'narrow';
    }
    if (margins.matches(WmlPageMargins.moderate)) {
      return 'moderate';
    }
    if (margins.matches(WmlPageMargins.wide)) {
      return 'wide';
    }
    return 'normal';
  }

  String _marginPresetLabel(String id) => switch (id) {
    'narrow' => _arabic ? 'ضيق (0.5")' : 'Narrow (0.5")',
    'moderate' => _arabic ? 'متوسط (0.75")' : 'Moderate (0.75")',
    'wide' => _arabic ? 'واسع (2")' : 'Wide (2")',
    _ => _arabic ? 'عادي (1")' : 'Normal (1")',
  };

  void _applyMarginPreset(String id) {
    _word.setPageMargins(switch (id) {
      'narrow' => WmlPageMargins.narrow,
      'moderate' => WmlPageMargins.moderate,
      'wide' => WmlPageMargins.wide,
      _ => WmlPageMargins.normal,
    });
  }

  void _selectAllDocument() => _word.selectAll();

  void _insertBlockAfterActive(WmlBlock block) {
    for (final WmlSection section in _word.document.sections) {
      final int index = _topLevelIndexOf(section.blocks, _activeParagraph);
      if (index >= 0) {
        section.blocks.insert(index + 1, block);
        _word.relayout();
        if (block is WmlVisual) {
          _word.selectVisual(block);
        }
        if (block is WmlEquation) {
          _word.selectEquation(block);
        }
        _word.refresh();
        return;
      }
    }
    _word.document.sections.first.blocks.add(block);
    _word.relayout();
    if (block is WmlVisual) {
      _word.selectVisual(block);
    }
    if (block is WmlEquation) {
      _word.selectEquation(block);
    }
    _word.refresh();
  }

  int _topLevelIndexOf(List<WmlBlock> blocks, WmlParagraph para) {
    for (int i = 0; i < blocks.length; i++) {
      final WmlBlock current = blocks[i];
      if (identical(current, para)) {
        return i;
      }
      if (current is WmlToc && WordToc.ownsParagraph(current, para)) {
        return i;
      }
      if (current is WmlTable) {
        for (final WmlTableRow row in current.rows) {
          for (final WmlTableCell cell in row.cells) {
            if (_containsParagraph(cell.blocks, para)) {
              return i;
            }
          }
        }
      }
    }
    return -1;
  }

  bool _containsParagraph(List<WmlBlock> blocks, WmlParagraph para) {
    for (final WmlBlock block in blocks) {
      if (identical(block, para)) {
        return true;
      }
      if (block is WmlToc && WordToc.ownsParagraph(block, para)) {
        return true;
      }
      if (block is WmlTable) {
        for (final WmlTableRow row in block.rows) {
          for (final WmlTableCell cell in row.cells) {
            if (_containsParagraph(cell.blocks, para)) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  void _clearActiveCell() {
    _sheet.beginCellEdit(initial: '', replace: true);
    _sheet.commitCellEdit();
  }

  String _formulaArgs() {
    final SmlRange range = _sheet.selection.range;
    if (range.start.col != range.end.col || range.start.row != range.end.row) {
      return '${range.start.a1}:${range.end.a1}';
    }
    final SmlCellRef focus = _sheet.selection.focus;
    if (focus.col > 0) {
      return '${SmlCellRef(0, focus.row).a1}:${SmlCellRef(focus.col - 1, focus.row).a1}';
    }
    return '${SmlCellRef(1, focus.row).a1}:${SmlCellRef(4, focus.row).a1}';
  }

  void _insertFormula(String name) {
    final String formula = '=$name(${_formulaArgs()})';
    _sheet.beginCellEdit(initial: formula, replace: true);
    _sheet.commitCellEdit();
  }

  String _fnCategoryLabel(FormulaFnCategory category) {
    return switch (category) {
      FormulaFnCategory.math => _arabic ? 'رياضية' : 'Math',
      FormulaFnCategory.statistical => _arabic ? 'إحصاء' : 'Statistical',
      FormulaFnCategory.logical => _arabic ? 'منطقية' : 'Logical',
      FormulaFnCategory.text => _arabic ? 'نص' : 'Text',
      FormulaFnCategory.lookup => _arabic ? 'بحث' : 'Lookup',
      FormulaFnCategory.information => _arabic ? 'معلومات' : 'Information',
      FormulaFnCategory.date => _arabic ? 'تاريخ' : 'Date',
      FormulaFnCategory.financial => _arabic ? 'مالية' : 'Financial',
    };
  }

  Future<void> _openFunctionGuide() async {
    FormulaFnCategory? filter;
    String query = '';
    FormulaFnDoc selected = FormulaFunctionGuide.all.first;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialog) {
            final List<FormulaFnDoc> rows = <FormulaFnDoc>[
              for (final FormulaFnDoc doc in FormulaFunctionGuide.all)
                if ((filter == null || doc.category == filter) &&
                    (query.isEmpty ||
                        doc.name.contains(query.toUpperCase()) ||
                        doc.aliases.any(
                          (String a) => a.contains(query.toUpperCase()),
                        ) ||
                        doc.summary(_arabic).contains(query)))
                  doc,
            ];
            if (rows.isNotEmpty && !rows.contains(selected)) {
              selected = rows.first;
            }
            return AlertDialog(
              title: Text(
                _arabic ? 'دليل دوال الإكسل' : 'Excel function guide',
              ),
              content: SizedBox(
                width: 720,
                height: 440,
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 280,
                      child: Column(
                        children: <Widget>[
                          TextField(
                            decoration: InputDecoration(
                              hintText: _arabic ? 'بحث' : 'Search',
                              isDense: true,
                            ),
                            onChanged: (String value) {
                              setDialog(() => query = value);
                            },
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: <Widget>[
                              ChoiceChip(
                                label: Text(_arabic ? 'الكل' : 'All'),
                                selected: filter == null,
                                onSelected: (_) =>
                                    setDialog(() => filter = null),
                              ),
                              for (final FormulaFnCategory category
                                  in FormulaFnCategory.values)
                                ChoiceChip(
                                  label: Text(_fnCategoryLabel(category)),
                                  selected: filter == category,
                                  onSelected: (_) =>
                                      setDialog(() => filter = category),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: rows.length,
                              itemBuilder: (BuildContext context, int i) {
                                final FormulaFnDoc doc = rows[i];
                                return ListTile(
                                  dense: true,
                                  selected: identical(doc, selected),
                                  title: Text(doc.name),
                                  subtitle: Text(
                                    _fnCategoryLabel(doc.category),
                                    maxLines: 1,
                                  ),
                                  onTap: () => setDialog(() => selected = doc),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 16),
                    Expanded(
                      child: ListView(
                        children: <Widget>[
                          Text(
                            selected.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selected.syntax,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                          const SizedBox(height: 12),
                          Text(selected.summary(_arabic)),
                          if (selected.example.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(_arabic ? 'مثال' : 'Example'),
                            Text(selected.example),
                          ],
                          if (selected.aliases.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              '${_arabic ? 'أسماء بديلة' : 'Aliases'}: '
                              '${selected.aliases.join(', ')}',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_arabic ? 'إغلاق' : 'Close'),
                ),
                if (_canMutate)
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _sheet.beginCellEdit(
                        initial: '=${selected.name}(',
                        replace: true,
                      );
                    },
                    child: Text(_arabic ? 'إدراج' : 'Insert'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _insertIfFormula() {
    final SmlCellRef focus = _sheet.selection.focus;
    final String probe = focus.col > 0
        ? SmlCellRef(focus.col - 1, focus.row).a1
        : SmlCellRef(focus.col + 1, focus.row).a1;
    final String yes = _arabic ? 'نعم' : 'Yes';
    final String no = _arabic ? 'لا' : 'No';
    _sheet.beginCellEdit(initial: '=IF($probe>0,"$yes","$no")', replace: true);
    _sheet.commitCellEdit();
  }

  void _newWord() {
    _wordPath = null;
    _wordName = 'Document1.docx';
    _word.document = WmlDocument.empty(
      text: _arabic ? 'مستند جديد' : 'New document',
      rtl: _arabic,
    );
    _word.documentCaret.paragraphIndex = 0;
    _word.documentCaret.logicalIndex = 0;
    _word.documentCaret.collapseSelection();
    _word.relayout();
    _word.refresh();
  }

  void _newSheet() {
    _sheetPath = null;
    _sheetName = 'Book1.xlsx';
    _sheet.workbook = SmlWorkbook();
    _sheet.setActiveSheet(0);
  }

  void _newSlides() {
    _slidePath = null;
    _slideName = 'Presentation1.pptx';
    _slides.presentation = PmlPresentation();
    _slides.setActiveSlide(0);
  }

  void _resetWord() {
    _wordPath = null;
    _wordName = 'Al Tahreer Neighbourhood Profile.docx';
    _word.document = SampleLibrary.wordBriefing();
    _word.documentCaret.paragraphIndex = 0;
    _word.documentCaret.logicalIndex = 0;
    _word.documentCaret.collapseSelection();
    _word.relayout();
    _word.refresh();
  }

  void _resetSheet() {
    _sheetPath = null;
    _sheetName = 'Budget.xlsx';
    _sheet.workbook = SampleLibrary.excelBudget();
    _sheet.setActiveSheet(0);
  }

  void _resetSlides() {
    _slidePath = null;
    _slideName = 'Studio deck.pptx';
    _slides.presentation = SampleLibrary.slideDeck();
    _slides.setActiveSlide(0);
  }

  int _nextSlideId() {
    var maxId = 255;
    for (final PmlSlide slide in _slides.presentation.slides) {
      if (slide.id > maxId) {
        maxId = slide.id;
      }
    }
    return maxId + 1;
  }

  int _nextShapeId(PmlSlide slide) {
    var maxId = 1;
    for (final PmlShape shape in slide.shapes) {
      if (shape.id > maxId) {
        maxId = shape.id;
      }
    }
    return maxId + 1;
  }

  void _addSlide() {
    _slides.presentation.slides.add(
      PmlSlide(
        id: _nextSlideId(),
        shapes: <PmlShape>[
          PmlShape(
            id: 2,
            name: 'Title',
            text: _arabic ? 'شريحة جديدة' : 'New slide',
            fillColor: '2B579A',
            transform: const PmlTransform(
              x: 800000,
              y: 1800000,
              cx: 7500000,
              cy: 1200000,
            ),
          ),
        ],
      ),
    );
    _slides.setActiveSlide(_slides.presentation.slides.length - 1);
  }

  void _duplicateSlide() {
    final PmlSlide src = _slides.slide;
    _slides.presentation.slides.add(
      PmlSlide(
        id: _nextSlideId(),
        layoutName: src.layoutName,
        notes: src.notes,
        transition: src.transition,
        animations: <PmlShapeAnimation>[
          for (final PmlShapeAnimation anim in src.animations) anim.copyWith(),
        ],
        shapes: <PmlShape>[
          for (final PmlShape shape in src.shapes)
            PmlShape(
              id: shape.id,
              name: shape.name,
              text: shape.text,
              fillColor: shape.fillColor,
              textColor: shape.textColor,
              fontSizePt: shape.fontSizePt,
              preset: shape.preset,
              transform: shape.transform,
              visual: shape.visual?.copy(),
              table: shape.table?.copy(),
              rightToLeft: shape.rightToLeft,
              textAlign: shape.textAlign,
            ),
        ],
      ),
    );
    _slides.setActiveSlide(_slides.presentation.slides.length - 1);
  }

  void _deleteSlide() {
    if (_slides.presentation.slides.length <= 1) {
      return;
    }
    final int index = _slides.activeSlideIndex;
    _slides.presentation.slides.removeAt(index);
    _slides.setActiveSlide(index - 1);
  }

  void _addCardShape() {
    final PmlSlide slide = _slides.slide;
    final PmlShape shape = PmlShape(
      id: _nextShapeId(slide),
      name: 'Card',
      text: _arabic ? 'بطاقة جديدة' : 'New card',
      fillColor: '217346',
      transform: const PmlTransform(
        x: 1400000,
        y: 1600000,
        cx: 6200000,
        cy: 1600000,
      ),
    );
    slide.shapes.add(shape);
    _slides.selectShape(shape);
  }

  void _addTitleShape() {
    final PmlSlide slide = _slides.slide;
    final PmlShape shape = PmlShape(
      id: _nextShapeId(slide),
      name: 'Title',
      text: _arabic ? 'عنوان الشريحة' : 'Slide title',
      fillColor: 'B7472A',
      transform: const PmlTransform(
        x: 600000,
        y: 400000,
        cx: 8000000,
        cy: 900000,
      ),
    );
    slide.shapes.add(shape);
    _slides.selectShape(shape);
  }

  void _addAccentShape() {
    final PmlSlide slide = _slides.slide;
    final PmlShape shape = PmlShape(
      id: _nextShapeId(slide),
      name: 'Accent',
      text: _arabic ? 'شكل تمييز' : 'Accent shape',
      fillColor: '7030A0',
      transform: const PmlTransform(
        x: 2800000,
        y: 2000000,
        cx: 3600000,
        cy: 1400000,
      ),
    );
    slide.shapes.add(shape);
    _slides.selectShape(shape);
  }

  static const List<String> _shapeFills = <String>[
    '2B579A',
    '217346',
    'B7472A',
    'ED7D31',
    '5B9BD5',
    '7030A0',
    'C45911',
    '548235',
  ];

  void _cycleShapeFill() {
    final PmlShape? shape = _slides.selected;
    if (shape == null) {
      return;
    }
    final int i = _shapeFills.indexOf(shape.fillColor.toUpperCase());
    final String next = _shapeFills[(i + 1) % _shapeFills.length];
    _slides.updateSelected(fillColor: next);
  }

  void _centerSelectedShape() {
    _alignSelectedShape(x: 0.5, y: 0.5);
  }

  void _alignSelectedShape({double? x, double? y}) {
    final PmlShape? shape = _slides.selected;
    if (shape == null) {
      return;
    }
    final PmlTransform t = shape.transform;
    final int nextX = x == null
        ? t.x
        : ((_slides.presentation.slideWidth - t.cx) * x).round();
    final int nextY = y == null
        ? t.y
        : ((_slides.presentation.slideHeight - t.cy) * y).round();
    _slides.applyTransform(
      shape,
      PmlTransform(x: nextX, y: nextY, cx: t.cx, cy: t.cy, rot: t.rot),
    );
    _slides.refresh();
  }

  void _jumpWordPage(int index) {
    final int last = _word.pageCount < 1 ? 0 : _word.pageCount - 1;
    final int page = index.clamp(0, last);
    final double scale = _word.viewport.scale * (96 / 72);
    _word.viewport.origin = Offset(
      _word.viewport.origin.dx,
      _word.documentLaidOut.pageStackTop(page, scale),
    );
    _word.refresh();
  }

  Widget _body(bool dark) {
    return ColoredBox(
      color: dark ? const Color(0xFF121212) : const Color(0xFFD0D0D0),
      child: Row(
        children: <Widget>[
          if (!(_app == SuiteApp.powerpoint && _slides.isPresenting))
            _sidePane(dark),
          Expanded(child: _stage(dark)),
          if (_app == SuiteApp.word && _showComments) _wordCommentsPane(dark),
          if (_selectedOfficeVisual != null &&
              !(_app == SuiteApp.powerpoint && _slides.isPresenting))
            _visualPane(dark),
          if (_app == SuiteApp.powerpoint &&
              _showAnimPane &&
              !_slides.isPresenting)
            _animationPane(dark),
        ],
      ),
    );
  }

  Widget _stage(bool dark) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x33000000), blurRadius: 8),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            switch (_app) {
              SuiteApp.word => Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  QudsWordEditor(
                    controller: _word,
                    focusNode: _wordFocus,
                    config: _printPreview
                        ? _config.copyWith(mode: OfficeInteractionMode.viewing)
                        : _config,
                  ),
                  if (_printPreview) _wordPrintPreviewBanner(),
                ],
              ),
              SuiteApp.excel => Column(
                children: <Widget>[
                  _excelFormulaBar(dark),
                  Expanded(
                    child: QudsSheetEditor(
                      controller: _sheet,
                      focusNode: _sheetFocus,
                      config: _config,
                    ),
                  ),
                  _excelSheetTabs(dark),
                ],
              ),
              SuiteApp.powerpoint => Column(
                children: <Widget>[
                  Expanded(
                    child: QudsSlideEditor(
                      controller: _slides,
                      focusNode: _slideFocus,
                      config: _config,
                    ),
                  ),
                  if (_showNotes && !_slides.isPresenting) _slideNotes(dark),
                ],
              ),
              SuiteApp.pdf => StudioPdfSurface(
                controller: _pdf,
                config: _config,
                options: _pdfViewerOptions,
                events: _pdfEvents,
                onFollowLink: (PdfLinkAction action) {
                  final String target = action.uri ??
                      (action.pageIndex != null
                          ? '${_arabic ? 'صفحة' : 'page'} ${action.pageIndex! + 1}'
                          : '?');
                  if (_pdfPreventLinks && action.uri != null) {
                    _toast(
                      _arabic
                          ? 'رابط بدون فتح: $target'
                          : 'Link blocked: $target',
                    );
                  }
                },
              ),
            },
            if (_findOpen && _app == SuiteApp.pdf)
              Positioned(top: 8, left: 8, right: 8, child: _pdfFindBar(dark)),
            if (_findOpen && _app != SuiteApp.pdf)
              Positioned(
                top: 0,
                bottom: 0,
                left: _arabic ? 0 : null,
                right: _arabic ? null : 0,
                child: StudioFindPane(
                  controller: _active,
                  arabic: _arabic,
                  accent: _accent,
                  replaceMode: _findReplace,
                  onReplaceMode: (bool value) {
                    setState(() => _findReplace = value);
                  },
                  onClose: _closeFind,
                ),
              ),
            if (_opening) _openProgressOverlay(dark),
          ],
        ),
      ),
    );
  }

  Widget _wordPrintPreviewBanner() {
    final List<LaidOutPage> pages = _word.printPreviewPages();
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: const Color(0xEE2B579A),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _arabic
                    ? 'معاينة طباعة · ${pages.length} صفحة'
                    : 'Print preview · ${pages.length} pages',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              IconButton(
                onPressed: () => _jumpWordPage(_word.visiblePageIndex - 1),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
              IconButton(
                onPressed: () => _jumpWordPage(_word.visiblePageIndex + 1),
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
              IconButton(
                onPressed: () => setState(() => _printPreview = false),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _openProgressOverlay(bool dark) {
    final int percent = (_openProgress * 100).round().clamp(0, 100);
    final Color card = dark ? const Color(0xFF1E1E22) : Colors.white;
    final Color track = dark
        ? const Color(0xFF3A3A42)
        : const Color(0xFFE8E8EE);
    return ColoredBox(
      color: const Color(0xB3000000),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: card,
            elevation: 16,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[_accent, _accent.withValues(alpha: 0.55)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.picture_as_pdf_rounded,
                          color: _accent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _arabic ? 'جاري تجهيز المستند' : 'Preparing document',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: _officeTheme.chromeText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _openStatusLabel,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: _officeTheme.chromeText.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _openProgress.clamp(0.04, 1),
                          minHeight: 8,
                          backgroundColor: track,
                          color: _accent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _excelFormulaBar(bool dark) {
    return Material(
      color: dark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F7F7),
      child: SizedBox(
        height: 32,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 72,
              child: Center(
                child: Text(
                  _sheet.selectionAddress,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _officeTheme.chromeText,
                  ),
                ),
              ),
            ),
            VerticalDivider(
              width: 1,
              color: dark ? const Color(0xFF444444) : const Color(0xFFD0D0D0),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'fx',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: _accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: _canMutate ? _sheet.beginCellEdit : null,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text.rich(
                    _sheet.cellEditor.editing
                        ? FormulaRefStyle.textSpan(
                            _sheet.formulaBarText,
                            baseColor: _officeTheme.chromeText,
                            fontSize: 14,
                          )
                        : TextSpan(
                            text: _sheet.formulaBarText,
                            style: TextStyle(color: _officeTheme.chromeText),
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            if (_sheet.cellEditor.editing)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _sheet.commitCellEdit,
                icon: Icon(Icons.check, size: 16, color: _accent),
              ),
          ],
        ),
      ),
    );
  }

  Widget _excelSheetTabs(bool dark) {
    return Material(
      color: dark ? const Color(0xFF252525) : const Color(0xFFEEEEEE),
      child: SizedBox(
        height: 28,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: <Widget>[
            for (int i = 0; i < _sheet.workbook.sheets.length; i++)
              InkWell(
                onTap: () => _sheet.setActiveSheet(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == _sheet.activeSheetIndex
                        ? (dark ? const Color(0xFF1E1E1E) : Colors.white)
                        : Colors.transparent,
                    border: Border(
                      top: BorderSide(
                        color: i == _sheet.activeSheetIndex
                            ? _accent
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _sheet.workbook.sheets[i].name,
                    style: TextStyle(
                      fontSize: 12,
                      color: i == _sheet.activeSheetIndex
                          ? _accent
                          : _officeTheme.chromeText,
                      fontWeight: i == _sheet.activeSheetIndex
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            InkWell(
              onTap: _canMutate ? _addSheet : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.add, size: 16, color: _accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addSheet() {
    _sheet.workbook.sheets.add(
      SmlWorksheet(
        name: 'Sheet${_sheet.workbook.sheets.length + 1}',
        sheetId: _sheet.workbook.sheets.length + 1,
      ),
    );
    _sheet.setActiveSheet(_sheet.workbook.sheets.length - 1);
  }

  void _deleteSheet() {
    if (_sheet.workbook.sheets.length <= 1) {
      return;
    }
    final int index = _sheet.activeSheetIndex;
    _sheet.workbook.sheets.removeAt(index);
    _sheet.setActiveSheet(index - 1);
  }

  OfficeVisual? get _selectedOfficeVisual {
    return switch (_app) {
      SuiteApp.word => _word.selectedVisual?.visual,
      SuiteApp.excel => _sheet.selectedDrawing?.visual,
      SuiteApp.powerpoint => _slides.selected?.visual,
      SuiteApp.pdf => null,
    };
  }

  void _mutateVisual(void Function(OfficeVisual visual) edit) {
    switch (_app) {
      case SuiteApp.word:
        _word.mutateSelectedVisual(edit);
      case SuiteApp.excel:
        _sheet.mutateSelectedDrawing(edit);
      case SuiteApp.powerpoint:
        _slides.mutateSelectedShapeVisual(edit);
      case SuiteApp.pdf:
        break;
    }
  }

  void _deleteSelectedVisual() {
    switch (_app) {
      case SuiteApp.word:
        _word.deleteSelectedVisual();
      case SuiteApp.excel:
        _sheet.deleteSelectedDrawing();
      case SuiteApp.powerpoint:
        _slides.deleteSelectedShape();
      case SuiteApp.pdf:
        break;
    }
  }

  List<StudioRibbonGroup> _visualRibbon() {
    final OfficeVisual? visual = _selectedOfficeVisual;
    if (visual == null) {
      return const <StudioRibbonGroup>[];
    }
    if (visual.isPicture) {
      return <StudioRibbonGroup>[
        StudioRibbonGroup(
          title: _arabic ? 'تنسيق الصورة' : 'Picture format',
          children: <Widget>[
            _cmd(
              Icons.photo_library_outlined,
              _arabic ? 'استبدال' : 'Replace',
              _canMutate ? _replaceSelectedPicture : null,
            ),
            _cmd(
              Icons.crop,
              _arabic ? 'قص' : 'Crop',
              _canMutate ? _toggleWordPictureCrop : null,
              selected: _app == SuiteApp.word && _word.pictureCropMode,
            ),
            _cmd(
              Icons.crop_free,
              _arabic ? 'إلغاء القص' : 'Clear crop',
              _canMutate
                  ? () => _mutateVisual((OfficeVisual v) {
                      v.picture
                        ..cropLeft = 0
                        ..cropTop = 0
                        ..cropRight = 0
                        ..cropBottom = 0;
                    })
                  : null,
            ),
            _cmd(
              Icons.rotate_right,
              _arabic ? 'دوران' : 'Rotate',
              _canMutate
                  ? () => _mutateVisual((OfficeVisual v) => v.rotateBy(90))
                  : null,
            ),
            _cmd(
              Icons.wb_sunny_outlined,
              _arabic ? 'إضاءة' : 'Bright',
              _canMutate
                  ? () =>
                        _mutateVisual((OfficeVisual v) => v.bumpBrightness(0.1))
                  : null,
            ),
            _cmd(
              Icons.contrast,
              _arabic ? 'تباين' : 'Contrast',
              _canMutate
                  ? () =>
                        _mutateVisual((OfficeVisual v) => v.bumpContrast(0.15))
                  : null,
            ),
            _cmd(
              Icons.border_style,
              _arabic ? 'إطار' : 'Border',
              _canMutate
                  ? () => _mutateVisual((OfficeVisual v) => v.cycleBorder())
                  : null,
            ),
            _cmd(
              Icons.opacity,
              _arabic ? 'شفافية' : 'Opacity',
              _canMutate
                  ? () => _mutateVisual(
                      (OfficeVisual v) => v.bumpTransparency(0.1),
                    )
                  : null,
            ),
            _cmd(
              Icons.flip,
              _arabic ? 'قلب أفقي' : 'Flip H',
              _canMutate
                  ? () => _mutateVisual((OfficeVisual v) => v.toggleFlipH())
                  : null,
              selected: visual.picture.flipH,
            ),
            _cmd(
              Icons.flip_camera_android,
              _arabic ? 'قلب عمودي' : 'Flip V',
              _canMutate
                  ? () => _mutateVisual((OfficeVisual v) => v.toggleFlipV())
                  : null,
              selected: visual.picture.flipV,
            ),
            _cmd(
              Icons.wrap_text,
              _arabic ? 'التفاف' : 'Wrap',
              _canMutate
                  ? () => _mutateVisual((OfficeVisual v) => v.cycleWrap())
                  : null,
            ),
            _cmd(
              Icons.aspect_ratio,
              _arabic ? 'نسبة' : 'Lock',
              _canMutate
                  ? () => _mutateVisual(
                      (OfficeVisual v) =>
                          v.picture.lockAspect = !v.picture.lockAspect,
                    )
                  : null,
              selected: visual.picture.lockAspect,
            ),
            _cmd(
              Icons.blur_on,
              _arabic ? 'ظل' : 'Shadow',
              _canMutate
                  ? () => _mutateVisual(
                      (OfficeVisual v) => v.picture.shadow = !v.picture.shadow,
                    )
                  : null,
              selected: visual.picture.shadow,
            ),
            _cmd(
              Icons.restart_alt,
              _arabic ? 'إعادة' : 'Reset',
              _canMutate
                  ? () => _mutateVisual((OfficeVisual v) => v.resetPicture())
                  : null,
            ),
            _cmd(
              Icons.delete_outline,
              _arabic ? 'حذف' : 'Delete',
              _canMutate ? _deleteSelectedVisual : null,
            ),
          ],
        ),
      ];
    }
    return <StudioRibbonGroup>[
      StudioRibbonGroup(
        title: _arabic ? 'تصميم المخطط' : 'Chart design',
        children: <Widget>[
          _cmd(
            Icons.bar_chart,
            _arabic ? 'أعمدة' : 'Column',
            _canMutate
                ? () => _mutateVisual(
                    (OfficeVisual v) => v.kind = OfficeVisualKind.chartColumn,
                  )
                : null,
            selected: visual.kind == OfficeVisualKind.chartColumn,
          ),
          _cmd(
            Icons.stacked_bar_chart,
            _arabic ? 'شريطي' : 'Bar',
            _canMutate
                ? () => _mutateVisual(
                    (OfficeVisual v) => v.kind = OfficeVisualKind.chartBar,
                  )
                : null,
            selected: visual.kind == OfficeVisualKind.chartBar,
          ),
          _cmd(
            Icons.pie_chart,
            _arabic ? 'دائري' : 'Pie',
            _canMutate
                ? () => _mutateVisual(
                    (OfficeVisual v) => v.kind = OfficeVisualKind.chartPie,
                  )
                : null,
            selected: visual.kind == OfficeVisualKind.chartPie,
          ),
          _cmd(
            Icons.show_chart,
            _arabic ? 'خطي' : 'Line',
            _canMutate
                ? () => _mutateVisual(
                    (OfficeVisual v) => v.kind = OfficeVisualKind.chartLine,
                  )
                : null,
            selected: visual.kind == OfficeVisualKind.chartLine,
          ),
          _cmd(
            Icons.title,
            _arabic ? 'عنوان' : 'Title',
            _canMutate
                ? () => _mutateVisual(
                    (OfficeVisual v) => v.cycleTitle(arabic: _arabic),
                  )
                : null,
          ),
          _cmd(
            Icons.add,
            _arabic ? 'نقطة' : 'Point',
            _canMutate
                ? () => _mutateVisual(
                    (OfficeVisual v) => v.addSamplePoint(arabic: _arabic),
                  )
                : null,
          ),
          _cmd(
            Icons.remove,
            _arabic ? 'حذف نقطة' : 'Remove',
            _canMutate && visual.points.length > 1
                ? () => _mutateVisual((OfficeVisual v) => v.removeLastPoint())
                : null,
          ),
          _cmd(
            Icons.legend_toggle,
            _arabic ? 'وسيلة إيضاح' : 'Legend',
            _canMutate
                ? () => _mutateVisual(
                    (OfficeVisual v) =>
                        v.chart.showLegend = !v.chart.showLegend,
                  )
                : null,
            selected: visual.chart.showLegend,
          ),
          _cmd(
            Icons.label_outline,
            _arabic ? 'تسميات' : 'Labels',
            _canMutate
                ? () => _mutateVisual(
                    (OfficeVisual v) =>
                        v.chart.showDataLabels = !v.chart.showDataLabels,
                  )
                : null,
            selected: visual.chart.showDataLabels,
          ),
          _cmd(
            Icons.grid_4x4,
            _arabic ? 'محاور' : 'Axes',
            _canMutate
                ? () => _mutateVisual(
                    (OfficeVisual v) => v.chart.showAxes = !v.chart.showAxes,
                  )
                : null,
            selected: visual.chart.showAxes,
          ),
          _cmd(
            Icons.grid_on,
            _arabic ? 'خطوط شبكة' : 'Grid',
            _canMutate
                ? () => _mutateVisual(
                    (OfficeVisual v) =>
                        v.chart.showGridlines = !v.chart.showGridlines,
                  )
                : null,
            selected: visual.chart.showGridlines,
          ),
          _cmd(
            Icons.place,
            _arabic ? 'موضع الإيضاح' : 'Legend pos',
            _canMutate
                ? () => _mutateVisual((OfficeVisual v) => v.cycleLegendPos())
                : null,
          ),
          _cmd(
            Icons.title,
            _arabic ? 'إظهار العنوان' : 'Show title',
            _canMutate
                ? () => _mutateVisual(
                    (OfficeVisual v) => v.chart.showTitle = !v.chart.showTitle,
                  )
                : null,
            selected: visual.chart.showTitle,
          ),
          _cmd(
            Icons.percent,
            _arabic ? 'نسب' : 'Percent',
            _canMutate
                ? () => _mutateVisual(
                    (OfficeVisual v) =>
                        v.chart.showPercent = !v.chart.showPercent,
                  )
                : null,
            selected: visual.chart.showPercent,
          ),
          _cmd(
            Icons.delete_outline,
            _arabic ? 'حذف' : 'Delete',
            _canMutate ? _deleteSelectedVisual : null,
          ),
        ],
      ),
    ];
  }

  void _toggleWordPictureCrop() {
    if (_app == SuiteApp.word) {
      _word.togglePictureCropMode();
      return;
    }
    _mutateVisual((OfficeVisual v) => v.cropBy(0.06));
  }

  Future<void> _replaceSelectedPicture() async {
    final Uint8List? bytes = await StudioFiles.pickImage();
    if (bytes == null) {
      return;
    }
    _mutateVisual((OfficeVisual v) {
      v
        ..kind = OfficeVisualKind.picture
        ..imageBytes = bytes
        ..resetPicture();
    });
  }

  Widget _visualPane(bool dark) {
    final OfficeVisual? visual = _selectedOfficeVisual;
    if (visual == null) {
      return const SizedBox.shrink();
    }
    return Material(
      color: dark ? const Color(0xFF242424) : const Color(0xFFF3F3F3),
      child: SizedBox(
        width: 260,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 12),
          children: <Widget>[
            StudioPaneTitle(
              text: visual.isPicture
                  ? (_arabic ? 'تنسيق الصورة' : 'Picture format')
                  : (_arabic ? 'تحرير المخطط' : 'Chart editor'),
              accent: _accent,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                visual.title.isEmpty ? _visualTitle(visual.kind) : visual.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _officeTheme.chromeText,
                ),
              ),
            ),
            if (visual.isPicture) ...<Widget>[
              _visualSlider(
                _arabic ? 'دوران' : 'Rotation',
                visual.picture.rotationDeg,
                0,
                359,
                '${visual.picture.rotationDeg.round()}°',
                (double v) => _mutateVisual(
                  (OfficeVisual vis) => vis.picture.rotationDeg = v,
                ),
              ),
              _visualSlider(
                _arabic ? 'إضاءة' : 'Brightness',
                visual.picture.brightness,
                -0.5,
                0.5,
                visual.picture.brightness.toStringAsFixed(2),
                (double v) => _mutateVisual(
                  (OfficeVisual vis) => vis.picture.brightness = v,
                ),
              ),
              _visualSlider(
                _arabic ? 'تباين' : 'Contrast',
                visual.picture.contrast,
                0.5,
                1.8,
                visual.picture.contrast.toStringAsFixed(2),
                (double v) => _mutateVisual(
                  (OfficeVisual vis) => vis.picture.contrast = v,
                ),
              ),
              _visualSlider(
                _arabic ? 'شفافية' : 'Transparency',
                visual.picture.transparency,
                0,
                0.85,
                '${(visual.picture.transparency * 100).round()}%',
                (double v) => _mutateVisual(
                  (OfficeVisual vis) => vis.picture.transparency = v,
                ),
              ),
              _visualSlider(
                _arabic ? 'قص' : 'Crop',
                visual.picture.cropLeft,
                0,
                0.4,
                '${(visual.picture.cropLeft * 100).round()}%',
                (double v) => _mutateVisual((OfficeVisual vis) {
                  vis.picture
                    ..cropLeft = v
                    ..cropTop = v
                    ..cropRight = v
                    ..cropBottom = v;
                }),
              ),
              _visualSlider(
                _arabic ? 'عرض الإطار' : 'Border width',
                visual.picture.borderWidth,
                0,
                12,
                visual.picture.borderWidth.toStringAsFixed(1),
                (double v) => _mutateVisual((OfficeVisual vis) {
                  vis.picture.borderWidth = v;
                  if (v > 0 && vis.picture.borderColor.isEmpty) {
                    vis.picture.borderColor = '2B579A';
                  }
                }),
              ),
              _visualFact(
                _arabic ? 'التفاف النص' : 'Text wrap',
                _wrapLabel(visual.picture.wrap),
              ),
              _visualFact(
                _arabic ? 'نص بديل' : 'Alt text',
                visual.picture.altDescription.isEmpty
                    ? visual.title
                    : visual.picture.altDescription,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Wrap(
                  spacing: 4,
                  children: <Widget>[
                    for (final PictureWrap wrap in PictureWrap.values)
                      ChoiceChip(
                        label: Text(
                          _wrapLabel(wrap),
                          style: const TextStyle(fontSize: 10),
                        ),
                        selected: visual.picture.wrap == wrap,
                        onSelected: _canMutate
                            ? (_) => _mutateVisual(
                                (OfficeVisual v) => v.picture.wrap = wrap,
                              )
                            : null,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ] else ...<Widget>[
              SwitchListTile(
                dense: true,
                title: Text(
                  _arabic ? 'وسيلة إيضاح' : 'Legend',
                  style: TextStyle(
                    fontSize: 12,
                    color: _officeTheme.chromeText,
                  ),
                ),
                value: visual.chart.showLegend,
                onChanged: _canMutate
                    ? (bool v) => _mutateVisual(
                        (OfficeVisual vis) => vis.chart.showLegend = v,
                      )
                    : null,
              ),
              SwitchListTile(
                dense: true,
                title: Text(
                  _arabic ? 'تسميات البيانات' : 'Data labels',
                  style: TextStyle(
                    fontSize: 12,
                    color: _officeTheme.chromeText,
                  ),
                ),
                value: visual.chart.showDataLabels,
                onChanged: _canMutate
                    ? (bool v) => _mutateVisual(
                        (OfficeVisual vis) => vis.chart.showDataLabels = v,
                      )
                    : null,
              ),
              SwitchListTile(
                dense: true,
                title: Text(
                  _arabic ? 'محاور' : 'Axes',
                  style: TextStyle(
                    fontSize: 12,
                    color: _officeTheme.chromeText,
                  ),
                ),
                value: visual.chart.showAxes,
                onChanged: _canMutate
                    ? (bool v) => _mutateVisual(
                        (OfficeVisual vis) => vis.chart.showAxes = v,
                      )
                    : null,
              ),
              SwitchListTile(
                dense: true,
                title: Text(
                  _arabic ? 'خطوط الشبكة' : 'Gridlines',
                  style: TextStyle(
                    fontSize: 12,
                    color: _officeTheme.chromeText,
                  ),
                ),
                value: visual.chart.showGridlines,
                onChanged: _canMutate
                    ? (bool v) => _mutateVisual(
                        (OfficeVisual vis) => vis.chart.showGridlines = v,
                      )
                    : null,
              ),
              _visualFact(
                _arabic ? 'موضع الإيضاح' : 'Legend position',
                visual.chart.legendPos.name,
              ),
              _visualSlider(
                _arabic ? 'فجوة الأعمدة' : 'Gap width',
                visual.chart.gapWidth.toDouble(),
                0,
                400,
                '${visual.chart.gapWidth}',
                (double v) => _mutateVisual(
                  (OfficeVisual vis) => vis.chart.gapWidth = v.round(),
                ),
              ),
              for (int i = 0; i < visual.points.length; i++)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 8,
                    backgroundColor: Color(
                      0xFF000000 |
                          (int.tryParse(visual.points[i].color, radix: 16) ??
                              0x4472C4),
                    ),
                  ),
                  title: Text(
                    '${visual.points[i].label}  ${visual.points[i].value.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _officeTheme.chromeText,
                    ),
                  ),
                  onTap: _canMutate
                      ? () => _mutateVisual(
                          (OfficeVisual v) => v.cyclePointColor(i),
                        )
                      : null,
                  trailing: SizedBox(
                    width: 72,
                    child: Row(
                      children: <Widget>[
                        InkWell(
                          onTap: _canMutate
                              ? () => _mutateVisual(
                                  (OfficeVisual v) => v.bumpPointValue(i, -5),
                                )
                              : null,
                          child: const Icon(Icons.remove, size: 16),
                        ),
                        InkWell(
                          onTap: _canMutate
                              ? () => _mutateVisual(
                                  (OfficeVisual v) => v.bumpPointValue(i, 5),
                                )
                              : null,
                          child: const Icon(Icons.add, size: 16),
                        ),
                        InkWell(
                          onTap: _canMutate
                              ? () => _mutateVisual(
                                  (OfficeVisual v) =>
                                      v.cyclePointLabel(i, arabic: _arabic),
                                )
                              : null,
                          child: const Icon(Icons.text_fields, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _visualFact(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: TextStyle(fontSize: 11, color: _officeTheme.chromeText),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _accent,
        ),
      ),
    );
  }

  Widget _visualSlider(
    String label,
    double value,
    double min,
    double max,
    String display,
    void Function(double value) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: _officeTheme.chromeText,
                  ),
                ),
              ),
              Text(
                display,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _accent,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: _accent,
              thumbColor: _accent,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: _canMutate ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }

  String _wrapLabel(PictureWrap wrap) {
    if (_arabic) {
      return switch (wrap) {
        PictureWrap.inline => 'ضمن السطر',
        PictureWrap.square => 'مربع',
        PictureWrap.tight => 'ضيق',
        PictureWrap.through => 'خلال',
        PictureWrap.topAndBottom => 'أعلى وأسفل',
        PictureWrap.behind => 'خلف النص',
        PictureWrap.inFront => 'أمام النص',
      };
    }
    return switch (wrap) {
      PictureWrap.inline => 'In line',
      PictureWrap.square => 'Square',
      PictureWrap.tight => 'Tight',
      PictureWrap.through => 'Through',
      PictureWrap.topAndBottom => 'Top and bottom',
      PictureWrap.behind => 'Behind',
      PictureWrap.inFront => 'In front',
    };
  }

  Widget _animationPane(bool dark) {
    final List<PmlShapeAnimation> anims = _slides.slide.animations;
    var clickNo = 0;
    return Material(
      color: dark ? const Color(0xFF242424) : const Color(0xFFF3F3F3),
      child: SizedBox(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StudioPaneTitle(
              text: _arabic ? 'جزء الحركة' : 'Animation pane',
              accent: _accent,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(
                anims.isEmpty
                    ? (_arabic
                          ? 'حدد شكلاً ثم اختر حركة من الشريط.'
                          : 'Select a shape, then add an effect.')
                    : '${anims.length} ${_arabic ? 'حركة' : 'effects'}',
                style: TextStyle(
                  fontSize: 11,
                  color: _officeTheme.chromeText.withValues(alpha: 0.7),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: anims.length,
                itemBuilder: (BuildContext context, int i) {
                  final PmlShapeAnimation anim = anims[i];
                  if (i == 0 || anim.trigger == PmlAnimTrigger.onClick) {
                    clickNo++;
                  }
                  final bool on = _slides.selectedAnimationIndex == i;
                  final String shapeName = _slides.slide.shapes
                      .firstWhere(
                        (PmlShape s) => s.id == anim.shapeId,
                        orElse: () => PmlShape(
                          id: anim.shapeId,
                          name: '#${anim.shapeId}',
                        ),
                      )
                      .name;
                  final Color tone = switch (anim.category) {
                    PmlAnimClass.entrance => const Color(0xFF217346),
                    PmlAnimClass.emphasis => const Color(0xFFC9A227),
                    PmlAnimClass.exit => const Color(0xFFB7472A),
                    PmlAnimClass.motion => const Color(0xFF2B579A),
                  };
                  return ListTile(
                    dense: true,
                    selected: on,
                    selectedTileColor: _accent.withValues(alpha: 0.12),
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: tone,
                      child: Text(
                        '$clickNo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    title: Text(
                      PmlMotionCatalog.animLabel(anim.preset, arabic: _arabic),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _officeTheme.chromeText,
                      ),
                    ),
                    subtitle: Text(
                      '$shapeName · ${_triggerLabel(anim.trigger)}'
                      '${anim.delayMs > 0 ? ' · ${anim.delayMs}ms' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: _officeTheme.chromeText.withValues(alpha: 0.7),
                      ),
                    ),
                    onTap: () => _slides.selectAnimation(i),
                  );
                },
              ),
            ),
            if (anims.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Wrap(
                  spacing: 4,
                  children: <Widget>[
                    _icon(
                      Icons.keyboard_arrow_up,
                      _arabic ? 'أعلى' : 'Up',
                      _slides.selectedAnimationIndex == null
                          ? null
                          : () => _slides.moveShapeAnimation(
                              _slides.selectedAnimationIndex!,
                              -1,
                            ),
                    ),
                    _icon(
                      Icons.keyboard_arrow_down,
                      _arabic ? 'أسفل' : 'Down',
                      _slides.selectedAnimationIndex == null
                          ? null
                          : () => _slides.moveShapeAnimation(
                              _slides.selectedAnimationIndex!,
                              1,
                            ),
                    ),
                    _icon(
                      Icons.delete_outline,
                      _arabic ? 'حذف' : 'Remove',
                      _slides.selectedAnimationIndex == null
                          ? null
                          : () => _slides.removeShapeAnimation(
                              _slides.selectedAnimationIndex!,
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _presenterPane() {
    final Duration elapsed = _slides.presenterElapsed;
    final String clock =
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    final int? next = _slides.nextVisibleSlide;
    final String nextText = next == null
        ? (_arabic ? 'النهاية' : 'End')
        : _slides.presentation.slides[next].notes.isEmpty
        ? '${_arabic ? 'الشريحة' : 'Slide'} ${next + 1}'
        : _slides.presentation.slides[next].notes;
    return ColoredBox(
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _arabic ? 'عرض المقدّم' : 'Presenter',
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _slides.pausePresenter,
                  icon: Icon(
                    _slides.presenterPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            Text(
              clock,
              style: const TextStyle(color: Color(0xFF8CD3FF), fontSize: 28),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: IgnorePointer(
                child: SlideStage(
                  slide: _slides.slide,
                  preview: true,
                  config: _config.copyWith(
                    mode: OfficeInteractionMode.viewing,
                    showSlideHandles: false,
                    showRulers: false,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _slides.presentation.slides.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: 6),
                itemBuilder: (BuildContext context, int i) {
                  final bool on = i == _slides.activeSlideIndex;
                  return GestureDetector(
                    onTap: () => _slides.setActiveSlide(i),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: on ? _accent : const Color(0xFF555555),
                          width: on ? 2 : 1,
                        ),
                      ),
                      child: SizedBox(
                        width: 72,
                        child: IgnorePointer(
                          child: SlideStage(
                            slide: _slides.presentation.slides[i],
                            preview: true,
                            config: _config.copyWith(
                              mode: OfficeInteractionMode.viewing,
                              showSlideHandles: false,
                              showRulers: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _arabic ? 'ملاحظات هذه الشريحة' : 'This slide',
              style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 11),
            ),
            Text(
              _slides.slide.notes.isEmpty
                  ? (_arabic ? 'لا ملاحظات' : 'No notes')
                  : _slides.slide.notes,
              style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              _arabic ? 'التالي' : 'Next',
              style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 11),
            ),
            Text(
              nextText,
              style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _syncSlideNotesField() {
    if (_notesSlideIndex == _slides.activeSlideIndex &&
        _slideNotesEdit.text == _slides.slide.notes) {
      return;
    }
    _notesSlideIndex = _slides.activeSlideIndex;
    if (_slideNotesEdit.text != _slides.slide.notes) {
      _slideNotesEdit.value = TextEditingValue(
        text: _slides.slide.notes,
        selection: TextSelection.collapsed(offset: _slides.slide.notes.length),
      );
    }
  }

  Widget _slideNotes(bool dark) {
    _syncSlideNotesField();
    return Material(
      color: dark ? const Color(0xFF242424) : const Color(0xFFF7F7F7),
      child: SizedBox(
        height: 88,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _arabic ? 'ملاحظات المحاضر' : 'Presenter notes',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _accent,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: TextField(
                  controller: _slideNotesEdit,
                  enabled: _canMutate,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 12,
                    color: _officeTheme.chromeText,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: _arabic
                        ? 'اكتب ملاحظات المتحدث…'
                        : 'Type speaker notes…',
                  ),
                  onChanged: _slides.setSpeakerNotes,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidePane(bool dark) {
    final Color bg = dark ? const Color(0xFF242424) : const Color(0xFFF3F3F3);
    return Material(
      color: bg,
      child: SizedBox(
        width: 268,
        child: switch (_app) {
          SuiteApp.word => _wordNav(),
          SuiteApp.excel => _sheetNav(),
          SuiteApp.powerpoint => _slideNav(),
          SuiteApp.pdf => _pdfNav(),
        },
      ),
    );
  }

  String _headingStyleLabel(int level) {
    if (level <= 0) {
      return _arabic ? 'عادي' : 'Normal';
    }
    return _arabic ? 'عنوان $level' : 'Heading $level';
  }

  Widget _wordNav() {
    final List<WmlHeadingRef> headings = WordToc.headings(_word.document);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StudioPaneTitle(text: _arabic ? 'المخطط' : 'Outline', accent: _accent),
        Expanded(
          child: ListView(
            children: <Widget>[
              for (final WmlHeadingRef heading in headings)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsetsDirectional.only(
                    start: 12 + (heading.level - 1) * 12,
                    end: 8,
                  ),
                  selected: _word.documentCaret.paragraphIndex == heading.index,
                  selectedTileColor: _accent.withValues(alpha: 0.12),
                  title: Text(
                    heading.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: heading.level == 1 ? 13 : 12,
                      fontWeight: heading.level == 1
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: _officeTheme.chromeText,
                    ),
                  ),
                  onTap: () => _word.jumpToParagraph(heading.index),
                ),
              const Divider(height: 1),
              StudioPaneTitle(
                text: _arabic ? 'الخصائص' : 'Properties',
                accent: _accent,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Text(
                  _arabic ? 'جرّب من الشريط' : 'Try from the ribbon',
                  style: TextStyle(
                    fontSize: 11,
                    color: _officeTheme.chromeText.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  children: <Widget>[
                    StudioMetaChip(
                      label: _arabic ? 'عريض / مائل' : 'Bold / Italic',
                      accent: _accent,
                    ),
                    StudioMetaChip(
                      label: _arabic ? 'جدول ٣×٣' : '3×3 table',
                      accent: _accent,
                    ),
                    StudioMetaChip(
                      label: _arabic ? 'فاصل صفحة' : 'Page break',
                      accent: _accent,
                    ),
                    StudioMetaChip(
                      label: 'RTL / LTR',
                      accent: const Color(0xFF217346),
                    ),
                    StudioMetaChip(
                      label: 'Ctrl+Z',
                      accent: const Color(0xFFB7472A),
                      tone: const Color(0xFFB7472A),
                    ),
                    StudioMetaChip(
                      label: _arabic ? 'تحديد كلمة' : 'Select word',
                      accent: const Color(0xFFC9A227),
                      tone: const Color(0xFFC9A227),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sheetNav() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StudioPaneTitle(text: _arabic ? 'الأوراق' : 'Sheets', accent: _accent),
        for (int i = 0; i < _sheet.workbook.sheets.length; i++)
          ListTile(
            dense: true,
            leading: Icon(Icons.table_chart_outlined, color: _accent, size: 18),
            selected: i == _sheet.activeSheetIndex,
            selectedTileColor: _accent.withValues(alpha: 0.12),
            title: Text(_sheet.workbook.sheets[i].name),
            subtitle: Text(
              '${_sheet.workbook.sheets[i].allCells.length} '
              '${_arabic ? 'خلية' : 'cells'}',
            ),
            onTap: () => _sheet.setActiveSheet(i),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${_arabic ? 'الخلية' : 'Cell'} ${_sheet.selectionAddress}\n'
            '${_sheet.formulaBarText}',
            style: TextStyle(fontSize: 12, color: _officeTheme.chromeText),
          ),
        ),
      ],
    );
  }

  Widget _pdfNav() {
    final PdfOutlineNode? outline = _pdf.file?.outline;
    final bool hasOutline = outline != null && outline.children.isNotEmpty;
    final int tab = hasOutline ? _pdfSideTab.clamp(0, 1) : 0;
    if (!hasOutline && _pdfSideTab != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _pdfSideTab = 0);
        }
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: tab == 0 ? _pdfThumbsPane() : _pdfOutlinePane(outline!),
        ),
        if (hasOutline) _pdfSideTabBar(tab),
      ],
    );
  }

  Widget _pdfSideTabBar(int tab) {
    Widget iconTab({
      required IconData icon,
      required int index,
      required String tip,
    }) {
      final bool selected = tab == index;
      return Tooltip(
        message: tip,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _pdfSideTab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 40,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? _accent.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: selected
                  ? _accent
                  : _officeTheme.chromeText.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
    }

    return Material(
      color: _officeTheme.chromeFill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: _officeTheme.chromeText.withValues(alpha: 0.12),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            iconTab(
              icon: Icons.grid_view_rounded,
              index: 0,
              tip: _arabic ? 'معاينة الصفحات' : 'Page previews',
            ),
            iconTab(
              icon: Icons.format_list_bulleted_rounded,
              index: 1,
              tip: _arabic ? 'المخطط' : 'Outline',
            ),
          ],
        ),
      ),
    );
  }

  Widget _pdfThumbsPane() {
    final List<PdfDisplayList> lists = _pdf.lists;
    final int current = _pdf.pageIndex;
    if (current != _pdfThumbSyncedPage) {
      _pdfThumbSyncedPage = current;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pdfThumbScroll.hasClients || lists.isEmpty) {
          return;
        }
        // ListView.builder may not have built the selected child yet, so
        // estimate offset from page aspect instead of ensureVisible alone.
        const double pad = 12;
        final double contentW = math.max(
          80,
          _pdfThumbScroll.position.viewportDimension > 0 ? 268 - pad * 2 : 244,
        );
        var y = 4.0;
        for (int i = 0; i < current && i < lists.length; i++) {
          final PdfDisplayList list = lists[i];
          final double pageW = list.page.width <= 0 ? 595 : list.page.width;
          final double pageH = list.page.height <= 0 ? 842 : list.page.height;
          final double thumbH = contentW * pageH / pageW;
          y += thumbH + 6 + 16 + 12; // thumb + gap + label + padding
        }
        final double max = _pdfThumbScroll.position.maxScrollExtent;
        final double target = (y - 24).clamp(0.0, max);
        _pdfThumbScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StudioPaneTitle(
          text: _arabic ? 'معاينة الصفحات' : 'Page previews',
          accent: _accent,
        ),
        Expanded(
          child: ListView.builder(
            controller: _pdfThumbScroll,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            itemCount: lists.length,
            itemBuilder: (BuildContext context, int index) {
              final bool selected = index == current;
              return Padding(
                key: ValueKey<int>(index),
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _pdf.goToPage(index),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      PdfPageThumb(
                        list: lists[index],
                        selected: selected,
                        annots:
                            _pdf.file?.annotsOn(index) ?? const <PdfAnnot>[],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_arabic ? 'صفحة' : 'Page'} ${index + 1}'
                        '${selected ? (_arabic ? '  ·  الحالية' : '  ·  current') : ''}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? _accent
                              : _officeTheme.chromeText.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _pdfOutlinePane(PdfOutlineNode root) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StudioPaneTitle(text: _arabic ? 'المخطط' : 'Outline', accent: _accent),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 16),
            children: <Widget>[
              for (int i = 0; i < root.children.length; i++)
                _pdfOutlineTile(root.children[i], 'r$i', 0),
            ],
          ),
        ),
      ],
    );
  }

  int? _outlineTargetPage(PdfOutlineNode node) {
    if (node.pageIndex != null) {
      return node.pageIndex;
    }
    for (final PdfOutlineNode child in node.children) {
      final int? page = _outlineTargetPage(child);
      if (page != null) {
        return page;
      }
    }
    return null;
  }

  Widget _pdfOutlineTile(PdfOutlineNode node, String path, int depth) {
    final bool hasKids = node.children.isNotEmpty;
    // Collapsed keys are stored as `c$path`; default is expanded (Evince-like).
    final bool open = hasKids && !_pdfOutlineExpanded.contains('c$path');
    final int? page = _outlineTargetPage(node);
    final bool selected =
        page != null && page == _pdf.pageIndex && node.pageIndex == page;

    void toggleExpand() {
      setState(() {
        final String key = 'c$path';
        if (_pdfOutlineExpanded.contains(key)) {
          _pdfOutlineExpanded.remove(key);
        } else {
          _pdfOutlineExpanded.add(key);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: selected
              ? _accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: page == null
                ? (hasKids ? toggleExpand : null)
                : () => _pdf.goToPage(page),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: 4.0 + depth * 12.0,
                end: 4,
                top: 6,
                bottom: 6,
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: hasKids
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            onPressed: toggleExpand,
                            icon: Icon(
                              open ? Icons.expand_more : Icons.chevron_right,
                              color: _officeTheme.chromeText.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: Text(
                      node.title.trim().isEmpty
                          ? (_arabic ? '(بدون عنوان)' : '(Untitled)')
                          : node.title.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: depth == 0 ? 13 : 12,
                        fontWeight: depth == 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _officeTheme.chromeText,
                      ),
                    ),
                  ),
                  if (page != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: Text(
                        '${page + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: _officeTheme.chromeText.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (open)
          for (int i = 0; i < node.children.length; i++)
            _pdfOutlineTile(node.children[i], '$path.$i', depth + 1),
      ],
    );
  }

  Widget _slideNav() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StudioPaneTitle(
          text: _arabic ? 'فارز الشرائح' : 'Slide sorter',
          accent: _accent,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double cardW = math.max(80, constraints.maxWidth - 16);
              final double previewH = cardW * 405 / 720;
              return ReorderableListView.builder(
                padding: const EdgeInsets.all(8),
                buildDefaultDragHandles: false,
                itemCount: _slides.presentation.slides.length,
                proxyDecorator:
                    (Widget child, int index, Animation<double> anim) {
                      return Material(
                        elevation: 6,
                        color: Colors.transparent,
                        child: child,
                      );
                    },
                onReorder: (int from, int to) {
                  if (!_canMutate) {
                    return;
                  }
                  var dest = to;
                  if (dest > from) {
                    dest -= 1;
                  }
                  _slides.reorderSlide(from, dest);
                },
                itemBuilder: (BuildContext context, int i) {
                  return _slideSorterCard(
                    key: ObjectKey(_slides.presentation.slides[i]),
                    index: i,
                    previewHeight: previewH,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _slideSorterCard({
    required Key key,
    required int index,
    required double previewHeight,
  }) {
    final PmlSlide slide = _slides.presentation.slides[index];
    final bool on = index == _slides.activeSlideIndex;
    final bool hidden = slide.hidden;
    final bool dark = _look != SuiteLook.light;
    final Color card = dark ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF);
    final Color mat = dark ? const Color(0xFF1A1A1A) : const Color(0xFFB8B8B8);
    final Color frame = on
        ? _accent
        : (hidden
              ? (dark ? const Color(0xFF7A7A7A) : const Color(0xFF6A6A6A))
              : (dark ? const Color(0xFFD0D0D0) : const Color(0xFF1F1F1F)));
    final Color slideStroke = dark
        ? const Color(0xFF000000)
        : const Color(0xFF111111);
    return ReorderableDragStartListener(
      key: key,
      index: index,
      enabled: _canMutate,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: card,
          elevation: on ? 5 : 2,
          shadowColor: const Color(0x88000000),
          child: InkWell(
            onTap: () => _slides.setActiveSlide(index),
            onSecondaryTapDown: (TapDownDetails details) {
              _slides.setActiveSlide(index);
              _showSlideSorterMenu(details.globalPosition, index);
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: frame, width: on ? 3 : 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                    child: Row(
                      children: <Widget>[
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            color: hidden ? const Color(0xFF777777) : _accent,
                            fontWeight: FontWeight.bold,
                            decoration: hidden
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        if (hidden)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 4),
                            child: Icon(
                              Icons.visibility_off,
                              size: 12,
                              color: _accent,
                            ),
                          ),
                        const Spacer(),
                        if (!slide.transition.isNone)
                          Icon(Icons.animation, size: 12, color: _accent),
                        if (slide.animations.isNotEmpty)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 4),
                            child: Text(
                              '${slide.animations.length}',
                              style: TextStyle(
                                fontSize: 10,
                                color: _accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
                    child: ColoredBox(
                      color: mat,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: slideStroke, width: 1.5),
                          ),
                          child: SizedBox(
                            height: previewHeight,
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                Opacity(
                                  opacity: hidden ? 0.42 : 1,
                                  child: IgnorePointer(
                                    child: SlideStage(
                                      slide: slide,
                                      preview: true,
                                      config: _config.copyWith(
                                        mode: OfficeInteractionMode.viewing,
                                        showSlideHandles: false,
                                        showRulers: false,
                                      ),
                                    ),
                                  ),
                                ),
                                if (hidden)
                                  const ColoredBox(
                                    color: Color(0x33000000),
                                    child: Align(
                                      alignment: Alignment.bottomLeft,
                                      child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.visibility_off,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSlideSorterMenu(Offset globalPosition, int index) {
    OfficeContextMenu.dismiss(_slideSorterMenu);
    _slideSorterMenu = OfficeContextMenu.show(
      context: context,
      globalPosition: globalPosition,
      actions: OfficeContextMenu.slideSorter(controller: _slides, index: index),
      onSelect: (String id) {
        _slideSorterMenu = null;
        switch (id) {
          case 'copySlide':
            _slides.copySlide(index);
          case 'pasteSlide':
            _slides.pasteSlide(afterIndex: index);
          case 'duplicateSlide':
            _slides.duplicateSlide(index);
          case 'hideSlide':
            _slides.setSlideHidden(index, true);
          case 'showSlide':
            _slides.setSlideHidden(index, false);
        }
      },
    );
  }

  Widget _statusBar() {
    final String detail = switch (_app) {
      SuiteApp.word =>
        '${_arabic ? 'صفحة' : 'Page'} ${_word.visiblePageIndex + 1}'
            ' ${_arabic ? 'من' : 'of'} ${_word.pageCount}'
            ' · ${_arabic ? 'فقرة' : 'Paragraph'} ${_word.documentCaret.paragraphIndex + 1}'
            ' · ${_word.document.paragraphs.length} '
            '${_arabic ? 'فقرات' : 'paragraphs'}'
            ' · $_wordCount ${_arabic ? 'كلمة' : 'words'}'
            '${_word.selectedVisual != null ? ' · ${_word.selectedVisual!.visual.title}' : ''}'
            '${WordComment.roots(_word.document).isEmpty ? '' : ' · ${WordComment.roots(_word.document).length} ${_arabic ? 'تعليقات' : 'comments'}'}'
            '${_word.isDirty ? ' · •' : ''}',
      SuiteApp.excel =>
        '${_sheet.sheet.name}!${_sheet.selectionAddress}'
            '${_sheet.cellEditor.editing ? (_arabic ? ' · تحرير الخلية' : ' · editing cell') : ''}'
            ' · ${_sheet.workbook.sheets.length} '
            '${_arabic ? 'أوراق' : 'sheets'}'
            '${_sheet.selectedDrawing != null ? ' · ${_sheet.selectedDrawing!.visual.title}' : ''}'
            '${_sheet.isDirty ? ' · •' : ''}',
      SuiteApp.powerpoint =>
        '${_arabic ? 'شريحة' : 'Slide'} ${_slides.activeSlideIndex + 1}'
            '/${_slides.presentation.slides.length}'
            '${_slides.isPresenting ? (_arabic ? ' · عرض الشرائح · Esc للخروج' : ' · slideshow · Esc to exit') : ''}'
            '${!_slides.slide.transition.isNone ? ' · ${PmlMotionCatalog.transitionLabel(_slides.slide.transition.kind, arabic: _arabic)}' : ''}'
            '${_slides.slide.animations.isNotEmpty ? ' · ${_slides.slide.animations.length} ${_arabic ? 'حركة' : 'fx'}' : ''}'
            '${_slides.selected != null ? ' · ${_slides.selected!.name}' : ''}'
            '${_slides.editingText ? (_arabic ? ' · تحرير النص' : ' · editing text') : ''}'
            '${_slides.slide.hidden ? (_arabic ? ' · مخفية' : ' · hidden') : ''}'
            '${_slides.isDirty ? ' · •' : ''}',
      SuiteApp.pdf =>
        '${_arabic ? 'صفحة' : 'Page'} ${_pdf.pageIndex + 1}/${_pdf.pageCount}'
            '${_pdfNightMode ? (_arabic ? ' · ليلي' : ' · night') : ''}'
            '${_pdfSwipeHorizontal ? (_arabic ? ' · أفقي' : ' · horizontal') : ''}'
            '${_pdfPageSnap ? (_arabic ? ' · محاذاة' : ' · snap') : ''}'
            '${_pdfEvents.last.isEmpty ? '' : ' · ${_pdfEvents.last}'}'
            '${_pdf.isDirty ? ' · •' : ''}',
    };
    return Material(
      color: _accent,
      child: SizedBox(
        height: _savePhase == _SavePhase.saving || _opening ? 34 : 26,
        child: Column(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _opening
                            ? _openStatusLabel
                            : (_isSaving
                                  ? _saveStatusLabel
                                  : '$_modeLabel · $detail'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    InkWell(
                      onTap: () => _setZoom(_viewScale - 0.1),
                      child: const Icon(
                        Icons.remove,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '$_zoomPercent%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _setZoom(_viewScale + 0.1),
                      child: const Icon(
                        Icons.add,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _app == SuiteApp.pdf
                          ? (_arabic ? 'مستند PDF' : 'PDF document')
                          : _active.semanticsLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            if (_savePhase == _SavePhase.saving || _opening)
              LinearProgressIndicator(
                value: (_opening ? _openProgress : _saveProgress).clamp(
                  0.0,
                  1.0,
                ),
                minHeight: 4,
                backgroundColor: const Color(0x33FFFFFF),
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }

  int get _wordCount => _word.documentStats.words;
}
