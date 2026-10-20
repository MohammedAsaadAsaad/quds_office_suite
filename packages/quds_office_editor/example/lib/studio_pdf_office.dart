import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

/// Runs [startPdfOfficeExport] behind a progress dialog.
///
/// Returns null when the user cancels. The open PDF is read with [readBytes]
/// after the dialog has painted, so that copy does not hide the dialog.
Future<PdfOfficeExportResult?> studioPdfOfficeDialog({
  required BuildContext context,
  required bool arabic,
  required String extension,
  required Uint8List Function() readBytes,
}) async {
  final ValueNotifier<PdfOfficeExportProgress> progress =
      ValueNotifier<PdfOfficeExportProgress>(
        const PdfOfficeExportProgress(stage: 'prepare', current: 0, total: 0),
      );
  PdfOfficeExportRun? run;
  var open = true;
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  final Future<void> dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return _PdfOfficeProgressDialog(
        arabic: arabic,
        extension: extension,
        progress: progress,
        onCancel: () {
          if (!open) {
            return;
          }
          open = false;
          run?.cancel();
          Navigator.of(dialogContext).pop();
        },
      );
    },
  );
  await WidgetsBinding.instance.endOfFrame;
  final Uint8List bytes = readBytes();
  if (bytes.isEmpty) {
    if (open) {
      open = false;
      navigator.pop();
    }
    await dialog;
    progress.dispose();
    return const PdfOfficeExportResult(error: 'empty');
  }
  if (!open) {
    await dialog;
    progress.dispose();
    return null;
  }
  run = await startPdfOfficeExport(
    bytes: bytes,
    extension: extension,
    onProgress: (PdfOfficeExportProgress update) {
      progress.value = update;
    },
  );
  final PdfOfficeExportResult result = await run.done;
  if (open) {
    open = false;
    navigator.pop();
  }
  await dialog;
  progress.dispose();
  if (result.error == 'cancelled') {
    return null;
  }
  return result;
}

class _PdfOfficeProgressDialog extends StatelessWidget {
  const _PdfOfficeProgressDialog({
    required this.arabic,
    required this.extension,
    required this.progress,
    required this.onCancel,
  });

  final bool arabic;
  final String extension;
  final ValueNotifier<PdfOfficeExportProgress> progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final String format = switch (extension) {
      'docx' => 'Word',
      'xlsx' => 'Excel',
      _ => 'PowerPoint',
    };
    return AlertDialog(
      title: Text(arabic ? 'تحويل إلى $format' : 'Converting to $format'),
      content: ValueListenableBuilder<PdfOfficeExportProgress>(
        valueListenable: progress,
        builder: (BuildContext context, PdfOfficeExportProgress step, Widget? child) {
          final bool pages = step.stage == 'page' && step.total > 0;
          return SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LinearProgressIndicator(
                  value: pages ? step.current / step.total : null,
                ),
                const SizedBox(height: 12),
                Text(_label(step, format)),
              ],
            ),
          );
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: onCancel,
          child: Text(arabic ? 'إلغاء' : 'Cancel'),
        ),
      ],
    );
  }

  String _label(PdfOfficeExportProgress step, String format) {
    return switch (step.stage) {
      'page' when step.total > 0 => arabic
          ? 'قراءة الصفحة ${step.current} من ${step.total}'
          : 'Reading page ${step.current} of ${step.total}',
      'write' => arabic ? 'كتابة $format' : 'Writing $format',
      'open' => arabic ? 'فتح الملف' : 'Opening the PDF',
      _ => arabic ? 'جارٍ التجهيز' : 'Preparing',
    };
  }
}
