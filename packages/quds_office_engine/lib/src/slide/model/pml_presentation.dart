import '../../opc/opc_archive.dart';
import '../../visual/office_visual.dart';
import '../anim/pml_motion.dart';

/// Class PmlTransform.
class PmlTransform {
  /// PmlTransform API.
  const PmlTransform({
    this.x = 0,
    this.y = 0,
    this.cx = 914400,
    this.cy = 914400,
    this.rot = 0,
  });

  /// Offsets and extents in EMUs (1 pt = 12,700 EMUs).
  final int x;

  /// y API.
  final int y;

  /// cx API.
  final int cx;

  /// cy API.
  final int cy;

  /// rot API.
  final int rot;

  /// xPoints API.
  double get xPoints => x / 12700;

  /// yPoints API.
  double get yPoints => y / 12700;

  /// widthPoints API.
  double get widthPoints => cx / 12700;

  /// heightPoints API.
  double get heightPoints => cy / 12700;

  /// rotationDegrees API.
  double get rotationDegrees => rot / 60000;
}

/// Enum PmlShapePreset.
enum PmlShapePreset { rect, roundRect, ellipse, triangle, connector, freeform }

/// Enum PmlTextAlign.
enum PmlTextAlign { left, center, right, justify }

/// Class PmlTableCell.
class PmlTableCell {
  /// PmlTableCell API.
  PmlTableCell({this.text = '', this.fillColor = '', this.textColor = ''});

  /// text API.
  String text;

  /// fillColor API.
  String fillColor;

  /// textColor API.
  String textColor;

  /// copy API.
  PmlTableCell copy() =>
      PmlTableCell(text: text, fillColor: fillColor, textColor: textColor);
}

/// Class PmlTable.
class PmlTable {
  /// PmlTable API.
  PmlTable({
    List<List<PmlTableCell>>? rows,
    this.headerRow = true,
    this.rightToLeft = false,
  }) : rows = rows ?? <List<PmlTableCell>>[];

  /// rows API.
  List<List<PmlTableCell>> rows;

  /// headerRow API.
  bool headerRow;

  /// rightToLeft API.
  bool rightToLeft;

  /// rowCount API.
  int get rowCount => rows.length;

  /// colCount API.
  int get colCount {
    var max = 0;
    for (final List<PmlTableCell> row in rows) {
      if (row.length > max) {
        max = row.length;
      }
    }
    return max;
  }

  /// cellAt API.
  PmlTableCell cellAt(int row, int col) {
    while (rows.length <= row) {
      rows.add(<PmlTableCell>[]);
    }
    while (rows[row].length <= col) {
      rows[row].add(PmlTableCell());
    }
    return rows[row][col];
  }

  /// cellBounds API.
  ({double x, double y, double width, double height}) cellBounds({
    required double x,
    required double y,
    required double width,
    required double height,
    required int row,
    required int col,
  }) {
    final int rowsN = rowCount < 1 ? 1 : rowCount;
    final int colsN = colCount < 1 ? 1 : colCount;
    final double cw = width / colsN;
    final double rh = height / rowsN;
    final int visualCol = rightToLeft ? colsN - 1 - col : col;
    return (x: x + visualCol * cw, y: y + row * rh, width: cw, height: rh);
  }

  /// hitCell API.
  ({int row, int col})? hitCell({
    required double x,
    required double y,
    required double width,
    required double height,
    required double localX,
    required double localY,
  }) {
    if (rowCount <= 0 || colCount <= 0) {
      return null;
    }
    if (localX < x || localY < y || localX > x + width || localY > y + height) {
      return null;
    }
    final int row = ((localY - y) / (height / rowCount)).floor().clamp(
      0,
      rowCount - 1,
    );
    final int visualCol = ((localX - x) / (width / colCount)).floor().clamp(
      0,
      colCount - 1,
    );
    final int col = rightToLeft ? colCount - 1 - visualCol : visualCol;
    return (row: row, col: col);
  }

  /// grid API.
  static PmlTable grid({
    required int rows,
    required int cols,
    bool header = true,
    bool arabic = false,
  }) {
    final int safeRows = rows.clamp(1, 12);
    final int safeCols = cols.clamp(1, 12);
    final PmlTable table = PmlTable(headerRow: header, rightToLeft: arabic);
    for (int r = 0; r < safeRows; r++) {
      final bool isHeader = header && r == 0;
      table.rows.add(<PmlTableCell>[
        for (int c = 0; c < safeCols; c++)
          PmlTableCell(
            text: isHeader
                ? (arabic ? 'عمود ${c + 1}' : 'Column ${c + 1}')
                : (arabic
                      ? 'خلية ${r + 1}×${c + 1}'
                      : 'Cell ${r + 1}×${c + 1}'),
            fillColor: isHeader ? '2B579A' : (r.isOdd ? 'D6DCE4' : 'FFFFFF'),
            textColor: isHeader ? 'FFFFFF' : '1A1A1A',
          ),
      ]);
    }
    return table;
  }

