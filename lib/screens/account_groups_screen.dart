import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/screens/account_ledger_screen.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Account Groups List Screen
// ─────────────────────────────────────────────────────────────────────────────

class AccountGroupsScreen extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String fyLabel;

  const AccountGroupsScreen({
    super.key,
    required this.storeId,
    required this.financialYearId,
    required this.fyLabel,
  });

  @override
  State<AccountGroupsScreen> createState() => _AccountGroupsScreenState();
}

class _AccountGroupsScreenState extends State<AccountGroupsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _groups = [];
  String _search = '';

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
      final response = await ApiService.post(
        '/account-groups/',
        body: {
          'action': 'list',
          'store_id': widget.storeId,
        },
        useBearerToken: true,
      );
      if (mounted) {
        final data = response['data'];
        if (data != null && data['status'] == 200) {
          setState(() {
            _groups = List<Map<String, dynamic>>.from(data['response'] ?? []);
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data?['message'] ?? 'Failed to load Account Groups';
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

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _groups;
    final q = _search.toLowerCase();
    return _groups
        .where((g) =>
            (g['name'] ?? '').toString().toLowerCase().contains(q) ||
            (g['parent_name'] ?? '').toString().toLowerCase().contains(q) ||
            (g['nature_label'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  // ── Nature badge helpers ────────────────────────────────────────────────────
  Color _natureColor(String? nature) {
    switch ((nature ?? '').toUpperCase()) {
      case 'ASSET':
        return const Color(0xFF2563EB);
      case 'LIABILITY':
        return const Color(0xFFDC2626);
      case 'INCOME':
        return const Color(0xFF059669);
      case 'EXPENSE':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  Color _natureBg(String? nature) {
    switch ((nature ?? '').toUpperCase()) {
      case 'ASSET':
        return const Color(0xFFEFF6FF);
      case 'LIABILITY':
        return const Color(0xFFFEF2F2);
      case 'INCOME':
        return const Color(0xFFF0FDF4);
      case 'EXPENSE':
        return const Color(0xFFFFF7ED);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

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
                      'Account Groups',
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
              // ── New Group button ──────────────────────────────────────────
              GestureDetector(
                onTap: () => _showCreateGroupDialog(context),
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
                        'New Group',
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

  // ── Create Group Dialog ───────────────────────────────────────────────────────

  void _showCreateGroupDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String selectedNature = 'ASSET';
    const natures = ['ASSET', 'LIABILITY', 'INCOME', 'EXPENSE', 'EQUITY'];

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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Text(
                      'Create Account Group',
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
                        labelText: 'Name',
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
                    ),
                    const SizedBox(height: 18),

                    // Nature dropdown
                    DropdownButtonFormField<String>(
                      value: selectedNature,
                      decoration: InputDecoration(
                        labelText: 'Nature',
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
                      items: natures
                          .map((n) => DropdownMenuItem(
                                value: n,
                                child: Text(
                                  n,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: isCreating
                          ? null
                          : (v) {
                              if (v != null)
                                setDlgState(() => selectedNature = v);
                            },
                    ),
                    const SizedBox(height: 28),

                    // Actions row
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
                                        content:
                                            Text('Please enter a group name'),
                                        duration: Duration(seconds: 2),
                                      ));
                                      return;
                                    }
                                    setDlgState(() => isCreating = true);
                                    try {
                                      final response = await ApiService.post(
                                        '/account-groups/',
                                        body: {
                                          'action': 'create',
                                          'store_id': widget.storeId,
                                          'name': name,
                                          'nature': selectedNature,
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
                                                  'Failed to create group',
                                            ),
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
            );
          },
        );
      },
    );
  }


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
            const Text(
              'Failed to load Account Groups',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF64748B)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
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
              child: const Icon(Icons.group_work_rounded,
                  color: _accent, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              _search.isEmpty
                  ? 'No account groups found'
                  : 'No results for "$_search"',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Table header
        Container(
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              const Expanded(
                flex: 5,
                child: Text('Group Name',
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
              const Expanded(
                flex: 3,
                child: Text('Parent Group',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.2)),
              ),
              const SizedBox(
                width: 60,
                child: Text('Accounts',
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

  Widget _buildRow(Map<String, dynamic> group) {
    final name         = group['name']?.toString() ?? '';
    final nature       = group['nature']?.toString() ?? '';
    final natureLabel  = group['nature_label']?.toString() ?? '';
    final parentName   = group['parent_name']?.toString() ?? '';
    final accountCount = group['accounts_count'] as int? ?? 0;
    final groupId      = group['id']?.toString() ?? '';

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AccountGroupDetailScreen(
              storeId: widget.storeId,
              financialYearId: widget.financialYearId,
              groupId: groupId,
              groupName: name,
            ),
          ),
        );
      },
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon + name
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.group_work_rounded,
                        color: _accent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Nature badge
            Expanded(
              flex: 2,
              child: natureLabel.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _natureBg(nature),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        natureLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _natureColor(nature),
                        ),
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
            // Parent group
            Expanded(
              flex: 3,
              child: Text(
                parentName.isNotEmpty ? parentName : '–',
                style: TextStyle(
                  fontSize: 13,
                  color: parentName.isNotEmpty
                      ? const Color(0xFF475569)
                      : const Color(0xFFCBD5E1),
                ),
              ),
            ),
            // Account count
            SizedBox(
              width: 60,
              child: Text(
                '$accountCount',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: accountCount > 0
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account Group Detail Screen
// ─────────────────────────────────────────────────────────────────────────────

class AccountGroupDetailScreen extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String groupId;
  final String groupName;

  const AccountGroupDetailScreen({
    super.key,
    required this.storeId,
    required this.financialYearId,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<AccountGroupDetailScreen> createState() =>
      _AccountGroupDetailScreenState();
}

class _AccountGroupDetailScreenState extends State<AccountGroupDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

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
      final response = await ApiService.post(
        '/account-group-detail/',
        body: {
          'action': 'detail',
          'store_id': widget.storeId,
          'financial_year_id': widget.financialYearId,
          'group_id': widget.groupId,
        },
        useBearerToken: true,
      );
      if (mounted) {
        final data = response['data'];
        if (data != null && data['status'] == 200) {
          setState(() {
            _data = data['response'] as Map<String, dynamic>?;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data?['message'] ?? 'Failed to load group detail';
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

  String _fmt(String? raw) {
    if (raw == null) return '0.00';
    try {
      final val = double.parse(raw);
      final f = NumberFormat('#,##,##0.00', 'en_IN');
      return val < 0 ? '−${f.format(val.abs())}' : f.format(val);
    } catch (_) {
      return raw;
    }
  }

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
                          child: _buildContent(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

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
                child: Text(
                  widget.groupName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
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
            ],
          ),
        ),
      ),
    );
  }

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
            const Text('Failed to load group details',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF64748B)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_data == null) return const SizedBox.shrink();

    final name          = _data!['name']?.toString() ?? widget.groupName;
    final nature        = _data!['nature']?.toString() ?? '';
    final parentName    = _data!['parent_name']?.toString() ?? '';
    final subGroups     = _data!['sub_groups'] as List<dynamic>? ?? [];
    final accounts      = _data!['accounts'] as List<dynamic>? ?? [];
    final closingBal    = _data!['group_closing_balance']?.toString() ?? '0.00';
    final closingType   = _data!['group_closing_balance_type']?.toString() ?? 'DR';

    final isCr = closingType.toUpperCase() == 'CR';
    final balColor = isCr ? const Color(0xFFDC2626) : const Color(0xFF059669);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Group header ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (nature.isNotEmpty) 'Nature: $nature',
                          if (parentName.isNotEmpty) 'Parent: $parentName',
                        ].join('  |  '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'CLOSING BALANCE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_fmt(closingBal)} $closingType',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: balColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Sub Groups ──────────────────────────────────────────────────────
        if (subGroups.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'SUB GROUPS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[500],
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: subGroups.asMap().entries.map((e) {
                  final isLast = e.key == subGroups.length - 1;
                  final sg = e.value as Map<String, dynamic>;
                  return _subGroupRow(sg, isLast: isLast);
                }).toList(),
              ),
            ),
          ),
        ],

        // ── Direct Accounts ─────────────────────────────────────────────────
        if (accounts.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'DIRECT ACCOUNTS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[500],
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          // Table header
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: Row(
                      children: [
                        _hCell('ACCOUNT', flex: 4),
                        _hCell('OPENING', flex: 2),
                        _hCell('MOVEMENT', flex: 3),
                        _hCell('CLOSING', flex: 2, align: TextAlign.right),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  // Account rows
                  ...accounts.asMap().entries.map((e) {
                    final isLast = e.key == accounts.length - 1;
                    return _accountRow(
                        e.value as Map<String, dynamic>,
                        isLast: isLast);
                  }),
                ],
              ),
            ),
          ),
        ],

        // ── Empty state ─────────────────────────────────────────────────────
        if (accounts.isEmpty && subGroups.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.group_work_rounded,
                          color: _accent, size: 26),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No accounts or sub-groups',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This group has no ledger accounts or child groups yet.',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF94A3B8)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  // ── Sub group row ─────────────────────────────────────────────────────────
  Widget _subGroupRow(Map<String, dynamic> sg, {bool isLast = false}) {
    final name  = sg['name']?.toString() ?? '';
    final count = sg['accounts_count'] as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.subdirectory_arrow_right_rounded,
                color: _accent, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count accounts',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Account row ───────────────────────────────────────────────────────────
  Widget _accountRow(Map<String, dynamic> acc, {bool isLast = false}) {
    final name      = acc['name']?.toString() ?? '';
    final accountId = acc['id']?.toString() ?? '';
    final opening   = acc['opening_balance']?.toString() ?? '0.00';
    final openType  = acc['opening_balance_type']?.toString() ?? 'DR';
    final debit     = acc['debit']?.toString() ?? acc['movement_debit']?.toString() ?? '0.00';
    final credit    = acc['credit']?.toString() ?? acc['movement_credit']?.toString() ?? '0.00';
    final closing   = acc['closing_balance']?.toString() ?? '0.00';
    final closeType = acc['closing_balance_type']?.toString() ?? 'DR';

    final closingIsCr = closeType.toUpperCase() == 'CR';
    final closingColor = closingIsCr ? const Color(0xFFDC2626) : const Color(0xFF059669);

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
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9))),
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(14))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account name
            Expanded(
              flex: 4,
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            // Opening
            Expanded(
              flex: 2,
              child: Text(
                '${_fmt(opening)} $openType',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Movement
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '+${_fmt(debit)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '-${_fmt(credit)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Closing
            Expanded(
              flex: 2,
              child: Text(
                '${_fmt(closing)} $closeType',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: closingColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Table header cell ─────────────────────────────────────────────────────
  Widget _hCell(String text,
      {int flex = 2, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
