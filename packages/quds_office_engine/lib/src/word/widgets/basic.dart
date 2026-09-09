part of 'widgets.dart';

/// One edge of a [Border]. Same role as `pw.BorderSide`.
class BorderSide {
  /// BorderSide API.
  const BorderSide({this.color = '000000', this.width = 1});

  /// none API.
  static const BorderSide none = BorderSide(color: '', width: 0);

  /// RRGGBB.
  final String color;

  /// width API.
  final double width;
}

/// Rectangle border. Same role as `pw.Border`.
class Border {
  /// Border API.
  const Border({
    this.top = BorderSide.none,
    this.right = BorderSide.none,
    this.bottom = BorderSide.none,
    this.left = BorderSide.none,
  });

  /// all API.
  factory Border.all({String color = '000000', double width = 1}) {
    final BorderSide side = BorderSide(color: color, width: width);
    return Border(top: side, right: side, bottom: side, left: side);
  }

  /// top API.
  final BorderSide top;

  /// right API.
  final BorderSide right;

  /// bottom API.
  final BorderSide bottom;

  /// left API.
  final BorderSide left;

  /// First non-empty edge color, for Word `pBdr`.
  String? get stroke {
    for (final BorderSide side in <BorderSide>[bottom, top, left, right]) {
      if (side.color.isNotEmpty) {
        return side.color;
      }
    }
    return null;
  }
}

/// Fill + border. Same role as `pw.BoxDecoration` (no gradients).
class BoxDecoration {
  /// BoxDecoration API.
  const BoxDecoration({this.color, this.border, this.shape = BoxShape.rectangle});

  /// RRGGBB fill.
  final String? color;

  /// border API.
  final Border? border;

  /// shape API.
  final BoxShape shape;
}

/// Loose size hints. Same role as `pw.BoxConstraints`.
class BoxConstraints {
  /// BoxConstraints API.
  const BoxConstraints({
    this.minWidth = 0,
    this.maxWidth = double.infinity,
    this.minHeight = 0,
    this.maxHeight = double.infinity,
  });

  /// tightFor API.
  const BoxConstraints.tightFor({double? width, double? height})
    : minWidth = width ?? 0,
      maxWidth = width ?? double.infinity,
      minHeight = height ?? 0,
      maxHeight = height ?? double.infinity;

  /// minWidth API.
  final double minWidth;

  /// maxWidth API.
  final double maxWidth;

  /// minHeight API.
  final double minHeight;

  /// maxHeight API.
  final double maxHeight;
}

/// Shaded / bordered box. Same constructor as `pw.Container`.
class Container extends Widget {
  /// Container API.
  Container({
    this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.alignment,
    this.color,
    this.decoration,
    this.constraints,
  }) : assert(color == null || decoration == null);

  /// child API.
  final Widget? child;

  /// width API.
  final double? width;

  /// height API.
  final double? height;

  /// padding API.
  final EdgeInsets? padding;

  /// margin API.
  final EdgeInsets? margin;

  /// alignment API.
  final Alignment? alignment;

  /// RRGGBB shorthand for [BoxDecoration.color].
  final String? color;

  /// decoration API.
  final BoxDecoration? decoration;

  /// constraints API.
  final BoxConstraints? constraints;

  /// resolvedDecoration API.
  BoxDecoration? get resolvedDecoration =>
      decoration ?? (color == null ? null : BoxDecoration(color: color));
}

/// Same constructor as `pw.DecoratedBox`.
class DecoratedBox extends Widget {
  /// DecoratedBox API.
  const DecoratedBox({required this.decoration, required this.child});

  /// decoration API.
  final BoxDecoration decoration;

  /// child API.
  final Widget child;
}

/// Pass-through with optional tight size. Same role as `pw.ConstrainedBox`.
class ConstrainedBox extends Widget {
  /// ConstrainedBox API.
  const ConstrainedBox({required this.constraints, required this.child});

  /// constraints API.
  final BoxConstraints constraints;

  /// child API.
  final Widget child;
}

/// Same role as `pw.LimitedBox`.
class LimitedBox extends Widget {
  /// LimitedBox API.
  const LimitedBox({this.maxWidth = double.infinity, this.maxHeight = double.infinity, required this.child});

  /// maxWidth API.
  final double maxWidth;

  /// maxHeight API.
  final double maxHeight;

  /// child API.
  final Widget child;
}

/// Same role as `pw.AspectRatio`.
class AspectRatio extends Widget {
  /// AspectRatio API.
  const AspectRatio({required this.aspectRatio, required this.child});

  /// aspectRatio API.
  final double aspectRatio;

  /// child API.
  final Widget child;
}

/// Same role as `pw.FittedBox`.
class FittedBox extends Widget {
  /// FittedBox API.
  const FittedBox({this.fit = BoxFit.contain, required this.child});

  /// fit API.
  final BoxFit fit;

  /// child API.
  final Widget child;
}

/// Child uses the full page width (no extra indent). Same role as `pw.FullPage`.
class FullPage extends Widget {
  /// FullPage API.
  const FullPage({required this.child, this.ignoreMargins = false});

  /// child API.
  final Widget child;

  /// ignoreMargins API.
  final bool ignoreMargins;
}

/// Same role as `pw.OverflowBox`.
class OverflowBox extends Widget {
  /// OverflowBox API.
  const OverflowBox({required this.child});

  /// child API.
  final Widget child;
}

/// Word cannot layer opacity; the child is emitted unchanged.
class Opacity extends Widget {
  /// Opacity API.
  const Opacity({required this.opacity, required this.child});

  /// opacity API.
  final double opacity;

  /// child API.
  final Widget child;
}

/// Same constructor as `pw.VerticalDivider`.
class VerticalDivider extends Widget {
  /// VerticalDivider API.
  const VerticalDivider({this.width, this.thickness, this.color});

  /// width API.
  final double? width;

  /// thickness API.
  final double? thickness;

  /// RRGGBB.
  final String? color;
}
