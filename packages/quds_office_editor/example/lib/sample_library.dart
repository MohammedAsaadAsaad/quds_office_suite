import 'package:flutter/services.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

import 'al_tahreer_sample.dart';

/// In-memory sample documents that exercise the studio toolbars.
abstract final class SampleLibrary {
  static final Map<String, Uint8List> images = <String, Uint8List>{};

  static Future<void> preload() async {
    if (images.isNotEmpty) {
      return;
    }
    for (final String name in AlTahreerSample.imageFiles) {
      final ByteData data = await rootBundle.load('assets/al_tahreer/$name');
      images[name] = data.buffer.asUint8List();
    }
  }

  static WmlDocument wordBriefing() {
    return AlTahreerSample.build(images);
  }


  static SmlWorkbook excelBudget() {
    final SmlWorksheet budget = SmlWorksheet(name: 'Budget', sheetId: 1);
    final List<List<Object?>> rows = <List<Object?>>[
      <Object?>['Line', 'Q1', 'Q2', 'Q3', 'Q4', 'Total'],
      <Object?>['Licenses', 4200, 4200, 4500, 4500, null],
      <Object?>['Hosting', 1800, 1800, 1900, 1900, null],
      <Object?>['Design', 3200, 2100, 2800, 3000, null],
      <Object?>['Support', 5400, 5400, 5600, 5800, null],
      <Object?>['Total', null, null, null, null, null],
    ];
    for (int r = 0; r < rows.length; r++) {
      for (int c = 0; c < rows[r].length; c++) {
        final SmlCell cell = budget.cell(SmlCellRef(c, r));
        final Object? value = rows[r][c];
        if (r == 5 && c >= 1 && c <= 4) {
          cell.type = SmlCellType.formula;
          cell.formula = '=SUM(${SmlCellRef(c, 1).a1}:${SmlCellRef(c, 4).a1})';
          cell.value = cell.formula;
        } else if (c == 5 && r >= 1 && r <= 5) {
          cell.type = SmlCellType.formula;
          cell.formula = '=SUM(${SmlCellRef(1, r).a1}:${SmlCellRef(4, r).a1})';
          cell.value = cell.formula;
        } else if (value is num) {
          cell.type = SmlCellType.number;
          cell.value = value;
        } else {
          cell.type = SmlCellType.string;
          cell.value = value;
        }
      }
    }
    budget.cell(const SmlCellRef(0, 7)).value = 'Average Q1–Q4';
    budget.cell(const SmlCellRef(0, 7)).type = SmlCellType.string;
    final SmlCell avg = budget.cell(const SmlCellRef(1, 7));
    avg.type = SmlCellType.formula;
    avg.formula = '=AVERAGE(B2:E5)';
    avg.value = avg.formula;
    budget.cell(const SmlCellRef(0, 8)).value = 'Max line';
    budget.cell(const SmlCellRef(0, 8)).type = SmlCellType.string;
    final SmlCell mx = budget.cell(const SmlCellRef(1, 8));
    mx.type = SmlCellType.formula;
    mx.formula = '=MAX(F2:F5)';
    mx.value = mx.formula;

    final SmlWorksheet roster = SmlWorksheet(name: 'Roster', sheetId: 2);
    final List<List<Object?>> people = <List<Object?>>[
      <Object?>['Name', 'Role', 'Hours', 'Rate'],
      <Object?>['Lina', 'Editor', 36, 22],
      <Object?>['Karim', 'Sheets', 40, 24],
      <Object?>['Huda', 'Slides', 32, 21],
      <Object?>['Yousef', 'QA', 28, 20],
    ];
    for (int r = 0; r < people.length; r++) {
      for (int c = 0; c < people[r].length; c++) {
        final SmlCell cell = roster.cell(SmlCellRef(c, r));
        final Object? value = people[r][c];
        if (value is num) {
          cell.type = SmlCellType.number;
          cell.value = value;
        } else {
          cell.type = SmlCellType.string;
          cell.value = value;
        }
      }
    }
    budget.drawings.add(
      SmlDrawing(
        visual: OfficeVisual(
          kind: OfficeVisualKind.chartColumn,
          title: 'Budget by quarter',
          points: <ChartPoint>[
            const ChartPoint(label: 'Q1', value: 14600, color: '2B579A'),
            const ChartPoint(label: 'Q2', value: 13500, color: '217346'),
            const ChartPoint(label: 'Q3', value: 14800, color: 'B7472A'),
            const ChartPoint(label: 'Q4', value: 15200, color: 'ED7D31'),
          ],
          width: 280,
          height: 160,
        ),
        col: 0,
        row: 10,
        sourceFromA1: 'B6',
        sourceToA1: 'E6',
      ),
    );

    roster.cell(const SmlCellRef(0, 6)).value = 'Headcount';
    roster.cell(const SmlCellRef(0, 6)).type = SmlCellType.string;
    final SmlCell count = roster.cell(const SmlCellRef(1, 6));
    count.type = SmlCellType.formula;
    count.formula = '=COUNTA(A2:A5)';
    count.value = count.formula;

    final SmlWorksheet catalog = SmlWorksheet(name: 'Catalog', sheetId: 3);
    final List<List<Object?>> items = <List<Object?>>[
      <Object?>['SKU', 'Item', 'Qty', 'Price', 'Amount'],
      <Object?>['W-01', 'Word pack', 12, 9.5, null],
      <Object?>['X-02', 'Sheet pack', 8, 11, null],
      <Object?>['P-03', 'Slide pack', 15, 8.25, null],
    ];
    for (int r = 0; r < items.length; r++) {
      for (int c = 0; c < items[r].length; c++) {
        final SmlCell cell = catalog.cell(SmlCellRef(c, r));
        final Object? value = items[r][c];
        if (c == 4 && r >= 1) {
          cell.type = SmlCellType.formula;
          cell.formula = '=${SmlCellRef(2, r).a1}*${SmlCellRef(3, r).a1}';
          cell.value = cell.formula;
        } else if (value is num) {
          cell.type = SmlCellType.number;
          cell.value = value;
        } else {
          cell.type = SmlCellType.string;
          cell.value = value;
        }
      }
    }

    return SmlWorkbook(sheets: <SmlWorksheet>[budget, roster, catalog]);
  }

