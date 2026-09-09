import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

/// Word-style Navigation / Find & Replace pane driven only by [OfficeController].
class StudioFindPane extends StatefulWidget {
  const StudioFindPane({
    super.key,
    required this.controller,
    required this.arabic,
    required this.accent,
    required this.replaceMode,
    required this.onReplaceMode,
    required this.onClose,
  });

  final OfficeController controller;
  final bool arabic;
  final Color accent;
  final bool replaceMode;
  final ValueChanged<bool> onReplaceMode;
  final VoidCallback onClose;

  @override
  State<StudioFindPane> createState() => _StudioFindPaneState();
}

class _StudioFindPaneState extends State<StudioFindPane> {
  late final TextEditingController _query;
  late final TextEditingController _replace;
  final FocusNode _queryFocus = FocusNode();
  Timer? _debounce;
  var _matchCase = false;
  var _wholeWord = false;
  var _wildcards = false;
  var _more = false;

  OfficeController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: _c.findSession.options?.query ?? '');
    _replace = TextEditingController(
      text: _c.findSession.options?.replaceWith ?? '',
    );
    _matchCase = _c.findSession.options?.matchCase ?? false;
    _wholeWord = _c.findSession.options?.wholeWord ?? false;
    _wildcards = _c.findSession.options?.wildcards ?? false;
    _c.addListener(_onController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _queryFocus.requestFocus();
        _query.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _query.text.length,
        );
        if (_query.text.isNotEmpty) {
          _runFind();
        }
      }
    });
  }

  @override
  void didUpdateWidget(StudioFindPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _query.text = _c.findSession.options?.query ?? _query.text;
      _replace.text = _c.findSession.options?.replaceWith ?? _replace.text;
      if (_query.text.isNotEmpty) {
        _runFind();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.removeListener(_onController);
    _query.dispose();
    _replace.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _onController() {
    if (mounted) {
      setState(() {});
    }
  }

  OfficeFindOptions _options() {
    return OfficeFindOptions(
      query: _query.text,
      replaceWith: _replace.text,
      matchCase: _matchCase,
      wholeWord: _wholeWord,
      wildcards: _wildcards,
    );
  }

  void _scheduleFind() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 160), _runFind);
  }

  void _runFind() {
    if (!mounted) {
      return;
    }
    final String q = _query.text;
    if (q.isEmpty) {
      _c.findSession.clear();
      _c.findSession.active = true;
      _c.refresh();
      setState(() {});
      return;
    }
    _c.find(_options());
    setState(() {});
  }

  String get _status {
    final OfficeFindSession session = _c.findSession;
    if (_query.text.isEmpty) {
      return widget.arabic ? 'اكتب للبحث في المستند' : 'Type to search the document';
    }
    if (session.hits.isEmpty) {
      return widget.arabic ? 'لا نتائج' : 'No matches';
    }
    return widget.arabic
        ? '${session.index + 1} من ${session.hits.length}'
        : '${session.index + 1} of ${session.hits.length}';
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = dark ? const Color(0xFF2B2B2B) : Colors.white;
    final Color border = dark ? const Color(0xFF3D3D3D) : const Color(0xFFD0D0D0);
    final Color muted = dark ? const Color(0xFFB0B0B0) : const Color(0xFF5B5B5B);
    return Material(
      color: surface,
      elevation: 8,
      shadowColor: const Color(0x44000000),
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
          const SingleActivator(LogicalKeyboardKey.enter): () {
            if (_query.text.isEmpty) {
              return;
            }
            _c.findNext();
            setState(() {});
          },
          const SingleActivator(LogicalKeyboardKey.enter, shift: true): () {
            _c.findPrevious();
            setState(() {});
          },
          const SingleActivator(LogicalKeyboardKey.f3): () {
            _c.findNext();
            setState(() {});
          },
          const SingleActivator(LogicalKeyboardKey.f3, shift: true): () {
            _c.findPrevious();
            setState(() {});
          },
        },
        child: Focus(
          child: SizedBox(
            width: 332,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _header(muted),
                Divider(height: 1, color: border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    children: <Widget>[
                      _field(
                        controller: _query,
                        focusNode: _queryFocus,
                        icon: Icons.search,
                        hint: widget.arabic
                            ? 'بحث في المستند'
                            : 'Search document',
                        onChanged: (_) => _scheduleFind(),
                        suffix: _query.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: widget.arabic ? 'مسح' : 'Clear',
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  _query.clear();
                                  _runFind();
                                },
                                icon: const Icon(Icons.close, size: 16),
                              ),
                      ),
                      if (widget.replaceMode) ...<Widget>[
                        const SizedBox(height: 8),
                        _field(
                          controller: _replace,
                          icon: Icons.find_replace,
                          hint: widget.arabic ? 'استبدال بـ' : 'Replace with',
                        ),
                      ],
                      const SizedBox(height: 8),
                      _commandRow(),
                      Align(
                        alignment: widget.arabic
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() => _more = !_more),
                          child: Text(
                            _more
                                ? (widget.arabic ? 'أقل <<' : '<< Less')
                                : (widget.arabic ? 'المزيد >>' : 'More >>'),
                          ),
                        ),
                      ),
                      if (_more) _optionsBox(border),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Align(
                          alignment: widget.arabic
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Text(
                            _status,
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: border),
                Expanded(child: _results(muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(Color muted) {
    return SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          const SizedBox(width: 12),
          Icon(Icons.manage_search, size: 18, color: widget.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.replaceMode
                  ? (widget.arabic ? 'بحث واستبدال' : 'Find and Replace')
                  : (widget.arabic ? 'التنقل' : 'Navigation'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: widget.arabic ? 'استبدال' : 'Replace',
            visualDensity: VisualDensity.compact,
            onPressed: () => widget.onReplaceMode(!widget.replaceMode),
            icon: Icon(
              Icons.find_replace,
              size: 18,
              color: widget.replaceMode ? widget.accent : muted,
            ),
          ),
          IconButton(
            tooltip: widget.arabic ? 'إغلاق' : 'Close',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    FocusNode? focusNode,
    required IconData icon,
    required String hint,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) {
        if (_c.findSession.hits.isEmpty) {
          _runFind();
        } else {
          _c.findNext();
        }
        setState(() {});
      },
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18),
        suffixIcon: suffix,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );
  }

  Widget _commandRow() {
    final bool hasQuery = _query.text.isNotEmpty;
    final bool hasHits = _c.findSession.hits.isNotEmpty;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: <Widget>[
        _cmd(
          Icons.keyboard_arrow_up,
          widget.arabic ? 'السابق' : 'Previous',
          hasHits
              ? () {
                  _c.findPrevious();
                  setState(() {});
                }
              : null,
        ),
        _cmd(
          Icons.keyboard_arrow_down,
          widget.arabic ? 'التالي' : 'Next',
          hasQuery
              ? () {
                  if (hasHits) {
                    _c.findNext();
                  } else {
                    _runFind();
                  }
                  setState(() {});
                }
              : null,
        ),
        if (widget.replaceMode) ...<Widget>[
          _cmd(
            Icons.find_replace,
            widget.arabic ? 'استبدال' : 'Replace',
            hasHits && _c.config.allowsMutation
                ? () {
                    _c.replaceCurrent();
                    setState(() {});
                  }
                : null,
          ),
          _cmd(
            Icons.done_all,
            widget.arabic ? 'استبدال الكل' : 'Replace all',
            hasQuery && _c.config.allowsMutation
                ? () {
                    _c.replaceAll(_options());
                    setState(() {});
                  }
                : null,
          ),
        ],
      ],
    );
  }

  Widget _cmd(IconData icon, String label, VoidCallback? onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _optionsBox(Color border) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: <Widget>[
          _check(
            widget.arabic ? 'مطابقة حالة الأحرف' : 'Match case',
            _matchCase,
            (bool v) {
              setState(() => _matchCase = v);
              _runFind();
            },
          ),
          _check(
            widget.arabic ? 'الكلمة كاملة فقط' : 'Find whole words only',
            _wholeWord,
            (bool v) {
              setState(() => _wholeWord = v);
              _runFind();
            },
          ),
          _check(
            widget.arabic ? 'أحرف البدل (* ?)' : 'Use wildcards (* ?)',
            _wildcards,
            (bool v) {
              setState(() => _wildcards = v);
              _runFind();
            },
          ),
        ],
      ),
    );
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      title: Text(label, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: (bool? v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _results(Color muted) {
    final List<OfficeFindHit> hits = _c.findSession.hits;
    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.arabic
                ? 'ستظهر النتائج هنا مع تمييزها في المستند.'
                : 'Results appear here and are highlighted in the document.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (BuildContext context, int index) {
        final OfficeFindHit hit = hits[index];
        final bool active = index == _c.findSession.index;
        return InkWell(
          onTap: () {
            _c.findSession.index = index;
            _c.revealFindHit(hit);
            _c.refresh();
            setState(() {});
          },
          child: ColoredBox(
            color: active
                ? widget.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    _hitTitle(hit, index),
                    style: TextStyle(
                      fontSize: 11,
                      color: muted,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(_snippet(hit), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _hitTitle(OfficeFindHit hit, int index) {
    if (hit.a1 != null) {
      return '${hit.sheetName ?? ''}!${hit.a1}';
    }
    if (hit.slideIndex != null) {
      return widget.arabic
          ? 'شريحة ${(hit.slideIndex ?? 0) + 1}'
          : 'Slide ${(hit.slideIndex ?? 0) + 1}';
    }
    return widget.arabic
        ? 'فقرة ${(hit.paragraphIndex ?? 0) + 1} · ${index + 1}'
        : 'Paragraph ${(hit.paragraphIndex ?? 0) + 1} · ${index + 1}';
  }

  TextSpan _snippet(OfficeFindHit hit) {
    final String text = hit.preview;
    final int start = hit.start.clamp(0, text.length);
    final int end = hit.end.clamp(start, text.length);
    return TextSpan(
      style: const TextStyle(fontSize: 13, height: 1.35),
      children: <TextSpan>[
        TextSpan(text: text.substring(0, start)),
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            backgroundColor: const Color(0xFFFFE699),
            fontWeight: FontWeight.w700,
            color: widget.accent,
          ),
        ),
        TextSpan(text: text.substring(end)),
      ],
    );
  }
}
