/// Ready-made `.qrep` templates with matching sample data.
///
/// Each entry is a complete, validated report a developer can load as-is,
/// open in the designer, and adapt (bindings, colors, columns, wording).
library;

/// What a template is for (designer grouping).
enum ReportTemplateCategory { sales, finance, inventory, analytics }

/// One catalog entry: XML plus sample data matching its bindings.
class ReportTemplateInfo {
  /// ReportTemplateInfo API.
  const ReportTemplateInfo({
    required this.id,
    required this.title,
    required this.titleAr,
    required this.description,
    required this.descriptionAr,
    required this.category,
    required this.rtl,
    required this.xml,
    required this.sampleData,
  });

  /// Stable identifier (`sales_invoice_ar`).
  final String id;

  /// English title.
  final String title;

  /// Arabic title.
  final String titleAr;

  /// English summary of layout and bindings.
  final String description;

  /// Arabic summary.
  final String descriptionAr;

  /// category API.
  final ReportTemplateCategory category;

  /// Right-to-left layout.
  final bool rtl;

  /// `.qrep` XML.
  final String xml;

  /// Data shaped like the bindings the template expects.
  final Map<String, Object?> Function() sampleData;

  /// [title] or [titleAr] for [arabic].
  String titleFor({required bool arabic}) => arabic ? titleAr : title;
}

/// Catalog of professional starting points.
abstract final class ReportTemplates {
  /// Every template, in display order.
  static const List<ReportTemplateInfo> all = <ReportTemplateInfo>[
    ReportTemplateInfo(
      id: 'sales_invoice_ar',
      title: 'Sales invoice (Arabic)',
      titleAr: 'فاتورة مبيعات',
      description:
          'Right-to-left tax invoice: seller and customer blocks, QR code, '
          'striped item table, discount and VAT totals, amount in words.',
      descriptionAr:
          'فاتورة ضريبية من اليمين لليسار: بيانات البائع والعميل، رمز QR، '
          'جدول أصناف، الخصم والضريبة والإجمالي، والمبلغ بالحروف.',
      category: ReportTemplateCategory.sales,
      rtl: true,
      xml: _salesInvoiceAr,
      sampleData: _salesInvoiceArData,
    ),
    ReportTemplateInfo(
      id: 'invoice_en',
      title: 'Commercial invoice (English)',
      titleAr: 'فاتورة تجارية (إنجليزي)',
      description:
          'Modern left-to-right invoice with bill-to / ship-to, Code 128 '
          'invoice barcode, tax and shipping totals, and payment details.',
      descriptionAr:
          'فاتورة إنجليزية حديثة: عنوان الفوترة والشحن، باركود رقم الفاتورة، '
          'الضريبة والشحن، وبيانات الدفع.',
      category: ReportTemplateCategory.sales,
      rtl: false,
      xml: _invoiceEn,
      sampleData: _invoiceEnData,
    ),
    ReportTemplateInfo(
      id: 'sales_performance',
      title: 'Sales performance dashboard',
      titleAr: 'لوحة أداء المبيعات',
      description:
          'KPI cards, revenue-vs-target bars, category donut, orders trend, '
          'region ranking, then order details grouped by region.',
      descriptionAr:
          'بطاقات مؤشرات، أعمدة الإيراد مقابل المستهدف، حلقة الفئات، اتجاه '
          'الطلبات، ترتيب المناطق، ثم تفاصيل الطلبات مجمعة حسب المنطقة.',
      category: ReportTemplateCategory.analytics,
      rtl: false,
      xml: _salesPerformance,
      sampleData: _salesPerformanceData,
    ),
    ReportTemplateInfo(
      id: 'account_statement_ar',
      title: 'Customer account statement (Arabic)',
      titleAr: 'كشف حساب عميل',
      description:
          'Debit / credit / running balance table with totals, balance '
          'summary cards, closing balance in words, and a balance trend chart.',
      descriptionAr:
          'جدول مدين ودائن ورصيد متحرك مع الإجماليات، بطاقات ملخص الرصيد، '
          'الرصيد الختامي بالحروف، ومخطط تطور الرصيد.',
      category: ReportTemplateCategory.finance,
      rtl: true,
      xml: _accountStatementAr,
      sampleData: _accountStatementArData,
    ),
    ReportTemplateInfo(
      id: 'inventory_ar',
      title: 'Inventory status (Arabic)',
      titleAr: 'تقرير حالة المخزون',
      description:
          'Stock KPIs, top items by value, value share by category, then '
          'items grouped by category with reorder status and subtotals.',
      descriptionAr:
          'مؤشرات المخزون، أعلى الأصناف قيمة، توزيع القيمة حسب الفئة، ثم '
          'الأصناف مجمعة حسب الفئة مع حالة إعادة الطلب والمجاميع.',
      category: ReportTemplateCategory.inventory,
      rtl: true,
      xml: _inventoryAr,
      sampleData: _inventoryArData,
    ),
    ReportTemplateInfo(
      id: 'receipt_voucher_ar',
      title: 'Receipt voucher (Arabic)',
      titleAr: 'سند قبض',
      description:
          'A5 landscape receipt voucher: amount box, received-from, amount in '
          'words, purpose, payment method, and three signature lines.',
      descriptionAr:
          'سند قبض بحجم A5 أفقي: خانة المبلغ، استلمنا من، المبلغ بالحروف، '
          'الغرض، طريقة الدفع، وثلاث خانات توقيع.',
      category: ReportTemplateCategory.finance,
      rtl: true,
      xml: _receiptVoucherAr,
      sampleData: _receiptVoucherArData,
    ),
  ];

  /// Template with [id], or null.
  static ReportTemplateInfo? byId(String id) {
    for (final ReportTemplateInfo t in all) {
      if (t.id == id) {
        return t;
      }
    }
    return null;
  }
}

// ------------------------------------------------------------------ invoice AR

