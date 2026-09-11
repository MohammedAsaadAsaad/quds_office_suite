/// Text widgets: [Text], [RichText], [Paragraph], [Header], [Lorem].
library;

import '../../bidi/line_breaker.dart';
import 'pw_core.dart';
import 'pw_paint.dart';
import 'pw_style.dart';
import 'pw_types.dart';

/// Inline node inside [RichText].
sealed class InlineSpan {
  /// InlineSpan API.
  const InlineSpan();
}

/// Embedded child inside [RichText].
class WidgetSpan extends InlineSpan {
  /// WidgetSpan API.
  const WidgetSpan({required this.child});

  /// child API.
  final Widget child;
}

/// Text run. Same constructor as Flutter / `package:pdf` [TextSpan].
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

/// Single-run wrapped text.
class Text extends Widget {
  /// Text API.
  const Text(
    this.text, {
    this.style,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.softWrap = true,
  });

  /// text API.
  final String text;

  /// style API.
  final TextStyle? style;

  /// textAlign API.
  final TextAlign? textAlign;

  /// textDirection API.
  final TextDirection? textDirection;

  /// maxLines API.
  final int? maxLines;

  /// softWrap API.
  final bool softWrap;

  @override
  PwBox layout(Context context, BoxConstraints constraints) {
    final Context ctx = textDirection == null
        ? context
        : context.copyWith(textDirection: textDirection);
    final TextAlign align = textAlign ?? TextAlign.start;
    final double maxW = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : pwMeasureText(ctx, text, style);
    if (!softWrap) {
      final double w = pwMeasureText(ctx, text, style);
      final double h = PwResolvedStyle(ctx, style).lineHeight(ctx);
      return _TextBox(
        PwSize(
          constraints.constrainWidth(w),
          constraints.constrainHeight(h),
        ),
        text,
        style,
        align,
        maxLines,
      );
    }
    final List<BrokenLine> lines = pwWrapText(
      ctx,
      text,
      maxW,
      style,
      align: align,
    );
    final int keep = maxLines == null
        ? lines.length
        : lines.length.clamp(0, maxLines!);
    final double lh = PwResolvedStyle(ctx, style).lineHeight(ctx);
    var usedW = 0.0;
    for (int i = 0; i < keep; i++) {
      if (lines[i].width > usedW) {
        usedW = lines[i].width;
      }
    }
    return _TextBox(
      PwSize(
        constraints.constrainWidth(usedW < 1 ? maxW : usedW),
        constraints.constrainHeight(lh * (keep < 1 ? 1 : keep)),
      ),
      text,
      style,
      align,
      maxLines,
    );
  }
}

class _TextBox extends PwBox {
  _TextBox(super.size, this.text, this.style, this.align, this.maxLines);

  final String text;
  final TextStyle? style;
  final TextAlign align;
  final int? maxLines;

  @override
  void paint(Context context, PwOffset offset) {
    final List<BrokenLine> lines = pwWrapText(
      context,
      text,
      size.width,
      style,
      align: align,
    );
    final PwResolvedStyle resolved = PwResolvedStyle(context, style);
    final double lh = resolved.lineHeight(context);
    final int keep = maxLines == null
        ? lines.length
        : lines.length.clamp(0, maxLines!);
    var y = offset.dy;
    for (int i = 0; i < keep; i++) {
      pwPaintLine(
        context,
        lines[i],
        PwOffset(offset.dx, y),
        size.width,
        style,
        align,
      );
      y += lh;
    }
  }
}

/// Rich paragraph of [TextSpan] / [WidgetSpan] children.
class RichText extends Widget {
  /// RichText API.
  const RichText({
    required this.text,
    this.textAlign,
    this.textDirection,
  });

  /// text API.
  final TextSpan text;

  /// textAlign API.
  final TextAlign? textAlign;

  /// textDirection API.
  final TextDirection? textDirection;

  @override
  PwBox layout(Context context, BoxConstraints constraints) {
    final Context ctx = textDirection == null
        ? context
        : context.copyWith(textDirection: textDirection);
    final String flat = _flatten(text, ctx.theme.defaultTextStyle);
    return Text(
      flat,
      style: text.style,
      textAlign: textAlign,
      textDirection: textDirection,
    ).layout(ctx, constraints);
  }
}

