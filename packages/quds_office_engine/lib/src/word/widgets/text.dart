part of 'widgets.dart';

/// Single-run paragraph. Same constructor as `pw.Text`.
class Text extends Widget {
  /// Text API.
  const Text(
    this.text, {
    this.style,
    this.textAlign,
    this.textDirection,
  });

  /// text API.
  final String text;

  /// style API.
  final TextStyle? style;

  /// textAlign API.
  final TextAlign? textAlign;

  /// textDirection API.
  final TextDirection? textDirection;
}

/// Rich paragraph. Same constructor as `pw.RichText`.
class RichText extends Widget {
  /// RichText API.
  const RichText({required this.text, this.textAlign, this.textDirection});

  /// text API.
  final TextSpan text;

  /// textAlign API.
  final TextAlign? textAlign;

  /// textDirection API.
  final TextDirection? textDirection;
}

/// Body paragraph. Same constructor as `pw.Paragraph`.
class Paragraph extends Widget {
  /// Paragraph API.
  Paragraph({
    this.text,
    this.textAlign = TextAlign.justify,
    this.style,
    this.margin = const EdgeInsets.only(bottom: 5.0 * PdfPageFormat.mm),
    this.padding,
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
}

/// Heading 0–5. Same constructor as `pw.Header` (not page chrome).
class Header extends Widget {
  /// Header API.
  Header({
    this.level = 1,
    this.text,
    this.child,
    this.margin,
    this.padding,
    this.textStyle,
    String? title,
  }) : assert(level >= 0 && level <= 5),
       assert(child != null || text != null),
       title = title ?? text;

  /// title API.
  final String? title;

  /// text API.
  final String? text;

  /// child API.
  final Widget? child;

  /// level API.
  final int level;

  /// margin API.
  final EdgeInsets? margin;

  /// padding API.
  final EdgeInsets? padding;

  /// textStyle API.
  final TextStyle? textStyle;
}