const String _salesInvoiceAr = r'''<?xml version="1.0" encoding="UTF-8"?>
<QudsReport name="فاتورة مبيعات" isRtl="true" pageSize="A4" orientation="Portrait" defaultFont="Noto Naskh Arabic" defaultFontSize="9">
    <Settings>
        <Margins top="12mm" bottom="12mm" left="12mm" right="12mm"/>
        <Colors primary="#1F4E79" accent="#2E75B6" muted="#5F6B7A" light="#F3F6FA" border="#D9DEE7" text="#1F2933"/>
    </Settings>
    <Bands>
        <ReportHeader height="70mm">
            <Rectangle x="12mm" y="0mm" width="186mm" height="2.5mm" fill="primary" strokeWidth="0"/>
            <Shape kind="RoundedRectangle" x="12mm" y="6mm" width="18mm" height="18mm" fill="primary" strokeWidth="0" cornerRadius="4pt"/>
            <Text x="12mm" y="6mm" width="18mm" height="18mm" fontSize="20" bold="true" color="#FFFFFF" alignment="center" verticalAlignment="middle">ق</Text>
            <Text x="33mm" y="6mm" width="95mm" height="9mm" fontSize="15" bold="true" color="primary">{{Data.seller.name}}</Text>
            <Text x="33mm" y="15mm" width="95mm" height="5mm" fontSize="8" color="muted">{{Data.seller.address}}</Text>
            <Text x="33mm" y="20mm" width="95mm" height="5mm" fontSize="8" color="muted">هاتف: &#x2066;{{Data.seller.phone}}&#x2069;  •  الرقم الضريبي: {{Data.seller.vatNo}}</Text>
            <Text x="130mm" y="5mm" width="68mm" height="12mm" fontSize="20" bold="true" color="primary" alignment="end">فاتورة مبيعات</Text>
            <Text x="130mm" y="17mm" width="68mm" height="5mm" fontSize="8" color="muted" alignment="left" direction="ltr">TAX INVOICE</Text>
            <Line x1="12mm" y1="28mm" x2="198mm" y2="28mm" color="border" strokeWidth="0.75"/>
            <Shape kind="RoundedRectangle" x="12mm" y="32mm" width="100mm" height="34mm" fill="light" strokeWidth="0" cornerRadius="3pt"/>
            <Text x="16mm" y="34mm" width="92mm" height="5mm" fontSize="8" bold="true" color="accent">فاتورة إلى</Text>
            <Text x="16mm" y="40mm" width="92mm" height="7mm" fontSize="11" bold="true">{{Data.customer.name}}</Text>
            <Text x="16mm" y="47mm" width="92mm" height="5mm" fontSize="8.5" color="muted">{{Data.customer.address}}</Text>
            <Text x="16mm" y="53mm" width="92mm" height="5mm" fontSize="8.5" color="muted">الرقم الضريبي: {{Data.customer.vatNo}}</Text>
            <Text x="16mm" y="59mm" width="92mm" height="5mm" fontSize="8.5" color="muted">هاتف: &#x2066;{{Data.customer.phone}}&#x2069;</Text>
            <Shape kind="RoundedRectangle" x="116mm" y="32mm" width="56mm" height="34mm" fill="#FFFFFF" color="border" strokeWidth="0.75" cornerRadius="3pt"/>
            <Text x="119mm" y="34mm" width="22mm" height="7mm" fontSize="8" color="muted" verticalAlignment="middle">رقم الفاتورة</Text>
            <Text x="141mm" y="34mm" width="29mm" height="7mm" fontSize="9" bold="true" alignment="end" verticalAlignment="middle">{{Data.invoice.number}}</Text>
            <Text x="119mm" y="42mm" width="22mm" height="7mm" fontSize="8" color="muted" verticalAlignment="middle">التاريخ</Text>
            <Text x="141mm" y="42mm" width="29mm" height="7mm" fontSize="9" bold="true" alignment="end" verticalAlignment="middle">{{Data.invoice.date | date:dd/MM/yyyy}}</Text>
            <Text x="119mm" y="50mm" width="22mm" height="7mm" fontSize="8" color="muted" verticalAlignment="middle">الاستحقاق</Text>
            <Text x="141mm" y="50mm" width="29mm" height="7mm" fontSize="9" bold="true" alignment="end" verticalAlignment="middle">{{Data.invoice.dueDate | date:dd/MM/yyyy}}</Text>
            <Text x="119mm" y="58mm" width="22mm" height="7mm" fontSize="8" color="muted" verticalAlignment="middle">طريقة الدفع</Text>
            <Text x="141mm" y="58mm" width="29mm" height="7mm" fontSize="9" bold="true" alignment="end" verticalAlignment="middle">{{Data.invoice.paymentMethod}}</Text>
            <QrCode x="175mm" y="32mm" width="23mm" height="23mm" value="INV:{{Data.invoice.number}};VAT:{{Data.seller.vatNo}};TOTAL:{{SUM(item.qty * item.price - item.discount) * (1 + Data.taxRate) | n3}}"/>
            <Text x="175mm" y="56mm" width="23mm" height="5mm" fontSize="7" color="muted" alignment="center">امسح للتحقق</Text>
        </ReportHeader>
        <PageHeader height="9mm" printOnFirstPage="false">
            <Text x="12mm" y="1mm" width="186mm" height="6mm" fontSize="8" color="muted">{{Data.seller.name}} — فاتورة رقم {{Data.invoice.number}} (تابع)</Text>
            <Line x1="12mm" y1="7.5mm" x2="198mm" y2="7.5mm" color="border" strokeWidth="0.5"/>
        </PageHeader>
        <Detail dataSet="items" height="16mm">
            <Table x="12mm" y="0mm" width="186mm" showGrid="true" borderColor="border" headerBackground="primary" headerColor="#FFFFFF" stripeColor="light" fontSize="9" headerFontSize="9" rowHeight="7.5mm" headerHeight="8mm" padding="2pt">
                <Columns>
                    <Column width="8mm" header="#" align="center"/>
                    <Column width="22mm" header="الرمز" align="center"/>
                    <Column width="64mm" header="الوصف" align="start"/>
                    <Column width="16mm" header="الوحدة" align="center"/>
                    <Column width="16mm" header="الكمية" align="center"/>
                    <Column width="22mm" header="سعر الوحدة" align="center"/>
                    <Column width="16mm" header="الخصم" align="center"/>
                    <Column width="22mm" header="الإجمالي" align="center"/>
                </Columns>
                <RowTemplate>
                    <Cell field="System.RowNumber"/>
                    <Cell field="item.code"/>
                    <Cell field="item.name"/>
                    <Cell field="item.unit"/>
                    <Cell field="item.qty"/>
                    <Cell field="item.price" format="n3"/>
                    <Cell field="item.discount" format="n3"/>
                    <Cell field="item.qty * item.price - item.discount" format="n3" bold="true"/>
                </RowTemplate>
            </Table>
        </Detail>
        <ReportSummary height="78mm" keepTogether="true">
            <Text x="12mm" y="5mm" width="110mm" height="5mm" fontSize="8" bold="true" color="accent">المبلغ بالحروف</Text>
            <Text x="12mm" y="10mm" width="110mm" height="12mm" fontSize="9.5" bold="true">{{TAFQEET(SUM(item.qty * item.price - item.discount) * (1 + Data.taxRate), 'LYD')}}</Text>
            <Text x="12mm" y="25mm" width="110mm" height="5mm" fontSize="8" bold="true" color="accent">ملاحظات وشروط</Text>
            <Text x="12mm" y="30mm" width="110mm" height="14mm" fontSize="8.5" color="muted">{{Data.notes}}</Text>
            <Text x="128mm" y="4mm" width="40mm" height="7mm" fontSize="9" color="muted" verticalAlignment="middle">المجموع</Text>
            <Text x="168mm" y="4mm" width="30mm" height="7mm" fontSize="9" alignment="end" verticalAlignment="middle">{{SUM(item.qty * item.price) | n3}}</Text>
            <Text x="128mm" y="11mm" width="40mm" height="7mm" fontSize="9" color="muted" verticalAlignment="middle">الخصم</Text>
            <Text x="168mm" y="11mm" width="30mm" height="7mm" fontSize="9" alignment="end" verticalAlignment="middle">{{SUM(item.discount) | n3}}</Text>
            <Text x="128mm" y="18mm" width="40mm" height="7mm" fontSize="9" color="muted" verticalAlignment="middle">الصافي قبل الضريبة</Text>
            <Text x="168mm" y="18mm" width="30mm" height="7mm" fontSize="9" alignment="end" verticalAlignment="middle">{{SUM(item.qty * item.price - item.discount) | n3}}</Text>
            <Text x="128mm" y="25mm" width="40mm" height="7mm" fontSize="9" color="muted" verticalAlignment="middle">الضريبة ({{Data.taxRate | percent}})</Text>
            <Text x="168mm" y="25mm" width="30mm" height="7mm" fontSize="9" alignment="end" verticalAlignment="middle">{{SUM(item.qty * item.price - item.discount) * Data.taxRate | n3}}</Text>
            <Shape kind="RoundedRectangle" x="128mm" y="33mm" width="70mm" height="10mm" fill="primary" strokeWidth="0" cornerRadius="3pt"/>
            <Text x="131mm" y="33mm" width="30mm" height="10mm" fontSize="10" bold="true" color="#FFFFFF" verticalAlignment="middle">الإجمالي المستحق</Text>
            <Text x="161mm" y="33mm" width="35mm" height="10mm" fontSize="11" bold="true" color="#FFFFFF" alignment="end" verticalAlignment="middle">{{SUM(item.qty * item.price - item.discount) * (1 + Data.taxRate) | currency:LYD}}</Text>
            <Line x1="22mm" y1="64mm" x2="82mm" y2="64mm" color="muted" strokeWidth="0.6" lineStyle="dotted"/>
            <Text x="22mm" y="65mm" width="60mm" height="6mm" fontSize="8.5" color="muted" alignment="center">توقيع المستلم</Text>
            <Line x1="128mm" y1="64mm" x2="188mm" y2="64mm" color="muted" strokeWidth="0.6" lineStyle="dotted"/>
            <Text x="128mm" y="65mm" width="60mm" height="6mm" fontSize="8.5" color="muted" alignment="center">الختم والتوقيع المعتمد</Text>
        </ReportSummary>
        <PageFooter height="10mm">
            <Line x1="12mm" y1="1mm" x2="198mm" y2="1mm" color="border" strokeWidth="0.5"/>
            <Text x="12mm" y="3mm" width="120mm" height="6mm" fontSize="8" color="muted">شكرًا لتعاملكم معنا — {{Data.seller.email}}</Text>
            <Text x="148mm" y="3mm" width="50mm" height="6mm" fontSize="8" color="muted" alignment="end">صفحة {{System.PageNumber}} من {{System.TotalPages}}</Text>
        </PageFooter>
    </Bands>
</QudsReport>
''';

Map<String, Object?> _salesInvoiceArData() => <String, Object?>{
  'seller': <String, Object?>{
    'name': 'شركة القدس للتقنية',
    'address': 'طرابلس — شارع الجمهورية، مبنى 14',
    'phone': '+218 91 234 5678',
    'vatNo': '300123456700003',
    'email': 'sales@quds.ly',
  },
  'customer': <String, Object?>{
    'name': 'مؤسسة النور للتجارة العامة',
    'address': 'بنغازي — طريق النهر، الدور الثاني',
    'vatNo': '310987654300003',
    'phone': '+218 92 765 4321',
  },
  'invoice': <String, Object?>{
    'number': 'INV-2026-0142',
    'date': DateTime(2026, 10, 10),
    'dueDate': DateTime(2026, 11, 9),
    'paymentMethod': 'تحويل مصرفي',
  },
  'taxRate': 0.15,
  'notes':
      'البضاعة المباعة لا ترد ولا تستبدل بعد 14 يومًا من تاريخ الفاتورة. '
      'يرجى ذكر رقم الفاتورة عند التحويل.',
  'items': <Map<String, Object?>>[
    _invItem('LP-1420', 'حاسوب محمول 14 بوصة — معالج i7', 'قطعة', 3, 3250, 150),
    _invItem('MN-2701', 'شاشة 27 بوصة دقة 4K', 'قطعة', 4, 1180, 0),
    _invItem('KB-0310', 'لوحة مفاتيح لاسلكية عربي/إنجليزي', 'قطعة', 10, 95, 25),
    _invItem('MS-0450', 'فأرة لاسلكية صامتة', 'قطعة', 10, 55, 0),
    _invItem('PR-9100', 'طابعة ليزر ملونة', 'قطعة', 1, 2100, 100),
    _invItem('CB-0006', 'كابل شبكة Cat6 — 305 متر', 'لفة', 2, 420, 0),
    _invItem('SV-1000', 'خدمة تركيب وتهيئة الأجهزة', 'خدمة', 1, 850, 50),
  ],
};

