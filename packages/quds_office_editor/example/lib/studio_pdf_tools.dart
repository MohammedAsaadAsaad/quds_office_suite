import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quds_office_engine/pdf_file.dart';

/// Bytes produced by the PDF tools lab, ready to open in the editor.
class PdfToolOutput {
  /// PdfToolOutput API.
  const PdfToolOutput({required this.bytes, required this.name});

  /// File bytes.
  final Uint8List bytes;

  /// Suggested file name.
  final String name;
}

/// iLovePDF-style assembly lab. Writes new files via [PdfToolbox].
class PdfToolsLabDialog extends StatefulWidget {
  /// PdfToolsLabDialog API.
  const PdfToolsLabDialog({
    super.key,
    required this.arabic,
    required this.accent,
    this.currentBytes,
    this.currentName,
  });

  /// Arabic chrome.
  final bool arabic;

  /// Accent from the studio theme.
  final Color accent;

  /// Optional bytes of the PDF already open in the editor.
  final Uint8List? currentBytes;

  /// Name of [currentBytes].
  final String? currentName;

  @override
  State<PdfToolsLabDialog> createState() => _PdfToolsLabDialogState();
}

class _Job {
  _Job({required this.name, required this.bytes, required this.pages});

  final String name;
  final Uint8List bytes;
  final int pages;
  final TextEditingController ranges = TextEditingController();

  void dispose() => ranges.dispose();
}

class _PdfToolsLabDialogState extends State<PdfToolsLabDialog> {
  final List<_Job> _jobs = <_Job>[];
  final TextEditingController _order = TextEditingController();
  final TextEditingController _at = TextEditingController(text: '1');
  final TextEditingController _chunk = TextEditingController(text: '2');
  final TextEditingController _stamp = TextEditingController(text: 'DRAFT');
  final TextEditingController _headText = TextEditingController();
  final TextEditingController _bates = TextEditingController();
  final TextEditingController _crop = TextEditingController(
    text: '18, 18, 18, 18',
  );
  int _selected = 0;
  PdfSplitKind _split = PdfSplitKind.every;
  PdfExtractMode _extractMode = PdfExtractMode.oneFile;
  int _degrees = 90;
  String? _error;
  List<PdfToolOutput> _outputs = const <PdfToolOutput>[];

  @override
  void dispose() {
    for (final _Job job in _jobs) {
      job.dispose();
    }
    _order.dispose();
    _at.dispose();
    _chunk.dispose();
    _stamp.dispose();
    _headText.dispose();
    _bates.dispose();
    _crop.dispose();
    super.dispose();
  }

