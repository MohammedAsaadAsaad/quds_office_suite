import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../sheet/formula/formula_eval.dart';
import '../sheet/model/sml_workbook.dart';
import '../sheet/serial/sheet_serial.dart';
import '../slide/model/pml_presentation.dart';
import '../slide/serial/slide_serial.dart';
import '../visual/sheet_chart_data.dart';
import '../word/layout/word_layout.dart';
import '../word/model/wml_document.dart';
import '../word/serial/word_deserializer.dart';
import 'office_isolate_save.dart';
import 'repair/office_repair.dart';

/// Progress while a package is decoded on a worker isolate.
class OfficeOpenProgress {
  const OfficeOpenProgress({
    required this.value,
    required this.stage,
  });

  /// 0–1.
  final double value;

  /// `archive`, `document`, `layout`, `formulas`, or `apply`.
  final String stage;
}

class WordOpenPayload {
  const WordOpenPayload({
    required this.document,
    required this.laidOut,
  });

  final WmlDocument document;
  final LaidOutDocument laidOut;
}

/// Decodes Office packages on a worker isolate so the UI isolate stays live.
abstract final class OfficeIsolateOpen {
  static bool isHeavyBytes(Uint8List bytes) =>
      bytes.length >= OfficeSaveCost.isolateThresholdBytes;

  static Future<WordOpenPayload> word(
    Uint8List bytes, {
    String? password,
    void Function(OfficeOpenProgress progress)? onProgress,
  }) async {
    final Object raw = await _open(
      bytes: bytes,
      password: password,
      kind: 'word',
      onProgress: onProgress,
    );
    if (raw is WordOpenPayload) {
      return raw;
    }
    if (raw is List && raw.length >= 2) {
      return WordOpenPayload(
        document: raw[0] as WmlDocument,
        laidOut: raw[1] as LaidOutDocument,
      );
    }
    throw StateError('Word open isolate returned an unexpected payload');
  }

  static Future<SmlWorkbook> workbook(
    Uint8List bytes, {
    String? password,
    void Function(OfficeOpenProgress progress)? onProgress,
  }) async {
    final Object raw = await _open(
      bytes: bytes,
      password: password,
      kind: 'sheet',
      onProgress: onProgress,
    );
    return raw as SmlWorkbook;
  }

  static Future<PmlPresentation> presentation(
    Uint8List bytes, {
    String? password,
    void Function(OfficeOpenProgress progress)? onProgress,
  }) async {
    final Object raw = await _open(
      bytes: bytes,
      password: password,
      kind: 'slide',
      onProgress: onProgress,
    );
    return raw as PmlPresentation;
  }

  static Future<Object> _open({
    required Uint8List bytes,
    required String? password,
    required String kind,
    void Function(OfficeOpenProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      const OfficeOpenProgress(value: 0.06, stage: 'archive'),
    );
    final ReceivePort port = ReceivePort();
    try {
      await Isolate.spawn(
        _openWorker,
        <Object?>[port.sendPort, bytes, password, kind],
      );
    } on IsolateSpawnException {
      return _openSync(bytes, password, kind, onProgress);
    } on UnsupportedError {
      return _openSync(bytes, password, kind, onProgress);
    } on ArgumentError {
      return _openSync(bytes, password, kind, onProgress);
    }

    final Completer<Object> done = Completer<Object>();
    final StreamSubscription<dynamic> sub = port.listen((Object? message) {
      if (message is! List || message.isEmpty) {
        return;
      }
      final String type = message.first as String;
      if (type == 'progress' && message.length >= 3) {
        onProgress?.call(
          OfficeOpenProgress(
            value: (message[1] as num).toDouble(),
            stage: message[2] as String,
          ),
        );
        return;
      }
      if (type == 'done' && message.length >= 2) {
        if (!done.isCompleted) {
          done.complete(message[1] as Object);
        }
        return;
      }
      if (type == 'unsendable') {
        if (!done.isCompleted) {
          done.completeError(
            ArgumentError('unsendable isolate message'),
          );
        }
        return;
      }
      if (type == 'error') {
        if (!done.isCompleted) {
          final String text =
              message.length > 1 ? '${message[1]}' : 'Open failed';
          if (text.contains('isolate message') || text.contains('unsendable')) {
            done.completeError(ArgumentError(text));
          } else {
            done.completeError(StateError(text));
          }
        }
      }
    });
    try {
      return await done.future;
    } on ArgumentError catch (error) {
      final String text = error.toString();
      if (text.contains('isolate message') || text.contains('unsendable')) {
        return _openSync(bytes, password, kind, onProgress);
      }
      rethrow;
    } finally {
      await sub.cancel();
      port.close();
    }
  }
}

Object _openSync(
  Uint8List bytes,
  String? password,
  String kind,
  void Function(OfficeOpenProgress progress)? onProgress,
) {
  onProgress?.call(const OfficeOpenProgress(value: 0.2, stage: 'archive'));
  final Object result = _decodeOpen(bytes, password, kind, (OfficeOpenProgress p) {
    onProgress?.call(p);
  });
  onProgress?.call(const OfficeOpenProgress(value: 0.96, stage: 'apply'));
  return result;
}

void _openWorker(List<Object?> args) {
  final SendPort port = args[0] as SendPort;
  final Uint8List bytes = args[1] as Uint8List;
  final String? password = args[2] as String?;
  final String kind = args[3] as String;
  try {
    final Object result = _decodeOpen(bytes, password, kind, (OfficeOpenProgress p) {
      port.send(<Object>['progress', p.value, p.stage]);
    });
    try {
      port.send(<Object>['done', result]);
    } catch (error) {
      final String text = error.toString();
      if (text.contains('isolate') || text.contains('unsendable')) {
        port.send(const <Object>['unsendable']);
      } else {
        port.send(<Object>['error', error.toString()]);
      }
    }
  } catch (error) {
    port.send(<Object>['error', error.toString()]);
  }
}

Object _decodeOpen(
  Uint8List bytes,
  String? password,
  String kind,
  void Function(OfficeOpenProgress progress) emit,
) {
  emit(const OfficeOpenProgress(value: 0.16, stage: 'archive'));
  final package = OfficeRepair.open(bytes, password: password);
  emit(const OfficeOpenProgress(value: 0.42, stage: 'document'));
  switch (kind) {
    case 'word':
      final WmlDocument document = WordDeserializer().read(package);
      emit(const OfficeOpenProgress(value: 0.72, stage: 'layout'));
      final LaidOutDocument laidOut = WordLayoutEngine(font: null).layout(document);
      emit(const OfficeOpenProgress(value: 0.92, stage: 'apply'));
      return WordOpenPayload(document: document, laidOut: laidOut);
    case 'sheet':
      final SmlWorkbook workbook = SheetDeserializer().read(package);
      emit(const OfficeOpenProgress(value: 0.72, stage: 'formulas'));
      FormulaEvaluator.recalculate(workbook);
      SheetChartData.refreshWorkbook(workbook);
      emit(const OfficeOpenProgress(value: 0.92, stage: 'apply'));
      return workbook;
    case 'slide':
      final PmlPresentation presentation = SlideDeserializer().read(package);
      emit(const OfficeOpenProgress(value: 0.92, stage: 'apply'));
      return presentation;
    default:
      throw StateError('Unknown open kind: $kind');
  }
}