Map<String, Object?> _invItem(
  String code,
  String name,
  String unit,
  int qty,
  num price,
  num discount,
) => <String, Object?>{
  'code': code,
  'name': name,
  'unit': unit,
  'qty': qty,
  'price': price,
  'discount': discount,
};

// ------------------------------------------------------------------ invoice EN

const String _invoiceEn = r'''<?xml version="1.0" encoding="UTF-8"?>
<QudsReport name="Commercial Invoice" isRtl="false" pageSize="A4" orientation="Portrait" defaultFont="Liberation Sans" defaultFontSize="9">
    <Settings>
        <Margins top="12mm" bottom="12mm" left="12mm" right="12mm"/>
        <Colors primary="#0F766E" accent="#14B8A6" muted="#64748B" light="#F1F5F9" border="#E2E8F0" text="#0F172A"/>
    </Settings>
    <Bands>
        <ReportHeader height="66mm">
            <Text x="12mm" y="2mm" width="110mm" height="10mm" fontSize="18" bold="true" color="primary">{{Data.company.name}}</Text>
            <Text x="12mm" y="12mm" width="110mm" height="5mm" fontSize="8.5" color="muted">{{Data.company.address}}</Text>
            <Text x="12mm" y="16.5mm" width="110mm" height="5mm" fontSize="8.5" color="muted">{{Data.company.city}}</Text>
            <Text x="12mm" y="21mm" width="110mm" height="5mm" fontSize="8.5" color="muted">{{Data.company.phone}}  |  {{Data.company.email}}</Text>
            <Text x="120mm" y="0mm" width="78mm" height="13mm" fontSize="26" bold="true" color="primary" alignment="right">INVOICE</Text>
            <Barcode x="148mm" y="14mm" width="50mm" height="12mm" symbology="code128" value="{{Data.invoice.number}}" fontSize="7"/>
            <Rectangle x="12mm" y="30mm" width="186mm" height="0.8mm" fill="accent" strokeWidth="0"/>
            <Text x="12mm" y="34mm" width="60mm" height="5mm" fontSize="7.5" bold="true" color="primary">BILL TO</Text>
            <Text x="12mm" y="39mm" width="60mm" height="6mm" fontSize="10" bold="true">{{Data.billTo.name}}</Text>
            <Text x="12mm" y="45mm" width="60mm" height="5mm" fontSize="8.5" color="muted">{{Data.billTo.address}}</Text>
            <Text x="12mm" y="49.5mm" width="60mm" height="5mm" fontSize="8.5" color="muted">{{Data.billTo.city}}</Text>
            <Text x="12mm" y="54mm" width="60mm" height="5mm" fontSize="8.5" color="muted">{{Data.billTo.email}}</Text>
            <Text x="78mm" y="34mm" width="60mm" height="5mm" fontSize="7.5" bold="true" color="primary">SHIP TO</Text>
            <Text x="78mm" y="39mm" width="60mm" height="6mm" fontSize="10" bold="true">{{Data.shipTo.name}}</Text>
            <Text x="78mm" y="45mm" width="60mm" height="5mm" fontSize="8.5" color="muted">{{Data.shipTo.address}}</Text>
            <Text x="78mm" y="49.5mm" width="60mm" height="5mm" fontSize="8.5" color="muted">{{Data.shipTo.city}}</Text>
            <Shape kind="RoundedRectangle" x="144mm" y="34mm" width="54mm" height="27mm" fill="light" strokeWidth="0" cornerRadius="3pt"/>
            <Text x="147mm" y="36mm" width="22mm" height="5.5mm" fontSize="8" color="muted">Invoice #</Text>
            <Text x="169mm" y="36mm" width="27mm" height="5.5mm" fontSize="8.5" bold="true" alignment="right">{{Data.invoice.number}}</Text>
            <Text x="147mm" y="42mm" width="22mm" height="5.5mm" fontSize="8" color="muted">Date</Text>
            <Text x="169mm" y="42mm" width="27mm" height="5.5mm" fontSize="8.5" bold="true" alignment="right">{{Data.invoice.date | date:dd MMM yyyy}}</Text>
            <Text x="147mm" y="48mm" width="22mm" height="5.5mm" fontSize="8" color="muted">Due date</Text>
            <Text x="169mm" y="48mm" width="27mm" height="5.5mm" fontSize="8.5" bold="true" alignment="right">{{Data.invoice.dueDate | date:dd MMM yyyy}}</Text>
            <Text x="147mm" y="54mm" width="22mm" height="5.5mm" fontSize="8" color="muted">PO #</Text>
            <Text x="169mm" y="54mm" width="27mm" height="5.5mm" fontSize="8.5" bold="true" alignment="right">{{Data.invoice.po}}</Text>
        </ReportHeader>
        <PageHeader height="9mm" printOnFirstPage="false">
            <Text x="12mm" y="1mm" width="186mm" height="6mm" fontSize="8" color="muted">{{Data.company.name}} — Invoice {{Data.invoice.number}} (continued)</Text>
            <Line x1="12mm" y1="7.5mm" x2="198mm" y2="7.5mm" color="border" strokeWidth="0.5"/>
        </PageHeader>
        <Detail dataSet="items" height="16mm">
            <Table x="12mm" y="0mm" width="186mm" showGrid="false" headerBackground="primary" headerColor="#FFFFFF" stripeColor="light" fontSize="9" headerFontSize="8.5" rowHeight="7.5mm" headerHeight="8mm" padding="3pt">
                <Columns>
                    <Column width="8mm" header="#" align="center"/>
                    <Column width="24mm" header="SKU" align="left"/>
                    <Column width="82mm" header="DESCRIPTION" align="left"/>
                    <Column width="16mm" header="QTY" align="center"/>
                    <Column width="26mm" header="UNIT PRICE" align="right"/>
                    <Column width="30mm" header="AMOUNT" align="right"/>
                </Columns>
                <RowTemplate>
                    <Cell field="System.RowNumber"/>
                    <Cell field="item.sku"/>
                    <Cell field="item.description"/>
                    <Cell field="item.qty"/>
                    <Cell field="item.unitPrice" format="n2"/>
                    <Cell field="item.qty * item.unitPrice" format="n2" bold="true"/>
                </RowTemplate>
            </Table>
        </Detail>
        <ReportSummary height="72mm" keepTogether="true">
            <Line x1="12mm" y1="1mm" x2="198mm" y2="1mm" color="border" strokeWidth="0.75"/>
            <Text x="136mm" y="4mm" width="32mm" height="6.5mm" fontSize="9" color="muted">Subtotal</Text>
            <Text x="168mm" y="4mm" width="30mm" height="6.5mm" fontSize="9" alignment="right">${{SUM(item.qty * item.unitPrice) | n2}}</Text>
            <Text x="136mm" y="10.5mm" width="32mm" height="6.5mm" fontSize="9" color="muted">Tax ({{Data.taxRate | percent:1}})</Text>
            <Text x="168mm" y="10.5mm" width="30mm" height="6.5mm" fontSize="9" alignment="right">${{SUM(item.qty * item.unitPrice) * Data.taxRate | n2}}</Text>
            <Text x="136mm" y="17mm" width="32mm" height="6.5mm" fontSize="9" color="muted">Shipping</Text>
            <Text x="168mm" y="17mm" width="30mm" height="6.5mm" fontSize="9" alignment="right">${{Data.shipping | n2}}</Text>
            <Shape kind="RoundedRectangle" x="134mm" y="25mm" width="64mm" height="11mm" fill="primary" strokeWidth="0" cornerRadius="3pt"/>
            <Text x="137mm" y="25mm" width="28mm" height="11mm" fontSize="10" bold="true" color="#FFFFFF" verticalAlignment="middle">TOTAL DUE</Text>
            <Text x="163mm" y="25mm" width="33mm" height="11mm" fontSize="12" bold="true" color="#FFFFFF" alignment="right" verticalAlignment="middle">${{SUM(item.qty * item.unitPrice) * (1 + Data.taxRate) + Data.shipping | n2}}</Text>
            <Text x="12mm" y="5mm" width="110mm" height="5mm" fontSize="7.5" bold="true" color="primary">PAYMENT DETAILS</Text>
            <Text x="12mm" y="10.5mm" width="110mm" height="5mm" fontSize="8.5">Bank: {{Data.payment.bank}}</Text>
            <Text x="12mm" y="15.5mm" width="110mm" height="5mm" fontSize="8.5">IBAN: {{Data.payment.iban}}</Text>
            <Text x="12mm" y="20.5mm" width="110mm" height="5mm" fontSize="8.5">Terms: {{Data.payment.terms}}</Text>
            <Text x="12mm" y="29mm" width="110mm" height="5mm" fontSize="7.5" bold="true" color="primary">NOTES</Text>
            <Text x="12mm" y="34.5mm" width="110mm" height="14mm" fontSize="8.5" color="muted">{{Data.notes}}</Text>
            <Text x="12mm" y="56mm" width="186mm" height="8mm" fontSize="12" bold="true" color="primary" alignment="center">Thank you for your business!</Text>
        </ReportSummary>
        <PageFooter height="9mm">
            <Line x1="12mm" y1="1mm" x2="198mm" y2="1mm" color="border" strokeWidth="0.5"/>
            <Text x="12mm" y="2.5mm" width="120mm" height="5.5mm" fontSize="7.5" color="muted">{{Data.company.website}}</Text>
            <Text x="148mm" y="2.5mm" width="50mm" height="5.5mm" fontSize="7.5" color="muted" alignment="right">Page {{System.PageNumber}} of {{System.TotalPages}}</Text>
        </PageFooter>
    </Bands>
</QudsReport>
''';

