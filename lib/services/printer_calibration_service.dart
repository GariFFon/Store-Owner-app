import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:exanor/services/printer_capability_service.dart';
import 'package:exanor/services/image_preprocessing_service.dart';

/// Printer calibration and testing service
/// Generates test patterns to verify printer capabilities
class PrinterCalibrationService {
  static final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  /// Print comprehensive calibration receipt
  /// Tests: alignment, margins, font sizes, dividers, cutter, QR
  static Future<bool> printCalibrationTest({
    required PrinterProfile profile,
    double paperWidthMm = 80.0,
  }) async {
    try {
      final int lineWidth = profile.getCharsPerLine(paperWidthMm);
      final bSize = 0; // Normal font size

      // Initialize printer
      if (profile.needsInitCommand) {
        await _bluetooth.writeBytes(
          PrinterCapabilityService.getInitCommand(profile),
        );
      }

      // Title
      await _bluetooth.printCustom(
        'PRINTER CALIBRATION TEST',
        2, // Large font
        1, // Center
      );
      await _bluetooth.printCustom(
        'Profile: ${profile.model}',
        0,
        1,
      );
      await _bluetooth.printNewLine();

      // 1. Alignment Test
      await _bluetooth.printCustom('ALIGNMENT TEST', 1, 1);
      await _printDivider(lineWidth, '-');
      await _bluetooth.printCustom('LEFT', bSize, 0);
      await _bluetooth.printCustom('CENTER', bSize, 1);
      await _bluetooth.printCustom('RIGHT', bSize, 2);
      await _bluetooth.printNewLine();

      // 2. Character Width Test
      await _bluetooth.printCustom('CHARACTER WIDTH TEST', 1, 1);
      await _printDivider(lineWidth, '-');
      await _bluetooth.printCustom(
        '0123456789' * (lineWidth ~/ 10),
        bSize,
        0,
      );
      await _bluetooth.printCustom(
        'X' * lineWidth,
        bSize,
        0,
      );
      await _bluetooth.printNewLine();

      // 3. Font Size Test
      await _bluetooth.printCustom('FONT SIZE TEST', 1, 1);
      await _printDivider(lineWidth, '-');
      
      if (profile.supportsWideFont || profile.supportsTallFont) {
        await _bluetooth.printCustom('Normal (Size 0)', 0, 0);
        await _bluetooth.printCustom('Medium (Size 1)', 1, 0);
        await _bluetooth.printCustom('Large (Size 2)', 2, 0);
        
        if (profile.supportsWideFont && profile.supportsTallFont) {
          // Test double width and height
          await _bluetooth.writeBytes(
            PrinterCapabilityService.getFontSizeCommand(wide: true, tall: false),
          );
          await _bluetooth.printCustom('Double Width', 0, 0);
          
          await _bluetooth.writeBytes(
            PrinterCapabilityService.getFontSizeCommand(wide: false, tall: true),
          );
          await _bluetooth.printCustom('Double Height', 0, 0);
          
          await _bluetooth.writeBytes(
            PrinterCapabilityService.getFontSizeCommand(wide: true, tall: true),
          );
          await _bluetooth.printCustom('Double Both', 0, 0);
          
          // Reset font size
          await _bluetooth.writeBytes(
            PrinterCapabilityService.getFontSizeCommand(wide: false, tall: false),
          );
        }
      }
      await _bluetooth.printNewLine();

      // 4. Divider Styles Test
      await _bluetooth.printCustom('DIVIDER STYLES TEST', 1, 1);
      await _printDivider(lineWidth, '-');
      await _bluetooth.printCustom('Solid:', bSize, 0);
      await _printDivider(lineWidth, '_');
      await _bluetooth.printCustom('Dashed:', bSize, 0);
      await _printDivider(lineWidth, '-');
      await _bluetooth.printCustom('Dotted:', bSize, 0);
      await _printDivider(lineWidth, '.');
      await _bluetooth.printCustom('Double:', bSize, 0);
      await _printDivider(lineWidth, '=');
      await _bluetooth.printNewLine();

      // 5. Tabular/Column Test
      await _bluetooth.printCustom('COLUMN ALIGNMENT TEST', 1, 1);
      await _printDivider(lineWidth, '-');
      
      final qtyW = lineWidth <= 32 ? 6 : 8;
      final amtW = lineWidth <= 32 ? 8 : 10;
      final nameW = lineWidth - qtyW - amtW;
      
      // Header
      final header = 'Item'.padRight(nameW) +
          'Qty'.padLeft(qtyW) +
          'Amt'.padLeft(amtW);
      await _bluetooth.printCustom(header, bSize, 0);
      await _printDivider(lineWidth, '-');
      
      // Sample items
      final items = [
        ['Burger', '2', '240'],
        ['Fries Large', '1', '120'],
        ['Coke 500ml', '3', '180'],
        ['Chicken Wrap', '1', '199'],
      ];
      
      for (final item in items) {
        final line = item[0].padRight(nameW) +
            item[1].padLeft(qtyW) +
            item[2].padLeft(amtW);
        await _bluetooth.printCustom(line, bSize, 0);
      }
      await _bluetooth.printNewLine();

      // 6. Bold & Underline Test
      if (profile.supportsBold || profile.supportsUnderline) {
        await _bluetooth.printCustom('STYLE TEST', 1, 1);
        await _printDivider(lineWidth, '-');
        
        if (profile.supportsBold) {
          await _bluetooth.writeBytes(
            PrinterCapabilityService.getBoldCommand(true),
          );
          await _bluetooth.printCustom('Bold Text', bSize, 0);
          await _bluetooth.writeBytes(
            PrinterCapabilityService.getBoldCommand(false),
          );
        }
        
        if (profile.supportsUnderline) {
          await _bluetooth.writeBytes(
            PrinterCapabilityService.getUnderlineCommand(true),
          );
          await _bluetooth.printCustom('Underlined Text', bSize, 0);
          await _bluetooth.writeBytes(
            PrinterCapabilityService.getUnderlineCommand(false),
          );
        }
        await _bluetooth.printNewLine();
      }

      // 7. QR Code Test
      if (profile.supportsQr) {
        await _bluetooth.printCustom('QR CODE TEST', 1, 1);
        await _printDivider(lineWidth, '-');
        
        if (profile.supportsNativeQr) {
          // Native ESC/POS QR
          await _bluetooth.printQRcode('https://example.com', 200, 200, 1);
        } else {
          // Fallback: print text representation
          await _bluetooth.printCustom('(QR: Image mode)', bSize, 1);
        }
        await _bluetooth.printNewLine();
      }

      // 8. Image/Logo Test
      if (profile.supportsImage) {
        await _bluetooth.printCustom('IMAGE TEST', 1, 1);
        await _printDivider(lineWidth, '-');
        
        // Print test pattern
        final testPattern = ImagePreprocessingService.generateTestPattern(paperWidthMm);
        await _bluetooth.writeBytes(testPattern);
        await _bluetooth.printNewLine();
      }

      // 9. Feed Lines & Cut Test
      await _bluetooth.printCustom('CUT TEST', 1, 1);
      await _printDivider(lineWidth, '-');
      await _bluetooth.printCustom(
        'Feeding ${profile.minFeedLines} lines before cut...',
        bSize,
        0,
      );

      // Feed lines
      for (int i = 0; i < profile.minFeedLines; i++) {
        await _bluetooth.printNewLine();
      }

      // Auto cut
      if (profile.supportsCut) {
        await _bluetooth.writeBytes(
          PrinterCapabilityService.getCutCommand(
            profile,
            partial: profile.supportsPartialCut,
          ),
        );
      } else {
        await _bluetooth.printCustom(
          '(No cutter - tear manually)',
          bSize,
          1,
        );
        // Extra feed for tear space
        for (int i = 0; i < 5; i++) {
          await _bluetooth.printNewLine();
        }
      }

      return true;
    } catch (e, stack) {
      print('[PrinterCalibration] Error: $e');
      print('[PrinterCalibration] Stack: $stack');
      return false;
    }
  }

