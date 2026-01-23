import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'package:exanor/screens/store_screen.dart'; // We will create this
import 'package:exanor/components/translation_widget.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _processData(barcode.rawValue!);
        return; // Only process the first one
      }
    }
  }

  Future<void> _processData(String data) async {
    setState(() {
      _isProcessing = true;
    });

    // UUID Regex
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    String? storeId;

    if (uuidRegex.hasMatch(data)) {
      storeId = data;
    } else {
      try {
        final uri = Uri.parse(data);
        if (uri.host == 'web.exanor.com') {
          // Check for 'id' parameter (new format) or 'store-id' (legacy/fallback)
          String? paramId;
          if (uri.pathSegments.contains('store') &&
              uri.queryParameters.containsKey('id')) {
            paramId = uri.queryParameters['id'];
          } else if (uri.queryParameters.containsKey('store-id')) {
            paramId = uri.queryParameters['store-id'];
          }

          if (paramId != null && uuidRegex.hasMatch(paramId)) {
            storeId = paramId;
          }
        }
      } catch (e) {
        // Not a URL
      }
    }

    if (storeId != null) {
      // Valid Store ID found
      _controller.stop();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StoreScreen(storeId: storeId!),
          ),
        );
      }
    } else {
      // Normal URL or other data
      await _launchData(data);
      // Resume scanning after handling
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _launchData(String data) async {
    final Uri? uri = Uri.tryParse(data);
    if (uri != null) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Check for email/phone if not a standard URL schema
    if (data.contains('@')) {
      final emailUri = Uri(scheme: 'mailto', path: data);
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        return;
      }
    }

    // Basic phone check (very simple)
    if (RegExp(
          r'^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\s\./0-9]*$',
        ).hasMatch(data) &&
        data.length > 6) {
      final phoneUri = Uri(scheme: 'tel', path: data);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        return;
      }
    }

    // If we reach here, maybe show a snackbar or dialog with the text?
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Scanned: $data')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _handleBarcode),

          // Overlay
          Container(
            decoration: ShapeDecoration(
              shape: _ScannerOverlayShape(
                borderColor: Theme.of(context).primaryColor,
                borderRadius: 20,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: MediaQuery.of(context).size.width * 0.7,
              ),
            ),
          ),

          // Scanning Line
          AnimatedBuilder(
            animation: _scanLineAnimation,
            builder: (context, child) {
              final cutOutSize = MediaQuery.of(context).size.width * 0.7;
              final topOffset =
                  (MediaQuery.of(context).size.height - cutOutSize) / 2;
              return Positioned(
                top: topOffset + (cutOutSize * _scanLineAnimation.value),
                left: (MediaQuery.of(context).size.width - cutOutSize) / 2,
                child: Container(
                  width: cutOutSize,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Close Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    color: Colors.white.withOpacity(0.2),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),

          // Torch Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                final isTorchOn = state.torchState == TorchState.on;
                return GestureDetector(
                  onTap: () => _controller.toggleTorch(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        color: isTorchOn
                            ? Colors.white.withOpacity(0.6)
                            : Colors.white.withOpacity(0.2),
                        child: Icon(
                          isTorchOn ? Icons.flash_on : Icons.flash_off,
                          color: isTorchOn ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Instruction Text
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 0,
            right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    color: Colors.black.withOpacity(0.4),
                    child: const TranslatedText(
                      'Scan QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Shape for Scanner Overlay
class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderLength;
  final double borderRadius;
  final double cutOutSize;

  const _ScannerOverlayShape({
    required this.borderColor,
    this.borderWidth = 10.0,
    this.borderLength = 20.0,
    this.borderRadius = 10.0,
    required this.cutOutSize,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(
        Path()
          ..addRect(Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height))
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: rect.center,
                width: cutOutSize,
                height: cutOutSize,
              ),
              Radius.circular(borderRadius),
            ),
          ),
        Offset.zero,
      );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final double cutOutWidth = cutOutSize;
    final double cutOutHeight = cutOutSize;
    final double leftOffset = (width - cutOutWidth) / 2;
    final double topOffset = (height - cutOutHeight) / 2;
    final double bottomOffset = topOffset + cutOutHeight;
    final double rightOffset = leftOffset + cutOutWidth;

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final boxRect = Rect.fromLTWH(
      leftOffset,
      topOffset,
      cutOutWidth,
      cutOutHeight,
    );

    // Draw background with cutout
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRRect(
          RRect.fromRectAndRadius(boxRect, Radius.circular(borderRadius)),
        ),
      ),
      backgroundPaint,
    );

    // Draw corners
    final path = Path();

    // Top Left
    path.moveTo(leftOffset, topOffset + borderLength);
    path.lineTo(leftOffset, topOffset + borderRadius);
    path.arcToPoint(
      Offset(leftOffset + borderRadius, topOffset),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(leftOffset + borderLength, topOffset);

    // Top Right
    path.moveTo(rightOffset - borderLength, topOffset);
    path.lineTo(rightOffset - borderRadius, topOffset);
    path.arcToPoint(
      Offset(rightOffset, topOffset + borderRadius),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(rightOffset, topOffset + borderLength);

    // Bottom Right
    path.moveTo(rightOffset, bottomOffset - borderLength);
    path.lineTo(rightOffset, bottomOffset - borderRadius);
    path.arcToPoint(
      Offset(rightOffset - borderRadius, bottomOffset),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(rightOffset - borderLength, bottomOffset);

    // Bottom Left
    path.moveTo(leftOffset + borderLength, bottomOffset);
    path.lineTo(leftOffset + borderRadius, bottomOffset);
    path.arcToPoint(
      Offset(leftOffset, bottomOffset - borderRadius),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(leftOffset, bottomOffset - borderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return _ScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      borderLength: borderLength * t,
      borderRadius: borderRadius * t,
      cutOutSize: cutOutSize * t,
    );
  }
}
