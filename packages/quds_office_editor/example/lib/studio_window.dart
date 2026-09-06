import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop window chrome for the example host (Office-style custom frame).
class StudioWindow {
  StudioWindow._();

  static var supported = false;
  static var maximized = false;
  static var fullscreen = false;

  static bool get isDesktop {
    if (kIsWeb) {
      return false;
    }
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  }

  static Future<void> bootstrap() async {
    if (!isDesktop) {
      return;
    }
    try {
      await windowManager.ensureInitialized();
      const WindowOptions options = WindowOptions(
        size: Size(1280, 720),
        minimumSize: Size(880, 560),
        center: true,
        backgroundColor: Color(0x00000000),
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        title: 'Quds Office Studio',
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.setTitleBarStyle(
          TitleBarStyle.hidden,
          windowButtonVisibility: false,
        );
        await windowManager.setPreventClose(false);
        await windowManager.show();
        await windowManager.focus();
      });
      maximized = await windowManager.isMaximized();
      supported = true;
    } catch (_) {
      supported = false;
    }
  }

  static Future<void> setTitle(String title) async {
    if (!supported) {
      return;
    }
    try {
      await windowManager.setTitle(title);
    } catch (_) {}
  }

  static Future<void> drag() async {
    if (!supported) {
      return;
    }
    try {
      await windowManager.startDragging();
    } catch (_) {}
  }

  static Future<void> minimize() async {
    if (!supported) {
      return;
    }
    try {
      await windowManager.minimize();
    } catch (_) {}
  }

  static Future<void> toggleMaximize() async {
    if (!supported) {
      return;
    }
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
        maximized = false;
      } else {
        await windowManager.maximize();
        maximized = true;
      }
    } catch (_) {}
  }

  static Future<void> close() async {
    if (!supported) {
      return;
    }
    try {
      await windowManager.close();
    } catch (_) {}
  }

  /// OS-level fullscreen (covers the monitor, not just the app window).
  static Future<void> setFullScreen(bool value) async {
    if (!supported) {
      return;
    }
    try {
      final bool current = await windowManager.isFullScreen();
      if (current == value) {
        fullscreen = value;
        return;
      }
      await windowManager.setFullScreen(value);
      fullscreen = value;
    } catch (_) {}
  }

  static Widget wrap(Widget child) {
    if (!supported) {
      return child;
    }
    return _StudioWindowFrame(child: child);
  }
}

/// Keeps [StudioWindow.maximized] in sync with the native window.
class StudioWindowScope extends StatefulWidget {
  const StudioWindowScope({
    super.key,
    required this.child,
    required this.onChanged,
  });

  final Widget child;
  final VoidCallback onChanged;

  @override
  State<StudioWindowScope> createState() => _StudioWindowScopeState();
}

class _StudioWindowScopeState extends State<StudioWindowScope>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    if (StudioWindow.supported) {
      windowManager.addListener(this);
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
  void onWindowMaximize() {
    StudioWindow.maximized = true;
    widget.onChanged();
  }

  @override
  void onWindowUnmaximize() {
    StudioWindow.maximized = false;
    widget.onChanged();
  }

  @override
  void onWindowEnterFullScreen() {
    StudioWindow.fullscreen = true;
    widget.onChanged();
  }

  @override
  void onWindowLeaveFullScreen() {
    StudioWindow.fullscreen = false;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _StudioWindowFrame extends StatefulWidget {
  const _StudioWindowFrame({required this.child});

  final Widget child;

  @override
  State<_StudioWindowFrame> createState() => _StudioWindowFrameState();
}

class _StudioWindowFrameState extends State<_StudioWindowFrame>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowEnterFullScreen() {
    StudioWindow.fullscreen = true;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void onWindowLeaveFullScreen() {
    StudioWindow.fullscreen = false;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool locked = StudioWindow.fullscreen;
    return DragToResizeArea(
      resizeEdgeSize: locked ? 0 : 5,
      enableResizeEdges: locked ? const <ResizeEdge>[] : null,
      child: SizedBox.expand(child: widget.child),
    );
  }
}
