import 'dart:typed_data';

import '../builders/office_markup.dart';

/// In-document visual: picture, chart, or SmartArt-style diagram.
enum OfficeVisualKind {
  picture,
  chartColumn,
  chartBar,
  chartPie,
  chartLine,
  diagramProcess,
  diagramCycle,
  diagramHierarchy,
}

/// Text wrapping for a Word inline / floating picture (`wp:inline` / `wp:anchor`).
enum PictureWrap {
  inline,
  square,
  tight,
  through,
  topAndBottom,
  behind,
  inFront,
}

/// Legend placement (`c:legendPos`).
enum ChartLegendPos { bottom, top, left, right, topRight }

/// Crop, tone, rotation, stroke, wrap, and effects applied to a picture.
class PictureAdjust {
  PictureAdjust({
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropRight = 0,
    this.cropBottom = 0,
    this.rotationDeg = 0,
    this.brightness = 0,
    this.contrast = 1,
    this.transparency = 0,
    this.borderColor = '',
    this.borderWidth = 0,
    this.flipH = false,
    this.flipV = false,
    this.lockAspect = true,
    this.wrap = PictureWrap.inline,
    this.wrapDistT = 0,
    this.wrapDistB = 0,
    this.wrapDistL = 9,
    this.wrapDistR = 9,
    this.altTitle = '',
    this.altDescription = '',
    this.shadow = false,
  });

  double cropLeft;
  double cropTop;
  double cropRight;
  double cropBottom;
  double rotationDeg;
  double brightness;
  double contrast;
  double transparency;
  String borderColor;
  double borderWidth;
  bool flipH;
  bool flipV;
  bool lockAspect;
  PictureWrap wrap;
  double wrapDistT;
  double wrapDistB;
  double wrapDistL;
  double wrapDistR;
  String altTitle;
  String altDescription;
  bool shadow;

  PictureAdjust copy() => PictureAdjust(
        cropLeft: cropLeft,
        cropTop: cropTop,
        cropRight: cropRight,
        cropBottom: cropBottom,
        rotationDeg: rotationDeg,
        brightness: brightness,
        contrast: contrast,
        transparency: transparency,
        borderColor: borderColor,
        borderWidth: borderWidth,
        flipH: flipH,
        flipV: flipV,
        lockAspect: lockAspect,
        wrap: wrap,
        wrapDistT: wrapDistT,
        wrapDistB: wrapDistB,
        wrapDistL: wrapDistL,
        wrapDistR: wrapDistR,
        altTitle: altTitle,
        altDescription: altDescription,
        shadow: shadow,
      );

  void reset() {
    cropLeft = 0;
    cropTop = 0;
    cropRight = 0;
    cropBottom = 0;
    rotationDeg = 0;
    brightness = 0;
    contrast = 1;
    transparency = 0;
    borderColor = '';
    borderWidth = 0;
    flipH = false;
    flipV = false;
    lockAspect = true;
    wrap = PictureWrap.inline;
    wrapDistT = 0;
    wrapDistB = 0;
    wrapDistL = 9;
    wrapDistR = 9;
    altTitle = '';
    altDescription = '';
    shadow = false;
  }
}

/// Legend, labels, axes, and titles for a chart or diagram.
class ChartDisplay {
  ChartDisplay({
    this.showLegend = true,
    this.showDataLabels = false,
    this.showAxes = true,
    this.showGridlines = true,
    this.showTitle = true,
    this.showPercent = false,
    this.legendPos = ChartLegendPos.bottom,
    this.categoryTitle = '',
    this.valueTitle = '',
    this.gapWidth = 120,
    this.firstSliceAng = 0,
    this.holeSize = 50,
  });

  bool showLegend;
  bool showDataLabels;
  bool showAxes;
  bool showGridlines;
  bool showTitle;
  bool showPercent;
  ChartLegendPos legendPos;
  String categoryTitle;
  String valueTitle;
  int gapWidth;
  int firstSliceAng;
  int holeSize;

