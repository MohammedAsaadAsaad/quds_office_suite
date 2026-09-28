import 'package:flutter/material.dart';

import 'studio_pdf_gallery.dart';

/// Picker for studio PDF samples. Report templates are the first category.
class PdfSampleGalleryDialog extends StatefulWidget {
  /// PdfSampleGalleryDialog API.
  const PdfSampleGalleryDialog({
    super.key,
    required this.arabic,
    required this.accent,
    this.initialKind,
    this.initialGroup,
    this.initialSampleId,
  });

  /// Arabic chrome.
  final bool arabic;

  /// Accent from the studio theme.
  final Color accent;

  /// Restore last category tab when reopening.
  final StudioPdfSampleKind? initialKind;

  /// Restore last template sub-group when [initialKind] is templates.
  final String? initialGroup;

  /// Highlight / scroll to the last opened sample.
  final String? initialSampleId;

  /// Report templates first so they are the landing list, not a hidden tab.
  static const List<StudioPdfSampleKind> categories = <StudioPdfSampleKind>[
    StudioPdfSampleKind.templates,
    StudioPdfSampleKind.showcase,
    StudioPdfSampleKind.pdfWidgets,
    StudioPdfSampleKind.pdfEngine,
    StudioPdfSampleKind.officeToPdf,
  ];

  @override
  State<PdfSampleGalleryDialog> createState() => _PdfSampleGalleryDialogState();
}

class _PdfSampleGalleryDialogState extends State<PdfSampleGalleryDialog> {
  late StudioPdfSampleKind _kind;
  late String _group;
  final GlobalKey _selectedKey = GlobalKey();

  bool get arabic => widget.arabic;

  Color get accent => widget.accent;

  String? get _selectedId => widget.initialSampleId;

  @override
  void initState() {
    super.initState();
    final StudioPdfSampleKind? kind = widget.initialKind;
    _kind = kind != null && PdfSampleGalleryDialog.categories.contains(kind)
        ? kind
        : StudioPdfSampleKind.templates;
    final String? group = widget.initialGroup;
    _group = group != null && StudioPdfGallery.templateGroups.contains(group)
        ? group
        : StudioPdfGallery.templateGroups.first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _scrollToSelected() {
    final BuildContext? target = _selectedKey.currentContext;
    if (target == null) {
      return;
    }
    Scrollable.ensureVisible(
      target,
      alignment: 0.15,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color surface = Theme.of(context).colorScheme.surface;
    final Color onSurface = Theme.of(context).colorScheme.onSurface;
    return Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
          child: Material(
            color: surface,
            elevation: 18,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _header(context),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _rail(onSurface),
                      Expanded(child: _tabBody(onSurface: onSurface)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 8, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent,
            Color.lerp(accent, const Color(0xFF1A1A1A), 0.35)!,
          ],
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  arabic ? 'معرض عينات PDF' : 'PDF sample gallery',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  arabic
                      ? 'F1 يفتح المعرض على آخر تبويب وعينة. قوالب التقارير أولاً.'
                      : 'F1 restores the last tab and sample. Templates first.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: arabic ? 'إغلاق' : 'Close',
          ),
        ],
      ),
    );
  }

  Widget _rail(Color onSurface) {
    return SizedBox(
      width: 196,
      child: Material(
        color: onSurface.withValues(alpha: 0.04),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          children: <Widget>[
            for (final StudioPdfSampleKind kind
                in PdfSampleGalleryDialog.categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _railItem(kind, onSurface),
              ),
          ],
        ),
      ),
    );
  }

  Widget _railItem(StudioPdfSampleKind kind, Color onSurface) {
    final bool selected = kind == _kind;
    return Material(
      color: selected ? accent.withValues(alpha: 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() {
          _kind = kind;
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            children: <Widget>[
              Icon(
                _icon(kind),
                size: 18,
                color: selected ? accent : onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  StudioPdfGallery.kindTitle(kind, arabic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? accent : onSurface.withValues(alpha: 0.78),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBody({required Color onSurface}) {
    final StudioPdfSampleKind kind = _kind;
    final bool templates = kind == StudioPdfSampleKind.templates;
    final List<StudioPdfSample> samples = StudioPdfGallery.all
        .where((StudioPdfSample sample) => sample.kind == kind)
        .where(
          (StudioPdfSample sample) =>
              !templates || sample.group == _group,
        )
        .toList(growable: false);
    final Widget list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: <Widget>[
        Text(
          StudioPdfGallery.kindBlurb(kind, arabic),
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: onSurface.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 12),
        for (final StudioPdfSample sample in samples)
          Padding(
            key: sample.id == _selectedId ? _selectedKey : null,
            padding: const EdgeInsets.only(bottom: 8),
            child: _card(
              sample: sample,
              onSurface: onSurface,
              selected: sample.id == _selectedId,
              onTap: () => Navigator.of(context).pop(sample),
            ),
          ),
      ],
    );
    if (!templates) {
      return list;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            children: <Widget>[
              for (final String group in StudioPdfGallery.templateGroups)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    label: Text(StudioPdfGallery.templateGroupTitle(group, arabic)),
                    selected: group == _group,
                    selectedColor: accent.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          group == _group ? FontWeight.w700 : FontWeight.w500,
                      color: group == _group ? accent : onSurface,
                    ),
                    onSelected: (_) => setState(() {
                      _group = group;
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _scrollToSelected());
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: list),
      ],
    );
  }

  Widget _card({
    required StudioPdfSample sample,
    required Color onSurface,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final StudioPdfSampleKind kind = _kind;
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.16)
          : accent.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent
                  : accent.withValues(alpha: 0.12),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: selected ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon(kind), color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            sample.title(arabic),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                          ),
                        ),
                        if (selected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              arabic ? 'مفتوح' : 'Open',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sample.blurb(arabic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                arabic
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(StudioPdfSampleKind kind) {
    return switch (kind) {
      StudioPdfSampleKind.officeToPdf => Icons.apps_rounded,
      StudioPdfSampleKind.pdfEngine => Icons.picture_as_pdf_rounded,
      StudioPdfSampleKind.pdfWidgets => Icons.widgets_rounded,
      StudioPdfSampleKind.templates => Icons.dashboard_customize_rounded,
      StudioPdfSampleKind.showcase => Icons.auto_awesome_rounded,
    };
  }
}
