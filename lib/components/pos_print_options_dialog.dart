import 'package:flutter/material.dart';
import 'package:exanor/services/invoice_print_service.dart';
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

  Future<void> _handlePrint(String type, double widthInMm) async {
    setState(() => _isLoading = true);

    bool success = await InvoicePrintService.printPosInvoice(
      widget.orderId,
      type: type,
      widthInMm: widthInMm,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Failed to generate POS invoice'),
          ),
        );
      }
    }
  }

  void _showPrintMenu(BuildContext context, RenderBox box, String type) async {
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final value = await showMenu<double>(
      context: context,
      position: position,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 4,
      items: const [
        PopupMenuItem(value: 210.0, child: Text('A4 Size')),
        PopupMenuItem(value: 76.2, child: Text('3 Inch (76.2mm)')),
        PopupMenuItem(value: 50.8, child: Text('2 Inch (50.8mm)')),
      ],
    );

    if (value != null) {
      _handlePrint(type, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                const SizedBox(height: 24),

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
                  subtitle: '2 Tickets + 1 Invoice (3 Inch)',
                  icon: Icons.print_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: const Color(0xFFECFDF5),
                  onTap: () => _handlePrint('quick', 76.2),
                  isHighlighted: true,
                ),
                const SizedBox(height: 12),

                Builder(
                  builder: (ctx) => _buildDropdownTile(
                    context: ctx,
                    title: 'Print Invoice',
                    icon: Icons.receipt_rounded,
                    type: 'invoice',
                  ),
                ),
                const SizedBox(height: 12),

                Builder(
                  builder: (ctx) => _buildDropdownTile(
                    context: ctx,
                    title: 'Print Order Ticket',
                    icon: Icons.local_activity_rounded,
                    type: 'ticket',
                  ),
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
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const TranslatedText(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
        ],
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

  Widget _buildDropdownTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String type,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final RenderBox box = context.findRenderObject() as RenderBox;
          _showPrintMenu(context, box, type);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF64748B), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TranslatedText(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TranslatedText(
                      'Select',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