  ChartDisplay copy() => ChartDisplay(
        showLegend: showLegend,
        showDataLabels: showDataLabels,
        showAxes: showAxes,
        showGridlines: showGridlines,
        showTitle: showTitle,
        showPercent: showPercent,
        legendPos: legendPos,
        categoryTitle: categoryTitle,
        valueTitle: valueTitle,
        gapWidth: gapWidth,
        firstSliceAng: firstSliceAng,
        holeSize: holeSize,
      );
}

abstract final class VisualPalette {
  static const List<String> fills = <String>[
    '2B579A',
    '217346',
    'B7472A',
    'ED7D31',
    '7030A0',
    '5B9BD5',
    '00B0F0',
    'C00000',
    '548235',
    '833C0C',
  ];

  static const List<String> borders = <String>[
    '',
    '2B579A',
    '217346',
    'B7472A',
    '000000',
    'C9A227',
  ];

  static String nextFill(String current) {
    final int i = fills.indexOf(current.toUpperCase());
    return fills[(i + 1) % fills.length];
  }

  static String nextBorder(String current) {
    final int i = borders.indexOf(current.toUpperCase());
    return borders[(i + 1) % borders.length];
  }
}

class OfficeVisual {
  OfficeVisual({
    required this.kind,
    this.title = '',
    List<ChartPoint>? points,
    this.imageBytes,
    this.width = 360,
    this.height = 180,
    this.offsetX = 0,
    this.offsetY = 0,
    PictureAdjust? picture,
    ChartDisplay? chart,
  })  : points = points ?? <ChartPoint>[],
        picture = picture ?? PictureAdjust(),
        chart = chart ?? ChartDisplay();

  OfficeVisualKind kind;
  String title;
  List<ChartPoint> points;
  Uint8List? imageBytes;
  double width;
  double height;
  double offsetX;
  double offsetY;
  PictureAdjust picture;
  ChartDisplay chart;

  bool get isChart =>
      kind == OfficeVisualKind.chartColumn ||
      kind == OfficeVisualKind.chartBar ||
      kind == OfficeVisualKind.chartPie ||
      kind == OfficeVisualKind.chartLine;

  bool get isDiagram =>
      kind == OfficeVisualKind.diagramProcess ||
      kind == OfficeVisualKind.diagramCycle ||
      kind == OfficeVisualKind.diagramHierarchy;

  bool get isPicture => kind == OfficeVisualKind.picture;

  OfficeVisual copy() => OfficeVisual(
        kind: kind,
        title: title,
        points: <ChartPoint>[
          for (final ChartPoint point in points)
            ChartPoint(
              label: point.label,
              value: point.value,
              color: point.color,
            ),
        ],
        imageBytes: imageBytes == null ? null : Uint8List.fromList(imageBytes!),
        width: width,
        height: height,
        offsetX: offsetX,
        offsetY: offsetY,
        picture: picture.copy(),
        chart: chart.copy(),
      );

  void restoreFrom(OfficeVisual source) {
    kind = source.kind;
    title = source.title;
    points
      ..clear()
      ..addAll(source.points);
    imageBytes = source.imageBytes == null
        ? null
        : Uint8List.fromList(source.imageBytes!);
    width = source.width;
    height = source.height;
    offsetX = source.offsetX;
    offsetY = source.offsetY;
    picture = source.picture.copy();
    chart = source.chart.copy();
  }

  void addSamplePoint({required bool arabic}) {
    final int n = points.length + 1;
    points.add(
      ChartPoint(
        label: arabic ? 'ن$n' : 'P$n',
        value: 40 + (n * 7) % 35,
        color: VisualPalette.fills[points.length % VisualPalette.fills.length],
      ),
    );
  }

  void removeLastPoint() {
    if (points.length > 1) {
      points.removeLast();
    }
  }

  void bumpPointValue(int index, double delta) {
    if (index < 0 || index >= points.length) {
      return;
    }
    final ChartPoint p = points[index];
    points[index] = p.copyWith(value: (p.value + delta).clamp(1, 200));
  }

  void cyclePointColor(int index) {
    if (index < 0 || index >= points.length) {
      return;
    }
    final ChartPoint p = points[index];
    points[index] = p.copyWith(color: VisualPalette.nextFill(p.color));
  }