  static PmlPresentation slideDeck() {
    PmlShape box({
      required int id,
      required String name,
      required String text,
      required String fill,
      required int x,
      required int y,
      required int cx,
      required int cy,
    }) {
      return PmlShape(
        id: id,
        name: name,
        text: text,
        fillColor: fill,
        transform: PmlTransform(x: x, y: y, cx: cx, cy: cy),
      );
    }

    return PmlPresentation(
      slides: <PmlSlide>[
        PmlSlide(
          id: 256,
          transition: const PmlSlideTransition(kind: PmlTransitionKind.fade),
          animations: <PmlShapeAnimation>[
            PmlShapeAnimation(shapeId: 3, preset: PmlAnimPreset.fade, order: 0),
            PmlShapeAnimation(
              shapeId: 4,
              preset: PmlAnimPreset.flyIn,
              trigger: PmlAnimTrigger.afterPrevious,
              direction: PmlTransitionDir.up,
              order: 1,
            ),
          ],
          shapes: <PmlShape>[
            box(
              id: 2,
              name: 'Backdrop',
              text: '',
              fill: '2B579A',
              x: 0,
              y: 0,
              cx: 9144000,
              cy: 5143500,
            ),
            box(
              id: 3,
              name: 'Title',
              text: 'Quds Office Suite',
              fill: '2B579A',
              x: 600000,
              y: 1500000,
              cx: 8000000,
              cy: 900000,
            ),
            box(
              id: 4,
              name: 'Subtitle',
              text: 'Word · Excel · PowerPoint — full studio toolbar',
              fill: '2B579A',
              x: 600000,
              y: 2200000,
              cx: 8000000,
              cy: 500000,
            ),
            PmlShape(
              id: 5,
              name: 'Hero chart',
              fillColor: 'FFFFFF',
              transform: const PmlTransform(
                x: 2200000,
                y: 2900000,
                cx: 4800000,
                cy: 1900000,
              ),
              visual: OfficeVisual(
                kind: OfficeVisualKind.chartColumn,
                title: '',
                points: OfficeVisual.sampleSeries(),
              ),
            ),
          ],
        ),
        PmlSlide(
          id: 257,
          transition: const PmlSlideTransition(
            kind: PmlTransitionKind.push,
            direction: PmlTransitionDir.left,
          ),
          animations: <PmlShapeAnimation>[
            PmlShapeAnimation(shapeId: 2, preset: PmlAnimPreset.wipe, direction: PmlTransitionDir.left),
            PmlShapeAnimation(
              shapeId: 3,
              preset: PmlAnimPreset.peekIn,
              trigger: PmlAnimTrigger.afterPrevious,
              direction: PmlTransitionDir.left,
              order: 1,
            ),
            PmlShapeAnimation(
              shapeId: 4,
              preset: PmlAnimPreset.peekIn,
              trigger: PmlAnimTrigger.withPrevious,
              direction: PmlTransitionDir.right,
              order: 2,
            ),
            PmlShapeAnimation(
              shapeId: 5,
              preset: PmlAnimPreset.riseUp,
              trigger: PmlAnimTrigger.afterPrevious,
              order: 3,
            ),
          ],
          shapes: <PmlShape>[
            box(
              id: 2,
              name: 'Head',
              text: 'Word — document tools',
              fill: '1F4E79',
              x: 400000,
              y: 300000,
              cx: 8300000,
              cy: 700000,
            ),
            box(
              id: 3,
              name: 'Fmt',
              text: 'Home: bold italic underline color highlight size lists',
              fill: '2B579A',
              x: 400000,
              y: 1200000,
              cx: 4000000,
              cy: 1600000,
            ),
            box(
              id: 4,
              name: 'Ins',
              text: 'Insert: heading paragraph page break tables 2×2 / 3×3',
              fill: '2E75B6',
              x: 4600000,
              y: 1200000,
              cx: 4000000,
              cy: 1600000,
            ),
            box(
              id: 5,
              name: 'Rev',
              text: 'Review + View: select all / word / paragraph · rulers · zoom',
              fill: '5B9BD5',
              x: 400000,
              y: 3000000,
              cx: 8300000,
              cy: 1600000,
            ),
          ],
        ),
        PmlSlide(
          id: 258,
          transition: const PmlSlideTransition(
            kind: PmlTransitionKind.wipe,
            direction: PmlTransitionDir.up,
            durationMs: 800,
          ),
          animations: <PmlShapeAnimation>[
            PmlShapeAnimation(shapeId: 2, preset: PmlAnimPreset.fade),
            PmlShapeAnimation(
              shapeId: 3,
              preset: PmlAnimPreset.growTurn,
              trigger: PmlAnimTrigger.afterPrevious,
              order: 1,
            ),
            PmlShapeAnimation(
              shapeId: 4,
              preset: PmlAnimPreset.swivel,
              trigger: PmlAnimTrigger.afterPrevious,
              order: 2,
            ),
          ],
          shapes: <PmlShape>[
            box(
              id: 2,
              name: 'Head',
              text: 'Excel — grid tools',
              fill: '217346',
              x: 400000,
              y: 300000,
              cx: 8300000,
              cy: 700000,
            ),
            box(
              id: 3,
              name: 'Fx',
              text: 'Formulas: SUM AVERAGE MIN MAX COUNTIF · F2 · fx bar',
              fill: '548235',
              x: 400000,
              y: 1300000,
              cx: 8300000,
              cy: 1400000,
            ),
            box(
              id: 4,
              name: 'Grid',
              text: 'View: gridlines headers freeze row 1 · three sample sheets',
              fill: '70AD47',
              x: 400000,
              y: 2900000,
              cx: 8300000,
              cy: 1600000,
            ),
          ],
        ),
        PmlSlide(
          id: 259,
          transition: const PmlSlideTransition(kind: PmlTransitionKind.zoom),
          animations: <PmlShapeAnimation>[
            PmlShapeAnimation(shapeId: 2, preset: PmlAnimPreset.zoom),
            PmlShapeAnimation(
              shapeId: 3,
              preset: PmlAnimPreset.bounce,
              trigger: PmlAnimTrigger.onClick,
              order: 1,
            ),
            PmlShapeAnimation(
              shapeId: 4,
              preset: PmlAnimPreset.pulse,
              trigger: PmlAnimTrigger.withPrevious,
              order: 2,
            ),
          ],
          shapes: <PmlShape>[
            box(
              id: 2,
              name: 'Head',
              text: 'PowerPoint — stage tools',
              fill: 'B7472A',
              x: 400000,
              y: 300000,
              cx: 8300000,
              cy: 700000,
            ),
            box(
              id: 3,
              name: 'Left',
              text: 'Move a card — snap guides appear only when edges align',
              fill: 'C45911',
              x: 400000,
              y: 1300000,
              cx: 4000000,
              cy: 3000000,
            ),
            box(
              id: 4,
              name: 'Right',
              text: 'Design: fill, center, forward/back · Insert: card / title',
              fill: 'ED7D31',
              x: 4600000,
              y: 1300000,
              cx: 4000000,
              cy: 3000000,
            ),
          ],
        ),
        PmlSlide(
          id: 260,
          transition: const PmlSlideTransition(kind: PmlTransitionKind.gallery),
          animations: <PmlShapeAnimation>[
            PmlShapeAnimation(shapeId: 3, preset: PmlAnimPreset.grow),
            PmlShapeAnimation(
              shapeId: 4,
              preset: PmlAnimPreset.pathArc,
              trigger: PmlAnimTrigger.afterPrevious,
              direction: PmlTransitionDir.right,
              order: 1,
            ),
          ],
          shapes: <PmlShape>[
            box(
              id: 2,
              name: 'Head',
              text: 'Charts · pictures · diagrams',
              fill: '1F4E79',
              x: 400000,
              y: 250000,
              cx: 8300000,
              cy: 600000,
            ),
            PmlShape(
              id: 3,
              name: 'Chart',
              fillColor: 'FFFFFF',
              transform: const PmlTransform(
                x: 400000,
                y: 1000000,
                cx: 4200000,
                cy: 3600000,
              ),
              visual: OfficeVisual(
                kind: OfficeVisualKind.chartPie,
                title: 'Mix',
                points: OfficeVisual.sampleSeries(),
              ),
            ),
            PmlShape(
              id: 4,
              name: 'Flow',
              fillColor: 'FFFFFF',
              transform: const PmlTransform(
                x: 4800000,
                y: 1000000,
                cx: 3900000,
                cy: 3600000,
              ),
              visual: OfficeVisual(
                kind: OfficeVisualKind.diagramProcess,
                title: 'Ship',
                points: OfficeVisual.sampleSteps(),
              ),
            ),
          ],
        ),
        PmlSlide(
          id: 261,
          shapes: <PmlShape>[
            box(
              id: 2,
              name: 'MorphTitle',
              text: 'Morph',
              fill: '2B579A',
              x: 400000,
              y: 400000,
              cx: 3000000,
              cy: 800000,
            ),
            box(
              id: 3,
              name: 'MorphCard',
              text: 'Q1',
              fill: '5B9BD5',
              x: 500000,
              y: 1600000,
              cx: 2200000,
              cy: 2200000,
            ),
            box(
              id: 4,
              name: 'MorphNote',
              text: 'Before',
              fill: '70AD47',
              x: 3200000,
              y: 1800000,
              cx: 2400000,
              cy: 1600000,
            ),
          ],
        ),
        PmlSlide(
          id: 262,
          transition: const PmlSlideTransition(
            kind: PmlTransitionKind.morph,
            durationMs: 900,
          ),
          shapes: <PmlShape>[
            box(
              id: 2,
              name: 'MorphTitle',
              text: 'Morph',
              fill: '1F4E79',
              x: 4800000,
              y: 400000,
              cx: 3900000,
              cy: 800000,
            ),
            PmlShape(
              id: 3,
              name: 'MorphCard',
              text: 'Q4',
              fillColor: 'ED7D31',
              transform: const PmlTransform(
                x: 5600000,
                y: 1500000,
                cx: 3000000,
                cy: 2800000,
                rot: 5400000,
              ),
            ),
            box(
              id: 5,
              name: 'MorphNew',
              text: 'New',
              fill: '7030A0',
              x: 400000,
              y: 1800000,
              cx: 2000000,
              cy: 1400000,
            ),
          ],
        ),
        PmlSlide(
          id: 263,
          transition: const PmlSlideTransition(
            kind: PmlTransitionKind.fadeThroughBlack,
            durationMs: 900,
          ),
          animations: <PmlShapeAnimation>[
            PmlShapeAnimation(shapeId: 2, preset: PmlAnimPreset.floatIn, direction: PmlTransitionDir.up),
          ],
          shapes: <PmlShape>[
            box(
              id: 2,
              name: 'Close',
              text: 'شكراً — Ready to embed in any Flutter host',
              fill: '1F4E79',
              x: 800000,
              y: 1800000,
              cx: 7500000,
              cy: 1400000,
            ),
          ],
        ),
      ],
    );
  }
}