Map<String, Object?> _invoiceEnData() => <String, Object?>{
  'company': <String, Object?>{
    'name': 'Quds Software Ltd.',
    'address': '14 Republic Street, Suite 300',
    'city': 'Tripoli, Libya',
    'phone': '+218 21 444 0101',
    'email': 'billing@quds.dev',
    'website': 'www.quds.dev',
  },
  'billTo': <String, Object?>{
    'name': 'Northwind Traders',
    'address': '120 Harbor Road',
    'city': 'Valletta, Malta',
    'email': 'accounts@northwind.example',
  },
  'shipTo': <String, Object?>{
    'name': 'Northwind Warehouse 2',
    'address': 'Unit 7, Freeport Zone',
    'city': 'Marsaxlokk, Malta',
  },
  'invoice': <String, Object?>{
    'number': 'QS-2026-0381',
    'date': DateTime(2026, 10, 10),
    'dueDate': DateTime(2026, 11, 9),
    'po': 'PO-77812',
  },
  'taxRate': 0.075,
  'shipping': 45,
  'payment': <String, Object?>{
    'bank': 'Mediterranean Commercial Bank',
    'iban': 'LY83 0020 4800 0000 1234 5678',
    'terms': 'Net 30 days',
  },
  'notes':
      'Licenses are activated on receipt of payment. Support renewals are '
      'billed annually from the activation date.',
  'items': <Map<String, Object?>>[
    _enItem(
      'QOS-ENT',
      'Quds Office Suite — Enterprise license (per seat)',
      25,
      180,
    ),
    _enItem('QOS-RPT', 'Report designer add-on (per seat)', 10, 65),
    _enItem('SUP-PRM', 'Premium support — 12 months', 1, 2400),
    _enItem('TRN-DEV', 'Developer training workshop (2 days)', 1, 1850),
    _enItem('MIG-SRV', 'Template migration service (per template)', 12, 95),
    _enItem('CLD-STR', 'Cloud document storage — 1 TB / year', 2, 320),
  ],
};

Map<String, Object?> _enItem(
  String sku,
  String description,
  int qty,
  num unitPrice,
) => <String, Object?>{
  'sku': sku,
  'description': description,
  'qty': qty,
  'unitPrice': unitPrice,
};

// ------------------------------------------------------------ sales dashboard

const String _salesPerformance = r'''<?xml version="1.0" encoding="UTF-8"?>
<QudsReport name="Sales Performance" isRtl="false" pageSize="A4" orientation="Portrait" defaultFont="Liberation Sans" defaultFontSize="9">
    <Settings>
        <Margins top="12mm" bottom="12mm" left="12mm" right="12mm"/>
        <Colors primary="#1E3A8A" accent="#3B82F6" muted="#64748B" light="#F4F7FB" border="#E1E7EF" text="#0F172A" good="#16A34A" warm="#F59E0B" pink="#DB2777"/>
    </Settings>
    <Bands>
        <ReportHeader height="196mm">
            <Shape kind="RoundedRectangle" x="12mm" y="0mm" width="186mm" height="20mm" fill="primary" strokeWidth="0" cornerRadius="4pt"/>
            <Text x="18mm" y="3mm" width="120mm" height="9mm" fontSize="17" bold="true" color="#FFFFFF">Sales Performance Report</Text>
            <Text x="18mm" y="12mm" width="120mm" height="6mm" fontSize="9" color="#DBEAFE">{{Data.company}}  •  {{Data.period}}</Text>
            <Text x="130mm" y="12mm" width="62mm" height="6mm" fontSize="8" color="#DBEAFE" alignment="right">Generated {{System.CurrentDate | date:dd MMM yyyy}}</Text>
            <Shape kind="RoundedRectangle" x="12mm" y="25mm" width="43.5mm" height="22mm" fill="light" color="border" strokeWidth="0.5" cornerRadius="3pt"/>
            <Rectangle x="12mm" y="28mm" width="1.4mm" height="16mm" fill="accent" strokeWidth="0"/>
            <Text x="16mm" y="27mm" width="38mm" height="5mm" fontSize="7.5" color="muted">Total revenue (USD)</Text>
            <Text x="16mm" y="32mm" width="38mm" height="8mm" fontSize="14" bold="true">{{SUM(Data.orders.revenue) | n0}}</Text>
            <Text x="16mm" y="40mm" width="38mm" height="5mm" fontSize="7" color="good">{{SUM(Data.orders.revenue) / SUM(Data.monthly.target) | percent:1}} of target</Text>
            <Shape kind="RoundedRectangle" x="59.5mm" y="25mm" width="43.5mm" height="22mm" fill="light" color="border" strokeWidth="0.5" cornerRadius="3pt"/>
            <Rectangle x="59.5mm" y="28mm" width="1.4mm" height="16mm" fill="good" strokeWidth="0"/>
            <Text x="63.5mm" y="27mm" width="38mm" height="5mm" fontSize="7.5" color="muted">Orders</Text>
            <Text x="63.5mm" y="32mm" width="38mm" height="8mm" fontSize="14" bold="true">{{COUNT(Data.orders) | n0}}</Text>
            <Text x="63.5mm" y="40mm" width="38mm" height="5mm" fontSize="7" color="muted">{{DISTINCTCOUNT(Data.orders.customer)}} active customers</Text>
            <Shape kind="RoundedRectangle" x="107mm" y="25mm" width="43.5mm" height="22mm" fill="light" color="border" strokeWidth="0.5" cornerRadius="3pt"/>
            <Rectangle x="107mm" y="28mm" width="1.4mm" height="16mm" fill="warm" strokeWidth="0"/>
            <Text x="111mm" y="27mm" width="38mm" height="5mm" fontSize="7.5" color="muted">Units sold</Text>
            <Text x="111mm" y="32mm" width="38mm" height="8mm" fontSize="14" bold="true">{{SUM(Data.orders.units) | n0}}</Text>
            <Text x="111mm" y="40mm" width="38mm" height="5mm" fontSize="7" color="muted">across {{DISTINCTCOUNT(Data.orders.category)}} categories</Text>
            <Shape kind="RoundedRectangle" x="154.5mm" y="25mm" width="43.5mm" height="22mm" fill="light" color="border" strokeWidth="0.5" cornerRadius="3pt"/>
            <Rectangle x="154.5mm" y="28mm" width="1.4mm" height="16mm" fill="pink" strokeWidth="0"/>
            <Text x="158.5mm" y="27mm" width="38mm" height="5mm" fontSize="7.5" color="muted">Average order (USD)</Text>
            <Text x="158.5mm" y="32mm" width="38mm" height="8mm" fontSize="14" bold="true">{{AVG(Data.orders.revenue) | n0}}</Text>
            <Text x="158.5mm" y="40mm" width="38mm" height="5mm" fontSize="7" color="muted">{{DISTINCTCOUNT(Data.orders.region)}} regions</Text>
            <Chart x="12mm" y="52mm" width="112mm" height="70mm" chartType="bar" title="Revenue vs target by month" dataSet="Data.monthly" category="Row.month" valueFormat="n0" borderColor="border" borderWidth="0.5pt">
                <Series name="Revenue" value="Row.revenue" color="primary"/>
                <Series name="Target" value="Row.target" color="#94A3B8"/>
            </Chart>
            <Chart x="127mm" y="52mm" width="71mm" height="70mm" chartType="donut" title="Revenue by category" dataSet="Data.orders" category="Row.category" value="Row.revenue" sortBy="value" sortOrder="desc" showValues="true" valueFormat="n0" borderColor="border" borderWidth="0.5pt" palette="#1E3A8A,#3B82F6,#16A34A,#F59E0B,#DB2777,#94A3B8"/>
            <Chart x="12mm" y="126mm" width="112mm" height="56mm" chartType="line" title="Units sold per month" dataSet="Data.monthly" category="Row.month" showValues="true" showLegend="false" borderColor="border" borderWidth="0.5pt">
                <Series name="Units" value="Row.units" color="good"/>
            </Chart>
            <Chart x="127mm" y="126mm" width="71mm" height="56mm" chartType="horizontalBar" title="Revenue by region" dataSet="Data.orders" category="Row.region" value="Row.revenue" sortBy="value" sortOrder="desc" showValues="true" showLegend="false" showGrid="false" valueFormat="n0" borderColor="border" borderWidth="0.5pt" palette="#3B82F6"/>
            <Text x="12mm" y="186mm" width="186mm" height="8mm" fontSize="12" bold="true" color="primary">Order details by region</Text>
            <Line x1="12mm" y1="194mm" x2="198mm" y2="194mm" color="accent" strokeWidth="1"/>
        </ReportHeader>
        <PageHeader height="9mm" printOnFirstPage="false">
            <Text x="12mm" y="1mm" width="140mm" height="6mm" fontSize="8" color="muted">Sales Performance Report — {{Data.period}}</Text>
            <Line x1="12mm" y1="7.5mm" x2="198mm" y2="7.5mm" color="border" strokeWidth="0.5"/>
        </PageHeader>
        <GroupHeader height="10mm" groupBy="item.region" keepTogether="true">
            <Shape kind="RoundedRectangle" x="12mm" y="1.5mm" width="186mm" height="7.5mm" fill="#EEF2FF" strokeWidth="0" cornerRadius="2pt"/>
            <Text x="15mm" y="1.5mm" width="120mm" height="7.5mm" fontSize="9.5" bold="true" color="primary" verticalAlignment="middle">{{Group.Key}} region</Text>
            <Text x="138mm" y="1.5mm" width="57mm" height="7.5mm" fontSize="8" color="muted" alignment="right" verticalAlignment="middle">{{Group.Count}} orders</Text>
        </GroupHeader>
        <Detail dataSet="orders" sortBy="item.revenue desc" height="15mm">
            <Table x="12mm" y="0mm" width="186mm" showGrid="false" headerBackground="#FFFFFF" headerColor="muted" stripeColor="light" fontSize="8.5" headerFontSize="7.5" rowHeight="6.5mm" headerHeight="7mm" padding="3pt">
                <Columns>
                    <Column width="24mm" header="DATE" align="left"/>
                    <Column width="26mm" header="ORDER #" align="left"/>
                    <Column width="56mm" header="CUSTOMER" align="left"/>
                    <Column width="32mm" header="CATEGORY" align="left"/>
                    <Column width="18mm" header="UNITS" align="right"/>
                    <Column width="30mm" header="REVENUE" align="right"/>
                </Columns>
                <RowTemplate>
                    <Cell field="item.date" format="date:dd MMM yyyy"/>
                    <Cell field="item.orderNo"/>
                    <Cell field="item.customer"/>
                    <Cell field="item.category"/>
                    <Cell field="item.units" format="n0"/>
                    <Cell field="item.revenue" format="n2" bold="true"/>
                </RowTemplate>
            </Table>
        </Detail>
        <GroupFooter height="10mm">
            <Line x1="120mm" y1="1mm" x2="198mm" y2="1mm" color="border" strokeWidth="0.75"/>
            <Text x="120mm" y="2mm" width="30mm" height="6.5mm" fontSize="8.5" bold="true" color="muted" verticalAlignment="middle">Subtotal</Text>
            <Text x="150mm" y="2mm" width="18mm" height="6.5mm" fontSize="8.5" bold="true" alignment="right" verticalAlignment="middle">{{SUM(item.units) | n0}}</Text>
            <Text x="168mm" y="2mm" width="30mm" height="6.5mm" fontSize="8.5" bold="true" alignment="right" verticalAlignment="middle">{{SUM(item.revenue) | n2}}</Text>
        </GroupFooter>
        <ReportSummary height="16mm" keepTogether="true">
            <Shape kind="RoundedRectangle" x="12mm" y="3mm" width="186mm" height="10mm" fill="primary" strokeWidth="0" cornerRadius="3pt"/>
            <Text x="16mm" y="3mm" width="100mm" height="10mm" fontSize="10" bold="true" color="#FFFFFF" verticalAlignment="middle">Grand total — {{COUNT(item.orderNo)}} orders</Text>
            <Text x="146mm" y="3mm" width="22mm" height="10mm" fontSize="10" bold="true" color="#FFFFFF" alignment="right" verticalAlignment="middle">{{SUM(item.units) | n0}}</Text>
            <Text x="168mm" y="3mm" width="28mm" height="10mm" fontSize="10" bold="true" color="#FFFFFF" alignment="right" verticalAlignment="middle">{{SUM(item.revenue) | n2}}</Text>
        </ReportSummary>
        <PageFooter height="9mm">
            <Line x1="12mm" y1="1mm" x2="198mm" y2="1mm" color="border" strokeWidth="0.5"/>
            <Text x="12mm" y="2.5mm" width="120mm" height="5.5mm" fontSize="7.5" color="muted">{{Data.company}} — internal use only</Text>
            <Text x="148mm" y="2.5mm" width="50mm" height="5.5mm" fontSize="7.5" color="muted" alignment="right">Page {{System.PageNumber}} of {{System.TotalPages}}</Text>
        </PageFooter>
    </Bands>
</QudsReport>
''';

