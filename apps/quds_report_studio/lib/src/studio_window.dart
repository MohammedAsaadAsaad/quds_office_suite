import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Frameless desktop window: custom title bar, resize edges, caption buttons.
abstract final class StudioWindow {
  static bool _supported = false;

  /// Whether the native window is controlled by `window_manager`.
  static bool get supported => _supported;

  static bool get _desktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  /// Configures and shows the main window. Safe to call on any platform.
  static Future<void> bootstrap() async {
    if (!_desktop) {
      return;
    }
    try {
      await windowManager.ensureInitialized();
      const WindowOptions options = WindowOptions(
        size: Size(1440, 860),
        minimumSize: Size(960, 600),
        center: true,
        backgroundColor: Color(0x00000000),
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        title: 'Quds Report Studio',
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.setPreventClose(true);
        await windowManager.show();
        await windowManager.focus();
      });
      _supported = true;
    } on Object {
      _supported = false;
    }
  }

  static Future<void> _guard(Future<void> Function() action) async {
    if (!_supported) {
      return;
    }
    try {
      await action();
    } on Object {
      return;
    }
  }

  /// Updates the OS window title (task bar, alt-tab).
  static Future<void> setTitle(String title) =>
      _guard(() => windowManager.setTitle(title));

  /// Starts an OS window move from the current pointer.
  static Future<void> drag() => _guard(windowManager.startDragging);

  /// Minimizes the window.
  static Future<void> minimize() => _guard(windowManager.minimize);

  /// Maximizes or restores the window.
  static Future<void> toggleMaximize() => _guard(() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  });

  /// Asks to close; [StudioWindowScope.onCloseRequest] decides.
  static Future<void> close() => _guard(windowManager.close);

  /// Closes without asking again.
  static Future<void> destroy() => _guard(windowManager.destroy);
}

/// Tracks maximize state, adds resize edges, and routes close requests.
class StudioWindowScope extends StatefulWidget {
  const StudioWindowScope({
    super.key,
    required this.child,
    required this.onCloseRequest,
  });

  final Widget child;

  /// Returns whether the window may close (false keeps it open).
  final Future<bool> Function() onCloseRequest;

  /// Whether the window is maximized, from the closest scope.
  static bool maximizedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_WindowState>()?.maximized ??
      false;

  @override
  State<StudioWindowScope> createState() => _StudioWindowScopeState();
}

class _StudioWindowScopeState extends State<StudioWindowScope>
    with WindowListener {
  bool _maximized = false;
  bool _fullScreen = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    if (StudioWindow.supported) {
      windowManager.addListener(this);
      unawaited(_sync());
    }
  }

  Future<void> _sync() async {
    try {
      final bool maximized = await windowManager.isMaximized();
      if (mounted) {
        setState(() => _maximized = maximized);
      }
    } on Object {
      return;
    }
  }

  @override
  void dispose() {
    if (StudioWindow.supported) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  void onWindowEnterFullScreen() => setState(() => _fullScreen = true);

  @override
  void onWindowLeaveFullScreen() => setState(() => _fullScreen = false);

  @override
  Future<void> onWindowClose() async {
    if (_closing) {
      return;
    }
    _closing = true;
    try {
      if (await widget.onCloseRequest()) {
        await StudioWindow.destroy();
      }
    } finally {
      _closing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = _WindowState(
      maximized: _maximized,
      child: widget.child,
    );
    if (!StudioWindow.supported) {
      return child;
    }
    final bool locked = _maximized || _fullScreen;
    return DragToResizeArea(
      resizeEdgeSize: locked ? 0 : 6,
      enableResizeEdges: locked ? const <ResizeEdge>[] : null,
      child: child,
    );
  }
}

class _WindowState extends InheritedWidget {
  const _WindowState({required this.maximized, required super.child});

  final bool maximized;

  @override
  bool updateShouldNotify(_WindowState oldWidget) =>
      maximized != oldWidget.maximized;
}

/// Empty title-bar area that moves the window; double-click maximizes.
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key, this.child = const SizedBox.expand()});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => StudioWindow.drag(),
      onDoubleTap: StudioWindow.toggleMaximize,
      child: child,
    );
  }
}

/// Minimize / maximize / close buttons.
class WindowCaptionButtons extends StatelessWidget {
  const WindowCaptionButtons({super.key, required this.foreground});

  final Color foreground;

  @override
  Widget build(BuildContext context) {
    if (!StudioWindow.supported) {
      return const SizedBox.shrink();
    }
    final bool maximized = StudioWindowScope.maximizedOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _CaptionButton(
          icon: Icons.remove,
          tooltip: 'Minimize',
          foreground: foreground,
          onPressed: StudioWindow.minimize,
        ),
        _CaptionButton(
          icon: maximized ? Icons.filter_none : Icons.crop_square,
          tooltip: maximized ? 'Restore' : 'Maximize',
          foreground: foreground,
          onPressed: StudioWindow.toggleMaximize,
        ),
        _CaptionButton(
          icon: Icons.close,
          tooltip: 'Close',
          foreground: foreground,
          danger: true,
          onPressed: StudioWindow.close,
        ),
      ],
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.foreground,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final Color foreground;
  final VoidCallback onPressed;
  final bool danger;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color fill = !_hover
        ? Colors.transparent
        : widget.danger
        ? const Color(0xFFC42B1C)
        : widget.foreground.withValues(alpha: 0.14);
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 46,
            color: fill,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.icon == Icons.filter_none ? 13 : 16,
              color: _hover && widget.danger ? Colors.white : widget.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
