part of 'widgets.dart';

/// Rebuilds [builder] at translate time. Same constructor as `pw.Builder`.
class Builder extends Widget {
  /// Builder API.
  const Builder({required this.builder});

  /// builder API.
  final WidgetBuilder builder;
}

/// Overrides reading direction. Same constructor as `pw.Directionality`.
class Directionality extends Widget {
  /// Directionality API.
  const Directionality({required this.textDirection, required this.child});

  /// textDirection API.
  final TextDirection textDirection;

  /// child API.
  final Widget child;
}

/// Merges [style] into the theme for [child]. Same role as `pw.DefaultTextStyle`.
class DefaultTextStyle extends Widget {
  /// DefaultTextStyle API.
  const DefaultTextStyle({required this.style, required this.child, this.textAlign});

  /// style API.
  final TextStyle style;

  /// child API.
  final Widget child;

  /// textAlign API.
  final TextAlign? textAlign;
}

/// Sets `keepTogether` on produced paragraphs. Same idea as `pw.Inseparable`.
class Inseparable extends Widget {
  /// Inseparable API.
  const Inseparable({required this.child, this.canSpan = false});

  /// child API.
  final Widget child;

  /// When false, Word keeps the block on one page.
  final bool canSpan;
}

/// Bookmark on the first produced paragraph. Same role as `pw.Anchor`.
class Anchor extends Widget {
  /// Anchor API.
  const Anchor({required this.name, this.child});

  /// name API.
  final String name;

  /// child API.
  final Widget? child;
}

/// Diagonal document stamp. Same constructors as `pw.Watermark`.
class Watermark extends Widget {
  /// Watermark API.
  const Watermark({required this.child});

  /// text API.
  Watermark.text(String text, {TextStyle? style})
    : child = Text(text, style: style);

  /// child API.
  final Widget child;
}

/// Live Word TOC. Same name as `pw.TableOfContent`.
class TableOfContent extends Widget {
  /// TableOfContent API.
  const TableOfContent({
    this.title = 'Table of Contents',
    this.minLevel = 1,
    this.maxLevel = 3,
    this.showPageNumbers = true,
  });

  /// title API.
  final String title;

  /// minLevel API.
  final int minLevel;

  /// maxLevel API.
  final int maxLevel;

  /// showPageNumbers API.
  final bool showPageNumbers;
}

/// Empty bordered box. Same role as `pw.Placeholder`.
class Placeholder extends Widget {
  /// Placeholder API.
  const Placeholder({this.fallbackWidth = 400, this.fallbackHeight = 80, this.color = '455A64'});

  /// fallbackWidth API.
  final double fallbackWidth;

  /// fallbackHeight API.
  final double fallbackHeight;

  /// RRGGBB.
  final String color;
}

/// Deterministic lorem words (stable, not random like `pw.LoremText`).
abstract final class LoremText {
  /// generate API.
  static String generate({int words = 50}) {
    const List<String> source = <String>[
      'lorem', 'ipsum', 'dolor', 'sit', 'amet', 'consectetur', 'adipiscing',
      'elit', 'sed', 'do', 'eiusmod', 'tempor', 'incididunt', 'ut', 'labore',
      'et', 'dolore', 'magna', 'aliqua', 'ut', 'enim', 'ad', 'minim', 'veniam',
      'quis', 'nostrud', 'exercitation', 'ullamco', 'laboris', 'nisi', 'aliquip',
    ];
    final int count = words < 1 ? 1 : words;
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < count; i++) {
      if (i > 0) {
        buffer.write(' ');
      }
      buffer.write(source[i % source.length]);
    }
    final String raw = buffer.toString();
    return '${raw[0].toUpperCase()}${raw.substring(1)}.';
  }
}

/// Same role as `pw.Lorem`.
class Lorem extends Widget {
  /// Lorem API.
  const Lorem({this.length = 50});

  /// Word count.
  final int length;
}

/// Checkbox mark. Word form approximation of `pw.Checkbox`.
class Checkbox extends Widget {
  /// Checkbox API.
  const Checkbox({this.value = false, this.name = '', this.tristate = false});

  /// value API.
  final bool value;

  /// name API.
  final String name;

  /// tristate API.
  final bool tristate;
}

/// Underlined value line. Word approximation of `pw.TextField`.
class TextField extends Widget {
  /// TextField API.
  const TextField({this.name = '', this.value = '', this.maxLength});

  /// name API.
  final String name;

  /// value API.
  final String value;

  /// maxLength API.
  final int? maxLength;
}

/// Filled oval frame. Same role as `pw.Circle`.
class Circle extends Widget {
  /// Circle API.
  const Circle({
    this.fillColor,
    this.strokeColor,
    this.width = 40,
    this.height = 40,
  });

  /// fillColor API.
  final String? fillColor;

  /// strokeColor API.
  final String? strokeColor;

  /// width API.
  final double width;

  /// height API.
  final double height;
}

/// Filled rectangle frame. Same role as `pw.Rectangle`.
class Rectangle extends Widget {
  /// Rectangle API.
  const Rectangle({
    this.fillColor,
    this.strokeColor,
    this.width = 80,
    this.height = 40,
  });

  /// fillColor API.
  final String? fillColor;

  /// strokeColor API.
  final String? strokeColor;

  /// width API.
  final double width;

  /// height API.
  final double height;
}

/// Absolutely placed child (`WmlFrame`). Same role as `pw.Positioned`.
class Positioned extends Widget {
  /// Positioned API.
  const Positioned({
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    required this.child,
  });

  /// left API.
  final double? left;

  /// top API.
  final double? top;

  /// right API.
  final double? right;

  /// bottom API.
  final double? bottom;

  /// width API.
  final double? width;

  /// height API.
  final double? height;

  /// child API.
  final Widget child;
}

/// Flow children, then frames for [Positioned]. Same role as `pw.Stack`.
class Stack extends Widget {
  /// Stack API.
  const Stack({this.children = const <Widget>[], this.alignment = Alignment.topLeft});

  /// children API.
  final List<Widget> children;

  /// alignment API.
  final Alignment alignment;
}

/// One column of a [Partitions] table.
class Partition extends Widget {
  /// Partition API.
  const Partition({required this.child, this.width, this.flex = 1});

  /// child API.
  final Widget child;

  /// width API.
  final double? width;

  /// flex API.
  final int flex;
}

/// Side-by-side columns as a borderless table. Same idea as `pw.Partitions`.
class Partitions extends Widget {
  /// Partitions API.
  const Partitions({this.children = const <Partition>[]});

  /// children API.
  final List<Partition> children;
}
