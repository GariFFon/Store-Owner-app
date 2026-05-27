import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/models/receipt_layout_config.dart';
import 'package:exanor/services/invoice_print_service.dart';

class BluetoothPrintService {
  static final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  static const String _btPrinterPrefKey = 'default_bt_printer';

  // ─── Connection Management ──────────────────────────────────────

  /// Check if Bluetooth is available and currently turned ON
  static Future<bool> isBluetoothAvailable() async {
    try {
      final available = await _bluetooth.isAvailable ?? false;
      if (!available) return false;
      return await _bluetooth.isOn ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Check if currently connected to a printer
  static Future<bool> isConnected() async {
    try {
      return await _bluetooth.isConnected ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get list of paired Bluetooth devices
  static Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await _bluetooth.getBondedDevices();
    } catch (e) {
      print("Error getting Bluetooth devices: $e");
      return [];
    }
  }

  /// Connect to a Bluetooth device
  static Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      final connected = await isConnected();
      if (connected) {
        await _bluetooth.disconnect();
      }
      await _bluetooth.connect(device);
      // Give it a moment to connect
      await Future.delayed(const Duration(seconds: 1));
      return await isConnected();
    } catch (e) {
      print("Error connecting to Bluetooth device: $e");
      return false;
    }
  }

  /// Disconnect from current device
  static Future<void> disconnect() async {
    try {
      await _bluetooth.disconnect();
    } catch (_) {}
  }

  // ─── Printer Preferences ─────────────────────────────────────────

