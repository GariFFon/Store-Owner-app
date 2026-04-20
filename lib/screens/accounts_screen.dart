import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/screens/account_ledger_screen.dart';

class AccountsScreen extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String fyLabel;

  const AccountsScreen({
    super.key,
    required this.storeId,
    required this.financialYearId,
    required this.fyLabel,
  });

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _groups = [];

  static const _accent = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Fire both in parallel
      final results = await Future.wait([
        ApiService.post(
          '/accounts/',
          body: {'action': 'list', 'store_id': widget.storeId},
          useBearerToken: true,
        ),
        ApiService.post(
          '/account-groups/',
          body: {'action': 'list', 'store_id': widget.storeId},
          useBearerToken: true,
        ),
      ]);
      if (mounted) {
        final accData = results[0]['data'];
        final grpData = results[1]['data'];
        if (accData != null && accData['status'] == 200) {
          setState(() {
            _accounts =
                List<Map<String, dynamic>>.from(accData['response'] ?? []);
            _groups = grpData != null && grpData['status'] == 200
                ? List<Map<String, dynamic>>.from(grpData['response'] ?? [])
                : [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = accData?['message'] ?? 'Failed to load accounts';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ── Type label & color ────────────────────────────────────────────────────
  String _typeLabel(Map<String, dynamic> acc) {
    if (acc['is_bank'] == true) return 'BANK';
    if (acc['is_cash'] == true) return 'CASH';
    if (acc['is_control'] == true) return 'CONTROL';
    return 'GENERAL';
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'BANK':
        return const Color(0xFF2563EB);
      case 'CASH':
        return const Color(0xFF059669);
      case 'CONTROL':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _typeBg(String type) {
    switch (type) {
      case 'BANK':
        return const Color(0xFFEFF6FF);
      case 'CASH':
        return const Color(0xFFF0FDF4);
      case 'CONTROL':
        return const Color(0xFFF5F3FF);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _accent),
                    )
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _fetch,
                          color: _accent,
                          child: _buildList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
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
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF64748B), size: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chart of Accounts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (widget.fyLabel.isNotEmpty)
                      Text(
                        widget.fyLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              InkWell(
                onTap: _fetch,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Icon(Icons.refresh_rounded,
                        color: Color(0xFF64748B), size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // ── New Account button ──────────────────────────────────────
              GestureDetector(
                onTap: () => _showCreateAccountDialog(context),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 5),
                      Text(
                        'New Account',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFDC2626), size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Failed to load Accounts',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Account list ──────────────────────────────────────────────────────────
  Widget _buildList() {
    final items = _accounts;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: _accent, size: 28),
            ),
            const SizedBox(height: 12),
            const Text('No accounts found',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Table header
        Container(
          color: const Color(0xFFF8FAFC),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              const Expanded(
                flex: 6,
                child: Text('Account Name',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.2)),
              ),
              const Expanded(
                flex: 3,
                child: Text('Group',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.2)),
              ),
              const Expanded(
                flex: 2,
                child: Text('Nature',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.2)),
              ),
              const SizedBox(
                width: 72,
                child: Text('Type',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.2)),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Expanded(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
            itemBuilder: (context, index) => _buildRow(items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(Map<String, dynamic> acc) {
    final name      = acc['name']?.toString() ?? '';
    final groupName = acc['group_name']?.toString() ?? '';
    final nature    = acc['nature']?.toString() ?? '';
    final accountId = acc['id']?.toString() ?? '';
    final type      = _typeLabel(acc);

    return InkWell(
      onTap: accountId.isNotEmpty
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AccountLedgerScreen(
                    storeId: widget.storeId,
                    financialYearId: widget.financialYearId,
                    accountId: accountId,
                    accountName: name,
                  ),
                ),
              )
          : null,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Icon + Name
            Expanded(
              flex: 6,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: _accent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Group
            Expanded(
              flex: 3,
              child: Text(
                groupName,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Nature
            Expanded(
              flex: 2,
              child: nature.isNotEmpty
                  ? Text(
                      nature,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
            ),
            // Type badge
            SizedBox(
              width: 72,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _typeBg(type),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: _typeColor(type),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Create Account Dialog ─────────────────────────────────────────────────
  void _showCreateAccountDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String? selectedGroupId;
    // 'normal' | 'bank' | 'cash'
    String selectedType = 'normal';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        bool isCreating = false;
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Name field
                      TextField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Name',
                          hintStyle: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w400,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: _accent, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Group dropdown
                      DropdownButtonFormField<String>(
                        value: selectedGroupId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Group',
                          labelStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: _accent, width: 1.5),
                          ),
                        ),
                        hint: const Text('Select a group',
                            style: TextStyle(
                                fontSize: 14, color: Color(0xFF94A3B8))),
                        items: _groups
                            .map((g) => DropdownMenuItem<String>(
                                  value: g['id']?.toString() ?? '',
                                  child: Text(
                                    g['name']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: isCreating
                            ? null
                            : (v) => setDlgState(() => selectedGroupId = v),
                      ),
                      const SizedBox(height: 18),

                      // Account Type dropdown
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: InputDecoration(
                          labelText: 'Account Type',
                          labelStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: _accent, width: 1.5),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'normal',
                            child: Text('Normal',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B))),
                          ),
                          DropdownMenuItem(
                            value: 'bank',
                            child: Text('Bank',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B))),
                          ),
                          DropdownMenuItem(
                            value: 'cash',
                            child: Text('Cash',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B))),
                          ),
                        ],
                        onChanged: isCreating
                            ? null
                            : (v) =>
                                setDlgState(() => selectedType = v ?? 'normal'),
                      ),
                      const SizedBox(height: 28),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isCreating
                                ? null
                                : () => Navigator.of(ctx).pop(),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: isCreating
                                  ? null
                                  : () async {
                                      final name = nameCtrl.text.trim();
                                      if (name.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text(
                                              'Please enter an account name'),
                                          duration: Duration(seconds: 2),
                                        ));
                                        return;
                                      }
                                      if (selectedGroupId == null ||
                                          selectedGroupId!.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content:
                                              Text('Please select a group'),
                                          duration: Duration(seconds: 2),
                                        ));
                                        return;
                                      }
                                      setDlgState(() => isCreating = true);
                                      try {
                                        final response = await ApiService.post(
                                          '/accounts/',
                                          body: {
                                            'action': 'create',
                                            'store_id': widget.storeId,
                                            'name': name,
                                            'group_id': selectedGroupId,
                                            'is_bank': selectedType == 'bank',
                                            'is_cash': selectedType == 'cash',
                                            'is_control': false,
                                          },
                                          useBearerToken: true,
                                        );
                                        final data = response['data'];
                                        if (data != null &&
                                            data['status'] == 200) {
                                          if (ctx.mounted)
                                            Navigator.of(ctx).pop();
                                          _fetch();
                                        } else {
                                          setDlgState(
                                              () => isCreating = false);
                                          if (context.mounted)
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: Text(
                                                  data?['message'] ??
                                                      'Failed to create account'),
                                              duration:
                                                  const Duration(seconds: 3),
                                            ));
                                        }
                                      } catch (e) {
                                        setDlgState(() => isCreating = false);
                                        if (context.mounted)
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text(e.toString()),
                                            duration:
                                                const Duration(seconds: 3),
                                          ));
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 28),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: isCreating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Create',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