  String _t(String en, String ar) => widget.arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final Color surface = Theme.of(context).colorScheme.surface;
    final Color onSurface = Theme.of(context).colorScheme.onSurface;
    return Directionality(
      textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 680),
          child: Material(
            color: surface,
            elevation: 18,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: DefaultTabController(
              length: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _header(context, onSurface),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: widget.accent,
                    labelColor: widget.accent,
                    unselectedLabelColor: onSurface.withValues(alpha: 0.55),
                    tabs: <Widget>[
                      Tab(text: _t('Merge', 'دمج')),
                      Tab(text: _t('Split', 'تقسيم')),
                      Tab(text: _t('Extract', 'استخراج')),
                      Tab(text: _t('Organize', 'ترتيب')),
                      Tab(text: _t('Rotate', 'تدوير')),
                      Tab(text: _t('Appearance', 'مظهر')),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        SizedBox(width: 250, child: _files(onSurface)),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: TabBarView(
                            children: <Widget>[
                              _mergePane(),
                              _splitPane(),
                              _extractPane(),
                              _organizePane(),
                              _rotatePane(),
                              _appearancePane(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_outputs.isNotEmpty) _results(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Color onSurface) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
      child: Row(
        children: <Widget>[
          Icon(Icons.picture_as_pdf_outlined, color: widget.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _t('PDF tools', 'أدوات PDF'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                Text(
                  _t(
                    'New files. Fonts and images stay with each page.',
                    'ملفات جديدة. الخطوط والصور تبقى مع كل صفحة.',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _t('Close', 'إغلاق'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _files(Color onSurface) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _pick,
                icon: const Icon(Icons.note_add_outlined, size: 16),
                label: Text(_t('Add PDFs', 'إضافة ملفات')),
              ),
              if (widget.currentBytes != null &&
                  widget.currentBytes!.isNotEmpty)
                TextButton(
                  onPressed: _useCurrent,
                  child: Text(_t('Use open PDF', 'الملف المفتوح')),
                ),
            ],
          ),
        ),
        Expanded(
          child: _jobs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _t(
                        'Add one or more PDFs. A semicolon separates range groups: 1-3; 8-10; 15',
                        'أضف ملفاً أو أكثر. الفاصلة المنقوطة تفصل مجموعات المدى: 1-3; 8-10; 15',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _jobs.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _Job job = _jobs[index];
                    final bool on = index == _selected;
                    return Material(
                      color: on
                          ? widget.accent.withValues(alpha: 0.1)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _selected = index),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      job.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: _t('Remove', 'إزالة'),
                                    onPressed: () => _drop(index),
                                    icon: const Icon(Icons.close, size: 16),
                                  ),
                                ],
                              ),
                              Text(
                                _t('${job.pages} pages', '${job.pages} صفحات'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: onSurface.withValues(alpha: 0.62),
                                ),
                              ),
                              TextField(
                                controller: job.ranges,
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: _t('Ranges', 'المدى'),
                                  hintText: '1-3; 8-',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _mergePane() {
    return _pad(<Widget>[
      _note(
        _t(
          'Joins files in the list order. Mix interleaves two files: A1, B1, A2, B2.',
          'يدمج الملفات بترتيب القائمة. المزج يتناوب ملفين: أ1، ب1، أ2، ب2.',
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: <Widget>[
          FilledButton(
            onPressed: _jobs.isEmpty ? null : _merge,
            child: Text(_t('Merge', 'دمج')),
          ),
          OutlinedButton(
            onPressed: _jobs.length == 2 ? _mix : null,
            child: Text(_t('Mix two', 'مزج ملفين')),
          ),
        ],
      ),
    ]);
  }

  Widget _splitPane() {
    return _pad(<Widget>[
      _note(
        _t(
          'Cuts the selected file. Bookmark split starts a file at each outline page.',
          'يقص الملف المحدد. التقسيم حسب الإشارات يبدأ ملفاً عند كل إشارة.',
        ),
      ),
      const SizedBox(height: 12),
      DropdownButton<PdfSplitKind>(
        value: _split,
        items: <DropdownMenuItem<PdfSplitKind>>[
          DropdownMenuItem(
            value: PdfSplitKind.every,
            child: Text(_t('Every N pages', 'كل عدد من الصفحات')),
          ),
          DropdownMenuItem(
            value: PdfSplitKind.burst,
            child: Text(_t('One file per page', 'ملف لكل صفحة')),
          ),
          DropdownMenuItem(
            value: PdfSplitKind.odd,
            child: Text(_t('Odd pages', 'الصفحات الفردية')),
          ),
          DropdownMenuItem(
            value: PdfSplitKind.even,
            child: Text(_t('Even pages', 'الصفحات الزوجية')),
          ),
          DropdownMenuItem(
            value: PdfSplitKind.bookmarks,
            child: Text(_t('By bookmarks', 'حسب الإشارات')),
          ),
        ],
        onChanged: (PdfSplitKind? value) {
          if (value != null) {
            setState(() => _split = value);
          }
        },
      ),
      if (_split == PdfSplitKind.every)
        SizedBox(
          width: 120,
          child: TextField(
            controller: _chunk,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t('Pages each', 'صفحات كل ملف'),
            ),
          ),
        ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _jobs.isEmpty ? null : _splitFile,
        child: Text(_t('Split selected', 'تقسيم المحدد')),
      ),
    ]);
  }

  Widget _extractPane() {
    return _pad(<Widget>[
      _note(
        _t(
          'Each file keeps its own groups. Empty means the whole file. 1-3; 8-10; 15 from one file is three groups.',
          'كل ملف يحتفظ بمجموعاته. الفراغ يعني الملف كله. 1-3; 8-10; 15 من ملف واحد هي ثلاث مجموعات.',
        ),
      ),
      const SizedBox(height: 8),
      SegmentedButton<PdfExtractMode>(
        segments: <ButtonSegment<PdfExtractMode>>[
          ButtonSegment(
            value: PdfExtractMode.oneFile,
            label: Text(_t('One file', 'ملف واحد')),
          ),
          ButtonSegment(
            value: PdfExtractMode.perRange,
            label: Text(_t('One file per range', 'ملف لكل مدى')),
          ),
        ],
        selected: <PdfExtractMode>{_extractMode},
        onSelectionChanged: (Set<PdfExtractMode> next) {
          setState(() => _extractMode = next.first);
        },
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _jobs.isEmpty ? null : _extract,
        child: Text(_t('Extract', 'استخراج')),
      ),
    ]);
  }

  Widget _organizePane() {
    return _pad(<Widget>[
      _note(
        _t(
          'Order is 1-based. Repeating a number repeats the page. Remove uses the range field of the selected file.',
          'الترتيب يبدأ من 1. تكرار الرقم يكرر الصفحة. الحذف يستخدم مدى الملف المحدد.',
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _order,
        decoration: InputDecoration(
          labelText: _t('Page order', 'ترتيب الصفحات'),
          hintText: '3, 1, 2, 2',
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          FilledButton(
            onPressed: _jobs.isEmpty ? null : _reorder,
            child: Text(_t('Apply order', 'تطبيق الترتيب')),
          ),
          OutlinedButton(
            onPressed: _jobs.isEmpty ? null : _reverse,
            child: Text(_t('Reverse', 'عكس')),
          ),
          OutlinedButton(
            onPressed: _jobs.isEmpty ? null : _remove,
            child: Text(_t('Remove ranges', 'حذف المدى')),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: <Widget>[
          SizedBox(
            width: 140,
            child: TextField(
              controller: _at,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _t('Insert at', 'إدراج عند'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _jobs.isEmpty ? null : _blank,
            child: Text(_t('Blank page', 'صفحة فارغة')),
          ),
        ],
      ),
    ]);
  }

  Widget _rotatePane() {
    return _pad(<Widget>[
      _note(
        _t(
          'A real 90° turn. A point at the top moves to the side. The page box is not rewritten into the other orientation.',
          'دوران حقيقي 90°. النقطة التي كانت في الأعلى تنتقل إلى الجانب. صندوق الصفحة لا يُعاد كتابته ليصبح بالاتجاه الآخر.',
        ),
      ),
      const SizedBox(height: 8),
      SegmentedButton<int>(
        segments: <ButtonSegment<int>>[
          ButtonSegment(value: -90, label: Text(_t('90° left', '90° يساراً'))),
          ButtonSegment(value: 90, label: Text(_t('90° right', '90° يميناً'))),
          ButtonSegment(value: 180, label: Text('180°')),
        ],
        selected: <int>{_degrees},
        onSelectionChanged: (Set<int> next) {
          setState(() => _degrees = next.first);
        },
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _jobs.isEmpty ? null : _rotate,
        child: Text(_t('Rotate selected', 'تدوير المحدد')),
      ),
    ]);
  }

  Widget _appearancePane() {
    return _pad(<Widget>[
      _note(
        _t(
          'Overlay uses Helvetica and an opacity flag. It does not reshape Arabic, embed a font, or rewrite the page content. Crop only shrinks CropBox.',
          'الطبقة العلوية بخط Helvetica وعلامة شفافية. لا تشكّل العربية ولا تُضمّن خطاً ولا تعيد كتابة محتوى الصفحة. القصّ يصغّر CropBox فقط.',
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _stamp,
        decoration: InputDecoration(
          labelText: _t('Stamp (Latin)', 'الختم (لاتيني)'),
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _headText,
        decoration: InputDecoration(labelText: _t('Header', 'ترويسة')),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _bates,
        decoration: InputDecoration(
          labelText: _t('Bates prefix', 'بادئة الترقيم'),
          hintText: 'QD',
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _crop,
        decoration: InputDecoration(
          labelText: _t(
            'Crop left, bottom, right, top',
            'قص يسار، أسفل، يمين، أعلى',
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          FilledButton(
            onPressed: _jobs.isEmpty ? null : _stampFile,
            child: Text(_t('Stamp', 'ختم')),
          ),
          OutlinedButton(
            onPressed: _jobs.isEmpty ? null : _numberFile,
            child: Text(_t('Numbers', 'أرقام')),
          ),
          OutlinedButton(
            onPressed: _jobs.isEmpty ? null : _cropFile,
            child: Text(_t('Crop', 'قص')),
          ),
        ],
      ),
    ]);
  }

  Widget _results() {
    return Material(
      color: widget.accent.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _t('Results', 'النتائج'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final PdfToolOutput output in _outputs)
                  ActionChip(
                    label: Text(output.name),
                    onPressed: () => Navigator.of(context).pop(output),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pad(List<Widget> children) {
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }

  Widget _note(String text) {
    return Text(
      text,
      style: TextStyle(
        height: 1.35,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
      ),
    );
  }

  _Job? get _current {
    if (_jobs.isEmpty) {
      return null;
    }
    final int index = _selected.clamp(0, _jobs.length - 1);
    return _jobs[index];
  }

  Future<void> _pick() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) {
      return;
    }
    for (final PlatformFile file in result.files) {
      Uint8List? bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && file.path != null && !kIsWeb) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        continue;
      }
      _add(file.name.isEmpty ? 'document.pdf' : file.name, bytes);
    }
  }

  void _useCurrent() {
    final Uint8List? bytes = widget.currentBytes;
    if (bytes == null || bytes.isEmpty) {
      return;
    }
    _add(widget.currentName ?? 'Document.pdf', bytes);
  }

  void _add(String name, Uint8List bytes) {
    try {
      final PdfFile file = PdfFile.open(bytes);
      if (file.pageCount < 1) {
        throw ArgumentError(_t('File has no pages', 'الملف بلا صفحات'));
      }
      setState(() {
        _error = null;
        _jobs.add(_Job(name: name, bytes: bytes, pages: file.pageCount));
        _selected = _jobs.length - 1;
      });
    } on Object catch (error) {
      setState(() => _error = '$error');
    }
  }

  void _drop(int index) {
    setState(() {
      _jobs.removeAt(index).dispose();
      if (_selected >= _jobs.length) {
        _selected = _jobs.isEmpty ? 0 : _jobs.length - 1;
      }
    });
  }

  void _merge() {
    _runOne(
      'merged.pdf',
      PdfToolbox.merge(<PdfPageSource>[
        for (final _Job job in _jobs) PdfPageSource(job.bytes),
      ]),
    );
  }

  void _mix() {
    _runOne(
      'mixed.pdf',
      PdfToolbox.mix(
        PdfPageSource(_jobs[0].bytes),
        PdfPageSource(_jobs[1].bytes),
      ),
    );
  }

  void _splitFile() {
    final _Job? job = _current;
    if (job == null) {
      return;
    }
    final PdfSplitSpec spec = switch (_split) {
      PdfSplitKind.every => PdfSplitSpec.every(
        int.tryParse(_chunk.text.trim()) ?? 1,
      ),
      PdfSplitKind.burst => const PdfSplitSpec.burst(),
      PdfSplitKind.odd => const PdfSplitSpec.odd(),
      PdfSplitKind.even => const PdfSplitSpec.even(),
      PdfSplitKind.bookmarks => const PdfSplitSpec.bookmarks(),
    };
    _runMany(PdfToolbox.split(job.bytes, spec), _stem(job.name));
  }

  void _extract() {
    final List<PdfPageSource> sources = <PdfPageSource>[
      for (final _Job job in _jobs)
        PdfPageSource(job.bytes, ranges: _groups(job.ranges.text)),
    ];
    final List<Uint8List> files = PdfToolbox.extract(
      sources,
      mode: _extractMode,
    );
    _runMany(files, 'extract');
  }

  void _reorder() {
    final _Job? job = _current;
    if (job == null) {
      return;
    }
    final List<int> order = <int>[];
    for (final String part in _order.text.split(',')) {
      final int? page = int.tryParse(part.trim());
      if (page == null) {
        continue;
      }
      order.add(page - 1);
    }
    _runOne('reordered.pdf', PdfToolbox.reorder(job.bytes, order));
  }

  void _reverse() {
    final _Job? job = _current;
    if (job == null) {
      return;
    }
    _runOne('reversed.pdf', PdfToolbox.reverse(job.bytes));
  }

  void _remove() {
    final _Job? job = _current;
    if (job == null) {
      return;
    }
    _runOne(
      'removed.pdf',
      PdfToolbox.remove(job.bytes, _groups(job.ranges.text)),
    );
  }

  void _blank() {
    final _Job? job = _current;
    if (job == null) {
      return;
    }
    final int at = (int.tryParse(_at.text.trim()) ?? 1) - 1;
    _runOne('inserted.pdf', PdfToolbox.insertBlank(job.bytes, at));
  }

  void _stampFile() {
    final _Job? job = _current;
    if (job == null) {
      return;
    }
    _runOne(
      'stamped.pdf',
      PdfToolbox.stamp(
        job.bytes,
        text: _stamp.text,
        ranges: _groups(job.ranges.text),
      ),
    );
  }

  void _numberFile() {
    final _Job? job = _current;
    if (job == null) {
      return;
    }
    _runOne(
      'numbered.pdf',
      PdfToolbox.numberPages(
        job.bytes,
        bates: _bates.text,
        header: _headText.text,
        ranges: _groups(job.ranges.text),
      ),
    );
  }

  void _cropFile() {
    final _Job? job = _current;
    if (job == null) {
      return;
    }
    final List<double> inset = <double>[
      for (final String part in _crop.text.split(','))
        double.tryParse(part.trim()) ?? 0,
    ];
    while (inset.length < 4) {
      inset.add(0);
    }
    _runOne(
      'cropped.pdf',
      PdfToolbox.crop(
        job.bytes,
        left: inset[0],
        bottom: inset[1],
        right: inset[2],
        top: inset[3],
        ranges: _groups(job.ranges.text),
      ),
    );
  }

  void _rotate() {
    final _Job? job = _current;
    if (job == null) {
      return;
    }
    _runOne(
      'rotated.pdf',
      PdfToolbox.rotate(
        job.bytes,
        degrees: _degrees,
        ranges: _groups(job.ranges.text),
      ),
    );
  }

  void _runOne(String name, Uint8List bytes) {
    try {
      setState(() {
        _error = null;
        _outputs = <PdfToolOutput>[PdfToolOutput(bytes: bytes, name: name)];
      });
    } on Object catch (error) {
      setState(() => _error = '$error');
    }
  }

  void _runMany(List<Uint8List> files, String stem) {
    try {
      setState(() {
        _error = null;
        _outputs = <PdfToolOutput>[
          for (int i = 0; i < files.length; i++)
            PdfToolOutput(bytes: files[i], name: '$stem-${i + 1}.pdf'),
        ];
      });
    } on Object catch (error) {
      setState(() => _error = '$error');
    }
  }

  List<String> _groups(String raw) {
    return <String>[
      for (final String part in raw.split(';'))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  String _stem(String name) {
    final int dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }
}
