import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/screens/ob_trial_balance_screen.dart';

class OBOperationsScreen extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String fyLabel;

  const OBOperationsScreen({
    super.key,
    required this.storeId,
    required this.financialYearId,
    required this.fyLabel,
  });

  @override
  State<OBOperationsScreen> createState() => _OBOperationsScreenState();
}

class _OBOperationsScreenState extends State<OBOperationsScreen> {
  // ── Generate OB Voucher Dialog ─────────────────────────────────────────────

  void _showGenerateVoucherDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GenerateVoucherDialog(
        storeId: widget.storeId,
        financialYearId: widget.financialYearId,
        fyLabel: widget.fyLabel,
      ),
    );
  }

  // ── Carry Forward Dialog ───────────────────────────────────────────────────

  void _showCarryForwardDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CarryForwardDialog(
        storeId: widget.storeId,
        fromFinancialYearId: widget.financialYearId,
      ),
    );
  }

  // ── Trial Balance FY Picker ─────────────────────────────────────────────────

  void _showTrialBalanceFyPicker() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TrialBalanceFyPickerDialog(
        storeId: widget.storeId,
      ),
    );
  }

  void _showResultSnackBar(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildTopBanner(context)),

            // LIFECYCLE ACTIONS
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: _sectionHeader('LIFECYCLE ACTIONS'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildListDelegate([
                  _buildActionCard(
                    icon: Icons.restore_rounded,
                    iconBgColor: const Color(0xFFFFF7ED),
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Generate OB Voucher',
                    description:
                        'Compiles all your pending raw Opening Balance records (Accounts + Inventory) and injects them as a verified OPENING_BALANCE voucher for the current FY.',
                    actionLabel: 'GENERATE VOUCHER',
                    actionColor: const Color(0xFFF59E0B),
                    isLoading: false,
                    isHighlighted: false,
                    onAction: _showGenerateVoucherDialog,
                  ),
                  _buildActionCard(
                    icon: Icons.fast_forward_rounded,
                    iconBgColor: const Color(0xFFF3F0FF),
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Carry Forward to New Year',
                    description:
                        'End of Year step: Take all Closing Balances from current FY (Accounts + Stock) and insert them as Opening Balances in the next Financial Year.',
                    actionLabel: 'INITIATE CARRY FORWARD',
                    actionColor: const Color(0xFF7C3AED),
                    isLoading: false,
                    isHighlighted: true,
                    onAction: _showCarryForwardDialog,
                  ),
                ]),
              ),
            ),

            // REPORTING
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                child: _sectionHeader('REPORTING'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildListDelegate([
                  _buildActionCard(
                    icon: Icons.table_chart_rounded,
                    iconBgColor: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                    title: 'Trial Balance',
                    description:
                        'The ultimate checksum. Group-wise Trial Balance confirming Arithmetic accuracy of your books for the current FY.',
                    actionLabel: 'VIEW TRIAL BALANCE',
                    actionColor: const Color(0xFF2563EB),
                    isLoading: false,
                    isHighlighted: false,
                    onAction: _showTrialBalanceFyPicker,
                  ),
                  _buildActionCard(
                    icon: Icons.receipt_long_rounded,
                    iconBgColor: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF059669),
                    title: 'Account Ledger Statement',
                    description:
                        'Running balance statement reflecting every micro-transaction applied to an account (Gateway Explorer).',
                    actionLabel: 'VIEW LEDGER',
                    actionColor: const Color(0xFF059669),
                    isLoading: false,
                    isHighlighted: false,
                    onAction: () => _comingSoon('Account Ledger Statement'),
                  ),
                ]),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Coming Soon'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Top Banner ─────────────────────────────────────────────────────────────

  Widget _buildTopBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -10,
              child: Transform.rotate(
                angle: -math.pi / 10,
                child: Icon(
                  Icons.account_balance_rounded,
                  size: 140,
                  color: const Color(0xFF9333EA).withOpacity(0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFE2E8F0), width: 1.5),
                          ),
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.only(right: 2),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Color(0xFF1E293B),
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9333EA).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF9333EA).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded,
                                size: 13, color: Color(0xFF9333EA)),
                            const SizedBox(width: 5),
                            Text(
                              widget.fyLabel.isNotEmpty
                                  ? widget.fyLabel
                                  : 'Current FY',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9333EA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Opening Balance Operations',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Manage opening balances, carry forward year-end closing stocks, and generate system OB vouchers.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.5,
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

  Widget _sectionHeader(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF64748B),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String description,
    required String actionLabel,
    required Color actionColor,
    required bool isLoading,
    required bool isHighlighted,
    required VoidCallback onAction,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isLoading ? null : onAction,
        borderRadius: BorderRadius.circular(16),
        splashColor: actionColor.withOpacity(0.08),
        highlightColor: actionColor.withOpacity(0.04),
        child: Ink(
          decoration: BoxDecoration(
            color: isHighlighted ? const Color(0xFFF5F3FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted
                  ? const Color(0xFF7C3AED).withOpacity(0.3)
                  : const Color(0xFFE2E8F0),
              width: isHighlighted ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHighlighted
                    ? const Color(0xFF7C3AED).withOpacity(0.06)
                    : Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                // Action link label
                isLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: actionColor),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              actionLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: actionColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded,
                                size: 12, color: actionColor),
                          ],
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Generate Voucher Dialog ────────────────────────────────────────────────────

enum _VoucherDialogState { fyPicker, confirm, loading, result }

class _GenerateVoucherDialog extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String fyLabel;

  const _GenerateVoucherDialog({
    required this.storeId,
    required this.financialYearId,
    required this.fyLabel,
  });

  @override
  State<_GenerateVoucherDialog> createState() => _GenerateVoucherDialogState();
}

