import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/pdf_templates.dart';

void main() {
  final Directory out = Directory('/tmp/skin_shots');
  out.createSync(recursive: true);
  final Map<String, Uint8List> files = <String, Uint8List>{
    'invoice': InvoiceTemplate(
      seller: const TemplateParty(name: 'North Dock', lines: <String>['Port Road']),
      buyer: const TemplateParty(name: 'Harbour Supply'),
      lines: const <TradeLine>[
        TradeLine(description: 'Oak desk', quantity: '2', unit: 'ea', amount: '240'),
        TradeLine(description: 'Lamp', quantity: '4', unit: 'ea', amount: '80'),
      ],
      totals: const MoneyTotals(subtotal: '320', tax: '32', total: '352'),
      number: 'INV-19',
      date: '14 Sep 2026',
      due: '30 Sep 2026',
    ).save(),
    'quote': QuoteTemplate(
      seller: const TemplateParty(name: 'North Dock'),
      buyer: const TemplateParty(name: 'Harbour Supply'),
      lines: const <TradeLine>[
        TradeLine(description: 'Fit-out', quantity: '1', unit: 'job', amount: '1800'),
      ],
      totals: const MoneyTotals(subtotal: '1800', total: '1800'),
      number: 'Q-4',
      date: '14 Sep 2026',
      validUntil: '30 Sep 2026',
    ).save(),
    'receipt': ReceiptTemplate(
      seller: const TemplateParty(name: 'North Dock'),
      buyer: const TemplateParty(name: 'Walk-in'),
      lines: const <TradeLine>[
        TradeLine(description: 'Coffee', quantity: '2', amount: '8'),
        TradeLine(description: 'Pastry', quantity: '1', amount: '4'),
      ],
      totals: const MoneyTotals(subtotal: '12', total: '12'),
      number: 'R-88',
      date: '14 Sep 2026',
      method: 'Card',
    ).save(),
    'delivery': DeliveryNoteTemplate(
      sender: const TemplateParty(name: 'Warehouse A'),
      receiver: const TemplateParty(name: 'Site B'),
      lines: const <TradeLine>[
        TradeLine(description: 'Panels', quantity: '12', detail: '12'),
      ],
      number: 'DN-3',
      date: '14 Sep 2026',
      shipDate: '15 Sep 2026',
    ).save(),
    'letter': LetterTemplate(
      sender: const TemplateParty(name: 'Amina Haddad', lines: <String>['People desk']),
      recipient: const TemplateParty(name: 'Lina Khoury'),
      subject: 'Offer of employment',
      paragraphs: const <String>['We are pleased to offer you the role of designer.'],
      date: '14 Sep 2026',
    ).save(),
    'certificate': CertificateTemplate(
      issuer: const TemplateParty(name: 'Quds Academy'),
      recipient: 'Nora Saleh',
      award: 'Design practice',
      body: 'Completed the studio year with distinction.',
      date: '14 Sep 2026',
    ).save(),
    'payslip': PayslipTemplate(
      employer: const TemplateParty(name: 'North Dock'),
      employee: const TemplateParty(name: 'Sami Nassar'),
      earnings: const <PayLine>[PayLine(label: 'Salary', amount: '4200')],
      deductions: const <PayLine>[PayLine(label: 'Tax', amount: '400')],
      net: '3800',
      period: 'Sep 2026',
      paidOn: '28 Sep',
    ).save(),
    'checklist': ChecklistTemplate(
      owner: const TemplateParty(name: 'Floor lead'),
      groups: const <CheckGroup>[
        CheckGroup(
          title: 'Open',
          items: <CheckItem>[
            CheckItem(label: 'Doors', mark: CheckMark.done),
            CheckItem(label: 'Alarms', mark: CheckMark.open, note: 'West wing'),
          ],
        ),
      ],
    ).save(),
    'kpi': KpiSheetTemplate(
      owner: const TemplateParty(name: 'Ops'),
      metrics: const <KpiMetric>[
        KpiMetric(label: 'On time', value: '96%'),
        KpiMetric(label: 'Open', value: '12'),
        KpiMetric(label: 'NPS', value: '41'),
      ],
      period: 'Q3',
    ).save(),
    'waybill': TemplateSuite.demo('logistics.waybill', arabic: false),
    'voucher': TemplateSuite.demo('finance.payment-voucher', arabic: false),
    'grades': TemplateSuite.demo('education.report-card', arabic: false),
    'identity': TemplateSuite.demo('people.profile', arabic: false),
    'notice': TemplateSuite.demo('narrative.announcement', arabic: false),
    'journal': TemplateSuite.demo('finance.journal', arabic: false),
    'comparison': TemplateSuite.demo('data.comparison', arabic: false),
  };
  for (final MapEntry<String, Uint8List> entry in files.entries) {
    File('${out.path}/${entry.key}.pdf').writeAsBytesSync(entry.value);
  }
  stdout.writeln('wrote ${files.length}');
}