Map<String, Object?> _salesPerformanceData() {
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
  ];
  const List<int> revenue = <int>[48200, 52650, 61300, 57800, 66420, 72900];
  const List<int> target = <int>[50000, 52000, 58000, 60000, 64000, 70000];
  const List<double> share = <double>[0.34, 0.27, 0.22, 0.17];
  const List<String> regions = <String>['North', 'South', 'East', 'West'];
  const List<String> categories = <String>[
    'Laptops',
    'Monitors',
    'Accessories',
    'Printers',
    'Services',
  ];
  const List<String> customers = <String>[
    'Northwind Traders',
    'Contoso Retail',
    'Fabrikam Inc.',
    'Adventure Works',
    'Tailspin Toys',
    'Wide World Importers',
    'Litware Group',
    'Proseware LLC',
  ];
  return <String, Object?>{
    'company': 'Quds Trading Co.',
    'period': 'January – June 2026',
    'monthly': <Map<String, Object?>>[
      for (int m = 0; m < months.length; m++)
        <String, Object?>{
          'month': months[m],
          'revenue': revenue[m],
          'target': target[m],
          'units': <int>[
            for (int k = 0; k < share.length; k++) 4 + (m * 7 + k * 11) % 23,
          ].fold<int>(0, (int a, int b) => a + b),
        },
    ],
    'orders': <Map<String, Object?>>[
      for (int m = 0; m < months.length; m++)
        for (int k = 0; k < share.length; k++)
          <String, Object?>{
            'date': DateTime(2026, m + 1, 3 + k * 6),
            'orderNo': 'SO-${10240 + m * 17 + k * 3}',
            'customer': customers[(m * 3 + k * 5) % customers.length],
            'region': regions[(m + k * 3) % regions.length],
            'category': categories[(m * 2 + k) % categories.length],
            'units': 4 + (m * 7 + k * 11) % 23,
            'revenue': revenue[m] * share[k],
          },
    ],
  };
}

// ---------------------------------------------------------- statement AR

