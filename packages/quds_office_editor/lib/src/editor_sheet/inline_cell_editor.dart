import 'package:flutter/services.dart';

import '../core/input_bridge.dart';
import '../editor_word/caret_engine.dart';

/// Floating IME session synchronized with an in-place edit string.
class InlineCellEditor {
  InlineCellEditor({required this.onCommit, this.onChanged, this.commitOnNewline = true});

  final void Function(String text) onCommit;
  final void Function()? onChanged;
  final bool commitOnNewline;
  late final OfficeInputBridge bridge = OfficeInputBridge(
    onValue: _onValue,
    onAction: _onAction,
  );
  String formulaBar = '';
  var editing = false;
  var caretIndex = 0;
  var selectionBase = 0;

  int get selectionStart =>
      selectionBase < caretIndex ? selectionBase : caretIndex;

  int get selectionEnd =>
      selectionBase > caretIndex ? selectionBase : caretIndex;

  bool get hasSelection => selectionStart != selectionEnd;

  void begin(
    String initial, {
    int? caret,
    bool multiline = false,
  }) {
    editing = true;
    formulaBar = initial;
    caretIndex = (caret ?? initial.length).clamp(0, initial.length);
    selectionBase = caretIndex;
    bridge.setValue(
      TextEditingValue(
        text: initial,
        selection: TextSelection.collapsed(offset: caretIndex),
      ),
    );
    bridge.attach(
      multiline: multiline,
      action: multiline ? TextInputAction.newline : TextInputAction.done,
    );
    onChanged?.call();
  }

  void end() {
    if (!editing) {
      return;
    }
    editing = false;
    onCommit(formulaBar);
    bridge.detach();
  }

  void setCaret(int index, {bool extend = false}) {
    caretIndex = index.clamp(0, formulaBar.length);
    if (!extend) {
      selectionBase = caretIndex;
    }
    _syncBridge();
    onChanged?.call();
  }

  void moveCaret(int delta, {bool extend = false}) {
    setCaret(caretIndex + delta, extend: extend);
  }

  void selectAll() {
    if (!editing) {
      return;
    }
    selectionBase = 0;
    caretIndex = formulaBar.length;
    _syncBridge();
    onChanged?.call();
  }

  void selectWord(int index) {
    if (!editing) {
      return;
    }
    final ({int start, int end}) span = CaretEngine.wordBounds(
      formulaBar,
      index,
    );
    selectionBase = span.start;
    caretIndex = span.end;
    _syncBridge();
    onChanged?.call();
  }

  void selectParagraph(int index) {
    if (!editing) {
      return;
    }
    final ({int start, int end}) span = CaretEngine.paragraphBounds(
      formulaBar,
      index,
    );
    selectionBase = span.start;
    caretIndex = span.end;
    _syncBridge();
    onChanged?.call();
  }

  void deleteBackward() {
    if (!editing) {
      return;
    }
    if (hasSelection) {
      replaceRange(selectionStart, selectionEnd, '');
      return;
    }
    if (caretIndex <= 0) {
      return;
    }
    replaceRange(caretIndex - 1, caretIndex, '');
  }

  void deleteForward() {
    if (!editing) {
      return;
    }
    if (hasSelection) {
      replaceRange(selectionStart, selectionEnd, '');
      return;
    }
    if (caretIndex >= formulaBar.length) {
      return;
    }
    replaceRange(caretIndex, caretIndex + 1, '');
  }

  void replaceRange(int start, int end, String insert) {
    if (!editing) {
      return;
    }
    final int from = start.clamp(0, formulaBar.length);
    final int to = end.clamp(from, formulaBar.length);
    formulaBar = formulaBar.replaceRange(from, to, insert);
    caretIndex = from + insert.length;
    selectionBase = caretIndex;
    _syncBridge();
    onChanged?.call();
  }

  void _syncBridge() {
    bridge.setValue(
      TextEditingValue(
        text: formulaBar,
        selection: TextSelection(
          baseOffset: selectionBase.clamp(0, formulaBar.length),
          extentOffset: caretIndex.clamp(0, formulaBar.length),
        ),
      ),
    );
  }

  void _onValue(TextEditingValue value) {
    formulaBar = value.text;
    caretIndex = value.selection.extentOffset.clamp(0, formulaBar.length);
    selectionBase = value.selection.baseOffset.clamp(0, formulaBar.length);
    onChanged?.call();
  }

  void _onAction(TextInputAction action) {
    if (action == TextInputAction.done ||
        action == TextInputAction.next ||
        (action == TextInputAction.newline && commitOnNewline)) {
      end();
    }
  }
}
