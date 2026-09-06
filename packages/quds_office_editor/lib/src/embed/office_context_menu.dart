import 'package:flutter/material.dart';
import 'package:quds_office_engine/quds_office_engine.dart';

import 'office_controller.dart';
import 'office_theme.dart';

enum OfficeContextKind {
  document,
  table,
  tableHandle,
  picture,
  comment,
  hyperlink,
  equation,
  sheetCell,
  sheetRowHeader,
  sheetColHeader,
  slideShape,
  slideCanvas,
}

class OfficeContextHit {
  const OfficeContextHit({
    required this.kind,
    required this.globalPosition,
    this.table,
    this.tableRow,
    this.tableCol,
    this.visual,
    this.commentId,
    this.link,
    this.equation,
    this.cell,
    this.shape,
  });

  final OfficeContextKind kind;
  final Offset globalPosition;
  final WmlTable? table;
  final int? tableRow;
  final int? tableCol;
  final OfficeVisual? visual;
  final int? commentId;
  final WmlHyperlink? link;
  final WmlEquation? equation;
  final SmlCellRef? cell;
  final PmlShape? shape;
}

class OfficeContextAction {
  const OfficeContextAction({
    required this.id,
    required this.label,
    this.icon,
    this.shortcut,
    this.enabled = true,
    this.danger = false,
    this.separatorBefore = false,
  });

  final String id;
  final String label;
  final IconData? icon;
  final String? shortcut;
  final bool enabled;
  final bool danger;
  final bool separatorBefore;
}

/// Overlay context menu with its own [Material] surface (Column, not a list).
abstract final class OfficeContextMenu {
  static void dismiss(OverlayEntry? entry) {
    if (entry == null || !entry.mounted) {
      return;
    }
    entry.remove();
  }

  static OverlayEntry? show({
    required BuildContext context,
    required Offset globalPosition,
    required List<OfficeContextAction> actions,
    required ValueChanged<String> onSelect,
  }) {
    if (actions.isEmpty) {
      return null;
    }
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return null;
    }
    ThemeData theme = ThemeData.light();
    try {
      theme = Theme.of(context);
    } on Object {
      theme = ThemeData.light();
    }
    final TextDirection direction =
        Directionality.maybeOf(context) ?? TextDirection.ltr;
    var closed = false;
    late final OverlayEntry entry;
    void close() {
      if (closed) {
        return;
      }
      closed = true;
      if (entry.mounted) {
        entry.remove();
      }
    }

