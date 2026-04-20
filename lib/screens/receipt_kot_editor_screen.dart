import 'package:flutter/material.dart';
import 'package:exanor/models/receipt_layout_config.dart';
import 'package:exanor/services/bluetooth_print_service.dart';

class ReceiptKotEditorScreen extends StatefulWidget {
  const ReceiptKotEditorScreen({super.key});

  @override
  State<ReceiptKotEditorScreen> createState() => _ReceiptKotEditorScreenState();
}

class _ReceiptKotEditorScreenState extends State<ReceiptKotEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ReceiptLayoutConfig? _receiptConfig;
  ReceiptLayoutConfig? _kotConfig;
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConfigs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConfigs() async {
    final receipt = await ReceiptLayoutConfig.load('receipt');
    final kot = await ReceiptLayoutConfig.load('kot');
    if (mounted) {
      setState(() {
        _receiptConfig = receipt;
        _kotConfig = kot;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfigs() async {
    if (_receiptConfig != null) await _receiptConfig!.save();
    if (_kotConfig != null) await _kotConfig!.save();
    if (mounted) {
      setState(() => _hasChanges = false);
      BluetoothPrintService.showTopRightNotification(
        context,
        message: 'Layout Saved ✓',
        detail: 'Your receipt & KOT layout has been updated',
        icon: Icons.check_circle_rounded,
        backgroundColor: const Color(0xFF10B981),
      );
    }
  }

  Future<void> _resetConfig(String type) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.restore_rounded, color: Color(0xFFF59E0B), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reset ${type == 'kot' ? 'KOT' : 'Receipt'} Layout?',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Text(
          'This will restore all sections to their default settings. This action cannot be undone.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ReceiptLayoutConfig.resetToDefaults(type);
      await _loadConfigs();
      if (mounted) {
        BluetoothPrintService.showTopRightNotification(
          context,
          message: '${type == 'kot' ? 'KOT' : 'Receipt'} layout reset',
          icon: Icons.restore_rounded,
          backgroundColor: const Color(0xFFF59E0B),
        );
      }
    }
  }

  ReceiptLayoutConfig get _activeConfig =>
      _tabController.index == 0 ? _receiptConfig! : _kotConfig!;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    const lightBlueBg = Color(0xFFEFF6FF);
    const watermarkColor = Color(0xFFDBEAFE);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // ── Premium Custom Header ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: lightBlueBg,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRect(
              child: Stack(
                children: [
                  // Watermark
                  Positioned(
                    right: -20,
                    bottom: -30,
                    child: Icon(
                      Icons.receipt_long_outlined,
                      size: 140,
                      color: watermarkColor.withValues(alpha: 0.6),
                    ),
                  ),
                  // Content
                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                          child: Row(
                            children: [
                              // Back Button
                              InkWell(
                                onTap: () {
                                  if (_hasChanges) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        title: const Text('Unsaved Changes'),
                                        content: const Text('You have unsaved changes. Save before leaving?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                                            child: const Text('Discard', style: TextStyle(color: Color(0xFFEF4444))),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF10B981),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: () async {
                                              Navigator.pop(ctx);
                                              await _saveConfigs();
                                              if (mounted) Navigator.pop(context);
                                            },
                                            child: const Text('Save & Exit'),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    Navigator.pop(context);
                                  }
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.blueGrey.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Padding(
                                      padding: EdgeInsets.only(right: 2),
                                      child: Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: Colors.black87,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Title
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Print Layouts',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E293B),
                                        letterSpacing: -0.5,
                                        height: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                                      ),
                                      child: Text(
                                        'RECEIPT & KOT CONFIG',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.blue[800],
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Actions
                              if (_hasChanges)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  child: TextButton.icon(
                                    onPressed: _saveConfigs,
                                    icon: const Icon(Icons.save_rounded, size: 18),
                                    label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF10B981),
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                  ),
                                ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
                                ),
                                child: PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded, color: Colors.blueGrey[700]),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'reset_receipt',
                                      child: _buildPopupItem(Icons.restore_rounded, 'Reset Receipt Layout', const Color(0xFFF59E0B)),
                                    ),
                                    PopupMenuItem(
                                      value: 'reset_kot',
                                      child: _buildPopupItem(Icons.restore_rounded, 'Reset KOT Layout', const Color(0xFFF59E0B)),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'reset_receipt') _resetConfig('receipt');
                                    if (value == 'reset_kot') _resetConfig('kot');
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        // TabBar injected seamlessly at the bottom of header
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            onTap: (_) => setState(() {}),
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicatorPadding: const EdgeInsets.all(3),
                            dividerColor: Colors.transparent,
                            labelColor: const Color(0xFF1E293B),
                            unselectedLabelColor: const Color(0xFF64748B),
                            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long_rounded, size: 18, color: _tabController.index == 0 ? const Color(0xFF1E293B) : const Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    const Text('Receipt Layout'),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.description_rounded, size: 18, color: _tabController.index == 1 ? const Color(0xFF1E293B) : const Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    const Text('OD Layout'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildConfigEditor(_receiptConfig!, isDark, Colors.white, textColor, subtextColor, borderColor),
                      _buildConfigEditor(_kotConfig!, isDark, Colors.white, textColor, subtextColor, borderColor),
                    ],
                  ),
          ),
        ],
      ),
    );
  }


  Widget _buildPopupItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildConfigEditor(
    ReceiptLayoutConfig config,
    bool isDark,
    Color surfaceColor,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    final isReceipt = config.type == 'receipt';
    final accentColor = isReceipt ? const Color(0xFF6366F1) : const Color(0xFFF59E0B);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 800;

        final settingsWidgets = [
          // ── Printer Settings Card ──
          _buildSettingsCard(
            title: 'Printer Settings',
            icon: Icons.print_rounded,
            iconColor: const Color(0xFF3B82F6),
            isDark: isDark,
            surfaceColor: surfaceColor,
            textColor: textColor,
            subtextColor: subtextColor,
            borderColor: borderColor,
            children: [
              _buildSwitchTile(
                title: 'Auto-Cut',
                subtitle: 'Automatically cut paper after printing (ESC/POS printers)',
                icon: Icons.content_cut_rounded,
                iconColor: const Color(0xFFEF4444),
                value: config.autoCutEnabled,
                onChanged: (v) {
                  setState(() {
                    config.autoCutEnabled = v;
                    _hasChanges = true;
                  });
                },
                isDark: isDark,
                textColor: textColor,
                subtextColor: subtextColor,
              ),
              if (config.autoCutEnabled) ...[
                const SizedBox(height: 12),
                _buildSliderTile(
                  title: 'Feed Lines Before Cut',
                  subtitle: '${config.autoCutFeedLines} lines',
                  icon: Icons.space_bar_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  value: config.autoCutFeedLines.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  onChanged: (v) {
                    setState(() {
                      config.autoCutFeedLines = v.round();
                      _hasChanges = true;
                    });
                  },
                  isDark: isDark,
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ],
              const SizedBox(height: 12),
              _buildDropdownTile(
                title: 'Global Font Size',
                subtitle: 'Base size for printer text',
                icon: Icons.format_size_rounded,
                iconColor: const Color(0xFF8B5CF6),
                value: config.globalFontSize.toString(),
                items: const [
                  DropdownMenuItem(value: '0', child: Text('Standard')),
                  DropdownMenuItem(value: '1', child: Text('Bold & Med')),
                  DropdownMenuItem(value: '2', child: Text('Large')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      config.globalFontSize = int.parse(v);
                      _hasChanges = true;
                    });
                  }
                },
                isDark: isDark,
                textColor: textColor,
                subtextColor: subtextColor,
              ),
              const SizedBox(height: 12),
              _buildDropdownTile(
                title: 'Paper Width (Chars)',
                subtitle: 'Fix printer side gaps by matching limit',
                icon: Icons.compress_rounded,
                iconColor: const Color(0xFF14B8A6),
                value: config.paperWidthChars.toString(),
                items: const [
                  DropdownMenuItem(value: '32', child: Text('58mm (32 chars)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: '42', child: Text('80mm (42 chars)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: '46', child: Text('80mm Narrow (46 chars)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: '48', child: Text('80mm Std (48 chars)', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      config.paperWidthChars = int.parse(v);
                      _hasChanges = true;
                    });
                  }
                },
                isDark: isDark,
                textColor: textColor,
                subtextColor: subtextColor,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Break Line Settings ──
          _buildSettingsCard(
            title: 'Section Dividers',
            icon: Icons.horizontal_rule_rounded,
            iconColor: const Color(0xFF10B981),
            isDark: isDark,
            surfaceColor: surfaceColor,
            textColor: textColor,
            subtextColor: subtextColor,
            borderColor: borderColor,
            children: [
              _buildSwitchTile(
                title: 'Show Break Lines',
                subtitle: 'Add separator lines between sections',
                icon: Icons.view_day_rounded,
                iconColor: const Color(0xFF10B981),
                value: config.showBreakLine,
                onChanged: (v) {
                  setState(() {
                    config.showBreakLine = v;
                    _hasChanges = true;
                  });
                },
                isDark: isDark,
                textColor: textColor,
                subtextColor: subtextColor,
              ),
              if (config.showBreakLine) ...[
                const SizedBox(height: 12),
                _buildBreakLineStyleSelector(config, isDark, textColor, subtextColor),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // ── Layout Sections ──
          _buildSettingsCard(
            title: 'Layout Sections',
            icon: Icons.view_list_rounded,
            iconColor: accentColor,
            isDark: isDark,
            surfaceColor: surfaceColor,
            textColor: textColor,
            subtextColor: subtextColor,
            borderColor: borderColor,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Drag to reorder',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
            children: [
              _buildSectionsList(config, isDark, surfaceColor, textColor, subtextColor, borderColor, accentColor),
            ],
          ),
          
          if (!isWideScreen) const SizedBox(height: 16),
        ];

        final previewWidget = _buildSettingsCard(
          title: 'Live Preview',
          icon: Icons.preview_rounded,
          iconColor: const Color(0xFFF97316),
          isDark: isDark,
          surfaceColor: surfaceColor,
          textColor: textColor,
          subtextColor: subtextColor,
          borderColor: borderColor,
          children: [
            _buildReceiptPreview(config, isDark, textColor, subtextColor),
          ],
        );

        if (isWideScreen) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...settingsWidgets,
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16, right: 16, bottom: 100),
                  child: previewWidget,
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...settingsWidgets,
            previewWidget,
            const SizedBox(height: 100),
          ],
        );
      },
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required Color surfaceColor,
    required Color textColor,
    required Color subtextColor,
    required Color borderColor,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? iconColor.withOpacity(0.3)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: value ? iconColor : subtextColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: subtextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: iconColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: iconColor),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: iconColor,
              inactiveTrackColor: iconColor.withOpacity(0.2),
              thumbColor: iconColor,
              overlayColor: iconColor.withOpacity(0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: subtextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: value,
                    items: items,
                    onChanged: onChanged,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: iconColor, size: 18),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakLineStyleSelector(
    ReceiptLayoutConfig config,
    bool isDark,
    Color textColor,
    Color subtextColor,
  ) {
    final styles = [
      {'id': 'dashed', 'label': 'Dashed', 'icon': Icons.horizontal_rule_rounded, 'preview': '- - - - - - - - -'},
      {'id': 'solid', 'label': 'Solid', 'icon': Icons.remove_rounded, 'preview': '─────────────'},
      {'id': 'dotted', 'label': 'Dotted', 'icon': Icons.more_horiz_rounded, 'preview': '· · · · · · · · ·'},
      {'id': 'double', 'label': 'Double', 'icon': Icons.drag_handle_rounded, 'preview': '═══════════'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: styles.map((style) {
        final isSelected = config.breakLineStyle == style['id'];
        return GestureDetector(
          onTap: () {
            setState(() {
              config.breakLineStyle = style['id'] as String;
              _hasChanges = true;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF10B981).withOpacity(isDark ? 0.2 : 0.08)
                  : isDark
                      ? const Color(0xFF0F172A).withOpacity(0.5)
                      : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF10B981)
                    : isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  style['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF10B981) : subtextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  style['preview'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    color: subtextColor,
                    fontFamily: 'monospace',
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionsList(
    ReceiptLayoutConfig config,
    bool isDark,
    Color surfaceColor,
    Color textColor,
    Color subtextColor,
    Color borderColor,
    Color accentColor,
  ) {
    final sortedSections = config.sortedSections;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: sortedSections.length,
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) {
            final double elevation = Tween<double>(begin: 0, end: 8).animate(animation).value;
            return Material(
              elevation: elevation,
              borderRadius: BorderRadius.circular(14),
              color: Colors.transparent,
              shadowColor: accentColor.withOpacity(0.3),
              child: child,
            );
          },
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = sortedSections.removeAt(oldIndex);
          sortedSections.insert(newIndex, item);
          // Update order values
          for (int i = 0; i < sortedSections.length; i++) {
            final section = config.sections.firstWhere((s) => s.id == sortedSections[i].id);
            section.order = i;
          }
          _hasChanges = true;
        });
      },
      itemBuilder: (context, index) {
        final section = sortedSections[index];
        return _buildSectionItem(
          key: ValueKey(section.id),
          index: index,
          section: section,
          config: config,
          isDark: isDark,
          surfaceColor: surfaceColor,
          textColor: textColor,
          subtextColor: subtextColor,
          borderColor: borderColor,
          accentColor: accentColor,
        );
      },
    );
  }

  Widget _buildSectionItem({
    required Key key,
    required int index,
    required ReceiptSection section,
    required ReceiptLayoutConfig config,
    required bool isDark,
    required Color surfaceColor,
    required Color textColor,
    required Color subtextColor,
    required Color borderColor,
    required Color accentColor,
  }) {
    final sectionColor = section.enabled ? accentColor : subtextColor;
    final bgColor = isDark 
        ? (section.enabled ? const Color(0xFF1E293B) : const Color(0xFF0F172A).withValues(alpha: 0.5))
        : (section.enabled ? Colors.white : const Color(0xFFF8FAFC));

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: section.enabled ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ] : null,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0).withValues(alpha: section.enabled ? 0.8 : 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Drag handle at left
            ReorderableDragStartListener(
              index: index,
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.only(right: 14, top: 4, bottom: 4),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: subtextColor.withValues(alpha: 0.6),
                  size: 26,
                ),
              ),
            ),
            
            // Grand Number Base
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: section.enabled ? sectionColor.withValues(alpha: 0.15) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: sectionColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Context & Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    section.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: section.enabled ? textColor : subtextColor.withValues(alpha: 0.8),
                    ),
                  ),
                  if (_getSectionSubtitle(section) != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _getSectionSubtitle(section)!,
                      style: TextStyle(
                        fontSize: 13,
                        color: subtextColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // Actions on the right
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasSectionSettings(section))
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showSectionSettings(section, config),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.settings_outlined, size: 24, color: subtextColor),
                        ),
                      ),
                    ),
                  ),
                Switch.adaptive(
                  value: section.enabled,
                  onChanged: (v) {
                    setState(() {
                      section.enabled = v;
                      _hasChanges = true;
                    });
                  },
                  activeColor: accentColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  String? _getSectionSubtitle(ReceiptSection section) {
    switch (section.id) {
      case 'store_logo': return 'Logo size: ${section.options['size'] ?? 'medium'}';
      case 'store_name':
        final opts = section.options;
        final parts = <String>[];
        if (opts['showAddress'] == true) parts.add('Address');
        if (opts['showPhone'] == true) parts.add('Phone');
        if (opts['showGST'] == true) parts.add('GST');
        return parts.isEmpty ? null : parts.join(' • ');
      case 'qr_code': return 'Size: ${section.options['size'] ?? 'medium'}';
      case 'footer_message': return section.options['text'] as String?;
      case 'kot_header': return section.options['title'] as String?;
      case 'items_list': return 'Font: ${section.options['fontSize'] ?? 'normal'}';
      default: return null;
    }
  }

  bool _hasSectionSettings(ReceiptSection section) {
    return [
      'store_name', 'store_logo', 'bill_info', 'customer_info',
      'products_table', 'qr_code', 'footer_message',
      'kot_header', 'order_info', 'items_list', 'kot_footer',
    ].contains(section.id);
  }

  void _showSectionSettings(ReceiptSection section, ReceiptLayoutConfig config) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SectionSettingsSheet(
        section: section,
        configType: config.type,
        onSave: (updatedSection) {
          setState(() {
            final idx = config.sections.indexWhere((s) => s.id == section.id);
            if (idx != -1) {
              config.sections[idx] = updatedSection;
            }
            _hasChanges = true;
          });
        },
      ),
    );
  }

  // ─── Receipt Preview ──────────────────────────────────────────

  // ─── Dynamic font sizes based on config ────────────
  double _previewBaseFontSize(ReceiptLayoutConfig config) {
    switch (config.globalFontSize) {
      case 1: return 11.5;
      case 2: return 13.5;
      default: return 10.0;
    }
  }

  double _previewTitleFontSize(ReceiptLayoutConfig config) {
    switch (config.globalFontSize) {
      case 1: return 14.0;
      case 2: return 16.0;
      default: return 12.0;
    }
  }

  // Map paperWidthChars → preview container width px
  double _previewContainerWidth(ReceiptLayoutConfig config) {
    switch (config.paperWidthChars) {
      case 32: return 240;
      case 42: return 290;
      case 46: return 310;
      case 48: return 320;
      default: return 320;
    }
  }

  Widget _buildReceiptPreview(
    ReceiptLayoutConfig config,
    bool isDark,
    Color textColor,
    Color subtextColor,
  ) {
    final enabledSections = config.enabledSections;
    final breakLineChar = _getBreakLineChar(config.breakLineStyle);
    final containerWidth = _previewContainerWidth(config);
    final baseFontSize = _previewBaseFontSize(config);

    // Settings badge label
    final fontLabel = config.globalFontSize == 0 ? 'Std' : config.globalFontSize == 1 ? 'Med' : 'Lg';
    final widthLabel = '${config.paperWidthChars}ch';

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: containerWidth,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFDFD),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Preview header badge with live info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '📄 ${config.type == 'kot' ? 'KOT' : 'Receipt'}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      fontLabel,
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF6366F1)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widthLabel,
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF14B8A6)),
                    ),
                  ),
                ],
              ),
            ),

            // Render enabled sections
            for (int i = 0; i < enabledSections.length; i++) ...[
              _buildPreviewSection(enabledSections[i], config),
              if (config.showBreakLine && i < enabledSections.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    breakLineChar * 100,
                    style: TextStyle(
                      fontSize: baseFontSize,
                      color: const Color(0xFFE2E8F0),
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                  ),
                ),
            ],

            // Auto-cut indicator
            if (config.autoCutEnabled) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.content_cut_rounded, size: 14, color: Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    Text(
                      '✂ AUTO CUT (${config.autoCutFeedLines} feed lines)',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection(ReceiptSection section, ReceiptLayoutConfig config) {
    final baseFontSize = _previewBaseFontSize(config);
    final titleFontSize = _previewTitleFontSize(config);

    final textStyle = TextStyle(fontSize: baseFontSize, color: const Color(0xFF475569), fontFamily: 'monospace');
    final boldStyle = TextStyle(fontSize: baseFontSize, color: const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontFamily: 'monospace');
    final titleStyle = TextStyle(fontSize: titleFontSize, color: const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontFamily: 'monospace');

    switch (section.id) {
      case 'store_logo':
        return const Icon(Icons.image_rounded, size: 32, color: Color(0xFFCBD5E1));
      case 'store_name':
        return Column(
          children: [
            Text('MY STORE NAME', style: titleStyle, textAlign: TextAlign.center),
            if (section.options['showAddress'] == true)
              Text('123 Main Street, City', style: textStyle, textAlign: TextAlign.center),
            if (section.options['showPhone'] == true)
              Text('Ph: +91 98765 43210', style: textStyle, textAlign: TextAlign.center),
            if (section.options['showGST'] == true)
              Text('GSTIN: 29XXXXX1234X1Z5', style: textStyle, textAlign: TextAlign.center),
          ],
        );
      case 'bill_info':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (section.options['showBillNo'] != false)
              Text('Bill No: INV-001', style: textStyle),
            if (section.options['showTokenNo'] != false)
              Text('Token No: T-042', style: textStyle),
            if (section.options['showDate'] != false)
              Text('Date: 2026-04-18 10:30', style: textStyle),
          ],
        );
      case 'customer_info':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (section.options['showName'] != false)
              Text('Customer: John Doe', style: textStyle),
            if (section.options['showPhone'] != false)
              Text('Phone: +91 12345 67890', style: textStyle),
          ],
        );
      case 'products_table':
        return Column(
          children: [
            if (section.options['showHeader'] != false)
              Row(
                children: [
                  Expanded(flex: 5, child: Text('Item', style: boldStyle)),
                  Expanded(flex: 2, child: Text('Qty', style: boldStyle, textAlign: TextAlign.center)),
                  Expanded(flex: 3, child: Text('Amt', style: boldStyle, textAlign: TextAlign.right)),
                ],
              ),
            SizedBox(height: baseFontSize * 0.4),
            ...['Butter Chicken', 'Naan (2x)', 'Dal Tadka'].map((item) => Padding(
              padding: EdgeInsets.symmetric(vertical: baseFontSize * 0.1),
              child: Row(
                children: [
                  Expanded(flex: 5, child: Text(item, style: textStyle)),
                  Expanded(flex: 2, child: Text('1', style: textStyle, textAlign: TextAlign.center)),
                  Expanded(flex: 3, child: Text('₹350', style: textStyle, textAlign: TextAlign.right)),
                ],
              ),
            )),
          ],
        );
      case 'items_list':
        final showQty = section.options['showQuantity'] != false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ITEMS:', style: boldStyle),
            SizedBox(height: baseFontSize * 0.3),
            ...['Butter Chicken', 'Naan', 'Dal Tadka'].map((item) => Padding(
              padding: EdgeInsets.symmetric(vertical: baseFontSize * 0.1),
              child: Text(
                showQty ? '1x $item' : item,
                style: textStyle,
              ),
            )),
          ],
        );
      case 'cart_totals':
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal', style: textStyle),
                Text('₹850', style: textStyle),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tax (5%)', style: textStyle),
                Text('₹42.50', style: textStyle),
              ],
            ),
          ],
        );
      case 'platform_fees':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Platform Fee', style: textStyle),
            Text('₹10.00', style: textStyle),
          ],
        );
      case 'grand_total':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('GRAND TOTAL', style: titleStyle),
            Text('₹902.50', style: titleStyle),
          ],
        );
      case 'qr_code':
        final qrSize = section.options['size'] == 'small' ? 40.0 : section.options['size'] == 'large' ? 80.0 : 60.0;
        return Column(
          children: [
            Container(
              width: qrSize,
              height: qrSize,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.qr_code_2_rounded, size: qrSize * 0.65, color: const Color(0xFF94A3B8)),
            ),
          ],
        );
      case 'footer_message':
        return Text(
          section.options['text'] as String? ?? config.footerText,
          style: boldStyle,
          textAlign: TextAlign.center,
        );
      case 'kot_header':
        return Text(
          section.options['title'] as String? ?? 'KITCHEN TICKET',
          style: titleStyle,
          textAlign: TextAlign.center,
        );
      case 'order_info':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (section.options['showOrderId'] != false)
              Text('Order ID: ORD-12345', style: textStyle),
            if (section.options['showCustomerName'] != false)
              Text('Customer: John Doe', style: textStyle),
            if (section.options['showDate'] != false)
              Text('Date: 2026-04-18 10:30', style: textStyle),
          ],
        );
      case 'special_instructions':
        return Text('Notes: No onions, extra spicy', style: textStyle);
      case 'kot_footer':
        final ft = section.options['text'] as String? ?? '';
        return ft.isEmpty
            ? const SizedBox.shrink()
            : Text(ft, style: textStyle, textAlign: TextAlign.center);
      default:
        return Text('[${section.label}]', style: textStyle, textAlign: TextAlign.center);
    }
  }

  String _getBreakLineChar(String style) {
    switch (style) {
      case 'solid': return '─';
      case 'dotted': return '·';
      case 'double': return '═';
      default: return '-';
    }
  }
}

