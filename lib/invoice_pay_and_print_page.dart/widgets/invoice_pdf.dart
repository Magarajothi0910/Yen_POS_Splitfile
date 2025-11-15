// lib/Global/Services/invoice_pdf_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class InvoicePdfService {
  static Future<File> generateInvoicePdf({
    required String billNumber,
    required String customerName,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String? date,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'YEN POS INVOICE',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Invoice No: $billNumber'),
          pw.Text('Customer: $customerName'),
          pw.Text('Date: ${date ?? DateTime.now()}'),
          pw.Divider(),

          pw.Table.fromTextArray(
            headers: ['Item', 'Qty', 'Rate', 'Total'],
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            data: items.map((item) {
              final name = item['itemName'] ?? '';
              final qty = item['quantity']?.toString() ?? '0';
              final rate = (item['varianceData']?['variance_Defaultprice'] ?? 0).toString();
              final total = (item['totalPrice'] ?? 0).toStringAsFixed(2);
              return [name, qty, rate, total];
            }).toList(),
          ),

          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Grand Total: ₹${totalAmount.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Center(
            child: pw.Text(
              'Thank you for shopping with us!',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/invoices');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final file = File('${folder.path}/$billNumber.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // static Future<void> viewInvoice(File pdfFile) async {
  //   await Printing.layoutPdf(onLayout: (_) => pdfFile.readAsBytes());
  // }

  static Future<void> shareInvoice(File pdfFile, {String? message}) async {
    await Share.shareXFiles([XFile(pdfFile.path)], text: message ?? "Invoice PDF");
  }

  static Future<void> openInvoice(File pdfFile) async {
    await OpenFilex.open(pdfFile.path);
  }
}
