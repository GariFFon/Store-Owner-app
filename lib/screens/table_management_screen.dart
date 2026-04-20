import 'package:exanor/services/api_service.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────────────────────
// Table Management Screen
// ─────────────────────────────────────────────────────────────────────────────
class TableManagementScreen extends StatefulWidget {
  final String storeId;
  final String? storeName;

  const TableManagementScreen({
    super.key,
    required this.storeId,
    this.storeName,
  });

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tables = [];

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchTables();
  }

  // ── API ─────────────────────────────────────────────────────────────────────
  Future<void> _fetchTables() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.post(
        '/store-table-operations/',
        body: {
          'store_id': widget.storeId,
          'store_access': true,
          'create': false,
        },
        useBearerToken: true,
      );
      final data = res['data'] as Map<String, dynamic>?;
      final status = data?['status'] as int?;
      if (status == 200) {
        final raw = data?['response'];
        setState(() {
          _tables = raw is List
              ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
              : [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = data?['response']?.toString() ?? 'Failed to load tables.';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _createTable({
    required String tableNumber,
    required int seats,
    required String section,
  }) async {
    try {
      final res = await ApiService.post(
        '/store-table-operations/',
        body: {
          'store_id': widget.storeId,
          'store_access': true,
          'create': true,
          'table_number': tableNumber,
          'additional_data': {'seats': seats, 'section': section},
        },
        useBearerToken: true,
      );
      final data = res['data'] as Map<String, dynamic>?;
      final status = data?['status'] as int?;
      if (status == 200) {
        _showSnack('Table created successfully', success: true);
        await _fetchTables();
      } else {
        _showSnack(data?['response']?.toString() ?? 'Failed to create table.');
      }
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _updateTable({
    required String tableId,
    required String tableNumber,
    required int seats,
    required String section,
    required bool isActive,
    required bool isReserved,
  }) async {
    try {
      final res = await ApiService.put(
        '/store-table-operations/',
        body: {
          'store_id': widget.storeId,
          'store_access': true,
          'table_id': tableId,
          'table_number': tableNumber,
          'additional_data': {'seats': seats, 'section': section},
          'is_active': isActive,
          'is_reserved': isReserved,
        },
        useBearerToken: true,
      );
      final data = res['data'] as Map<String, dynamic>?;
      final status = data?['status'] as int?;
      if (status == 200) {
        _showSnack('Table updated successfully', success: true);
        await _fetchTables();
      } else {
        _showSnack(data?['response']?.toString() ?? 'Failed to update table.');
      }
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
    ));
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────
  void _showCreateDialog() {
    final numCtrl = TextEditingController();
    final seatsCtrl = TextEditingController(text: '2');
    final sectionCtrl = TextEditingController(text: 'Main');
    bool saving = false;
    String? err;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Text(
            'Create New Table',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                const SizedBox(height: 12),
                _field(numCtrl, 'Table Number (e.g. T-01)'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(seatsCtrl, 'Seats Capacity', num: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(sectionCtrl, 'Dining Section')),
                ]),
                if (err != null) ...[
                  const SizedBox(height: 10),
                  _errorBanner(err!),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final num = numCtrl.text.trim();
                      if (num.isEmpty) {
                        setDlg(() => err = 'Table number is required.');
                        return;
                      }
                      final seats =
                          int.tryParse(seatsCtrl.text.trim()) ?? 2;
                      setDlg(() {
                        saving = true;
                        err = null;
                      });
                      Navigator.of(ctx).pop();
                      await _createTable(
                        tableNumber: num,
                        seats: seats,
                        section: sectionCtrl.text.trim().isEmpty
                            ? 'Main'
                            : sectionCtrl.text.trim(),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4FE8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                elevation: 0,
              ),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Table',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> table) {
    final additional = table['additional_data'] as Map? ?? {};
    final numCtrl = TextEditingController(
        text: table['table_number']?.toString() ?? '');
    final seatsCtrl = TextEditingController(
        text: (additional['seats'] ?? 2).toString());
    final sectionCtrl = TextEditingController(
        text: additional['section']?.toString() ?? 'Main');
    bool isActive = table['is_active'] == true;
    bool isReserved = table['is_reserved'] == true;
    bool saving = false;
    String? err;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Text(
            'Edit Table Settings',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                const SizedBox(height: 12),
                _field(numCtrl, 'Table Number (e.g. T-01)'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(seatsCtrl, 'Seats Capacity', num: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(sectionCtrl, 'Dining Section')),
                ]),
                const SizedBox(height: 16),
                // Status toggles
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STATUS CONTROLS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          Row(
                            children: [
                              Switch(
                                value: isActive,
                                activeColor: const Color(0xFF16A34A),
                                onChanged: (v) =>
                                    setDlg(() => isActive = v),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Active (In Service)',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Switch(
                                value: isReserved,
                                activeColor: const Color(0xFFD97706),
                                onChanged: (v) =>
                                    setDlg(() => isReserved = v),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Reserved',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (err != null) ...[
                  const SizedBox(height: 10),
                  _errorBanner(err!),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final num = numCtrl.text.trim();
                      if (num.isEmpty) {
                        setDlg(() => err = 'Table number is required.');
                        return;
                      }
                      final seats =
                          int.tryParse(seatsCtrl.text.trim()) ?? 2;
                      setDlg(() {
                        saving = true;
                        err = null;
                      });
                      Navigator.of(ctx).pop();
                      await _updateTable(
                        tableId: table['id'].toString(),
                        tableNumber: num,
                        seats: seats,
                        section: sectionCtrl.text.trim().isEmpty
                            ? 'Main'
                            : sectionCtrl.text.trim(),
                        isActive: isActive,
                        isReserved: isReserved,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4FE8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                elevation: 0,
              ),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Table',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Small UI helpers ─────────────────────────────────────────────────────────
  Widget _field(TextEditingController c, String label,
      {bool num = false}) =>
      TextField(
        controller: c,
        keyboardType: num ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: label,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFF5B4FE8), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
        ),
      );

  Widget _errorBanner(String msg) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFDC2626))),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Match the bg color
      body: Column(
        children: [
          _buildExpandedBanner(),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Expanded(child: _buildBody()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedBanner() {
    const lightBlueBg = Color(0xFFEFF6FF);
    const watermarkColor = Color(0xFFDBEAFE);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: lightBlueBg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.5),
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
              right: -30,
              top: -10,
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Icon(
                  Icons.table_restaurant_outlined,
                  size: 180,
                  color: watermarkColor.withOpacity(0.6),
                ),
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                MediaQuery.of(context).padding.top + 8,
                12,
                48, // generous bottom padding to allow for overlap
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.blueGrey.withOpacity(0.5),
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
                          'Table Management',
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
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.withOpacity(0.2)),
                          ),
                          child: Text(
                            "${_tables.length} TABLES",
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.blue,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add Button
                  SizedBox(
                    width: 70,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ADD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.blueGrey[400],
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: _showCreateDialog,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueGrey.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 24,
                              color: Colors.blueGrey[700],
                            ),
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
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 60, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchTables,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B4FE8),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.table_restaurant_outlined, size: 64, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            const Text('No tables yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            const Text('Tap the + icon above to create your first table.', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Table'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4FE8),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTables,
      color: const Color(0xFF5B4FE8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 2;
          if (constraints.maxWidth > 1200) {
            crossAxisCount = 5;
          } else if (constraints.maxWidth > 900) {
            crossAxisCount = 4;
          } else if (constraints.maxWidth > 600) {
            crossAxisCount = 3;
          } else if (constraints.maxWidth < 360) {
            crossAxisCount = 1;
          }
          
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 0.85,
            ),
            itemCount: _tables.length,
            itemBuilder: (_, i) => _TableCard(
              table: _tables[i],
              onEdit: () => _showEditDialog(_tables[i]),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Table Card Widget
// ─────────────────────────────────────────────────────────────────────────────
class _TableCard extends StatelessWidget {
  final Map<String, dynamic> table;
  final VoidCallback onEdit;

  const _TableCard({required this.table, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final additional = table['additional_data'] as Map? ?? {};
    final tableNumber = table['table_number']?.toString() ?? '—';
    final seats = additional['seats'] ?? 0;
    final section = additional['section']?.toString() ?? '—';
    final isActive = table['is_active'] == true;
    final isReserved = table['is_reserved'] == true;

    final Color primaryColor = !isActive
        ? const Color(0xFF94A3B8)
        : isReserved
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);
            
    final Color bgColor = !isActive
        ? const Color(0xFFF8FAFC)
        : isReserved
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFF0FDF4);
            
    final String statusLabel = !isActive ? 'Inactive' : isReserved ? 'Reserved' : 'Available';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background Accent
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                Icons.table_restaurant_rounded,
                size: 100,
                color: bgColor.withOpacity(0.6),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row (Status & Edit)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Center / Main Info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TABLE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        tableNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  
                  // Bottom Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            '$seats',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          section.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
