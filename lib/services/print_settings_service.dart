import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/services/invoice_print_service.dart';

/// Print behavior mode after order placement.
/// - 'always': auto-print immediately, skip confirmation dialog
/// - 'ask': show the print options dialog (legacy behavior)
/// - 'never': do not print, just show order placed confirmation
class PrintSettingsService {
  static const String _autoPrintModeKey = 'pos_auto_print_mode';
  static const String _copiesKitchenKey = 'pos_print_copies_kitchen';
  static const String _copiesReceiptKey = 'pos_print_copies_receipt';
  static const String _enableConfirmationDialogKey =
      'pos_print_enable_confirmation';
  static const String _fallbackEnabledKey = 'pos_print_fallback_enabled';
  static const String _defaultPrinterNameKey = 'pos_print_default_printer_name';
  static const String _defaultPrinterUrlKey = 'pos_print_default_printer_url';
  static const String _defaultPrinterAddressKey =
      'pos_print_default_bt_address';
  static const String _paperSizeKey = 'pos_print_paper_size';
  static const String _connectionTypeKey = 'pos_print_connection_type';

  static const String modeAlways = 'always';
  static const String modeAsk = 'ask';
  static const String modeNever = 'never';

  // ─── Getters ─────────────────────────────────────────────────────────────

  static Future<String> getAutoPrintMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_autoPrintModeKey) ?? modeAsk;
  }

  static Future<int> getCopiesKitchen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_copiesKitchenKey) ?? 1;
  }

  static Future<int> getCopiesReceipt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_copiesReceiptKey) ?? 1;
  }

  static Future<bool> getEnableConfirmationDialog() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enableConfirmationDialogKey) ?? true;
  }

  static Future<bool> getFallbackEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fallbackEnabledKey) ?? false;
  }

  static Future<String?> getDefaultPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultPrinterNameKey);
  }

  static Future<String?> getDefaultPrinterUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultPrinterUrlKey);
  }

  static Future<String?> getDefaultPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultPrinterAddressKey);
  }

  static Future<double?> getPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_paperSizeKey);
  }

  static Future<String?> getConnectionType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_connectionTypeKey);
  }

  // ─── Setters ─────────────────────────────────────────────────────────────

  static Future<void> setAutoPrintMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoPrintModeKey, mode);
  }

  static Future<void> setCopiesKitchen(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_copiesKitchenKey, value);
  }

  static Future<void> setCopiesReceipt(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_copiesReceiptKey, value);
  }

  static Future<void> setEnableConfirmationDialog(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableConfirmationDialogKey, value);
  }

  static Future<void> setFallbackEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fallbackEnabledKey, value);
  }

  static Future<void> setDefaultPrinterName(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_defaultPrinterNameKey);
    } else {
      await prefs.setString(_defaultPrinterNameKey, value);
    }
  }

  static Future<void> setDefaultPrinterUrl(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_defaultPrinterUrlKey);
    } else {
      await prefs.setString(_defaultPrinterUrlKey, value);
    }
  }

  static Future<void> setDefaultPrinterAddress(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_defaultPrinterAddressKey);
    } else {
      await prefs.setString(_defaultPrinterAddressKey, value);
    }
  }

  static Future<void> setPaperSize(double? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_paperSizeKey);
    } else {
      await prefs.setDouble(_paperSizeKey, value);
    }
  }

  static Future<void> setConnectionType(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_connectionTypeKey);
    } else {
      await prefs.setString(_connectionTypeKey, value);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static String modeLabel(String mode) {
    switch (mode) {
      case modeAlways:
        return 'Auto-print';
      case modeNever:
        return 'Never print';
      case modeAsk:
      default:
        return 'Ask every time';
    }
  }

  static Future<void> syncFromExistingServices() async {
    // One-time migration: copy existing prefs from InvoicePrintService
    final connType = await InvoicePrintService.getSavedConnectionType();
    final paperSize = await InvoicePrintService.getSavedPaperSize();
    final printerName = await InvoicePrintService.getSavedPrinterName();

    final existingConn = await getConnectionType();
    if (existingConn == null && connType != null) {
      await setConnectionType(connType);
    }
    final existingPaper = await getPaperSize();
    if (existingPaper == null && paperSize != null) {
      await setPaperSize(paperSize);
    }
    final existingPrinter = await getDefaultPrinterName();
    if (existingPrinter == null && printerName != null) {
      await setDefaultPrinterName(printerName);
    }
  }
}
