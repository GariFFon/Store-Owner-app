import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Image preprocessing pipeline for thermal printer compatibility
/// Handles: resize → grayscale → threshold → dither → ESC/POS bitmap
class ImagePreprocessingService {
  /// Maximum recommended widths for thermal printers
  static const int maxWidth58mm = 384; // 58mm at 203 DPI
  static const int maxWidth80mm = 576; // 80mm at 203 DPI
  static const int maxWidth3inch = 640; // 3 inch at 203 DPI

  /// Process an image for thermal printing
  /// Returns ESC/POS compatible bitmap bytes
  static Future<Uint8List?> processImageForPrinting(
    Uint8List imageBytes, {
    required double paperWidthMm,
    bool enableDithering = true,
    int threshold = 128,
    bool invert = false,
  }) async {
    try {
      // Step 1: Decode image
      final original = img.decodeImage(imageBytes);
      if (original == null) {
        print('[ImagePreprocessing] Failed to decode image');
        return null;
      }

      print(
        '[ImagePreprocessing] Original: ${original.width}x${original.height}',
      );

      // Step 2: Calculate target width
      final maxWidth = _getMaxWidthForPaper(paperWidthMm);

      // Step 3: Resize maintaining aspect ratio
      img.Image resized;
      if (original.width > maxWidth) {
        final ratio = maxWidth / original.width;
        final newHeight = (original.height * ratio).round();
        resized = img.copyResize(
          original,
          width: maxWidth,
          height: newHeight,
          interpolation: img.Interpolation.cubic,
        );
        print(
          '[ImagePreprocessing] Resized to: ${resized.width}x${resized.height}',
        );
      } else {
        resized = original;
      }

      // Step 4: Convert to grayscale
      final grayscale = img.grayscale(resized);
      print('[ImagePreprocessing] Converted to grayscale');

      // Step 5: Apply threshold or dithering
      final processed = enableDithering
          ? _applyFloydSteinbergDithering(grayscale, threshold)
          : _applyThreshold(grayscale, threshold);

      print(
        '[ImagePreprocessing] Applied ${enableDithering ? "dithering" : "threshold"}',
      );

      // Step 6: Convert to ESC/POS bitmap format
      final bitmapBytes = _convertToEscPosBitmap(processed, invert: invert);
      print(
        '[ImagePreprocessing] Generated ESC/POS bitmap: ${bitmapBytes.length} bytes',
      );

      return bitmapBytes;
    } catch (e, stack) {
      print('[ImagePreprocessing] Error: $e');
      print('[ImagePreprocessing] Stack: $stack');
      return null;
    }
  }

  /// Process image from network URL
  static Future<Uint8List?> processImageFromUrl(
    String url, {
    required double paperWidthMm,
    bool enableDithering = true,
    int threshold = 128,
  }) async {
    try {
      // This would need network image loading
      // For now, return null - implement with your HTTP client
      print(
        '[ImagePreprocessing] Network loading not implemented in this stub',
      );
      return null;
    } catch (e) {
      print('[ImagePreprocessing] URL processing error: $e');
      return null;
    }
  }

  /// Get maximum image width for paper size
  static int _getMaxWidthForPaper(double paperWidthMm) {
    if (paperWidthMm <= 58) return maxWidth58mm;
    if (paperWidthMm <= 80) return maxWidth80mm;
    return maxWidth3inch;
  }

