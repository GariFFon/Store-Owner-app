import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single configurable section in a receipt or KOT
class ReceiptSection {
  final String id;
  String label;
  bool enabled;
  int order;
  Map<String, dynamic> options; // Extra per-section options

  ReceiptSection({
    required this.id,
    required this.label,
    this.enabled = true,
    this.order = 0,
    Map<String, dynamic>? options,
  }) : options = options ?? {};

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'enabled': enabled,
    'order': order,
    'options': options,
  };

  factory ReceiptSection.fromJson(Map<String, dynamic> json) => ReceiptSection(
    id: json['id'] as String,
    label: json['label'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
    order: json['order'] as int? ?? 0,
    options: json['options'] as Map<String, dynamic>? ?? {},
  );

  ReceiptSection copyWith({
    String? id,
    String? label,
    bool? enabled,
    int? order,
    Map<String, dynamic>? options,
  }) => ReceiptSection(
    id: id ?? this.id,
    label: label ?? this.label,
    enabled: enabled ?? this.enabled,
    order: order ?? this.order,
    options: options ?? Map.from(this.options),
  );
}

/// Full layout configuration for either Receipt or KOT
class ReceiptLayoutConfig {
  final String type; // 'receipt' or 'kot'
  List<ReceiptSection> sections;
  bool autoCutEnabled;
  int autoCutFeedLines; // number of blank lines before auto-cut
  bool showBreakLine; // dashed line breaks between sections
  String breakLineStyle; // 'dashed', 'solid', 'dotted', 'double'
  String footerText; // Custom footer message
  bool showOrderNumber;
  bool showDateTime;
  String productDisplayFormat; // 'compact', 'detailed', 'with_price'
  int globalFontSize; // 0: Normal, 1: Bold/Med, 2: Large
  int paperWidthChars; // 32 for 58mm, 48 for 80mm

  ReceiptLayoutConfig({
    required this.type,
    List<ReceiptSection>? sections,
    this.autoCutEnabled = false,
    this.autoCutFeedLines = 3,
    this.showBreakLine = true,
    this.breakLineStyle = 'dashed',
    this.footerText = 'Thank you for your visit!',
    this.showOrderNumber = true,
    this.showDateTime = true,
    this.productDisplayFormat = 'compact',
    this.globalFontSize = 0,
    this.paperWidthChars = 48,
  }) : sections = sections ?? _defaultSections(type);


  /// Default sections for a Receipt
  static List<ReceiptSection> _defaultReceiptSections() => [
    ReceiptSection(
      id: 'store_logo',
      label: 'Store Logo',
      enabled: true,
      order: 0,
      options: {'size': 'medium'}, // small, medium, large
    ),
    ReceiptSection(
      id: 'store_name',
      label: 'Store Name & Info',
      enabled: true,
      order: 1,
      options: {
        'showAddress': true,
        'showPhone': true,
        'showGST': true,
      },
    ),
    ReceiptSection(
      id: 'bill_info',
      label: 'Bill & Token Number',
      enabled: true,
      order: 2,
      options: {
        'showBillNo': true,
        'showTokenNo': true,
        'showDate': true,
      },
    ),
    ReceiptSection(
      id: 'customer_info',
      label: 'Customer Information',
      enabled: true,
      order: 3,
      options: {
        'showName': true,
        'showPhone': true,
      },
    ),
    ReceiptSection(
      id: 'products_table',
      label: 'Products / Items',
      enabled: true,
      order: 4,
      options: {
        'showHeader': true, // Item | Qty | Amt header
        'showUnitPrice': false,
        'showTax': false,
        'format': 'compact', // 'compact', 'detailed'
      },
    ),
    ReceiptSection(
      id: 'cart_totals',
      label: 'Cart Totals',
      enabled: true,
      order: 5,
    ),
    ReceiptSection(
      id: 'platform_fees',
      label: 'Platform Fees',
      enabled: true,
      order: 6,
    ),
    ReceiptSection(
      id: 'grand_total',
      label: 'Grand Total',
      enabled: true,
      order: 7,
    ),
    ReceiptSection(
      id: 'qr_code',
      label: 'QR Code',
      enabled: true,
      order: 8,
      options: {
        'size': 'medium', // 'small', 'medium', 'large'
        'position': 'center', // 'left', 'center', 'right'
      },
    ),
    ReceiptSection(
      id: 'footer_message',
      label: 'Footer Message',
      enabled: true,
      order: 9,
      options: {
        'text': 'Thank you for your visit!',
        'alignment': 'center',
      },
    ),
  ];

