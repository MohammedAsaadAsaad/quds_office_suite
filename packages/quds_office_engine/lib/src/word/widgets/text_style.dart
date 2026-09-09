part of 'widgets.dart';

/// Same names as `pw.FontWeight`.
enum FontWeight { normal, bold }

/// Same names as `pw.FontStyle`.
enum FontStyle { normal, italic }

/// Same names as `pw.TextDecoration`.
class TextDecoration {
  /// TextDecoration API.
  const TextDecoration._(this._mask);

  final int _mask;

  /// none API.
  static const TextDecoration none = TextDecoration._(0);

  /// underline API.
  static const TextDecoration underline = TextDecoration._(1);

  /// lineThrough API.
  static const TextDecoration lineThrough = TextDecoration._(4);

  /// contains API.
  bool contains(TextDecoration other) => (_mask | other._mask) == _mask;
}

/// Run style. Same fields as `pw.TextStyle` that map to Word `rPr`.
class TextStyle {
  /// TextStyle API.
  const TextStyle({
    this.color,
    this.font,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.decoration,
    this.lineSpacing,
  });

  /// RRGGBB or `#RRGGBB`.
  final String? color;

  /// Word ASCII / complex-script font name.
  final String? font;

  /// fontSize API.
  final double? fontSize;

  /// fontWeight API.
  final FontWeight? fontWeight;

  /// fontStyle API.
  final FontStyle? fontStyle;

  /// decoration API.
  final TextDecoration? decoration;

  /// Extra space after the paragraph when this style is used on [Paragraph].
  final double? lineSpacing;

  /// merge API.
  TextStyle merge(TextStyle? other) {
    if (other == null) {
      return this;
    }
    return TextStyle(
      color: other.color ?? color,
      font: other.font ?? font,
      fontSize: other.fontSize ?? fontSize,
      fontWeight: other.fontWeight ?? fontWeight,
      fontStyle: other.fontStyle ?? fontStyle,
      decoration: other.decoration ?? decoration,
      lineSpacing: other.lineSpacing ?? lineSpacing,
    );
  }

  /// copyWith API.
  TextStyle copyWith({
    String? color,
    String? font,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    TextDecoration? decoration,
    double? lineSpacing,
  }) {
    return TextStyle(
      color: color ?? this.color,
      font: font ?? this.font,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      decoration: decoration ?? this.decoration,
      lineSpacing: lineSpacing ?? this.lineSpacing,
    );
  }
}

/// Inline node inside [RichText]. Same role as `pw.InlineSpan`.
sealed class InlineSpan {
  /// InlineSpan API.
  const InlineSpan();
}

/// Embedded child inside [RichText]. Same role as `pw.WidgetSpan`.
class WidgetSpan extends InlineSpan {
  /// WidgetSpan API.
  const WidgetSpan({required this.child});

  /// child API.
  final Widget child;
}

/// Text run. Same constructor as `pw.TextSpan`.
class TextSpan extends InlineSpan {
  /// TextSpan API.
  const TextSpan({this.style, this.text, this.children});

  /// style API.
  final TextStyle? style;

  /// text API.
  final String? text;

  /// children API.
  final List<InlineSpan>? children;
}