  /// copy API.
  PmlTable copy() => PmlTable(
    headerRow: headerRow,
    rightToLeft: rightToLeft,
    rows: <List<PmlTableCell>>[
      for (final List<PmlTableCell> row in rows)
        <PmlTableCell>[for (final PmlTableCell cell in row) cell.copy()],
    ],
  );
}

/// Class PmlShape.
class PmlShape {
  /// PmlShape API.
  PmlShape({
    required this.id,
    required this.name,
    this.preset = PmlShapePreset.rect,
    this.transform = const PmlTransform(),
    this.text = '',
    this.fillColor = '4472C4',
    this.textColor = '',
    this.fontSizePt = 0,
    this.embedRelId,
    List<PmlPathPoint>? path,
    this.visual,
    this.table,
    this.rightToLeft,
    this.textAlign = PmlTextAlign.left,
  }) : path = path ?? <PmlPathPoint>[];

  /// id API.
  int id;

  /// name API.
  String name;

  /// preset API.
  PmlShapePreset preset;

  /// transform API.
  PmlTransform transform;

  /// text API.
  String text;

  /// fillColor API.
  String fillColor;

  /// textColor API.
  String textColor;

  /// fontSizePt API.
  double fontSizePt;

  /// embedRelId API.
  String? embedRelId;

  /// path API.
  List<PmlPathPoint> path;

  /// visual API.
  OfficeVisual? visual;

  /// table API.
  PmlTable? table;

  /// DrawingML `a:pPr/@rtl`. `null` auto-detects from the text.
  bool? rightToLeft;

  /// textAlign API.
  PmlTextAlign textAlign;
}

/// Class PmlPathPoint.
class PmlPathPoint {
  /// PmlPathPoint API.
  const PmlPathPoint(this.x, this.y);

  /// x API.
  final int x;

  /// y API.
  final int y;
}

/// Class PmlSlide.
class PmlSlide {
  /// PmlSlide API.
  PmlSlide({
    required this.id,
    List<PmlShape>? shapes,
    this.layoutName = 'Blank',
    this.masterName = 'Office Theme',
    this.notes = '',
    this.transition = const PmlSlideTransition(),
    List<PmlShapeAnimation>? animations,
    this.hidden = false,
  }) : shapes = shapes ?? <PmlShape>[],
       animations = animations ?? <PmlShapeAnimation>[];

  /// id API.
  int id;

  /// shapes API.
  List<PmlShape> shapes;

  /// layoutName API.
  String layoutName;

  /// masterName API.
  String masterName;

  /// notes API.
  String notes;

  /// transition API.
  PmlSlideTransition transition;

  /// animations API.
  final List<PmlShapeAnimation> animations;

  /// PowerPoint `p:sld/@show="0"` — skipped during a slide show.
  bool hidden;
}

/// Class PmlLayout.
class PmlLayout {
  /// PmlLayout API.
  PmlLayout({required this.name, this.placeholderText = ''});

  /// name API.
  String name;

  /// placeholderText API.
  String placeholderText;
}

/// Class PmlMaster.
class PmlMaster {
  /// PmlMaster API.
  PmlMaster({required this.name, this.background = 'FFFFFF'});

  /// name API.
  String name;

  /// background API.
  String background;
}

/// Class PmlPresentation.
class PmlPresentation {
  /// PmlPresentation API.
  PmlPresentation({
    List<PmlSlide>? slides,
    PmlMaster? master,
    List<PmlLayout>? layouts,
    this.package,
    this.slideWidth = 9144000,
    this.slideHeight = 5143500,
  }) : slides = slides ?? <PmlSlide>[PmlSlide(id: 256)],
       master = master ?? PmlMaster(name: 'Office Theme'),
       layouts = layouts ?? <PmlLayout>[PmlLayout(name: 'Blank')];

  /// slides API.
  List<PmlSlide> slides;

  /// master API.
  PmlMaster master;

  /// layouts API.
  List<PmlLayout> layouts;

  /// package API.
  OpcPackage? package;

  /// slideWidth API.
  int slideWidth;

  /// slideHeight API.
  int slideHeight;

  /// Cascade: slide shape → layout placeholder → master defaults.
  String resolveText(PmlShape shape, PmlSlide slide) {
    if (shape.text.isNotEmpty) {
      return shape.text;
    }
    for (final PmlLayout layout in layouts) {
      if (layout.name == slide.layoutName &&
          layout.placeholderText.isNotEmpty) {
        return layout.placeholderText;
      }
    }
    return '';
  }

  /// Next or previous slide that is not [PmlSlide.hidden], or `null`.
  int? visibleIndexAfter(int from, {int direction = 1}) {
    if (direction == 0) {
      return null;
    }
    var index = from + direction;
    while (index >= 0 && index < slides.length) {
      if (!slides[index].hidden) {
        return index;
      }
      index += direction;
    }
    return null;
  }
}
