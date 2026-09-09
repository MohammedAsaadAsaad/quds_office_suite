part of 'widgets.dart';

/// How text is aligned in a paragraph. Same names as `pw.TextAlign`.
enum TextAlign { left, right, start, end, center, justify }

/// Reading direction. Same names as `pw.TextDirection`.
enum TextDirection { ltr, rtl }

/// Page rotation hint. Same names as `pw.PageOrientation`.
enum PageOrientation { natural, landscape, portrait }

/// Main-axis direction. Same names as `pw.Axis`.
enum Axis { horizontal, vertical }

/// How a [Flexible] child is sized. Same names as `pw.FlexFit`.
enum FlexFit { tight, loose }

/// Image fit hint. Same names as `pw.BoxFit`.
enum BoxFit { contain, cover, fill, fitWidth, fitHeight, none, scaleDown }

/// Decoration shape. Same names as `pw.BoxShape`.
enum BoxShape { rectangle, circle }

/// How children sit on a [Row] / [Column].
enum MainAxisAlignment { start, end, center, spaceBetween, spaceAround, spaceEvenly }

/// Cross-axis alignment for [Row] / [Column].
enum CrossAxisAlignment { start, end, center, stretch }

/// Page size in typographic points. Same constants as `pw.PdfPageFormat`.
class PdfPageFormat {
  /// PdfPageFormat API.
  const PdfPageFormat(
    this.width,
    this.height, {
    double marginTop = 0,
    double marginBottom = 0,
    double marginLeft = 0,
    double marginRight = 0,
    double? marginAll,
  }) : marginTop = marginAll ?? marginTop,
       marginBottom = marginAll ?? marginBottom,
       marginLeft = marginAll ?? marginLeft,
       marginRight = marginAll ?? marginRight;

  /// a3 API.
  static const PdfPageFormat a3 = PdfPageFormat(
    29.7 * cm,
    42 * cm,
    marginAll: 2.0 * cm,
  );

  /// a4 API.
  static const PdfPageFormat a4 = PdfPageFormat(
    21.0 * cm,
    29.7 * cm,
    marginAll: 2.0 * cm,
  );

  /// a5 API.
  static const PdfPageFormat a5 = PdfPageFormat(
    14.8 * cm,
    21.0 * cm,
    marginAll: 2.0 * cm,
  );

  /// letter API.
  static const PdfPageFormat letter = PdfPageFormat(
    8.5 * inch,
    11.0 * inch,
    marginAll: inch,
  );

  /// legal API.
  static const PdfPageFormat legal = PdfPageFormat(
    8.5 * inch,
    14.0 * inch,
    marginAll: inch,
  );

  /// standard API.
  static const PdfPageFormat standard = a4;

  /// point API.
  static const double point = 1;

  /// inch API.
  static const double inch = 72;

  /// cm API.
  static const double cm = inch / 2.54;

  /// mm API.
  static const double mm = inch / 25.4;

  /// width API.
  final double width;

  /// height API.
  final double height;

  /// marginTop API.
  final double marginTop;

  /// marginBottom API.
  final double marginBottom;

  /// marginLeft API.
  final double marginLeft;

  /// marginRight API.
  final double marginRight;

  /// landscape API.
  PdfPageFormat get landscape => width > height
      ? this
      : PdfPageFormat(
          height,
          width,
          marginTop: marginLeft,
          marginBottom: marginRight,
          marginLeft: marginBottom,
          marginRight: marginTop,
        );

  /// contentWidth API.
  double get contentWidth =>
      (width - marginLeft - marginRight).clamp(72, width);
}

/// Alias used in some `pw` samples (`PageFormat.a4`).
typedef PageFormat = PdfPageFormat;

/// Insets around a child. Same constructors as `pw.EdgeInsets`.
class EdgeInsets {
  /// EdgeInsets API.
  const EdgeInsets.fromLTRB(this.left, this.top, this.right, this.bottom);

  /// all API.
  const EdgeInsets.all(double value)
    : left = value,
      top = value,
      right = value,
      bottom = value;

  /// only API.
  const EdgeInsets.only({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  /// symmetric API.
  const EdgeInsets.symmetric({double vertical = 0, double horizontal = 0})
    : left = horizontal,
      right = horizontal,
      top = vertical,
      bottom = vertical;

  /// zero API.
  static const EdgeInsets zero = EdgeInsets.all(0);

  /// left API.
  final double left;

  /// top API.
  final double top;

  /// right API.
  final double right;

  /// bottom API.
  final double bottom;
}

/// 2D alignment. Same constants as `pw.Alignment`.
class Alignment {
  /// Alignment API.
  const Alignment(this.x, this.y);

  /// x API.
  final double x;

  /// y API.
  final double y;

  /// topLeft API.
  static const Alignment topLeft = Alignment(-1, 1);

  /// topCenter API.
  static const Alignment topCenter = Alignment(0, 1);

  /// topRight API.
  static const Alignment topRight = Alignment(1, 1);

  /// centerLeft API.
  static const Alignment centerLeft = Alignment(-1, 0);

  /// center API.
  static const Alignment center = Alignment(0, 0);

  /// centerRight API.
  static const Alignment centerRight = Alignment(1, 0);

  /// bottomLeft API.
  static const Alignment bottomLeft = Alignment(-1, -1);

  /// bottomCenter API.
  static const Alignment bottomCenter = Alignment(0, -1);

  /// bottomRight API.
  static const Alignment bottomRight = Alignment(1, -1);
}
