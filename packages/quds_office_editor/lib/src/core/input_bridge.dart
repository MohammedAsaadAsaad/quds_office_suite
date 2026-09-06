import 'package:flutter/services.dart';

/// Raw [TextInputClient] used by Word runs and sheet cells.
class OfficeInputBridge with TextInputClient {
  OfficeInputBridge({
    required this.onValue,
    this.onAction,
    this.onSelector,
  });

  final void Function(TextEditingValue value) onValue;
  final void Function(TextInputAction action)? onAction;
  final void Function(String selector)? onSelector;
  TextInputConnection? _connection;
  TextEditingValue _value = TextEditingValue.empty;
  var composing = TextRange.empty;

  TextEditingValue get value => _value;
  bool get isAttached => _connection != null;

  void attach({
    bool multiline = false,
    TextInputAction action = TextInputAction.newline,
    bool autocorrect = true,
  }) {
    detach();
    _connection = TextInput.attach(
      this,
      TextInputConfiguration(
        inputType: multiline ? TextInputType.multiline : TextInputType.text,
        inputAction: action,
        autocorrect: autocorrect,
        enableSuggestions: autocorrect,
      ),
    )..show();
    _connection!.setEditingState(_value);
  }

  void detach() {
    _connection?.close();
    _connection = null;
  }

  void setValue(TextEditingValue value) {
    _value = value;
    composing = value.composing;
    _connection?.setEditingState(_value);
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    _value = value;
    composing = value.composing;
    onValue(value);
  }

  @override
  void performAction(TextInputAction action) {
    onAction?.call(action);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void connectionClosed() {
    _connection = null;
  }

  @override
  TextEditingValue get currentTextEditingValue => _value;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void showToolbar() {}

  @override
  void performSelector(String selectorName) {
    onSelector?.call(selectorName);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void insertContent(KeyboardInsertedContent content) {}

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}
}