    entry = OverlayEntry(
      builder: (BuildContext _) {
        return _OfficeContextOverlay(
          globalPosition: globalPosition,
          actions: actions,
          theme: theme,
          direction: direction,
          onDismiss: close,
          onSelect: (String id) {
            close();
            onSelect(id);
          },
        );
      },
    );
    overlay.insert(entry);
    return entry;
  }

  static List<OfficeContextAction> word({
    required OfficeContextHit hit,
    required WordEditorController controller,
  }) {
    final OfficeStrings strings = controller.config.strings;
    final bool mutate = controller.config.allowsMutation;
    final List<OfficeContextAction> items = <OfficeContextAction>[
      OfficeContextAction(
        id: 'cut',
        label: strings.cut,
        icon: Icons.content_cut,
        shortcut: 'Ctrl+X',
        enabled: mutate && controller.canCut,
      ),
      OfficeContextAction(
        id: 'copy',
        label: strings.copy,
        icon: Icons.content_copy,
        shortcut: 'Ctrl+C',
        enabled: controller.canCopy,
      ),
      OfficeContextAction(
        id: 'paste',
        label: strings.paste,
        icon: Icons.content_paste,
        shortcut: 'Ctrl+V',
        enabled: mutate && controller.canPaste,
      ),
      OfficeContextAction(
        id: 'selectAll',
        label: strings.selectAll,
        icon: Icons.select_all,
        shortcut: 'Ctrl+A',
        enabled: controller.config.allowsSelection,
        separatorBefore: true,
      ),
    ];
    if ((hit.kind == OfficeContextKind.table ||
            hit.kind == OfficeContextKind.tableHandle) &&
        hit.table != null) {
      final bool canDeleteRow = hit.table!.rows.length > 1;
      final bool canDeleteCol = WordTable.columnCount(hit.table!) > 1;
      items.addAll(<OfficeContextAction>[
        OfficeContextAction(
          id: 'insertRowAbove',
          label: strings.insertRowAbove,
          icon: Icons.keyboard_arrow_up,
          enabled: mutate,
          separatorBefore: true,
        ),
        OfficeContextAction(
          id: 'insertRowBelow',
          label: strings.insertRowBelow,
          icon: Icons.keyboard_arrow_down,
          enabled: mutate,
        ),
        OfficeContextAction(
          id: 'insertColLeft',
          label: strings.insertColumnLeft,
          icon: Icons.keyboard_arrow_left,
          enabled: mutate,
        ),
        OfficeContextAction(
          id: 'insertColRight',
          label: strings.insertColumnRight,
          icon: Icons.keyboard_arrow_right,
          enabled: mutate,
        ),
        OfficeContextAction(
          id: 'mergeTableCells',
          label: strings.mergeTableCells,
          icon: Icons.call_merge,
          enabled: mutate && controller.canMergeTableCells,
          separatorBefore: true,
        ),
        OfficeContextAction(
          id: 'unmergeTableCells',
          label: strings.unmergeTableCells,
          icon: Icons.call_split,
          enabled: mutate && controller.canUnmergeTableCells,
        ),
        OfficeContextAction(
          id: 'autoFitContents',
          label: strings.autoFitContents,
          icon: Icons.fit_screen,
          enabled: mutate,
          separatorBefore: true,
        ),
        OfficeContextAction(
          id: 'autoFitWindow',
          label: strings.autoFitWindow,
          icon: Icons.width_full,
          enabled: mutate,
        ),
        OfficeContextAction(
          id: 'autoFitFixed',
          label: strings.autoFitFixed,
          icon: Icons.view_week_outlined,
          enabled: mutate,
        ),
        OfficeContextAction(
          id: 'deleteRow',
          label: strings.deleteRow,
          icon: Icons.table_rows_outlined,
          enabled: mutate && canDeleteRow,
          danger: true,
          separatorBefore: true,
        ),
        OfficeContextAction(
          id: 'deleteCol',
          label: strings.deleteColumn,
          icon: Icons.view_column_outlined,
          enabled: mutate && canDeleteCol,
          danger: true,
        ),
        if (hit.kind == OfficeContextKind.tableHandle)
          OfficeContextAction(
            id: 'deleteTable',
            label: strings.deleteTable,
            icon: Icons.delete_outline,
            enabled: mutate,
            danger: true,
          ),
      ]);
    }
    if (hit.kind == OfficeContextKind.picture) {
      items.add(
        OfficeContextAction(
          id: 'cropPicture',
          label: strings.cropMode,
          icon: Icons.crop,
          enabled: mutate,
          separatorBefore: true,
        ),
      );
    }
    if (hit.link != null) {
      items.add(
        OfficeContextAction(
          id: 'followLink',
          label: strings.followLink,
          icon: Icons.open_in_new,
          separatorBefore: true,
        ),
      );
    }
    if (hit.kind == OfficeContextKind.comment && hit.commentId != null) {
      final WmlComment? comment =
          WordComment.byId(controller.document, hit.commentId!);
      final bool resolved = comment?.resolved ?? false;
      items.addAll(<OfficeContextAction>[
        OfficeContextAction(
          id: 'replyComment',
          label: strings.replyComment,
          icon: Icons.reply,
          enabled: mutate,
          separatorBefore: true,
        ),
        OfficeContextAction(
          id: resolved ? 'reopenComment' : 'resolveComment',
          label: resolved ? strings.reopenComment : strings.resolveComment,
          icon: resolved ? Icons.replay : Icons.task_alt,
          enabled: mutate,
        ),
        OfficeContextAction(
          id: 'deleteComment',
          label: strings.deleteComment,
          icon: Icons.delete_outline,
          enabled: mutate,
          danger: true,
        ),
      ]);
    } else if (hit.kind == OfficeContextKind.document ||
        hit.kind == OfficeContextKind.table) {
      items.add(
        OfficeContextAction(
          id: 'insertComment',
          label: strings.insertComment,
          icon: Icons.add_comment_outlined,
          enabled: mutate && !controller.isEditingComment,
          separatorBefore: true,
        ),
      );
    }
    return items;
  }

  static List<OfficeContextAction> sheet({
    required OfficeContextHit hit,
    required SheetEditorController controller,
  }) {
    final OfficeStrings strings = controller.config.strings;
    final bool mutate = controller.config.allowsMutation;
    return <OfficeContextAction>[
      OfficeContextAction(
        id: 'cut',
        label: strings.cut,
        icon: Icons.content_cut,
        shortcut: 'Ctrl+X',
        enabled: mutate && controller.canCut,
      ),
      OfficeContextAction(
        id: 'copy',
        label: strings.copy,
        icon: Icons.content_copy,
        shortcut: 'Ctrl+C',
        enabled: controller.canCopy,
      ),
      OfficeContextAction(
        id: 'paste',
        label: strings.paste,
        icon: Icons.content_paste,
        shortcut: 'Ctrl+V',
        enabled: mutate && controller.canPaste,
      ),
      OfficeContextAction(
        id: 'insertSheetRow',
        label: strings.insertSheetRow,
        icon: Icons.table_rows,
        enabled: mutate,
        separatorBefore: true,
      ),
      OfficeContextAction(
        id: 'insertSheetCol',
        label: strings.insertSheetColumn,
        icon: Icons.view_column,
        enabled: mutate,
      ),
      OfficeContextAction(
        id: 'deleteSheetRow',
        label: strings.deleteSheetRow,
        icon: Icons.table_rows_outlined,
        enabled: mutate,
        danger: true,
        separatorBefore: true,
      ),
      OfficeContextAction(
        id: 'deleteSheetCol',
        label: strings.deleteSheetColumn,
        icon: Icons.view_column_outlined,
        enabled: mutate,
        danger: true,
      ),
      OfficeContextAction(
        id: 'clearCells',
        label: strings.clearCells,
        icon: Icons.backspace_outlined,
        enabled: mutate,
        separatorBefore: true,
      ),
    ];
  }

  static List<OfficeContextAction> slide({
    required OfficeContextHit hit,
    required SlideEditorController controller,
  }) {
    final OfficeStrings strings = controller.config.strings;
    final bool mutate = controller.config.allowsMutation;
    return <OfficeContextAction>[
      OfficeContextAction(
        id: 'cut',
        label: strings.cut,
        icon: Icons.content_cut,
        shortcut: 'Ctrl+X',
        enabled: mutate && controller.canCut,
      ),
      OfficeContextAction(
        id: 'copy',
        label: strings.copy,
        icon: Icons.content_copy,
        shortcut: 'Ctrl+C',
        enabled: controller.canCopy,
      ),
      OfficeContextAction(
        id: 'paste',
        label: strings.paste,
        icon: Icons.content_paste,
        shortcut: 'Ctrl+V',
        enabled: mutate && controller.canPaste,
      ),
      if (hit.kind == OfficeContextKind.slideShape)
        OfficeContextAction(
          id: 'deleteShape',
          label: strings.deleteShape,
          icon: Icons.delete_outline,
          enabled: mutate,
          danger: true,
          separatorBefore: true,
        ),
    ];
  }

  static List<OfficeContextAction> slideSorter({
    required SlideEditorController controller,
    required int index,
  }) {
    final OfficeStrings strings = controller.config.strings;
    final bool mutate = controller.config.allowsMutation;
    final bool hidden = index >= 0 &&
        index < controller.presentation.slides.length &&
        controller.presentation.slides[index].hidden;
    return <OfficeContextAction>[
      OfficeContextAction(
        id: hidden ? 'showSlide' : 'hideSlide',
        label: hidden ? strings.showSlide : strings.hideSlide,
        icon: hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        enabled: mutate,
      ),
    ];
  }
}