  void cyclePointLabel(int index, {required bool arabic}) {
    if (index < 0 || index >= points.length) {
      return;
    }
    const List<String> en = <String>['Q1', 'Q2', 'Q3', 'Q4', 'East', 'West'];
    const List<String> ar = <String>['ر١', 'ر٢', 'ر٣', 'ر٤', 'شرق', 'غرب'];
    final List<String> labels = arabic ? ar : en;
    final ChartPoint p = points[index];
    final int i = labels.indexOf(p.label);
    points[index] = p.copyWith(label: labels[(i + 1) % labels.length]);
  }

  void cycleTitle({required bool arabic}) {
    const List<String> en = <String>['Sales', 'Revenue', 'Share', 'Trend', 'Mix'];
    const List<String> ar = <String>['مبيعات', 'إيراد', 'حصة', 'اتجاه', 'مزيج'];
    final List<String> titles = arabic ? ar : en;
    final int i = titles.indexOf(title);
    title = titles[(i + 1) % titles.length];
  }

  void cropBy(double delta) {
    final double next = (picture.cropLeft + delta).clamp(0.0, 0.4);
    picture
      ..cropLeft = next
      ..cropTop = next
      ..cropRight = next
      ..cropBottom = next;
  }

  void rotateBy(double degrees) {
    picture.rotationDeg = (picture.rotationDeg + degrees) % 360;
  }

  void bumpBrightness(double delta) {
    picture.brightness = (picture.brightness + delta).clamp(-0.5, 0.5);
  }

  void bumpContrast(double delta) {
    picture.contrast = (picture.contrast + delta).clamp(0.5, 1.8);
  }

  void cycleBorder() {
    picture.borderColor = VisualPalette.nextBorder(picture.borderColor);
    picture.borderWidth = picture.borderColor.isEmpty ? 0 : 3;
  }

  void bumpTransparency(double delta) {
    picture.transparency = (picture.transparency + delta).clamp(0.0, 0.85);
  }

  void toggleFlipH() {
    picture.flipH = !picture.flipH;
  }

  void toggleFlipV() {
    picture.flipV = !picture.flipV;
  }

  void cycleWrap() {
    const List<PictureWrap> order = PictureWrap.values;
    picture.wrap = order[(order.indexOf(picture.wrap) + 1) % order.length];
  }

  void cycleLegendPos() {
    const List<ChartLegendPos> order = ChartLegendPos.values;
    chart.legendPos = order[(order.indexOf(chart.legendPos) + 1) % order.length];
  }

  void resetPicture() {
    picture.reset();
  }

  static OfficeVisualKind nextKind(OfficeVisualKind kind) {
    const List<OfficeVisualKind> order = OfficeVisualKind.values;
    return order[(order.indexOf(kind) + 1) % order.length];
  }

  static List<ChartPoint> sampleSeries({bool arabic = false}) {
    return <ChartPoint>[
      ChartPoint(
        label: arabic ? 'ر١' : 'Q1',
        value: 42,
        color: '2B579A',
      ),
      ChartPoint(
        label: arabic ? 'ر٢' : 'Q2',
        value: 55,
        color: '217346',
      ),
      ChartPoint(
        label: arabic ? 'ر٣' : 'Q3',
        value: 38,
        color: 'B7472A',
      ),
      ChartPoint(
        label: arabic ? 'ر٤' : 'Q4',
        value: 61,
        color: 'ED7D31',
      ),
    ];
  }

  static List<ChartPoint> sampleSteps({bool arabic = false}) {
    return <ChartPoint>[
      ChartPoint(label: arabic ? 'خطّط' : 'Plan', value: 1, color: '2B579A'),
      ChartPoint(label: arabic ? 'ابنِ' : 'Build', value: 1, color: '217346'),
      ChartPoint(label: arabic ? 'راجع' : 'Review', value: 1, color: 'B7472A'),
    ];
  }
}

/// Floating drawing anchored to a worksheet cell.
class SmlDrawing {
  SmlDrawing({
    required this.visual,
    this.col = 6,
    this.row = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.sourceFromA1,
    this.sourceToA1,
  });

  OfficeVisual visual;
  int col;
  int row;
  double offsetX;
  double offsetY;
  String? sourceFromA1;
  String? sourceToA1;
}