const String _accountStatementAr = r'''<?xml version="1.0" encoding="UTF-8"?>
<QudsReport name="كشف حساب" isRtl="true" pageSize="A4" orientation="Portrait" defaultFont="Noto Naskh Arabic" defaultFontSize="9">
    <Settings>
        <Margins top="12mm" bottom="12mm" left="12mm" right="12mm"/>
        <Colors primary="#14532D" accent="#16A34A" muted="#5F6B7A" light="#F2F7F4" border="#D7E3DB" text="#1F2933" debit="#B91C1C" credit="#15803D"/>
    </Settings>
    <Bands>
        <ReportHeader height="84mm">
            <Text x="12mm" y="2mm" width="100mm" height="11mm" fontSize="20" bold="true" color="primary">كشف حساب عميل</Text>
            <Text x="12mm" y="13mm" width="100mm" height="5mm" fontSize="8" color="muted" direction="ltr" alignment="right">CUSTOMER ACCOUNT STATEMENT</Text>
            <Text x="118mm" y="2mm" width="80mm" height="7mm" fontSize="11" bold="true" alignment="end">{{Data.company.name}}</Text>
            <Text x="118mm" y="9mm" width="80mm" height="5mm" fontSize="8" color="muted" alignment="end">{{Data.company.address}}</Text>
            <Text x="118mm" y="14mm" width="80mm" height="5mm" fontSize="8" color="muted" alignment="end">هاتف: &#x2066;{{Data.company.phone}}&#x2069;</Text>
            <Line x1="12mm" y1="22mm" x2="198mm" y2="22mm" color="accent" strokeWidth="1"/>
            <Shape kind="RoundedRectangle" x="12mm" y="26mm" width="112mm" height="30mm" fill="light" strokeWidth="0" cornerRadius="3pt"/>
            <Text x="16mm" y="28mm" width="104mm" height="5mm" fontSize="8" bold="true" color="accent">بيانات العميل</Text>
            <Text x="16mm" y="34mm" width="104mm" height="7mm" fontSize="11" bold="true">{{Data.customer.name}}</Text>
            <Text x="16mm" y="41mm" width="50mm" height="5mm" fontSize="8.5" color="muted">رقم الحساب: {{Data.customer.code}}</Text>
            <Text x="68mm" y="41mm" width="52mm" height="5mm" fontSize="8.5" color="muted">هاتف: &#x2066;{{Data.customer.phone}}&#x2069;</Text>
            <Text x="16mm" y="47mm" width="104mm" height="5mm" fontSize="8.5" color="muted">العنوان: {{Data.customer.address}}</Text>
            <Shape kind="RoundedRectangle" x="128mm" y="26mm" width="70mm" height="30mm" fill="#FFFFFF" color="border" strokeWidth="0.75" cornerRadius="3pt"/>
            <Text x="132mm" y="28mm" width="62mm" height="5mm" fontSize="8" bold="true" color="accent">فترة الكشف</Text>
            <Text x="132mm" y="34mm" width="20mm" height="6mm" fontSize="8.5" color="muted">من</Text>
            <Text x="152mm" y="34mm" width="42mm" height="6mm" fontSize="9" bold="true" alignment="end">{{Data.period.from | date:dd/MM/yyyy}}</Text>
            <Text x="132mm" y="41mm" width="20mm" height="6mm" fontSize="8.5" color="muted">إلى</Text>
            <Text x="152mm" y="41mm" width="42mm" height="6mm" fontSize="9" bold="true" alignment="end">{{Data.period.to | date:dd/MM/yyyy}}</Text>
            <Text x="132mm" y="48mm" width="20mm" height="6mm" fontSize="8.5" color="muted">الإصدار</Text>
            <Text x="152mm" y="48mm" width="42mm" height="6mm" fontSize="9" alignment="end">{{System.CurrentDate | date:dd/MM/yyyy}}</Text>
            <Shape kind="RoundedRectangle" x="12mm" y="60mm" width="43.5mm" height="18mm" fill="#FFFFFF" color="border" strokeWidth="0.75" cornerRadius="3pt"/>
            <Text x="14mm" y="61.5mm" width="39.5mm" height="5mm" fontSize="7.5" color="muted" alignment="center">الرصيد الافتتاحي</Text>
            <Text x="14mm" y="67mm" width="39.5mm" height="8mm" fontSize="12" bold="true" alignment="center">{{Data.openingBalance | n3}}</Text>
            <Shape kind="RoundedRectangle" x="59.5mm" y="60mm" width="43.5mm" height="18mm" fill="#FFFFFF" color="border" strokeWidth="0.75" cornerRadius="3pt"/>
            <Text x="61.5mm" y="61.5mm" width="39.5mm" height="5mm" fontSize="7.5" color="muted" alignment="center">إجمالي المدين</Text>
            <Text x="61.5mm" y="67mm" width="39.5mm" height="8mm" fontSize="12" bold="true" color="debit" alignment="center">{{SUM(item.debit) | n3}}</Text>
            <Shape kind="RoundedRectangle" x="107mm" y="60mm" width="43.5mm" height="18mm" fill="#FFFFFF" color="border" strokeWidth="0.75" cornerRadius="3pt"/>
            <Text x="109mm" y="61.5mm" width="39.5mm" height="5mm" fontSize="7.5" color="muted" alignment="center">إجمالي الدائن</Text>
            <Text x="109mm" y="67mm" width="39.5mm" height="8mm" fontSize="12" bold="true" color="credit" alignment="center">{{SUM(item.credit) | n3}}</Text>
            <Shape kind="RoundedRectangle" x="154.5mm" y="60mm" width="43.5mm" height="18mm" fill="primary" strokeWidth="0" cornerRadius="3pt"/>
            <Text x="156.5mm" y="61.5mm" width="39.5mm" height="5mm" fontSize="7.5" color="#D1FAE5" alignment="center">الرصيد الختامي</Text>
            <Text x="156.5mm" y="67mm" width="39.5mm" height="8mm" fontSize="12" bold="true" color="#FFFFFF" alignment="center">{{Data.openingBalance + SUM(item.debit) - SUM(item.credit) | n3}}</Text>
        </ReportHeader>
        <PageHeader height="9mm" printOnFirstPage="false">
            <Text x="12mm" y="1mm" width="186mm" height="6mm" fontSize="8" color="muted">كشف حساب: {{Data.customer.name}} ({{Data.customer.code}}) — تابع</Text>
            <Line x1="12mm" y1="7.5mm" x2="198mm" y2="7.5mm" color="border" strokeWidth="0.5"/>
        </PageHeader>
        <Detail dataSet="transactions" height="22mm">
            <Table x="12mm" y="0mm" width="186mm" showGrid="true" borderColor="border" headerBackground="primary" headerColor="#FFFFFF" stripeColor="light" fontSize="8.5" headerFontSize="8.5" rowHeight="7mm" headerHeight="8mm" padding="2pt">
                <Columns>
                    <Column width="24mm" header="التاريخ" align="center"/>
                    <Column width="24mm" header="المرجع" align="center"/>
                    <Column width="66mm" header="البيان" align="start"/>
                    <Column width="24mm" header="مدين" align="center"/>
                    <Column width="24mm" header="دائن" align="center"/>
                    <Column width="24mm" header="الرصيد" align="center"/>
                </Columns>
                <RowTemplate>
                    <Cell field="item.date" format="date:dd/MM/yyyy"/>
                    <Cell field="item.ref"/>
                    <Cell field="item.description"/>
                    <Cell field="IF(item.debit > 0, item.debit, null)" format="n3" color="debit"/>
                    <Cell field="IF(item.credit > 0, item.credit, null)" format="n3" color="credit"/>
                    <Cell field="item.balance" format="n3" bold="true"/>
                </RowTemplate>
                <FooterRow>
                    <Cell text=""/>
                    <Cell text=""/>
                    <Cell text="الإجمالي" bold="true"/>
                    <Cell field="SUM(item.debit)" format="n3" bold="true"/>
                    <Cell field="SUM(item.credit)" format="n3" bold="true"/>
                    <Cell field="LAST(item.balance)" format="n3" bold="true"/>
                </FooterRow>
            </Table>
        </Detail>
        <ReportSummary height="82mm" keepTogether="true">
            <Shape kind="RoundedRectangle" x="12mm" y="4mm" width="186mm" height="16mm" fill="light" strokeWidth="0" cornerRadius="3pt"/>
            <Text x="16mm" y="5mm" width="120mm" height="7mm" fontSize="10" bold="true" color="primary" verticalAlignment="middle">الرصيد المستحق: {{Data.openingBalance + SUM(item.debit) - SUM(item.credit) | currency:LYD}}</Text>
            <Text x="16mm" y="12mm" width="178mm" height="7mm" fontSize="8.5" color="muted" verticalAlignment="middle">{{TAFQEET(Data.openingBalance + SUM(item.debit) - SUM(item.credit), 'LYD')}}</Text>
            <Chart x="12mm" y="24mm" width="186mm" height="44mm" chartType="area" title="تطور الرصيد خلال الفترة" dataSet="Data.transactions" category="FORMAT(Row.date, 'dd/MM')" aggregate="last" showLegend="false" valueFormat="n0" borderColor="border" borderWidth="0.5pt">
                <Series name="الرصيد" value="Row.balance" color="accent"/>
            </Chart>
            <Text x="12mm" y="71mm" width="186mm" height="9mm" fontSize="7.5" color="muted">يرجى مراجعة الكشف وإبلاغنا بأي ملاحظات خلال 15 يومًا من تاريخ الإصدار، وإلا اعتبر الرصيد صحيحًا.</Text>
        </ReportSummary>
        <PageFooter height="9mm">
            <Line x1="12mm" y1="1mm" x2="198mm" y2="1mm" color="border" strokeWidth="0.5"/>
            <Text x="12mm" y="2.5mm" width="120mm" height="5.5mm" fontSize="7.5" color="muted">{{Data.company.name}} — قسم الحسابات</Text>
            <Text x="148mm" y="2.5mm" width="50mm" height="5.5mm" fontSize="7.5" color="muted" alignment="end">صفحة {{System.PageNumber}} من {{System.TotalPages}}</Text>
        </PageFooter>
    </Bands>
</QudsReport>
''';

Map<String, Object?> _accountStatementArData() {
  const num opening = 12500;
  final List<(int, String, String, num, num)> moves =
      <(int, String, String, num, num)>[
        (2, 'INV-0921', 'فاتورة مبيعات — أجهزة حاسوب', 8650, 0),
        (5, 'RCV-0310', 'سند قبض — تحويل مصرفي', 0, 10000),
        (9, 'INV-0934', 'فاتورة مبيعات — مستلزمات مكتبية', 2340.5, 0),
        (12, 'RET-0041', 'مردودات مبيعات', 0, 420),
        (15, 'INV-0948', 'فاتورة مبيعات — طابعات', 4100, 0),
        (18, 'RCV-0326', 'سند قبض — شيك رقم 55120', 0, 6500),
        (21, 'INV-0957', 'فاتورة مبيعات — خدمات صيانة', 1250, 0),
        (24, 'DBN-0012', 'إشعار مدين — فرق أسعار', 310.75, 0),
        (27, 'RCV-0339', 'سند قبض — نقدًا', 0, 3000),
        (29, 'INV-0966', 'فاتورة مبيعات — شاشات', 5920, 0),
      ];
  var balance = opening;
  return <String, Object?>{
    'company': <String, Object?>{
      'name': 'شركة القدس للتقنية',
      'address': 'طرابلس — شارع الجمهورية',
      'phone': '+218 21 444 0101',
    },
    'customer': <String, Object?>{
      'name': 'مؤسسة النور للتجارة العامة',
      'code': 'C-10482',
      'phone': '+218 92 765 4321',
      'address': 'بنغازي — طريق النهر',
    },
    'period': <String, Object?>{
      'from': DateTime(2026, 9, 1),
      'to': DateTime(2026, 9, 30),
    },
    'openingBalance': opening,
    'transactions': <Map<String, Object?>>[
      for (final (int, String, String, num, num) m in moves)
        <String, Object?>{
          'date': DateTime(2026, 9, m.$1),
          'ref': m.$2,
          'description': m.$3,
          'debit': m.$4,
          'credit': m.$5,
          'balance': balance = balance + m.$4 - m.$5,
        },
    ],
  };
}

// ------------------------------------------------------------ inventory AR