class _MenuPalette {
  const _MenuPalette({
    required this.surface,
    required this.border,
    required this.hover,
    required this.text,
    required this.muted,
    required this.danger,
    required this.icon,
    required this.divider,
    required this.disabled,
  });

  factory _MenuPalette.of(ThemeData theme) {
    final bool dark = theme.brightness == Brightness.dark;
    if (dark) {
      return const _MenuPalette(
        surface: Color(0xFF2B2B2B),
        border: Color(0xFF3D3D3D),
        hover: Color(0xFF3A3A3A),
        text: Color(0xFFF3F3F3),
        muted: Color(0xFFB0B0B0),
        danger: Color(0xFFFF8A80),
        icon: Color(0xFFD0D0D0),
        divider: Color(0xFF444444),
        disabled: Color(0xFF7A7A7A),
      );
    }
    return const _MenuPalette(
      surface: Color(0xFFFFFFFF),
      border: Color(0xFFE1DFDD),
      hover: Color(0xFFE8F0FE),
      text: Color(0xFF242424),
      muted: Color(0xFF605E5C),
      danger: Color(0xFFC4314B),
      icon: Color(0xFF323130),
      divider: Color(0xFFE1DFDD),
      disabled: Color(0xFFA19F9D),
    );
  }

  final Color surface;
  final Color border;
  final Color hover;
  final Color text;
  final Color muted;
  final Color danger;
  final Color icon;
  final Color divider;
  final Color disabled;
}