  /// Save a Bluetooth printer as default
  static Future<void> savePrinter(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'name': device.name,
      'address': device.address,
      'type': device.type,
    });
    await prefs.setString(_btPrinterPrefKey, data);
  }

  /// Get saved default Bluetooth printer
  static Future<Map<String, dynamic>?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_btPrinterPrefKey);
    if (jsonStr == null) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Get just the saved printer name
  static Future<String?> getSavedPrinterName() async {
    final data = await getSavedPrinter();
    return data?['name'] as String?;
  }

  /// Check if a default Bluetooth printer is saved
  static Future<bool> hasDefaultPrinter() async {
    final data = await getSavedPrinter();
    return data != null;
  }

  /// Clear saved printer
  static Future<void> clearDefaultPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_btPrinterPrefKey);
  }

  /// Connect to the saved default printer
  static Future<bool> connectToSavedPrinter() async {
    final saved = await getSavedPrinter();
    if (saved == null) return false;

    final devices = await getPairedDevices();
    final device = devices.cast<BluetoothDevice?>().firstWhere(
      (d) => d?.address == saved['address'],
      orElse: () => null,
    );

    if (device == null) return false;
    return await connectToDevice(device);
  }

  // ─── Printer Picker Dialog ──────────────────────────────────────

  /// Show dialog to pick and save a Bluetooth printer
  static Future<bool> showPrinterPickerDialog(BuildContext context) async {
    final btSupported = await _bluetooth.isAvailable ?? false;
    if (!btSupported) {
      if (context.mounted) {
        showTopRightNotification(
          context,
          message: 'Bluetooth Unavailable',
          detail: 'This device does not support Bluetooth.',
          icon: Icons.bluetooth_disabled_rounded,
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 5),
        );
      }
      return false;
    }

    final btOn = await _bluetooth.isOn ?? false;
    if (!btOn) {
      if (context.mounted) {
        showTopRightNotification(
          context,
          message: 'Bluetooth is Turned Off',
          detail: 'Please turn on Bluetooth to scan for your printer.',
          icon: Icons.bluetooth_disabled_rounded,
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 5),
        );
      }
      return false;
    }

    final devices = await getPairedDevices();
    if (devices.isEmpty) {
      if (context.mounted) {
        showTopRightNotification(
          context,
          message: 'No Devices Found',
          detail: 'Pair your thermal printer in Settings > Bluetooth first.',
          icon: Icons.warning_amber_rounded,
          backgroundColor: const Color(0xFFF59E0B),
          duration: const Duration(seconds: 5),
        );
      }
      return false;
    }

    final currentSaved = await getSavedPrinter();
    final currentAddress = currentSaved?['address'];

    if (!context.mounted) return false;

    // Filter devices: separate likely printers from other devices
    final printerKeywords = [
      'printer',
      'thermal',
      'pos',
      'spp',
      'rpp',
      'pt-',
      'bp-',
      'print',
      'receipt',
      'label',
      'seznik',
      'epson',
      'star',
      'bixolon',
      'zebra',
      'tsc',
      'xprinter',
      'munbyn',
    ];
    final likelyPrinters = <BluetoothDevice>[];
    final otherDevices = <BluetoothDevice>[];

    for (final device in devices) {
      final name = (device.name ?? '').toLowerCase();
      // type 1536 (0x0600) = Imaging device (printers)
      final isPrinterType = device.type == 1536;
      final nameMatchesPrinter = printerKeywords.any((kw) => name.contains(kw));
      if (isPrinterType || nameMatchesPrinter) {
        likelyPrinters.add(device);
      } else {
        otherDevices.add(device);
      }
    }

    final selected = await showDialog<BluetoothDevice>(
      context: context,
      builder: (ctx) {
        bool showAll = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final displayDevices = showAll
                ? [...likelyPrinters, ...otherDevices]
                : likelyPrinters;
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bluetooth_rounded,
                            color: Color(0xFF3B82F6),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bluetooth Printer',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: SizedBox(
                          width: double.maxFinite,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (displayDevices.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 16,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.print_disabled_rounded,
                                        size: 48,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No printer devices found.\nTry "Show all devices" below.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Flexible(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: displayDevices.length,
                                    itemBuilder: (context, index) {
                                      final device = displayDevices[index];
                                      final isSelected =
                                          device.address == currentAddress;
                                      final isPrinter = likelyPrinters.contains(
                                        device,
                                      );
                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFE2E8F0),
                                            width: isSelected ? 2 : 1,
                                          ),
                                          color: isSelected
                                              ? const Color(
                                                  0xFF10B981,
                                                ).withOpacity(0.05)
                                              : Colors.transparent,
                                        ),
                                        child: ListTile(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          leading: Icon(
                                            isPrinter
                                                ? Icons.print_rounded
                                                : Icons.bluetooth_rounded,
                                            color: isSelected
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFF64748B),
                                          ),
                                          title: Text(
                                            device.name ?? 'Unknown Device',
                                            style: TextStyle(
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          subtitle: Text(
                                            device.address ?? '',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                          trailing: isSelected
                                              ? const Icon(
                                                  Icons.check_circle,
                                                  color: Color(0xFF10B981),
                                                )
                                              : null,
                                          onTap: () =>
                                              Navigator.pop(ctx, device),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              // "Show all" toggle
                              if (otherDevices.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextButton.icon(
                                    onPressed: () => setDialogState(
                                      () => showAll = !showAll,
                                    ),
                                    icon: Icon(
                                      showAll
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      size: 16,
                                      color: const Color(0xFF64748B),
                                    ),
                                    label: Text(
                                      showAll
                                          ? 'Show printers only (${likelyPrinters.length})'
                                          : 'Show all devices (${devices.length})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          currentAddress != null
                              ? TextButton.icon(
                                  onPressed: () async {
                                    await clearDefaultPrinter();
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFEF4444),
                                  ),
                                  label: const Text(
                                    'Clear',
                                    style: TextStyle(color: Color(0xFFEF4444)),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF475569),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      await savePrinter(selected);

      final connected = await connectToDevice(selected);

      if (context.mounted) {
        if (connected) {
          showTopRightNotification(
            context,
            message: 'Connected to ${selected.name ?? 'Unknown'} ✓',
            icon: Icons.check_circle_rounded,
            backgroundColor: const Color(0xFF10B981),
          );
        } else {
          showTopRightNotification(
            context,
            message: 'Could not connect to ${selected.name ?? 'Unknown'}',
            detail:
                'Printer may be off or out of range. Will retry when printing.',
            icon: Icons.warning_amber_rounded,
            backgroundColor: const Color(0xFFF59E0B),
          );
        }
      }
      return true;
    }
    return false;
  }

  // ─── Receipt Printing ───────────────────────────────────────────

  /// Print a POS invoice via Bluetooth
  static Future<bool> printPosInvoice(
    String orderId, {
    String type = 'quick',
    double widthInMm = 76.2,
  }) async {
    try {
      // Fetch invoice data from API
      final response = await ApiService.post(
        '/generate-custom-invoice-data/',
        body: {"order_id": orderId, "width_in_mm": widthInMm},
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final responseData = response['data'];
        Map<String, dynamic>? invoiceData;

        if (responseData['body'] != null &&
            responseData['body']['data'] != null) {
          invoiceData = responseData['body']['data'];
        } else if (responseData['data'] != null &&
            responseData['data'] is Map) {
          invoiceData = responseData['data'];
        }

        if (invoiceData != null) {
          // Ensure connection
          final connected = await isConnected();
          if (!connected) {
            final reconnected = await connectToSavedPrinter();
            if (!reconnected) {
              print("Cannot connect to Bluetooth printer");
              return false;
            }
          }

          // Print based on type
          if (type == 'quick' || type == 'ticket') {
            await _printTicket(invoiceData, widthInMm);
            if (type == 'quick') {
              await _printTicket(invoiceData, widthInMm); // 2nd ticket
            }
          }
          if (type == 'quick' || type == 'invoice') {
            await _printInvoice(invoiceData, widthInMm);
          }

          return true;
        }
      }

      print("API request failed: $response");
      return false;
    } catch (e) {
      print("Error Bluetooth printing: $e");
      return false;
    }
  }

  static Future<void> _printTicket(
    Map<String, dynamic> data,
    double widthInMm,
  ) async {
    final storeInfo = data['store_info'] ?? {};
    final userInfo = data['user_info'] ?? {};
    final products = data['products'] as List? ?? [];

    final config = await ReceiptLayoutConfig.load('kot');
    final int lineWidth = config.paperWidthChars;
    final int bSize = config.globalFontSize;
    print(
      '[BluetoothPrint] KOT config loaded: width=$lineWidth, fontSize=$bSize, sections=${config.enabledSections.map((s) => s.id).toList()}',
    );

    void printBreakLine() {
      if (config.showBreakLine) {
        String bl = config.breakLineStyle == 'solid'
            ? '_'
            : config.breakLineStyle == 'dotted'
            ? '.'
            : config.breakLineStyle == 'double'
            ? '='
            : '-';
        _bluetooth.printCustom(bl * lineWidth, bSize, 0);
      } else {
        _bluetooth.printCustom(" ", bSize, 0);
      }
    }

    for (final section in config.enabledSections) {
      final opts = section.options;
      switch (section.id) {
        case 'kot_header':
          final title = opts['title'] ?? 'KITCHEN TICKET';
          _bluetooth.printCustom(title, bSize == 0 ? 1 : bSize + 1, 1);
          printBreakLine();
          break;
        case 'store_name':
          _bluetooth.printCustom("Store: ${storeInfo['name'] ?? ''}", bSize, 0);
          break;
        case 'order_info':
          if (opts['showOrderId'] == true) {
            _bluetooth.printCustom(
              "Order ID: ${storeInfo['order_number'] ?? ''}",
              bSize,
              0,
            );
          }
          if (opts['showTokenNo'] == true) {
            _bluetooth.printCustom(
              "Token No: ${storeInfo['token_number'] ?? data['token_number'] ?? ''}",
              bSize,
              0,
            );
          }
          if (opts['showCustomerName'] == true &&
              userInfo['name'] != null &&
              userInfo['name'] != 'unnamed user') {
            _bluetooth.printCustom("Customer: ${userInfo['name']}", bSize, 0);
          }
          if (opts['showDate'] == true) {
            _bluetooth.printCustom(
              "Date: ${DateTime.now().toString().substring(0, 16)}",
              bSize,
              0,
            );
          }
          printBreakLine();
          break;
        case 'items_list':
          _bluetooth.printCustom("ITEMS:", bSize, 0);
          for (int i = 0; i < products.length; i++) {
            final p = products[i];
            String qty = opts['showQuantity'] == true
                ? "${p['quantity']}x "
                : "";
            _printWrappedLine(
              "$qty${p['product_name']}",
              lineWidth,
              align: 0,
              size: bSize,
            );
            if (i < products.length - 1) {
              _bluetooth.printCustom(" ", bSize, 0);
            }
          }
          printBreakLine();
          break;
        case 'special_instructions':
          // Future feature for instructions
          break;
        case 'kot_footer':
          final text = opts['text'] ?? '';
          if (text.isNotEmpty) _bluetooth.printCustom(text, bSize, 1);
          break;
      }
    }

    _bluetooth.printNewLine();
    _bluetooth.printNewLine();
    _bluetooth.printNewLine();

    // Auto-cut support
    if (config.autoCutEnabled) {
      try {
        for (int i = 0; i < config.autoCutFeedLines; i++) {
          _bluetooth.printNewLine();
        }
        _bluetooth.writeBytes(
          InvoicePrintService.getAutoCutBytes(
            feedLines: config.autoCutFeedLines,
          ),
        );
      } catch (e) {
        print('Auto-cut command failed: $e');
      }
    }
  }

  static Future<void> _printInvoice(
    Map<String, dynamic> data,
    double widthInMm,
  ) async {
    final storeInfo = data['store_info'] ?? {};
    final userInfo = data['user_info'] ?? {};
    final products = data['products'] as List? ?? [];
    final cartTotal = data['cart_total'] as List? ?? [];
    final platformFees = data['platform_fees'] as List? ?? [];
    final grandTotal = data['grand_total'] ?? 0;
    final qrCodeUrl = data['qr_code_url'] ?? '';

    final config = await ReceiptLayoutConfig.load('receipt');
    final int lineWidth = config.paperWidthChars;
    final int bSize = config.globalFontSize;
    print(
      '[BluetoothPrint] Receipt config loaded: width=$lineWidth, fontSize=$bSize, sections=${config.enabledSections.map((s) => s.id).toList()}',
    );

    // Width configurations
    final int qtyW = lineWidth <= 32 ? 6 : 8;
    final int amtW = lineWidth <= 32 ? 8 : 12;

    void printBreakLine() {
      if (config.showBreakLine) {
        String bl = config.breakLineStyle == 'solid'
            ? '_'
            : config.breakLineStyle == 'dotted'
            ? '.'
            : config.breakLineStyle == 'double'
            ? '='
            : '-';
        _bluetooth.printCustom(bl * lineWidth, bSize, 0);
      } else {
        _bluetooth.printCustom(" ", bSize, 0);
      }
    }

    for (final section in config.enabledSections) {
      final opts = section.options;
      switch (section.id) {
        case 'store_name': // Also acts as header
          _bluetooth.printCustom(
            storeInfo['name'] ?? '',
            bSize == 0 ? 1 : bSize + 1,
            1,
          );
          if (opts['showAddress'] == true && storeInfo['address'] != null) {
            _printWrappedLine(
              storeInfo['address'],
              lineWidth,
              align: 1,
              size: bSize,
            );
          }
          if (opts['showPhone'] == true && storeInfo['phone'] != null) {
            _bluetooth.printCustom("Ph: ${storeInfo['phone']}", bSize, 1);
          }
          if (opts['showGST'] == true && storeInfo['gst_number'] != null) {
            _bluetooth.printCustom(
              "GSTIN: ${storeInfo['gst_number']}",
              bSize,
              1,
            );
          }
          printBreakLine();
          break;
        case 'bill_info':
          if (opts['showBillNo'] == true)
            _printWrappedLine(
              "Bill No: ${storeInfo['bill_number'] ?? ''}",
              lineWidth,
              size: bSize,
            );
          if (opts['showTokenNo'] == true)
            _printWrappedLine(
              "Token No: ${storeInfo['token_number'] ?? ''}",
              lineWidth,
              size: bSize,
            );
          if (opts['showDate'] == true)
            _bluetooth.printCustom(
              "Date: ${DateTime.now().toString().substring(0, 16)}",
              bSize,
              0,
            );
          printBreakLine();
          break;
        case 'customer_info':
          if (opts['showName'] == true)
            _printWrappedLine(
              "Customer: ${userInfo['name'] ?? 'Guest'}",
              lineWidth,
              size: bSize,
            );
          if (opts['showPhone'] == true && userInfo['phone'] != null) {
            _bluetooth.printCustom("Phone: ${userInfo['phone']}", bSize, 0);
          }
          printBreakLine();
          break;
        case 'products_table':
          if (opts['showHeader'] == true) {
            try {
              _bluetooth.writeBytes(Uint8List.fromList([27, 69, 1]));
            } catch (_) {}
            _printTabularItem(
              "Item",
              "Qty",
              "Amt",
              lineWidth,
              qtyW,
              amtW,
              size: bSize,
            );
            try {
              _bluetooth.writeBytes(Uint8List.fromList([27, 69, 0]));
            } catch (_) {}
            _bluetooth.printCustom(" ", bSize, 0);
          }
          for (int i = 0; i < products.length; i++) {
            final p = products[i];
            final pricing = p['pricing_details'] ?? {};
            final name = p['product_name'] ?? '';
            final qty = "${p['quantity'] ?? 0}";
            final amt = "${pricing['selling_amount_including_tax'] ?? 0}";
            _printTabularItem(
              name,
              qty,
              amt,
              lineWidth,
              qtyW,
              amtW,
              size: bSize,
            );
            if (i < products.length - 1) _bluetooth.printCustom(" ", bSize, 0);
          }
          printBreakLine();
          break;
        case 'cart_totals':
          for (final item in cartTotal) {
            _printTabularRight(
              "${item['title'] ?? ''}",
              "${item['value'] ?? 0}",
              lineWidth,
              amtW,
              size: bSize,
            );
          }
          break;
        case 'platform_fees':
          for (final item in platformFees) {
            _printTabularRight(
              "${item['title'] ?? ''}",
              "${item['value'] ?? 0}",
              lineWidth,
              amtW,
              size: bSize,
            );
          }
          printBreakLine();
          break;
        case 'grand_total':
          try {
            _bluetooth.writeBytes(Uint8List.fromList([27, 69, 1]));
          } catch (_) {}
          _printTabularRight(
            "GRAND TOTAL",
            "$grandTotal",
            lineWidth,
            amtW,
            size: bSize == 0 ? 1 : bSize + 1,
          );
          try {
            _bluetooth.writeBytes(Uint8List.fromList([27, 69, 0]));
          } catch (_) {}
          printBreakLine();
          break;
        case 'qr_code':
          if (qrCodeUrl.isNotEmpty) {
            _bluetooth.printNewLine();
            _bluetooth.printQRcode(qrCodeUrl, 250, 250, 1);
            _bluetooth.printNewLine();
          }
          break;
        case 'footer_message':
          final text = opts['text'] ?? config.footerText;
          if (text.isNotEmpty) _bluetooth.printCustom(text, bSize, 1);
          break;
      }
    }

    _bluetooth.printNewLine();
    _bluetooth.printNewLine();
    _bluetooth.printNewLine();

    // Auto-cut support
    if (config.autoCutEnabled) {
      try {
        for (int i = 0; i < config.autoCutFeedLines; i++) {
          _bluetooth.printNewLine();
        }
        _bluetooth.writeBytes(
          InvoicePrintService.getAutoCutBytes(
            feedLines: config.autoCutFeedLines,
          ),
        );
      } catch (e) {
        print('Auto-cut command failed: $e');
      }
    }
  }

  /// Print text wrapping if it exceeds lineWidth
  static void _printWrappedLine(
    String text,
    int width, {
    int align = 0,
    int size = 0,
  }) {
    int start = 0;
    while (start < text.length) {
      int end = start + width;
      if (end > text.length) end = text.length;
      _bluetooth.printCustom(text.substring(start, end), size, align);
      start += width;
    }
  }

  /// Format 3 columns: Item (wrap) | Qty | Amt
  static void _printTabularItem(
    String name,
    String qty,
    String amt,
    int totalWidth,
    int qtyW,
    int amtW, {
    int size = 0,
  }) {
    int nameW = totalWidth - qtyW - amtW;

    // Split name into chunks
    List<String> nameChunks = [];
    int start = 0;
    while (start < name.length) {
      int end = start + nameW;
      if (end > name.length) end = name.length;
      nameChunks.add(name.substring(start, end));
      start += nameW;
    }

    if (nameChunks.isEmpty) nameChunks.add("");

    // If Qty or Amt is large enough to kill the 1-space margin, safely shift to a new line
    bool fits = (qty.length <= (qtyW - 1)) && (amt.length <= (amtW - 1));

    if (!fits) {
      // Print the full item name on its own lines
      for (int i = 0; i < nameChunks.length; i++) {
        _bluetooth.printCustom(nameChunks[i], size, 0);
      }
      // Print Qty and Amt gracefully right-aligned on the *next* line
      String secondLine =
          " ".padRight(nameW) + qty.padLeft(qtyW) + amt.padLeft(amtW);
      _bluetooth.printCustom(secondLine, size, 0);
    } else {
      // First line prints name chunk + qty + amt
      String firstLine =
          nameChunks[0].padRight(nameW) + qty.padLeft(qtyW) + amt.padLeft(amtW);
      _bluetooth.printCustom(firstLine, size, 0);

      // Subsequent lines print the rest of the name
      for (int i = 1; i < nameChunks.length; i++) {
        _bluetooth.printCustom(nameChunks[i], size, 0);
      }
    }
  }

  /// Format 2 columns: Title (wrap) | Amount
  static void _printTabularRight(
    String title,
    String rightVal,
    int totalWidth,
    int rightW, {
    int size = 0,
  }) {
    int titleW = totalWidth - rightW;

    List<String> titleChunks = [];
    int start = 0;
    while (start < title.length) {
      int end = start + titleW;
      if (end > title.length) end = title.length;
      titleChunks.add(title.substring(start, end));
      start += titleW;
    }

    if (titleChunks.isEmpty) titleChunks.add("");

    bool fits = rightVal.length <= (rightW - 1);

    if (!fits) {
      // Print title first fully
      for (int i = 0; i < titleChunks.length; i++) {
        _bluetooth.printCustom(titleChunks[i], size, 0);
      }
      // Print amount safely right-aligned on next line to avoid collision
      String secondLine = " ".padRight(totalWidth - rightVal.length) + rightVal;
      _bluetooth.printCustom(secondLine, size, 0);
    } else {
      // First line
      String firstLine =
          titleChunks[0].padRight(titleW) + rightVal.padLeft(rightW);
      _bluetooth.printCustom(firstLine, size, 0);

      // Rest of title lines
      for (int i = 1; i < titleChunks.length; i++) {
        _bluetooth.printCustom(titleChunks[i], size, 0);
      }
    }
  }

  /// Print text with full justification (both edges aligned).
  /// Words are distributed so that each printed line stretches
  /// from column 0 to column [maxChars] with even spacing.
  static void _printJustified(String text, int maxChars) {
    // Normalize whitespace: replace newlines with spaces, collapse runs
    final cleaned = text.replaceAll(RegExp(r'[\n\r]+'), ' ').trim();
    final allWords = cleaned.split(RegExp(r'\s+'));

    // Remove any empty entries
    final words = allWords.where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return;

    List<String> lineWords = [];
    int lineLen = 0;

    for (final word in words) {
      if (lineWords.isEmpty) {
        lineWords.add(word);
        lineLen = word.length;
      } else if (lineLen + 1 + word.length <= maxChars) {
        lineWords.add(word);
        lineLen += 1 + word.length;
      } else {
        // Flush current line with justification
        _bluetooth.printCustom(_buildJustifiedLine(lineWords, maxChars), 0, 0);
        lineWords = [word];
        lineLen = word.length;
      }
    }

    // Last line: left-aligned (standard typesetting)
    if (lineWords.isNotEmpty) {
      _bluetooth.printCustom(lineWords.join(' '), 0, 0);
    }
  }

  /// Build a single justified line: distribute extra spaces evenly
  /// between words so the total length equals [maxChars].
  static String _buildJustifiedLine(List<String> words, int maxChars) {
    if (words.length <= 1) return words.join();

    final int charCount = words.fold<int>(0, (s, w) => s + w.length);
    final int totalSpaces = maxChars - charCount;
    final int gaps = words.length - 1;
    final int base = totalSpaces ~/ gaps;
    int extra = totalSpaces % gaps;

    final buf = StringBuffer();
    for (int i = 0; i < words.length; i++) {
      buf.write(words[i]);
      if (i < gaps) {
        int sp = base + (extra > 0 ? 1 : 0);
        if (extra > 0) extra--;
        for (int j = 0; j < sp; j++) {
          buf.write(' ');
        }
      }
    }
    return buf.toString();
  }

  static String _dashedLine(int width) {
    return '-' * width;
  }

  // ─── Top-Right Notification ────────────────────────────────────

  /// Show a compact notification at the top-right corner of the screen.
  /// Used instead of SnackBars for connection status and errors.
  static void showTopRightNotification(
    BuildContext context, {
    required String message,
    String? detail,
    IconData icon = Icons.info_outline_rounded,
    Color backgroundColor = const Color(0xFF1E293B),
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _TopRightNotification(
        message: message,
        detail: detail,
        icon: icon,
        backgroundColor: backgroundColor,
        onDismiss: () {
          try {
            entry.remove();
          } catch (_) {}
        },
        duration: duration,
      ),
    );

    overlay.insert(entry);
  }
}

/// A compact notification widget that appears at the top-right corner.
class _TopRightNotification extends StatefulWidget {
  final String message;
  final String? detail;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onDismiss;
  final Duration duration;

  const _TopRightNotification({
    required this.message,
    this.detail,
    required this.icon,
    required this.backgroundColor,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_TopRightNotification> createState() => _TopRightNotificationState();
}

class _TopRightNotificationState extends State<_TopRightNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDetail = widget.detail != null && widget.detail!.isNotEmpty;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                _controller.reverse().then((_) => widget.onDismiss());
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: widget.backgroundColor.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.backgroundColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.backgroundColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.message,
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (hasDetail) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.detail!,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
