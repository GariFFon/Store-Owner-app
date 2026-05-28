import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

/// Printer capability profiles for different thermal printer models
/// This enables proper feature detection and fallback commands
class PrinterProfile {
  final String model;
  final String manufacturer;
  final int charsPerLine58mm;
  final int charsPerLine80mm;
  final int dpi;
  final bool supportsCut;
  final bool supportsPartialCut;
  final bool supportsQr;
  final bool supportsImage;
  final bool supportsBold;
  final bool supportsUnderline;
  final bool supportsReverse;
  final bool supportsBarcode;
  final bool supportsWideFont;
  final bool supportsTallFont;
  final bool needsInitCommand;
  final bool needsFeedBeforeCut;
  final int minFeedLines;
  final int maxFeedLines;
  final bool supportsNativeQr;
  final int maxImageWidth;
  final bool requiresDithering;
  final bool requiresThreshold;

  const PrinterProfile({
    required this.model,
    required this.manufacturer,
    this.charsPerLine58mm = 32,
    this.charsPerLine80mm = 48,
    this.dpi = 203,
    this.supportsCut = true,
    this.supportsPartialCut = true,
    this.supportsQr = true,
    this.supportsImage = true,
    this.supportsBold = true,
    this.supportsUnderline = true,
    this.supportsReverse = false,
    this.supportsBarcode = true,
    this.supportsWideFont = true,
    this.supportsTallFont = true,
    this.needsInitCommand = true,
    this.needsFeedBeforeCut = true,
    this.minFeedLines = 3,
    this.maxFeedLines = 10,
    this.supportsNativeQr = true,
    this.maxImageWidth = 576, // 80mm at 203 DPI
    this.requiresDithering = false,
    this.requiresThreshold = true,
  });

  int getCharsPerLine(double paperWidthMm) {
    if (paperWidthMm <= 58) return charsPerLine58mm;
    return charsPerLine80mm;
  }

  bool get supportsFeedLines => true; // All printers support feed

  Map<String, dynamic> toJson() => {
    'model': model,
    'manufacturer': manufacturer,
    'charsPerLine58mm': charsPerLine58mm,
    'charsPerLine80mm': charsPerLine80mm,
    'dpi': dpi,
    'supportsCut': supportsCut,
    'supportsPartialCut': supportsPartialCut,
    'supportsQr': supportsQr,
    'supportsImage': supportsImage,
    'supportsBold': supportsBold,
    'supportsUnderline': supportsUnderline,
    'supportsReverse': supportsReverse,
    'supportsBarcode': supportsBarcode,
    'supportsWideFont': supportsWideFont,
    'supportsTallFont': supportsTallFont,
    'needsInitCommand': needsInitCommand,
    'needsFeedBeforeCut': needsFeedBeforeCut,
    'minFeedLines': minFeedLines,
    'maxFeedLines': maxFeedLines,
    'supportsNativeQr': supportsNativeQr,
    'maxImageWidth': maxImageWidth,
    'requiresDithering': requiresDithering,
    'requiresThreshold': requiresThreshold,
  };

  factory PrinterProfile.fromJson(Map<String, dynamic> json) => PrinterProfile(
    model: json['model'] as String,
    manufacturer: json['manufacturer'] as String,
    charsPerLine58mm: json['charsPerLine58mm'] as int? ?? 32,
    charsPerLine80mm: json['charsPerLine80mm'] as int? ?? 48,
    dpi: json['dpi'] as int? ?? 203,
    supportsCut: json['supportsCut'] as bool? ?? true,
    supportsPartialCut: json['supportsPartialCut'] as bool? ?? true,
    supportsQr: json['supportsQr'] as bool? ?? true,
    supportsImage: json['supportsImage'] as bool? ?? true,
    supportsBold: json['supportsBold'] as bool? ?? true,
    supportsUnderline: json['supportsUnderline'] as bool? ?? true,
    supportsReverse: json['supportsReverse'] as bool? ?? false,
    supportsBarcode: json['supportsBarcode'] as bool? ?? true,
    supportsWideFont: json['supportsWideFont'] as bool? ?? true,
    supportsTallFont: json['supportsTallFont'] as bool? ?? true,
    needsInitCommand: json['needsInitCommand'] as bool? ?? true,
    needsFeedBeforeCut: json['needsFeedBeforeCut'] as bool? ?? true,
    minFeedLines: json['minFeedLines'] as int? ?? 3,
    maxFeedLines: json['maxFeedLines'] as int? ?? 10,
    supportsNativeQr: json['supportsNativeQr'] as bool? ?? true,
    maxImageWidth: json['maxImageWidth'] as int? ?? 576,
    requiresDithering: json['requiresDithering'] as bool? ?? false,
    requiresThreshold: json['requiresThreshold'] as bool? ?? true,
  );
}

