import 'package:flutter/services.dart';
import 'package:quds_office_engine/quds_office_engine.dart';

/// How pasted content is applied, matching Office paste options.
enum OfficePasteMode {
  /// Keep source formatting / formulas (Ctrl+V when rich data is available).
  keepSource,

  /// Apply destination character style; cell values without formulas.
  mergeFormatting,

  /// Unicode text only (Ctrl+Shift+V).
  keepTextOnly,
}

enum OfficeClipboardKind { empty, text, richText, cells, shape, visual }

class OfficeClipboardSpan {
  OfficeClipboardSpan({required this.text, required this.props});

  final String text;
  final WmlRunProps props;

  WmlRun toRun() => WmlRun(text: text, properties: props.copy());
}

class OfficeClipboardCell {
  const OfficeClipboardCell({
    this.value,
    this.formula,
    this.type = SmlCellType.string,
    this.text = '',
  });

  final Object? value;
  final String? formula;
  final SmlCellType type;
  final String text;
}

/// In-memory Office payload plus the last plain text written to the OS clipboard.
class OfficeClipboardPayload {
  OfficeClipboardPayload({
    required this.kind,
    required this.plain,
    List<List<OfficeClipboardSpan>>? paragraphs,
    List<List<OfficeClipboardCell>>? cells,
    List<WmlBlock>? wordBlocks,
    this.shape,
    this.visual,
  }) : paragraphs = paragraphs ?? <List<OfficeClipboardSpan>>[],
       cells = cells ?? <List<OfficeClipboardCell>>[],
       wordBlocks = wordBlocks ?? <WmlBlock>[];

  factory OfficeClipboardPayload.empty() => OfficeClipboardPayload(
        kind: OfficeClipboardKind.empty,
        plain: '',
      );

  factory OfficeClipboardPayload.fromPlain(String text) {
    if (text.isEmpty) {
      return OfficeClipboardPayload.empty();
    }
    return OfficeClipboardPayload(
      kind: OfficeClipboardKind.text,
      plain: text,
    );
  }

  final OfficeClipboardKind kind;
  final String plain;
  final List<List<OfficeClipboardSpan>> paragraphs;
  final List<List<OfficeClipboardCell>> cells;
  final List<WmlBlock> wordBlocks;
  final PmlShape? shape;
  final OfficeVisual? visual;

  bool get isEmpty {
    return plain.isEmpty &&
        paragraphs.every((List<OfficeClipboardSpan> p) => p.isEmpty) &&
        wordBlocks.isEmpty &&
        cells.isEmpty &&
        shape == null &&
        visual == null;
  }

  bool get hasWordBlocks => wordBlocks.isNotEmpty;

  bool get hasRichText =>
      kind == OfficeClipboardKind.richText &&
      (wordBlocks.isNotEmpty || paragraphs.isNotEmpty);

  bool get hasCells => cells.isNotEmpty;

  static List<String> splitPlainLines(String text) {
    return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  }

  static List<List<String>> parseTsv(String text) {
    final List<String> lines = splitPlainLines(text);
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return <List<String>>[
      for (final String line in lines) line.split('\t'),
    ];
  }
}

/// Process-wide clipboard: rich Office data plus optional system text.
class OfficeClipboard {
  OfficeClipboard._();

  static final OfficeClipboard instance = OfficeClipboard._();

  OfficeClipboardPayload? _local;
  var useSystem = true;

  OfficeClipboardPayload? get local => _local;

  bool get hasContent => _local != null && !_local!.isEmpty;

  Future<void> write(OfficeClipboardPayload payload) async {
    _local = payload;
    if (useSystem) {
      await Clipboard.setData(ClipboardData(text: payload.plain));
    }
  }

  void writeLocal(OfficeClipboardPayload payload) {
    _local = payload;
  }

  Future<OfficeClipboardPayload> read() async {
    var system = '';
    if (useSystem) {
      try {
        system = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
      } catch (_) {
        system = '';
      }
    }
    final OfficeClipboardPayload? local = _local;
    if (local != null && !local.isEmpty && (system.isEmpty || system == local.plain)) {
      return local;
    }
    if (system.isNotEmpty) {
      return OfficeClipboardPayload.fromPlain(system);
    }
    return local ?? OfficeClipboardPayload.empty();
  }

  void clear() {
    _local = null;
  }
}

PmlShape cloneClipboardShape(PmlShape source, {int id = 0, int nudgeEmu = 127000}) {
  return PmlShape(
    id: id == 0 ? source.id : id,
    name: source.name,
    preset: source.preset,
    transform: PmlTransform(
      x: source.transform.x + nudgeEmu,
      y: source.transform.y + nudgeEmu,
      cx: source.transform.cx,
      cy: source.transform.cy,
      rot: source.transform.rot,
    ),
    text: source.text,
    fillColor: source.fillColor,
    textColor: source.textColor,
    fontSizePt: source.fontSizePt,
    path: <PmlPathPoint>[
      for (final PmlPathPoint point in source.path)
        PmlPathPoint(point.x, point.y),
    ],
    visual: source.visual?.copy(),
    table: source.table?.copy(),
    rightToLeft: source.rightToLeft,
    textAlign: source.textAlign,
  );
}