  /// Print simple test pattern for quick verification
  static Future<bool> printQuickTest({
    required PrinterProfile profile,
    double paperWidthMm = 80.0,
  }) async {
    try {
      final int lineWidth = profile.getCharsPerLine(paperWidthMm);

      // Initialize
      if (profile.needsInitCommand) {
        await _bluetooth.writeBytes(
          PrinterCapabilityService.getInitCommand(profile),
        );
      }

      // Simple test
      await _bluetooth.printCustom('PRINTER TEST', 2, 1);
      await _printDivider(lineWidth, '=');
      await _bluetooth.printCustom('Alignment: LEFT', 0, 0);
      await _bluetooth.printCustom('Alignment: CENTER', 0, 1);
      await _bluetooth.printCustom('Alignment: RIGHT', 0, 2);
      await _printDivider(lineWidth, '-');
      await _bluetooth.printCustom('123456789' * (lineWidth ~/ 9), 0, 0);
      await _printDivider(lineWidth, '-');

      // Cut or feed
      if (profile.supportsCut) {
        for (int i = 0; i < profile.minFeedLines; i++) {
          await _bluetooth.printNewLine();
        }
        await _bluetooth.writeBytes(
          PrinterCapabilityService.getCutCommand(profile),
        );
      } else {
        for (int i = 0; i < 5; i++) {
          await _bluetooth.printNewLine();
        }
      }

      return true;
    } catch (e) {
      print('[PrinterCalibration] Quick test error: $e');
      return false;
    }
  }

