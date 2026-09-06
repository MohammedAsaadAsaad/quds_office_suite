import 'package:flutter/material.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

import 'studio_window.dart';

/// Compact Office-style command used only in the example host chrome.
class StudioCmd extends StatelessWidget {
  const StudioCmd({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.foreground,
    this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Color foreground;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color color = enabled ? (selected ? accent : foreground) : Colors.grey;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 18, color: enabled ? accent : Colors.grey),
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: color),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon-only ribbon button, matching the dense Office Home toolbar.
class StudioIconCmd extends StatelessWidget {
  const StudioIconCmd({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.accent,
    this.foreground = const Color(0xFF333333),
    this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final Color accent;
  final Color foreground;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? (selected ? accent : foreground) : Colors.grey,
          ),
        ),
      ),
    );
  }
}

/// Paste button with an Office-style options menu.
class StudioPasteCmd extends StatelessWidget {
  const StudioPasteCmd({
    super.key,
    required this.accent,
    required this.foreground,
    required this.pasteLabel,
    required this.keepSourceLabel,
    required this.mergeLabel,
    required this.textOnlyLabel,
    this.onPaste,
    this.onKeepSource,
    this.onMerge,
    this.onTextOnly,
  });

  final Color accent;
  final Color foreground;
  final String pasteLabel;
  final String keepSourceLabel;
  final String mergeLabel;
  final String textOnlyLabel;
  final VoidCallback? onPaste;
  final VoidCallback? onKeepSource;
  final VoidCallback? onMerge;
  final VoidCallback? onTextOnly;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPaste != null;
    return Tooltip(
      message: '$pasteLabel (Ctrl+V)',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: onPaste,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.content_paste,
                    size: 18,
                    color: enabled ? accent : Colors.grey,
                  ),
                  Text(
                    pasteLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: enabled ? foreground : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<OfficePasteMode>(
            enabled: enabled,
            tooltip: pasteLabel,
            padding: EdgeInsets.zero,
            onSelected: (OfficePasteMode mode) {
              switch (mode) {
                case OfficePasteMode.keepSource:
                  (onKeepSource ?? onPaste)?.call();
                case OfficePasteMode.mergeFormatting:
                  (onMerge ?? onPaste)?.call();
                case OfficePasteMode.keepTextOnly:
                  (onTextOnly ?? onPaste)?.call();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<OfficePasteMode>>[
              PopupMenuItem<OfficePasteMode>(
                value: OfficePasteMode.keepSource,
                child: Text(keepSourceLabel),
              ),
              PopupMenuItem<OfficePasteMode>(
                value: OfficePasteMode.mergeFormatting,
                child: Text(mergeLabel),
              ),
              PopupMenuItem<OfficePasteMode>(
                value: OfficePasteMode.keepTextOnly,
                child: Text(textOnlyLabel),
              ),
            ],
            child: Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: enabled ? foreground : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

enum StudioFaceStyle { regular, bold, italic, boldItalic }

/// Compact ribbon combo for font family, style, or size.
class StudioCombo<T> extends StatelessWidget {
  const StudioCombo({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onSelected,
    this.width = 112,
    this.enabled = true,
    this.tooltip,
    this.previewFamily,
  });

  final T value;
  final List<T> items;
  final String Function(T value) labelOf;
  final ValueChanged<T>? onSelected;
  final double width;
  final bool enabled;
  final String? tooltip;
  final String Function(T value)? previewFamily;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? labelOf(value),
      child: PopupMenuButton<T>(
        enabled: enabled && onSelected != null,
        tooltip: '',
        padding: EdgeInsets.zero,
        onSelected: onSelected,
        itemBuilder: (BuildContext context) => <PopupMenuEntry<T>>[
          for (final T item in items)
            PopupMenuItem<T>(
              value: item,
              child: Text(
                labelOf(item),
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: previewFamily?.call(item),
                ),
              ),
            ),
        ],
        child: Container(
          width: width,
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFC6C6C6)),
            borderRadius: BorderRadius.circular(3),
            color: enabled ? const Color(0xFFFFFFFF) : const Color(0xFFF3F3F3),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  labelOf(value),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: enabled
                        ? const Color(0xFF333333)
                        : const Color(0xFF9E9E9E),
                    fontFamily: previewFamily?.call(value),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: enabled ? const Color(0xFF555555) : const Color(0xFFBDBDBD),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudioRibbonGroup extends StatelessWidget {
  const StudioRibbonGroup({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Row(children: children)),
          Text(
            title,
            style: const TextStyle(fontSize: 9, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }
}

class StudioRibbonStrip extends StatelessWidget {
  const StudioRibbonStrip({super.key, required this.groups});

  final List<StudioRibbonGroup> groups;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: <Widget>[
        for (int i = 0; i < groups.length; i++) ...<Widget>[
          groups[i],
          if (i < groups.length - 1)
            const VerticalDivider(width: 16, indent: 4, endIndent: 4),
        ],
      ],
    );
  }
}

class StudioTabChip extends StatelessWidget {
  const StudioTabChip({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? accent : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }
}

class StudioAppSwitcher extends StatelessWidget {
  const StudioAppSwitcher({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.22) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StudioPaneTitle extends StatelessWidget {
  const StudioPaneTitle({
    super.key,
    required this.text,
    required this.accent,
  });

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: accent.withValues(alpha: 0.1),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }
}

/// Office-style caption button (minimize / maximize / close).
class StudioCaptionButton extends StatelessWidget {
  const StudioCaptionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.close = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool close;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: close
              ? const Color(0xFFE81123)
              : Colors.white.withValues(alpha: 0.16),
          child: SizedBox(
            width: 46,
            height: double.infinity,
            child: Icon(icon, size: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Drag region that moves the desktop window, Office title-bar style.
class StudioDragRegion extends StatelessWidget {
  const StudioDragRegion({
    super.key,
    required this.child,
    this.onDoubleTap,
  });

  final Widget child;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) {
        StudioWindow.drag();
      },
      onDoubleTap: onDoubleTap,
      child: child,
    );
  }
}

class StudioMetaChip extends StatelessWidget {
  const StudioMetaChip({
    super.key,
    required this.label,
    required this.accent,
    this.tone,
  });

  final String label;
  final Color accent;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final Color color = tone ?? accent;
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
