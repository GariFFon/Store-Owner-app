import 'package:flutter/material.dart';
import 'package:exanor/services/printer_capability_service.dart';
import 'package:exanor/models/receipt_layout_config.dart';

/// Virtual Printer Preview - Simulates ESC/POS output on screen
/// This acts as a "virtual thermal printer" to preview receipts before printing
class VirtualPrinterPreview extends StatefulWidget {
  final double paperWidthMm;
  final PrinterProfile? printerProfile;
  final ReceiptLayoutConfig? config;
  final Map<String, dynamic>? sampleData;
  final bool showRuler;
  final bool showMargins;

  const VirtualPrinterPreview({
    super.key,
    this.paperWidthMm = 80.0,
    this.printerProfile,
    this.config,
    this.sampleData,
    this.showRuler = true,
    this.showMargins = true,
  });

  @override
  State<VirtualPrinterPreview> createState() => _VirtualPrinterPreviewState();
}

class _VirtualPrinterPreviewState extends State<VirtualPrinterPreview> {
  late double _currentWidth;
  late PrinterProfile _currentProfile;
  int _selectedTab = 0; // 0=Receipt, 1=KOT, 2=Calibration

  @override
  void initState() {
    super.initState();
    _currentWidth = widget.paperWidthMm;
    _currentProfile = widget.printerProfile ?? PrinterProfiles.generic80;
  }

