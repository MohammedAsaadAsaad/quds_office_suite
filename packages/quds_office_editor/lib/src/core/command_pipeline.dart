/// Transactional undo/redo with invert-able deltas.
abstract class OfficeCommand {
  void execute();
  void undo();
  OfficeCommand invert();
}

class CommandPipeline {
  CommandPipeline({this.capacity = 200});

  final int capacity;
  final List<OfficeCommand> _undo = <OfficeCommand>[];
  final List<OfficeCommand> _redo = <OfficeCommand>[];
  final List<OfficeCommand> _batch = <OfficeCommand>[];
  final List<void Function()> _listeners = <void Function()>[];
  var _batching = false;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notify() {
    for (final void Function() listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }

  void beginBatch() {
    _batching = true;
    _batch.clear();
  }

  void endBatch() {
    _batching = false;
    if (_batch.isEmpty) {
      return;
    }
    final CompositeCommand composite =
        CompositeCommand(List<OfficeCommand>.from(_batch));
    _batch.clear();
    _undo.add(composite);
    if (_undo.length > capacity) {
      _undo.removeAt(0);
    }
    _redo.clear();
    _notify();
  }

  void commit(OfficeCommand command) {
    if (_batching) {
      _batch.add(command);
      command.execute();
      return;
    }
    command.execute();
    _undo.add(command);
    if (_undo.length > capacity) {
      _undo.removeAt(0);
    }
    _redo.clear();
    _notify();
  }

  void undo() {
    if (_undo.isEmpty) {
      return;
    }
    final OfficeCommand cmd = _undo.removeLast();
    cmd.undo();
    _redo.add(cmd);
    _notify();
  }

  void redo() {
    if (_redo.isEmpty) {
      return;
    }
    final OfficeCommand cmd = _redo.removeLast();
    cmd.execute();
    _undo.add(cmd);
    _notify();
  }
}

class CompositeCommand implements OfficeCommand {
  CompositeCommand(this.commands);

  final List<OfficeCommand> commands;

  @override
  void execute() {
    for (final OfficeCommand c in commands) {
      c.execute();
    }
  }

  @override
  void undo() {
    for (final OfficeCommand c in commands.reversed) {
      c.undo();
    }
  }

  @override
  OfficeCommand invert() =>
      CompositeCommand(commands.reversed.map((c) => c.invert()).toList());
}

class InsertTextDelta implements OfficeCommand {
  InsertTextDelta({
    required this.getText,
    required this.setText,
    required this.index,
    required this.text,
  });

  final String Function() getText;
  final void Function(String value) setText;
  final int index;
  final String text;

  @override
  void execute() {
    final String cur = getText();
    final int i = index.clamp(0, cur.length);
    setText(cur.replaceRange(i, i, text));
  }

  @override
  void undo() {
    final String cur = getText();
    final int i = index.clamp(0, cur.length);
    final int end = (i + text.length).clamp(0, cur.length);
    setText(cur.replaceRange(i, end, ''));
  }

  @override
  OfficeCommand invert() => DeleteTextDelta(
        getText: getText,
        setText: setText,
        index: index,
        length: text.length,
      );
}

class DeleteTextDelta implements OfficeCommand {
  DeleteTextDelta({
    required this.getText,
    required this.setText,
    required this.index,
    required this.length,
  });

  final String Function() getText;
  final void Function(String value) setText;
  final int index;
  final int length;
  String _deleted = '';

  @override
  void execute() {
    final String cur = getText();
    final int i = index.clamp(0, cur.length);
    final int end = (i + length).clamp(0, cur.length);
    _deleted = cur.substring(i, end);
    setText(cur.replaceRange(i, end, ''));
  }

  @override
  void undo() {
    final String cur = getText();
    final int i = index.clamp(0, cur.length);
    setText(cur.replaceRange(i, i, _deleted));
  }

  @override
  OfficeCommand invert() => InsertTextDelta(
        getText: getText,
        setText: setText,
        index: index,
        text: _deleted,
      );
}

class UpdateCellDelta implements OfficeCommand {
  UpdateCellDelta({
    required this.read,
    required this.write,
    required this.next,
  });

  final Object? Function() read;
  final void Function(Object? value) write;
  final Object? next;
  Object? _prev;

  @override
  void execute() {
    _prev = read();
    write(next);
  }

  @override
  void undo() => write(_prev);

  @override
  OfficeCommand invert() => UpdateCellDelta(read: read, write: write, next: _prev);
}

class FormatRangeDelta implements OfficeCommand {
  FormatRangeDelta({
    required this.apply,
    required this.revert,
  });

  final void Function() apply;
  final void Function() revert;

  @override
  void execute() => apply();

  @override
  void undo() => revert();

  @override
  OfficeCommand invert() =>
      FormatRangeDelta(apply: revert, revert: apply);
}

class TransformShapeDelta implements OfficeCommand {
  TransformShapeDelta({
    required this.read,
    required this.write,
    required this.next,
  });

  final List<int> Function() read;
  final void Function(List<int> v) write;
  final List<int> next;
  List<int> _prev = const <int>[];

  @override
  void execute() {
    _prev = read();
    write(next);
  }

  @override
  void undo() => write(_prev);

  @override
  OfficeCommand invert() =>
      TransformShapeDelta(read: read, write: write, next: _prev);
}
