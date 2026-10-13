import 'package:flutter/widgets.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

/// Interface language of the studio window: its own texts plus the
/// designer's [ReportDesignerStrings].
///
/// Texts are authored in English; [t] falls back to the designer table and
/// then to the English text. Placeholders such as `{name}` are filled by
/// [f].
class StudioStrings {
  const StudioStrings._(this.designer, this._table);

  /// English.
  static const StudioStrings english = StudioStrings._(
    ReportDesignerStrings.english,
    <String, String>{},
  );

  /// Arabic, laid out right to left.
  static const StudioStrings arabic = StudioStrings._(
    ReportDesignerStrings.arabic,
    _arabic,
  );

  /// Languages with a translation.
  static const List<StudioStrings> all = <StudioStrings>[english, arabic];

  /// Locales the studio is translated to.
  static const List<Locale> locales = <Locale>[Locale('en'), Locale('ar')];

  /// Strings for [locale]; English when the language has no translation.
  static StudioStrings forLocale(Locale? locale) {
    for (final StudioStrings s in all) {
      if (s.designer.languageCode == locale?.languageCode) {
        return s;
      }
    }
    return english;
  }

  /// Strings of the app locale above [context].
  static StudioStrings of(BuildContext context) =>
      forLocale(Localizations.maybeLocaleOf(context));

  /// Strings handed to the report designer.
  final ReportDesignerStrings designer;

  final Map<String, String> _table;

  /// Whether the interface reads right to left.
  bool get isRtl => designer.isRtl;

  /// Translation of the English text [english].
  String t(String english) => _table[english] ?? designer.t(english);

  /// [t] with each `{key}` replaced by its value in [args].
  String f(String english, Map<String, String> args) {
    var out = t(english);
    for (final MapEntry<String, String> a in args.entries) {
      out = out.replaceAll('{${a.key}}', a.value);
    }
    return out;
  }

  /// `3 problems` in this language.
  String count(int n, String noun) => designer.count(n, noun);

  static const Map<String, String> _arabic = <String, String>{
    'Quds Report Studio': 'استوديو القدس للتقارير',
    // Title bar and File menu.
    'File': 'ملف',
    'File menu': 'قائمة الملف',
    'New (Ctrl+N)': 'جديد (Ctrl+N)',
    'Open (Ctrl+O)': 'فتح (Ctrl+O)',
    'Save (Ctrl+S)': 'حفظ (Ctrl+S)',
    'Edited': 'معدّل',
    'New blank report': 'تقرير فارغ جديد',
    'New from template': 'جديد من قالب',
    'Open…': 'فتح…',
    'Open recent': 'الملفات الأخيرة',
    'No recent files': 'لا توجد ملفات حديثة',
    'Clear recent files': 'مسح قائمة الملفات الأخيرة',
    'Save': 'حفظ',
    'Save as…': 'حفظ باسم…',
    'Print…': 'طباعة…',
    'Save as template': 'حفظ كقالب',
    'My templates': 'قوالبي',
    'Open templates folder': 'فتح مجلد القوالب',
    'No templates yet. Use File › Save as template.':
        'لا توجد قوالب بعد. استخدم ملف › حفظ كقالب.',
    'Saved as template "{name}"': 'تم الحفظ كقالب "{name}"',
    'Cannot save the template: {error}': 'تعذّر حفظ القالب: {error}',
    'Print (Ctrl+P)': 'طباعة (Ctrl+P)',
    'Open .qrep files with Report Studio':
        'فتح ملفات ‎.qrep‎ باستوديو التقارير',
    'Exit': 'خروج',
    // Settings.
    'Settings': 'الإعدادات',
    'Theme': 'المظهر',
    'Language': 'اللغة',
    'Same as the system': 'حسب النظام',
    'Light': 'فاتح',
    'Dark': 'داكن',
    // Dialogs.
    'Save changes to {name}?': 'حفظ التغييرات في {name}؟',
    "Your changes will be lost if you don't save.":
        'ستفقد التغييرات إن لم تحفظها.',
    'Cancel': 'إلغاء',
    "Don't save": 'عدم الحفظ',
    'Open report template': 'فتح قالب تقرير',
    'Save report template': 'حفظ قالب التقرير',
    'Embed image in report': 'تضمين صورة في التقرير',
    'Embed TrueType fonts in report': 'تضمين خطوط TrueType في التقرير',
    'Import sample data': 'استيراد بيانات تجريبية',
    'Import shapes': 'استيراد أشكال',
    'Export {format}': 'تصدير {format}',
    // Messages.
    'Saved {name}': 'تم حفظ {name}',
    'Exported {name}': 'تم تصدير {name}',
    'Show problems': 'عرض المشاكل',
    'Hide problems': 'إخفاء المشاكل',
    'Cannot open {name}: {error}': 'تعذّر فتح {name}: {error}',
    'Cannot read {name}: {error}': 'تعذّرت قراءة {name}: {error}',
    'Cannot save: {error}': 'تعذّر الحفظ: {error}',
    'Cannot print: {error}': 'تعذّرت الطباعة: {error}',
    'Cannot export: {error}': 'تعذّر التصدير: {error}',
    '.qrep files now open with Report Studio':
        'ملفات ‎.qrep‎ تُفتح الآن باستوديو التقارير',
    'Could not register .qrep files': 'تعذّر ربط ملفات ‎.qrep‎',
    // Status bar.
    'Unsaved changes': 'تغييرات غير محفوظة',
    'Saved': 'محفوظ',
    'Not saved to disk yet': 'لم يُحفظ على القرص بعد',
    'No problems': 'لا مشاكل',
  };
}