  @override
  Widget build(BuildContext context) {
    final int charsPerLine = _currentProfile.getCharsPerLine(_currentWidth);
    final double paperWidthPx = _currentWidth == 58 ? 280 : 380;

    return Dialog(
      backgroundColor: Colors.grey[900],
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.print, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Virtual Printer Preview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Controls
                  Row(
                    children: [
                      // Paper width selector
                      Expanded(
                        child: SegmentedButton<double>(
                          segments: const [
                            ButtonSegment(
                              value: 58.0,
                              label: Text('58mm'),
                              icon: Icon(Icons.receipt),
                            ),
                            ButtonSegment(
                              value: 80.0,
                              label: Text('80mm'),
                              icon: Icon(Icons.receipt_long),
                            ),
                          ],
                          selected: {_currentWidth},
                          onSelectionChanged: (value) {
                            setState(() {
                              _currentWidth = value.first;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Printer profile selector
                      Expanded(
                        child: DropdownButtonFormField<PrinterProfile>(
                          value: _currentProfile,
                          dropdownColor: Colors.grey[800],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[700],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: PrinterProfiles.allProfiles.map((profile) {
                            return DropdownMenuItem(
                              value: profile,
                              child: Text(
                                profile.model,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _currentProfile = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Info chips
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildInfoChip('$charsPerLine chars/line'),
                      _buildInfoChip('${_currentProfile.dpi} DPI'),
                      if (_currentProfile.supportsCut)
                        _buildInfoChip('Auto-cut ✓')
                      else
                        _buildInfoChip('No cutter ✗'),
                      if (_currentProfile.supportsNativeQr)
                        _buildInfoChip('Native QR ✓')
                      else
                        _buildInfoChip('Img QR'),
                    ],
                  ),
                ],
              ),
            ),
            // Tab selector
            Container(
              color: Colors.grey[850],
              child: Row(
                children: [
                  _buildTabButton('Receipt Preview', 0),
                  _buildTabButton('KOT Preview', 1),
                  _buildTabButton('Calibration', 2),
                ],
              ),
            ),
            // Preview content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Container(
                    width: paperWidthPx,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.showRuler) _buildRuler(charsPerLine),
                        if (widget.showMargins) _buildMarginIndicators(),
                        _buildPreviewContent(charsPerLine),
                        if (widget.showMargins) _buildMarginIndicators(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Footer actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showCalibrationDialog(context),
                    icon: const Icon(Icons.tune),
                    label: const Text('Calibrate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _printReal(context),
                    icon: const Icon(Icons.print),
                    label: const Text('Print Real'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.blue : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
      backgroundColor: Colors.grey[700],
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildRuler(int charsPerLine) {
    return Container(
      height: 20,
      color: Colors.grey[200],
      child: Row(
        children: List.generate(charsPerLine + 1, (index) {
          if (index == 0 || index == charsPerLine || index == charsPerLine ~/ 2) {
            return Container(
              width: 2,
              color: Colors.red.withOpacity(0.5),
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(fontSize: 8, color: Colors.red),
                ),
              ),
            );
          }
          if (index % 10 == 0) {
            return Container(
              width: 1,
              color: Colors.grey[400],
              child: Center(
                child: Text(
                  '${index ~/ 10}',
                  style: TextStyle(fontSize: 6, color: Colors.grey[600]),
                ),
              ),
            );
          }
          return Container(width: 1, color: Colors.grey[300]);
        }),
      ),
    );
  }

  Widget _buildMarginIndicators() {
    return Container(
      height: 8,
      color: Colors.yellow[100],
      child: Row(
        children: [
          Container(width: 4, color: Colors.yellow[300]),
          const Expanded(
            child: Center(
              child: Text(
                'MARGIN',
                style: TextStyle(fontSize: 6, color: Colors.orange),
              ),
            ),
          ),
          Container(width: 4, color: Colors.yellow[300]),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(int charsPerLine) {
    switch (_selectedTab) {
      case 0:
        return _buildReceiptPreview(charsPerLine);
      case 1:
        return _buildKOTPreview(charsPerLine);
      case 2:
        return _buildCalibrationPreview(charsPerLine);
      default:
        return _buildReceiptPreview(charsPerLine);
    }
  }

  Widget _buildReceiptPreview(int charsPerLine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Store header
          _buildText('MY STORE', align: TextAlign.center, bold: true, size: 18),
          _buildText('123 Main Street, City', align: TextAlign.center),
          _buildText('GST: 12ABCDE1234F1Z5', align: TextAlign.center),
          _buildDivider(charsPerLine, '='),
          
          // Bill info
          _buildText('BILL NO: 00123'),
          _buildText('DATE: 2024-01-15 14:30'),
          _buildDivider(charsPerLine, '-'),
          
          // Items header
          _buildRow('Item', 'Qty', 'Amt', charsPerLine),
          _buildDivider(charsPerLine, '-'),
          
          // Sample items
          _buildRow('Burger Cheese', '2', '240.00', charsPerLine),
          _buildRow('Fries Large', '1', '120.00', charsPerLine),
          _buildRow('Coke 500ml', '3', '180.00', charsPerLine),
          _buildRow('Chicken Wrap Spicy', '1', '199.00', charsPerLine),
          _buildDivider(charsPerLine, '-'),
          
          // Totals
          _buildRow('Subtotal', '', '739.00', charsPerLine),
          _buildRow('GST (5%)', '', '36.95', charsPerLine),
          _buildRow('Platform Fee', '', '15.00', charsPerLine),
          _buildDivider(charsPerLine, '-'),
          _buildRow('TOTAL', '', '790.95', charsPerLine, bold: true),
          _buildDivider(charsPerLine, '='),
          
          // Footer
          _buildText('Thank you for visiting!', align: TextAlign.center),
          _buildText('Scan for digital invoice', align: TextAlign.center),
          const SizedBox(height: 8),
          // QR placeholder
          Container(
            height: 80,
            color: Colors.grey[100],
            child: const Center(
              child: Text('[QR CODE]', style: TextStyle(color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 8),
          _buildText('--- END OF BILL ---', align: TextAlign.center),
          const SizedBox(height: 16),
          // Cut indicator
          Container(
            height: 20,
            color: Colors.grey[200],
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cut, size: 12, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('CUT HERE', style: TextStyle(fontSize: 8, color: Colors.grey)),
                  SizedBox(width: 4),
                  Icon(Icons.cut, size: 12, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKOTPreview(int charsPerLine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KOT Header
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Text(
              'KITCHEN ORDER TICKET',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          _buildText('Token: #042', bold: true, size: 20),
          _buildText('Order #12345'),
          _buildText('Table: T-12'),
          _buildText('Time: 14:30:22'),
          _buildDivider(charsPerLine, '='),
          
          // Items (Kitchen style - larger text)
          _buildText('2x Burger Cheese', size: 16),
          _buildText('   [NO ONION, EXTRA CHEESE]'),
          const SizedBox(height: 8),
          _buildText('1x Chicken Wrap Spicy', size: 16),
          _buildText('   [MEDIUM SPICY]'),
          const SizedBox(height: 8),
          _buildText('3x Coke 500ml', size: 16),
          _buildDivider(charsPerLine, '='),
          
          _buildText('Priority: NORMAL', align: TextAlign.center),
          _buildDivider(charsPerLine, '-'),
          
          // Kitchen instructions
          Container(
            color: Colors.yellow[100],
            padding: const EdgeInsets.all(4),
            child: const Text(
              'SPECIAL: Allergic to nuts!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          
          // Cut indicator
          Container(
            height: 20,
            color: Colors.grey[200],
            child: const Center(
              child: Text('✂️ CUT HERE', style: TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationPreview(int charsPerLine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildText('CALIBRATION TEST', align: TextAlign.center, bold: true, size: 18),
          _buildDivider(charsPerLine, '='),
          
          _buildText('ALIGNMENT TEST:', bold: true),
          _buildText('LEFT', align: TextAlign.left),
          _buildText('CENTER', align: TextAlign.center),
          _buildText('RIGHT', align: TextAlign.right),
          _buildDivider(charsPerLine, '-'),
          
          _buildText('CHARACTER WIDTH:', bold: true),
          _buildText('0' * charsPerLine, fontFamily: 'Courier'),
          _buildText('X' * charsPerLine, fontFamily: 'Courier'),
          _buildDivider(charsPerLine, '-'),
          
          _buildText('DIVIDER STYLES:', bold: true),
          _buildText('-' * charsPerLine),
          _buildText('_' * charsPerLine),
          _buildText('=' * charsPerLine),
          _buildText('. ' * (charsPerLine ~/ 2)),
          _buildDivider(charsPerLine, '-'),
          
          _buildText('COLUMN TEST:', bold: true),
          _buildRow('Item Name', 'Qty', 'Price', charsPerLine),
          _buildRow('Burger', '2', '240', charsPerLine),
          _buildRow('Long Item Name', '1', '199', charsPerLine),
          _buildDivider(charsPerLine, '='),
          
          _buildText('FONT SIZES:', bold: true),
          _buildText('Size 8 (Small)'),
          _buildText('Size 12 (Normal)'),
          _buildText('Size 16 (Medium)'),
          _buildText('Size 20 (Large)'),
          _buildDivider(charsPerLine, '-'),
          
          _buildText('BORDER TEST:', bold: true),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1),
            ),
            padding: const EdgeInsets.all(4),
            child: const Text('Box Border'),
          ),
          _buildDivider(charsPerLine, '='),
          
          // Feed lines visualization
          _buildText('FEED LINES TEST:', bold: true),
          ...List.generate(5, (index) => _buildText('Line ${index + 1}')),
          _buildDivider(charsPerLine, '-'),
          
          _buildText('--- END CALIBRATION ---', align: TextAlign.center),
          const SizedBox(height: 16),
          
          // Cut indicator with feed lines
          Container(
            height: 60,
            color: Colors.grey[100],
            child: Column(
              children: [
                const Text('Feed 3 lines then cut', style: TextStyle(fontSize: 8)),
                const Divider(),
                const Icon(Icons.cut, size: 16),
                const Text('✂️ CUT HERE ✂️', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildText(
    String text, {
    TextAlign align = TextAlign.left,
    bool bold = false,
    double size = 12,
    String? fontFamily,
  }) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontFamily: fontFamily ?? 'Courier',
        fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        height: 1.2,
        color: Colors.black,
      ),
    );
  }

  Widget _buildDivider(int width, String char) {
    return Text(
      char * width,
      style: const TextStyle(
        fontFamily: 'Courier',
        fontSize: 12,
        color: Colors.black,
      ),
    );
  }

  Widget _buildRow(String left, String center, String right, int width, {bool bold = false}) {
    final qtyW = width <= 32 ? 6 : 8;
    final amtW = width <= 32 ? 8 : 10;
    final nameW = width - qtyW - amtW;
    
    final line = left.padRight(nameW) + center.padLeft(qtyW) + right.padLeft(amtW);
    
    return Text(
      line,
      style: TextStyle(
        fontFamily: 'Courier',
        fontSize: 12,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _showCalibrationDialog(BuildContext context) {
    // This would trigger the actual calibration print
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Print Calibration'),
        content: Text(
          'Send calibration test to ${_currentProfile.model} on ${_currentWidth}mm paper?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Trigger actual calibration print
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calibration sent to printer')),
              );
            },
            child: const Text('Print Test'),
          ),
        ],
      ),
    );
  }

  void _printReal(BuildContext context) {
    // This would trigger actual printing
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Print'),
        content: const Text('Send this receipt to the actual printer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Trigger actual print
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sent to printer')),
              );
            },
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }
}
