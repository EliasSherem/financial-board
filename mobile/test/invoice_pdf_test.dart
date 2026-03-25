import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/lang_store.dart';
import 'package:mobile/models.dart';
import 'package:mobile/utils/invoice_pdf.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('formatInvoiceMoney uses only the dollar sign for USD and MXN', () {
    expect(formatInvoiceMoney(50000, 'USD'), r'$50,000.00');
    expect(formatInvoiceMoney(50000, 'MXN'), r'$50,000.00');
  });

  testWidgets('buildInvoicePdf creates a PDF document', (tester) async {
    final langStore = LangStore();
    late BuildContext capturedContext;

    await tester.pumpWidget(
      ChangeNotifierProvider<LangStore>.value(
        value: langStore,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final detail = InvoiceDetail(
      invoice: InvoiceSummary(
        id: 42,
        number: 'INV-42',
        customerName: 'Acme Corp',
        customerEmail: 'billing@acme.test',
        customerCompany: 'Acme Corp',
        customerTaxId: 'RFC123456',
        customerAddress: '123 Invoice Street',
        status: 'sent',
        currency: 'MXN',
        notes: 'Thank you for your business.',
        issueDate: DateTime(2026, 3, 16),
        dueDate: DateTime(2026, 3, 23),
        subtotal: 100,
        discount: 10,
        tax: 14.4,
        total: 104.4,
        amountDue: 104.4,
      ),
      items: [
        InvoiceItem(
          description: 'Consulting services',
          quantity: 2,
          unitPrice: 50,
          amount: 100,
        ),
      ],
      payments: const [],
    );

    final pdfBytes = await buildInvoicePdf(capturedContext, detail, 'sherelyn');

    expect(pdfBytes, isNotEmpty);
    expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
  });
}
