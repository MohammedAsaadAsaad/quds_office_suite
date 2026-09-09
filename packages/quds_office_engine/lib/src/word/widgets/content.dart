part of 'widgets.dart';

/// One bullet item. Same constructor as `pw.Bullet`.
class Bullet extends Widget {
  /// Bullet API.
  Bullet({
    this.text,
    this.textAlign = TextAlign.left,
    this.style,
    this.margin = const EdgeInsets.only(bottom: 2.0 * PdfPageFormat.mm),
    this.padding,
    this.child,
  });

  /// text API.
  final String? text;

  /// textAlign API.
  final TextAlign textAlign;

  /// style API.
  final TextStyle? style;

  /// margin API.
  final EdgeInsets margin;

  /// padding API.
  final EdgeInsets? padding;

  /// Optional child instead of [text].
  final Widget? child;
}

/// Numbered list item (Word `numId` 2). `pdf/widgets` has no numbered list;
/// this is the Word equivalent of repeating `Bullet` with outline numbers.
class Numbered extends Widget {
  /// Numbered API.
  Numbered({
    this.text,
    this.textAlign = TextAlign.left,
    this.style,
    this.margin = const EdgeInsets.only(bottom: 2.0 * PdfPageFormat.mm),
    this.child,
    this.level = 0,
  });

  /// text API.
  final String? text;

  /// textAlign API.
  final TextAlign textAlign;

  /// style API.
  final TextStyle? style;

  /// margin API.
  final EdgeInsets margin;

  /// child API.
  final Widget? child;

  /// level API.
  final int level;
}

/// Three-slot chrome row. Same constructor as `pw.Footer`.
class Footer extends Widget {
  /// Footer API.
  const Footer({this.leading, this.title, this.trailing, this.margin, this.padding});

  /// leading API.
  final Widget? leading;

  /// title API.
  final Widget? title;

  /// trailing API.
  final Widget? trailing;

  /// margin API.
  final EdgeInsets? margin;

  /// padding API.
  final EdgeInsets? padding;
}
