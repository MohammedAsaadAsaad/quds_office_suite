import 'dart:typed_data';

import 'package:quds_office_engine/pdf_templates.dart' as tpl;

import 'studio_pdf_faces.dart';

tpl.SfntFont? _font() => StudioPdfFaces.tryFamily('tajawal');

tpl.SfntFont? _bold() {
  try {
    return StudioPdfFaces.tajawalBold();
  } on Object {
    return _font();
  }
}

/// One PDF: page 1 English, page 2 Arabic, same template class.
Uint8List studioTemplatePair(String id) {
  final tpl.SfntFont? font = _font();
  final tpl.SfntFont? bold = _bold();
  final Uint8List english = tpl.TemplateSuite.ids.contains(id)
      ? tpl.TemplateSuite.demo(id, arabic: false, font: font, fontBold: bold)
      : _legacy(id, arabic: false, font: font, bold: bold);
  final Uint8List arabic = tpl.TemplateSuite.ids.contains(id)
      ? tpl.TemplateSuite.demo(id, arabic: true, font: font, fontBold: bold)
      : _legacy(id, arabic: true, font: font, bold: bold);
  return tpl.joinTemplateFiles(<Uint8List>[english, arabic]);
}

tpl.TemplateParty _party(bool arabic, String en, String ar) {
  return tpl.TemplateParty(name: arabic ? ar : en);
}

