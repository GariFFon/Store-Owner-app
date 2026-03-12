import 'package:flutter/material.dart';
import 'package:exanor/services/invoice_print_service.dart';
import 'package:exanor/services/bluetooth_print_service.dart';
import 'package:exanor/components/translation_widget.dart';

class PosPrintOptionsDialog extends StatefulWidget {
  final String orderId;
  final String title;
  final VoidCallback? onViewOrder;
  final VoidCallback? onNewOrder;

  const PosPrintOptionsDialog({
    super.key,
    required this.orderId,
    this.title = 'Order Placed Successfully!',
    this.onViewOrder,
    this.onNewOrder,
  });

  @override
  State<PosPrintOptionsDialog> createState() => _PosPrintOptionsDialogState();
}

class _PosPrintOptionsDialogState extends State<PosPrintOptionsDialog> {
  bool _isLoading = false;
  String? _savedPrinterName;
  double? _savedPaperSize;
  String? _connectionType; // 'bluetooth' or 'wifi_other'

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    final connType = await InvoicePrintService.getSavedConnectionType();
    String? printerName;

    if (connType == InvoicePrintService.connectionBluetooth) {
      printerName = await BluetoothPrintService.getSavedPrinterName();
    } else if (connType == InvoicePrintService.connectionWifi || connType == InvoicePrintService.connectionWired) {
      if (InvoicePrintService.isDesktop) {
        printerName = await InvoicePrintService.getSavedPrinterName();
      } else {
        printerName = 'System Print Dialog';
      }
    } else if (InvoicePrintService.isDesktop) {
      printerName = await InvoicePrintService.getSavedPrinterName();
    }