const String _inventoryAr = r'''<?xml version="1.0" encoding="UTF-8"?>
<QudsReport name="تقرير المخزون" isRtl="true" pageSize="A4" orientation="Portrait" defaultFont="Noto Naskh Arabic" defaultFontSize="9">
    <Settings>
        <Margins top="12mm" bottom="12mm" left="12mm" right="12mm"/>
        <Colors primary="#7C2D12" accent="#EA580C" muted="#6B7280" light="#FFF7ED" border="#F1DCCB" text="#1F2933" alert="#DC2626" ok="#15803D"/>
    </Settings>
    <Bands>
        <ReportHeader height="128mm">
            <Shape kind="RoundedRectangle" x="12mm" y="0mm" width="186mm" height="20mm" fill="primary" strokeWidth="0" cornerRadius="4pt"/>
            <Text x="17mm" y="2.5mm" width="120mm" height="10mm" fontSize="17" bold="true" color="#FFFFFF">تقرير حالة المخزون</Text>
            <Text x="17mm" y="12mm" width="120mm" height="6mm" fontSize="9" color="#FED7AA">{{Data.warehouse}}</Text>
            <Text x="130mm" y="12mm" width="63mm" height="6mm" fontSize="8.5" color="#FED7AA" alignment="end">بتاريخ {{Data.date | date:dd/MM/yyyy}}</Text>
            <Shape kind="RoundedRectangle" x="12mm" y="25mm" width="43.5mm" height="20mm" fill="light" color="border" strokeWidth="0.5" cornerRadius="3pt"/>
            <Text x="14mm" y="27mm" width="39.5mm" height="5mm" fontSize="7.5" color="muted" alignment="center">عدد الأصناف</Text>
            <Text x="14mm" y="33mm" width="39.5mm" height="9mm" fontSize="15" bold="true" alignment="center">{{COUNT(item.code)}}</Text>
            <Shape kind="RoundedRectangle" x="59.5mm" y="25mm" width="43.5mm" height="20mm" fill="light" color="border" strokeWidth="0.5" cornerRadius="3pt"/>
            <Text x="61.5mm" y="27mm" width="39.5mm" height="5mm" fontSize="7.5" color="muted" alignment="center">إجمالي الكميات</Text>
            <Text x="61.5mm" y="33mm" width="39.5mm" height="9mm" fontSize="15" bold="true" alignment="center">{{SUM(item.qty) | n0}}</Text>
            <Shape kind="RoundedRectangle" x="107mm" y="25mm" width="43.5mm" height="20mm" fill="light" color="border" strokeWidth="0.5" cornerRadius="3pt"/>
            <Text x="109mm" y="27mm" width="39.5mm" height="5mm" fontSize="7.5" color="muted" alignment="center">قيمة المخزون (د.ل)</Text>
            <Text x="109mm" y="33mm" width="39.5mm" height="9mm" fontSize="15" bold="true" alignment="center">{{SUM(item.qty * item.cost) | n0}}</Text>
            <Shape kind="RoundedRectangle" x="154.5mm" y="25mm" width="43.5mm" height="20mm" fill="#FEF2F2" color="#FECACA" strokeWidth="0.5" cornerRadius="3pt"/>
            <Text x="156.5mm" y="27mm" width="39.5mm" height="5mm" fontSize="7.5" color="alert" alignment="center">أصناف تحتاج إعادة طلب</Text>
            <Text x="156.5mm" y="33mm" width="39.5mm" height="9mm" fontSize="15" bold="true" color="alert" alignment="center">{{SUM(IF(item.qty &lt;= item.reorderLevel, 1, 0))}}</Text>
            <Chart x="12mm" y="50mm" width="112mm" height="66mm" chartType="horizontalBar" title="أعلى الأصناف قيمةً" dataSet="Data.items" category="Row.name" value="Row.qty * Row.cost" sortBy="value" sortOrder="desc" limit="7" showValues="true" showLegend="false" showGrid="false" valueFormat="n0" borderColor="border" borderWidth="0.5pt" palette="#EA580C"/>
            <Chart x="128mm" y="50mm" width="70mm" height="66mm" chartType="pie" title="القيمة حسب الفئة" dataSet="Data.items" category="Row.category" value="Row.qty * Row.cost" sortBy="value" sortOrder="desc" showValues="true" borderColor="border" borderWidth="0.5pt" palette="#7C2D12,#EA580C,#F59E0B,#FDBA74,#A16207,#78716C"/>
            <Text x="12mm" y="119mm" width="186mm" height="7mm" fontSize="11" bold="true" color="primary">تفاصيل الأصناف حسب الفئة</Text>
        </ReportHeader>
        <PageHeader height="9mm" printOnFirstPage="false">
            <Text x="12mm" y="1mm" width="186mm" height="6mm" fontSize="8" color="muted">تقرير حالة المخزون — {{Data.warehouse}} — تابع</Text>
            <Line x1="12mm" y1="7.5mm" x2="198mm" y2="7.5mm" color="border" strokeWidth="0.5"/>
        </PageHeader>
        <GroupHeader height="10mm" groupBy="item.category" keepTogether="true">
            <Shape kind="RoundedRectangle" x="12mm" y="1.5mm" width="186mm" height="7.5mm" fill="light" strokeWidth="0" cornerRadius="2pt"/>
            <Text x="15mm" y="1.5mm" width="120mm" height="7.5mm" fontSize="9.5" bold="true" color="primary" verticalAlignment="middle">الفئة: {{Group.Key}}</Text>
            <Text x="138mm" y="1.5mm" width="57mm" height="7.5mm" fontSize="8" color="muted" alignment="end" verticalAlignment="middle">{{Group.Count}} صنف</Text>
        </GroupHeader>
        <Detail dataSet="items" sortBy="item.name" height="15mm">
            <Table x="12mm" y="0mm" width="186mm" showGrid="true" borderColor="border" headerBackground="#FFFFFF" headerColor="muted" stripeColor="#FFFBF7" fontSize="8.5" headerFontSize="8" rowHeight="6.8mm" headerHeight="7mm" padding="2pt">
                <Columns>
                    <Column width="20mm" header="الرمز" align="center"/>
                    <Column width="50mm" header="الصنف" align="start"/>
                    <Column width="16mm" header="الوحدة" align="center"/>
                    <Column width="18mm" header="الكمية" align="center"/>
                    <Column width="18mm" header="حد الطلب" align="center"/>
                    <Column width="20mm" header="التكلفة" align="center"/>
                    <Column width="24mm" header="القيمة" align="center"/>
                    <Column width="20mm" header="الحالة" align="center"/>
                </Columns>
                <RowTemplate>
                    <Cell field="item.code"/>
                    <Cell field="item.name"/>
                    <Cell field="item.unit"/>
                    <Cell field="item.qty" format="n0"/>
                    <Cell field="item.reorderLevel" format="n0"/>
                    <Cell field="item.cost" format="n3"/>
                    <Cell field="item.qty * item.cost" format="n3" bold="true"/>
                    <Cell field="IF(item.qty &lt;= item.reorderLevel, 'إعادة طلب', 'متوفر')" bold="true"/>
                </RowTemplate>
            </Table>
        </Detail>
        <GroupFooter height="10mm">
            <Text x="120mm" y="1.5mm" width="40mm" height="6.5mm" fontSize="8.5" bold="true" color="muted" verticalAlignment="middle">قيمة الفئة</Text>
            <Text x="160mm" y="1.5mm" width="38mm" height="6.5mm" fontSize="8.5" bold="true" alignment="end" verticalAlignment="middle">{{SUM(item.qty * item.cost) | currency:LYD}}</Text>
        </GroupFooter>
        <ReportSummary height="26mm" keepTogether="true">
            <Shape kind="RoundedRectangle" x="12mm" y="3mm" width="186mm" height="10mm" fill="primary" strokeWidth="0" cornerRadius="3pt"/>
            <Text x="16mm" y="3mm" width="90mm" height="10mm" fontSize="10" bold="true" color="#FFFFFF" verticalAlignment="middle">إجمالي قيمة المخزون</Text>
            <Text x="120mm" y="3mm" width="74mm" height="10mm" fontSize="11" bold="true" color="#FFFFFF" alignment="end" verticalAlignment="middle">{{SUM(item.qty * item.cost) | currency:LYD}}</Text>
            <Text x="12mm" y="15mm" width="186mm" height="8mm" fontSize="8.5" color="muted">{{TAFQEET(SUM(item.qty * item.cost), 'LYD')}}</Text>
        </ReportSummary>
        <PageFooter height="9mm">
            <Line x1="12mm" y1="1mm" x2="198mm" y2="1mm" color="border" strokeWidth="0.5"/>
            <Text x="12mm" y="2.5mm" width="120mm" height="5.5mm" fontSize="7.5" color="muted">أعدّه: {{Data.preparedBy}}</Text>
            <Text x="148mm" y="2.5mm" width="50mm" height="5.5mm" fontSize="7.5" color="muted" alignment="end">صفحة {{System.PageNumber}} من {{System.TotalPages}}</Text>
        </PageFooter>
    </Bands>
</QudsReport>
''';

