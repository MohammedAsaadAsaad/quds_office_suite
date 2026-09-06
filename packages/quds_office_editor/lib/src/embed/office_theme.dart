import 'dart:ui';

/// How the host wants the surface to behave when embedded.
enum OfficeInteractionMode {
  /// Scroll/zoom only. No caret, handles, IME, or mutations.
  viewing,

  /// Selection and copy. No IME or document mutations.
  selecting,

  /// Full Office-like editing.
  editing,
}

/// Visual tokens for every custom RenderBox surface.
class OfficeTheme {
  const OfficeTheme({
    required this.canvasBackground,
    required this.pageBackground,
    required this.pageBorder,
    required this.caret,
    required this.selectionFill,
    required this.selectionStroke,
    required this.gridLine,
    required this.frozenFill,
    required this.headerFill,
    required this.headerText,
    required this.chromeFill,
    required this.chromeText,
    required this.handleStroke,
    required this.handleFill,
    required this.snapGuide,
    required this.slideBackground,
    required this.focusRing,
    this.fontFamily,
  });

  final Color canvasBackground;
  final Color pageBackground;
  final Color pageBorder;
  final Color caret;
  final Color selectionFill;
  final Color selectionStroke;
  final Color gridLine;
  final Color frozenFill;
  final Color headerFill;
  final Color headerText;
  final Color chromeFill;
  final Color chromeText;
  final Color handleStroke;
  final Color handleFill;
  final Color snapGuide;
  final Color slideBackground;
  final Color focusRing;
  final String? fontFamily;

  static const OfficeTheme light = OfficeTheme(
    canvasBackground: Color(0xFF5B5B5B),
    pageBackground: Color(0xFFFFFFFF),
    pageBorder: Color(0xFFB0B0B0),
    caret: Color(0xFF000000),
    selectionFill: Color(0x332E75B6),
    selectionStroke: Color(0xFF2E75B6),
    gridLine: Color(0xFFD0D0D0),
    frozenFill: Color(0xFFE8E8E8),
    headerFill: Color(0xFFF3F3F3),
    headerText: Color(0xFF444444),
    chromeFill: Color(0xFFF7F7F7),
    chromeText: Color(0xFF222222),
    handleStroke: Color(0xFF2E75B6),
    handleFill: Color(0xFFFFFFFF),
    snapGuide: Color(0xFFFF4FA0),
    slideBackground: Color(0xFFFFFFFF),
    focusRing: Color(0xFF2E75B6),
  );

  static const OfficeTheme dark = OfficeTheme(
    canvasBackground: Color(0xFF1E1E1E),
    pageBackground: Color(0xFF2B2B2B),
    pageBorder: Color(0xFF555555),
    caret: Color(0xFFF2F2F2),
    selectionFill: Color(0x664478C4),
    selectionStroke: Color(0xFF5B9BD5),
    gridLine: Color(0xFF3F3F3F),
    frozenFill: Color(0xFF333333),
    headerFill: Color(0xFF2A2A2A),
    headerText: Color(0xFFDDDDDD),
    chromeFill: Color(0xFF252525),
    chromeText: Color(0xFFEEEEEE),
    handleStroke: Color(0xFF5B9BD5),
    handleFill: Color(0xFF2B2B2B),
    snapGuide: Color(0xFFFF7AC3),
    slideBackground: Color(0xFF2B2B2B),
    focusRing: Color(0xFF5B9BD5),
  );

  static const OfficeTheme highContrast = OfficeTheme(
    canvasBackground: Color(0xFF000000),
    pageBackground: Color(0xFF000000),
    pageBorder: Color(0xFFFFFFFF),
    caret: Color(0xFFFFFF00),
    selectionFill: Color(0x99FFFF00),
    selectionStroke: Color(0xFFFFFF00),
    gridLine: Color(0xFFFFFFFF),
    frozenFill: Color(0xFF1A1A1A),
    headerFill: Color(0xFF000000),
    headerText: Color(0xFFFFFFFF),
    chromeFill: Color(0xFF000000),
    chromeText: Color(0xFFFFFFFF),
    handleStroke: Color(0xFFFFFF00),
    handleFill: Color(0xFF000000),
    snapGuide: Color(0xFF00FFFF),
    slideBackground: Color(0xFF000000),
    focusRing: Color(0xFFFFFF00),
  );