Uint8List _legacy(
  String id, {
  required bool arabic,
  required tpl.SfntFont? font,
  required tpl.SfntFont? bold,
}) {
  final tpl.TextDirection direction =
      arabic ? tpl.TextDirection.rtl : tpl.TextDirection.ltr;
  final tpl.TemplateParty dock = _party(arabic, 'North Dock', 'الرصيف الشمالي');
  final tpl.TemplateParty clinic = _party(arabic, 'River Clinic', 'عيادة النهر');
  return switch (id) {
    'commerce.invoice' => tpl.InvoiceTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        seller: dock,
        buyer: clinic,
        number: 'INV-14',
        date: arabic ? '14 أيلول 2026' : '14 Sep 2026',
        due: arabic ? '28 أيلول 2026' : '28 Sep 2026',
        labels: arabic
            ? const tpl.TradeLabels(
                document: 'فاتورة',
                from: 'من',
                to: 'إلى',
                number: 'الرقم',
                date: 'التاريخ',
                extra: 'الاستحقاق',
                description: 'البيان',
                quantity: 'الكمية',
                unit: 'السعر',
                amount: 'المبلغ',
                subtotal: 'المجموع',
                tax: 'الضريبة',
                total: 'الإجمالي',
                notes: 'ملاحظات',
              )
            : const tpl.TradeLabels(),
        lines: <tpl.TradeLine>[
          tpl.TradeLine(
            description: arabic ? 'حقيبة ميدانية' : 'Field kit',
            quantity: '12',
            unit: '48',
            amount: '576',
          ),
        ],
        totals: const tpl.MoneyTotals(subtotal: '576', tax: '86', total: '662'),
        notes: arabic
            ? 'المبالغ منسّقة مسبقاً. الاتجاه يقلب الجدول.'
            : 'Amounts are already formatted. Direction flips the table.',
      ).save(),
    'commerce.quote' => tpl.QuoteTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        seller: dock,
        buyer: clinic,
        number: 'Q-9',
        date: arabic ? '14 أيلول 2026' : '14 Sep 2026',
        validUntil: arabic ? '30 أيلول 2026' : '30 Sep 2026',
        labels: arabic
            ? const tpl.TradeLabels(
                document: 'عرض سعر',
                from: 'من',
                to: 'إلى',
                extra: 'صالح حتى',
                description: 'البيان',
                quantity: 'الكمية',
                unit: 'السعر',
                amount: 'المبلغ',
                total: 'الإجمالي',
                notes: 'ملاحظات',
              )
            : const tpl.TradeLabels(document: 'Quote', extra: 'Valid until'),
        lines: <tpl.TradeLine>[
          tpl.TradeLine(
            description: arabic ? 'هيكل خيمة' : 'Tent frame',
            quantity: '6',
            unit: '120',
            amount: '720',
          ),
        ],
        totals: const tpl.MoneyTotals(subtotal: '720', total: '720'),
      ).save(),
    'commerce.receipt' => tpl.ReceiptTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        seller: dock,
        buyer: clinic,
        number: 'RC-4',
        date: arabic ? '14 أيلول 2026' : '14 Sep 2026',
        labels: arabic
            ? const tpl.TradeLabels(
                document: 'إيصال',
                from: 'من',
                to: 'إلى',
                description: 'البيان',
                amount: 'المبلغ',
                total: 'الإجمالي',
              )
            : const tpl.TradeLabels(document: 'Receipt'),
        lines: <tpl.TradeLine>[
          tpl.TradeLine(
            description: arabic ? 'دفعة الحقائب' : 'Kit payment',
            amount: '662',
          ),
        ],
        totals: const tpl.MoneyTotals(subtotal: '662', total: '662'),
      ).save(),
    'commerce.delivery' => tpl.DeliveryNoteTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        sender: dock,
        receiver: clinic,
        number: 'DN-6',
        date: arabic ? '14 أيلول 2026' : '14 Sep 2026',
        labels: arabic
            ? const tpl.TradeLabels(
                document: 'إذن تسليم',
                from: 'المرسل',
                to: 'المستلم',
                description: 'البيان',
                quantity: 'المطلوب',
                unit: 'المشحون',
              )
            : const tpl.TradeLabels(
                document: 'Delivery note',
                from: 'Sender',
                to: 'Receiver',
                quantity: 'Ordered',
                unit: 'Shipped',
              ),
        lines: <tpl.TradeLine>[
          tpl.TradeLine(
            description: arabic ? 'حقيبة ميدانية' : 'Field kit',
            quantity: '12',
            detail: '12',
          ),
        ],
      ).save(),
    'finance.statement' => tpl.StatementTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        issuer: dock,
        account: clinic,
        period: arabic ? 'أيلول' : 'September',
        opening: '1,200',
        closing: '860',
        labels: arabic
            ? const tpl.StatementLabels(
                document: 'كشف حساب',
                account: 'الحساب',
                period: 'الفترة',
                opening: 'افتتاحي',
                closing: 'ختامي',
                date: 'التاريخ',
                detail: 'البيان',
                debit: 'مدين',
                credit: 'دائن',
                balance: 'الرصيد',
                notes: 'ملاحظات',
              )
            : const tpl.StatementLabels(),
        lines: <tpl.StatementLine>[
          tpl.StatementLine(
            date: arabic ? '03 أيلول' : '03 Sep',
            detail: arabic ? 'فاتورة حقائب' : 'Kit invoice',
            debit: '480',
            balance: '720',
          ),
        ],
      ).save(),
    'finance.expense' => tpl.ExpenseTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        claimant: dock,
        total: '90',
        date: arabic ? '14 أيلول 2026' : '14 Sep 2026',
        purpose: arabic ? 'سفر البوابة' : 'Gate travel',
        labels: arabic
            ? const tpl.ExpenseLabels(
                document: 'مطالبة مصروف',
                date: 'التاريخ',
                category: 'البند',
                amount: 'المبلغ',
                total: 'الإجمالي',
                notes: 'ملاحظات',
              )
            : const tpl.ExpenseLabels(),
        lines: <tpl.ExpenseLine>[
          tpl.ExpenseLine(
            date: arabic ? '12 أيلول' : '12 Sep',
            category: arabic ? 'تنقّل' : 'Travel',
            amount: '90',
          ),
        ],
      ).save(),
    'finance.payslip' => tpl.PayslipTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        employer: dock,
        employee: clinic,
        period: arabic ? 'أيلول' : 'September',
        net: '800',
        labels: arabic
            ? const tpl.PayslipLabels(
                document: 'قسيمة راتب',
                period: 'الفترة',
                earnings: 'الاستحقاقات',
                deductions: 'الخصومات',
                item: 'البند',
                amount: 'المبلغ',
                net: 'الصافي',
              )
            : const tpl.PayslipLabels(),
        earnings: <tpl.PayLine>[
          tpl.PayLine(label: arabic ? 'أساسي' : 'Base', amount: '900'),
        ],
        deductions: <tpl.PayLine>[
          tpl.PayLine(label: arabic ? 'ضريبة' : 'Tax', amount: '100'),
        ],
      ).save(),
    'people.letter' => tpl.LetterTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        sender: dock,
        recipient: clinic,
        subject: arabic ? 'ساعات البوابة' : 'Gate hours',
        date: arabic ? '14 أيلول 2026' : '14 Sep 2026',
        labels: arabic
            ? const tpl.LetterLabels(
                document: 'رسالة',
                to: 'إلى',
                subject: 'الموضوع',
                closing: 'مع التحية',
              )
            : const tpl.LetterLabels(),
        paragraphs: <String>[
          arabic
              ? 'البوابة الشرقية تُغلق عند 18:00 من الجمعة.'
              : 'The east gate closes at 18:00 from Friday.',
        ],
      ).save(),
    'people.certificate' => tpl.CertificateTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        issuer: dock,
        recipient: arabic ? 'لينا حداد' : 'Lina Haddad',
        award: arabic ? 'تناوب العيادة' : 'Clinic rotation',
        date: arabic ? '14 أيلول 2026' : '14 Sep 2026',
        body: arabic
            ? 'تُمنح لاثنتي عشرة ليلة على جدول عيادة النهر.'
            : 'Awarded for twelve nights on the river clinic roster.',
        labels: arabic
            ? const tpl.CertificateLabels(
                document: 'شهادة',
                presentedTo: 'تُمنح إلى',
                date: 'التاريخ',
              )
            : const tpl.CertificateLabels(),
        signs: <tpl.SignSlot>[
          tpl.SignSlot(role: arabic ? 'المدير' : 'Director'),
        ],
      ).save(),
    'operations.agenda' => tpl.AgendaTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        host: dock,
        when: arabic ? 'الجمعة 09:00' : 'Friday 09:00',
        where: arabic ? 'القاعة' : 'Hall',
        labels: arabic
            ? const tpl.AgendaLabels(
                document: 'جدول أعمال',
                when: 'متى',
                where: 'أين',
                time: 'الوقت',
                item: 'البند',
                owner: 'الصاحب',
              )
            : const tpl.AgendaLabels(),
        items: <tpl.AgendaItem>[
          tpl.AgendaItem(
            time: '09:00',
            title: arabic ? 'افتتاح' : 'Open',
            owner: arabic ? 'المضيف' : 'Host',
          ),
        ],
      ).save(),
    'operations.minutes' => tpl.MinutesTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        host: dock,
        when: arabic ? 'الجمعة' : 'Friday',
        labels: arabic
            ? const tpl.MinutesLabels(
                document: 'محضر',
                when: 'متى',
                attendees: 'الحضور',
                decisions: 'القرارات',
                actions: 'المهام',
                task: 'المهمة',
                owner: 'الصاحب',
                due: 'الاستحقاق',
              )
            : const tpl.MinutesLabels(),
        attendees: <String>[arabic ? 'المضيف' : 'Host', arabic ? 'العيادة' : 'Clinic'],
        decisions: <tpl.Decision>[
          tpl.Decision(text: arabic ? 'تُشحن الحقائب فجراً.' : 'Kits ship at dawn.'),
        ],
        actions: <tpl.ActionItem>[
          tpl.ActionItem(
            task: arabic ? 'تأكيد العدد' : 'Confirm the count',
            owner: arabic ? 'المضيف' : 'Host',
            due: arabic ? 'الخميس' : 'Thursday',
          ),
        ],
      ).save(),
    'operations.checklist' => tpl.ChecklistTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        owner: dock,
        labels: arabic
            ? const tpl.ChecklistLabels(
                document: 'قائمة تحقق',
                item: 'البند',
                mark: 'العلامة',
                note: 'ملاحظة',
                marks: <tpl.CheckMark, String>{
                  tpl.CheckMark.open: 'مفتوح',
                  tpl.CheckMark.done: 'تم',
                  tpl.CheckMark.pass: 'نجاح',
                  tpl.CheckMark.fail: 'فشل',
                  tpl.CheckMark.na: 'لا ينطبق',
                },
              )
            : const tpl.ChecklistLabels(),
        groups: <tpl.CheckGroup>[
          tpl.CheckGroup(
            title: arabic ? 'البوابة' : 'Gate',
            items: <tpl.CheckItem>[
              tpl.CheckItem(
                label: arabic ? 'الأقفال' : 'Locks',
                mark: tpl.CheckMark.done,
              ),
            ],
          ),
        ],
      ).save(),
    'operations.inspection' => tpl.InspectionTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        inspector: dock,
        site: arabic ? 'مستودع 4' : 'Warehouse 4',
        when: arabic ? '14 أيلول 2026' : '14 Sep 2026',
        labels: arabic
            ? const tpl.InspectionLabels(
                document: 'تفتيش',
                site: 'الموقع',
                when: 'متى',
                inspector: 'المفتش',
                pass: 'نجاح',
                fail: 'فشل',
                open: 'مفتوح',
                item: 'البند',
                result: 'النتيجة',
                note: 'ملاحظة',
                marks: <tpl.CheckMark, String>{
                  tpl.CheckMark.open: 'مفتوح',
                  tpl.CheckMark.done: 'تم',
                  tpl.CheckMark.pass: 'نجاح',
                  tpl.CheckMark.fail: 'فشل',
                  tpl.CheckMark.na: 'لا ينطبق',
                },
              )
            : const tpl.InspectionLabels(),
        items: <tpl.CheckItem>[
          tpl.CheckItem(label: arabic ? 'المنحدر' : 'Ramp', mark: tpl.CheckMark.pass),
          tpl.CheckItem(
            label: arabic ? 'الإنارة' : 'Light',
            mark: tpl.CheckMark.fail,
            note: arabic ? 'الباب الشرقي' : 'East door',
          ),
        ],
      ).save(),
    'narrative.memo' => tpl.MemoTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        from: dock,
        to: clinic,
        subject: arabic ? 'ساعات الرصيف' : 'Dock hours',
        date: arabic ? '14 أيلول 2026' : '14 Sep 2026',
        labels: arabic
            ? const tpl.MemoLabels(
                document: 'مذكرة',
                to: 'إلى',
                from: 'من',
                date: 'التاريخ',
                subject: 'الموضوع',
              )
            : const tpl.MemoLabels(),
        sections: <tpl.TemplateSection>[
          tpl.TemplateSection(
            heading: arabic ? 'التغيير' : 'Change',
            body: arabic
                ? 'البوابة تُغلق عند 18:00 يوم الجمعة.'
                : 'The gate closes at 18:00 on Friday.',
          ),
        ],
      ).save(),
    'narrative.briefing' => tpl.BriefingTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        author: dock,
        title: arabic ? 'الأسبوع 37' : 'Week 37',
        summary: arabic ? 'الحقائب تحركت في موعدها.' : 'Kits moved on time.',
        labels: arabic
            ? const tpl.BriefingLabels(document: 'إحاطة', next: 'التالي')
            : const tpl.BriefingLabels(),
        metrics: <tpl.BriefMetric>[
          tpl.BriefMetric(label: arabic ? 'في الموعد' : 'On time', value: '12'),
        ],
        next: <String>[arabic ? 'إعادة العدّ الجمعة.' : 'Recount on Friday.'],
      ).save(),
    'data.kpi' => tpl.KpiSheetTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        owner: clinic,
        period: arabic ? 'الربع الثالث' : 'Q3',
        labels: arabic
            ? const tpl.KpiLabels(
                document: 'ورقة مؤشرات',
                period: 'الفترة',
                notes: 'ملاحظات',
              )
            : const tpl.KpiLabels(),
        metrics: <tpl.KpiMetric>[
          tpl.KpiMetric(
            label: arabic ? 'زيارات' : 'Visits',
            value: '1,240',
            delta: '+6%',
          ),
        ],
        chartTitle: arabic ? 'الزيارات' : 'Visits',
        chart: <tpl.ChartPoint>[
          tpl.ChartPoint(label: arabic ? 'أيلول' : 'Sep', value: 450, color: '217346'),
        ],
      ).save(),
    'data.listing' => tpl.ListingTemplate(
        direction: direction,
        font: font,
        fontBold: bold,
        owner: dock,
        filter: arabic ? 'مفتوح' : 'Open',
        labels: arabic
            ? const tpl.ListingLabels(
                document: 'كشف سجلات',
                filter: 'التصفية',
                count: 'الصفوف',
              )
            : const tpl.ListingLabels(),
        columns: <String>[
          arabic ? 'الرقم' : 'Id',
          arabic ? 'الحالة' : 'Status',
        ],
        rows: <List<String>>[
          <String>['14', arabic ? 'مفتوح' : 'Open'],
        ],
      ).save(),
    _ => throw ArgumentError('Unknown template sample: $id'),
  };
}
