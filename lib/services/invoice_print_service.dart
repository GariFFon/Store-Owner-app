import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/models/receipt_layout_config.dart';
import 'package:http/http.dart' as http;

class InvoicePrintService {
  /// Whether we're on a desktop platform (Windows/macOS/Linux)
  /// Direct printing (listPrinters/directPrintPdf) only works on desktop.
  /// On mobile, we always use the system print dialog.
  static bool get isDesktop {
    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

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

  /// Generate PDF bytes for a POS receipt.
  /// Shared between desktop printing and Bluetooth image-based printing.
  static Future<Uint8List> generatePdfBytes(
    Map<String, dynamic> data, {
    String type = 'quick',
    double widthInMm = 76.2,
  }) async {
    final pdf = pw.Document();

    final productsCount = (data['products'] as List? ?? []).length;
    // Estimate max height required for the invoice/ticket:
    // Base height for headers/footers/QR code/totals + lines per product
    double estimatedHeightMm = 200.0 + (productsCount * 12.0);

    // Determine if this is a narrow (2-inch) receipt
    final bool isNarrow = widthInMm <= 50.8;
    final bool isA4 = widthInMm >= 210.0;

    // Adaptive sizing based on paper width
    // For 2-inch printers, use smaller width (46mm) to account for
    // the printer's own non-printable margins on each side
    final double effectiveWidthMm = isNarrow ? 46.0 : widthInMm;
    final double marginMm = isNarrow ? 3.0 : (isA4 ? 20.0 : 5.0);
    final double storeNameSize = isNarrow ? 10.0 : (isA4 ? 18.0 : 14.0);
    final double headerSize = isNarrow ? 9.0 : (isA4 ? 16.0 : 12.0);
    final double bodySize = isNarrow ? 8.0 : (isA4 ? 11.0 : 9.0);
    final double smallSize = isNarrow ? 7.0 : (isA4 ? 9.0 : 7.5);

    final double grandTotalSize = isNarrow ? 9.0 : (isA4 ? 14.0 : 11.0);
    final double thankYouSize = isNarrow ? 8.0 : (isA4 ? 15.0 : 11.0);
    final double logoSize = isNarrow ? 30.0 : (isA4 ? 60.0 : 50.0);
    final double qrSize = isNarrow ? 50.0 : (isA4 ? 100.0 : 80.0);
    final double itemSpacing = isNarrow ? 1.0 : 2.0;
    final double sectionSpacing = isNarrow ? 3.0 : 5.0;

    // Bold style for thermal printer readability
    final pw.FontWeight boldWeight = pw.FontWeight.bold;

    // Column flex ratios for item table (give more space to item name on narrow)
    final int itemFlex = isNarrow ? 5 : 3;
    final int amountFlex = isNarrow ? 2 : 2;

    final PdfPageFormat pageFormat;

    if (isA4) {
      pageFormat = PdfPageFormat.a4;
    } else {
      final double widthPt = effectiveWidthMm * PdfPageFormat.mm;
      final double heightPt = estimatedHeightMm * PdfPageFormat.mm;
      final double marginPt = marginMm * PdfPageFormat.mm;
      final double marginRightPt = (isNarrow ? 2.0 : 3.0) * PdfPageFormat.mm;
      pageFormat = PdfPageFormat(widthPt, heightPt, marginLeft: marginPt, marginRight: marginRightPt, marginTop: marginPt, marginBottom: marginPt);
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
              style: pw.TextStyle(fontSize: headerSize, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
          pw.Text(
            "Store: ${storeInfo['name'] ?? ''}",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: bodySize),
          ),
          pw.Text("Order ID: ${storeInfo['order_number'] ?? ''}", style: pw.TextStyle(fontSize: bodySize, fontWeight: boldWeight)),
          if (userInfo['name'] != null && userInfo['name'] != 'unnamed user')
            pw.Text("Customer: ${userInfo['name']}", style: pw.TextStyle(fontSize: bodySize, fontWeight: boldWeight)),
          pw.Text("Date: ${DateTime.now().toString().substring(0, 16)}", style: pw.TextStyle(fontSize: bodySize, fontWeight: boldWeight)),
          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
          pw.Text(
            "ITEMS:",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: bodySize),
          ),
          pw.SizedBox(height: sectionSpacing),
          ...products.map(
            (p) => pw.Padding(
              padding: pw.EdgeInsets.symmetric(vertical: itemSpacing),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      "${p['quantity']}x ${p['product_name']}",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: isNarrow ? 8.0 : 13.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 20),
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
                  pw.Image(logoImage, height: logoSize, width: logoSize),
                if (logoImage != null) pw.SizedBox(height: 3),
                pw.Text(
                  storeInfo['name'] ?? '',
                  style: pw.TextStyle(
                    fontSize: storeNameSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                if (storeInfo['address'] != null)
                  pw.Text(
                    storeInfo['address'],
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: smallSize, fontWeight: boldWeight),
                  ),
                if (storeInfo['phone'] != null)
                  pw.Text(
                    "Ph: ${storeInfo['phone']}",
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: smallSize, fontWeight: boldWeight),
                  ),
                if (storeInfo['gst_number'] != null)
                  pw.Text(
                    "GSTIN: ${storeInfo['gst_number']}",
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: smallSize, fontWeight: boldWeight),
                  ),
              ],
            ),
          ),
          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
          pw.Text(
            "Bill No: ${storeInfo['bill_number'] ?? ''}",
            style: pw.TextStyle(fontSize: smallSize, fontWeight: boldWeight),
          ),
          pw.Text(
            "Token No: ${storeInfo['token_number'] ?? ''}",
            style: pw.TextStyle(fontSize: smallSize, fontWeight: boldWeight),
          ),
          pw.Text(
            "Date: ${DateTime.now().toString().substring(0, 16)}",
            style: pw.TextStyle(fontSize: smallSize, fontWeight: boldWeight),
          ),
          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
          pw.Text(
            "Customer: ${userInfo['name'] ?? 'Guest'}",
            style: pw.TextStyle(fontSize: smallSize, fontWeight: boldWeight),
          ),
          if (userInfo['phone'] != null)
            pw.Text(
              "Phone: ${userInfo['phone']}",
              style: pw.TextStyle(fontSize: smallSize, fontWeight: boldWeight),
            ),
          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

          // Table header
          pw.Row(
            children: [
              pw.Expanded(
                flex: itemFlex,
                child: pw.Text(
                  "Item",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: smallSize),
                ),
              ),
              pw.SizedBox(
                width: isNarrow ? 18 : 30,
                child: pw.Text(
                  "Qty",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: smallSize),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Expanded(
                flex: amountFlex,
                child: pw.Text(
                  "Amt",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: smallSize),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),

          // Product rows
          ...products.map((p) {
            final pricing = p['pricing_details'] ?? {};
            return pw.Padding(
              padding: pw.EdgeInsets.symmetric(vertical: itemSpacing),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: itemFlex,
                    child: pw.Text(
                      p['product_name'] ?? '',
                      style: pw.TextStyle(fontSize: smallSize, fontWeight: boldWeight),
                    ),
                  ),
                  pw.SizedBox(
                    width: isNarrow ? 18 : 30,
                    child: pw.Text(
                      "${p['quantity'] ?? 0}",
                      style: pw.TextStyle(fontSize: smallSize, fontWeight: boldWeight),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: amountFlex,
                    child: pw.Text(
                      "${pricing['selling_amount_including_tax'] ?? 0}",
                      style: pw.TextStyle(fontSize: smallSize, fontWeight: boldWeight),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),

          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
          // Cart totals
          ...cartTotal.map(
            (item) => pw.Padding(
              padding: pw.EdgeInsets.symmetric(vertical: itemSpacing),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      item['title'] ?? '',
                      style: pw.TextStyle(fontSize: smallSize),
                    ),
                  ),
                  pw.Text(
                    "${item['value'] ?? 0}",
                    style: pw.TextStyle(fontSize: smallSize),
                    textAlign: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
          // Platform fees
          ...platformFees.map(
            (item) => pw.Padding(
              padding: pw.EdgeInsets.symmetric(vertical: itemSpacing),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      item['title'] ?? '',
                      style: pw.TextStyle(fontSize: smallSize, fontWeight: boldWeight),
                    ),
                  ),
                  pw.Text(
                    "${item['value'] ?? 0}",
                    style: pw.TextStyle(fontSize: smallSize, fontWeight: boldWeight),
                    textAlign: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
          // Grand total
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "GRAND TOTAL",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: grandTotalSize,
                ),
              ),
              pw.Text(
                "$grandTotal",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: grandTotalSize,
                ),
              ),
            ],
          ),
          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

          // QR Code
          if (qrCodeUrl.isNotEmpty) ...[
            pw.SizedBox(height: sectionSpacing),
            pw.Center(
              child: pw.SizedBox(
                height: qrSize,
                width: qrSize,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrCodeUrl,
                ),
              ),
            ),
            pw.SizedBox(height: sectionSpacing),
          ],

          pw.Center(
            child: pw.Text(
              "Thank you for your visit!",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: thankYouSize),
            ),
          ),
          pw.SizedBox(height: 20),
        ],
      );
    }

    // Build pages using the correct pageFormat (not the built-in roll formats)
    final pw.EdgeInsets pageMargin = isA4
        ? const pw.EdgeInsets.all(20)
        : pw.EdgeInsets.all(isNarrow ? 4 : 6);

    if (type == 'quick' || type == 'ticket') {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pageMargin,
          build: (pw.Context context) => buildTicket(),
        ),
      );
      if (type == 'quick') {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pageMargin,
            build: (pw.Context context) => buildTicket(),
          ),
        );
      }
    }

    if (type == 'quick' || type == 'invoice') {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pageMargin,
          build: (pw.Context context) => buildInvoice(),
        ),
      );
    }

    return await pdf.save();
  }

  // ─── Auto-Cut ESC/POS Commands ─────────────────────────────────

  /// Get ESC/POS auto-cut command bytes
  /// GS V 66 n — Select cut mode and cut paper
  /// n = number of feed lines before cut (0-255)
  static Uint8List getAutoCutBytes({int feedLines = 3}) {
    // ESC/POS: GS V 66 n (partial cut with n lines feed)
    return Uint8List.fromList([0x1D, 0x56, 0x42, feedLines]);
  }

  /// Get ESC/POS full cut command bytes
  static Uint8List getFullCutBytes() {
    // ESC/POS: GS V 0 (full cut)
    return Uint8List.fromList([0x1D, 0x56, 0x00]);
  }

  /// Get feed and cut bytes (useful for ensuring content clears the cutter)
  static Uint8List getFeedAndCutBytes({int feedLines = 3}) {
    final bytes = <int>[];
    // Feed n lines
    for (int i = 0; i < feedLines; i++) {
      bytes.addAll([0x0A]); // LF - line feed
    }
    // Partial cut
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    return Uint8List.fromList(bytes);
  }

  /// Check if auto-cut is enabled in settings
  static Future<bool> isAutoCutEnabled() async {
    final config = await ReceiptLayoutConfig.load('receipt');
    return config.autoCutEnabled;
  }

  /// Get auto-cut feed lines from config
  static Future<int> getAutoCutFeedLines() async {
    final config = await ReceiptLayoutConfig.load('receipt');
    return config.autoCutFeedLines;
  }

  static Future<void> _generateAndPrintPdf(
    Map<String, dynamic> data, {
    String type = 'quick',
    double widthInMm = 76.2,
  }) async {
    final pdfBytes = await generatePdfBytes(data, type: type, widthInMm: widthInMm);

    // Compute page format for print dialog
    final productsCount = (data['products'] as List? ?? []).length;
    final bool isNarrow = widthInMm <= 50.8;
    final bool isA4 = widthInMm >= 210.0;
    final double estimatedHeightMm = 200.0 + (productsCount * 12.0);
    final double effectiveWidthMm = isNarrow ? 46.0 : widthInMm;
    final double marginMm = isNarrow ? 3.0 : (isA4 ? 20.0 : 5.0);

    final PdfPageFormat dialogFormat;

    if (isA4) {
      dialogFormat = PdfPageFormat.a4;
    } else {
      final double widthPt = effectiveWidthMm * PdfPageFormat.mm;
      final double heightPt = estimatedHeightMm * PdfPageFormat.mm;
      final double marginPt = marginMm * PdfPageFormat.mm;
      final double marginRightPt = (isNarrow ? 2.0 : 3.0) * PdfPageFormat.mm;
      dialogFormat = PdfPageFormat(widthPt, heightPt, marginLeft: marginPt, marginRight: marginRightPt, marginTop: marginPt, marginBottom: marginPt);
    }

    if (isDesktop) {
      final savedPrinter = await _getSavedPrinter();
      if (savedPrinter != null) {
        try {
          final printers = await Printing.listPrinters();
          final matchedPrinter = printers.firstWhere(
            (p) => p.url == savedPrinter['url'],
            orElse: () => printers.firstWhere(
              (p) => p.name == savedPrinter['name'],
              orElse: () => throw Exception('Saved printer not found'),
            ),
          );
          await Printing.directPrintPdf(
            printer: matchedPrinter,
            format: dialogFormat,
            usePrinterSettings: true,
            onLayout: (PdfPageFormat f) async => pdfBytes,
          );
          return;
        } catch (e) {
          print("Direct print failed, falling back to dialog: $e");
        }
      }
    }

    await Printing.layoutPdf(
      format: dialogFormat,
      usePrinterSettings: true,
      onLayout: (PdfPageFormat defaultFormat) async => pdfBytes,
    );
  }

  // --- Default Printer Management ---

  static const String _printerPrefKey = 'default_pos_printer';

  static Future<void> saveDefaultPrinter(Printer printer) async {
    final prefs = await SharedPreferences.getInstance();
    final printerData = jsonEncode({
      'name': printer.name,
      'url': printer.url,
    });
    await prefs.setString(_printerPrefKey, printerData);
  }

  static Future<Map<String, dynamic>?> _getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final printerJson = prefs.getString(_printerPrefKey);
    if (printerJson == null) return null;
    try {
      return jsonDecode(printerJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getSavedPrinterName() async {
    final data = await _getSavedPrinter();
    return data?['name'] as String?;
  }

  static Future<void> clearDefaultPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_printerPrefKey);
  }

  static Future<bool> showPrinterPickerDialog(BuildContext context) async {
    final printers = await Printing.listPrinters();
    final currentSaved = await _getSavedPrinter();
    final currentName = currentSaved?['name'];
    if (!context.mounted) return false;

    final selected = await showDialog<Printer>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              printers.isEmpty ? Icons.warning_amber_rounded : Icons.print_rounded,
              color: printers.isEmpty ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                printers.isEmpty ? 'No Printers Found' : 'Select Printer',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, top: 20, right: 20, bottom: 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        content: SizedBox(
          width: double.maxFinite,
          child: printers.isEmpty
              // ── Empty state ──
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.print_disabled_rounded, size: 48, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 12),
                      Text(
                        isDesktop
                            ? 'No printers are installed on this computer.\n\n'
                              'To add a printer:\n'
                              '1. Open Windows Settings\n'
                              '2. Go to Printers & scanners\n'
                              '3. Click "Add device"\n'
                              '4. Come back here and try again'
                            : 'No printers detected.\n\n'
                              '• Make sure your printer is on\n'
                              '• Check it\'s on the same network\n'
                              '• Install the manufacturer\'s app',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              // ── Printer list ──
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: printers.length,
                  itemBuilder: (context, index) {
                    final printer = printers[index];
                    final isSelected = printer.name == currentName;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                        color: isSelected ? const Color(0xFF10B981).withOpacity(0.05) : Colors.transparent,
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Icon(
                          Icons.print_rounded,
                          color: isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                        title: Text(
                          printer.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: printer.isDefault
                            ? const Text('System Default', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
                            : null,
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF10B981)) : null,
                        onTap: () => Navigator.pop(ctx, printer),
                      ),
                    );
                  },
                ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          if (!printers.isEmpty && currentName != null)
            TextButton.icon(
              onPressed: () async {
                await clearDefaultPrinter();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
              label: const Text('Clear', style: TextStyle(color: Color(0xFFEF4444))),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            )
          else
            const SizedBox.shrink(),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: const Color(0xFFF1F5F9),
              foregroundColor: const Color(0xFF475569),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(printers.isEmpty ? 'OK' : 'Cancel', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (selected != null) {
      await saveDefaultPrinter(selected);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Default printer set to: ${selected.name}')));
      }
      return true;
    }
    return false;
  }

  // --- Default Paper Size Management ---

  static const String _paperSizePrefKey = 'default_pos_paper_size';

  static const List<Map<String, dynamic>> paperSizeOptions = [
    {'label': '2 Inch (50.8mm)', 'widthInMm': 50.8},
    {'label': '3 Inch (76.2mm)', 'widthInMm': 76.2},
    {'label': 'A4 Size', 'widthInMm': 210.0},
  ];

  static Future<void> saveDefaultPaperSize(double widthInMm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_paperSizePrefKey, widthInMm);
    
    int chars = widthInMm <= 50.8 ? 32 : 48;
    final rConfig = await ReceiptLayoutConfig.load('receipt');
    rConfig.paperWidthChars = chars;
    await rConfig.save();

    final kConfig = await ReceiptLayoutConfig.load('kot');
    kConfig.paperWidthChars = chars;
    await kConfig.save();
  }

  static Future<double?> getSavedPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_paperSizePrefKey);
  }

  static String getPaperSizeLabel(double widthInMm) {
    for (final option in paperSizeOptions) {
      if (option['widthInMm'] == widthInMm) {
        return option['label'] as String;
      }
    }
    return '${widthInMm}mm';
  }

  // --- Printer Connection Type Management ---

  static const String _connectionTypePrefKey = 'pos_printer_connection_type';
  static const String connectionBluetooth = 'bluetooth';
  static const String connectionWifi = 'wifi';
  static const String connectionWired = 'wired';

  static Future<void> saveConnectionType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_connectionTypePrefKey, type);
  }

  static Future<String?> getSavedConnectionType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_connectionTypePrefKey);
  }

  static String getConnectionTypeLabel(String type) {
    switch (type) {
      case connectionBluetooth: return 'Bluetooth';
      case connectionWifi: return 'WiFi / Network';
      case connectionWired: return 'Wired (USB)';
      default: return 'Unknown';
    }
  }

  static IconData getConnectionTypeIcon(String type) {
    switch (type) {
      case connectionBluetooth: return Icons.bluetooth_rounded;
      case connectionWifi: return Icons.wifi_rounded;
      case connectionWired: return Icons.usb_rounded;
      default: return Icons.print_rounded;
    }
  }
}