  /// Print alignment calibration pattern
  static Future<bool> printAlignmentCalibration({
    required PrinterProfile profile,
    double paperWidthMm = 80.0,
  }) async {
    try {
      // Initialize
      if (profile.needsInitCommand) {
        await _bluetooth.writeBytes(
          PrinterCapabilityService.getInitCommand(profile),
        );
      }

      // Print image-based alignment markers
      final alignmentPattern = ImagePreprocessingService.generateAlignmentTest(paperWidthMm);
      await _bluetooth.writeBytes(alignmentPattern);
      
      await _bluetooth.printNewLine();
      await _bluetooth.printCustom('LEFT', 0, 0);
      await _bluetooth.printCustom('CENTER', 0, 1);
      await _bluetooth.printCustom('RIGHT', 0, 2);
      
      // Cut
      if (profile.supportsCut) {
        await _bluetooth.writeBytes(
          PrinterCapabilityService.getCutCommand(profile),
        );
      }

      return true;
    } catch (e) {
      print('[PrinterCalibration] Alignment test error: $e');
      return false;
    }
  }

  /// Print dithering/quality test pattern
  static Future<bool> printQualityTest({
    required PrinterProfile profile,
    double paperWidthMm = 80.0,
  }) async {
    try {
      // Initialize
      if (profile.needsInitCommand) {
        await _bluetooth.writeBytes(
          PrinterCapabilityService.getInitCommand(profile),
        );
      }

      await _bluetooth.printCustom('IMAGE QUALITY TEST', 2, 1);
      await _bluetooth.printNewLine();

      // Test pattern with gradients
      final testPattern = ImagePreprocessingService.generateTestPattern(paperWidthMm);
      await _bluetooth.writeBytes(testPattern);

      await _bluetooth.printNewLine();
      await _bluetooth.printCustom(
        'Dithering: ${profile.requiresDithering ? "ON" : "OFF"}',
        0,
        1,
      );
      await _bluetooth.printCustom(
        'Max Width: ${profile.maxImageWidth}px',
        0,
        1,
      );

      // Cut
      if (profile.supportsCut) {
        await _bluetooth.writeBytes(
          PrinterCapabilityService.getCutCommand(profile),
        );
      }

      return true;
    } catch (e) {
      print('[PrinterCalibration] Quality test error: $e');
      return false;
    }
  }

  /// Helper: Print divider line
  static Future<void> _printDivider(int width, String char) async {
    final line = char * width;
    await _bluetooth.printCustom(line, 0, 0);
  }
}