    final paperSize = await InvoicePrintService.getSavedPaperSize();
    if (mounted) {
      setState(() {
        _connectionType = connType;
        _savedPrinterName = printerName;
        _savedPaperSize = paperSize;
      });
    }
  }

  /// Show dialog to pick connection type (Bluetooth, WiFi/Network, or Wired/USB)
  Future<void> _showConnectionTypePicker() async {
    final isDesktop = InvoicePrintService.isDesktop;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('How is your printer connected?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConnectionOption(
              ctx,
              type: InvoicePrintService.connectionBluetooth,
              icon: Icons.bluetooth_rounded,
              title: 'Bluetooth',
              subtitle: isDesktop
                  ? 'Pair in Windows Settings first, then select here'
                  : 'For Bluetooth thermal printers (e.g. Seznik)',
              color: const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 10),
            _buildConnectionOption(
              ctx,
              type: InvoicePrintService.connectionWifi,
              icon: Icons.wifi_rounded,
              title: 'WiFi / Network',
              subtitle: isDesktop
                  ? 'Install printer in Windows Settings first'
                  : 'Uses system print dialog automatically',
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 10),
            _buildConnectionOption(
              ctx,
              type: InvoicePrintService.connectionWired,
              icon: Icons.usb_rounded,
              title: 'Wired (USB)',
              subtitle: isDesktop
                  ? 'Install printer in Windows Settings first'
                  : 'Uses system print dialog automatically',
              color: const Color(0xFFF59E0B),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      await InvoicePrintService.saveConnectionType(selected);
      if (!mounted) return;

      if (selected == InvoicePrintService.connectionBluetooth) {
        if (isDesktop) {
          // On Desktop, blue_thermal_printer doesn't work.
          // Guide user: pair BT printer in Windows, then pick from system printers.
          final goToPick = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 28),
                  SizedBox(width: 10),
                  Expanded(child: Text('Bluetooth on Desktop', style: TextStyle(fontSize: 18))),
                ],
              ),
              content: const Text(
                'To use a Bluetooth printer on Windows:\n\n'
                '1. Go to Windows Settings > Bluetooth & devices\n'
                '2. Pair your thermal printer\n'
                '3. Go to Settings > Printers & scanners\n'
                '4. Add the paired printer\n\n'
                'Once added, tap "Select Printer" below to pick it.',
                style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Select Printer'),
                ),
              ],
            ),
          );
          if (goToPick == true && mounted) {
            await InvoicePrintService.showPrinterPickerDialog(context);
          }
        } else {
          // On mobile, use blue_thermal_printer to scan BT devices
          await BluetoothPrintService.showPrinterPickerDialog(context);
        }
      } else if (selected == InvoicePrintService.connectionWifi || selected == InvoicePrintService.connectionWired) {
        if (isDesktop) {
          // On desktop, list installed system printers
          await InvoicePrintService.showPrinterPickerDialog(context);
        } else {
          // On mobile, system print dialog handles discovery automatically
          // Just show confirmation
          if (mounted) {
            BluetoothPrintService.showTopRightNotification(
              context,
              message: '${InvoicePrintService.getConnectionTypeLabel(selected)} selected!',
              detail: 'System will find printer automatically on print.',
              icon: Icons.check_circle_rounded,
              backgroundColor: const Color(0xFF10B981),
            );
          }
        }
      }

      await _loadSavedPreferences();
    }
  }

  Widget _buildConnectionOption(
    BuildContext ctx, {
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _connectionType == type;
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? color.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title, 
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14, // slightly smaller to prevent overflow
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle, 
                    style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle, color: color),
            ]
          ],
        ),
      ),
    );
  }

  /// Check if printer is set; if not, prompt user to set one.
  Future<bool> _ensurePrinterIsSet() async {
    // If no connection type is chosen yet, show picker
    if (_connectionType == null) {
      if (!mounted) return false;

      final shouldSetup = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.settings_rounded, color: Color(0xFF8B5CF6), size: 28),
              SizedBox(width: 10),
              Expanded(child: Text('Setup Printer')),
            ],
          ),
          content: const Text(
            'You need to set up your printer before printing. '
            'Choose how your printer is connected (Bluetooth, WiFi, USB, etc.)',
            style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Setup Printer'),
            ),
          ],
        ),
      );

      if (shouldSetup == true && mounted) {
        await _showConnectionTypePicker();
        return _connectionType != null;
      }
      return false;
    }

    // If Bluetooth, check if a BT printer is selected
    if (_connectionType == InvoicePrintService.connectionBluetooth) {
      final hasBtPrinter = await BluetoothPrintService.hasDefaultPrinter();
      if (!hasBtPrinter && mounted) {
        await BluetoothPrintService.showPrinterPickerDialog(context);
        await _loadSavedPreferences();
        return await BluetoothPrintService.hasDefaultPrinter();
      }
    }

    return true;
  }

  Future<void> _handlePrint(String type) async {
    // Check printer is set first
    final printerReady = await _ensurePrinterIsSet();
    if (!printerReady) return;

    // Use saved paper size, default to 76.2mm (3 inch) if not set
    final widthInMm = _savedPaperSize ?? 76.2;

    setState(() => _isLoading = true);

    if (mounted) {
      String typeLabel = type == 'quick' 
          ? 'Quick Print' 
          : type == 'invoice' 
              ? 'Invoice' 
              : 'Order Ticket';

      BluetoothPrintService.showTopRightNotification(
        context,
        message: 'Printing $typeLabel...',
        detail: 'Sending to printer',
        icon: Icons.print_rounded,
        backgroundColor: const Color(0xFF3B82F6),
        duration: const Duration(seconds: 2),
      );
    }

    bool success;
    if (_connectionType == InvoicePrintService.connectionBluetooth) {
      // Use Bluetooth direct printing
      success = await BluetoothPrintService.printPosInvoice(
        widget.orderId,
        type: type,
        widthInMm: widthInMm,
      );
    } else {
      // Use PDF-based printing (system dialog for WiFi/Network/USB)
      success = await InvoicePrintService.printPosInvoice(
        widget.orderId,
        type: type,
        widthInMm: widthInMm,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        BluetoothPrintService.showTopRightNotification(
          context,
          message: _connectionType == InvoicePrintService.connectionBluetooth
              ? 'Failed to print'
              : 'Print failed',
          detail: _connectionType == InvoicePrintService.connectionBluetooth
              ? 'Check if printer is on and in range'
              : 'Could not generate POS invoice',
          icon: Icons.error_outline_rounded,
          backgroundColor: const Color(0xFFEF4444),
        );
      }
    }
  }

  Future<void> _showPaperSizeSelector() async {
    final currentSize = _savedPaperSize;

    final selected = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        title: const Text(
          'Select Receipt Size',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...InvoicePrintService.paperSizeOptions.map((option) {
              final widthInMm = option['widthInMm'] as double;
              final label = option['label'] as String;
              final isSelected = widthInMm == currentSize;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected
                      ? const Color(0xFFEFF6FF)
                      : Colors.white,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Icon(
                    Icons.straighten_rounded,
                    color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF475569),
                      fontSize: 15,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF3B82F6))
                      : null,
                  onTap: () => Navigator.pop(ctx, widthInMm),
                ),
              );
            }),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      await InvoicePrintService.saveDefaultPaperSize(selected);
      await _loadSavedPreferences();
      if (mounted) {
        BluetoothPrintService.showTopRightNotification(
          context,
          message: 'Receipt size updated',
          detail: InvoicePrintService.getPaperSizeLabel(selected),
          icon: Icons.straighten_rounded,
          backgroundColor: const Color(0xFF3B82F6),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String paperSizeLabel = _savedPaperSize != null
        ? InvoicePrintService.getPaperSizeLabel(_savedPaperSize!)
        : 'Not set';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (widget.orderId.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TranslatedText(
                        'Order #${widget.orderId.length > 8 ? widget.orderId.substring(0, 8) : widget.orderId}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Settings Row: Printer + Paper Size ──
                  Row(
                    children: [
                      // Printer chip — shows connection type and printer name
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await _showConnectionTypePicker();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: _savedPrinterName != null
                                  ? const Color(0xFFF0FDF4)
                                  : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _savedPrinterName != null
                                    ? const Color(0xFF10B981).withOpacity(0.3)
                                    : const Color(0xFFEF4444).withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _connectionType != null
                                          ? InvoicePrintService.getConnectionTypeIcon(_connectionType!)
                                          : Icons.print_rounded,
                                      size: 14,
                                      color: _savedPrinterName != null
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _connectionType != null
                                          ? InvoicePrintService.getConnectionTypeLabel(_connectionType!)
                                          : 'Printer',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _savedPrinterName ?? 'Not set',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _savedPrinterName != null
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: _savedPrinterName != null
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFEF4444),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Paper Size chip — always shown
                      Expanded(
                        child: GestureDetector(
                          onTap: _showPaperSizeSelector,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: _savedPaperSize != null
                                  ? const Color(0xFFF0F9FF)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _savedPaperSize != null
                                    ? const Color(0xFF3B82F6).withOpacity(0.3)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.straighten_rounded,
                                      size: 14,
                                      color: _savedPaperSize != null
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Receipt Size',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  paperSizeLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _savedPaperSize != null
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: _savedPaperSize != null
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFF94A3B8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Actions List
                  if (widget.onViewOrder != null) ...[
                    _buildActionTile(
                      title: 'View Order Details',
                      subtitle: 'Review items and payments',
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      iconBgColor: const Color(0xFFEFF6FF),
                      onTap: widget.onViewOrder!,
                    ),
                    const SizedBox(height: 12),
                  ],

                  _buildActionTile(
                    title: 'Quick Print',
                    subtitle: '2 Tickets + 1 Invoice ($paperSizeLabel)',
                    icon: Icons.print_rounded,
                    iconColor: const Color(0xFF10B981),
                    iconBgColor: const Color(0xFFECFDF5),
                    onTap: () => _handlePrint('quick'),
                    isHighlighted: true,
                  ),
                  const SizedBox(height: 12),

                  _buildActionTile(
                    title: 'Print Invoice',
                    subtitle: 'Invoice only ($paperSizeLabel)',
                    icon: Icons.receipt_rounded,
                    iconColor: const Color(0xFF6366F1),
                    iconBgColor: const Color(0xFFEEF2FF),
                    onTap: () => _handlePrint('invoice'),
                  ),
                  const SizedBox(height: 12),

                  _buildActionTile(
                    title: 'Print Order Ticket',
                    subtitle: 'Kitchen ticket ($paperSizeLabel)',
                    icon: Icons.local_activity_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    iconBgColor: const Color(0xFFFFFBEB),
                    onTap: () => _handlePrint('ticket'),
                  ),

                  const SizedBox(height: 24),

                  // Bottom CTA
                  if (widget.onNewOrder != null)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: widget.onNewOrder,
                        child: const TranslatedText(
                          'Start New Order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const TranslatedText(
                          'Close Options',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Floating Success Icon
            Positioned(
              top: -32,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),

            // Loading Overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF10B981),
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 16),
                        TranslatedText(
                          'Processing...',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Close Icon if no actions available
            if (widget.onNewOrder == null && widget.onViewOrder == null)
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isHighlighted
                  ? iconColor.withOpacity(0.3)
                  : const Color(0xFFE2E8F0),
              width: isHighlighted ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            color: isHighlighted ? iconColor.withOpacity(0.04) : Colors.white,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TranslatedText(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    TranslatedText(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
