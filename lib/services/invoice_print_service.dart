import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:exanor/services/api_service.dart';
import 'package:http/http.dart' as http;

class InvoicePrintService {
  static Future<bool> printPosInvoice(
    String orderId, {
    String type = 'quick', // 'quick' (2 tickets+invoice), 'invoice', 'ticket'
    double widthInMm = 76.2, // 210 for A4, 76.2 for 3", 50.8 for 2"
  }) async {
    try {
      final response = await ApiService.post(
        '/generate-custom-invoice-data/',
        body: {"order_id": orderId, "width_in_mm": widthInMm},
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final responseData = response['data'];
        Map<String, dynamic>? invoiceData;

        // Safely extract the 'data' payload, which may be wrapped in a 'body'
        if (responseData['body'] != null &&
            responseData['body']['data'] != null) {
          invoiceData = responseData['body']['data'];
        } else if (responseData['data'] != null &&
            responseData['data'] is Map) {
          invoiceData = responseData['data'];
        }

        if (invoiceData != null) {
          await _generateAndPrintPdf(
            invoiceData,
            type: type,
            widthInMm: widthInMm,
          );
          return true;
        } else {
          print(
            "Failed to find invoice data payload in response: $responseData",
          );
          return false;
        }
      } else {
        print("API request failed: $response");
        return false;
      }
    } catch (e) {
      print("Error printing POS invoice: $e");
      return false;
    }
  }

  static Future<void> _generateAndPrintPdf(
    Map<String, dynamic> data, {
    String type = 'quick',
    double widthInMm = 76.2,
  }) async {
    final pdf = pw.Document();

    final PdfPageFormat format;
    if (widthInMm >= 210.0) {
      format = PdfPageFormat.a4;
    } else if (widthInMm <= 50.8) {
      format = PdfPageFormat.roll57;
    } else {
      format = PdfPageFormat.roll80;
    }

    pw.ImageProvider? logoImage;
    if (data['store_logo_img_url'] != null &&
        data['store_logo_img_url'].toString().isNotEmpty) {
      try {
        final logoBytes = await http.readBytes(
          Uri.parse(data['store_logo_img_url']),
        );
        logoImage = pw.MemoryImage(logoBytes);
      } catch (e) {
        print("Error loading logo image: $e");
      }
    }

    final storeInfo = data['store_info'] ?? {};
    final userInfo = data['user_info'] ?? {};
    final products = data['products'] as List? ?? [];
    final cartTotal = data['cart_total'] as List? ?? [];
    final platformFees = data['platform_fees'] as List? ?? [];
    final grandTotal = data['grand_total'] ?? 0;
    final qrCodeUrl = data['qr_code_url'] ?? '';

    pw.Widget buildTicket() {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Text(
              "KITCHEN TICKET",
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.Text(
            "Store: ${storeInfo['name'] ?? ''}",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text("Order No: ${storeInfo['order_number'] ?? ''}"),
          if (userInfo['name'] != null && userInfo['name'] != 'unnamed user')
            pw.Text("Customer: ${userInfo['name']}"),
          pw.Text("Date: ${DateTime.now().toString().substring(0, 16)}"),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.Text(
            "ITEMS:",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          ...products.map(
            (p) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      "${p['quantity']}x ${p['product_name']}",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 30), // Padding at bottom for tearing
        ],
      );
    }

    pw.Widget buildInvoice() {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Column(
              children: [
                if (logoImage != null)
                  pw.Image(logoImage, height: 60, width: 60),
                if (logoImage != null) pw.SizedBox(height: 5),
                pw.Text(
                  storeInfo['name'] ?? '',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                if (storeInfo['address'] != null)
                  pw.Text(storeInfo['address'], textAlign: pw.TextAlign.center),
                if (storeInfo['phone'] != null)
                  pw.Text(
                    "Phone: ${storeInfo['phone']}",
                    textAlign: pw.TextAlign.center,
                  ),
                if (storeInfo['gst_number'] != null)
                  pw.Text(
                    "GSTIN: ${storeInfo['gst_number']}",
                    textAlign: pw.TextAlign.center,
                  ),
              ],
            ),
          ),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.Text("Bill No: ${storeInfo['bill_number'] ?? ''}"),
          pw.Text("Order No: ${storeInfo['order_number'] ?? ''}"),
          pw.Text("Date: ${DateTime.now().toString().substring(0, 16)}"),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.Text("Customer: ${userInfo['name'] ?? 'Guest'}"),
          if (userInfo['phone'] != null) pw.Text("Phone: ${userInfo['phone']}"),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  "Item",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Text(
                  "Qty",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  "Amount",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),

          ...products.map((p) {
            final pricing = p['pricing_details'] ?? {};
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(flex: 3, child: pw.Text(p['product_name'] ?? '')),
                  pw.Expanded(flex: 1, child: pw.Text("${p['quantity'] ?? 0}")),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      "${pricing['selling_amount_including_tax'] ?? 0}",
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),

          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          ...cartTotal.map(
            (item) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(item['title'] ?? ''),
                pw.Text("${item['value'] ?? 0}", textAlign: pw.TextAlign.right),
              ],
            ),
          ),
          ...platformFees.map(
            (item) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(item['title'] ?? ''),
                pw.Text("${item['value'] ?? 0}", textAlign: pw.TextAlign.right),
              ],
            ),
          ),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "GRAND TOTAL",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              pw.Text(
                "$grandTotal",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

          if (qrCodeUrl.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.SizedBox(
                height: 100,
                width: 100,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrCodeUrl,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
          ],

          pw.Center(
            child: pw.Text(
              "Thank you for your visit!",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15),
            ),
          ),
          if (data['refund_policy'] != null &&
              data['refund_policy'].toString().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              data['refund_policy'],
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
          pw.SizedBox(height: 30), // Padding at bottom for tearing
        ],
      );
    }

    if (type == 'quick' || type == 'ticket') {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(10),
          build: (pw.Context context) => buildTicket(),
        ),
      );
      if (type == 'quick') {
        pdf.addPage(
          pw.Page(
            pageFormat: format,
            margin: const pw.EdgeInsets.all(10),
            build: (pw.Context context) => buildTicket(),
          ),
        );
      }
    }

    if (type == 'quick' || type == 'invoice') {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(10),
          build: (pw.Context context) => buildInvoice(),
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat defaultFormat) async => pdf.save(),
    );
  }
}