  /// Default sections for a KOT (Kitchen Order Ticket)
  static List<ReceiptSection> _defaultKOTSections() => [
    ReceiptSection(
      id: 'kot_header',
      label: 'KOT Header Title',
      enabled: true,
      order: 0,
      options: {
        'title': 'KITCHEN TICKET',
        'showBold': true,
      },
    ),
    ReceiptSection(
      id: 'store_name',
      label: 'Store Name',
      enabled: true,
      order: 1,
    ),
    ReceiptSection(
      id: 'order_info',
      label: 'Order ID & Details',
      enabled: true,
      order: 2,
      options: {
        'showOrderId': true,
        'showCustomerName': true,
        'showDate': true,
        'showTableNo': true,
      },
    ),
    ReceiptSection(
      id: 'items_list',
      label: 'Items List',
      enabled: true,
      order: 3,
      options: {
        'showQuantity': true,
        'showPrice': false, // Kitchen usually doesn't need price
        'fontSize': 'large', // 'small', 'normal', 'large'
        'showNotes': true,
      },
    ),
    ReceiptSection(
      id: 'special_instructions',
      label: 'Special Instructions',
      enabled: true,
      order: 4,
    ),
    ReceiptSection(
      id: 'kot_footer',
      label: 'KOT Footer',
      enabled: false,
      order: 5,
      options: {
        'text': '',
      },
    ),
  ];

  static List<ReceiptSection> _defaultSections(String type) {
    return type == 'kot' ? _defaultKOTSections() : _defaultReceiptSections();
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'sections': sections.map((s) => s.toJson()).toList(),
    'autoCutEnabled': autoCutEnabled,
    'autoCutFeedLines': autoCutFeedLines,
    'showBreakLine': showBreakLine,
    'breakLineStyle': breakLineStyle,
    'footerText': footerText,
    'showOrderNumber': showOrderNumber,
    'showDateTime': showDateTime,
    'productDisplayFormat': productDisplayFormat,
    'globalFontSize': globalFontSize,
    'paperWidthChars': paperWidthChars,
  };

  factory ReceiptLayoutConfig.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'receipt';
    return ReceiptLayoutConfig(
      type: type,
      sections: (json['sections'] as List?)
          ?.map((s) => ReceiptSection.fromJson(s as Map<String, dynamic>))
          .toList() ??
          _defaultSections(type),
      autoCutEnabled: json['autoCutEnabled'] as bool? ?? false,
      autoCutFeedLines: json['autoCutFeedLines'] as int? ?? 3,
      showBreakLine: json['showBreakLine'] as bool? ?? true,
      breakLineStyle: json['breakLineStyle'] as String? ?? 'dashed',
      footerText: json['footerText'] as String? ?? 'Thank you for your visit!',
      showOrderNumber: json['showOrderNumber'] as bool? ?? true,
      showDateTime: json['showDateTime'] as bool? ?? true,
      productDisplayFormat: json['productDisplayFormat'] as String? ?? 'compact',
      globalFontSize: json['globalFontSize'] as int? ?? 0,
      paperWidthChars: json['paperWidthChars'] as int? ?? 48,
    );
  }


  // ─── Persistence ────────────────────────────────────────────────

  static const String _receiptConfigKey = 'receipt_layout_config';
  static const String _kotConfigKey = 'kot_layout_config';

  static String _prefKey(String type) =>
      type == 'kot' ? _kotConfigKey : _receiptConfigKey;

  /// Save this config to SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(toJson());
    await prefs.setString(_prefKey(type), json);
    print('[ReceiptLayoutConfig] SAVED $type config (${json.length} chars, paperWidth: $paperWidthChars, fontSize: $globalFontSize)');
  }

  /// Load config from SharedPreferences, or return defaults
  static Future<ReceiptLayoutConfig> load(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKey(type));
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          return ReceiptLayoutConfig.fromJson(decoded);
        }
      } catch (e, stack) {
        print('[ReceiptLayoutConfig] ERROR loading $type config: $e');
        print('[ReceiptLayoutConfig] Stack: $stack');
      }
    }
    return ReceiptLayoutConfig(type: type);
  }

  /// Reset to defaults
  static Future<void> resetToDefaults(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey(type));
  }

  /// Get sorted, enabled sections only
  List<ReceiptSection> get enabledSections {
    final enabled = sections.where((s) => s.enabled).toList();
    enabled.sort((a, b) => a.order.compareTo(b.order));
    return enabled;
  }

  /// Get all sections sorted by order
  List<ReceiptSection> get sortedSections {
    final sorted = List<ReceiptSection>.from(sections);
    sorted.sort((a, b) => a.order.compareTo(b.order));
    return sorted;
  }
}