class _OfficeContextOverlay extends StatelessWidget {
  const _OfficeContextOverlay({
    required this.globalPosition,
    required this.actions,
    required this.theme,
    required this.direction,
    required this.onDismiss,
    required this.onSelect,
  });

  final Offset globalPosition;
  final List<OfficeContextAction> actions;
  final ThemeData theme;
  final TextDirection direction;
  final VoidCallback onDismiss;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final _MenuPalette palette = _MenuPalette.of(theme);
    final Size screen = MediaQuery.sizeOf(context);
    const double width = 268;
    final double height = actions.fold<double>(12, (double h, OfficeContextAction a) {
      return h + (a.separatorBefore ? 9 : 0) + 36;
    });
    final double left =
        globalPosition.dx.clamp(8, (screen.width - width - 8).clamp(8, screen.width));
    final double top =
        globalPosition.dy.clamp(8, (screen.height - height - 8).clamp(8, screen.height));
    return Directionality(
      textDirection: direction,
      child: Theme(
        data: theme,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => onDismiss(),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: width,
                child: Material(
                  color: palette.surface,
                  elevation: 12,
                  shadowColor: const Color(0x40000000),
                  surfaceTintColor: const Color(0x00000000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: palette.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final OfficeContextAction action in actions) ...<Widget>[
                          if (action.separatorBefore)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ColoredBox(
                                color: palette.divider,
                                child: const SizedBox(height: 1),
                              ),
                            ),
                          _OfficeContextItem(
                            action: action,
                            palette: palette,
                            onSelect: onSelect,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficeContextItem extends StatefulWidget {
  const _OfficeContextItem({
    required this.action,
    required this.palette,
    required this.onSelect,
  });

  final OfficeContextAction action;
  final _MenuPalette palette;
  final ValueChanged<String> onSelect;

  @override
  State<_OfficeContextItem> createState() => _OfficeContextItemState();
}

class _OfficeContextItemState extends State<_OfficeContextItem> {
  var _hot = false;

  @override
  Widget build(BuildContext context) {
    final OfficeContextAction action = widget.action;
    final _MenuPalette palette = widget.palette;
    final Color fg = !action.enabled
        ? palette.disabled
        : (action.danger ? palette.danger : palette.text);
    final Color iconColor = !action.enabled
        ? palette.disabled
        : (action.danger ? palette.danger : palette.icon);
    return MouseRegion(
      onEnter: (_) {
        if (action.enabled) {
          setState(() => _hot = true);
        }
      },
      onExit: (_) => setState(() => _hot = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: action.enabled ? () => widget.onSelect(action.id) : null,
        child: ColoredBox(
          color: _hot && action.enabled ? palette.hover : const Color(0x00000000),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 28,
                  child: action.icon == null
                      ? const SizedBox.shrink()
                      : Icon(action.icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: fg,
                      height: 1.2,
                    ),
                  ),
                ),
                if (action.shortcut != null) ...<Widget>[
                  const SizedBox(width: 16),
                  Text(
                    action.shortcut!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: action.enabled ? palette.muted : palette.disabled,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
