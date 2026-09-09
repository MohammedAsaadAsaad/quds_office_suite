part of 'widgets.dart';

/// Same constructor as `pw.Padding`.
class Padding extends Widget {
  /// Padding API.
  const Padding({required this.padding, required this.child});

  /// padding API.
  final EdgeInsets padding;

  /// child API.
  final Widget child;
}

/// Same constructor as `pw.Align`.
class Align extends Widget {
  /// Align API.
  const Align({this.alignment = Alignment.center, required this.child});

  /// alignment API.
  final Alignment alignment;

  /// child API.
  final Widget child;
}

/// Same constructor as `pw.Center`.
class Center extends Align {
  /// Center API.
  const Center({required super.child}) : super(alignment: Alignment.center);
}

/// Same constructors as `pw.SizedBox`.
class SizedBox extends Widget {
  /// SizedBox API.
  const SizedBox({this.width, this.height, this.child});

  /// shrink API.
  const SizedBox.shrink({this.child}) : width = 0, height = 0;

  /// width API.
  final double? width;

  /// height API.
  final double? height;

  /// child API.
  final Widget? child;
}

/// Same constructor as `pw.Divider`.
class Divider extends Widget {
  /// Divider API.
  const Divider({this.height, this.thickness, this.color});

  /// height API.
  final double? height;

  /// thickness API.
  final double? thickness;

  /// RRGGBB.
  final String? color;
}

/// Forced page break. Same name as `pw.NewPage`.
class NewPage extends Widget {
  /// NewPage API.
  const NewPage();
}

/// Same constructor as `pw.Column`.
class Column extends Widget {
  /// Column API.
  const Column({
    this.children = const <Widget>[],
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  /// children API.
  final List<Widget> children;

  /// mainAxisAlignment API.
  final MainAxisAlignment mainAxisAlignment;

  /// crossAxisAlignment API.
  final CrossAxisAlignment crossAxisAlignment;
}

/// Horizontal row as a borderless Word table. Same constructor as `pw.Row`.
class Row extends Widget {
  /// Row API.
  const Row({
    this.children = const <Widget>[],
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  /// children API.
  final List<Widget> children;

  /// mainAxisAlignment API.
  final MainAxisAlignment mainAxisAlignment;

  /// crossAxisAlignment API.
  final CrossAxisAlignment crossAxisAlignment;
}

/// Flex child of [Row] / [Column]. Same constructor as `pw.Flexible`.
class Flexible extends Widget {
  /// Flexible API.
  const Flexible({this.flex = 1, this.fit = FlexFit.loose, required this.child});

  /// flex API.
  final int flex;

  /// fit API.
  final FlexFit fit;

  /// child API.
  final Widget child;
}

/// Same constructor as `pw.Expanded`.
class Expanded extends Flexible {
  /// Expanded API.
  const Expanded({super.flex, required super.child}) : super(fit: FlexFit.tight);
}

/// Same constructor as `pw.Spacer`.
class Spacer extends Flexible {
  /// Spacer API.
  const Spacer({super.flex}) : super(child: const SizedBox.shrink(), fit: FlexFit.tight);
}

/// Row or column from [direction]. Same role as `pw.Flex`.
class Flex extends Widget {
  /// Flex API.
  const Flex({
    required this.direction,
    this.children = const <Widget>[],
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  /// direction API.
  final Axis direction;

  /// children API.
  final List<Widget> children;

  /// mainAxisAlignment API.
  final MainAxisAlignment mainAxisAlignment;

  /// crossAxisAlignment API.
  final CrossAxisAlignment crossAxisAlignment;
}

/// Vertical list. Same constructors as `pw.ListView` (flows as a [Column]).
class ListView extends Widget {
  /// ListView API.
  const ListView({
    this.direction = Axis.vertical,
    this.reverse = false,
    this.spacing = 0,
    this.padding,
    this.children = const <Widget>[],
  }) : itemBuilder = null,
       separatorBuilder = null,
       itemCount = 0;

  /// builder API.
  const ListView.builder({
    this.direction = Axis.vertical,
    this.reverse = false,
    this.spacing = 0,
    this.padding,
    required this.itemBuilder,
    required this.itemCount,
  }) : children = const <Widget>[],
       separatorBuilder = null;

  /// separated API.
  const ListView.separated({
    this.direction = Axis.vertical,
    this.reverse = false,
    this.padding,
    required this.itemBuilder,
    required this.separatorBuilder,
    required this.itemCount,
  }) : children = const <Widget>[],
       spacing = 0;

  /// direction API.
  final Axis direction;

  /// reverse API.
  final bool reverse;

  /// spacing API.
  final double spacing;

  /// padding API.
  final EdgeInsets? padding;

  /// children API.
  final List<Widget> children;

  /// itemBuilder API.
  final IndexedWidgetBuilder? itemBuilder;

  /// separatorBuilder API.
  final IndexedWidgetBuilder? separatorBuilder;

  /// itemCount API.
  final int itemCount;
}

/// Children in document order. Word has no wrap engine; this is a [Column].
class Wrap extends Widget {
  /// Wrap API.
  const Wrap({
    this.children = const <Widget>[],
    this.spacing = 0,
    this.runSpacing = 0,
    this.direction = Axis.horizontal,
  });

  /// children API.
  final List<Widget> children;

  /// spacing API.
  final double spacing;

  /// runSpacing API.
  final double runSpacing;

  /// direction API.
  final Axis direction;
}

/// Fixed-column table. Same core fields as `pw.GridView`.
class GridView extends Widget {
  /// GridView API.
  const GridView({
    required this.crossAxisCount,
    this.children = const <Widget>[],
    this.crossAxisSpacing = 0,
    this.mainAxisSpacing = 0,
    this.padding = EdgeInsets.zero,
  });

  /// crossAxisCount API.
  final int crossAxisCount;

  /// children API.
  final List<Widget> children;

  /// crossAxisSpacing API.
  final double crossAxisSpacing;

  /// mainAxisSpacing API.
  final double mainAxisSpacing;

  /// padding API.
  final EdgeInsets padding;
}
