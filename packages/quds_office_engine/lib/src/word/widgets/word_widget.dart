part of 'widgets.dart';

/// Declarative Word node. Same role as `pw.Widget`.
sealed class Widget {
  /// Widget API.
  const Widget();
}

/// Build a single child (page chrome / [Page]).
typedef BuildCallback = Widget Function(Context context);

/// Build a list of children ([MultiPage]).
typedef BuildListCallback = List<Widget> Function(Context context);

/// Build one child from [Context] (`pw.Builder`).
typedef WidgetBuilder = Widget Function(Context context);

/// Build child `i` (`pw.ListView.builder`).
typedef IndexedWidgetBuilder = Widget Function(Context context, int index);

/// Translation / page-chrome context. Same fields as `pw.Context` that Word can honor.
class Context {
  /// Context API.
  Context({
    required this.theme,
    required this.pageFormat,
    this.textDirection = TextDirection.ltr,
    this.pageNumber = 1,
    this.pagesCount = 1,
  });

  /// theme API.
  final ThemeData theme;

  /// pageFormat API.
  final PdfPageFormat pageFormat;

  /// textDirection API.
  final TextDirection textDirection;

  /// Current page (Word `PAGE` field when used as chrome text).
  final int pageNumber;

  /// Total pages (Word `NUMPAGES` field when used as chrome text).
  final int pagesCount;

  /// rtl API.
  bool get rtl => textDirection == TextDirection.rtl;
}
