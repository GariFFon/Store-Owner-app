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

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: Color(0xFF334155)),
                    onPressed: () => Navigator.of(context).maybePop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Table Management',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          "Manage your store's dining tables, reservations, and sections.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Refresh
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        size: 22, color: Color(0xFF5B4FE8)),
                    onPressed: _fetchTables,
                  ),
                  const SizedBox(width: 4),
                  // Add Table
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add\nTable',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4FE8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 52, color: Color(0xFFCBD5E1)),
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center),
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
            const Icon(Icons.table_restaurant_outlined,
                size: 64, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            const Text('No tables yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 6),
            const Text('Tap "Add Table" to create your first table.',
                style:
                    TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
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
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: _tables.length,
        itemBuilder: (_, i) => _TableCard(
          table: _tables[i],
          onEdit: () => _showEditDialog(_tables[i]),
        ),
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
    final section =
        additional['section']?.toString() ?? '—';
    final isActive = table['is_active'] == true;
    final isReserved = table['is_reserved'] == true;

    final statusColor = !isActive
        ? const Color(0xFF94A3B8)
        : isReserved
            ? const Color(0xFFD97706)
            : const Color(0xFF16A34A);
    final statusLabel =
        !isActive ? 'Inactive' : isReserved ? 'Reserved' : 'Available';
    final ringColor = !isActive
        ? const Color(0xFFCBD5E1)
        : isReserved
            ? const Color(0xFFD97706)
            : const Color(0xFF16A34A);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Edit button
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined,
                    size: 15, color: Color(0xFF64748B)),
              ),
            ),
          ),

          // Content
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Seat icons + ring
                _TableVisual(
                  tableNumber: tableNumber,
                  ringColor: ringColor,
                  seats: seats is int ? seats : int.tryParse(seats.toString()) ?? 0,
                ),

                const SizedBox(height: 10),

                // Status dot + label
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Seats | Section
                Text(
                  '$seats Seat${seats == 1 ? '' : 's'} | $section Section',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Table visual: ring + table number + seat icons ──────────────────────────
class _TableVisual extends StatelessWidget {
  final String tableNumber;
  final Color ringColor;
  final int seats;

  const _TableVisual({
    required this.tableNumber,
    required this.ringColor,
    required this.seats,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: _TablePainter(
          ringColor: ringColor,
          seats: seats,
        ),
        child: Center(
          child: Text(
            tableNumber,
            style: TextStyle(
              fontSize: tableNumber.length > 4 ? 14 : 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }
}

class _TablePainter extends CustomPainter {
  final Color ringColor;
  final int seats;

  _TablePainter({required this.ringColor, required this.seats});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final ringR = size.width * 0.36;
    const seatR = 7.0;
    const orbitR = 52.0;

    // Ring
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(Offset(cx, cy), ringR, ringPaint);

    // Seat dots around the ring
    final seatPaint = Paint()..color = ringColor;
    final count = seats.clamp(0, 8);
    for (int i = 0; i < count; i++) {
      final angle = (2 * math.pi / count) * i - math.pi / 2;
      final sx = cx + orbitR * math.cos(angle);
      final sy = cy + orbitR * math.sin(angle);
      canvas.drawCircle(Offset(sx, sy), seatR, seatPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TablePainter old) =>
      old.ringColor != ringColor || old.seats != seats;
}
