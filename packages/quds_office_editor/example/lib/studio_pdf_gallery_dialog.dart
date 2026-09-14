import 'package:flutter/material.dart';

import 'studio_pdf_gallery.dart';

/// Tabbed picker for studio PDF samples.
class PdfSampleGalleryDialog extends StatelessWidget {
  /// PdfSampleGalleryDialog API.
  const PdfSampleGalleryDialog({
    super.key,
    required this.arabic,
    required this.accent,
  });

  /// Arabic chrome.
  final bool arabic;

  /// Accent from the studio theme.
  final Color accent;

  static const List<StudioPdfSampleKind> _tabs = <StudioPdfSampleKind>[
    StudioPdfSampleKind.showcase,
    StudioPdfSampleKind.pdfWidgets,
    StudioPdfSampleKind.pdfEngine,
    StudioPdfSampleKind.officeToPdf,
  ];

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
            child: DefaultTabController(
              length: _tabs.length,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _header(context),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: accent,
                    labelColor: accent,
                    unselectedLabelColor: onSurface.withValues(alpha: 0.55),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: <Widget>[
                      for (final StudioPdfSampleKind kind in _tabs)
                        Tab(
                          text: StudioPdfGallery.kindTitle(kind, arabic),
                          icon: Icon(_icon(kind), size: 18),
                        ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        for (final StudioPdfSampleKind kind in _tabs)
                          _tabBody(
                            context,
                            kind: kind,
                            onSurface: onSurface,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
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
                      ? 'تبويبات: عرض ثنائي، أدوات، محرك، أوفيس.'
                      : 'Tabs: bilingual showcase, widgets, engine, Office.',
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

  Widget _tabBody(
    BuildContext context, {
    required StudioPdfSampleKind kind,
    required Color onSurface,
  }) {
    final List<StudioPdfSample> samples = StudioPdfGallery.all
        .where((StudioPdfSample sample) => sample.kind == kind)
        .toList(growable: false);
    return ListView(
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
            padding: const EdgeInsets.only(bottom: 8),
            child: _card(
              sample: sample,
              kind: kind,
              onSurface: onSurface,
              onTap: () => Navigator.of(context).pop(sample),
            ),
          ),
      ],
    );
  }

  Widget _card({
    required StudioPdfSample sample,
    required StudioPdfSampleKind kind,
    required Color onSurface,
    required VoidCallback onTap,
  }) {
    return Material(
      color: accent.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon(kind), color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      sample.title(arabic),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
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
      StudioPdfSampleKind.showcase => Icons.auto_awesome_rounded,
    };
  }
}