/// Predefined profiles for common printer models
class PrinterProfiles {
  // Epson TM series - Industry standard, full ESC/POS support
  static const epsonTM = PrinterProfile(
    model: 'Epson TM-T20/T88',
    manufacturer: 'Epson',
    charsPerLine58mm: 32,
    charsPerLine80mm: 48,
    dpi: 203,
    supportsCut: true,
    supportsPartialCut: true,
    supportsQr: true,
    supportsImage: true,
    supportsBold: true,
    supportsUnderline: true,
    supportsReverse: true,
    supportsBarcode: true,
    supportsWideFont: true,
    supportsTallFont: true,
    needsInitCommand: true,
    needsFeedBeforeCut: true,
    minFeedLines: 3,
    maxFeedLines: 10,
    supportsNativeQr: true,
    maxImageWidth: 576,
    requiresDithering: false,
    requiresThreshold: false,
  );

  // Sunmi built-in printers - Good support but some quirks
  static const sunmi = PrinterProfile(
    model: 'Sunmi V1/V2',
    manufacturer: 'Sunmi',
    charsPerLine58mm: 32,
    charsPerLine80mm: 48,
    dpi: 203,
    supportsCut: false, // No cutter on Sunmi
    supportsPartialCut: false,
    supportsQr: true,
    supportsImage: true,
    supportsBold: true,
    supportsUnderline: true,
    supportsReverse: false,
    supportsBarcode: true,
    supportsWideFont: true,
    supportsTallFont: true,
    needsInitCommand: true,
    needsFeedBeforeCut: false,
    minFeedLines: 0,
    maxFeedLines: 5,
    supportsNativeQr: true,
    maxImageWidth: 384,
    requiresDithering: false,
    requiresThreshold: true,
  );

  // XPrinter - Popular cheap Chinese printer
  static const xprinter = PrinterProfile(
    model: 'XPrinter XP-58/80',
    manufacturer: 'XPrinter',
    charsPerLine58mm: 32,
    charsPerLine80mm: 48,
    dpi: 203,
    supportsCut: true,
    supportsPartialCut: false, // Only full cut
    supportsQr: true,
    supportsImage: true,
    supportsBold: true,
    supportsUnderline: true,
    supportsReverse: false,
    supportsBarcode: true,
    supportsWideFont: true,
    supportsTallFont: true,
    needsInitCommand: true,
    needsFeedBeforeCut: true,
    minFeedLines: 3,
    maxFeedLines: 8,
    supportsNativeQr: false, // Must use image-based QR
    maxImageWidth: 384,
    requiresDithering: true,
    requiresThreshold: true,
  );

  // Rongta - Another popular cheap printer
  static const rongta = PrinterProfile(
    model: 'Rongta RP58/RP80',
    manufacturer: 'Rongta',
    charsPerLine58mm: 32,
    charsPerLine80mm: 48,
    dpi: 203,
    supportsCut: true,
    supportsPartialCut: false,
    supportsQr: true,
    supportsImage: true,
    supportsBold: true,
    supportsUnderline: true,
    supportsReverse: false,
    supportsBarcode: true,
    supportsWideFont: true,
    supportsTallFont: true,
    needsInitCommand: true,
    needsFeedBeforeCut: true,
    minFeedLines: 3,
    maxFeedLines: 8,
    supportsNativeQr: false,
    maxImageWidth: 384,
    requiresDithering: true,
    requiresThreshold: true,
  );

  // Generic 58mm - Bare minimum support
  static const generic58 = PrinterProfile(
    model: 'Generic 58mm',
    manufacturer: 'Unknown',
    charsPerLine58mm: 32,
    charsPerLine80mm: 32,
    dpi: 203,
    supportsCut: false,
    supportsPartialCut: false,
    supportsQr: false,
    supportsImage: false, // Too risky on cheap printers
    supportsBold: true,
    supportsUnderline: true,
    supportsReverse: false,
    supportsBarcode: false,
    supportsWideFont: true,
    supportsTallFont: true,
    needsInitCommand: false,
    needsFeedBeforeCut: true,
    minFeedLines: 3,
    maxFeedLines: 5,
    supportsNativeQr: false,
    maxImageWidth: 384,
    requiresDithering: false,
    requiresThreshold: true,
  );