class _GenerateVoucherDialogState extends State<_GenerateVoucherDialog> {
  _VoucherDialogState _phase = _VoucherDialogState.fyPicker;

  // ── FY picker state
  bool _fyLoading = false;
  List<Map<String, dynamic>> _financialYears = [];
  String? _fyError;
  Map<String, dynamic>? _selectedFy;
  bool _dropdownOpen = false;

  // ── After FY selected, use these for the API call
  String get _selectedFyId =>
      _selectedFy?['id']?.toString() ?? widget.financialYearId;
  String get _selectedFyLabel =>
      _selectedFy?['label']?.toString() ?? widget.fyLabel;

  // Result fields
  bool _isSuccess = false;
  String _voucherNumber = '';
  String _warningMessage = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchFYs();
  }

  Future<void> _fetchFYs() async {
    setState(() {
      _fyLoading = true;
      _fyError = null;
    });
    try {
      final response = await ApiService.post(
        '/financial-years/',
        body: {'store_id': widget.storeId},
        useBearerToken: true,
      );
      if (!mounted) return;
      final data = response['data'];
      final int status = data?['status'] ?? 0;
      if (status == 200 && data?['response'] is List) {
        setState(() {
          _financialYears =
              List<Map<String, dynamic>>.from(data['response'] as List);
          _fyLoading = false;
        });
      } else {
        setState(() {
          _fyError = 'Failed to load financial years.';
          _fyLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fyError = 'Network error. Please try again.';
        _fyLoading = false;
      });
    }
  }

  Future<void> _processVoucher() async {
    setState(() => _phase = _VoucherDialogState.loading);

    try {
      final response = await ApiService.post(
        '/generate-opening-voucher/',
        body: {
          'store_id': widget.storeId,
          'financial_year_id': _selectedFyId,
        },
        useBearerToken: true,
      );

      if (!mounted) return;

      final data = response['data'];
      final int status = data?['status'] ?? 0;
      final dynamic responseBody = data?['response'];

      if (status == 200 || status == 201) {
        _isSuccess = true;
        if (responseBody is Map) {
          _voucherNumber =
              responseBody['voucher_number']?.toString() ?? '';
          _warningMessage =
              responseBody['warning']?.toString() ?? '';
        } else {
          _voucherNumber = '';
          _warningMessage = '';
        }
      } else {
        _isSuccess = false;
        if (responseBody is String) {
          _errorMessage = responseBody;
        } else if (responseBody is Map) {
          _errorMessage = responseBody['message']?.toString() ??
              responseBody['detail']?.toString() ??
              'An error occurred. Please try again.';
        } else {
          _errorMessage = 'An error occurred. Please try again.';
        }
      }
    } catch (e) {
      if (!mounted) return;
      _isSuccess = false;
      _errorMessage = 'Network error. Please check your connection.';
    }

    if (mounted) setState(() => _phase = _VoucherDialogState.result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _VoucherDialogState.fyPicker:
        return _buildFyPickerPhase();
      case _VoucherDialogState.confirm:
        return _buildConfirmPhase();
      case _VoucherDialogState.loading:
        return _buildLoadingPhase();
      case _VoucherDialogState.result:
        return _buildResultPhase();
    }
  }

  // ── Phase 0: FY Picker ──────────────────────────────────────────────────────

  Widget _buildFyPickerPhase() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Opening Voucher',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select the Financial Year for which you want to generate the OB voucher.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Dropdown
          _buildFyDropdown(),
          const SizedBox(height: 24),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _selectedFy != null
                    ? () => setState(
                        () => _phase = _VoucherDialogState.confirm)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text(
                  'NEXT',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFyDropdown() {
    if (_fyLoading) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFFF59E0B)),
          ),
        ),
      );
    }
    if (_fyError != null) {
      return GestureDetector(
        onTap: _fetchFYs,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(
                color: const Color(0xFFDC2626).withOpacity(0.4)),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFFEF2F2),
          ),
          child: Center(
            child: Text(
              '$_fyError  Tap to retry.',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ),
        ),
      );
    }
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedFy,
      isExpanded: true,
      hint: const Text(
        'Select Financial Year',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF64748B)),
      decoration: InputDecoration(
        labelText: _dropdownOpen ? 'Financial Year' : null,
        labelStyle: const TextStyle(
          color: Color(0xFFF59E0B),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
        ),
      ),
      onTap: () => setState(() => _dropdownOpen = true),
      onChanged: (val) => setState(() {
        _selectedFy = val;
        _dropdownOpen = false;
      }),
      items: _financialYears.map((fy) {
        final label = fy['label']?.toString() ?? '';
        final isActive = fy['is_active'] == true;
        final isLocked = fy['is_locked'] == true;
        return DropdownMenuItem<Map<String, dynamic>>(
          value: fy,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isActive)
                _fyBadge('Active', const Color(0xFF16A34A),
                    const Color(0xFFF0FDF4)),
              if (isLocked)
                _fyBadge('Locked', const Color(0xFFDC2626),
                    const Color(0xFFFEF2F2)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _fyBadge(String label, Color textColor, Color bg) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }

  // ── Phase 1: Confirm ────────────────────────────────────────────────────────

  Widget _buildConfirmPhase() {
    final fyDisplay =
        _selectedFyLabel.isNotEmpty ? _selectedFyLabel : 'the selected FY';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Opening Voucher',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.6,
              ),
              children: [
                const TextSpan(
                    text:
                        'This will process all master Opening Balance records for '),
                TextSpan(
                  text: 'FY $fyDisplay',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const TextSpan(
                    text:
                        ' and update any existing Opening Balance voucher. Inventory combinations will automatically ingest opening batches.'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _processVoucher,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text(
                  'PROCESS VOUCHER',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Phase 2: Loading ────────────────────────────────────────────────────────

  Widget _buildLoadingPhase() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Opening Voucher',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 32),
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(
                  color: Color(0xFF2563EB),
                  strokeWidth: 2.5,
                ),
                SizedBox(height: 16),
                Text(
                  'Processing voucher…',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Phase 3: Result ─────────────────────────────────────────────────────────

  Widget _buildResultPhase() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Opening Voucher',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),

          // Result card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: _isSuccess
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                // Icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isSuccess
                        ? Icons.check_rounded
                        : Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                Text(
                  _isSuccess ? 'Voucher Generated!' : 'Generation Failed',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _isSuccess
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 6),

                if (_isSuccess) ...[
                  // Voucher number (may be empty)
                  Text(
                    _voucherNumber.isNotEmpty
                        ? 'Voucher #: $_voucherNumber'
                        : 'Voucher #:',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                  // Warning message (OB imbalance etc.)
                  if (_warningMessage.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Warning: $_warningMessage',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ] else ...[
                  // Error message
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Carry Forward Dialog ───────────────────────────────────────────────────────

enum _CFPhase { select, loading, result }

class _CarryForwardDialog extends StatefulWidget {
  final String storeId;
  final String fromFinancialYearId;
  const _CarryForwardDialog({
    required this.storeId,
    required this.fromFinancialYearId,
  });

  @override
  State<_CarryForwardDialog> createState() => _CarryForwardDialogState();
}

class _CarryForwardDialogState extends State<_CarryForwardDialog> {
  // FY list state
  bool _fyLoading = false;
  List<Map<String, dynamic>> _financialYears = [];
  String? _fyError;

  // From FY (source)
  Map<String, dynamic>? _fromFy;
  bool _fromDropdownOpen = false;

  // To FY (target)
  Map<String, dynamic>? _selectedFy;
  bool _dropdownOpen = false;

  // Overall dialog phase
  _CFPhase _phase = _CFPhase.select;

  // Structured result data
  bool _resultSuccess = false;
  String _resultErrorMessage = '';
  int _accountsCarried = 0;
  int _inventoryCarried = 0;
  String _netProfit = '0.00';
  bool _isProfit = true;
  bool _obVoucherGenerated = false;
  String _obVoucherError = '';

  bool get _canTransfer => _fromFy != null && _selectedFy != null;

  @override
  void initState() {
    super.initState();
    _fetchFYs();
  }

  Future<void> _fetchFYs() async {
    setState(() {
      _fyLoading = true;
      _fyError = null;
    });
    try {
      final response = await ApiService.post(
        '/financial-years/',
        body: {'store_id': widget.storeId},
        useBearerToken: true,
      );
      if (!mounted) return;
      final data = response['data'];
      final int status = data?['status'] ?? 0;
      if (status == 200 && data?['response'] is List) {
        setState(() {
          _financialYears =
              List<Map<String, dynamic>>.from(data['response'] as List);
          _fyLoading = false;
        });
      } else {
        setState(() {
          _fyError = 'Failed to load financial years.';
          _fyLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fyError = 'Network error. Please try again.';
        _fyLoading = false;
      });
    }
  }

  Future<void> _initiateTransfer() async {
    if (!_canTransfer) return;
    setState(() => _phase = _CFPhase.loading);
    try {
      final response = await ApiService.post(
        '/carry-forward-balances/',
        body: {
          'store_id': widget.storeId,
          'from_financial_year_id': _fromFy!['id']?.toString() ?? '',
          'to_financial_year_id': _selectedFy!['id']?.toString() ?? '',
          'auto_generate_ob_voucher': true,
        },
        useBearerToken: true,
      );
      if (!mounted) return;
      final data = response['data'];
      final int status = data?['status'] ?? 0;
      if ((status == 200 || status == 201) && data?['response'] is Map) {
        final r = data['response'] as Map<String, dynamic>;
        setState(() {
          _phase = _CFPhase.result;
          _resultSuccess = true;
          _accountsCarried = (r['balance_sheet_accounts_carried'] as num?)?.toInt() ?? 0;
          _inventoryCarried = (r['inventory_items_carried'] as num?)?.toInt() ?? 0;
          _netProfit = r['net_profit']?.toString() ?? '0.00';
          _isProfit = r['is_profit'] == true;
          _obVoucherGenerated = r['ob_voucher_generated'] == true;
          _obVoucherError = r['ob_voucher_error']?.toString() ?? '';
        });
      } else {
        final dynamic errBody = data?['response'];
        setState(() {
          _phase = _CFPhase.result;
          _resultSuccess = false;
          _resultErrorMessage = errBody is String
              ? errBody
              : 'An error occurred. Please try again.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _CFPhase.result;
        _resultSuccess = false;
        _resultErrorMessage = 'Network error. Please check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _CFPhase.select:
        return _buildSelectPhase();
      case _CFPhase.loading:
        return _buildLoadingPhase();
      case _CFPhase.result:
        return _buildResultPhase();
    }
  }

  // ── Phase 1: Select FYs ─────────────────────────────────────────────────────

  Widget _buildSelectPhase() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Year-End Carry Forward',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose the source and destination Financial Years for the balance migration.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // FROM label + dropdown
          _buildFyLabel('From Financial Year (Source)'),
          const SizedBox(height: 6),
          _buildSingleDropdown(
            value: _fromFy,
            hint: 'Select Source FY',
            isOpen: _fromDropdownOpen,
            onTap: () => setState(() => _fromDropdownOpen = true),
            onChanged: (val) => setState(() {
              _fromFy = val;
              _fromDropdownOpen = false;
            }),
          ),

          const SizedBox(height: 10),
          // Arrow connector
          Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_downward_rounded,
                size: 16,
                color: Color(0xFF7C3AED),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // TO label + dropdown
          _buildFyLabel('To Financial Year (Target)'),
          const SizedBox(height: 6),
          _buildSingleDropdown(
            value: _selectedFy,
            hint: 'Select Target FY',
            isOpen: _dropdownOpen,
            onTap: () => setState(() => _dropdownOpen = true),
            onChanged: (val) => setState(() {
              _selectedFy = val;
              _dropdownOpen = false;
            }),
          ),

          const SizedBox(height: 16),

          // Warning banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFF59E0B), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'This is a massive read-write operation spanning Accounts and Inventory. Do not close this window while operating.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFB45309),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _canTransfer ? _initiateTransfer : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text(
                  'INITIATE TRANSFER',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFyLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
          letterSpacing: 0.3,
        ),
      );

  // Reusable dropdown used for both FROM and TO FY pickers
  Widget _buildSingleDropdown({
    required Map<String, dynamic>? value,
    required String hint,
    required bool isOpen,
    required VoidCallback onTap,
    required ValueChanged<Map<String, dynamic>?> onChanged,
  }) {
    if (_fyLoading) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF2563EB)),
          ),
        ),
      );
    }
    if (_fyError != null) {
      return GestureDetector(
        onTap: _fetchFYs,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(
                color: const Color(0xFFDC2626).withOpacity(0.4)),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFFEF2F2),
          ),
          child: Center(
            child: Text(
              '$_fyError  Tap to retry.',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ),
        ),
      );
    }
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: value,
      isExpanded: true,
      hint: Text(
        hint,
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF64748B)),
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
      ),
      onTap: onTap,
      onChanged: onChanged,
      items: _financialYears.map((fy) {
        final label = fy['label']?.toString() ?? '';
        final isActive = fy['is_active'] == true;
        final isLocked = fy['is_locked'] == true;
        return DropdownMenuItem<Map<String, dynamic>>(
          value: fy,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isActive)
                _fyChip('Active', const Color(0xFF16A34A),
                    const Color(0xFFF0FDF4)),
              if (isLocked)
                _fyChip('Locked', const Color(0xFFDC2626),
                    const Color(0xFFFEF2F2)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _fyChip(String label, Color textColor, Color bg) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }

  // ── Phase 2: Loading ────────────────────────────────────────────────────────

  Widget _buildLoadingPhase() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Year-End Carry Forward',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 36),
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(
                    color: Color(0xFF7C3AED), strokeWidth: 2.5),
                SizedBox(height: 16),
                Text(
                  'Transferring balances…\nDo not close this window.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  // ── Phase 3: Result ─────────────────────────────────────────────────────────

  Widget _buildResultPhase() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Year-End Carry Forward',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: _resultSuccess
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _resultSuccess
                ? _buildSuccessContent()
                : _buildErrorContent(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      children: [
        // Tick icon
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFF16A34A),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 14),
        const Text(
          'Carry Forward Complete!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF16A34A),
          ),
        ),
        const SizedBox(height: 16),
        // Stats
        _statRow('Accounts migrated:', _accountsCarried.toString()),
        const SizedBox(height: 6),
        _statRow('Inventory Items migrated:', _inventoryCarried.toString()),
        const SizedBox(height: 6),
        _statRow(
          'Net Profit rolled:',
          '$_netProfit (${_isProfit ? 'Profit' : 'Loss'})',
        ),
        // OB Voucher info
        if (_obVoucherGenerated) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'OB Voucher auto-generated successfully.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF166534),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        // OB Voucher error/warning
        if (_obVoucherError.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFDC2626).withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.warning_amber_rounded,
                      size: 14, color: Color(0xFFDC2626)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _obVoucherError,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFDC2626),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorContent() {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFFDC2626),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 14),
        const Text(
          'Transfer Failed',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFFDC2626),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _resultErrorMessage,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF166534),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF166534),
          ),
        ),
      ],
    );
  }
}