  /// Apply simple threshold (black/white)
  static img.Image _applyThreshold(img.Image source, int threshold) {
    final result = img.Image(width: source.width, height: source.height);

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final luminance = pixel.luminance;
        final value = luminance >= threshold ? 255 : 0;
        result.setPixel(x, y, img.ColorRgb8(value, value, value));
      }
    }

    return result;
  }

  /// Apply Floyd-Steinberg dithering for smoother prints
  static img.Image _applyFloydSteinbergDithering(
    img.Image source,
    int threshold,
  ) {
    final result = img.Image(width: source.width, height: source.height);

    // Create working copy with error diffusion buffer
    final List<List<double>> errors = List.generate(
      source.height,
      (_) => List.filled(source.width, 0.0),
    );

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        double oldPixel = pixel.luminance + errors[y][x];

        // Clamp to valid range
        oldPixel = oldPixel.clamp(0.0, 255.0);

        final newPixel = oldPixel >= threshold ? 255.0 : 0.0;
        final error = oldPixel - newPixel;

        // Set output pixel
        final value = newPixel.toInt();
        result.setPixel(x, y, img.ColorRgb8(value, value, value));

        // Distribute error using Floyd-Steinberg coefficients
        // X = current pixel
        //     X   7/16
        // 3/16 5/16 1/16

        if (x + 1 < source.width) {
          errors[y][x + 1] += error * 7 / 16;
        }
        if (y + 1 < source.height) {
          if (x > 0) {
            errors[y + 1][x - 1] += error * 3 / 16;
          }
          errors[y + 1][x] += error * 5 / 16;
          if (x + 1 < source.width) {
            errors[y + 1][x + 1] += error * 1 / 16;
          }
        }
      }
    }

    return result;
  }

  /// Convert image to ESC/POS bitmap format
  /// Uses GS v 0 command format
  static Uint8List _convertToEscPosBitmap(
    img.Image source, {
    bool invert = false,
  }) {
    final width = source.width;
    final height = source.height;

    // ESC/POS bitmap width must be multiple of 8
    final widthBytes = (width + 7) ~/ 8;
    final paddedWidth = widthBytes * 8;

    // Build bitmap data (1 bit per pixel)
    final bitmapData = Uint8List(widthBytes * height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = source.getPixel(x, y);
        final luminance = pixel.luminance;

        // Thermal printers: 1 = black, 0 = white (usually)
        final isBlack = luminance < 128;
        final bit = invert ? !isBlack : isBlack;

        if (bit) {
          final byteIndex = (y * widthBytes) + (x ~/ 8);
          final bitIndex = 7 - (x % 8); // MSB first
          bitmapData[byteIndex] |= (1 << bitIndex);
        }
      }
    }

    // Build ESC/POS command
    // GS v 0 m xL xH yL yH d1...dk
    // m = 0 (normal), xL/xH = width low/high bytes, yL/yH = height low/high bytes

    final xL = widthBytes & 0xFF;
    final xH = (widthBytes >> 8) & 0xFF;
    final yL = height & 0xFF;
    final yH = (height >> 8) & 0xFF;

    final command = BytesBuilder();
    command.addByte(0x1D); // GS
    command.addByte(0x76); // v
    command.addByte(0x30); // 0
    command.addByte(0x00); // m = 0 (normal)
    command.addByte(xL);
    command.addByte(xH);
    command.addByte(yL);
    command.addByte(yH);
    command.add(bitmapData);

    return command.toBytes();
  }

  /// Generate a simple test pattern for calibration
  static Uint8List generateTestPattern(double paperWidthMm) {
    final width = _getMaxWidthForPaper(paperWidthMm);
    final height = 200;

    final image = img.Image(width: width, height: height);

    // Fill white
    img.fill(image, color: img.ColorRgb8(255, 255, 255));

    // Draw calibration patterns
    final centerX = width ~/ 2;

    // Top border line
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < 5; y++) {
        image.setPixel(x, y, img.ColorRgb8(0, 0, 0));
      }
    }

    // Center marker
    for (int x = centerX - 20; x < centerX + 20; x++) {
      for (int y = 20; y < 30; y++) {
        image.setPixel(x, y, img.ColorRgb8(0, 0, 0));
      }
    }

    // Gradient bars for dithering test
    for (int i = 0; i < 10; i++) {
      final gray = (255 - (i * 25)).clamp(0, 255);
      final y = 50 + (i * 10);
      for (int x = width ~/ 4; x < (width * 3) ~/ 4; x++) {
        for (int row = 0; row < 8; row++) {
          image.setPixel(x, y + row, img.ColorRgb8(gray, gray, gray));
        }
      }
    }

    // Bottom border
    for (int x = 0; x < width; x++) {
      for (int y = height - 5; y < height; y++) {
        image.setPixel(x, y, img.ColorRgb8(0, 0, 0));
      }
    }

    // Convert to ESC/POS
    return _convertToEscPosBitmap(image, invert: false);
  }

  /// Generate text alignment test pattern
  static Uint8List generateAlignmentTest(double paperWidthMm) {
    final width = _getMaxWidthForPaper(paperWidthMm);
    final height = 150;

    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));

    // Left align marker (vertical line at 10%)
    final leftX = width ~/ 10;
    for (int y = 0; y < height; y++) {
      image.setPixel(leftX, y, img.ColorRgb8(0, 0, 0));
    }

    // Center marker (vertical line at 50%)
    final centerX = width ~/ 2;
    for (int y = 0; y < height; y++) {
      image.setPixel(centerX, y, img.ColorRgb8(0, 0, 0));
    }

    // Right align marker (vertical line at 90%)
    final rightX = (width * 9) ~/ 10;
    for (int y = 0; y < height; y++) {
      image.setPixel(rightX, y, img.ColorRgb8(0, 0, 0));
    }

    // Horizontal center line
    final centerY = height ~/ 2;
    for (int x = 0; x < width; x++) {
      image.setPixel(x, centerY, img.ColorRgb8(0, 0, 0));
    }

    return _convertToEscPosBitmap(image, invert: false);
  }

  /// Preprocess logo image from bytes
  static Future<Uint8List?> preprocessLogo(
    Uint8List logoBytes, {
    required double paperWidthMm,
    int? maxHeight,
    bool enableDithering = true,
  }) async {
    return processImageForPrinting(
      logoBytes,
      paperWidthMm: paperWidthMm,
      enableDithering: enableDithering,
      threshold: 128,
      invert: false,
    );
  }

  /// Convert Flutter ImageProvider to preprocessed bytes
  static Future<Uint8List?> processImageProvider(
    ImageProvider provider, {
    required double paperWidthMm,
    bool enableDithering = true,
  }) async {
    try {
      final stream = provider.resolve(ImageConfiguration.empty);
      final completer = Completer<Uint8List?>();

      final listener = ImageStreamListener(
        (info, _) async {
          final byteData = await info.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteData != null) {
            final bytes = byteData.buffer.asUint8List();
            final processed = await processImageForPrinting(
              bytes,
              paperWidthMm: paperWidthMm,
              enableDithering: enableDithering,
            );
            completer.complete(processed);
          } else {
            completer.complete(null);
          }
        },
        onError: (error, _) {
          completer.completeError(error);
        },
      );

      stream.addListener(listener);
      return await completer.future;
    } catch (e) {
      print('[ImagePreprocessing] Provider processing error: $e');
      return null;
    }
  }
}