  // Generic 80mm - Bare minimum support
  static const generic80 = PrinterProfile(
    model: 'Generic 80mm',
    manufacturer: 'Unknown',
    charsPerLine58mm: 32,
    charsPerLine80mm: 48,
    dpi: 203,
    supportsCut: false,
    supportsPartialCut: false,
    supportsQr: false,
    supportsImage: false,
    supportsBold: true,
    supportsUnderline: true,
    supportsReverse: false,
    supportsBarcode: false,
    supportsWideFont: true,
    supportsTallFont: true,
    needsInitCommand: false,
    needsFeedBeforeCut: true,
    minFeedLines: 3,
    maxFeedLines: 5,
    supportsNativeQr: false,
    maxImageWidth: 576,
    requiresDithering: false,
    requiresThreshold: true,
  );

  static List<PrinterProfile> get allProfiles => [
    epsonTM,
    sunmi,
    xprinter,
    rongta,
    generic58,
    generic80,
  ];

  static PrinterProfile getProfileForModel(String? modelName) {
    if (modelName == null) return generic80;
    final lower = modelName.toLowerCase();

    if (lower.contains('epson') || lower.contains('tm-')) return epsonTM;
    if (lower.contains('sunmi')) return sunmi;
    if (lower.contains('xprinter') || lower.contains('xp-')) return xprinter;
    if (lower.contains('rongta') || lower.contains('rp')) return rongta;
    if (lower.contains('58')) return generic58;

    return generic80;
  }
}

/// Service for managing printer capabilities and detection
class PrinterCapabilityService {
  static const String _profileKey = 'printer_selected_profile';
  static const String _detectedModelKey = 'printer_detected_model';

  /// Get the currently selected printer profile
  static Future<PrinterProfile> getCurrentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_profileKey);
    if (jsonStr != null) {
      try {
        return PrinterProfile.fromJson(
          Map<String, dynamic>.from(
            const {}.runtimeType.toString().contains('Map')
                ? jsonStr as Map
                : {},
          ),
        );
      } catch (e) {
        print('[PrinterCapability] Error loading profile: $e');
      }
    }
    return PrinterProfiles.generic80;
  }

  /// Save selected printer profile
  static Future<void> saveProfile(PrinterProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, profile.model);
  }

  /// Detect printer capabilities by printing a test pattern
  /// and analyzing printer response (if available)
  static Future<PrinterProfile> detectPrinterCapabilities() async {
    // For now, return generic profile
    // In future, this could send ESC/POS status commands
    // and analyze printer responses
    return PrinterProfiles.generic80;
  }

  /// Get ESC/POS initialization command bytes
  static Uint8List getInitCommand(PrinterProfile profile) {
    if (!profile.needsInitCommand) return Uint8List(0);
    // ESC @ - Initialize printer
    return Uint8List.fromList([0x1B, 0x40]);
  }

  /// Get ESC/POS cut command based on profile capabilities
  static Uint8List getCutCommand(
    PrinterProfile profile, {
    bool partial = true,
  }) {
    if (!profile.supportsCut) return Uint8List(0);

    if (partial && profile.supportsPartialCut) {
      // GS V 66 0 - Partial cut
      return Uint8List.fromList([0x1D, 0x56, 0x42, 0x00]);
    } else {
      // GS V 66 1 - Full cut
      return Uint8List.fromList([0x1D, 0x56, 0x42, 0x01]);
    }
  }

  /// Get feed lines command
  static Uint8List getFeedCommand(int lines) {
    // ESC d n - Print and feed n lines
    return Uint8List.fromList([0x1B, 0x64, lines]);
  }

  /// Get bold mode command
  static Uint8List getBoldCommand(bool enable) {
    // ESC E n - Bold mode
    return Uint8List.fromList([0x1B, 0x45, enable ? 0x01 : 0x00]);
  }

  /// Get underline mode command
  static Uint8List getUnderlineCommand(bool enable) {
    // ESC - n - Underline mode
    return Uint8List.fromList([0x1B, 0x2D, enable ? 0x01 : 0x00]);
  }

  /// Get font size command (width/height doubling)
  static Uint8List getFontSizeCommand({bool wide = false, bool tall = false}) {
    // GS ! n - Select character size
    int n = 0;
    if (wide) n |= 0x10;
    if (tall) n |= 0x01;
    return Uint8List.fromList([0x1D, 0x21, n]);
  }

  /// Get alignment command
  static Uint8List getAlignmentCommand(int align) {
    // ESC a n - Select justification
    // 0 = left, 1 = center, 2 = right
    return Uint8List.fromList([0x1B, 0x61, align]);
  }
}