  OfficeTheme copyWith({
    Color? canvasBackground,
    Color? pageBackground,
    Color? pageBorder,
    Color? caret,
    Color? selectionFill,
    Color? selectionStroke,
    Color? gridLine,
    Color? frozenFill,
    Color? headerFill,
    Color? headerText,
    Color? chromeFill,
    Color? chromeText,
    Color? handleStroke,
    Color? handleFill,
    Color? snapGuide,
    Color? slideBackground,
    Color? focusRing,
    String? fontFamily,
  }) {
    return OfficeTheme(
      canvasBackground: canvasBackground ?? this.canvasBackground,
      pageBackground: pageBackground ?? this.pageBackground,
      pageBorder: pageBorder ?? this.pageBorder,
      caret: caret ?? this.caret,
      selectionFill: selectionFill ?? this.selectionFill,
      selectionStroke: selectionStroke ?? this.selectionStroke,
      gridLine: gridLine ?? this.gridLine,
      frozenFill: frozenFill ?? this.frozenFill,
      headerFill: headerFill ?? this.headerFill,
      headerText: headerText ?? this.headerText,
      chromeFill: chromeFill ?? this.chromeFill,
      chromeText: chromeText ?? this.chromeText,
      handleStroke: handleStroke ?? this.handleStroke,
      handleFill: handleFill ?? this.handleFill,
      snapGuide: snapGuide ?? this.snapGuide,
      slideBackground: slideBackground ?? this.slideBackground,
      focusRing: focusRing ?? this.focusRing,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}

/// Host-facing chrome and interaction flags for an embedded surface.
class OfficeSurfaceConfig {
  const OfficeSurfaceConfig({
    this.mode = OfficeInteractionMode.editing,
    this.theme = OfficeTheme.light,
    this.showRulers = true,
    this.showFormulaBar = true,
    this.showGridHeaders = true,
    this.showGridlines = true,
    this.showSlideHandles = true,
    this.enableUndo = true,
    this.autofocus = false,
    this.textDirection = TextDirection.ltr,
    this.strings = OfficeStrings.english,
  });

  final OfficeInteractionMode mode;
  final OfficeTheme theme;
  final bool showRulers;
  final bool showFormulaBar;
  final bool showGridHeaders;
  final bool showGridlines;
  final bool showSlideHandles;
  final bool enableUndo;
  final bool autofocus;
  final TextDirection textDirection;
  final OfficeStrings strings;

  bool get allowsMutation => mode == OfficeInteractionMode.editing;

  bool get allowsSelection =>
      mode == OfficeInteractionMode.editing ||
      mode == OfficeInteractionMode.selecting;

  bool get showsCaret => mode == OfficeInteractionMode.editing;

  OfficeSurfaceConfig copyWith({
    OfficeInteractionMode? mode,
    OfficeTheme? theme,
    bool? showRulers,
    bool? showFormulaBar,
    bool? showGridHeaders,
    bool? showGridlines,
    bool? showSlideHandles,
    bool? enableUndo,
    bool? autofocus,
    TextDirection? textDirection,
    OfficeStrings? strings,
  }) {
    return OfficeSurfaceConfig(
      mode: mode ?? this.mode,
      theme: theme ?? this.theme,
      showRulers: showRulers ?? this.showRulers,
      showFormulaBar: showFormulaBar ?? this.showFormulaBar,
      showGridHeaders: showGridHeaders ?? this.showGridHeaders,
      showGridlines: showGridlines ?? this.showGridlines,
      showSlideHandles: showSlideHandles ?? this.showSlideHandles,
      enableUndo: enableUndo ?? this.enableUndo,
      autofocus: autofocus ?? this.autofocus,
      textDirection: textDirection ?? this.textDirection,
      strings: strings ?? this.strings,
    );
  }
}

/// Accessible labels for screen readers and chrome (English / Arabic).
class OfficeStrings {
  const OfficeStrings({
    required this.wordEditor,
    required this.sheetEditor,
    required this.slideEditor,
    required this.formulaBar,
    required this.pageLabel,
    required this.cellLabel,
    required this.shapeLabel,
    required this.viewing,
    required this.editing,
    required this.undo,
    required this.redo,
    this.speakerNotes = 'Speaker notes',
    this.cut = 'Cut',
    this.copy = 'Copy',
    this.paste = 'Paste',
    this.pasteKeepSource = 'Keep source formatting',
    this.pasteMerge = 'Merge formatting',
    this.pasteTextOnly = 'Keep text only',
    this.pictureLabel = 'Picture',
    this.cropMode = 'Crop mode',
    this.pictureHint =
        'Drag handles to resize. Drag the picture to move. Press C to crop. Shift plus arrows resize.',
    this.followLinkHint = 'Press Ctrl and click to follow the link',
    this.selectAll = 'Select all',
    this.insertComment = 'New comment',
    this.replyComment = 'Reply',
    this.resolveComment = 'Resolve',
    this.reopenComment = 'Reopen',
    this.deleteComment = 'Delete comment',
    this.insertRowAbove = 'Insert row above',
    this.insertRowBelow = 'Insert row below',
    this.insertColumnLeft = 'Insert column left',
    this.insertColumnRight = 'Insert column right',
    this.deleteRow = 'Delete row',
    this.deleteColumn = 'Delete column',
    this.deleteTable = 'Delete table',
    this.autoFitContents = 'AutoFit contents',
    this.autoFitWindow = 'AutoFit window',
    this.autoFitFixed = 'Fixed column width',
    this.mergeTableCells = 'Merge cells',
    this.unmergeTableCells = 'Split cells',
    this.insertSheetRow = 'Insert row',
    this.insertSheetColumn = 'Insert column',
    this.deleteSheetRow = 'Delete row',
    this.deleteSheetColumn = 'Delete column',
    this.clearCells = 'Clear contents',
    this.deleteShape = 'Delete',
    this.followLink = 'Open link',
    this.hideSlide = 'Hide Slide',
    this.showSlide = 'Show Slide',
  });

  final String wordEditor;
  final String sheetEditor;
  final String slideEditor;
  final String formulaBar;
  final String pageLabel;
  final String cellLabel;
  final String shapeLabel;
  final String viewing;
  final String editing;
  final String undo;
  final String redo;
  final String speakerNotes;
  final String cut;
  final String copy;
  final String paste;
  final String pasteKeepSource;
  final String pasteMerge;
  final String pasteTextOnly;
  final String pictureLabel;
  final String cropMode;
  final String pictureHint;
  final String followLinkHint;
  final String selectAll;
  final String insertComment;
  final String replyComment;
  final String resolveComment;
  final String reopenComment;
  final String deleteComment;
  final String insertRowAbove;
  final String insertRowBelow;
  final String insertColumnLeft;
  final String insertColumnRight;
  final String deleteRow;
  final String deleteColumn;
  final String deleteTable;
  final String autoFitContents;
  final String autoFitWindow;
  final String autoFitFixed;
  final String mergeTableCells;
  final String unmergeTableCells;
  final String insertSheetRow;
  final String insertSheetColumn;
  final String deleteSheetRow;
  final String deleteSheetColumn;
  final String clearCells;
  final String deleteShape;
  final String followLink;
  final String hideSlide;
  final String showSlide;

  static const OfficeStrings english = OfficeStrings(
    wordEditor: 'Word document',
    sheetEditor: 'Spreadsheet',
    slideEditor: 'Slide',
    formulaBar: 'Formula bar',
    pageLabel: 'Page',
    cellLabel: 'Cell',
    shapeLabel: 'Shape',
    viewing: 'Viewing',
    editing: 'Editing',
    undo: 'Undo',
    redo: 'Redo',
    speakerNotes: 'Speaker notes',
    cut: 'Cut',
    copy: 'Copy',
    paste: 'Paste',
    pasteKeepSource: 'Keep source formatting',
    pasteMerge: 'Merge formatting',
    pasteTextOnly: 'Keep text only',
    pictureLabel: 'Picture',
    cropMode: 'Crop mode',
    pictureHint:
        'Drag handles to resize. Drag the picture to move. Press C to crop. Shift plus arrows resize.',
    followLinkHint: 'Press Ctrl and click to follow the link',
    selectAll: 'Select all',
    insertComment: 'New comment',
    replyComment: 'Reply',
    resolveComment: 'Resolve',
    reopenComment: 'Reopen',
    deleteComment: 'Delete comment',
    insertRowAbove: 'Insert row above',
    insertRowBelow: 'Insert row below',
    insertColumnLeft: 'Insert column left',
    insertColumnRight: 'Insert column right',
    deleteRow: 'Delete row',
    deleteColumn: 'Delete column',
    deleteTable: 'Delete table',
    autoFitContents: 'AutoFit contents',
    autoFitWindow: 'AutoFit window',
    autoFitFixed: 'Fixed column width',
    mergeTableCells: 'Merge cells',
    unmergeTableCells: 'Split cells',
    insertSheetRow: 'Insert row',
    insertSheetColumn: 'Insert column',
    deleteSheetRow: 'Delete row',
    deleteSheetColumn: 'Delete column',
    clearCells: 'Clear contents',
    deleteShape: 'Delete',
    followLink: 'Open link',
    hideSlide: 'Hide Slide',
    showSlide: 'Show Slide',
  );

  static const OfficeStrings arabic = OfficeStrings(
    wordEditor: 'مستند وورد',
    sheetEditor: 'ورقة عمل',
    slideEditor: 'شريحة',
    formulaBar: 'شريط الصيغة',
    pageLabel: 'صفحة',
    cellLabel: 'خلية',
    shapeLabel: 'شكل',
    viewing: 'عرض',
    editing: 'تحرير',
    undo: 'تراجع',
    redo: 'إعادة',
    speakerNotes: 'ملاحظات المحاضر',
    cut: 'قص',
    copy: 'نسخ',
    paste: 'لصق',
    pasteKeepSource: 'الاحتفاظ بتنسيق المصدر',
    pasteMerge: 'دمج التنسيق',
    pasteTextOnly: 'الاحتفاظ بالنص فقط',
    pictureLabel: 'صورة',
    cropMode: 'وضع القص',
    pictureHint:
        'اسحب المقابض لتغيير الحجم. اسحب الصورة لنقلها. اضغط C للقص. Shift مع الأسهم لتغيير الحجم.',
    followLinkHint: 'اضغط Ctrl ثم انقر للانتقال',
    selectAll: 'تحديد الكل',
    insertComment: 'تعليق جديد',
    replyComment: 'رد',
    resolveComment: 'حلّ',
    reopenComment: 'إعادة فتح',
    deleteComment: 'حذف التعليق',
    insertRowAbove: 'إدراج صف أعلى',
    insertRowBelow: 'إدراج صف أسفل',
    insertColumnLeft: 'إدراج عمود يسار',
    insertColumnRight: 'إدراج عمود يمين',
    deleteRow: 'حذف الصف',
    deleteColumn: 'حذف العمود',
    deleteTable: 'حذف الجدول',
    autoFitContents: 'ملاءمة المحتوى',
    autoFitWindow: 'ملاءمة النافذة',
    autoFitFixed: 'عرض أعمدة ثابت',
    mergeTableCells: 'دمج الخلايا',
    unmergeTableCells: 'إلغاء الدمج',
    insertSheetRow: 'إدراج صف',
    insertSheetColumn: 'إدراج عمود',
    deleteSheetRow: 'حذف الصف',
    deleteSheetColumn: 'حذف العمود',
    clearCells: 'مسح المحتوى',
    deleteShape: 'حذف',
    followLink: 'فتح الرابط',
    hideSlide: 'إخفاء الشريحة',
    showSlide: 'إظهار الشريحة',
  );
}