// ─── Section Settings Bottom Sheet ────────────────────────────────

class _SectionSettingsSheet extends StatefulWidget {
  final ReceiptSection section;
  final String configType;
  final ValueChanged<ReceiptSection> onSave;

  const _SectionSettingsSheet({
    required this.section,
    required this.configType,
    required this.onSave,
  });

  @override
  State<_SectionSettingsSheet> createState() => _SectionSettingsSheetState();
}

class _SectionSettingsSheetState extends State<_SectionSettingsSheet> {
  late ReceiptSection _editedSection;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _editedSection = widget.section.copyWith();
    // Initialize text controller for text-editable sections
    String initialText = '';
    if (widget.section.id == 'footer_message' || widget.section.id == 'kot_footer') {
      initialText = widget.section.options['text'] as String? ?? '';
    } else if (widget.section.id == 'kot_header') {
      initialText = widget.section.options['title'] as String? ?? 'KITCHEN TICKET';
    }
    _textController = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: const Color(0xFF6366F1), size: 24),
                const SizedBox(width: 10),
                Text(
                  '${_editedSection.label} Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          // Settings based on section type
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildSectionSpecificSettings(isDark, textColor, subtextColor),
              ),
            ),
          ),

          // Save button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  widget.onSave(_editedSection);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Save Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSectionSpecificSettings(bool isDark, Color textColor, Color subtextColor) {
    final section = _editedSection;
    final widgets = <Widget>[];

    switch (section.id) {
      case 'store_name':
        widgets.addAll([
          _buildOptionSwitch('Show Address', 'showAddress', isDark, textColor),
          _buildOptionSwitch('Show Phone', 'showPhone', isDark, textColor),
          _buildOptionSwitch('Show GST Number', 'showGST', isDark, textColor),
        ]);
        break;
      case 'store_logo':
        widgets.add(_buildSizeSelector('Logo Size', 'size', ['small', 'medium', 'large'], isDark, textColor, subtextColor));
        break;
      case 'bill_info':
        widgets.addAll([
          _buildOptionSwitch('Show Bill Number', 'showBillNo', isDark, textColor),
          _buildOptionSwitch('Show Token Number', 'showTokenNo', isDark, textColor),
          _buildOptionSwitch('Show Date/Time', 'showDate', isDark, textColor),
        ]);
        break;
      case 'customer_info':
        widgets.addAll([
          _buildOptionSwitch('Show Customer Name', 'showName', isDark, textColor),
          _buildOptionSwitch('Show Phone', 'showPhone', isDark, textColor),
        ]);
        break;
      case 'products_table':
        widgets.addAll([
          _buildOptionSwitch('Show Table Header', 'showHeader', isDark, textColor),
          _buildOptionSwitch('Show Unit Price', 'showUnitPrice', isDark, textColor),
          _buildOptionSwitch('Show Tax Details', 'showTax', isDark, textColor),
          _buildSizeSelector('Display Format', 'format', ['compact', 'detailed'], isDark, textColor, subtextColor),
        ]);
        break;
      case 'qr_code':
        widgets.addAll([
          _buildSizeSelector('QR Size', 'size', ['small', 'medium', 'large'], isDark, textColor, subtextColor),
          _buildSizeSelector('Position', 'position', ['left', 'center', 'right'], isDark, textColor, subtextColor),
        ]);
        break;
      case 'footer_message':
      case 'kot_footer':
        widgets.add(_buildTextInputSetting(
          'Footer Text',
          'text',
          isDark, textColor,
          hint: 'Enter footer message...',
        ));
        break;
      case 'kot_header':
        widgets.addAll([
          _buildTextInputSetting('Header Title', 'title', isDark, textColor, hint: 'e.g. KITCHEN TICKET'),
          _buildOptionSwitch('Bold Text', 'showBold', isDark, textColor),
        ]);
        break;
      case 'order_info':
        widgets.addAll([
          _buildOptionSwitch('Show Order ID', 'showOrderId', isDark, textColor),
          _buildOptionSwitch('Show Customer Name', 'showCustomerName', isDark, textColor),
          _buildOptionSwitch('Show Date/Time', 'showDate', isDark, textColor),
          _buildOptionSwitch('Show Table Number', 'showTableNo', isDark, textColor),
        ]);
        break;
      case 'items_list':
        widgets.addAll([
          _buildOptionSwitch('Show Quantity', 'showQuantity', isDark, textColor),
          _buildOptionSwitch('Show Price', 'showPrice', isDark, textColor),
          _buildOptionSwitch('Show Notes', 'showNotes', isDark, textColor),
          _buildSizeSelector('Font Size', 'fontSize', ['small', 'normal', 'large'], isDark, textColor, subtextColor),
        ]);
        break;
    }

    return widgets;
  }

  Widget _buildOptionSwitch(String label, String optionKey, bool isDark, Color textColor) {
    final value = _editedSection.options[optionKey] as bool? ?? true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent, // More minimal look
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            Transform.scale(
              scale: 0.85,
              child: Switch.adaptive(
                value: value,
                onChanged: (v) {
                  setState(() {
                    _editedSection.options[optionKey] = v;
                  });
                },
                activeColor: const Color(0xFF6366F1),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeSelector(
    String label,
    String optionKey,
    List<String> options,
    bool isDark,
    Color textColor,
    Color subtextColor,
  ) {
    final currentValue = _editedSection.options[optionKey] as String? ?? options.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: subtextColor),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((opt) {
              final isSelected = currentValue == opt;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _editedSection.options[optionKey] = opt;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.1)
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    opt[0].toUpperCase() + opt.substring(1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF6366F1) : subtextColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInputSetting(
    String label,
    String optionKey,
    bool isDark,
    Color textColor, {
    String hint = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            onChanged: (val) {
              _editedSection.options[optionKey] = val;
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: TextStyle(fontSize: 14, color: textColor),
          ),
        ],
      ),
    );
  }
}