// ── Trial Balance FY Picker Dialog ────────────────────────────────────────────

class _TrialBalanceFyPickerDialog extends StatefulWidget {
  final String storeId;

  const _TrialBalanceFyPickerDialog({required this.storeId});

  @override
  State<_TrialBalanceFyPickerDialog> createState() =>
      _TrialBalanceFyPickerDialogState();
}

class _TrialBalanceFyPickerDialogState
    extends State<_TrialBalanceFyPickerDialog> {
  bool _fyLoading = false;
  List<Map<String, dynamic>> _financialYears = [];
  String? _fyError;
  Map<String, dynamic>? _selectedFy;

  @override
  void initState() {
    super.initState();
    _fetchFYs();
  }

  Future<void> _fetchFYs() async {
    setState(() {
      _fyLoading = true;
      _fyError = null;
    });
    try {
      final response = await ApiService.post(
        '/financial-years/',
        body: {'store_id': widget.storeId},
        useBearerToken: true,
      );
      if (!mounted) return;
      final data = response['data'];
      final int status = data?['status'] ?? 0;
      if (status == 200 && data?['response'] is List) {
        setState(() {
          _financialYears =
              List<Map<String, dynamic>>.from(data['response'] as List);
          _fyLoading = false;
        });
      } else {
        setState(() {
          _fyError = 'Failed to load financial years.';
          _fyLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fyError = 'Network error. Please try again.';
        _fyLoading = false;
      });
    }
  }

  void _openTrialBalance() {
    if (_selectedFy == null) return;
    final fyId = _selectedFy!['id']?.toString() ?? '';
    final fyLabel = _selectedFy!['label']?.toString() ?? '';
    Navigator.of(context).pop(); // close dialog
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OBTrialBalanceScreen(
          storeId: widget.storeId,
          financialYearId: fyId,
          fyLabel: fyLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + title row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.table_chart_rounded,
                      color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Trial Balance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select the Financial Year to view the Trial Balance for.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // Dropdown
            _buildDropdown(),

            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _selectedFy != null ? _openTrialBalance : null,
                  icon: const Icon(Icons.table_chart_rounded, size: 16),
                  label: const Text(
                    'VIEW',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    if (_fyLoading) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF2563EB)),
          ),
        ),
      );
    }

    if (_fyError != null) {
      return GestureDetector(
        onTap: _fetchFYs,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(
                color: const Color(0xFFDC2626).withOpacity(0.4)),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFFEF2F2),
          ),
          child: Center(
            child: Text(
              '$_fyError  Tap to retry.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ),
        ),
      );
    }

    return DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedFy,
      isExpanded: true,
      hint: const Text(
        'Select Financial Year',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF64748B)),
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
      onChanged: (val) => setState(() => _selectedFy = val),
      items: _financialYears.map((fy) {
        final label = fy['label']?.toString() ?? '';
        final isActive = fy['is_active'] == true;
        final isLocked = fy['is_locked'] == true;
        final isCurrent = fy['is_current'] == true;
        return DropdownMenuItem<Map<String, dynamic>>(
          value: fy,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isCurrent)
                _badge('Current', const Color(0xFF2563EB),
                    const Color(0xFFEFF6FF)),
              if (isActive)
                _badge('Active', const Color(0xFF16A34A),
                    const Color(0xFFF0FDF4)),
              if (isLocked)
                _badge('Locked', const Color(0xFFDC2626),
                    const Color(0xFFFEF2F2)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _badge(String label, Color textColor, Color bg) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: textColor),
      ),
    );
  }
}
