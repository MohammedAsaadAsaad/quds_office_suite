part of 'widgets.dart';

/// Glyph from a symbol font. Same constructor as `pw.IconData`.
class IconData {
  /// IconData API.
  const IconData(this.codePoint, {this.matchTextDirection = false});

  /// codePoint API.
  final int codePoint;

  /// matchTextDirection API.
  final bool matchTextDirection;
}

/// Default icon color / size. Same role as `pw.IconThemeData`.
class IconThemeData {
  /// IconThemeData API.
  const IconThemeData({this.color, this.size = 24, this.font});

  /// fallback API.
  const IconThemeData.fallback()
    : color = '000000',
      size = 24,
      font = 'Segoe UI Symbol';

  /// RRGGBB.
  final String? color;

  /// size API.
  final double size;

  /// font API.
  final String? font;
}

/// Font glyph as a text run. Same constructor as `pw.Icon`.
class Icon extends Widget {
  /// Icon API.
  const Icon(this.icon, {this.size, this.color, this.font});

  /// icon API.
  final IconData icon;

  /// size API.
  final double? size;

  /// RRGGBB.
  final String? color;

  /// font API.
  final String? font;
}