Map<String, Object?> _inventoryArData() {
  final List<(String, String, String, String, int, int, num)> rows =
      <(String, String, String, String, int, int, num)>[
        ('LP-1420', 'حاسوب محمول 14 بوصة', 'حواسيب', 'قطعة', 18, 10, 2650),
        ('LP-1560', 'حاسوب محمول 15.6 بوصة', 'حواسيب', 'قطعة', 7, 8, 2980),
        ('DT-0700', 'حاسوب مكتبي متكامل', 'حواسيب', 'قطعة', 11, 5, 3400),
        ('MN-2401', 'شاشة 24 بوصة', 'شاشات', 'قطعة', 26, 12, 640),
        ('MN-2701', 'شاشة 27 بوصة 4K', 'شاشات', 'قطعة', 9, 10, 1050),
        ('KB-0310', 'لوحة مفاتيح لاسلكية', 'ملحقات', 'قطعة', 64, 30, 78),
        ('MS-0450', 'فأرة لاسلكية', 'ملحقات', 'قطعة', 22, 30, 42),
        ('HS-0200', 'سماعة رأس بميكروفون', 'ملحقات', 'قطعة', 35, 15, 115),
        ('PR-9100', 'طابعة ليزر ملونة', 'طابعات', 'قطعة', 4, 3, 1850),
        ('PR-9050', 'طابعة ليزر أبيض وأسود', 'طابعات', 'قطعة', 6, 4, 920),
        ('TN-9100', 'حبر طابعة ملون', 'طابعات', 'علبة', 12, 20, 260),
        ('CB-0006', 'كابل شبكة Cat6', 'شبكات', 'لفة', 9, 4, 380),
        ('SW-2400', 'محول شبكة 24 منفذ', 'شبكات', 'قطعة', 5, 3, 1150),
        ('RT-0600', 'موجه لاسلكي', 'شبكات', 'قطعة', 2, 4, 560),
      ];
  return <String, Object?>{
    'warehouse': 'المستودع الرئيسي — طرابلس',
    'date': DateTime(2026, 10, 10),
    'preparedBy': 'قسم المخازن',
    'items': <Map<String, Object?>>[
      for (final (String, String, String, String, int, int, num) r in rows)
        <String, Object?>{
          'code': r.$1,
          'name': r.$2,
          'category': r.$3,
          'unit': r.$4,
          'qty': r.$5,
          'reorderLevel': r.$6,
          'cost': r.$7,
        },
    ],
  };
}

// ------------------------------------------------------------- receipt AR

const String _receiptVoucherAr = r'''<?xml version="1.0" encoding="UTF-8"?>
<QudsReport name="سند قبض" isRtl="true" pageSize="A5" orientation="Landscape" defaultFont="Noto Naskh Arabic" defaultFontSize="10">
    <Settings>
        <Margins top="10mm" bottom="10mm" left="10mm" right="10mm"/>
        <Colors primary="#1E3A8A" accent="#2563EB" muted="#64748B" light="#EFF4FF" line="#94A3B8" text="#111827"/>
    </Settings>
    <Bands>
        <ReportHeader height="128mm">
            <Shape kind="RoundedRectangle" x="10mm" y="0mm" width="190mm" height="127mm" color="primary" strokeWidth="1.2" cornerRadius="5pt"/>
            <Text x="16mm" y="5mm" width="70mm" height="8mm" fontSize="13" bold="true" color="primary">{{Data.company.name}}</Text>
            <Text x="16mm" y="13mm" width="70mm" height="5mm" fontSize="8" color="muted">{{Data.company.address}} — &#x2066;{{Data.company.phone}}&#x2069;</Text>
            <Text x="75mm" y="4mm" width="60mm" height="11mm" fontSize="22" bold="true" color="primary" alignment="center">سند قبض</Text>
            <Text x="75mm" y="15mm" width="60mm" height="5mm" fontSize="8" color="muted" alignment="center" direction="ltr">RECEIPT VOUCHER</Text>
            <Shape kind="RoundedRectangle" x="148mm" y="5mm" width="46mm" height="16mm" fill="light" strokeWidth="0" cornerRadius="3pt"/>
            <Text x="151mm" y="6mm" width="40mm" height="7mm" fontSize="9.5" bold="true" verticalAlignment="middle">رقم: {{Data.voucher.number}}</Text>
            <Text x="151mm" y="13mm" width="40mm" height="7mm" fontSize="9" color="muted" verticalAlignment="middle">التاريخ: {{Data.voucher.date | date:dd/MM/yyyy}}</Text>
            <Line x1="16mm" y1="24mm" x2="194mm" y2="24mm" color="accent" strokeWidth="0.8"/>
            <Text x="16mm" y="28mm" width="30mm" height="12mm" fontSize="10" bold="true" color="primary" verticalAlignment="middle">المبلغ</Text>
            <Shape kind="RoundedRectangle" x="46mm" y="28mm" width="62mm" height="12mm" fill="light" color="accent" strokeWidth="0.8" cornerRadius="3pt"/>
            <Text x="46mm" y="28mm" width="62mm" height="12mm" fontSize="14" bold="true" alignment="center" verticalAlignment="middle">{{Data.voucher.amount | currency:LYD}}</Text>
            <Text x="16mm" y="46mm" width="44mm" height="8mm" fontSize="10" color="muted" verticalAlignment="bottom">استلمنا من السيد/ السادة:</Text>
            <Text x="60mm" y="46mm" width="134mm" height="8mm" fontSize="11" bold="true" verticalAlignment="bottom">{{Data.voucher.receivedFrom}}</Text>
            <Line x1="60mm" y1="54.5mm" x2="194mm" y2="54.5mm" color="line" strokeWidth="0.6" lineStyle="dotted"/>
            <Text x="16mm" y="58mm" width="44mm" height="8mm" fontSize="10" color="muted" verticalAlignment="bottom">مبلغًا وقدره:</Text>
            <Text x="60mm" y="58mm" width="134mm" height="8mm" fontSize="10" bold="true" verticalAlignment="bottom">{{TAFQEET(Data.voucher.amount, 'LYD')}}</Text>
            <Line x1="60mm" y1="66.5mm" x2="194mm" y2="66.5mm" color="line" strokeWidth="0.6" lineStyle="dotted"/>
            <Text x="16mm" y="70mm" width="44mm" height="8mm" fontSize="10" color="muted" verticalAlignment="bottom">وذلك عن:</Text>
            <Text x="60mm" y="70mm" width="134mm" height="8mm" fontSize="10" bold="true" verticalAlignment="bottom">{{Data.voucher.purpose}}</Text>
            <Line x1="60mm" y1="78.5mm" x2="194mm" y2="78.5mm" color="line" strokeWidth="0.6" lineStyle="dotted"/>
            <Text x="16mm" y="82mm" width="26mm" height="8mm" fontSize="10" color="muted" verticalAlignment="bottom">طريقة الدفع:</Text>
            <Text x="42mm" y="82mm" width="36mm" height="8mm" fontSize="10" bold="true" verticalAlignment="bottom">{{Data.voucher.method}}</Text>
            <Text x="80mm" y="82mm" width="22mm" height="8mm" fontSize="10" color="muted" verticalAlignment="bottom">رقم الشيك:</Text>
            <Text x="102mm" y="82mm" width="32mm" height="8mm" fontSize="10" bold="true" verticalAlignment="bottom">{{COALESCE(Data.voucher.chequeNo, '—')}}</Text>
            <Text x="136mm" y="82mm" width="16mm" height="8mm" fontSize="10" color="muted" verticalAlignment="bottom">المصرف:</Text>
            <Text x="152mm" y="82mm" width="42mm" height="8mm" fontSize="10" bold="true" verticalAlignment="bottom">{{COALESCE(Data.voucher.bank, '—')}}</Text>
            <Line x1="42mm" y1="90.5mm" x2="194mm" y2="90.5mm" color="line" strokeWidth="0.6" lineStyle="dotted"/>
            <Line x1="22mm" y1="112mm" x2="62mm" y2="112mm" color="line" strokeWidth="0.6"/>
            <Text x="22mm" y="113mm" width="40mm" height="6mm" fontSize="9" color="muted" alignment="center">المستلم</Text>
            <Line x1="85mm" y1="112mm" x2="125mm" y2="112mm" color="line" strokeWidth="0.6"/>
            <Text x="85mm" y="113mm" width="40mm" height="6mm" fontSize="9" color="muted" alignment="center">المحاسب</Text>
            <Line x1="148mm" y1="112mm" x2="188mm" y2="112mm" color="line" strokeWidth="0.6"/>
            <Text x="148mm" y="113mm" width="40mm" height="6mm" fontSize="9" color="muted" alignment="center">المدير المالي</Text>
            <QrCode x="176mm" y="26mm" width="18mm" height="18mm" value="RCV:{{Data.voucher.number}};AMT:{{Data.voucher.amount | n3}}"/>
        </ReportHeader>
    </Bands>
</QudsReport>
''';

Map<String, Object?> _receiptVoucherArData() => <String, Object?>{
  'company': <String, Object?>{
    'name': 'شركة القدس للتقنية',
    'address': 'طرابلس — شارع الجمهورية',
    'phone': '+218 21 444 0101',
  },
  'voucher': <String, Object?>{
    'number': 'RCV-2026-0339',
    'date': DateTime(2026, 10, 10),
    'amount': 3750.5,
    'receivedFrom': 'مؤسسة النور للتجارة العامة',
    'purpose': 'سداد جزئي لفاتورة المبيعات رقم INV-2026-0142',
    'method': 'شيك',
    'chequeNo': '55120',
    'bank': 'مصرف الجمهورية',
  },
};