String _flatten(InlineSpan span, TextStyle inherited) {
  if (span is TextSpan) {
    final StringBuffer buffer = StringBuffer(span.text ?? '');
    final List<InlineSpan>? kids = span.children;
    if (kids != null) {
      for (final InlineSpan child in kids) {
        buffer.write(_flatten(child, inherited.merge(span.style)));
      }
    }
    return buffer.toString();
  }
  return '';
}

/// Body paragraph with bottom margin.
class Paragraph extends Widget {
  /// Paragraph API.
  Paragraph({
    this.text,
    this.textAlign = TextAlign.justify,
    this.style,
    this.margin = const EdgeInsets.only(bottom: 8),
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

  @override
  PwBox layout(Context context, BoxConstraints constraints) {
    final TextStyle merged = context.theme.defaultTextStyle
        .merge(context.theme.paragraphStyle)
        .merge(style);
    final EdgeInsets pad = padding ?? EdgeInsets.zero;
    final EdgeInsets inset = EdgeInsets.fromLTRB(
      margin.left + pad.left,
      margin.top + pad.top,
      margin.right + pad.right,
      margin.bottom + pad.bottom,
    );
    final BoxConstraints inner = constraints.deflate(inset);
    final PwBox child = Text(
      text ?? '',
      style: merged,
      textAlign: textAlign,
    ).layout(context, inner);
    return ProxyBox(
      PwSize(
        constraints.constrainWidth(child.size.width + inset.horizontal),
        constraints.constrainHeight(child.size.height + inset.vertical),
      ),
      child: child,
      childOffset: PwOffset(inset.left, inset.top),
    );
  }
}

/// Heading 0–5. Registers a TOC / outline entry.
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

  @override
  PwBox layout(Context context, BoxConstraints constraints) {
    final String label = title ?? text ?? '';
    if (label.isNotEmpty) {
      context.registerHeading(level, label);
    }
    final EdgeInsets inset =
        margin ??
        EdgeInsets.only(top: level <= 1 ? 10 : 8, bottom: 6);
    final EdgeInsets pad = padding ?? EdgeInsets.zero;
    final EdgeInsets all = EdgeInsets.fromLTRB(
      inset.left + pad.left,
      inset.top + pad.top,
      inset.right + pad.right,
      inset.bottom + pad.bottom,
    );
    final Widget body =
        child ??
        Text(
          text ?? '',
          style: context.theme.headerStyle(level).merge(textStyle),
        );
    final PwBox box = body.layout(context, constraints.deflate(all));
    final BoxDecoration? deco = level <= 1
        ? const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: '90A4AE', width: 0.7),
            ),
          )
        : null;
    final double contentW = box.size.width + all.horizontal;
    final double wide = constraints.hasBoundedWidth
        ? (contentW > constraints.maxWidth ? contentW : constraints.maxWidth)
        : contentW;
    return ProxyBox(
      PwSize(
        constraints.constrainWidth(wide),
        constraints.constrainHeight(
          box.size.height + all.vertical + (deco != null ? 4 : 0),
        ),
      ),
      child: box,
      childOffset: PwOffset(all.left, all.top),
      decoration: deco,
    );
  }
}

/// Merges [style] into the theme for [child].
class DefaultTextStyle extends Widget {
  /// DefaultTextStyle API.
  const DefaultTextStyle({
    required this.style,
    required this.child,
    this.textAlign,
  });

  /// style API.
  final TextStyle style;

  /// child API.
  final Widget child;

  /// textAlign API.
  final TextAlign? textAlign;

  @override
  PwBox layout(Context context, BoxConstraints constraints) {
    return child.layout(
      context.copyWith(
        theme: context.theme.copyWith(
          defaultTextStyle: context.theme.defaultTextStyle.merge(style),
        ),
      ),
      constraints,
    );
  }
}

/// Deterministic lorem words.
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

  @override
  PwBox layout(Context context, BoxConstraints constraints) {
    return Paragraph(text: LoremText.generate(words: length)).layout(
      context,
      constraints,
    );
  }
}
